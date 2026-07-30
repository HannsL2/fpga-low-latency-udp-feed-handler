# UVM Verification Environment

## Structure

The UVM 1.2 environment uses one agent for receive-stream stimulus and observation. Output observation, result checking and functional coverage remain direct children of the environment.

```text
tb/uvm/
|-- feed_handler_if.sv
|-- feed_handler_uvm_pkg.sv
|-- feed_packet_item.svh
|-- feed_result_item.svh
|-- feed_handler_sequencer.svh
|-- feed_handler_driver.svh
|-- feed_input_monitor.svh
|-- feed_input_agent.svh
|-- feed_output_monitor.svh
|-- feed_handler_scoreboard.svh
|-- feed_handler_coverage.svh
|-- feed_handler_env.svh
|-- feed_handler_base_sequence.svh
|-- feed_handler_smoke_sequence.svh
|-- feed_handler_random_sequence.svh
|-- feed_handler_base_test.svh
|-- feed_handler_smoke_test.svh
|-- feed_handler_random_test.svh
`-- feed_handler_tb_top.sv
```

The package imports UVM and the shared feed-handler definitions, then includes the transaction, component, sequence and test classes in dependency order. The elaborated hierarchy is:

```text
feed_handler_tb_top
|-- DUT: udp_feed_handler_top
|-- feed_handler_if
`-- run_test()
    `-- selected feed-handler test
        `-- env: feed_handler_env
            |-- input_agent: feed_input_agent
            |   |-- sequencer: feed_handler_sequencer
            |   |-- driver: feed_handler_driver
            |   `-- monitor: feed_input_monitor
            |-- output_monitor: feed_output_monitor
            |-- scoreboard: feed_handler_scoreboard
            `-- coverage: feed_handler_coverage
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

## Constrained-random regression

`feed_handler_random_test` generates 40 packets per seed. Weighted constraints vary:

- all supported message types
- accepted destinations and MAC, IPv4 or UDP-port mismatches
- normal, gap, duplicate and older sequence numbers
- zero to two idle cycles between input bytes
- zero to four cycles of payload backpressure
- instrument, price and quantity fields

The test requires at least one gap, duplicate and older sequence event. It also checks total, accepted, rejected, valid-message and destination-mismatch counter relationships at the end of every run.

| Seed | Accepted | Rejected | Gaps | Duplicates | Older | Scoreboard matches | Result |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 20260730 | 27 | 13 | 6 | 7 | 3 | 94 | Pass |
| 20260731 | 32 | 8 | 5 | 2 | 4 | 104 | Pass |

## Recorded XSim baseline

The deterministic smoke regression completed at 2604 ns. The scoreboard matched 13 payload, message, rejection and sequence results. The UVM report contained zero warnings, errors and fatals.

Both recorded constrained-random seeds completed with zero UVM warnings, errors and fatals. A repeated project-mode run of seed `20260730` reproduced the same completion time, counters and scoreboard total. The smoke and random tests share `feed_handler_tb_top`; test selection does not introduce another HDL wrapper or a second UVM environment.
