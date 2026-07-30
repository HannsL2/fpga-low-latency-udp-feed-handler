# UVM Verification Environment

## Structure

The UVM 1.2 environment is connected to the same byte-stream interface used by the directed tests.

```text
packet sequence -> sequencer -> driver -> DUT
                                     |
input monitor -> reference model -> scoreboard <- output monitor
                                             |
                                      functional coverage
```

`feed_packet_item` carries a complete Ethernet frame together with constrained input-gap, inter-packet-idle and payload-stall controls. The driver applies reset, obeys the input ready/valid handshake and can apply output backpressure while a payload is active.

The input monitor reconstructs packets only from completed transfers. The output monitor independently records accepted payloads, decoded messages, rejection events and sequence results.

## Reference scoreboard

The scoreboard parses the monitored packet bytes independently of the RTL. It checks:

- Ethernet, IPv4 and UDP destination fields
- protocol version and supported message type
- every accepted payload byte
- decoded sequence, instrument, price and quantity fields
- rejection reason
- expected and received sequence numbers
- normal, gap, duplicate and out-of-order classifications
- missing-message count

Expected and observed results are queued independently, so an early header rejection can be matched after the input monitor receives the final packet byte. Rejected traffic does not update the scoreboard's sequence state.

## Smoke scenario

`feed_handler_smoke_test` sends five packets:

1. Add Order, sequence 1.
2. Cancel Order, sequence 2, with payload backpressure.
3. Trade, sequence 3, rejected by the destination-port filter.
4. Trade, sequence 5, producing a two-message gap from expected sequence 3.
5. System Event, sequence 6.

This exercises all four supported message types, destination-port rejection, output backpressure, normal sequence progression and a forward gap. The scoreboard compares 13 payload, message, rejection and sequence results. The test also checks the final packet, acceptance, rejection, message, gap and missing-message counters.

Functional coverage samples result kind, supported message type, rejection reason and sequence classification.

## Recorded XSim result

The `tb_feed_handler_uvm` run completed at 2604 ns. The scoreboard matched 13 payload, message, rejection and sequence results. The UVM report contained zero warnings, errors and fatals.
