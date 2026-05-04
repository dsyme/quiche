# Informal Specification: `idle_timeout()` — RFC 9000 §10.1.1 Negotiation

**Target ID**: T46
**Source**: `quiche/src/lib.rs:8757` — `fn idle_timeout(&self) -> Option<Duration>`
**Status**: Phase 3 (Lean spec written)

---

## Purpose

`idle_timeout()` computes the effective QUIC idle timeout for a connection by
negotiating between the local and peer `max_idle_timeout` transport parameters
and applying a safety floor of `3 × PTO`.

Per RFC 9000 §10.1.1, if an endpoint uses an idle timeout, it SHOULD use the
minimum of the values advertised by the two endpoints. An endpoint with a
`max_idle_timeout = 0` has disabled the idle timeout.

---

## Preconditions

- `self.local_transport_params.max_idle_timeout`: local max idle timeout in ms (0 = disabled)
- `self.peer_transport_params.max_idle_timeout`: peer max idle timeout in ms (0 = disabled)
- `path_pto = self.paths.get_active()?.recovery.pto()` in milliseconds

---

## Postconditions

| Condition | Result |
|-----------|--------|
| `local = 0 && peer = 0` | `None` (both endpoints disabled idle timeout) |
| `local = 0 && peer ≠ 0` | `Some(max(peer, 3 × pto))` |
| `local ≠ 0 && peer = 0` | `Some(max(local, 3 × pto))` |
| `local ≠ 0 && peer ≠ 0` | `Some(max(min(local, peer), 3 × pto))` |

---

## Invariants

1. **None ↔ both-zero**: result is `None` if and only if both parameters are 0.
2. **≥ 3 × PTO**: when result is `Some(t)`, `t ≥ 3 × pto`.
3. **Commutativity**: `idle_timeout(local, peer) = idle_timeout(peer, local)`.
4. **≤ max(local, peer)** (when `pto = 0`): result never exceeds both inputs.
5. **Monotone in PTO**: higher PTO cannot shrink the result.

---

## Edge Cases

- `pto = 0`: result equals the negotiated base directly (no PTO clamping).
- Both parameters identical: result is that value (clamped).
- Very large PTO relative to idle timeout: PTO floor dominates.
- `get_active()` failure: `path_pto = Duration::ZERO` → no PTO clamping (OQ-T46-1).

---

## Examples

| local | peer | pto | result |
|-------|------|-----|--------|
| 0 | 0 | 100 | None |
| 5000 | 0 | 100 | Some 5000 |
| 0 | 3000 | 100 | Some 3000 |
| 5000 | 3000 | 100 | Some 3000 |
| 1000 | 2000 | 500 | Some 1500 (3×500=1500 > min=1000) |
| 1000 | 2000 | 100 | Some 1000 |
| 100 | 200 | 400 | Some 1200 (3×400=1200 > min=100) |

---

## Open Questions

- **OQ-T46-1**: When `get_active()` fails (Err), `path_pto` is set to
  `Duration::ZERO`, silently disabling the PTO safety floor. This could
  be a latent bug on connections where no active path exists.
- **OQ-T46-2**: RFC 9000 says SHOULD (not MUST) use the minimum; the
  implementation uses `min`, which is the most conservative choice.
- **OQ-T46-3**: Multi-path connections use only the active path's PTO.
  Is this correct for multi-path QUIC?

---

*Extracted by Lean Squad (run 127+128). Ready for Task 3 Lean spec.*
