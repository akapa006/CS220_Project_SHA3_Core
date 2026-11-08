#!/bin/tcsh -f
# Wrapper: runs PrimeTime PX from the ptpx/ folder and keeps the console log.
# Optional overrides before running, e.g.:
#   setenv PT_VCD ../sim/keccak_power.vcd
#   setenv PT_T_START 100 ; setenv PT_T_END 3005
mkdir -p reports
pt_shell -f run_ptpx.tcl | tee reports/ptpx_run.log
echo "----- summary -----"
cat reports/power_summary.txt
