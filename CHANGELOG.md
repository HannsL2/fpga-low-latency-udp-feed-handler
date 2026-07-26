# Changelog

## Unreleased

- Established the repository layout and Vivado/XSim tool flow.
- Defined the streaming interface, packet format and receive-path architecture.
- Added the shared SystemVerilog package and top-level interface.
- Added the first directed Ethernet/IPv4/UDP packet test.
- Added handshake-aware packet indexing and Ethernet field extraction.
- Added directed checks for stalls, packet boundaries and truncated headers.
- Added fixed-header IPv4 parsing and address extraction.
- Added IPv4 rejection checks for version, header length, fragmentation, protocol and short headers.
