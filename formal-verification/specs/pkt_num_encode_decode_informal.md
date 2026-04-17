# Informal Specification: encode_pkt_num → decode_pkt_num Composition (T24)

**Target**: `encode_pkt_num` / `decode_pkt_num` / `pkt_num_len`
  in `quiche/src/packet.rs` (lines 569, 634, 719)
**Priority**: HIGH
**FV Phase**: 2 (Informal Spec)
**Status**: Identified in run 74, informal spec written in run 75.

---

## Purpose

QUIC truncates packet numbers on the wire to save space (RFC 9000 §17.1).
Three functions collaborate to implement this:

- `pkt_num_len(pn, largest_acked)` — computes the minimum byte count (1–4)
  needed to encode `pn` unambiguously relative to `largest_acked`.
- `encode_pkt_num(pn, pn_len, buf)` — writes the low `pn_len * 8` bits of
  `pn` into the output buffer as a big-endian integer.
- `decode_pkt_num(largest_pn, truncated_pn, pn_len)` — given the receiver's
  `largest_pn` and the truncated value, recovers the full packet number.

The **composition property** is:

> If the sender computes `pn_len = pkt_num_len(pn, largest_acked)` and sends
> `truncated_pn = pn % pnWin(pn_len)`, and the receiver holds `largest_pn =
> largest_acked`, then `decode_pkt_num(largest_acked, truncated_pn, pn_len) = pn`.

This is the end-to-end correctness of QUIC packet number truncation and
reconstruction, which is foundational to ordered delivery and packet dedup.

**Relation to existing proofs**: `FVSquad/PacketNumDecode.lean` already proves
`decode_pktnum_correct` — a conditional correctness theorem for `decodePktNum`
given explicit proximity preconditions. T24 closes the gap by showing that
`pkt_num_len` always produces a `pn_len` that satisfies those preconditions.

---

## Functions

### `pkt_num_len(pn, largest_acked) → usize`

```rust
pub fn pkt_num_len(pn: u64, largest_acked: u64) -> usize {
    let num_unacked: u64 = pn.saturating_sub(largest_acked) + 1;
    let min_bits = u64::BITS - num_unacked.leading_zeros() + 1;
    min_bits.div_ceil(8) as usize
}
```

Returns 1, 2, 3, or 4. The formula computes ⌈(⌊log₂(num_unacked)⌋ + 2) / 8⌉,
which is the minimum number of bytes such that `pnWin = 2^(pn_len * 8) ≥ 2 * num_unacked`.

**Key invariant**: `pnWin(pkt_num_len(pn, largest_acked)) ≥ 2 * (pn - largest_acked + 1)`
when `pn ≥ largest_acked`. This is the proximity condition needed by
`decode_pktnum_correct`.

### `encode_pkt_num(pn, pn_len, buf)`

```rust
pub fn encode_pkt_num(pn: u64, pn_len: usize, b: &mut octets::OctetsMut) -> Result<()> {
    match pn_len {
        1 => b.put_u8(pn as u8)?,
        2 => b.put_u16(pn as u16)?,
        3 => b.put_u24(pn as u32)?,
        4 => b.put_u32(pn as u32)?,
        _ => return Err(Error::InvalidPacket),
    };
    Ok(())
}
```

Writes the low `pn_len * 8` bits of `pn` as a big-endian integer.
The truncated packet number is `pn % pnWin(pn_len)`.

### `decode_pkt_num(largest_pn, truncated_pn, pn_len) → u64`

