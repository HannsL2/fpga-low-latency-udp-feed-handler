# Engineering Review Checklist

- [ ] The change stays within its stated scope.
- [ ] Multi-byte network fields use big-endian byte order.
- [ ] Parser state advances only on completed input handshakes.
- [ ] Reset behavior is explicit and consistent.
- [ ] `s_last` closes packet state cleanly.
- [ ] Output data remains stable under backpressure.
- [ ] Rejected packets cannot update message or sequence state.
- [ ] Directed tests cover the changed behavior.
- [ ] The existing regression still passes.
- [ ] Simulator and Vivado warnings have been reviewed.
- [ ] Generated build directories are not committed.
- [ ] Documentation matches the observed results.
- [ ] Performance claims are backed by checked-in reports.
