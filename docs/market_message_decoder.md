# Payload Path and Market-Message Decoder

## Selected payload stream

`udp_payload_router` forwards payload bytes only after the Ethernet, IPv4 and UDP headers match the configured destination. A one-byte holding register decouples the packet input from `m_payload_ready`.

When the output is stalled, `m_payload_data` and `m_payload_last` remain stable and the input stream is backpressured before another selected payload byte is accepted. Header bytes and rejected packets do not use the payload register.

The UDP length determines the final payload byte. Ethernet padding after the UDP datagram is therefore not forwarded.

## Message layout

`market_message_decoder` consumes the selected payload as it transfers through the router. It extracts the 16-byte project message in big-endian order:

| Payload bytes | Field |
| --- | --- |
| 0 | Protocol version |
| 1 | Message type |
| 2-5 | Sequence number |
| 6-7 | Instrument ID |
| 8-11 | Price |
| 12-15 | Quantity |

`message_valid` pulses with the completed fields after payload byte 15. Add Order, Cancel Order, Trade and System Event share this fixed layout.

## Validation

The decoder reports separate reasons for an unsupported protocol version, unsupported message type, truncated payload and payloads longer than the 16-byte message. A rejected message does not assert `message_valid`.

Network-header selection and message acceptance are distinct decisions. Payload forwarding begins after the destination fields are validated; message validity is known when the complete message has arrived. This preserves cut-through operation without buffering the full packet.

## Verification

The directed tests cover all four supported message types, big-endian field extraction, valid gaps, short and long payloads, unsupported values, payload ordering, `m_payload_last` and output backpressure. The complete Ethernet/IPv4/UDP packet test and all parser regressions pass with Vivado XSim 2026.1.
