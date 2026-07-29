# Create a local Vivado project containing the current RTL and directed tests.

set script_dir  [file dirname [file normalize [info script]]]
set repo_root   [file dirname $script_dir]

if {$argc >= 1} {
    set project_dir [file normalize [lindex $argv 0]]
} else {
    set project_dir [file join $repo_root build vivado]
}

file mkdir $project_dir

create_project feed_handler $project_dir -part xc7a35tcpg236-1 -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

set rtl_files [list \
    [file join $repo_root rtl feed_handler_pkg.sv] \
    [file join $repo_root rtl stream_packet_controller.sv] \
    [file join $repo_root rtl ethernet_parser.sv] \
    [file join $repo_root rtl ipv4_parser.sv] \
    [file join $repo_root rtl udp_parser.sv] \
    [file join $repo_root rtl packet_filter.sv] \
    [file join $repo_root rtl udp_payload_router.sv] \
    [file join $repo_root rtl market_message_decoder.sv] \
    [file join $repo_root rtl udp_feed_handler_top.sv]]

set simulation_files [list \
    [file join $repo_root tb basic tb_ethernet_parser.sv] \
    [file join $repo_root tb basic tb_ipv4_parser.sv] \
    [file join $repo_root tb basic tb_udp_filter.sv] \
    [file join $repo_root tb basic tb_market_message_decoder.sv] \
    [file join $repo_root tb basic tb_feed_handler_basic.sv]]

add_files -norecurse -fileset sources_1 $rtl_files
add_files -norecurse -fileset sim_1 $simulation_files

set_property file_type SystemVerilog [get_files $rtl_files]
set_property file_type SystemVerilog [get_files $simulation_files]
set_property top udp_feed_handler_top [get_filesets sources_1]
set_property top tb_feed_handler_basic [get_filesets sim_1]
set_property xsim.simulate.runtime 5us [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Created Vivado project: [file join $project_dir feed_handler.xpr]"
close_project
