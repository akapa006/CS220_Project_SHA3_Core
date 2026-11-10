#!/bin/tcsh -f
# =============================================================================
# run_netlist.csh -- gate-level simulation of the synthesized netlist at the
#                    synthesized clock (2.5 ns = 400 MHz), run from sim/
#
# Purpose
#   1. Verification: the netlist must give the same hashes as the RTL.
#   2. Power: it writes keccak.vcd, the switching activity PrimeTime PX reads
#      (see ../ptpx/README.md).
#
# Simulation is zero-delay (+nospecify +notimingcheck). Timing is already
# signed off by Design Compiler at 2.5 ns; this run checks function and
# records toggles at the real clock rate.
#
# Workload size: the first NVEC vectors written by gen_vectors.py
# (default 200 = message lengths 0-199 bytes, 1-3 blocks, ~6,600 cycles,
# VCD ~0.75 GB). For the full 451 vectors (~27,800 cycles, VCD ~3.2 GB):
#     setenv NVEC 451 ; ./run_netlist.csh
#
# Logs: netlist.log    Output: keccak.vcd
# Expect: "ALL <NVEC> VECTORS PASSED"
# =============================================================================
if (! $?NVEC) setenv NVEC 200
set LIB = /usr/local/synopsys/pdk/SAED32_EDK/lib

if (! -e lens.hex) then
    python3 ../sw/gen_vectors.py || exit 1
endif

vcs -full64 -timescale=1ns/1ps +define+P=2.5 +define+DUMP_VCD \
    test_keccak_vectors.v ../syn/keccak_synthesized.v \
    -v $LIB/stdcell_rvt/verilog/saed32nm.v \
    -v $LIB/stdcell_lvt/verilog/saed32nm_lvt.v \
    -v $LIB/stdcell_hvt/verilog/saed32nm_hvt.v \
    +nospecify +notimingcheck \
    -o simv_netlist -l comp_netlist.log > /dev/null || exit 1

./simv_netlist +nvec=$NVEC | tee netlist.log | grep -E "PASSED|FAILED|FAIL"
ls -lh keccak.vcd
