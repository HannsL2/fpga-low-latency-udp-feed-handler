# Protocol Reference

## Packet offsets

Packet indexing starts at the first destination-MAC byte.

| Packet bytes | Field |
| --- | --- |
| 0-5 | Destination MAC |
| 6-11 | Source MAC |
| 12-13 | EtherType, big-endian |
| 14 | IPv4 version and header length |
| 23 | IPv4 protocol |
| 30-33 | Destination IPv4 address |
| 34-35 | UDP source port |
| 36-37 | UDP destination port |
| 42 onward | UDP payload |

The supported IPv4 first byte is `8'h45`. The upper nibble selects version 4. The lower nibble gives an Internet Header Length of five 32-bit words, which is a 20-byte header.

## Message payload

Each UDP payload carries one 16-byte message:

| Offset | Field | Encoding |
| --- | --- | --- |
| 0 | Protocol version | `8'h01` |
| 1 | Message type | `8'h01` Add Order, `8'h02` Cancel Order, `8'h03` Trade, `8'h04` System Event |
| 2-5 | Sequence number | unsigned 32-bit, big-endian |
| 6-7 | Instrument ID | unsigned 16-bit, big-endian |
| 8-11 | Price | unsigned 32-bit, big-endian |
| 12-15 | Quantity | unsigned 32-bit, big-endian |

The layout is specific to this repository. It keeps the receive path compact and provides enough field variety to exercise parsing, filtering, decoding and sequence checking without depending on a proprietary or commercial feed specification.
