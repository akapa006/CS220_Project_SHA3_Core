# =============================================================================
# run_ptpx_timebased.tcl -- PrimeTime PX time-based (cycle-by-cycle) power
#                           of the synthesized SHA-3 core (CS 220 Team 2)
#
# Companion to run_ptpx.tcl (averaged power). Same libraries, netlist, SDC and
# VCD conventions; the difference is power_analysis_mode time_based, which
# gives:
#   - peak power and the time it happens   -> reports/tb_power.log
#   - a power-vs-time waveform              -> reports/power_wave.out (text)
#                                              and reports/power_wave.fsdb (Verdi)
#
# Inputs (same env-var overrides as run_ptpx.tcl):
#   PT_NETLIST ../syn/keccak_synthesized.v   PT_SDC ../syn/keccak_const.sdc
#   PT_TOP keccak   PT_VCD ../sim/keccak.vcd   PT_STRIP test_keccak_vec/uut
#   PT_LIB_DIR /usr/local/synopsys/pdk/SAED32_EDK/lib
#
# Use a short VCD (e.g. NVEC=150 in sim/) -- time-based analysis is much slower
# than averaged analysis and the waveform file grows with simulated time.
#
# Run (from ptpx/):  pt_shell -f run_ptpx_timebased.tcl | tee reports/ptpx_timebased.log
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
set RPT "reports"
file mkdir $RPT

foreach f [list $NETLIST $SDC $VCD] {
    if {![file exists $f]} { puts "ERROR: input file not found: $f"; exit 1 }
}

set power_enable_analysis TRUE
set power_analysis_mode   time_based

set target_library [list \
    ${LIB_DIR}/stdcell_rvt/db_nldm/saed32rvt_ss0p75v125c.db \
    ${LIB_DIR}/stdcell_lvt/db_nldm/saed32lvt_ss0p75v125c.db \
    ${LIB_DIR}/stdcell_hvt/db_nldm/saed32hvt_ss0p75v125c.db ]
set link_library [concat {*} $target_library]
foreach lib $target_library { read_db $lib }

read_verilog $NETLIST
link_design  $TOP
read_sdc     $SDC

read_vcd -strip_path $STRIP $VCD

# One power sample per clock cycle (2.5 ns). Text waveform for plotting,
# then the same waveform as FSDB for Verdi/nWave.
set_power_analysis_options -waveform_interval 2.5 -waveform_format out  -waveform_output $RPT/power_wave
update_power
report_power -nosplit            > $RPT/tb_power.log
report_power -nosplit -hierarchy > $RPT/tb_hier_power.log

set_power_analysis_options -waveform_interval 2.5 -waveform_format fsdb -waveform_output $RPT/power_wave
update_power

exit
