# Changelog

## Unreleased

## 1.0.0 - 2026-09-04

- Established the repository layout and Vivado/XSim tool flow.
- Defined the streaming interface, packet format and receive-path architecture.
- Added the shared SystemVerilog package and top-level interface.
- Added the first directed Ethernet/IPv4/UDP packet test.
- Added handshake-aware packet indexing and Ethernet field extraction.
- Added directed checks for stalls, packet boundaries and truncated headers.
- Added fixed-header IPv4 parsing and address extraction.
- Added IPv4 rejection checks for version, header length, fragmentation, protocol and short headers.
- Added UDP port, length and checksum extraction.
- Added UDP length consistency checks and truncated-header detection.
- Added configurable destination MAC, IPv4 address and UDP port filtering.
- Added a reproducible Vivado project and focused simulation runner.
- Added cut-through payload forwarding with output backpressure.
- Added fixed-format market-message decoding for all four supported message types.
- Added protocol, type and payload-length validation.
- Added sequence initialization, progression and anomaly classification.
- Added gap counts, duplicate detection, out-of-order detection and wraparound handling.
- Added wrapping packet, rejection, message and sequence statistics.
- Added dedicated counters for protocol and destination-filter rejection categories.
- Expanded the integrated directed test to cover acceptance, rejection, sequence gaps and final statistics.
- Added end-to-end payload ordering and backpressure-stability checks.
- Added bound protocol assertions for stream handshakes, receive events and sequence classifications.
- Added the assertion source to the generated Vivado simulation fileset.
- Reworked the README around stable implemented capabilities and verification results.
- Added a Vivado XSim verification record covering directed tests, assertions and evidence boundaries.
- Added a UVM 1.2 packet driver, passive monitors, reference scoreboard and functional coverage.
- Added a five-packet UVM smoke scenario covering all message types, rejection, backpressure and sequence gaps.
- Added the UVM testbench to the generated Vivado project and selectable simulation tops.
- Added a 40-packet constrained-random UVM regression with reproducible seed results.
- Added weighted destination, sequence, timing and message-field randomization.
- Refactored the UVM environment into modular class files with a named sequencer and input agent.
- Added the MicroPhase A7-LITE ES1 target, board constraints and 50-to-125 MHz clock generation.
- Added a deterministic on-board packet replay with latched pass/fail LED results.
- Added cycle-accurate latency verification at 125 MHz.
- Added warning-clean synthesis, implementation, timing and utilisation evidence for XC7A35T FGG484.
- Added a single-command Vivado regression covering nine directed runs, the UVM smoke test and two reproducible random seeds.
- Isolated generated XSim state and assertion scope between regression test tops.
- Validated the implemented self-test on the physical A7-LITE XC7A35T through JTAG and recorded the pass indication.
