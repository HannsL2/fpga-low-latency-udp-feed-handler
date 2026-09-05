set_property PACKAGE_PIN J19 [get_ports clk_50mhz]
set_property IOSTANDARD LVCMOS33 [get_ports clk_50mhz]

set_property PACKAGE_PIN L18 [get_ports reset_n]
set_property IOSTANDARD LVCMOS33 [get_ports reset_n]
set_property PULLUP true [get_ports reset_n]

set_property PACKAGE_PIN M18 [get_ports led_link_n]
set_property PACKAGE_PIN N18 [get_ports led_activity_n]
set_property IOSTANDARD LVCMOS33 [get_ports {led_link_n led_activity_n}]
set_property DRIVE 8 [get_ports {led_link_n led_activity_n}]
set_property SLEW SLOW [get_ports {led_link_n led_activity_n}]

set_property PACKAGE_PIN V2 [get_ports uart_tx]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx]
set_property DRIVE 8 [get_ports uart_tx]
set_property SLEW SLOW [get_ports uart_tx]

set_property PACKAGE_PIN H18 [get_ports eth_rx_clk]
set_property PACKAGE_PIN K19 [get_ports eth_rx_ctl]
set_property PACKAGE_PIN J17 [get_ports {eth_rxd[0]}]
set_property PACKAGE_PIN K16 [get_ports {eth_rxd[1]}]
set_property PACKAGE_PIN L15 [get_ports {eth_rxd[2]}]
set_property PACKAGE_PIN M15 [get_ports {eth_rxd[3]}]

set_property PACKAGE_PIN L13 [get_ports eth_tx_clk]
set_property PACKAGE_PIN N20 [get_ports eth_tx_ctl]
set_property PACKAGE_PIN L16 [get_ports {eth_txd[0]}]
set_property PACKAGE_PIN L14 [get_ports {eth_txd[1]}]
set_property PACKAGE_PIN M13 [get_ports {eth_txd[2]}]
set_property PACKAGE_PIN K14 [get_ports {eth_txd[3]}]

set_property PACKAGE_PIN M21 [get_ports eth_mdc]
set_property PACKAGE_PIN M20 [get_ports eth_mdio]
set_property PACKAGE_PIN M22 [get_ports eth_reset_n]

set_property IOSTANDARD LVCMOS33 [get_ports {
    eth_rx_clk eth_rx_ctl eth_rxd[*]
    eth_tx_clk eth_tx_ctl eth_txd[*]
    eth_mdc eth_mdio eth_reset_n
}]
set_property DRIVE 8 [get_ports {
    eth_tx_clk eth_tx_ctl eth_txd[*] eth_mdc eth_reset_n
}]
set_property SLEW FAST [get_ports {eth_tx_clk eth_tx_ctl eth_txd[*]}]
set_property SLEW SLOW [get_ports {eth_mdc eth_reset_n}]

# The A7-LITE PCB connects RTL8211E RXCK to H18, which Vivado identifies as
# a non-clock-capable I/O. This board-specific exception permits the only
# physical route available from that fixed pin to the global RX clock buffer.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rx_clock_input]
