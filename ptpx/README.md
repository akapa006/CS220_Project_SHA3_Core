# ptpx/ — PrimeTime PX power analysis

Measures the **average power** of the synthesized SHA-3 core at its maximum
frequency (2.5 ns, 400 MHz), using switching activity recorded from a
gate-level simulation of a representative workload.

## How it fits with the other folders

PrimeTime is the last stage of the flow. It only reads files that the other
folders produce, and nothing depends on its output.

```
rtl/  Verilog ──► syn/  Design Compiler ──► syn/keccak_synthesized.v
                                             syn/keccak_const.sdc
sim/  gen_vectors.py (golden model) ──► lens.hex, msgs.hex, digests.hex
      test_keccak_vectors.v + netlist, 2.5 ns clock ──► sim/keccak.vcd
                                                │
ptpx/ PrimeTime PX: netlist + SDC + VCD + same libraries ──► ptpx/reports/
```

| Input | Produced by | Default path | Convention both sides keep |
|---|---|---|---|
| Netlist | `syn/` | `../syn/keccak_synthesized.v` | top module `keccak` |
| Constraints | `syn/` | `../syn/keccak_const.sdc` | same synthesis run as the netlist; clock `clk`, 2.5 ns |
| Libraries | — | `/usr/local/synopsys/pdk/SAED32_EDK/lib` | identical to `syn/syn.tcl`: `saed32{rvt,lvt,hvt}_ss0p75v125c.db` (db_nldm) |
| Workload | `sim/gen_vectors.py` | `sim/*.hex` | seed 1, original Keccak padding (0x01) |
| Activity | `sim/run_netlist.csh` | `../sim/keccak.vcd` | DUT instance `test_keccak_vec.uut`, clock 2.5 ns |

Every input can be overridden with an environment variable (`PT_NETLIST`,
`PT_SDC`, `PT_TOP`, `PT_VCD`, `PT_STRIP`, `PT_LIB_DIR`), so the script never has
to be edited when a file name changes. If someone renames the netlist, the
testbench module or the `uut` instance, update this table and the defaults at
the top of `run_ptpx.tcl` together.

## How to run

On Bender, from the repository root (bash shown; tcsh equivalents in comments):

```bash
cd sim
NVEC=451 ./run_netlist.csh   # bash; in tcsh: setenv NVEC 451 first. Must print "ALL 451 VECTORS PASSED"
cd ../ptpx
nohup ./run_ptpx.csh > ptpx_nohup.out &   # several minutes for a 4.4 GB VCD; survives SSH drops
tail -5 ptpx_nohup.out                    # finished when the power summary is printed
```

`syn/` must already contain the netlist and SDC (they are committed).

Optional settings:

```bash
export PT_T_START=100      # in ptpx/: analyse only a time window, in ns (tcsh: setenv)
export PT_T_END=60000
```

## Outputs (`reports/`)

| File | Contents |
|---|---|
| `power_summary.txt` | internal, switching, leakage and total power in mW, plus the inputs used |
| `total_power.log` | full averaged power report |
| `hier_power.log` | power per module (`padder_`, `f_permutation_`, `round_`, …) |
| `cell_power.log` | power per cell |
| `unannotated.log` | nets with no activity from the VCD — **must be empty** |
| `switching_activity.log` | annotation statistics |
| `clock.log` | clock actually used (confirms 2.5 ns) |
| `ptpx_run.log` | console log of the run |

`reports/` is committed; the VCD is not (it is large and can be regenerated).

## Methodology

- **Mode:** averaged power (`power_analysis_mode averaged`) over the whole
  simulated workload.
- **Corner:** the same worst-case libraries as synthesis (ss, 0.75 V, 125 °C,
  RVT + LVT + HVT), so the timing and power numbers describe the same chip.
- **Frequency:** the clock comes from the synthesis SDC (2.5 ns), and the
  netlist simulation runs at the same period (`+define+P=2.5`), so toggle
  rates match the reported frequency.
- **Workload:** the full 451-vector set from `gen_vectors.py` (`NVEC=451`):
  every message length from 0 to 300 bytes plus 150 random lengths up to
  699 bytes (1–10 blocks), fed back to back, 27,783 cycles. This covers
  every value of `byte_num`, the multiple-of-8 case, multi-block messages
  and the padder stall on `buffer_full`. The VCD is ~4.4 GB, so it is
  deleted after the run and regenerated when needed. (`run_netlist.csh`
  defaults to 200 vectors for quick checks.)
- **Validity:** the same simulation checks every hash against the golden
  model, so power is only reported for a run where the netlist is
  functionally correct. `unannotated.log` must be empty; if it isn't,
  `PT_STRIP` does not match the testbench hierarchy and PrimeTime would fall
  back to guessed toggle rates.

### Known messages (harmless)

- `Error: Library Compiler executable path is not set (PT-063)`: Library
  Compiler is only needed to compile `.lib` sources; this flow reads `.db`
  files.
- `Warning: Some timing arcs have been disabled ... (PTE-003)`: normal for this
  design, where the permutation state feeds back into the round logic.

## Results

### Baseline (original core), measured 2026-11-07

Workload: all 451 vectors (`NVEC=451`), back to back, 27,783 cycles
(69.5 µs) at 2.5 ns. The netlist simulation passed all 451 hashes.
Annotation: 26,068 / 26,068 nets (100 %) from the VCD, no unannotated nets;
clock confirmed at 2.5 ns.

| Component | Power | Share |
|---|---|---|
| Cell internal | 36.30 mW | 65.5 % |
| Net switching | 6.72 mW | 12.1 % |
| Leakage | 12.42 mW | 22.4 % |
| **Total average** | **55.44 mW** | 100 % |

| Module | Internal | Switching | Leakage | Total | Share |
|---|---|---|---|---|---|
| `keccak` (top) | 36.3 mW | 6.72 mW | 12.4 mW | 55.4 mW | 100 % |
| `padder_` (incl. 576-bit buffer) | 0.82 mW | 0.05 mW | 0.79 mW | 1.67 mW | 3.0 % |
| `f_permutation_` | 35.5 mW | 6.67 mW | 11.6 mW | 53.8 mW | 97.0 % |
| └ `round_` (two Keccak rounds) | 31.0 mW | 5.90 mW | 8.43 mW | 45.3 mW | 81.8 % |

Reading the numbers:

- Almost all power is in the permutation, and most of that is the
  combinational round logic that runs every cycle while a block is hashed.
- Leakage (12.4 mW) does not depend on activity; it is high because of the
  125 °C corner and the LVT cells synthesis chose to meet 2.5 ns.
- The padder, including the 576-bit buffer that the planned area reduction
  removes, is 3 % of total power. Removing the buffer is therefore expected
  to save mainly **area** and at most a few percent of power, and the
  extra cycles per block will lower throughput. The after-optimization run
  will measure this rather than assume it.

An earlier run on a shorter 20-message workload (~1,200 cycles, with idle
gaps) gave 43.6 mW. The difference is workload: the 451-vector run streams
data continuously, so the permutation is busy a larger fraction of the time.
Leakage is the same in both runs (12.4 mW), as expected. Only the 451-vector
number is used for comparisons.

### Area-reduced core

Same script, libraries, clock and workload (`NVEC=451`); only the netlist
and its VCD change. Because the optimized core needs more cycles per block,
compare **energy per hash** (average power × simulated time ÷ 451) as well
as average power:

```tcsh
setenv PT_NETLIST ../syn/keccak_area_reduced_synthesized.v
setenv PT_SDC     ../syn/keccak_area_reduced_const.sdc
./run_ptpx.csh
```
