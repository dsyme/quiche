# Informal Specification: `decode_pkt_num`

**Source**: `quiche/src/packet.rs`, lines 634–652  
**RFC Reference**: RFC 9000 Appendix A.3 — Sample Packet Number Decoding Algorithm  
**Phase**: 2 (Informal Spec)

---

## Purpose

QUIC packet headers carry a *truncated* packet number to save space: only the
low `pn_len * 8` bits of the actual packet number are transmitted.  The receiver
must reconstruct the full 62-bit packet number using its knowledge of the
largest packet number it has already received.

`decode_pkt_num` implements the RFC 9000 Appendix A.3 algorithm: given

- `largest_pn` — the largest successfully-processed packet number so far,
- `truncated_pn` — the low bits received in the header,
- `pn_len` — the number of bytes used to encode the packet number (1–4),

it returns the full 64-bit packet number.

---

## Key Definitions

Let:
- `pn_nbits  = pn_len * 8`   (8, 16, 24, or 32)
- `pn_win    = 1 << pn_nbits`  (the window size, a power of two)
- `pn_hwin   = pn_win / 2`    (half-window)
- `pn_mask   = pn_win - 1`    (low-bit mask)
- `expected_pn = largest_pn + 1`
- `candidate_pn = (expected_pn & ~pn_mask) | truncated_pn`
  — obtained by replacing the low bits of `expected_pn` with `truncated_pn`

The candidate is then adjusted by ±`pn_win` if it lies too far from `expected_pn`.

---

## Preconditions

1. `pn_len ∈ {1, 2, 3, 4}` — packet number length is 1–4 bytes.
2. `truncated_pn < pn_win` — the truncated value fits in `pn_len` bytes.
3. `largest_pn < 2^62` — packet numbers are bounded by RFC 9000 §17.1.
4. Implicit: the actual packet number being decoded lies within `pn_hwin`
   of `expected_pn` (the QUIC invariant that the sender does not skip more
   than `pn_hwin` packet numbers ahead of the receiver).

---

## Postconditions

1. **Congruence**: `result ≡ truncated_pn (mod pn_win)`.
   The low `pn_nbits` bits of the result equal `truncated_pn`.

2. **Proximity**: `|result - expected_pn| ≤ pn_hwin`.
   The result is the multiple of `pn_win` closest to `expected_pn` that
   is congruent to `truncated_pn` mod `pn_win`.

3. **Non-negative**: `result ≥ 0` (trivially satisfied in `u64` arithmetic).

4. **Overflow guard**: the upward adjustment is suppressed when
   `candidate_pn ≥ 2^62 − pn_win`, preventing the result from exceeding `2^62`.

---

## Invariants

- The algorithm chooses among exactly three candidates differing by `pn_win`:
  `candidate_pn - pn_win`, `candidate_pn`, `candidate_pn + pn_win`.
- It selects whichever lies closest to `expected_pn`, with ties broken toward
  the higher value (the `<= expected_pn` condition in branch 1).
- When `truncated_pn = (expected_pn & pn_mask)` exactly, no adjustment is
  needed and `candidate_pn = expected_pn`.

---

## Edge Cases

| Case | Behaviour |
|------|-----------|
| `pn_len = 1` | 8-bit window, `pn_win = 256`, `pn_hwin = 128` — most compact |
| `pn_len = 4` | 32-bit window, full RFC maximum |
| `largest_pn = 0` | First packet; `expected_pn = 1` |
| `truncated_pn = 0` | Low bits are zero; candidate uses upper bits of `expected_pn` |
| Large `largest_pn` near `2^62 − 1` | Overflow guard prevents upward adjustment |
| `candidate_pn < pn_win` | Downward adjustment suppressed (`candidate_pn >= pn_win` guard) |

---

## Examples

Based on the RFC and quiche test vectors:

| `largest_pn` | `truncated_pn` | `pn_len` | `expected` | `result` |
|---|---|---|---|---|
| `0xa82f30ea` | `0x9b32` | 2 | `0xa82f30eb` | `0xa82f9b32` |
| `0xac5c01` | encoded `0xac5c02` low 16 bits | 2 | `0xac5c02` | `0xac5c02` |
| `0xace9fa` | encoded `0xace9fe` low 24 bits | 3 | `0xace9fb` | `0xace9fe` |

The RFC example (§A.3): `largest_pn = 0xa82f30ea`, `truncated_pn = 0x9b32`,
`pn_len = 2` → `candidate = 0xa82f9b32`, which is within 2^15 of expected
`0xa82f30eb`, so no adjustment → result = `0xa82f9b32`.

---

## Inferred Intent

The algorithm is a nearest-neighbour decoder: it reconstructs the full
packet number as the value closest to what the receiver expects next.
This is exactly the RFC 9000 algorithm; the implementation directly
translates the RFC pseudocode.

The overflow guard (`candidate_pn < (1 << 62) - pn_win`) prevents the upward
branch from producing a packet number ≥ 2^62, which would be illegal in QUIC.
No analogous guard is needed for the downward branch because `candidate_pn >=
pn_win` already ensures the result is non-negative.

---

## Open Questions

1. **Should `pn_len = 0` be treated as a precondition violation?**  
   The current code would panic (shift by 0 then `pn_win = 1`, effectively
   no truncation), but QUIC forbids 0-byte packet numbers.

2. **Is the tie-breaking rule (toward higher values) intentional?**  
   Branch 1 uses `<=` (`candidate_pn + pn_hwin <= expected_pn`), which means
   when `candidate_pn + pn_hwin = expected_pn` exactly, the upward adjustment
   is applied. This matches the RFC but could be a surprising edge case.

3. **What is the expected behaviour when the QUIC invariant is violated?**  
   If the true packet number is more than `pn_hwin` away from `expected_pn`,
   the algorithm will silently return an incorrect result. The caller must
   ensure this doesn't happen.
