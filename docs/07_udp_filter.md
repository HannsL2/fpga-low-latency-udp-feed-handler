# UDP Parser and Destination Filter

## Receive path

`udp_parser` reads the eight-byte UDP header after a supported IPv4 header. It extracts both port numbers, the UDP length and the checksum field without buffering the payload.

| Packet bytes | Field |
| --- | --- |
| 34-35 | Source port |
| 36-37 | Destination port |
| 38-39 | UDP length |
| 40-41 | UDP checksum |

All multi-byte values use big-endian network byte order. The destination port is available after byte 37, and `header_valid` pulses after byte 41 confirms that the complete header has arrived.

## Length checks

A supported datagram must satisfy both of these conditions:

- UDP length is at least eight bytes, the size of the UDP header.
- UDP length equals the IPv4 total length minus the fixed 20-byte IPv4 header.

These checks prevent a malformed length field from shifting the interpreted payload boundary. A packet that ends before byte 41 or cannot contain a complete UDP header reports `REJECT_SHORT_UDP`.

The checksum field is retained for inspection but is not included in the acceptance decision. IPv4 permits a zero UDP checksum, and checksum computation is outside the current byte-stream receive path.

## Destination filtering

`packet_filter` compares the parsed packet against three top-level parameters:

- `EXPECTED_DESTINATION_MAC`
- `EXPECTED_DESTINATION_IP`
- `EXPECTED_DESTINATION_PORT`

The comparison is combinational once `udp_header_valid` is asserted, so the result is available before the first payload byte is accepted. A matching packet produces `packet_accepted`; otherwise, `reject_valid` identifies the first mismatch in MAC, IP and port order.

The ordering gives deterministic reporting when more than one destination field differs. Header-format failures are reported by their respective parsers before the destination filter is evaluated.

## Directed verification

`tb/basic/03_tb_udp_filter.sv` covers:

- source port, destination port, length and checksum extraction
- an input-valid gap within the UDP header
- matching destination fields
- destination MAC, IPv4 address and port mismatches
- a UDP length below the minimum header size
- inconsistent IPv4 and UDP length fields
- a packet ending before the UDP header is complete

The focused test and the existing Ethernet and IPv4 directed tests pass with Vivado XSim 2026.1.
