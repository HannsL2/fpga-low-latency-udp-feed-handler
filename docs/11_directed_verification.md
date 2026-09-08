# Directed Verification

## Integrated packet scenario

`tb/basic/07_tb_feed_handler_basic.sv` provides a readable end-to-end check of the complete RTL receive path. It sends four Ethernet/IPv4/UDP packets in this order:

1. An accepted Add Order with sequence 1.
2. An accepted Add Order with sequence 2.
3. A packet rejected because its destination port does not match.
4. An accepted Add Order with sequence 5, producing a two-message gap.

The test applies output backpressure during the first accepted payload and checks that the output byte and final-byte indication remain stable while stalled.

## Checked results

The test independently checks:

- all 48 payload bytes from the three accepted packets
- one `m_payload_last` transfer per accepted packet
- three decoded messages and one rejection
- decoded fields from the final accepted message
- expected sequence 3, received sequence 5 and two missing messages
- four completed packets, three accepted packets and one rejected packet
- one destination-port mismatch and one sequence-gap event
- zero unexpected malformed, protocol, destination or ordering counters

The focused Ethernet, IPv4, UDP/filter, message-decoder, sequence-checker and statistics tests run alongside the integrated scenario, latency measurement and A7-LITE validation image. All nine directed tests pass with Vivado XSim 2026.1.

## Scope

The directed suite provides deterministic RTL checks and cycle-level timing measurements. The separate UVM environment adds constrained-random stimulus, independent reference modelling, functional coverage and reproducible seeds; bound assertions run across both verification layers.
