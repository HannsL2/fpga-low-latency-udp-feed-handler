# Statistics Counters

## Counter events

`statistics_counters` records packet, message, rejection and sequence events produced by the receive path. Each counter is 32 bits and wraps naturally after `32'hFFFF_FFFF`.

| Counter | Increment condition |
| --- | --- |
| Total packets | A transferred byte asserts `s_last` |
| Accepted packets | A complete validated message asserts `message_valid` |
| Rejected packets | The receive path asserts `reject_valid` |
| Valid messages | A complete validated message asserts `message_valid` |
| Sequence gaps | A sequence event reports a gap |
| Missing-message total | Adds the missing count reported with each gap |
| Duplicates | A sequence event reports a duplicate |
| Out of order | A sequence event reports an older message |

One project message is carried per UDP packet, so `message_valid` is also the final packet-acceptance event. Packet completion can occur before message and rejection events propagate through the registered decoder; software or a testbench should sample the counters after the receive pipeline has settled.

## Rejection categories

Dedicated counters record unsupported EtherType, non-UDP traffic and destination MAC, IPv4 address and UDP port mismatches. Other rejection reasons contribute to `malformed_packet_count`, including truncated headers, unsupported IPv4 formats, fragmented traffic and invalid message payloads.

The parser and decoder hierarchy produces at most one reject event for a packet. This allows `rejected_packet_count` and the corresponding category counter to increment from the same event without maintaining a second packet-history table.

## Verification

`tb/basic/tb_statistics_counters.sv` checks primary totals, every dedicated rejection category, malformed traffic, valid messages and all sequence statistics. The integrated packet test checks that one accepted packet produces exactly one completed-packet count, one accepted count and one valid-message count, with no error counters. All directed XSim tests pass with no compile or elaboration warnings.
