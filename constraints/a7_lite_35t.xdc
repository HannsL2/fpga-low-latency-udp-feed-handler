set_property PACKAGE_PIN J19 [get_ports clk_50mhz]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50mhz]

set_property PACKAGE_PIN L18 [get_ports reset_n]
set_property IOSTANDARD LVCMOS33 [get_ports reset_n]
set_property PULLUP true [get_ports reset_n]

set_property PACKAGE_PIN M18 [get_ports led_pass_n]
set_property PACKAGE_PIN N18 [get_ports led_fail_n]
set_property IOSTANDARD LVCMOS33 [get_ports {led_pass_n led_fail_n}]
set_property DRIVE 8 [get_ports {led_pass_n led_fail_n}]
set_property SLEW SLOW [get_ports {led_pass_n led_fail_n}]
