#!/usr/bin/env python3
"""Send one project-format market-data frame through a selected Ethernet NIC."""

import argparse
import struct

from scapy.all import Ether, IP, Raw, UDP, get_if_list, sendp


DESTINATION_MAC = "02:00:00:00:00:01"
DESTINATION_IP = "192.168.1.100"
DESTINATION_PORT = 18000


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Transmit one raw Ethernet/IPv4/UDP market-data frame."
    )
    parser.add_argument("--interface", help="Scapy/Npcap interface name")
    parser.add_argument("--list-interfaces", action="store_true")
    parser.add_argument("--sequence", type=int, default=1)
    parser.add_argument("--instrument", type=int, default=0x1234)
    parser.add_argument("--price", type=int, default=12345)
    parser.add_argument("--quantity", type=int, default=100)
    parser.add_argument("--message-type", type=int, default=1)
    return parser.parse_args()


def checked_unsigned(name: str, value: int, bits: int) -> int:
    if not 0 <= value < (1 << bits):
        raise ValueError(f"{name} must fit in {bits} unsigned bits")
    return value


def main() -> None:
    arguments = parse_arguments()
    if arguments.list_interfaces:
        print("\n".join(get_if_list()))
        return
    if not arguments.interface:
        raise SystemExit("--interface is required (use --list-interfaces first)")

    message_type = checked_unsigned("message type", arguments.message_type, 8)
    sequence = checked_unsigned("sequence", arguments.sequence, 32)
    instrument = checked_unsigned("instrument", arguments.instrument, 16)
    price = checked_unsigned("price", arguments.price, 32)
    quantity = checked_unsigned("quantity", arguments.quantity, 32)

    payload = struct.pack(
        "!BBIHII", 1, message_type, sequence, instrument, price, quantity
    )
    packet = (
        Ether(dst=DESTINATION_MAC)
        / IP(src="192.168.1.1", dst=DESTINATION_IP)
        / UDP(sport=10000, dport=DESTINATION_PORT)
        / Raw(payload)
    )
    sendp(packet, iface=arguments.interface, count=1, verbose=False)
    print(
        f"sent sequence={sequence} instrument=0x{instrument:04X} "
        f"price={price} quantity={quantity}"
    )


if __name__ == "__main__":
    main()
