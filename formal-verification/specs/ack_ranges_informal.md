# Informal Specification: ACK Frame Acked-Range Bounds (T43)

**Target**: `parse_ack_frame` in `quiche/src/frame.rs` (lines 1257–1311)  
**Phase**: 2 — Informal specification

---

## Purpose

The QUIC ACK frame encodes a set of acknowledged packet-number ranges in a
compact wire format (RFC 9000 §19.3). The parser reconstructs a `RangeSet`
of acknowledged packet numbers from a sequence of varints encoding:

1. `largest_ack`: the highest packet number acknowledged
2. `ack_delay`: acknowledgement delay (not used in range reconstruction)
3. `block_count`: number of additional ACK blocks after the first
4. `ack_block` (first): how many packets below `largest_ack` are also acknowledged
5. For each additional block: `gap` (two-plus-gap packets skipped) and `ack_block`

Each block corresponds to a contiguous range of acknowledged packet numbers.
The blocks are encoded in strictly decreasing order; successive blocks are
separated by a minimum gap of 2 (i.e., at least one unacknowledged packet
number separates any two acknowledged ranges).

---

## Preconditions

- The `Octets` cursor `b` contains a valid wire-encoded ACK or ACK_ECN frame.
- `ty` is `0x02` (ACK) or `0x03` (ACK_ECN).
- The varint fields are well-formed (sufficient bytes remain in `b`).

---

## Postconditions

On success (`Ok(Frame::ACK { ranges, .. })`):

1. **No-underflow (first block)**: `largest_ack >= ack_block`, so
   `smallest_ack = largest_ack - ack_block` does not underflow.

2. **First range validity**: the first inserted range satisfies
   `smallest_ack <= largest_ack + 1`, i.e., it is a non-empty range.

3. **Per-additional-block no-underflow**:
   - `smallest_ack >= 2 + gap`, so `largest_ack_next = (smallest_ack - gap) - 2`
     does not underflow.
   - `largest_ack_next >= ack_block_next`, so `smallest_ack_next = largest_ack_next -
     ack_block_next` does not underflow.

4. **Strict monotone decrease**: each subsequent block's `largest_ack` is strictly
   less than the previous block's `smallest_ack` minus 1. Concretely,
   `largest_ack_next <= smallest_ack_prev - 2`.

5. **Disjointness**: no two inserted ranges overlap. This follows from the strict
   monotone decrease: if block i covers `[s_i, l_i]`, then
   `l_{i+1} <= s_i - 2 < s_i`, so `[s_{i+1}, l_{i+1}]` and `[s_i, l_i]`
   are disjoint.

6. **Bounded coverage**: every packet number in `ranges` is in the interval
   `[0, largest_ack]`.

On failure (`Err(InvalidFrame)`), the invariants are violated in the input:
- `largest_ack < ack_block`, or
- `smallest_ack < 2 + gap` for some additional block, or
- `largest_ack_next < ack_block_next` for some additional block.

---

## Invariants

### Wire-format invariants (pure model)

Given a list of `(gap, ack_block)` pairs `blocks = [(g_1, b_1), ..., (g_n, b_n)]`
and initial values `L = largest_ack`, `B = ack_block`, define the sequence:

```
s_0 = L - B                         (first smallest)
l_0 = L                             (first largest)

l_i = (s_{i-1} - g_i) - 2          (for i >= 1)
s_i = l_i - b_i                     (for i >= 1)
```

The invariant is:
- `l_0 >= B` (first block no-underflow)
- For each `i >= 1`: `s_{i-1} >= 2 + g_i` (gap no-underflow)
- For each `i >= 1`: `l_i >= b_i` (block no-underflow)
- **Strictly decreasing**: `l_i < s_{i-1}` for all `i >= 1`
  (equivalently `l_i <= s_{i-1} - 2` since integers)
- **Disjoint ranges**: `[s_i, l_i]` and `[s_j, l_j]` are disjoint for `i ≠ j`
- **Non-empty ranges**: `s_i <= l_i` for all `i`

---

## Edge Cases

| Case | Behaviour |
|------|-----------|
| `block_count = 0` | Single range `[largest_ack - ack_block, largest_ack]` |
| `ack_block = 0` | Single packet acknowledged: range `[largest_ack, largest_ack]` |
| `largest_ack = 0`, `ack_block = 0` | Acknowledges packet 0 only |
| `largest_ack < ack_block` | Returns `Err(InvalidFrame)` |
| `smallest_ack < 2 + gap` | Returns `Err(InvalidFrame)` for the offending block |
| `largest_ack_next < ack_block_next` | Returns `Err(InvalidFrame)` for the offending block |
| Maximum packet number (`2^62 - 1`) | `ack_block = 0` avoids overflow; if `ack_block > 0` the no-underflow check applies |

---

## Examples

### Single block, one packet
- Input: `largest_ack=5, ack_delay=0, block_count=0, ack_block=0`
- Result: ranges = `{[5, 6)}`

### Single block, multiple packets
- Input: `largest_ack=10, ack_delay=0, block_count=0, ack_block=3`
- Result: `smallest_ack=7`, ranges = `{[7, 11)}`

### Two blocks, no gap violation
- Input: `largest_ack=20, ack_block=4, block_count=1, gap=2, ack_block2=3`
- `s_0=16`, `l_0=20`, range0 = `[16, 21)`
- `l_1 = (16 - 2) - 2 = 12`, `s_1 = 12 - 3 = 9`, range1 = `[9, 13)`
- Result: ranges = `{[9, 13), [16, 21)}`

### Gap too large → error
- Input: `largest_ack=5, ack_block=0, block_count=1, gap=10, ...`
- `smallest_ack=5 < 2+10=12` → `Err(InvalidFrame)`

---

## Inferred Intent

The wire format guarantees that acknowledged ranges are:
- **Non-overlapping**: ensured by the gap encoding (minimum gap of 2)
- **Non-empty**: ensured by the no-underflow checks
- **In decreasing order on the wire**: enables single-pass decoding

The guards (`return Err(InvalidFrame)`) are RFC-mandated validity checks
(RFC 9000 §19.3.1): a malformed ACK frame with underflowing block arithmetic
is treated as a connection error rather than silently truncated.

### Open Questions

1. **OQ-T43-1**: Does the implementation correctly handle `largest_ack = 0`
   with `ack_block = 0`? The check `largest_ack < ack_block` would pass
   (0 < 0 is false), so `smallest_ack = 0`. This should be fine, but
   deserves a test.

2. **OQ-T43-2**: Is `block_count` bounded by the ACK frame size or is it
   allowed to be arbitrarily large? In principle a peer could send a
   malicious frame with `block_count = 2^62 - 1` and few actual bytes,
   causing the loop to terminate early when `b.get_varint()` returns an
   error. The specification does not mention an explicit cap — this may
   be a denial-of-service vector worth noting.

3. **OQ-T43-3**: The monotone-decrease bound is `l_{i+1} <= s_i - 2`
   (exactly 2 below the previous smallest). RFC 9000 §19.3.1 defines
   the gap field as counting *unacknowledged* packets between ranges,
   and uses `gap + 2` to derive the next `largest_ack`. Verifying that
   this formula matches the RFC's table precisely is in scope for the
   Lean spec.
