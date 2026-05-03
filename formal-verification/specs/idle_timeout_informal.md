# Informal Specification: `idle_timeout()` Negotiation (RFC 9000 §10.1.1)

> Target: T46 — `Connection::idle_timeout()` in `quiche/src/lib.rs` (line ~8757)

---

## Purpose

`idle_timeout()` computes the effective idle timeout duration for a QUIC
connection, implementing the negotiation logic mandated by RFC 9000 §10.1.1.
Each endpoint independently advertises a `max_idle_timeout` transport
parameter (in milliseconds). A value of `0` means "no idle timeout" for that
endpoint. The negotiated idle timeout is the *minimum* of the two non-zero
values, or the single non-zero value if the other is zero, or disabled if both
are zero.

Additionally, the negotiated duration is clamped from below to `3 × PTO`
(probe timeout) so that network jitter cannot prematurely expire the idle
timer.

---

## Inputs

| Input | Type | Description |
|-------|------|-------------|
| `local` | `u64` | Local `max_idle_timeout` transport parameter (ms). `0` = disabled. |
| `peer` | `u64` | Peer `max_idle_timeout` transport parameter (ms). `0` = disabled. |
| `path_pto` | `Duration` | Current path PTO estimate (from active path's recovery). |

---

## Postconditions / Return Value

Returns `Option<Duration>`:

| Condition | Return |
|-----------|--------|
| `local == 0 && peer == 0` | `None` — idle timeout is disabled |
| `local == 0 && peer > 0` | `Some(max(peer_ms, 3 * pto))` |
| `local > 0 && peer == 0` | `Some(max(local_ms, 3 * pto))` |
| `local > 0 && peer > 0` | `Some(max(min(local_ms, peer_ms), 3 * pto))` |

where `local_ms = Duration::from_millis(local)` and
`peer_ms = Duration::from_millis(peer)`.

---

## Key Properties

1. **No-timeout-if-both-zero**: if `local == 0 && peer == 0` then result is `None`.
2. **Some-if-any-nonzero**: if `local > 0 || peer > 0` then result is `Some(_)`.
3. **PTO lower bound**: the result, when `Some(d)`, satisfies `d >= 3 * path_pto`.
4. **RFC minimum**: the effective base timeout (before PTO clamping) equals
   - `peer_ms` when `local == 0`
   - `local_ms` when `peer == 0`
   - `min(local_ms, peer_ms)` otherwise  
   This matches RFC 9000 §10.1.1: *"an endpoint SHOULD use the minimum of the
   two values"*.
5. **Monotone in PTO**: if `path_pto` increases and all else is equal, the
   result is ≥ the prior result.
6. **Symmetry**: `idle_timeout(local, peer, pto) == idle_timeout(peer, local, pto)`
   — the negotiation is symmetric.
7. **Zero-zero boundary**: `idle_timeout(0, 0, anything) == None`.
8. **Nonzero-zero boundary**: `idle_timeout(v, 0, 0) == Some(v ms)` for `v > 0`.

---

## Preconditions

- None on values — any `u64` for `local` and `peer`, any `Duration` for `path_pto`.
- The active path must be retrievable; if not, `path_pto` defaults to
  `Duration::ZERO` (no clamping effect).

---

## Edge Cases

| Case | Expected Behaviour |
|------|--------------------|
| Both zero | `None` |
| One zero, one huge | `Some(huge_ms)` — clamped only if `3 × pto > huge_ms` |
| Both equal nonzero | `Some(v_ms)` clamped to `max(v_ms, 3 * pto)` |
| Very large PTO | Result is `3 * pto` (PTO dominates) |
| `u64::MAX` for either param | Arithmetic overflow in `Duration::from_millis` is not modelled by the pure spec (use `Nat`) |

---

## Examples

| `local` (ms) | `peer` (ms) | `path_pto` (ms) | Result |
|-------------|-------------|-----------------|--------|
| 0 | 0 | 100 | `None` |
| 5000 | 0 | 100 | `Some(5000 ms)` |
| 0 | 3000 | 100 | `Some(3000 ms)` |
| 5000 | 3000 | 100 | `Some(3000 ms)` |
| 5000 | 3000 | 2000 | `Some(6000 ms)` |
| 500 | 500 | 300 | `Some(900 ms)` |
| 1 | 1 | 1000 | `Some(3000 ms)` |

---

## Inferred Intent

The function enforces two goals simultaneously:
1. **RFC compliance**: negotiate the minimum non-disabled idle timeout.
2. **PTO safety**: prevent the timer from firing during a burst of packet loss
   (where retransmits may be in flight for up to 3 PTO periods).

A specification that omits the PTO clamping would be incomplete: that step is
load-bearing for correctness under loss.

---

## Open Questions

1. **OQ-T46-1**: Is it possible for `get_active()` to fail during an
   established connection? If so, `path_pto = ZERO` silently disables the PTO
   bound. This seems like a latent bug on single-path connections that haven't
   fully validated yet.
2. **OQ-T46-2**: RFC 9000 §10.1.1 says SHOULD use the minimum, not MUST.
   Is there a scenario where the implementation intentionally uses the maximum
   instead? The code uses `min`; this is the conservative choice.
3. **OQ-T46-3**: The PTO is computed from `paths.get_active().recovery.pto()`.
   For connections with multiple paths, only the active path's PTO is used.
   Is this correct? Should it be the minimum PTO across all paths?

---

## Lean Modelling Approach

Model the pure negotiation function taking `(local peer : Nat) (pto : Nat)`
(all in milliseconds, using `Nat` to avoid overflow), returning `Option Nat`:

```lean
def idleTimeout (local peer pto : Nat) : Option Nat :=
  if local == 0 && peer == 0 then none
  else
    let base := if local == 0 then peer
                else if peer == 0 then local
                else min local peer
    some (max base (3 * pto))
```

All key properties are provable by `omega` or simple `simp`/`cases`. The
expected theorem count is ~12 theorems, all at the `omega` level.
