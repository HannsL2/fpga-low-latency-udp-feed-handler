# Design Decisions

## Byte-wide input

An 8-bit stream makes the relationship between clock cycles and protocol byte positions explicit. At 125 MHz, an unstalled stream accepts one byte per cycle, corresponding to a nominal raw rate of 1 Gb/s. A wider datapath would improve throughput but would also add alignment and lane-handling logic that is not needed for this design target.

## Packet framing

The receive pipeline starts with destination-MAC byte 0 and uses `s_last` to mark the final byte. Preamble detection, frame check sequence validation and PHY signalling belong to the MAC/PHY layer and are kept outside this block.

## Fixed IPv4 header

Only IPv4 headers with IHL 5 are accepted. A fixed 20-byte header keeps the UDP offsets constant and makes result timing easier to analyse. IPv4 options and fragmented traffic are rejected explicitly.

## Cut-through field extraction

Fields are captured as their final bytes arrive. The design stores protocol fields and a small amount of flow-control state instead of buffering complete packets. This reduces storage and avoids adding a packet-length wait before processing begins.

## UDP length consistency

The UDP length must equal the IPv4 total length minus the fixed IPv4 header size. Checking the two independently supplied lengths catches malformed datagrams before payload processing begins. The UDP checksum is exposed for inspection but is not calculated by this receive path.

## Sequence state follows packet acceptance

Only complete messages that pass the protocol and destination checks may update the sequence tracker. Otherwise, malformed traffic or packets for another destination could corrupt the expected sequence number.

Sequence ordering uses modulo-2^32 subtraction and a half-range comparison. This handles natural wraparound while giving deterministic treatment to values that could otherwise be interpreted as either far ahead or far behind.

## Verification toolchain

Vivado and XSim 2026.1 are the reference tools. Reported behavior and measurements come from commands executed against the checked-in source; unavailable or unverified results are not estimated.

## Representative FPGA target

Implementation uses `xc7a35tcpg236-1`, which is available in the installed Vivado part database. It provides a consistent Artix-7 target for timing and utilisation comparisons without tying the receive pipeline to a particular development board.
