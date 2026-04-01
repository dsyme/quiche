# Formal Verification — Lean ↔ Rust Correspondence

🔬 *Maintained by the Lean Squad automation.*

## Last Updated

- **Date**: 2026-03-30 10:00 UTC
- **Commit**: `e485077b`

---

## Overview

This document records, for each Lean file under `formal-verification/lean/FVSquad/`,
exactly how the Lean definitions and theorems relate to the Rust source.  For each
definition the correspondence level is one of:

| Level | Meaning |
|-------|---------|
| **exact** | Lean semantics are equivalent to the Rust semantics on all valid inputs |
| **abstraction** | Lean models a pure functional subset; effects/invariants deliberately omitted |
| **approximation** | Lean diverges from the Rust in a documented, bounded way |
| **mismatch** | Lean is incorrect — a divergence that could invalidate a proof |

---

## Known Mismatches

*None identified as of this revision.*

---

## `FVSquad/Varint.lean`

**Rust source**: `octets/src/lib.rs`

### Purpose

Models the QUIC variable-length integer (varint) codec (RFC 9000 §16).  A
varint encodes a `u64` value in 1, 2, 4, or 8 bytes depending on its magnitude,
with a 2-bit length tag in the most-significant bits of the first byte.

### Type mapping

| Lean name | Lean type | Rust name | Rust type | Correspondence |
|-----------|-----------|-----------|-----------|---------------|
| `MAX_VAR_INT` | `Nat` | *(implicit 2^62-1 bound)* | `u64` | **exact** — same numeric value |
| `varint_len_nat` | `Nat → Nat` | `varint_len` (`octets/src/lib.rs:L~187`) | `u64 → usize` | **abstraction** — Nat instead of u64; no overflow |
| `varint_parse_len_nat` | `Nat → Nat` | `get_varint` first-byte dispatch | `u8 → usize` | **abstraction** — first-byte to length, pure |
| `varint_encode` | `Nat → Option (List Nat)` | `put_varint_with_len` (`octets/src/lib.rs:L505`) | `OctetsMut → Result<&[u8]>` | **approximation** — see §Approximations |
| `varint_decode` | `List Nat → Option Nat` | `get_varint` (`octets/src/lib.rs:L187`) | `OctetsMut → Result<u64>` | **approximation** — see §Approximations |

### Approximations in Varint.lean

1. **Buffer mutation omitted**: `put_varint` mutates an `OctetsMut` cursor in
   Rust; `varint_encode` returns `Option (List Nat)`.  The I/O effects and
   offset tracking are entirely absent from the model.

2. **Bitwise OR replaced by addition**: In the Rust encoder (`put_varint_with_len`,
   lines 505–536), the 2-bit tag is written by OR-ing into the first byte
   (`buf[0] |= 0x40` etc.).  In the Lean model, the tag constant is *added*
   arithmetically.  This is semantically equivalent because the value field
   occupies the low bits and the tag the top 2 bits — they can never overlap —
   but the equivalence is asserted by comment rather than proved.

3. **`u64` → `Nat`**: All values are unbounded `Nat`.  The `v ≤ MAX_VAR_INT`
   precondition guards every theorem that would otherwise fail for large inputs.

4. **Error paths**: `varint_encode` returns `none` for `v > MAX_VAR_INT`.
   Rust returns an `Err`; the distinction (option vs result) is immaterial here
   since both signal "invalid input".

### Impact on proved theorems

| Theorem | Relies on | Risk from approximations |
|---------|-----------|--------------------------|
| `varint_round_trip` | `varint_encode`, `varint_decode` | **Low** — bitwise-OR vs addition approximation is sound for in-range values; confirmed by 25 `native_decide` concrete examples |
| `varint_encode_length` | `varint_len_nat`, `varint_encode` | **None** — purely arithmetic |
| `varint_len_nat_*` (4 lemmas) | `varint_len_nat` | **None** — no Rust coupling |
| `varint_first_byte_tag` | `varint_encode` | **Low** — the tag position arithmetic models the OR correctly by construction |

**Overall assessment for Varint.lean**: *exact* for the pure value-to-bytes
mapping; the buffer-mutation and error-propagation omissions are clearly
documented and do not affect any proved theorem.

---

## `FVSquad/RangeSet.lean`

**Rust source**: `quiche/src/ranges.rs`

### Purpose

Models the `RangeSet` data structure — a sorted, disjoint collection of
half-open `[start, end)` intervals over `u64`.  Used extensively in `quiche`
for tracking QUIC packet acknowledgement windows.

### Type mapping

| Lean name | Lean type | Rust name | Rust file/line | Correspondence |
|-----------|-----------|-----------|----------------|---------------|
| `RangeSetModel` | `List (Nat × Nat)` | `RangeSet` (enum) | `ranges.rs:L42` | **abstraction** — see §Dual representation |
| `valid_range` | `(Nat×Nat) → Prop` | *(invariant of stored ranges)* | `ranges.rs:L42` | **exact** — captures `s < e` |
| `sorted_disjoint` | `RangeSetModel → Prop` | *(maintained by all mutators)* | `ranges.rs:L42` | **abstraction** — see §Invariant |
| `in_range` | `(Nat×Nat) → Nat → Bool` | `Range::contains` | stdlib | **exact** — `s ≤ n < e` |
| `covers` | `RangeSetModel → Nat → Bool` | `flatten().any(|x| x == n)` | `ranges.rs:L140` | **exact** — membership test |
| `range_insert` | `RangeSetModel → Nat → Nat → RangeSetModel` | `RangeSet::insert` | `ranges.rs:L114` | **approximation** — see §Insert |
| `range_remove_until` | `RangeSetModel → Nat → RangeSetModel` | `RangeSet::remove_until` | `ranges.rs:L171` | **approximation** — see §Remove |

