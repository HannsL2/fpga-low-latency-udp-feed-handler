# Vivado XSim Simulation Guide

## Create and open the project

From the repository root, create the Vivado project from the checked-in source list:

```powershell
vivado -mode batch -nojournal -nolog -source scripts/create_vivado_project.tcl
```

Open `build/vivado/feed_handler.xpr` in Vivado. The generated project contains the synthesizable RTL, protocol assertions and all directed testbenches.

## Run a test in the graphical interface

1. In the Sources window, select **Simulation Sources**.
2. Right-click the required testbench and choose **Set as Top**. Use `tb_feed_handler_basic` for the integrated receive-path test.
3. In the Flow Navigator, select **Run Simulation**, then **Run Behavioral Simulation**.
4. When XSim opens, select **Run All**. The directed testbench ends the run with `$finish`.
5. Check the Tcl Console for the test's `PASS` message. An assertion or testbench failure stops the run with a diagnostic identifying the violated rule.

A focused test can also be run in batch mode:

```powershell
vivado -mode batch -nojournal -nolog -source scripts/run_directed_simulation.tcl -tclargs tb_udp_filter
```

## Recommended waveform signals

Start with the top-level testbench signals, then expand `dut` in the Scopes window when internal parser events are needed.

| Area | Signals | What to check |
| --- | --- | --- |
| Clock and reset | `clk`, `reset` | Outputs and parser state return to their reset values. |
| Input stream | `s_data`, `s_valid`, `s_ready`, `s_last` | A byte advances only when valid and ready are both high. Data and last remain stable during a stall. |
| Packet position | `dut.packet_byte_index`, `dut.packet_start`, `dut.packet_end` | The index advances once per completed input transfer and resets between frames. |
| Header parsing | `dut.ethernet_header_valid`, `dut.ipv4_header_valid`, `dut.udp_header_valid` | Each valid pulse follows the final required header byte. |
| Filtering | `dut.filter_decision_valid`, `dut.filter_packet_accepted`, `reject_valid`, `reject_reason` | Only matching packets reach the payload and decoder paths. |
| Payload output | `m_payload_data`, `m_payload_valid`, `m_payload_ready`, `m_payload_last` | Output data remains stable while ready is low, and last accompanies the final accepted payload byte. |
| Message output | `message_valid`, `message_type`, `sequence_number`, `instrument_id`, `price`, `quantity` | Fields are valid when `message_valid` pulses. |
| Sequence result | `sequence_event_valid`, `expected_sequence`, `received_sequence`, `sequence_gap`, `sequence_duplicate`, `sequence_out_of_order`, `missing_message_count` | Classification and missing-message count agree with the accepted sequence stream. |
| Statistics | packet, rejection, message and sequence counters | Counters increment once for their corresponding event. |

## Packet byte landmarks

The integrated testbench starts at the first destination-MAC byte:

- destination MAC: bytes 0-5
- EtherType: bytes 12-13
- IPv4 version and IHL: byte 14
- destination IPv4 address: bytes 30-33
- UDP destination port: bytes 36-37
- UDP payload: byte 42 onward
- message sequence number: packet bytes 44-47

Display packet data and decoded fields in hexadecimal. Use waveform cursors around valid/ready handshakes and event pulses; this makes off-by-one byte errors and incorrect pipeline timing easier to identify.

Waveforms are primarily a debugging aid. The testbench comparisons and bound assertions determine whether a simulation passes, while the waveform explains where and when a failure occurred.
