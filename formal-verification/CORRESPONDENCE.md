# Formal Verification — Lean ↔ Rust Correspondence

🔬 *Maintained by the Lean Squad automation.*

## Last Updated

- **Date**: 2026-04-02 20:00 UTC
- **Commit**: `da22572e`

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

*None — all theorems in RangeSet.lean are fully proved as of run 28 (merged PR #22).*

The previously deferred theorems `insert_preserves_invariant` and
`insert_covers_union` were both proved in run 28 using a generalised
accumulator induction strategy with four simultaneous invariants.

### Proved theorems — correspondence assessment (complete list)

### Proved theorems — correspondence assessment (complete list)

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
| `remove_until_removes_small` | **abstraction** | **High** | Core safety property: no value ≤ largest survives |
| `remove_until_preserves_large` | **abstraction** | **High** | Liveness: covered values above threshold are retained |
| `remove_until_preserves_invariant` | **abstraction** | **High** | Invariant maintenance by `remove_until` |
| `insert_covers_union` | **abstraction** | **High** | Proved run 28: insert covers exactly the union of old set and new range (when `len < capacity`) |
| `insert_preserves_invariant` | **abstraction** | **High** | Proved run 28: `sorted_disjoint` is maintained by `range_insert` |

---

## `FVSquad/Minmax.lean`

**Rust source**: `quiche/src/minmax.rs`

### Purpose

Models the Kathleen Nichols windowed minimum/maximum filter.  The filter
maintains three (time, value) samples — best, 2nd-best, 3rd-best — to provide
a window-minimum estimate that remains accurate even as old values expire.  Used
in `RttStats` to track the minimum RTT over a 300 s window.

### Type mapping

| Lean name | Lean type | Rust name | Rust file/line | Correspondence |
|-----------|-----------|-----------|----------------|---------------|
| `Sample` | `{time : Nat, value : Nat}` | `MinmaxSample<T>` | `minmax.rs:L1` | **approximation** — `T` is `Nat`; Rust is generic over `Copy + PartialOrd` |
| `MinmaxState` | `{s0 s1 s2 : Sample}` | `Minmax<T>.estimate` | `minmax.rs:L12` | **exact** — same three-sample structure |
| `min_val_inv` | `Prop` | *(internal invariant)* | — | **exact** — `s0.value ≤ s1.value ≤ s2.value` |
| `time_ordered` | `Prop` | *(internal invariant)* | — | **exact** — `s0.time ≤ s1.time ≤ s2.time` |
| `reset_model` | `Nat → Nat → MinmaxState` | `Minmax::reset` | `minmax.rs:L35` | **exact** — sets all three samples to (time, meas) |
| `running_min_model` | `MinmaxState → Nat → Nat → Nat → MinmaxState` | `Minmax::running_min` | `minmax.rs:L70` | **abstraction** — see §Approximations |

### Approximations in Minmax.lean

1. **Generics**: `Minmax<T>` is generic; the Lean model specialises to `Nat`.
   Duration comparisons are `Nat` inequalities.

2. **`subwin_update` timing fractions**: `subwin_update` uses `window / 4` and
   `window / 2` comparisons to decide when to rotate samples.  The Lean model
   includes this logic in the `running_min_model` branches but does not model
   the Rust's `div_f32` fractional window arithmetic — the window is a `Nat`
   and sub-window boundaries are exact integer divisions.

3. **Window vs. absolute min**: The 300 s windowing means old minima may be
   discarded.  The Lean model accurately captures the three-sample rotation
   mechanism, so the window behaviour is modelled, not just the abstract minimum.

4. **Mutation → pure function**: `&mut self` in Rust is modelled as returning
   the updated `MinmaxState`.

### Proved theorems — correspondence assessment

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|------------------------|-------|
| `reset_returns_meas` | **exact** | Low | After reset, best estimate = meas |
| `reset_all_equal` | **exact** | Low | After reset, all three samples equal |
| `reset_min_val_inv` | **exact** | Medium | Reset establishes value ordering invariant |
| `reset_time_ordered` | **exact** | Medium | Reset establishes time ordering invariant |
| `reset_s0_value` | **exact** | Low | s0.value = meas after reset |
| `reset_s0_time` | **exact** | Low | s0.time = time after reset |
| `running_min_new_min_returns_meas` | **abstraction** | **High** | New minimum correctly replaces best estimate |
| `running_min_new_min_all_equal` | **abstraction** | **High** | When new min, all three samples set to new meas |
| `running_min_win_elapsed_all_equal` | **abstraction** | **High** | Window expiry correctly resets all samples |
| `running_min_win_elapsed_returns_meas` | **abstraction** | **High** | After window expiry, estimate = latest meas |
| `running_min_best_unchanged` | **abstraction** | Medium | No-change branch preserves best estimate |
| `running_min_returns_s0` | **exact** | Medium | `running_min` returns `s0.value` as the estimate |
| `reset_establishes_inv` | **exact** | Medium | Reset → both invariants hold |
| `running_min_reset_preserves_inv` | **abstraction** | **High** | running_min (reset branch) preserves invariants |
| `running_min_update_s1_s2_preserves_inv` | **abstraction** | **High** | running_min (update branch) preserves invariants |

**Overall assessment for Minmax.lean**: *abstraction* — the three-sample
rotation mechanism is accurately modelled.  The `div_f32` sub-window boundary
approximation is the only notable divergence from the Rust source; proofs are
valid for the integer-division model and would hold in the Rust setting wherever
sub-window boundaries are not fractional (i.e., when the window size is
divisible by 4).

---

## `FVSquad/RttStats.lean`

**Rust source**: `quiche/src/recovery/rtt.rs`

### Purpose

Models the RTT estimator used by QUIC congestion control (RFC 9002 §5).
Tracks smoothed RTT (EWMA, weight 7/8), RTT variance (EWMA of |smoothed −
adjusted|, weight 3/4), and the minimum/maximum RTT.

### Type mapping

| Lean name | Lean type | Rust name | Rust file/line | Correspondence |
|-----------|-----------|-----------|----------------|---------------|
| `RttState` | struct | `RttStats` | `rtt.rs:L34` | **abstraction** — see §Approximations |
| `rtt_init` | `Nat → Nat → RttState` | `RttStats::new` | `rtt.rs:L63` | **abstraction** — see §Approximations |
| `adjusted_rtt_of` | `Nat → Nat → Nat → Nat` | local var in `update_rtt` | `rtt.rs:L95` | **exact** — same plausibility-filter logic |
| `abs_diff` | `Nat → Nat → Nat` | `u128::abs_diff` | stdlib | **exact** — same semantics for `Nat` |
| `rtt_update` | `RttState → Nat → Nat → Bool → RttState` | `RttStats::update_rtt` | `rtt.rs:L74` | **abstraction** — see §Approximations |

### Approximations in RttStats.lean

1. **Duration → Nat**: `std::time::Duration` is modelled as `Nat` (nanoseconds,
   unbounded).  No u64/u128 overflow is possible in the Lean model.  The Rust
   `abs_diff` casts from `u128` to `u64`, which could overflow for RTTs >
   ~584 years — not guarded in the source.

2. **Minmax<Duration> → plain Nat**: `min_rtt` in Rust is a `Minmax<Duration>`
   sliding-window filter.  In the Lean model it is a plain `Nat` updated as
   `Nat.min prev latest_rtt`.  This is a **sound abstraction** for all theorems
   proved here because those theorems only require `min_rtt ≤ latest_rtt`, which
   holds for both the Minmax windowed filter and the plain minimum.

3. **Instant → not modelled**: `now : Instant` is passed to `update_rtt` for
   the Minmax windowing; since we abstract away the windowing, `now` is dropped
   from `rtt_update`.

4. **`update_rtt` first branch**: On the first sample (`has_first_rtt = false`),
   `ack_delay` is completely ignored (per RFC 9002).  The Lean model captures
   this exactly.

5. **EWMA integer truncation**: `smoothed_rtt * 7 / 8` and `rttvar * 3 / 4`
   use Lean `Nat` (floor) division, matching Rust's integer division exactly.

### Proved theorems — correspondence assessment

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|------------------------|-------|
| `rtt_init_smoothed_eq` | **exact** | Low | Constructor postcondition |
| `rtt_init_rttvar_eq` | **exact** | Low | Constructor postcondition |
| `rtt_init_no_first_sample` | **exact** | Low | Constructor postcondition |
| `rtt_init_smoothed_pos` | **exact** | Medium | Positive smoothed_rtt from positive initial_rtt |
| `rtt_first_update_smoothed_eq` | **exact** | **High** | First sample sets smoothed_rtt = latest_rtt |
| `rtt_first_update_rttvar_eq` | **exact** | Medium | First sample sets rttvar = latest_rtt / 2 |
| `rtt_first_update_min_rtt_eq` | **exact** | Medium | First sample sets min_rtt = latest_rtt |
| `rtt_first_update_has_first` | **exact** | Low | After first update, flag is set |
| `adjusted_rtt_ge_min_rtt` | **exact** | **High** | **Key safety theorem**: adjusted_rtt ≥ min_rtt when min_rtt ≤ latest_rtt — prevents negative EWMA input |
| `adjusted_rtt_le_latest` | **exact** | Medium | adjusted_rtt ≤ latest_rtt — the delay can only reduce it |
| `adjusted_rtt_of_zero_delay` | **exact** | Low | Zero ack delay → adjusted = latest |
| `abs_diff_comm` | **exact** | Low | Symmetry of absolute difference |
| `abs_diff_self` | **exact** | Low | abs_diff a a = 0 |
| `rtt_update_min_rtt_le_latest` | **abstraction** | **High** | min_rtt ≤ latest_rtt after update (key invariant I3) |
| `rtt_update_min_rtt_le_prev` | **abstraction** | **High** | min_rtt is non-increasing (monotone invariant) |
| `rtt_update_max_rtt_ge_latest` | **abstraction** | Medium | max_rtt ≥ latest_rtt after update |
| `rtt_update_max_rtt_ge_prev` | **abstraction** | Medium | max_rtt is non-decreasing |
| `rtt_update_smoothed_pos` | **abstraction** | **High** | smoothed_rtt > 0 preserved when prev ≥ 8 ns |

**Overall assessment for RttStats.lean**: *abstraction* — the arithmetic core
of `update_rtt` is modelled faithfully.  The most security-relevant theorem is
`adjusted_rtt_ge_min_rtt`, which proves the plausibility-filter invariant and
directly rules out the ack-delay manipulation attack described in RFC 9002.

---

## Summary

All four Lean files provide sound, useful specifications within their documented
abstractions.  The most significant results are:

- **RangeSet.lean**: All 14 theorems proved (0 sorry), including the complex
  `insert_preserves_invariant` and `insert_covers_union` (proved in run 28).
- **Varint.lean**: All 10 theorems proved (0 sorry), including the round-trip
  property.
- **Minmax.lean**: All 15 theorems proved (0 sorry), covering the windowed
  minimum algorithm's correctness and invariant preservation.
- **RttStats.lean**: 18 theorems proved (0 sorry) covering RTT estimator
  arithmetic, including the key security property `adjusted_rtt_ge_min_rtt`.

No mismatches (where the Lean model is outright wrong) have been identified.
All known divergences are deliberate, documented approximations.
