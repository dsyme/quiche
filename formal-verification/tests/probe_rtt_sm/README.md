# Route-B Test: T60 — BBR2 ProbeRTT State Machine

🔬 Lean Squad correspondence test for `FVSquad/ProbeRTTStateMachine.lean`.

## What is tested

The Lean model defines two transition functions:

- `congestionStep (state eventTime inflight target duration)` — models
  `ProbeRTT::on_congestion_event`'s exit_time state machine (stripped of
  cwnd/pacing updates and mode transitions).
- `quiescenceStep (state now)` — models `ProbeRTT::on_exit_quiescence`'s
  exit_time transition.

Both functions operate on a two-constructor state type:

| State | Meaning |
|-------|---------|
| `Draining` | `exit_time = None`; inflight has not yet reached the target |
| `Waiting(t)` | `exit_time = Some(t)`; timer expires when `event_time > t` |

This test re-implements both functions in Rust (using `u64` for times, exactly
as the Lean model uses `Nat`) and compares them against an oracle that directly
re-implements the Rust source logic from
`quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs`.

### Branches exercised

| Case | `congestionStep` | `quiescenceStep` |
|------|------------------|------------------|
| Draining, inflight > target | stays Draining | — |
| Draining, inflight ≤ target | enters Waiting(event+dur) | always exits |
| Waiting, event_time > exit_time | exits ProbeRTT | exits ProbeRTT |
| Waiting, event_time ≤ exit_time | stays Waiting | stays Waiting |

### Composed lifecycle cases (mirrors §6 theorems)

- **Two-step happy path**: Draining → Waiting → ExitToProbeBW
- **Draining absorbing**: stays Draining when inflight always above target
- **Waiting never returns to Draining**: no congestion event can go Waiting → Draining
- **Minimum ProbeRTT duration**: timer at `t0`, exits only when `event_time > t0 + duration`

## Running the test

```bash
rustc formal-verification/tests/probe_rtt_sm/probe_rtt_sm_test.rs \
  -o /tmp/probe_rtt_sm_test
/tmp/probe_rtt_sm_test
```

Expected output: 23 × `PASS` lines followed by `=== All 23 checks PASS ===`.

## What is NOT tested

- The BBRv2NetworkModel updates (cwnd gain, pacing gain) — omitted by the Lean model.
- The full `into_probe_bw` mode transition — outside the Lean model's scope.
- Floating-point BDP computation for `inflight_target` — abstracted as a plain Nat.
- The `Instant` → `Nat` mapping: we verify the state machine logic is correct
  assuming a monotone tick counter, but do not verify time monotonicity in the
  full Rust scheduler.

## Source correspondence

| Lean definition | Rust source | Line |
|-----------------|-------------|------|
| `congestionStep` | `ProbeRTT::on_congestion_event` | `probe_rtt.rs:85-112` |
| `quiescenceStep` | `ProbeRTT::on_exit_quiescence` | `probe_rtt.rs:114-123` |
| `ProbeRttState::Draining` | `exit_time: None` | `probe_rtt.rs:47-56` |
| `ProbeRttState::Waiting(t)` | `exit_time: Some(t)` | `probe_rtt.rs:47-56` |
