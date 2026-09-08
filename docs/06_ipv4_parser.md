# IPv4 Parser

## Purpose

`ipv4_parser` processes the fixed 20-byte IPv4 header that follows an Ethernet II header. It extracts the fields needed by the UDP path and rejects packet formats that would change header offsets or require reassembly.

The parser starts only after `ethernet_parser` reports a complete header with EtherType `16'h0800`.

## Captured fields

| Packet bytes | Field |
| --- | --- |
| 14 | Version and Internet Header Length |
| 16-17 | Total length |
| 20-21 | Flags and fragment offset |
| 23 | Protocol |
| 26-29 | Source IPv4 address |
| 30-33 | Destination IPv4 address |

All multi-byte fields are assembled in big-endian network order. `header_valid` pulses after byte 33 is accepted and all checks have passed.

## Validation

The supported header requires:

- EtherType `16'h0800`
- IPv4 version 4
- Internet Header Length 5, corresponding to 20 bytes
- total length of at least 20 bytes
- reserved fragmentation flag clear
- More Fragments flag clear
- fragment offset zero
- protocol `8'h11` for UDP
- packet data present through byte 33

The Don't Fragment flag is permitted because it does not require reassembly. IPv4 options and fragmented traffic are rejected before the UDP header is reached.

Header checksum validation is not part of this receive path. The parser consumes the checksum bytes but does not use them in the acceptance decision.

## Event behaviour

`reject_valid` pulses when a failure can be identified. `reject_reason` distinguishes EtherType, version, header length, fragmentation, non-UDP protocol and short-header failures.

After an early rejection, the parser stops updating IPv4 fields for the remainder of that frame. The packet controller continues to consume bytes through `s_last`, allowing the next packet to begin from a clean byte index.

## Timing

Version and header length are checked with byte 14. Fragmentation is known after byte 21, protocol after byte 23 and destination address after byte 33. A supported header therefore becomes valid immediately after the rising edge that accepts byte 33.

## Directed verification

`tb/basic/02_tb_ipv4_parser.sv` covers:

- supported IPv4/UDP header extraction
- source and destination address byte order
- non-IPv4 EtherType
- incorrect version
- variable header length
- invalid total length
- More Fragments and reserved fragmentation flags
- acceptance of the Don't Fragment flag
- non-UDP protocol
- a packet ending before the IPv4 header is complete

The focused test passes with Vivado XSim 2026.1.
