if {$argc > 1} {
    error "Usage: vivado -mode batch -source scripts/03_run_regression.tcl -tclargs ?<project_file>?"
}

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file dirname $script_dir]

if {$argc == 1} {
    set project_file [file normalize [lindex $argv 0]]
} else {
    set project_file [file join $repo_root build vivado feed_handler.xpr]
}

if {![file exists $project_file]} {
    error "Vivado project not found: $project_file"
}

proc run_regression_test {label simulation_top xsim_options} {
    set simulation_fileset [get_filesets sim_1]
    set assertion_source [get_files -quiet *feed_handler_protocol_assertions.sv]
    set assertion_tops [list \
        tb_feed_handler_basic \
        tb_feed_handler_latency \
        tb_a7_lite_self_test \
        feed_handler_tb_top]
    set assertions_enabled [expr {
        [lsearch -exact $assertion_tops $simulation_top] >= 0
    }]

    puts "REGRESSION START: $label"
    reset_simulation -mode behavioral sim_1
    set_property used_in_simulation $assertions_enabled $assertion_source
    set_property top $simulation_top $simulation_fileset
    set_property xsim.simulate.runtime 0ns $simulation_fileset
    set_property -name xsim.simulate.xsim.more_options \
                 -value [join $xsim_options { }] \
                 -objects $simulation_fileset
    update_compile_order -fileset sim_1
    launch_simulation -mode behavioral
    run all
    close_sim -force
    puts "REGRESSION PASS: $label"
}

open_project $project_file

foreach directed_test [list \
    tb_ethernet_parser \
    tb_ipv4_parser \
    tb_udp_filter \
    tb_market_message_decoder \
    tb_sequence_checker \
    tb_statistics_counters \
    tb_feed_handler_basic \
    tb_feed_handler_latency \
    tb_a7_lite_self_test] {
    run_regression_test $directed_test $directed_test {}
}

run_regression_test feed_handler_smoke_test feed_handler_tb_top {}
run_regression_test "feed_handler_random_test seed 20260730" \
    feed_handler_tb_top {-testplusarg FEED_RANDOM_TEST -sv_seed 20260730}
run_regression_test "feed_handler_random_test seed 20260731" \
    feed_handler_tb_top {-testplusarg FEED_RANDOM_TEST -sv_seed 20260731}

close_project
puts "REGRESSION COMPLETE: 12 runs passed."
