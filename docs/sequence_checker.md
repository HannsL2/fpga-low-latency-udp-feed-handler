# Sequence Checker

## Purpose

`sequence_checker` tracks the sequence number of accepted market messages. Its state changes only when `message_valid` is asserted, so malformed packets and traffic rejected by the destination filter cannot disturb the configured feed.

The first accepted message establishes the reference sequence. Each accepted message produces a one-cycle `sequence_event_valid` pulse; the classification flags remain clear for initialization and normal progression.

## Classification

For each message after initialization, the expected value is the previous accepted sequence plus one:

- A message carrying the expected value advances normally.
- A greater forward value reports a gap and the number of missing messages.
- A value equal to the previous accepted sequence reports a duplicate.
- An older value reports out of order and does not move the reference sequence backwards.

Gap and normal events advance the stored reference. Duplicate and out-of-order events leave it unchanged.

## Wraparound

Sequence arithmetic is modulo 2^32. The expected value after `32'hFFFF_FFFF` is `32'h0000_0000`, and gaps may cross this boundary.

Ordering uses the modular distance from the expected value. A distance below 2^31 is treated as forward; a distance of 2^31 or more is treated as old or ambiguous. This half-range rule provides deterministic behavior without extending the protocol with an epoch counter.

## Verification

`tb/basic/tb_sequence_checker.sv` covers initialization, normal progression, forward gaps, missing-message counts, duplicates, older messages, ignored cycles without `message_valid`, reset and 32-bit wraparound. The focused test and the complete existing directed regression pass with Vivado XSim 2026.1.
