# =============================================================================
# run_ptpx.tcl -- PrimeTime PX average-power analysis of the synthesized SHA-3
#                 core (CS 220 Team 2, midterm)
#
# What it does
#   1. Loads the SAME worst-case libraries synthesis used (ss0p75v125c RVT/LVT/HVT)
#   2. Reads the synthesized netlist and the SDC written by the same synthesis run
#   3. Annotates switching activity from a VCD of the gate-level (netlist)
#      simulation running a representative workload at the synthesized clock
#   4. Runs averaged power analysis and writes reports to reports/
#
# Inputs (hand-off points with the other folders; override any of them with
# environment variables before running, e.g.  setenv PT_VCD ../sim/power.vcd)
#   PT_NETLIST   ../syn/keccak_synthesized.v   from syn/
#   PT_SDC       ../syn/keccak_const.sdc       from syn/  (clock = 2.5 ns)
#   PT_TOP       keccak                        top module of the netlist
#   PT_VCD       ../sim/keccak.vcd             from sim/ (netlist simulation)
#   PT_STRIP     test_keccak_vec/uut           testbench path to the DUT in the VCD
#   PT_LIB_DIR   /usr/local/synopsys/pdk/SAED32_EDK/lib
#   PT_T_START / PT_T_END   optional analysis window in ns (e.g. skip reset)
#
# Run (from the ptpx/ folder):   ./run_ptpx.csh      or
#                                pt_shell -f run_ptpx.tcl | tee reports/ptpx_run.log
# =============================================================================

proc cfg {name default} {
    if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) }
    return $default
}

set NETLIST [cfg PT_NETLIST "../syn/keccak_synthesized.v"]
set SDC     [cfg PT_SDC     "../syn/keccak_const.sdc"]
set TOP     [cfg PT_TOP     "keccak"]
set VCD     [cfg PT_VCD     "../sim/keccak.vcd"]
set STRIP   [cfg PT_STRIP   "test_keccak_vec/uut"]
set LIB_DIR [cfg PT_LIB_DIR "/usr/local/synopsys/pdk/SAED32_EDK/lib"]
set T_START [cfg PT_T_START ""]
set T_END   [cfg PT_T_END   ""]
set RPT     "reports"
file mkdir $RPT

foreach f [list $NETLIST $SDC $VCD] {
    if {![file exists $f]} { puts "ERROR: input file not found: $f"; exit 1 }
}

# ---- 1. power analysis mode and libraries ----------------------------------
set power_enable_analysis TRUE
set power_analysis_mode   averaged

# Worst-case corner required by the midterm, identical to syn/syn.tcl
set target_library [list \
    ${LIB_DIR}/stdcell_rvt/db_nldm/saed32rvt_ss0p75v125c.db \
    ${LIB_DIR}/stdcell_lvt/db_nldm/saed32lvt_ss0p75v125c.db \
    ${LIB_DIR}/stdcell_hvt/db_nldm/saed32hvt_ss0p75v125c.db ]
set link_library [concat {*} $target_library]
foreach lib $target_library { read_db $lib }

# ---- 2. netlist + constraints from the same synthesis run -----------------
read_verilog $NETLIST
link_design  $TOP
read_sdc     $SDC

# ---- 3. switching activity from the netlist simulation --------------------
if {$T_START ne "" && $T_END ne ""} {
    read_vcd -strip_path $STRIP -time [list $T_START $T_END] $VCD
} else {
    read_vcd -strip_path $STRIP $VCD
}

# ---- 4. power ----------------------------------------------------------------
update_power

report_power -nosplit -verbose                 > $RPT/total_power.log
report_power -nosplit -hierarchy               > $RPT/hier_power.log
report_power -nosplit -cell -verbose           > $RPT/cell_power.log
report_switching_activity -list_not_annotated  > $RPT/unannotated.log
report_switching_activity                      > $RPT/switching_activity.log
report_clock                                   > $RPT/clock.log

# One-file summary for the report / README (values in W, converted to mW)
set d [current_design]
set fp [open $RPT/power_summary.txt w]
puts $fp "SHA-3 core average power (PrimeTime PX, averaged mode)"
puts $fp "Corner     : ss0p75v125c (RVT + LVT + HVT, db_nldm)"
puts $fp "Netlist    : $NETLIST   (top = $TOP)"
puts $fp "Constraints: $SDC"
puts $fp "Activity   : $VCD   (strip path $STRIP)"
if {$T_START ne ""} { puts $fp "Window     : $T_START ns to $T_END ns" }
foreach a {internal_power switching_power leakage_power total_power} {
    if {[catch {set v [get_attribute $d $a]}]} { set v "n/a" } else { set v [format "%.4f mW" [expr {$v * 1000.0}]] }
    puts $fp [format "%-16s : %s" $a $v]
}
close $fp
puts "Reports written to $RPT/  (see $RPT/power_summary.txt)"
exit
