# Low-Latency FPGA UDP Feed Handler

This project develops a cut-through SystemVerilog receive pipeline for Ethernet II, IPv4 and UDP traffic. The design accepts an 8-bit packet stream, filters traffic by destination, decodes a compact market-data message and checks message sequence continuity.

The main design target is predictable packet-processing latency while sustaining one input byte per clock at 125 MHz.

## Design overview

The receive path is organised around the order in which fields arrive on the wire:

```text
Byte stream -> Ethernet -> IPv4 -> UDP -> destination filter
                                              |
                                              +-> payload output
                                              +-> message decoder -> sequence checker
```

Header fields are captured as soon as their final byte arrives. This avoids buffering a complete packet before processing begins and keeps the latency tied to fixed byte positions.

The design uses one clock domain and a ready/valid interface throughout. Input state advances only after a completed handshake, and output data is held stable while backpressured.

## Packet format

The supported receive format is intentionally focused:

- Ethernet II frames without VLAN tags
- IPv4 with a 20-byte header and no fragmentation
- UDP with one fixed-format message in the payload
- big-endian network byte order
- configurable destination MAC address, IPv4 address and UDP port
- input-valid gaps, back-to-back packets and output backpressure

The testbench starts at the first destination-MAC byte and provides `s_last` with the final packet byte. Ethernet preamble, frame check sequence and PHY signalling sit outside the receive pipeline.

## Message format

Each UDP payload contains one 16-byte project-specific message:

| Payload bytes | Field | Width |
| --- | --- | --- |
| 0 | Protocol version | 8 bits |
| 1 | Message type | 8 bits |
| 2-5 | Sequence number | 32 bits |
| 6-7 | Instrument ID | 16 bits |
| 8-11 | Price | 32 bits |
| 12-15 | Quantity | 32 bits |

Protocol version `0x01` defines Add Order (`0x01`), Cancel Order (`0x02`), Trade (`0x03`) and System Event (`0x04`) messages. The format is purpose-built for this design and does not reproduce a commercial exchange protocol.

## Sequence checking

Accepted messages establish and update the expected sequence number. The checker distinguishes normal progression, forward gaps, duplicates and out-of-order messages. Rejected or malformed packets do not affect sequence state.

## Verification and implementation

AMD Vivado and Vivado XSim 2026.1 are the reference tools. Verification is built around:

- directed SystemVerilog tests for fast RTL bring-up
- UVM 1.2 sequences, monitors, reference modelling and scoreboard checks
- assertions for ready/valid and packet-processing rules
- functional coverage for packet types, rejection reasons and sequence events
- cycle-based latency and throughput measurements

The representative implementation target is the Artix-7 `xc7a35tcpg236-1` with an 8 ns clock constraint. Timing, utilisation and latency figures will be added only after they have been produced by the checked-in Vivado flow.

### Simulation evidence

Vivado XSim 2026.1 is the reference simulator. Checked-in Tcl captures the source files and simulation-top selection, while generated project and simulator data remain outside version control. The [XSim verification record](docs/xsim_verification.md) reports the executed tests, assertion scope, UVM scoreboard result and evidence boundary.

## Repository structure

| Path | Purpose |
| --- | --- |
| `rtl/` | Synthesizable SystemVerilog |
| `tb/basic/` | Directed RTL tests |
| `tb/uvm/` | UVM verification environment |
| `assertions/` | Interface and design properties |
| `constraints/` | Timing constraints |
| `scripts/` | Vivado and XSim automation |
| `docs/` | Design, protocol and verification notes |
| `reports/` | Selected simulation and implementation results |
| `waveforms/` | Waveform configurations and review evidence |

## Implemented capabilities

- cut-through Ethernet II, fixed-header IPv4 and UDP parsing
- configurable destination MAC, IPv4 address and UDP port filtering
- backpressure-safe UDP payload forwarding
- fixed-format market-message decoding
- sequence progression, gap, duplicate and out-of-order classification
- event-driven packet, rejection, message and sequence statistics

## Verification

Seven directed XSim tests cover individual blocks and an integrated four-packet scenario with acceptance, rejection, output backpressure, sequence progression, a forward gap and final counter checks. Bound protocol assertions continuously check stream stability, event consistency and sequence classification during simulation.

The UVM 1.2 environment adds reusable packet transactions, a handshake-aware driver, passive input and output monitors, an independent packet and sequence model, a scoreboard and functional coverage. A deterministic smoke scenario exercises all supported message types, while a 40-packet constrained-random regression varies message fields, destination outcomes, sequence classifications, input gaps and output backpressure.

See [the design specification](docs/project_specification.md), [architecture notes](docs/architecture.md), [directed-verification notes](docs/directed_verification.md), [UVM verification notes](docs/uvm_verification.md), [protocol-assertion notes](docs/assertions.md), [Ethernet parser notes](docs/ethernet_parser.md), [IPv4 parser notes](docs/ipv4_parser.md), [UDP/filter notes](docs/udp_filter.md), [message-decoder notes](docs/market_message_decoder.md), [sequence-checker notes](docs/sequence_checker.md), [statistics notes](docs/statistics.md) and [protocol reference](docs/protocol.md) for detailed design information.
