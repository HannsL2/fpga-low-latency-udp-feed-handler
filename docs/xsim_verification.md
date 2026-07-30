# Vivado XSim Verification

## Verification configuration

| Item | Configuration |
| --- | --- |
| Simulator | AMD Vivado XSim 2026.1 |
| HDL | SystemVerilog |
| Clock period | 8 ns |
| Design under test | `udp_feed_handler_top` and focused receive-path modules |
| Integrated directed top | `tb_feed_handler_basic` |
| UVM simulation top | `feed_handler_tb_top` |
| UVM tests | `feed_handler_smoke_test`, `feed_handler_random_test` |
| UVM library | UVM 1.2 supplied with Vivado |

The checked-in Tcl files define the project source list and selectable simulation tops. Generated Vivado project data and simulator working files are excluded from version control.

## Verification layers

| Layer | Purpose | Recorded evidence |
| --- | --- | --- |
| Focused directed tests | Isolate parser, decoder, sequence and statistics behavior | Six passing XSim tests |
| Integrated directed test | Exercise the complete receive path across accepted and rejected packets | Four packets, three accepted messages, one rejection and one sequence gap |
| Protocol assertions | Continuously enforce stream and event invariants | No assertion failures across the directed and UVM runs |
| UVM environment | Separate stimulus, monitoring, reference prediction, comparison and coverage | Deterministic smoke test and two passing 40-packet random seeds |

## Directed XSim results

| Testbench | Verified behavior | Completion time | Result |
| --- | --- | ---: | --- |
| `tb_ethernet_parser` | Ethernet fields, stalls, packet boundaries and short frames | 284 ns | Pass |
| `tb_ipv4_parser` | IPv4 extraction and supported-format validation | 2732 ns | Pass |
| `tb_udp_filter` | UDP extraction, length validation and destination filtering | 3324 ns | Pass |
| `tb_market_message_decoder` | Message decoding, supported types and payload validation | 1260 ns | Pass |
| `tb_sequence_checker` | Normal progression, gaps, duplicates, older messages and wraparound | 344 ns | Pass |
| `tb_statistics_counters` | Packet, rejection, message and sequence counters | 344 ns | Pass |
| `tb_feed_handler_basic` | Integrated acceptance, rejection, backpressure, sequencing and statistics | 2012 ns | Pass |

The integrated test transfers 48 accepted payload bytes from three messages. A fourth packet is rejected for a destination-port mismatch and does not update sequence state. The following accepted sequence produces expected sequence 3, received sequence 5 and a missing-message count of 2.

## Assertion scope

The simulation binds assertions to the payload router, sequence checker and top-level event interface. The checked properties cover:

- input and output stability while stalled
- valid/last consistency on the payload interface
- sequence-event causality and exclusive classification
- nonzero missing-message counts for forward gaps
- mutual exclusion of message acceptance and packet rejection
- valid rejection reasons
- supported protocol versions and message types

## UVM result

The five-packet UVM scenario covers all four supported message types, output backpressure, destination-port rejection, normal sequence progression and a forward gap. The reference scoreboard independently predicts payload, message, rejection and sequence results from the monitored input bytes.

The run completed at 2604 ns with:

- 13 matched scoreboard results
- 0 UVM warnings
- 0 UVM errors
- 0 UVM fatals
- 5 total packets
- 4 accepted messages
- 1 destination-port rejection
- 1 sequence gap representing 2 missing messages

The constrained-random test completed two recorded seeds with zero UVM warnings, errors or fatals:

| Seed | Completion time | Accepted | Rejected | Sequence events: gap / duplicate / older | Scoreboard matches |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 20260730 | 32284 ns | 27 | 13 | 6 / 7 / 3 | 94 |
| 20260731 | 35980 ns | 32 | 8 | 5 / 2 / 4 | 104 |

Repeating seed `20260730` through the generated Vivado project produced the same completion time, counters and scoreboard total.

## Evidence boundary

These results are behavioral simulation evidence. They do not represent post-synthesis timing, implemented resource utilisation or physical-board measurements.
