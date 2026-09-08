# Ethernet Parser

## Purpose

The Ethernet receive logic comprises two small blocks:

- `stream_packet_controller` defines accepted transfers, packet boundaries and the packet-relative byte index.
- `ethernet_parser` uses that index to recover destination MAC, source MAC and EtherType fields.

Keeping transfer control separate from field extraction gives every parser the same view of packet position and prevents each block from maintaining its own byte counter.

## Packet controller

`transfer` is asserted only when `s_valid`, `s_ready` and `!reset` are all true. The current `byte_index` identifies the byte being transferred on that cycle.

`packet_start` accompanies byte 0. `packet_end` accompanies the accepted byte carrying `s_last`. After `packet_end`, `packet_active` clears and `byte_index` returns to zero for the next frame.

When the input is stalled, the controller retains both values. No parser state advances until the pending byte is accepted.

## Field extraction

| Byte index | Captured field |
| --- | --- |
| 0-5 | Destination MAC |
| 6-11 | Source MAC |
| 12 | EtherType bits 15:8 |
| 13 | EtherType bits 7:0 |

`header_valid` pulses when byte 13 is accepted. At that point all three fields contain the complete big-endian values.

If `s_last` arrives before byte 13, `short_frame` pulses instead. The partially captured fields are not presented as a valid Ethernet header.

## Timing

Field registers update on the same rising edge that accepts their corresponding bytes. `header_valid` is therefore available immediately after the edge accepting byte 13. The parser adds no separate buffering stage.

## Reset behaviour

Reset clears the packet controller, captured fields and event outputs. The top level deasserts `s_ready` while reset is active, so the source cannot complete an input transfer during reset.

## Directed verification

`tb/basic/01_tb_ethernet_parser.sv` checks:

- destination and source MAC byte order
- EtherType byte order
- a three-cycle stall within the destination MAC
- packet start and end event counts
- byte-index reset after `s_last`
- rejection of a ten-byte truncated header

The focused test passes with Vivado XSim 2026.1.
