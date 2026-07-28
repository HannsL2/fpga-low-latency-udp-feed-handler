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

### Opening the design in Vivado

Run the following commands from the repository root in a shell where `vivado` is available:

```powershell
vivado -mode batch -nojournal -nolog -source scripts/create_vivado_project.tcl
vivado build/vivado/feed_handler.xpr
```

The project includes the directed Ethernet, IPv4 and UDP/filter tests as simulation sources. A focused test can also be run without opening the graphical interface:

```powershell
vivado -mode batch -nojournal -nolog -source scripts/run_directed_simulation.tcl -tclargs tb_udp_filter
```

Generated project and simulation data remain under `build/` and are not tracked by Git.

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

## Current status

The checked-in receive path includes packet control, Ethernet and fixed-header IPv4 parsing, UDP header extraction and configurable destination filtering. Directed XSim tests cover field extraction, valid gaps, packet boundaries, truncated headers, unsupported IPv4 formats, UDP length checks and destination mismatches.

See [the design specification](docs/project_specification.md), [architecture notes](docs/architecture.md), [Ethernet parser notes](docs/ethernet_parser.md), [IPv4 parser notes](docs/ipv4_parser.md), [UDP/filter notes](docs/udp_filter.md) and [protocol reference](docs/protocol.md) for the detailed interface and byte layout.
