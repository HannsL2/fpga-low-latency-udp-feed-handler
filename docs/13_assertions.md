# Protocol Assertions

The simulation source `assertions/feed_handler_protocol_assertions.sv` adds continuous checks around the receive path without changing the synthesizable RTL. Vivado binds the checks to the relevant modules when a simulation is elaborated.

## Stream checks

The payload-router assertions enforce the ready/valid contract on both sides of the module:

- input data, valid and last remain stable until a stalled transfer can complete
- payload data, valid and last remain stable while the downstream interface is stalled
- `m_payload_last` is only asserted with `m_payload_valid`

## Sequence checks

The sequence-checker assertions confirm that:

- every sequence event follows a decoded message
- gap, duplicate and out-of-order classifications only accompany a sequence event
- at most one classification is active for an event
- a gap reports at least one missing message
- non-gap events report zero missing messages

## Receive-path checks

The top-level assertions confirm that:

- message acceptance and packet rejection never occur together
- every rejection carries a defined reason
- the rejection reason returns to `REJECT_NONE` when no rejection is active
- every decoded message uses the supported protocol version and message type

An assertion failure ends the simulation immediately with a specific diagnostic. The assertion source is part of the Vivado simulation fileset and is not included in synthesis.
