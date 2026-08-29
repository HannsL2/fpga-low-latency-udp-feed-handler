set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file dirname $script_dir]
set bitstream  [file join $repo_root reports a7_lite a7_lite_self_test.bit]

if {![file exists $bitstream]} {
    error "A7-LITE self-test bitstream not found: $bitstream"
}

open_hw_manager
connect_hw_server -allow_non_jtag
open_hw_target

set matching_devices [get_hw_devices -quiet -filter {PART =~ "xc7a35t*"}]
if {[llength $matching_devices] != 1} {
    error "Expected one XC7A35T device, found [llength $matching_devices]."
}

set device [lindex $matching_devices 0]
current_hw_device $device
refresh_hw_device -update_hw_probes false $device
set_property PROGRAM.FILE $bitstream $device
program_hw_devices $device
refresh_hw_device -update_hw_probes false $device

puts "Programmed A7-LITE self-test: $bitstream"
close_hw_manager
