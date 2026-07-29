# Run one directed test from the generated Vivado project.

if {$argc < 1 || $argc > 2} {
    error "Usage: vivado -mode batch -source scripts/run_directed_simulation.tcl -tclargs <testbench> ?<project_file>?"
}

set testbench [lindex $argv 0]
set supported_testbenches [list tb_ethernet_parser tb_ipv4_parser tb_udp_filter tb_market_message_decoder tb_feed_handler_basic]

if {[lsearch -exact $supported_testbenches $testbench] < 0} {
    error "Unsupported testbench '$testbench'. Choose tb_ethernet_parser, tb_ipv4_parser, tb_udp_filter or tb_feed_handler_basic."
}

set script_dir  [file dirname [file normalize [info script]]]
set repo_root   [file dirname $script_dir]

if {$argc == 2} {
    set project_file [file normalize [lindex $argv 1]]
} else {
    set project_file [file join $repo_root build vivado feed_handler.xpr]
}

if {![file exists $project_file]} {
    error "Vivado project not found. Run scripts/create_vivado_project.tcl first."
}

open_project $project_file
set_property top $testbench [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation -mode behavioral
run all
close_sim -force
close_project
