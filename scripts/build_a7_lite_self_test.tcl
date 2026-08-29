set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file dirname $script_dir]
set build_dir  [file join $repo_root build a7_lite_self_test]
set report_dir [file join $repo_root reports a7_lite]

proc sanitize_report_header {report_path repo_root} {
    set input_file [open $report_path r]
    set report_text [read $input_file]
    close $input_file

    regsub -all -line {^\| Host\s+:.*$} $report_text \
        {| Host         : omitted from public report} report_text
    set normalized_root [string map {\\ /} $repo_root]
    set report_text [string map [list "$normalized_root/" ""] $report_text]
    regsub -all -line {[ \t]+$} $report_text {} report_text
    set report_text "[string trimright $report_text]\n"

    set output_file [open $report_path w]
    puts -nonewline $output_file $report_text
    close $output_file
}

file mkdir $build_dir
file mkdir $report_dir

create_project a7_lite_self_test $build_dir -part xc7a35tfgg484-2 -force
set_property target_language Verilog [current_project]

set rtl_files [list \
    [file join $repo_root rtl feed_handler_pkg.sv] \
    [file join $repo_root rtl stream_packet_controller.sv] \
    [file join $repo_root rtl ethernet_parser.sv] \
    [file join $repo_root rtl ipv4_parser.sv] \
    [file join $repo_root rtl udp_parser.sv] \
    [file join $repo_root rtl packet_filter.sv] \
    [file join $repo_root rtl udp_payload_router.sv] \
    [file join $repo_root rtl market_message_decoder.sv] \
    [file join $repo_root rtl sequence_checker.sv] \
    [file join $repo_root rtl statistics_counters.sv] \
    [file join $repo_root rtl udp_feed_handler_top.sv] \
    [file join $repo_root rtl board a7_lite_self_test_top.sv]]

add_files -norecurse $rtl_files
set physical_constraints [file join $repo_root constraints a7_lite_35t.xdc]
set timing_constraints [file join $repo_root constraints a7_lite_timing.xdc]
add_files -fileset constrs_1 -norecurse \
    [list $physical_constraints $timing_constraints]
set_property used_in_synthesis false [get_files $physical_constraints]
set_property file_type SystemVerilog [get_files $rtl_files]
set_property top a7_lite_self_test_top [current_fileset]
update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 4
wait_on_run synth_1
open_run synth_1
report_utilization -file [file join $report_dir post_synthesis_utilization.rpt]
report_timing_summary -file [file join $report_dir post_synthesis_timing.rpt]

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
open_run impl_1
report_utilization -file [file join $report_dir post_implementation_utilization.rpt]
report_methodology -file [file join $report_dir post_implementation_methodology.rpt]
report_timing_summary -file [file join $report_dir post_implementation_timing.rpt]
report_clock_utilization -file [file join $report_dir clock_utilization.rpt]

foreach report_file [glob -nocomplain -directory $report_dir *.rpt] {
    sanitize_report_header $report_file $repo_root
}

set bitstream_source [file join \
    [get_property DIRECTORY [get_runs impl_1]] \
    a7_lite_self_test_top.bit]
if {$bitstream_source eq "" || ![file exists $bitstream_source]} {
    error "Implementation completed without producing a bitstream."
}
file copy -force $bitstream_source \
    [file join $report_dir a7_lite_self_test.bit]

puts "A7-LITE self-test implementation completed."
puts "Reports and bitstream: $report_dir"
close_project
