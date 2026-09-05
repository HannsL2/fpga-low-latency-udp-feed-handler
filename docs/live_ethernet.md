# Live Ethernet receive path

The A7-LITE hardware image extends the verified byte-stream core to the
board's RTL8211E-VB Gigabit Ethernet PHY. It is a receive-only demonstration:
a raw Ethernet/IPv4/UDP frame enters through RJ45, is decoded by the existing
feed-handler pipeline, and produces one readable line on the board's USB-UART
connection.

## Implemented path

```text
RTL8211E RGMII RX
    -> DDR nibble capture
    -> preamble/SFD recognition
    -> FCS removal
    -> udp_feed_handler_top
    -> message clock-domain crossing
    -> 115200-8-N-1 UART output
```

`rgmii_rx` uses Artix-7 IDDR registers to capture four data bits and RX control
on both edges of the 125 MHz receive clock. The rising-edge nibble becomes the
low half of each Ethernet byte and the falling-edge nibble becomes the high
half. `ethernet_frame_deframer` then identifies seven `55` preamble bytes and
the `D5` start-of-frame delimiter. A five-byte tail allows it to assert the
stream's final-byte marker while withholding the four-byte Ethernet FCS.

The resulting frame begins at the destination MAC address, matching the input
contract of `udp_feed_handler_top`. Accepted 16-byte messages cross from the
recovered receive clock to the board's 50 MHz clock through a request/
acknowledge handshake. The UART formatter holds that handshake until it can
accept the message, preventing a completed decode from being silently consumed
while the previous text line is still transmitting.

The emitted line has this form:

```text
MSG type=01 seq=0000002A inst=1234 price=0001E240 qty=000003E8
```

## Board integration

The physical target is the MicroPhase A7-LITE ES1 with the
`xc7a35tfgg484-2` Artix-7 and RTL8211E-VB PHY. The board straps the PHY for
RGMII operation without its internal receive-clock delay. An MMCM therefore
shifts the recovered clock by 2.5 ns before the input DDR registers. Static
timing uses the PHY's specified -0.5 ns to +0.5 ns transmit skew.

The PCB routes PHY RXCK to package pin H18, which is not a clock-capable input
on this Artix-7 package. The constraints contain a narrow
`CLOCK_DEDICATED_ROUTE FALSE` exception for that fixed PCB connection. The
post-route result meets all declared constraints, but this board-specific
clock route makes physical packet testing particularly important.

The receive-only image supplies the PHY with a free-running 125 MHz RGMII
transmit clock and holds transmit data/control inactive. MDIO configuration,
Ethernet transmission, ARP, IP-stack behaviour, FCS validation, and dynamic
10/100 Mb/s clock selection are outside this stage. The connected adapter must
therefore negotiate a Gigabit link, and the host sends a raw Layer-2 frame to
the fixed project destination rather than relying on ARP.

## Verification and implementation evidence

The directed PHY-path simulation drives RGMII nibbles on both clock edges,
including the preamble, SFD and four FCS bytes. It checks every frame byte
delivered to the existing core and verifies the decoded sequence, instrument,
price, quantity and final statistics. A separate UART simulation reconstructs
each serial byte and checks the complete output line, including 8-N-1 framing
and CR/LF termination.

Vivado 2026.1 synthesis and implementation for the complete live image report:

| Result | Value |
| --- | ---: |
| RGMII receive clock | 125 MHz |
| Post-route setup slack | +0.096 ns |
| Post-route hold slack | +0.078 ns |
| Slice LUTs | 613 / 20,800 (2.95%) |
| Slice registers | 1,060 / 41,600 (2.55%) |
| Input DDR registers | 5 |
| MMCMs | 2 |

The generated image is
`reports/a7_lite_ethernet/a7_lite_ethernet.bit`. These figures establish
simulation and static-timing completion. Live RJ45-to-UART behaviour remains
pending until it is exercised on a working board; it is not presented as a
completed hardware result.

## Host stimulus

`tools/send_market_packet.py` builds the project's 16-byte big-endian message
and transmits it as a raw Ethernet/IPv4/UDP frame through Scapy/Npcap. The
PowerShell entry point is `tools/send_market_packet.ps1`. It targets:

| Field | Value |
| --- | --- |
| Destination MAC | `02:00:00:00:00:01` |
| Destination IPv4 | `192.168.1.100` |
| Destination UDP port | `18000` |

The host utility and the UART terminal are deliberately kept outside the RTL
data path. They provide observable stimulus and results without embedding a
processor or software stack in the FPGA image. Its Windows dependencies are
Python 3, Npcap and the Scapy version range recorded in
`tools/requirements.txt`.
