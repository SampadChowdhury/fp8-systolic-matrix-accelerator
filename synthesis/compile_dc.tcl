# Portable Design Compiler setup for the complete APB accelerator.
# Set PDK_DIR to the directory containing gscl45nm.db.

set rtl_files [list \
    ../rtl/fp8_e3m4_mul.sv \
    ../rtl/fp8_e3m4_add.sv \
    ../rtl/dual_mode_mac_pe.sv \
    ../rtl/systolic_array_4x4.sv \
    ../rtl/matrix_accelerator_core.sv \
    ../rtl/matmul_apb_wrapper.sv]

set top_module matmul_apb_wrapper
set clock_period_ns 2.0
set io_delay_ns 0.05

set pdk_dir [getenv PDK_DIR]
if {$pdk_dir eq ""} {
    error "PDK_DIR must point to the directory containing gscl45nm.db"
}

set search_path [concat $search_path [list $pdk_dir]]
set target_library [list gscl45nm.db]
set link_library [concat "*" $target_library [list dw_foundation.sldb]]

define_design_lib WORK -path ./WORK
analyze -format sverilog $rtl_files
elaborate $top_module
current_design $top_module
link
uniquify

create_clock -name PCLK -period $clock_period_ns [get_ports PCLK]
set_input_delay $io_delay_ns -clock PCLK \
    [remove_from_collection [all_inputs] [get_ports {PCLK PRESETn}]]
set_output_delay $io_delay_ns -clock PCLK [all_outputs]
set_false_path -from [get_ports PRESETn]

compile_ultra
check_design
report_constraint -all_violators

file mkdir reports
redirect reports/timing.rpt {report_timing -max_paths 10}
redirect reports/area.rpt {report_area -hierarchy}
redirect reports/power.rpt {report_power}
write -format ddc -hierarchy -output reports/matmul_apb_wrapper.ddc
write_sdc reports/matmul_apb_wrapper.sdc
quit
