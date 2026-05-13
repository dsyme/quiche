# Informal Specification: BBR2 ProbeRTT State Machine

**Target T60**  
**Source**: `quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs`  
**Phase**: 2 — Informal Specification  

---

## Purpose

The BBR2 `ProbeRTT` phase exists to let the connection measure the true minimum
round-trip time (minRTT) of the path.  Because BBR2 normally keeps inflight data
close to the BDP (bandwidth-delay product), the queuing introduced by normal
operation inflates RTT samples.  ProbeRTT periodically drains inflight below a
target (`probe_rtt_inflight_target_bdp_fraction × BDP`, typically `0.5 × BDP`)
and holds it there for a fixed duration (`probe_rtt_duration`, default 200 ms)
before returning to the normal `ProbeBW` phase.

The key state variable is `exit_time: Option<Instant>`:
- `None` → the *draining* sub-phase: inflight has not yet reached the target.
- `Some(t)` → the *waiting* sub-phase: inflight ≤ target was first observed at
  some time, so the exit timer was set to `t` (= observation time + duration).

---

## Preconditions

- `on_congestion_event` is called at `event_time` with non-negative
  `bytes_in_flight` and a computed `inflight_target`.
- `on_exit_quiescence` is called at `now` with `now ≥ entry_time`.
- `probe_rtt_duration` is a positive duration.

---

## State Machine

```
         enter ProbeRTT
               │
               ▼
         ┌─────────────┐   inflight > target        ┌─────────────┐
         │  DRAINING   │ ─────────────────────────▶ │  DRAINING   │
         │(exit=None)  │                             │(exit=None)  │
         └─────────────┘                             └─────────────┘
               │
               │ inflight ≤ target
               │ (set exit_time = event_time + duration)
               ▼
         ┌─────────────┐   event_time ≤ exit_time   ┌─────────────┐
         │  WAITING    │ ─────────────────────────▶  │  WAITING    │
         │(exit=Some t)│                             │(exit=Some t)│
         └─────────────┘                             └─────────────┘
               │
               │ event_time > exit_time
               │
               ▼
          ProbeBW (exit)

Quiescence shortcut:
  DRAINING → ProbeBW immediately
  WAITING, now > exit_time → ProbeBW immediately
  WAITING, now ≤ exit_time → stay in WAITING
```

---

## Postconditions per Operation

### `on_congestion_event(state, event_time, inflight, target, duration)`

| Pre-state | inflight vs target | Post-state |
|-----------|--------------------|------------|
| DRAINING  | inflight ≤ target  | WAITING(event_time + duration) |
| DRAINING  | inflight > target  | DRAINING |
| WAITING(t)| event_time > t     | ProbeBW (exit) |
| WAITING(t)| event_time ≤ t     | WAITING(t) — unchanged exit_time |

### `on_exit_quiescence(state, now)`

| Pre-state | now vs exit_time | Post-state |
|-----------|-----------------|------------|
| DRAINING  | (any)           | ProbeBW (exit) — immediate |
| WAITING(t)| now > t         | ProbeBW (exit) |
| WAITING(t)| now ≤ t         | WAITING(t) — unchanged |

---

## Invariants

1. **Exit-time monotonicity**: once `exit_time` is set to `Some(t)`, it never
   changes until the phase exits.  In particular, even if inflight goes above
   target again after the timer was set, `exit_time` stays at its first value.

2. **Exit-time lower bound**: when `exit_time = Some(t)`, then
   `t ≥ event_time_when_timer_was_set + duration`.

3. **No re-entry to DRAINING from WAITING**: the state never transitions from
   WAITING back to DRAINING during normal operation.

4. **Finite stay**: once in WAITING, the next `on_congestion_event` with
   `event_time > t` will always exit.  After at most `duration` real time,
   the phase ends.

5. **Quiescence is a fast-path exit from DRAINING**: exiting quiescence while
   in DRAINING always causes an immediate transition to ProbeBW without
   waiting for the timer.

---

## Edge Cases

- **Zero inflight**: if `inflight = 0 ≤ target` (always true for positive
  target), the timer is set immediately on the first congestion event in
  DRAINING.
- **Duration zero**: if `probe_rtt_duration = 0`, then
  `exit_time = event_time + 0 = event_time`.  A subsequent event at the same
  time does NOT exit (`event_time > exit_time` is strict), but the next event
  at `event_time + 1` will.
- **Inflight oscillates**: if inflight drops below target then rises again, the
  exit_time is still the one set when it first dropped — it is not reset.

---

## Open Questions

- **OQ-T60-1**: Is the `on_exit_quiescence` fast-path from DRAINING correct?
  The Rust code exits to ProbeBW immediately without setting the timer.  This
  means the full `probe_rtt_duration` is *not* observed.  Is this intentional?
  The QUIC-BBR2 spec says the sender MUST spend at least `probe_rtt_duration`
  at or below the inflight target — is quiescence excluded from this
  requirement?

- **OQ-T60-2**: The `on_congestion_event` does not directly compare
  `bytes_in_flight` to `inflight_target` — it uses the result of
  `congestion_event.bytes_in_flight` which may include in-flight packets from
  just before the loss event.  Is this the right signal for the drain check?

---

## Examples

**Example 1 — Normal drain**: BDP = 100, target = 50, duration = 200.
- t=0: enter DRAINING, inflight = 80 > 50 → stay DRAINING
- t=100: inflight = 45 ≤ 50 → set exit_time = 300, enter WAITING
- t=200: event_time=200 ≤ 300 → stay WAITING
- t=301: event_time=301 > 300 → exit to ProbeBW ✓

**Example 2 — Quiescence fast-path**: BDP = 100, target = 50, duration = 200.
- t=0: enter DRAINING, inflight = 80 > 50
- t=50: on_exit_quiescence(50) → exit to ProbeBW immediately
  (timer was never set)

**Example 3 — Timer not reset**: BDP = 100, target = 50, duration = 200.
- t=100: inflight = 45 → set exit_time = 300, enter WAITING
- t=150: inflight = 70 > 50, but state is WAITING, so we check timer only
  event_time=150 ≤ 300 → stay WAITING (exit_time unchanged at 300)
- t=301: event_time=301 > 300 → exit to ProbeBW ✓
