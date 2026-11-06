# Set search and library paths
set LIB_DIR "/usr/local/synopsys/pdk/SAED32_EDK/lib"
set TARGET_LIBS [list \
    ${LIB_DIR}/stdcell_hvt/db_nldm/saed32hvt_ss0p75v125c.db \
    ${LIB_DIR}/stdcell_rvt/db_nldm/saed32rvt_ss0p75v125c.db \
    ${LIB_DIR}/stdcell_lvt/db_nldm/saed32lvt_ss0p75v125c.db ]

set_app_var search_path ../rtl
set_app_var link_path      "* $TARGET_LIBS"
set_app_var target_library $TARGET_LIBS

# Power grid settings
set dc_allow_rtl_pg       true
set mw_logic1_net "VDD"
set mw_logic0_net "VSS"

# Define the design name
set DESIGN_NAME     "keccak"

# Analyze the Verilog source file
analyze -format verilog "keccak.v padder.v padder1.v f_permutation.v round2in1.v rconst2in1.v"

# Elaborate the design
elaborate ${DESIGN_NAME} -architecture verilog -library DEFAULT

# Link the design to ensure all references are resolved
link

# Flatten the hierarchy to ensure all submodules are ungrouped
# ungroup -all -flatten -simple_names

# Constraints
# Clock definition: 2.5 ns period (400 MHz), 50% duty cycle
create_clock -name "clk" -period 2.5 -waveform {0 1.25} [get_ports "clk"]
set_dont_touch_network [get_clocks "clk"]

# Input and output delays relative to clock
set_input_delay 0.1 -max -clock "clk" [get_ports "reset"]
set_input_delay 0.1 -max -clock "clk" [get_ports "in[*]"]
set_input_delay 0.1 -max -clock "clk" [get_ports "in_ready"]
set_input_delay 0.1 -max -clock "clk" [get_ports "is_last"]
set_input_delay 0.1 -max -clock "clk" [get_ports "byte_num[*]"]
set_output_delay 0.1 -max -clock "clk" [get_ports "buffer_full"]
set_output_delay 0.1 -max -clock "clk" [get_ports "out[*]"]
set_output_delay 0.1 -max -clock "clk" [get_ports "out_ready"]


# Clock uncertainty for setup and hold times
set_clock_uncertainty 0.2 -setup [get_clocks "clk"]
set_clock_uncertainty 0.2 -hold [get_clocks "clk"]

# General design constraints
set_max_fanout 100 [get_designs "*"]
set_fix_multiple_port_nets -all -buffer_constants

# Design-specific constraints
set_input_transition 0.1 [get_ports "reset"]
set_input_transition 0.1 [get_ports "in[*]"]
set_input_transition 0.1 [get_ports "in_ready"]
set_input_transition 0.1 [get_ports "is_last"]
set_input_transition 0.1 [get_ports "byte_num[*]"]

# Set capacitive load to outputs
set_load 5 [get_ports "buffer_full"]
set_load 5 [get_ports "out[*]"]
set_load 5 [get_ports "out_ready"]

# Check the design for issues
check_design

# Perform synthesis with optimization
compile_ultra -no_autoungroup

# Fix naming and hierarchy for output
change_names -rules verilog -hierarchy

# Write synthesized outputs
write -format ddc -hierarchy -output "${DESIGN_NAME}_synthesized.ddc"
write -format verilog -hierarchy -output "${DESIGN_NAME}_synthesized.v"
write_sdc -nosplit "${DESIGN_NAME}_const.sdc"
write_sdf "${DESIGN_NAME}_const.sdf"

# Generate reports
report_timing -transition_time -nets -attributes > reports/${DESIGN_NAME}_timing_reports.log
report_qor > reports/${DESIGN_NAME}_qor_reports.log
report_area -hierarchy > reports/${DESIGN_NAME}_area_reports.log
report_power -hierarchy > reports/${DESIGN_NAME}_power_reports.log
report_reference -hierarchy > reports/${DESIGN_NAME}_reference_reports.log
report_constraint -all_violators > reports/${DESIGN_NAME}_violators.log

# Exit the synthesis tool
exit