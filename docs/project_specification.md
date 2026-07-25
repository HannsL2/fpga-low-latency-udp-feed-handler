# Design Specification

## Purpose

The feed handler receives Ethernet II, IPv4 and UDP packets over an 8-bit streaming interface. It selects traffic for a configured destination, forwards accepted UDP payload bytes, decodes one fixed-format message and reports sequence continuity and packet statistics.

## Input interface

The first transferred byte is the first byte of the destination MAC address. `s_last` is asserted with the final packet byte. A byte transfers only when `s_valid && s_ready`; parser state must not advance in any other cycle.

The source must hold `s_data` and `s_last` stable while stalled. The same rule applies to the payload output: data and `m_payload_last` remain stable while `m_payload_valid` is high and `m_payload_ready` is low.

## Supported traffic

- Ethernet II with EtherType `16'h0800`
- IPv4 version 4 with Internet Header Length 5
- no IPv4 options or fragmentation
- UDP protocol value `8'h11`
- one 16-byte message per UDP payload
- big-endian multi-byte fields
- input-valid gaps and back-to-back packets
- output backpressure

Frames outside this format are consumed safely and reported with a reject reason.

## Destination filtering

Three configurable values identify the receive feed:

- destination MAC address
- destination IPv4 address
- UDP destination port

The filter decision is made as soon as the final comparison field is available. A packet is accepted only after the required headers and message fields have passed validation.

## Message decoding

The decoder extracts protocol version, message type, sequence number, instrument ID, price and quantity. One-cycle validity pulses report decoded messages and sequence events.

## Sequence handling

The first accepted message initializes the sequence tracker. Subsequent messages are classified as expected, gap, duplicate or out of order. Forward gaps also report the number of missing messages.

Sequence state changes only for accepted messages. This keeps malformed packets and traffic for other destinations from disturbing the configured feed.

## Performance requirements

- one clock domain
- 125 MHz target frequency
- 8 ns clock period
- one input byte per clock when unstalled
- cut-through field extraction
- deterministic result timing for identical valid input conditions

Latency is measured from both the first packet byte and the final required message byte. Throughput and latency are reported separately.

## Verification requirements

Directed XSim tests cover fast RTL bring-up. The UVM 1.2 environment provides constrained packet generation, independent monitoring, reference modelling, scoreboard comparisons, functional coverage and reproducible random seeds. Assertions check the ready/valid contract and key packet-processing rules.

## Implementation target

Vivado synthesis and implementation use `xc7a35tcpg236-1` as a representative Artix-7 target. The project reports simulated, synthesized, implemented and physically tested results separately; the representative part does not imply board-level testing.

## Design boundary

The repository covers the receive-side packet-processing pipeline. Ethernet MAC/PHY functions, preamble and FCS handling, ARP, TCP, IPv6, IP reassembly, PCIe, DMA and physical board I/O are outside this boundary.