Reconstructs `pn` from `largest_pn` (receiver's largest received packet number)
and the truncated value. Uses the proximity window to disambiguate. See
`PacketNumDecode.lean` for the formal model (`decodePktNum`).

---

## Preconditions

1. `pn ≥ 0` (trivially satisfied, pn is `u64`).
2. `pn < 2^62` — QUIC packet numbers are at most 62 bits (RFC 9000 §12.3).
3. `largest_acked ≤ pn` — the sender has not received an acknowledgement for
   a packet number greater than the one being encoded.
4. `pn - largest_acked < 2^31` — the gap fits in 4 bytes of packet number
   space (practical constraint; `pkt_num_len` returns ≤ 4).
5. The receiver holds the same `largest_pn = largest_acked` as the sender
   used when computing `pn_len`.

---

## Postconditions

1. **Roundtrip**: `decode_pkt_num(largest_acked, pn % pnWin(pn_len), pn_len) = pn`
   where `pn_len = pkt_num_len(pn, largest_acked)`.
2. **Encoding length**: `pn_len ∈ {1, 2, 3, 4}`.
3. **Truncation**: `encode_pkt_num(pn, pn_len, buf)` writes exactly `pn % pnWin(pn_len)`
   (low `pn_len * 8` bits of `pn`) into the buffer as a big-endian integer.

---

## Invariants

- **Window sufficiency**: `pnWin(pn_len) ≥ 2 * (pn - largest_acked + 1)` where
  `pn_len = pkt_num_len(pn, largest_acked)`. This ensures the proximity
  conditions of `decode_pktnum_correct` are satisfied.
- **Proximity**: `|pn - (largest_acked + 1)| < pnHwin(pn_len)`, i.e., the
  actual packet number lies within the half-window of the expected value.

---

## Edge Cases

| Scenario | Behaviour |
|---|---|
| `pn = largest_acked + 1` (common next packet) | `num_unacked = 2`, `min_bits = 2`, `pn_len = 1` (1 byte) |
| `pn = largest_acked + 127` (gap < 128) | `pn_len = 1` (1 byte suffices) |
| `pn = largest_acked + 128` | `pn_len = 2` (2 bytes needed) |
| `pn = 0, largest_acked = 0` | `num_unacked = 1`, `pn_len = 1` |
| `pn ≫ largest_acked` (large gap) | `pn_len = 3` or `4`; decode still correct |
| `pn = 2^62 - 1` (maximum) | `pn_len = 4`; roundtrip holds with appropriate `largest_acked` |

---

## Examples

| `pn` | `largest_acked` | `num_unacked` | `pn_len` | `truncated_pn` | `decode result` |
|------|-----------------|---------------|----------|----------------|-----------------|
| 1    | 0               | 2             | 1        | 1              | 1               |
| 255  | 127             | 129           | 2        | 255            | 255             |
| 256  | 0               | 257           | 2        | 256            | 256             |
| 65535| 32767           | 32769         | 3        | 65535          | 65535           |

---

## Key Lemma: pkt_num_len Satisfies Proximity

The link between `pkt_num_len` and `decode_pktnum_correct` is:

**Claim**: If `pn_len = pkt_num_len(pn, largest_acked)` and `pn ≥ largest_acked`
and `pn < 2^62`, then the proximity conditions of `decode_pktnum_correct` hold:
- `pn ≤ largest_acked + 1 + pnHwin(pn_len)`
- `largest_acked + 1 < pn + pnHwin(pn_len)`

**Proof sketch**: By definition, `pnWin(pn_len) ≥ 2 * num_unacked =
2 * (pn - largest_acked + 1)`. So `pnHwin(pn_len) = pnWin(pn_len)/2 ≥ num_unacked
= pn - largest_acked + 1`. Therefore:
- `pn = largest_acked + num_unacked - 1 ≤ largest_acked + pnHwin(pn_len) ≤
  largest_acked + 1 + pnHwin(pn_len) - 1 ≤ largest_acked + 1 + pnHwin(pn_len)` ✓
- `pnHwin(pn_len) ≥ num_unacked = pn - largest_acked + 1 > 0`, so
  `largest_acked + 1 < pn + pnHwin(pn_len)` ✓

---

## Inferred Intent

The design intention is that QUIC packet number truncation is **transparent**:
the sender can always send the minimal encoding, and the receiver (with the
same context `largest_pn`) will always recover the original packet number.
This requires that the encode and decode functions are inverses under the
proximity assumption, which `pkt_num_len` is specifically designed to guarantee.

---

## Open Questions

- **OQ-T24-1**: `pkt_num_len` is defined with `pn.saturating_sub(largest_acked)`.
  When `pn < largest_acked` (which should not happen in correct operation),
  `num_unacked = 1`, giving `pn_len = 1`. Is this the intended behaviour, or
  should this be an error condition? The QUIC spec requires packet numbers to
  be monotonically increasing.
- **OQ-T24-2**: The `encode_pkt_num`/`decode_pkt_num` pair only models the
  truncation/reconstruction. The final packet number comparison in the receiver
  uses `decrypt_hdr`/the AEAD tag to confirm the reconstructed number is
  correct. The formal spec covers only the inner decode, not the full
  authenticated decryption loop.
- **OQ-T24-3**: `pkt_num_len` returns at most 4 (since `div_ceil(8)` of ≤32
  bits gives ≤4), but `encode_pkt_num` handles up to `pn_len = 4`. The 3-byte
  case uses `put_u24` which writes 3 bytes. The formal model in
  `PacketNumDecode.lean` uses `pn_len ∈ {1,2,3,4}` — this aligns.

---

## Notes for Lean Formalisation

- The key linking theorem is:
  `pktNumLen_satisfies_proximity (pn largest_acked : Nat) (hpn : pn < 2^62) (hle : largest_acked ≤ pn) : let n := pktNumLen pn largest_acked; pn ≤ largest_acked + 1 + pnHwin n ∧ largest_acked + 1 < pn + pnHwin n`
- The Lean model of `pkt_num_len` uses `leading_zeros` or can be formulated
  directly as: the smallest `k ∈ {1,2,3,4}` such that `2^(8*k) ≥ 2 * (pn - largest_acked + 1)`.
- The existing `decode_pktnum_correct` theorem in `PacketNumDecode.lean` can be
  invoked directly once proximity is established.
- The composition theorem combines:
  1. `pktNumLen_satisfies_proximity` (new)
  2. `decode_pktnum_correct` (existing in PacketNumDecode.lean)
  to yield `decodePktNum largest_acked (pn % pnWin pn_len) pn_len = pn`.

🔬 *Lean Squad — automated formal verification for `dsyme/quiche`.*
