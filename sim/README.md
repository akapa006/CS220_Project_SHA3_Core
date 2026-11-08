# sim/ — verification and power simulation

| File | Purpose |
|---|---|
| `gen_vectors.py` | Golden model (Keccak-512 with this core's 0x01 padding, self-checked against `hashlib.sha3_512` with 0x06 padding) and vector generator. Writes `lens.hex`, `msgs.hex`, `digests.hex`. Seed 1 by default: `python3 gen_vectors.py [seed]`. |
| `test_keccak_vectors.v` | Self-checking testbench: feeds every vector to the core and compares each 512-bit output with the golden digest. 451 vectors: every length 0–300 bytes plus 150 random lengths 301–699 (1–10 blocks). |
| `test_keccak.v` | Hand-written corner cases with hard-coded expected hashes. |
| `run_rtl.csh` | RTL regression: vectors back to back, vectors with random idle gaps (`+gaps`), and the hard-coded cases. |
| `run_netlist.csh` | Gate-level simulation of `../syn/keccak_synthesized.v` at 2.5 ns; checks the hashes and writes `keccak.vcd` for `../ptpx/`. |

## Run (on Bender, tcsh, from `sim/`)

```tcsh
./run_rtl.csh        # expect "ALL 451 VECTORS PASSED" twice, then the hard-coded results
./run_netlist.csh    # expect "ALL 200 VECTORS PASSED", then keccak.vcd
```

## Testbench options

| Option | Kind | Effect |
|---|---|---|
| `+gaps` | run time | 0–3 random idle cycles before each input word |
| `+nvec=N` | run time | run only the first N vectors |
| `+define+P=2.5` | compile time | clock period in ns (default 20) |
| `+define+DUMP_VCD` | compile time | dump `test_keccak_vec.uut` to `keccak.vcd` for PrimeTime |

The input protocol the testbench follows (needed by any new test):
inputs change on the falling clock edge; a word is never presented while
`buffer_full` is 1; the last word carries `is_last = 1` and `byte_num` = number
of valid bytes (left-aligned); a message whose length is a multiple of 8 ends
with an extra empty word (`byte_num = 0`).

Generated files (`*.hex`, `simv*`, `csrc/`, `*.daidir`, `*.vcd`, logs) are not
committed; rerun the scripts to recreate them.
