# Informal Specification: `pkt_num_len` and `encode_pkt_num`

> 🔬 *Lean Squad — automated formal verification for `dsyme/quiche`.*

**Source**: `quiche/src/packet.rs`, functions `pkt_num_len` (line ~569) and
`encode_pkt_num` (line ~719).

---

## Purpose

`pkt_num_len(pn, largest_acked)` computes the **minimum number of bytes**
needed to encode a QUIC packet number `pn` in a packet header, given that
`largest_acked` is the largest packet number the receiver has acknowledged.

`encode_pkt_num(pn, pn_len, b)` writes the truncated packet number into a
buffer using exactly `pn_len` bytes (1–4).

These functions implement RFC 9000 §17.1: the packet number is encoded with
the minimum length that allows the receiver to reconstruct the full 62-bit
packet number using the sliding-window algorithm from RFC 9000 Appendix A.3.

---

## Key Concepts

### Number of Unacknowledged Packets

```
num_unacked = pn.saturating_sub(largest_acked) + 1
```

This is 1 when `pn ≤ largest_acked` (unusual but safe), and `pn - la + 1`
otherwise. It represents the number of distinct packet numbers that could
fall between `largest_acked` and `pn`, inclusive.

### Minimum Bits Formula (Rust)

```
min_bits = u64::BITS - num_unacked.leading_zeros() + 1
```

This is `floor(log₂(num_unacked)) + 2` — one more bit than needed to
represent `num_unacked`, ensuring the half-window covers the gap.

### Length in Bytes

```
pn_len = ceil(min_bits / 8)
```

This gives 1, 2, 3, or 4 for realistic QUIC packet number gaps.

---

## Preconditions

- `pn` and `largest_acked` are 62-bit packet numbers (u64 ≤ 2^62 - 1)
- In practice, `pn - largest_acked ≤ 2^31 - 2` (the gap is at most
  `2^31 - 1` unacked packets). This guarantees `pkt_num_len` returns ≤ 4.
- For `encode_pkt_num`: `pn_len ∈ {1, 2, 3, 4}`

---

## Postconditions

### `pkt_num_len`

1. **Result is in {1, 2, 3, 4}** when `num_unacked ≤ 2^31 - 1`
2. **Covers the gap**: `num_unacked ≤ pnHwin(pkt_num_len)` where
   `pnHwin(len) = 2^(8*len - 1)`. This ensures the receiver's sliding-window
   decode (RFC 9000 §A.3) can unambiguously reconstruct `pn`.
3. **Minimality**: `pkt_num_len` is the smallest value in {1,2,3,4} satisfying
   the coverage condition.
4. **Monotone**: if the gap `pn - la` increases, `pkt_num_len` does not
   decrease.

### `encode_pkt_num`

1. Writes exactly `pn_len` bytes to the buffer (big-endian, truncated to
   `pn_len * 8` bits).
2. Returns `Ok(())` iff `pn_len ∈ {1, 2, 3, 4}`.
3. Returns `Err(InvalidPacket)` for any other `pn_len`.

---

## Invariants

### RFC 9000 Sliding-Window Invariant

The encoding is correct if and only if:

```
pn - largest_acked ≤ pnHwin(pkt_num_len(pn, largest_acked)) - 1
```

This is exactly the precondition required by `decode_pkt_num` (RFC 9000
§A.3) to guarantee unambiguous decoding.

**Threshold table:**

| `pkt_num_len` | `pnHwin` | Max `num_unacked` | Max gap `pn - la` |
|---|---|---|---|
| 1 | 128 | 127 | 126 |
| 2 | 32768 | 32767 | 32766 |
| 3 | 8388608 | 8388607 | 8388606 |
| 4 | 2147483648 | 2147483647 | 2147483646 |

---

## Edge Cases

1. **`pn == largest_acked`**: `num_unacked = 1`, returns 1 (minimum).
2. **`pn < largest_acked`**: saturating subtraction gives `num_unacked = 1`,
   returns 1.
3. **Gap exactly at threshold** (e.g., `num_unacked = 127` → len 1,
   `num_unacked = 128` → len 2): transition is sharp.
4. **Very large gaps** (`num_unacked > 2^31`): returns 5 or more — `encode_pkt_num`
   would then return `Err(InvalidPacket)`. This indicates a QUIC protocol
   error (too many unacked packets).

---

## Examples

| `pn` | `la` | `num_unacked` | `pkt_num_len` |
|------|------|---------------|----------------|
| 10 | 0 | 11 | 1 |
| 127 | 0 | 128 | 2 |
| 126 | 0 | 127 | 1 |
| 32767 | 0 | 32768 | 3 |
| 32766 | 0 | 32767 | 2 |
| 5 | 10 | 1 (sat.) | 1 |
| 8388607 | 0 | 8388608 | 4 |
| 8388606 | 0 | 8388607 | 3 |

---

## Inferred Intent

The `pkt_num_len` function implements the **sender side** of the QUIC packet
number encoding scheme. It complements `decode_pkt_num` (the receiver side,
already formally verified in `FVSquad/PacketNumDecode.lean`). Together they
form a codec: the sender picks the minimum encoding length, and the receiver
decodes the full 62-bit packet number from the truncated form.

The critical security/correctness property is that the encoding is sufficient
for unambiguous decoding: a packet sent with `pkt_num_len` bytes can always
be decoded by a receiver that has seen `largest_acked`, as long as the network
does not reorder packets by more than half the encoding window.

---

## Open Questions

- **OQ-1**: For gaps ≥ 2^31, the Rust code returns a `pn_len` ≥ 5, and
  `encode_pkt_num` returns `Err(InvalidPacket)`. Is this the intended
  behaviour, or should `pkt_num_len` be clipped to 4? Currently no QUIC
  implementation should exceed 2^31 unacked packets, but this is an implicit
  contract.
