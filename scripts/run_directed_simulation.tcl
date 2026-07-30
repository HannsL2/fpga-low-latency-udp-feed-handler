# Run one directed test from the generated Vivado project.

if {$argc < 1 || $argc > 3} {
    error "Usage: vivado -mode batch -source scripts/run_directed_simulation.tcl -tclargs <testbench> ?<project_file>? ?<seed>?"
}

set testbench [lindex $argv 0]
set supported_testbenches [list tb_ethernet_parser tb_ipv4_parser tb_udp_filter tb_market_message_decoder tb_sequence_checker tb_statistics_counters tb_feed_handler_basic tb_feed_handler_uvm tb_feed_handler_uvm_random feed_handler_tb_top feed_handler_smoke_test feed_handler_random_test]

if {[lsearch -exact $supported_testbenches $testbench] < 0} {
    error "Unsupported testbench '$testbench'. Choose one of: [join $supported_testbenches {, }]."
}

set script_dir  [file dirname [file normalize [info script]]]
set repo_root   [file dirname $script_dir]

if {$argc >= 2} {
    set project_file [file normalize [lindex $argv 1]]
} else {
    set project_file [file join $repo_root build vivado feed_handler.xpr]
}

if {![file exists $project_file]} {
    error "Vivado project not found. Run scripts/create_vivado_project.tcl first."
}

set simulation_top $testbench
set xsim_more_options {}

if {$testbench eq "tb_feed_handler_uvm" ||
    $testbench eq "feed_handler_smoke_test"} {
    set simulation_top feed_handler_tb_top
} elseif {$testbench eq "tb_feed_handler_uvm_random" ||
          $testbench eq "feed_handler_random_test"} {
    set simulation_top feed_handler_tb_top
    set xsim_more_options {-testplusarg FEED_RANDOM_TEST}
}

if {$argc == 3} {
    set simulation_seed [lindex $argv 2]
    if {![string is integer -strict $simulation_seed]} {
        error "Simulation seed must be an integer."
    }
    lappend xsim_more_options -sv_seed $simulation_seed
}

open_project $project_file
set_property top $simulation_top [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
set_property -name xsim.simulate.xsim.more_options \
             -value [join $xsim_more_options { }] \
             -objects [get_filesets sim_1]
update_compile_order -fileset sim_1

launch_simulation -mode behavioral
run all
close_sim -force
close_project
