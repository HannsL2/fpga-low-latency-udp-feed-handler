create_clock -name clk_50mhz -period 20.000 [get_ports clk_50mhz]
create_clock -name rgmii_rx_clk -period 8.000 [get_ports eth_rx_clk]

set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks clk_50mhz] \
    -group [get_clocks -include_generated_clocks rgmii_rx_clk]

# The RTL8211E is strapped for original (no internal delay) RGMII receive
# timing. Its specified clock-to-data output skew is -0.5 ns to +0.5 ns. The RX
# MMCM shifts the internal sample clock by 2.5 ns to balance post-route setup
# and hold margins at the Artix-7 input registers.
set_input_delay -clock rgmii_rx_clk -max 0.500 [get_ports {eth_rx_ctl eth_rxd[*]}]
set_input_delay -clock rgmii_rx_clk -min -0.500 [get_ports {eth_rx_ctl eth_rxd[*]}]
set_input_delay -clock rgmii_rx_clk -clock_fall -add_delay -max 0.500 \
    [get_ports {eth_rx_ctl eth_rxd[*]}]
set_input_delay -clock rgmii_rx_clk -clock_fall -add_delay -min -0.500 \
    [get_ports {eth_rx_ctl eth_rxd[*]}]