### Approximation: dual representation (abstraction)

The Rust `RangeSet` is an enum with two variants:

- `RangeSet::Inline(InlineRangeSet)` — backed by a `SmallVec` of up to 4 ranges.
- `RangeSet::BTree(BTreeRangeSet)` — backed by a `BTreeMap` for larger sets.

The Lean model uses a single `List (Nat × Nat)`, abstracting both variants.
The two Rust variants maintain the same logical invariant (sorted, disjoint)
so all proved theorems apply equally to both.  The variant-switching
`fixup` method (`ranges.rs:L170`) is not modelled; theorems apply at the
abstract level only.

### Approximation: invariant

`sorted_disjoint` requires `r_i.2 ≤ r_{i+1}.1` (non-strict gap between
consecutive ranges).  The Rust implementation merges both overlapping and
*adjacent* ranges (where `r_i.end == r_{i+1}.start`), so in practice the
stored invariant is a strict gap after any insert.  The Lean model uses `≤`
(allowing touching ranges) which is a *weaker* invariant than what Rust
maintains — our theorems are proved under this weaker assumption and therefore
still hold in the Rust setting.

### Approximation: capacity eviction (abstraction, significant)

Both Rust variants enforce a `capacity` limit.  When the set is full and a new
range is inserted, the oldest range is evicted (`inner.remove(0)`).  The Lean
model has **no capacity limit** — `range_insert` always preserves all ranges.

**Impact**: `insert_covers_union` and `insert_preserves_invariant` (both still
marked `sorry`) assert *unconditional* semantic correctness.  These theorems
would *not* hold in the Rust code when capacity eviction fires.  This is a
**known gap**: the proved theorems apply only when `len < capacity`.

### Approximation: insert (`range_insert`)

`range_insert_go` is a single-pass left-to-right scan with an accumulator,
mirroring the `InlineRangeSet::insert` loop logic.  The Rust
`BTreeRangeSet::insert` uses a BTree range lookup for O(log n) behaviour,
but the logical input/output contract is equivalent.

Key difference: the Lean model uses pattern-matched functional recursion;
the Rust uses mutable state with index-based mutation.  The accumulator
semantics are equivalent on valid (sorted_disjoint) input.

### Approximation: remove_until (`range_remove_until`)

The Lean `range_remove_until` corresponds most closely to
`InlineRangeSet::remove_until` (`ranges.rs:L254`).  The `BTreeRangeSet`
variant (`ranges.rs:L315`) uses a different algorithm (collect + re-insert)
but has the same postcondition.

Minor divergence: in `InlineRangeSet::remove_until`, a trimmed range where
`s == e` after trimming is removed (`ranges.rs:L264`).  In the Lean model,
a trimmed range satisfies `v+1 < e` (since the `e ≤ v+1` branch is dropped
first), so this edge case cannot arise — the models agree on all reachable
inputs.

**`u64` overflow edge case**: when `largest == u64::MAX`, `largest + 1`
overflows to 0 in Rust (wrapping arithmetic).  In the Lean model, `Nat`
is unbounded, so this case is not captured.  The proved theorems are
therefore valid only for `largest < 2^64 - 1`.

### Proved theorems — correspondence assessment

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|------------------------|-------|
| `empty_sorted_disjoint` | **exact** | Low | Trivial structural fact |
| `singleton_sorted_disjoint` | **exact** | Low | Trivial structural fact |
| `empty_covers_nothing` | **exact** | Low | Trivial |
| `singleton_covers_iff` | **exact** | Medium | Correct membership spec |
| `insert_empty` | **exact** | Medium | Matches `InlineRangeSet::insert` single-element case |
| `remove_until_empty` | **exact** | Low | Trivial |
| `insert_empty_covers` | **exact** | Medium | Combines two facts cleanly |
| `sorted_disjoint_tail` | **exact** | Low | Structural helper |
| `sorted_disjoint_head_valid` | **exact** | Low | Structural helper |
| `remove_until_removes_small` | **abstraction** | **High** | Core safety property: no value ≤ largest survives; u64 overflow edge case excluded |
| `remove_until_preserves_large` | **abstraction** | **High** | Liveness: covered values above threshold are retained |
| `remove_until_preserves_invariant` | **abstraction** | **High** | Invariant maintenance by remove_until |

### Sorry theorems

| Theorem | Reason | Risk |
|---------|--------|------|
| `insert_preserves_invariant` | Requires induction over `range_insert_go` with acc invariant — complex | Medium (not yet verified) |
| `insert_covers_union` | Same difficulty; additionally, does NOT hold when capacity eviction fires | **High** — would need capacity precondition |

---

## Summary

Both Lean files provide sound, useful specifications within their documented
abstractions.  The most significant gap is the capacity-eviction approximation
for `insert_*` theorems: the Lean proofs (once completed) will only be valid
when `len < capacity`.  The `remove_until` theorems are fully proved and their
correspondence to the Rust is high-fidelity, modulo the `u64::MAX` overflow
edge case.

No mismatches (where the Lean model is outright wrong) have been identified.
All known divergences are deliberate, documented approximations.
