# Informal Specification: Proportional Rate Reduction (PRR)

**Source**: `quiche/src/recovery/congestion/prr.rs`  
**Reference**: RFC 6937 — Proportional Rate Reduction for TCP

---

## Purpose

PRR controls the sending rate during TCP/QUIC congestion recovery so that:
1. The total bytes sent during recovery stay proportional to the fraction of the
   initial flight that has been delivered (PRR mode).
2. When the pipe drains below `ssthresh`, the connection is allowed to recover
   quickly back up to `ssthresh` (PRR-SSRB mode).

The key abstraction is `snd_cnt`: how many bytes the sender is permitted to
transmit before the next ACK arrives. It is recomputed on every ACK, and
decremented by each byte actually sent.

---

## State

```
PRR {
  prr_delivered : usize  // total bytes ACKed since congestion_event
  recoverfs     : usize  // bytes-in-flight at the start of recovery
  prr_out       : usize  // total bytes sent since congestion_event
  snd_cnt       : usize  // additional bytes permitted to send now
}
```

Initial state (after `Default::default()`): all fields 0.

---

## Operations

### `congestion_event(bytes_in_flight)`

Resets PRR for a new recovery epoch.

**Preconditions**: none.  
**Postconditions**:
- `prr_delivered = 0`
- `recoverfs = bytes_in_flight`
- `prr_out = 0`
- `snd_cnt = 0`

**Invariant**: Any prior recovery-epoch state is discarded. A second call with
a different `bytes_in_flight` replaces `recoverfs` again.

---

### `on_packet_sent(sent_bytes)`

Records that `sent_bytes` bytes were actually sent.

**Preconditions**: `sent_bytes ≤ snd_cnt` (protocol contract — not enforced by
the function itself).  
**Postconditions**:
- `prr_out += sent_bytes`
- `snd_cnt = max(0, snd_cnt - sent_bytes)`  (saturating subtraction)

---

### `on_packet_acked(delivered_data, pipe, ssthresh, max_datagram_size)`

Recomputes `snd_cnt` after receiving ACKs.

**Parameters**:
- `delivered_data`: bytes newly ACKed in this round.
- `pipe`: estimated bytes still in flight.
- `ssthresh`: slow-start threshold (target cwnd after recovery).
- `max_datagram_size` (mss): maximum datagram size.

**Postconditions** — `prr_delivered` and modes:
- `prr_delivered += delivered_data` (monotone).
- `prr_out` unchanged.

**Mode 1 — PRR (`pipe > ssthresh`)**:
- If `recoverfs = 0`: `snd_cnt = 0`.
- If `recoverfs > 0`:
  ```
  snd_cnt = max(0, ceil(prr_delivered' * ssthresh / recoverfs) - prr_out)
  ```
  The "target" is `ceil(prr_delivered' * ssthresh / recoverfs)`: a proportional
  fraction of `ssthresh` scaled by the delivery ratio. `snd_cnt` represents how
  far below the target `prr_out` currently sits.

**Mode 2 — PRR-SSRB (`pipe ≤ ssthresh`)**:
  ```
  limit = max(prr_delivered' - prr_out, delivered_data) + mss
  snd_cnt = min(ssthresh - pipe, limit)
  ```
  SSRB permits sending up to `ssthresh - pipe` more bytes (to fill the gap to
  ssthresh), but limits each round to `limit` to avoid bursting.

---

## Invariants

1. **snd_cnt ≥ 0**: always (usize / Nat).
2. **PRR rate bound**: After `on_packet_acked` in PRR mode with `recoverfs > 0`:
   `snd_cnt ≤ ceil(prr_delivered * ssthresh / recoverfs)`.
3. **SSRB gap bound**: After `on_packet_acked` in SSRB mode:
   `snd_cnt ≤ ssthresh - pipe`.
4. **SSRB at-least-mss**: After `on_packet_acked` in SSRB mode (when room exists):
   `snd_cnt ≥ min(ssthresh - pipe, mss)`, since `limit ≥ mss` always holds.

---

## Edge Cases

- `recoverfs = 0` (zero bytes in flight at congestion): PRR mode sends nothing
  (`snd_cnt = 0`). SSRB is unaffected since `recoverfs` is not used there.
- `pipe = ssthresh`: the boundary — SSRB mode applies (`¬ pipe > ssthresh`).
  `snd_cnt = min(0, limit) = 0` since `ssthresh - pipe = 0`.
- `ssthresh = 0`: In SSRB mode, `snd_cnt = min(0, limit) = 0` since 
  `ssthresh - pipe` saturates to 0 (pipe ≥ 0).
- `delivered_data = 0`: `prr_delivered` unchanged; `snd_cnt` still recomputed.

---

## Examples (from unit tests)

### PRR mode example
```
recoverfs = 10000, ssthresh = 5000, pipe = 10000
After ACK(1000): prr_delivered = 1000
snd_cnt = ceil(1000 * 5000 / 10000) - 0 = ceil(0.5) = 1 ... wait
Actually: ceil(5000000 / 10000) = ceil(500) = 500
snd_cnt = 500 ✓ (matches test: assert_eq!(prr.snd_cnt, 500))
```

### SSRB mode example
```
recoverfs = 10000, ssthresh = 5000, pipe = 1000, mss = 1000
After ACK(1000): prr_delivered = 1000
limit = max(1000 - 0, 1000) + 1000 = 1000 + 1000 = 2000
snd_cnt = min(5000 - 1000, 2000) = min(4000, 2000) = 2000 ✓
```

---

## Open Questions

1. **Integer overflow**: Can `prr_delivered * ssthresh` overflow `usize` in
   practice? The current Rust code uses `usize` without checked arithmetic.
   Our Lean model uses `Nat` (unbounded), so this is not captured.
2. **Protocol invariant**: Is `sent_bytes ≤ snd_cnt` actually guaranteed by the
   caller before every `on_packet_sent` call? If not, `prr_out` could diverge
   from what `snd_cnt` permits.
3. **Interaction with cwnd**: PRR computes `snd_cnt` independently of `cwnd`.
   The actual packet sending is limited by `min(cwnd, snd_cnt)`. This interaction
   is outside the scope of this spec.
