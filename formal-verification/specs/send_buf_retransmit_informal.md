# Informal Specification: `SendBuf::retransmit`

> 🔬 *Lean Squad — automated formal verification for `dsyme/quiche`.*

**Source**: `quiche/src/stream/send_buf.rs:366`  
**Lean file**: `formal-verification/lean/FVSquad/SendBufRetransmit.lean`

---

## Purpose

`SendBuf::retransmit(off, len)` marks a range of bytes `[off, off+len)` in
the stream send buffer as needing re-transmission.  This is called when the
QUIC loss-detection module determines that a packet containing stream data
was lost and must be resent.

Concretely, the function walks the internal `VecDeque<RangeBuf>` and resets
the `pos` cursor in each affected buffer to include the retransmit range.
The `pos` cursor separates bytes that have already been *emitted* (sent to
the network) from bytes that are still pending.  Lowering `pos` effectively
puts bytes "back" into the send queue.

---

## Preconditions

- `self` is a valid `SendBuf` (invariants hold — see below).
- `off` is any byte offset (may be before or after the currently emitted
  region, including within the already-acknowledged prefix).
- `len` is any non-negative length.

---

## Postconditions

1. **Early return**: if `off + len ≤ ack_off()` (the entire retransmit range
   is already acknowledged), the buffer is unchanged.

2. **Active retransmit**: otherwise, bytes from `max(ack_off(), off)` up to
   `min(emit_off, off + len)` are marked as pending resend.  The observable
   scalar effect:
   - `emit_off` is lowered to `min(emit_off, max(ack_off(), off))`.
   - `len` (unsent byte count) is increased by `prev_pos − new_pos` for each
     affected buffer.
   - All other fields (`off`, `ack_off`, `max_data`, `fin_off`) are unchanged.

3. **Invariant preservation**: the `SendBuf` invariant continues to hold:
   - `ack_off ≤ emit_off`: satisfied because emitOff ≥ ackOff is enforced.
   - `emit_off ≤ off`: only decreases emitOff.
   - `emit_off ≤ max_data`: only decreases emitOff.
   - `fin_off` consistency: finOff is not touched.

---

## Invariants

The `SendBuf` maintains (at all times):
- **I1**: `ack_off ≤ emit_off` — cannot acknowledge bytes that were never sent.
- **I2**: `emit_off ≤ off` — cannot send bytes that were never written.
- **I3**: `emit_off ≤ max_data` — flow-control safety (security-relevant).
- **I4**: `fin_off = Some(f) → f = off` — FIN is set to the final size.

`retransmit` preserves I1–I4.

---

## Edge Cases

- **Range fully acked** (`off + len ≤ ack_off()`): no-op.  Already-acknowledged
  bytes cannot be retransmitted (they were successfully received).
- **Range beyond emitOff** (`off ≥ emit_off`): no-op on emitOff.  These bytes
  were never sent, so there is nothing to retransmit.
- **Range partially before ackOff**: only the portion `[ack_off, off+len)` is
  active; bytes below `ack_off` are clamped.
- **Empty buffer** (`data.is_empty()`): Rust has an early return; in the
  abstract model this is subsumed by the numeric guard.
- **len = 0, off > ack_off**: in the Lean model this is NOT necessarily a
  no-op — the emitOff may be moved back to `off` even for a zero-length range.
  This edge case is noted as a minor divergence from the Rust early returns.

---

## Examples

| `ackOff` | `emitOff` | `off` | `len` | Result emitOff | Notes |
|----------|-----------|-------|-------|----------------|-------|
| 40 | 80 | 90 | 10 | 80 | Range beyond emitOff — no-op |
| 40 | 80 | 60 | 10 | 60 | Active retransmit — lowered to off |
| 40 | 80 | 20 | 30 | 40 | off < ackOff — clamped to ackOff |
| 40 | 80 | 10 | 20 | 80 | Range fully acked (30 ≤ 40) — no-op |
| 40 | 80 | 40 | 50 | 40 | Entire emitted range — emitOff = ackOff |

---

## Inferred Intent

The Rust code `buf.pos = min(buf.pos, ...)` pattern in the loop is equivalent
to: "expand the unsent region of each buffer to include the retransmit range".
The scalar model captures this as lowering `emitOff`.

The `SendBuf.len` field (unsent byte count) is not modelled in the abstract
state — only the `emitOff` cursor.  In the Rust, `self.len += prev_pos − new_pos`
accounts for bytes re-added to the send queue.  In the abstract model, the
equivalent quantity `off − emitOff` increases after retransmit.

---

## Open Questions

- **OQ-RT-1**: Does `retransmit(off, 0)` with `off > ack_off` actually move
  the `pos` cursor in the Rust code?  A zero-length retransmit range should
  logically be a no-op, but the `if off + len ≤ ack_off { return }` guard
  does not catch it when `off > ack_off` and `len = 0`.  This is a potential
  inconsistency worth clarifying with maintainers.

- **OQ-RT-2**: Is it possible to call `retransmit` on a range that overlaps
  an already-retransmitted-but-not-yet-emitted region?  The current code
  handles this gracefully (idempotent), but the invariant proof could be
  made tighter if the model tracked "in-flight but not acked" bytes.
