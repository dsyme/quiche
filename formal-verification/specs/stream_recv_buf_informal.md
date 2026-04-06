# Informal Specification: `RecvBuf` (stream/recv_buf.rs)

🔬 *Lean Squad — automated formal verification.*

---

## Purpose

`RecvBuf` is the receive-side stream buffer for a QUIC stream.  It accepts
out-of-order byte chunks from the network and presents a contiguous, ordered
byte sequence to the application.

Internally it maintains a `BTreeMap<u64, RangeBuf>` keyed by stream offset,
so that out-of-order chunks can be inserted and then read contiguously once
the preceding data arrives.

---

## Key Fields

| Field       | Type                    | Description                                             |
|-------------|-------------------------|---------------------------------------------------------|
| `data`      | `BTreeMap<u64, RangeBuf>` | Buffered chunks not yet read, ordered by offset.      |
| `off`       | `u64`                   | Lowest unread byte offset (≡ "read cursor").            |
| `len`       | `u64`                   | Highest byte offset ever received (high watermark).     |
| `fin_off`   | `Option<u64>`           | Final stream offset, once known from a FIN frame.       |
| `flow_control` | `FlowControl`        | Receiver-side flow-control state (not specified here).  |
| `error`     | `Option<u64>`           | Error code from a RESET_STREAM frame, if any.           |
| `drain`     | `bool`                  | If true, incoming data is validated but not buffered.   |

---

## Preconditions

### `write(buf: RangeBuf) -> Result<()>`

- `buf.max_off() ≤ max_data()` — respect flow-control window.
- If `fin_off` is already known, `buf.max_off() ≤ fin_off` (no data beyond FIN).
- If `buf.fin()` and `fin_off` is already known, `buf.max_off() = fin_off` (no
  changing the final size).
- If `buf.fin()`, `buf.max_off() ≥ len` (FIN cannot shrink the known high watermark).

### `emit(out: &mut [u8]) -> Result<(usize, bool)>`

- Must be called only when the stream is `ready()`.

---

## Postconditions

### `write(buf)` — on success

1. **`len` is monotone**: `new_len ≥ old_len`.
2. **`off` is unchanged**: the read cursor never advances on write.
3. **FIN is monotone**: once `fin_off = Some(f)`, it cannot be changed.
4. **High watermark**: `new_len ≥ buf.max_off()` (if the write added data).

### `emit(out)` — on success

1. **`off` advances**: `new_off = old_off + bytes_written`.
2. **`len` is unchanged**: emit does not change the high watermark.
3. **FIN indicator**: the returned `bool` is `true` iff `new_off = fin_off`.
4. **Completeness**: if `ready()` held before, at least 1 byte is emitted.

---

## Invariants (always hold on any observable state)

**I1 – off ≤ len**: `self.off ≤ self.len`  
  The read cursor never exceeds the received high watermark.

**I2 – chunks above cursor**: every chunk `(k, buf)` in `data` satisfies
  `buf.off() ≥ self.off`.  Bytes below `off` have already been consumed.

**I3 – non-overlapping**: no two chunks in `data` overlap in their byte ranges.

**I4 – FIN consistency**: if `fin_off = Some(f)` then `f = self.len`.
  (The final offset matches the high watermark at the time FIN was received.)

**I5 – is_fin ↔ off = fin_off**: `is_fin() = (fin_off = Some(off))`.

**I6 – max_off = len**: `max_off()` always returns `self.len`.

**I7 – ready ↔ front chunk at off**: `ready()` is true iff the first entry in
  `data` has `buf.off() = self.off`.

---

## Edge Cases

- **Empty buffer**: `data` is empty, `off = len = 0`, `fin_off = None`.
  `is_fin() = false`, `ready() = false`, `max_off() = 0`.
- **Fully duplicate chunk**: chunk with `max_off ≤ self.off` is silently
  discarded.
- **Partial overlap**: the incoming chunk is trimmed or split to remove the
  portion already received.
- **Zero-length FIN**: a zero-length buffer with `fin = true` is accepted;
  it sets `fin_off` without adding data.
- **FIN at current offset**: if `fin_off = Some(off)`, `is_fin()` returns true
  immediately without needing `emit`.

---

## Examples

```
Initial:  off=0  len=0  fin_off=None  data={}
write({off=5, len=3, fin=false})  →  off=0  len=8  data={(5, buf)}
write({off=0, len=5, fin=false})  →  off=0  len=8  data={(0, buf), (5, buf)}
emit(out[0..8])  → returns (8, false), off=8  data={}
write({off=8, len=0, fin=true})   →  off=8  len=8  fin_off=Some(8)
is_fin()  → true
```

---

## Inferred Intent

The design intent is a bounded, out-of-order reassembly buffer.  The
`BTreeMap` key (the chunk start offset) enables efficient ordered iteration.
The `off` cursor guarantees that once data is consumed it is never buffered
again, preventing unbounded growth for streams that receive retransmissions.

The `len` field tracks the high watermark irrespective of gaps; this allows
flow-control credit to be granted based on highest-received even when data
arrives out of order.

---

## Open Questions

1. **Overlapping invariant**: is it an invariant that `data` never contains two
   overlapping chunks *after* `write` returns `Ok`?  The code splits and trims
   incoming data, but no formal invariant is stated. This should be a
   **key theorem** to prove.
2. **`error` field**: when `error = Some(code)`, what operations are still
   permitted?  The spec should clarify which methods fail early on reset.
3. **`drain` mode**: in drain mode, data is validated but not stored.  Does
   `off` still advance?  Are invariants I2–I3 trivially preserved vacuously?
4. **Flow-control interaction**: I4 above (fin_off = len) — is this exactly
   what the code guarantees, or can `len` exceed `fin_off` before being clamped?
