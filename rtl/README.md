# RTL reading order

Follow the numbered files in order. The numbers indicate a reading order; compilation dependencies are handled by the Vivado scripts and UVM package.

- [01_feed_handler_pkg.sv](01_feed_handler_pkg.sv)
- [02_udp_feed_handler_top.sv](02_udp_feed_handler_top.sv)
- [03_stream_packet_controller.sv](03_stream_packet_controller.sv)
- [04_ethernet_parser.sv](04_ethernet_parser.sv)
- [05_ipv4_parser.sv](05_ipv4_parser.sv)
- [06_udp_parser.sv](06_udp_parser.sv)
- [07_packet_filter.sv](07_packet_filter.sv)
- [08_udp_payload_router.sv](08_udp_payload_router.sv)
- [09_market_message_decoder.sv](09_market_message_decoder.sv)
- [10_sequence_checker.sv](10_sequence_checker.sv)
- [11_statistics_counters.sv](11_statistics_counters.sv)

After the core, see the [A7-LITE board wrapper](board/a7_lite_self_test_top.sv).
