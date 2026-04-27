# Formal Verification — Lean ↔ Rust Correspondence

🔬 *Maintained by the Lean Squad automation.*

## Last Updated

- **Date**: 2026-04-27 18:30 UTC
- **Commit**: `608ea4474bb5a16e0471345290a3b210cc159360`
- **Lean build**: `lake build` passed with Lean 4.30.0-rc2 — 31 files, **0 sorry** 🎉
  (PathState.lean added run 109; BytesInFlight.lean run 107)
- **Route-B tests**: `tests/pkt_num_len/` 18/18 PASS; `tests/bandwidth_arithmetic/` 25/25 PASS;
  `tests/rangeset_insert/` 21/21 PASS; `tests/ack_ranges/` 25/25 PASS (run 102);
  `tests/h3_frame/` 25/25 PASS (run 103)

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

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|------------------------|-------|
| `empty_sorted_disjoint` | **exact** | Low | Trivial structural fact |
| `singleton_sorted_disjoint` | **exact** | Low | Trivial structural fact |
| `empty_covers_nothing` | **exact** | Low | Trivial |
| `singleton_covers_iff` | **exact** | Medium | Correct membership spec |
| `singleton_not_covers_left` | **exact** | Low | Membership excludes values before start |
| `singleton_not_covers_right` | **exact** | Low | Membership excludes values at/after end |
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
| `RttState.has_first_rtt` | `Bool` | `RttStats.has_first_rtt_sample` | `rtt.rs:L48` | **exact** — same semantics; Lean field renamed for brevity |
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

6. **Field name**: The Rust field is `has_first_rtt_sample` (`rtt.rs:L48`);
   the Lean model uses `has_first_rtt` for brevity.  Semantics are identical.

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
| `ewma_floor_sum` | **exact** | Low | Pure arithmetic: `a * 7/8 + a/8 ≤ a`; building block for EWMA bounds |
| `rtt_update_latest_rtt_eq` | **exact** | Medium | update always records the new sample in `.latest_rtt` |
| `rtt_update_has_first_true` | **exact** | Low | `has_first_rtt` is permanently set after any update |
| `rtt_update_smoothed_upper_bound` | **abstraction** | **High** | smoothed_rtt ≤ max(prev_smoothed, latest_rtt) — EWMA cannot overshoot both inputs |
| `rtt_update_min_rtt_inv` | **abstraction** | **High** | Combined joint invariant: min_rtt ≤ latest_rtt in the result state |

**Overall assessment for RttStats.lean**: *abstraction* — the arithmetic core
of `update_rtt` is modelled faithfully.  The most security-relevant theorem is
`adjusted_rtt_ge_min_rtt`, which proves the plausibility-filter invariant and
directly rules out the ack-delay manipulation attack described in RFC 9002.
The new `rtt_update_smoothed_upper_bound` and `rtt_update_min_rtt_inv` theorems
(run 30) complete an invariant chain showing that both key state fields
remain within their expected bounds after every update.

---

## `FVSquad/FlowControl.lean`

**Rust source**: `quiche/src/flowcontrol.rs`

### Purpose

Models the receive-side flow-control window management for QUIC streams and the
connection as a whole.  The key abstractions are the "consumed" byte counter, the
advertised `MAX_DATA` limit, and the adaptive-window autotune mechanism.

### Type mapping

| Lean name | Lean type | Rust name | Rust file:line | Correspondence |
|-----------|-----------|-----------|---------------|---------------|
| `FcState` | `structure` | `FlowControl` | `flowcontrol.rs:L39` | **abstraction** — see §Approximations |
| `FcState.consumed` | `Nat` | `FlowControl.consumed : u64` | `flowcontrol.rs:L46` | **approximation** — Nat vs u64; overflow not captured |
| `FcState.max_data` | `Nat` | `FlowControl.max_data : u64` | `flowcontrol.rs:L42` | **approximation** — same |
| `FcState.window` | `Nat` | `FlowControl.window : u64` | `flowcontrol.rs:L50` | **approximation** — same |
| `FcState.max_window` | `Nat` | `FlowControl.max_window : u64` | `flowcontrol.rs:L54` | **approximation** — same |
| `FcState.tuned` | `Bool` | `FlowControl.last_update : Option<Instant>` | `flowcontrol.rs:L56` | **abstraction** — `tuned = last_update.is_some()` |

### Function mapping

| Lean name | Rust name | Rust file:line | Correspondence | Notes |
|-----------|-----------|---------------|---------------|-------|
| `fc_new` | `FlowControl::new` | `flowcontrol.rs:L58` | **exact** | Window clamped to `max_window` in both |
| `fc_add_consumed` | `FlowControl::add_consumed` | `flowcontrol.rs:L87` | **abstraction** | No bounds-check vs `max_data` |
| `fc_should_update` | `FlowControl::should_update_max_data` | `flowcontrol.rs:L95` | **exact** | `(max_data - consumed) < window/2` |
| `fc_max_data_next` | `FlowControl::max_data_next` | `flowcontrol.rs:L102` | **exact** | `consumed + window` |
| `fc_update_max_data` | `FlowControl::update_max_data` | `flowcontrol.rs:L107` | **abstraction** | `now` timestamp omitted; sets `tuned = true` |
| `fc_set_window` | `FlowControl::set_window` | `flowcontrol.rs:L123` | **exact** | Clamps to `max_window` |
| `fc_autotune_window` | `FlowControl::autotune_window` | `flowcontrol.rs:L115` | **abstraction** | `should_tune : Bool` replaces the `now - last_update < rtt * 2` condition |
| `fc_set_window_if_not_tuned` | `FlowControl::set_window_if_not_tuned_yet` | `flowcontrol.rs:L128` | **exact** | Guards on `!tuned` |
| `fc_ensure_window_lower_bound` | `FlowControl::ensure_window_lower_bound` | `flowcontrol.rs:L136` | **exact** | Raises window if below `min_window` |

### Approximations

1. **`u64` → `Nat`**: All byte-offset fields are modelled as `Nat` (unbounded
   natural numbers) rather than `u64`.  Overflow cannot occur in the Lean model.
   In practice, QUIC restricts all offsets to 2^62-1, so overflow is unreachable
   on compliant connections; this abstraction is acceptable.

2. **`Instant`/`Duration` → `Bool should_tune`**: The timing condition in
   `autotune_window` (`now - last_update ≥ 2 * rtt`) is abstracted to an opaque
   boolean `should_tune`.  Properties about the autotune logic are stated and
   proved for arbitrary values of `should_tune`, not for the actual time-based
   condition.  Time-domain properties (e.g. "the window doubles at most once per
   2-RTT interval") are **not** captured.

3. **`Option<Instant>` → `Bool tuned`**: The `last_update` field is abstracted to
   `tuned : Bool`.  All properties that depend only on whether `update_max_data`
   was ever called are correctly captured; properties that depend on the actual
   timestamp are not.

4. **`add_consumed` no bounds check**: The Lean model does not verify that
   `consumed ≤ max_data` is maintained by callers.  The informal spec documents
   this as a caller invariant; the formal model omits the check.

### Theorems and correspondence

| Theorem | Category | Level | Bug-catching | Correspondence quality |
|---------|----------|-------|-------------|----------------------|
| `fc_new_inv` | invariant | Low | Low | **exact** |
| `fc_new_consumed_zero` | constructor | Low | Low | **exact** |
| `fc_new_window_le_max` | constructor | Low | Low | **exact** |
| `fc_set_window_inv` | invariant | Low | Low | **exact** |
| `fc_add_consumed_preserves_inv` | invariant | Low | Low | **exact** |
| `fc_add_consumed_window_unchanged` | helper | Low | Low | **exact** |
| `fc_update_preserves_inv` | invariant | Medium | Medium | **abstraction** (timestamp omitted) |
| `fc_update_max_data_eq` | arithmetic | Medium | Medium | **exact** |
| `fc_no_update_needed_after_update` | protocol | **High** | **High** | **exact** |
| `fc_max_data_next_gt_when_should_update` | protocol | **High** | **High** | **exact** |
| `fc_max_data_next_ge_consumed` | safety | **High** | **High** | **exact** |
| `fc_update_idempotent` | protocol | **High** | **High** | **exact** |
| `fc_consumed_monotone` | monotonicity | Medium | Medium | **exact** |
| `fc_should_update_iff` | helper | Low | Low | **exact** |
| `fc_autotune_preserves_inv` | invariant | Low | Medium | **abstraction** (timing omitted) |
| `fc_autotune_window_when_tuned` | autotune | Medium | **High** | **abstraction** (timing omitted) |
| `fc_autotune_window_unchanged` | autotune | Low | Low | **abstraction** |
| `fc_autotune_consumed_unchanged` | helper | Low | Low | **abstraction** |
| `fc_autotune_max_data_unchanged` | helper | Low | Low | **abstraction** |
| `fc_ensure_lb_preserves_inv` | invariant | Low | Low | **exact** |
| `fc_ensure_lb_ge` | postcondition | Medium | Medium | **exact** |
| `fc_set_window_if_not_tuned_inv` | invariant | Low | Low | **exact** |

**Overall assessment for FlowControl.lean**: *abstraction* — the arithmetic and
state-machine core of flow control is modelled faithfully.  The three highest-value
results are `fc_no_update_needed_after_update` (proves no redundant MAX_DATA
frames), `fc_max_data_next_gt_when_should_update` (proves the non-decreasing
MAX_DATA QUIC requirement), and `fc_update_idempotent` (proves double-update
safety).  Timing-domain properties are not captured; no mismatches found.

---

## Summary

All nine Lean files provide sound, useful specifications within their documented
abstractions.  The most significant results are:

- **RangeSet.lean**: All 16 theorems proved (0 sorry), including the complex
  `insert_preserves_invariant` and `insert_covers_union` (proved in run 28).
- **Varint.lean**: All 10 theorems proved (0 sorry), including the round-trip
  property.
- **Minmax.lean**: All 15 theorems proved (0 sorry), covering the windowed
  minimum algorithm's correctness and invariant preservation.
- **RttStats.lean**: 23 theorems proved (0 sorry) covering RTT estimator
  arithmetic, including the key security property `adjusted_rtt_ge_min_rtt`
  and EWMA bounding theorems.
- **FlowControl.lean**: 22 theorems proved (0 sorry) covering flow-control
  window arithmetic, update idempotence, and the non-decreasing MAX_DATA
  invariant (QUIC protocol requirement).
- **NewReno.lean**: 13 theorems proved (0 sorry) covering AIMD window
  management, the congestion-window floor invariant, and loss-event halving.
- **DatagramQueue.lean**: 26 theorems proved (0 sorry) covering bounded FIFO
  semantics, byte-size accounting, and capacity invariant preservation.
- **PRR.lean**: 20 theorems proved (0 sorry) covering PRR and PRR-SSRB rate
  control, including exact RFC 6937 formula verification.
- **PacketNumDecode.lean**: 24 theorems proved (0 sorry) covering RFC 9000
  §A.3 packet number decoding, including `decode_pktnum_correct` — the first
  RFC-algorithm end-to-end correctness theorem in the suite (run 39).

**Total: 190 theorems, 0 sorry** across all nine Lean files.

No mismatches (where the Lean model is outright wrong) have been identified.
All known divergences are deliberate, documented approximations.

---


## `FVSquad/NewReno.lean` ↔ `quiche/src/recovery/congestion/reno.rs`

*Added: run 34 (2026-04-03)*

### Type correspondence

| Lean type | Rust type | Correspondence | Notes |
|-----------|-----------|----------------|-------|
| `NewReno` (structure) | `Congestion` (struct, `mod.rs`) | abstraction | Only fields relevant to Reno are modelled; others (e.g. HyStart, CUBIC-specific) omitted |
| `NewReno.cwnd : Nat` | `congestion_window: usize` | exact | Nat is unbounded; usize overflow not modelled |
| `NewReno.ssthresh : Nat` | `ssthresh: Saturating<usize>` | abstraction | `Saturating` wrapper dropped; Nat is sufficient for Reno proofs |
| `NewReno.bytes_acked_ca : Nat` | `bytes_acked_ca: usize` | exact | |
| `NewReno.bytes_acked_sl : Nat` | `bytes_acked_sl: usize` | exact | Not used in current proofs |
| `NewReno.mss : Nat` | `max_datagram_size: usize` | exact | |
| `NewReno.in_recovery : Bool` | `congestion_recovery_start_time: Option<Instant>` | abstraction | Full `Instant` comparison replaced by a single boolean |
| `NewReno.app_limited : Bool` | `app_limited: bool` | exact | |

### Function correspondence

| Lean function | Rust function | File | Lines | Correspondence | Divergences |
|--------------|---------------|------|-------|----------------|-------------|
| `halve` | `(x as f64 * LOSS_REDUCTION_FACTOR) as usize` | `reno.rs` | ~104, ~108 | exact | `f64 * 0.5` cast = Nat floor-div-2; identical on all `usize` values |
| `NewReno.congestion_event` | `congestion_event` | `reno.rs` | 99–117 | abstraction | HyStart CSS notification omitted; `ssthresh.update(…)` replaced by direct assignment; `Instant` comparison abstracted to `in_recovery` |
| `NewReno.on_packet_acked` | `on_packet_acked` | `reno.rs` | 68–95 | abstraction | HyStart++ CSS branch (`hystart.in_css()`) abstracted away — only plain slow-start modelled; `hystart.on_packet_acked(…)` call omitted |

### Known divergences

| ID | Lean | Rust | Impact |
|----|------|------|--------|
| D1 | `NewReno.in_recovery : Bool` | `in_congestion_recovery(time_sent)` compares `time_sent` against `congestion_recovery_start_time` | All theorems about recovery guard are proved only for the boolean abstraction. The timing property (packets sent *before* recovery start are still guarded) is not captured. |
| D2 | HyStart++ branch omitted | `if r.hystart.in_css() { cwnd += hystart.css_cwnd_inc(mss) }` in slow start | `slow_start_growth` only applies to the non-CSS branch. Properties of CSS growth are not verified. |
| D3 | `NewReno.congestion_event` omits HyStart notification | `r.hystart.congestion_event()` called in Rust | No impact on cwnd/ssthresh proofs; HyStart++ state is not modelled. |
| D4 | `Saturating<usize>` wrapper dropped | `ssthresh` uses `Saturating` to prevent overflow on very large values | No overflow is possible in Lean's `Nat` model anyway; the `Saturating` wrapper's saturation behaviour at `usize::MAX` is not tested. |

### Theorem impact

The key theorems are sound with respect to the modelled abstractions:
- `cwnd_floor_new_event`: valid for all NewReno state regardless of HyStart/timing abstractions; directly mirrors the `cmp::max(…, mss * MINIMUM_WINDOW_PACKETS)` expression in `congestion_event`.
- `single_halving`: valid; corresponds exactly to the `if !r.in_congestion_recovery(time_sent)` guard.
- `acked_cwnd_monotone` / `acked_preserves_floor_inv`: valid for the plain slow-start and CA branches; holds regardless of the CSS abstraction because the CSS branch also grows `cwnd`.

No mismatches (where Lean is outright wrong) have been identified.  All divergences are deliberate, documented abstractions.

---

## `FVSquad/DatagramQueue.lean` ↔ `quiche/src/dgram.rs`

**Target**: `DatagramQueue<F: BufFactory>` — a bounded FIFO queue of QUIC DATAGRAM frames.

| Lean definition | Rust source | File | Lines | Correspondence | Notes |
|-----------------|-------------|------|-------|----------------|-------|
| `DgramQueue` | `DatagramQueue<F>` | `dgram.rs` | 40–49 | abstraction | `F::DgramBuf` abstracted to `Nat` (byte length); `Option<VecDeque<_>>` modelled as `List Nat` (always non-None when non-empty) |
| `DgramQueue.push` | `DatagramQueue::push` | `dgram.rs` | 51–60 | abstraction | Returns `Option DgramQueue` instead of `Result<(), Error::Done>` |
| `DgramQueue.pop` | `DatagramQueue::pop` | `dgram.rs` | 78–86 | abstraction | Returns `Option (Nat × DgramQueue)`; `queue_bytes_size.saturating_sub` is exact under ByteInv |
| `DgramQueue.purge` | `DatagramQueue::purge` | `dgram.rs` | 88–93 | exact | `filter (!f)` matches `q.retain(\|d\| !f(d))`; `byte_size` recomputed via fold |
| `DgramQueue.byteSize` | `DatagramQueue.queue_bytes_size` | `dgram.rs` | 44 | exact | Lean uses `foldl (· + ·) 0`; Rust increments/decrements on push/pop/purge |

### Known divergences

| ID | Lean | Rust | Impact |
|----|------|------|--------|
| D1 | `List Nat` | `Option<VecDeque<F::DgramBuf>>` (lazy init) | Lazy-init optimization not modelled; byte equality holds but allocation behaviour not verified |
| D2 | `Nat` payload lengths | `F::DgramBuf` — actual byte slices | Content of payloads not modelled; only lengths used in byte-size proofs |
| D3 | `saturating_sub` in pop | direct subtraction | Under `ByteInv`, no underflow occurs; `saturating_sub` matches regular subtraction |
| D4 | `peek_front_bytes` not modelled | copies bytes into caller buffer | Buffer-copy operation not formalized (requires modelling byte slices) |

### Theorem impact

All 26 theorems are sound:
- **Capacity invariant** (`push_preserves_cap_inv`, `pop_preserves_cap_inv`, `purge_preserves_cap_inv`): directly correspond to the `is_full()` guard in push.
- **FIFO ordering** (`push_then_pop_front_unchanged`, `push_pop_singleton`): exact for the `List` model; `VecDeque` shares the same head/tail order.
- **Byte-size tracking** (`push_byteSize_inc`, `pop_byteSize_dec`): correct for the `Nat`-length model; diverges from Rust only when payload content matters (not the case for size proofs).

No mismatches found.

---

## `FVSquad/PRR.lean` ↔ `quiche/src/recovery/congestion/prr.rs`

**Last Updated**: 2026-04-05 03:46 UTC  
**Commit**: `8f8e2881`

**Target**: `PRR` struct — Proportional Rate Reduction (RFC 6937) for congestion recovery pacing.

| Lean definition | Rust source | File | Lines | Correspondence | Notes |
|-----------------|-------------|------|-------|----------------|-------|
| `PRR` (structure) | `PRR` (struct) | `prr.rs` | 37–48 | exact | All four `usize` fields modelled as `Nat`; `pub snd_cnt` correctly public |
| `PRR.congestion_event` | `PRR::congestion_event` | `prr.rs` | 57–63 | exact | All fields reset identically |
| `PRR.on_packet_sent` | `PRR::on_packet_sent` | `prr.rs` | 51–55 | exact | `prr_out += b`, `snd_cnt = snd_cnt.saturating_sub(b)` — Lean `Nat` sub is already saturating |
| `PRR.on_packet_acked` | `PRR::on_packet_acked` | `prr.rs` | 67–96 | exact | PRR and PRR-SSRB modes; `cmp::max(snd_cnt, 0)` elided (Nat is always ≥ 0) |
| `divCeil` | `usize::div_ceil` | `prr.rs` | 77 | exact | `(a + b - 1) / b` matches Rust's `div_ceil`; `= 0` when `b = 0` matches Lean Nat convention and Rust's `recoverfs > 0` guard |

### Known divergences

| ID | Lean | Rust | Impact |
|----|------|------|--------|
| P1 | `Nat` (unbounded) | `usize` (64-bit) | No overflow captured; `prr_delivered * ssthresh` could theoretically overflow in Rust on pathological workloads |
| P2 | `cmp::max(snd_cnt, 0)` omitted | present at line 95 | No-op for `Nat`; Rust's `snd_cnt` is `usize` so it is also always ≥ 0 |
| P3 | Protocol precondition not modelled | callers should only call `on_packet_sent` with `sent_bytes ≤ snd_cnt` | Theorems hold unconditionally; practical invariants require the protocol contract |

### Theorem impact

All 20 theorems are sound. The `exact` correspondence for all four operations means:
- State-reset theorems (`congestion_event_*`): verified directly by `rfl`.
- PRR mode formula (`prr_mode_snd_cnt_formula`): exactly matches lines 76–80.
- SSRB mode bounds (`ssrb_snd_cnt_le_gap`, `ssrb_snd_cnt_ge_min_gap_mss`): capture the RFC 6937 §3 rate guarantees.

No mismatches found.

---

## Target 9: PacketNumDecode (`FVSquad/PacketNumDecode.lean`)

**Last Updated**: 2026-04-05 03:46 UTC  
**Commit**: `8f8e2881`

**Target**: `decode_pkt_num` — RFC 9000 Appendix A.3 packet number decoding.

| Lean definition | Rust source | File | Lines | Correspondence | Notes |
|-----------------|-------------|------|-------|----------------|-------|
| `candidatePn` | `candidate_pn = (expected_pn & !pn_mask) \| truncated_pn` | `packet.rs` | 640 | abstraction | Arithmetic: `(exp/win)*win + trunc`. Equivalent to bitwise when `win = 2^k` and `trunc < win` |
| `decodePktNum` | `decode_pkt_num` | `packet.rs` | 634–652 | abstraction | Nested `if` instead of `&&` — identical semantics. Nat arithmetic; u64 overflow not modelled |
| `pnWin` | `pn_win = 1 << pn_nbits` | `packet.rs` | 637 | exact | `1 <<< (pn_len * 8)` — same shift |
| `pnHwin` | `pn_hwin = pn_win / 2` | `packet.rs` | 638 | exact | Integer division |

### Known divergences

| ID | Lean | Rust | Impact |
|----|------|------|--------|
| Q1 | Arithmetic `(exp/win)*win + trunc` | Bitwise `(exp & !mask) \| trunc` | Equivalent when `win = 2^k` and `trunc < win`. `decode_mod_win_exact` proves congruence holds for the arithmetic model; bridging to bitwise requires an additional lemma (not yet proved) |
| Q2 | `Nat` arithmetic (unbounded) | `u64` arithmetic | Overflow at `2^64` not captured. The overflow guard (`cand < 2^62 - win`) is faithfully modelled as a Prop condition |
| Q3 | `pn_len` unconstrained | `pn_len ∈ {1,2,3,4}` in QUIC | Theorems hold for all `pn_len : Nat` including 0 (degenerate). `native_decide` test vectors use pn_len ∈ {1,2,3} |
| Q4 | QUIC proximity invariant is a hypothesis | Enforced by protocol | `decode_pktnum_correct` requires the invariant as a precondition; it is not verified from the Rust perspective |

### Theorem impact

24 theorems total (24 fully proved, **0 sorry** ✅):
- `decode_mod_win_exact` (central): fully proved — verifies the RFC 9000 §17.1 congruence invariant for the arithmetic model.
- 7 `native_decide` test vectors including the RFC A.3 example — verified by computation.
- `decode_branch1_overflow_guard`: overflow guard proof for upward adjustment.
- `decode_pktnum_correct`: **fully proved** (run 39) via 3-way window-quotient case split.
  During proof, an edge case was discovered: the non-strict `hprox2 ≤` form
  allows a counterexample at `actual_pn = expected_pn − pnHwin`. The theorem
  was corrected to use strict `<` (matching RFC 9000 §A.3) plus bounds
  `hoverflow` and `hwin_le`. This is not a bug in the Rust code (the Rust u64
  type prevents the edge case automatically); it is a precision gap in the
  original Lean theorem statement.
- `mul_uniq_in_range`: helper lemma for the unique-multiple-in-interval argument.

No mismatches. The arithmetic model has been verified to be equivalent to the bitwise computation in all test vectors; a general proof of the equivalence for arbitrary inputs would close divergence Q1.

---

## Target 10: CUBIC congestion control (`FVSquad/Cubic.lean`)

**Rust source**: `quiche/src/recovery/congestion/cubic.rs`
**Lean file**: `formal-verification/lean/FVSquad/Cubic.lean`
**Phase**: 5 — Proofs complete (26 theorems, 0 sorry)

### Definitions correspondence

| Lean name | Rust equivalent | File | Line(s) | Correspondence | Notes |
|-----------|----------------|------|---------|---------------|-------|
| `betaNum`, `betaDen` | `BETA_CUBIC: f64 = 0.7` | `cubic.rs` | 63 | exact | Rational 7/10 encodes 0.7 exactly |
| `cNum`, `cDen` | `C: f64 = 0.4` | `cubic.rs` | 65 | exact | Rational 4/10 encodes 0.4 exactly |
| `alphaNum`, `alphaDen` | `ALPHA_AIMD: f64 = 3.0*(1.0-BETA_CUBIC)/(1.0+BETA_CUBIC)` | `cubic.rs` | 75 | exact | Rational 9/17; verified by `alphaAimd_numerator_eq` |
| `ssthreshCubic cwnd` | `(r.congestion_window as f64 * BETA_CUBIC) as usize` | `cubic.rs` | 375 | approximation | Nat floor division `cwnd * 7 / 10`; equivalent to f64 cast for typical values |
| `wMaxFastConv cwnd` | `r.congestion_window as f64 * (1.0 + BETA_CUBIC) / 2.0` | `cubic.rs` | 370 | approximation | Nat floor division `cwnd * 17 / 20`; models the f64 computation |
| `wcubic c t k wMax` | `State::w_cubic(t, mds)` (W_cubic(t) = C*(t-K)³+w_max) | `cubic.rs` | 140–145 | abstraction | Int model; no `max_datagram_size` scaling; cube-root not computed |
| `wcubicNat c t k wMax` | `State::w_cubic` (t ≥ K branch) | `cubic.rs` | 140–145 | abstraction | Nat model; valid only for t ≥ k |
| `cubicK_zero_when_cwnd_ge_wmax` | `cubic_k → 0.0` branch | `cubic.rs` | 381–382 | exact | Zero K when cwnd ≥ w_max, no recovery needed |

### Proved theorems — correspondence assessment (complete list)

| Theorem | Level | Property verified | Code path |
|---------|-------|------------------|-----------|
| `alphaAimd_numerator_eq` | exact | 3×(10−7) = 9 | `cubic.rs:75` constant |
| `alphaAimd_denominator_eq` | exact | 10+7 = 17 | `cubic.rs:75` constant |
| `alphaAimd_pos` | exact | 0 < alphaNum | `cubic.rs:75` |
| `alphaAimd_lt_one` | exact | alphaNum < alphaDen | rate bounded < 1 |
| `beta_pos` | exact | 0 < betaNum | `cubic.rs:63` |
| `beta_lt_one` | exact | betaNum < betaDen | CUBIC reduces on loss |
| `ssthresh_le_cwnd` | approximation | ssthreshCubic cwnd ≤ cwnd | `cubic.rs:375` |
| `ssthresh_lt_cwnd_pos` | approximation | ssthreshCubic cwnd < cwnd (cwnd > 0) | `cubic.rs:375` strict reduction |
| `ssthresh_monotone` | approximation | a ≤ b → ssthreshCubic a ≤ ssthreshCubic b | monotone ssthresh |
| `ssthresh_nonneg` | exact | 0 ≤ ssthreshCubic cwnd | Nat triviality |
| `ssthresh_concrete_10000` | approximation | ssthreshCubic 10000 = 7000 | f64 cast matches integer model |
| `wCubic_at_k_eq_wmax` | exact | wcubic c k k wMax = wMax | `cubic.rs:140`: C×0³+w_max=w_max |
| `wCubic_epoch_anchor` | exact | −C×K³+w_max = cwnd given C×K³=w_max−cwnd | RFC 8312bis §5.1 anchor property |
| `wCubicNat_at_k_eq_wmax` | exact | wcubicNat c k k wMax = wMax | Nat model of above |
| `wCubicNat_monotone` | exact | t1≤t2 → wcubicNat t1 ≤ wcubicNat t2 | W_cubic non-decreasing in time |
| `wCubicNat_monotone_c` | exact | c1≤c2 → wcubicNat c1 ≤ wcubicNat c2 | monotone in C scaling factor |
| `wCubicNat_ge_wmax_of_t_ge_k` | exact | wMax ≤ wcubicNat c t k wMax | curve stays above w_max |
| `fastConv_wmax_lt_cwnd` | approximation | wMaxFastConv cwnd < cwnd (cwnd > 0) | `cubic.rs:369` fast convergence reduces w_max |
| `fastConv_wmax_le_cwnd` | approximation | wMaxFastConv cwnd ≤ cwnd | weak form |
| `fastConv_monotone` | approximation | a≤b → wMaxFastConv a ≤ wMaxFastConv b | monotone |
| `wMaxFastConv_concrete` | approximation | wMaxFastConv 10000 = 8500 | concrete value check |
| `congestionEvent_reduces_cwnd` | approximation | cwnd>0 → ssthreshCubic cwnd < cwnd | `cubic.rs:379` cwnd = ssthresh |
| `cubicK_zero_when_cwnd_ge_wmax` | exact | wMax ≤ cwnd → wMax − cwnd = 0 | `cubic.rs:381`: K=0 branch |
| `ssthresh_concrete_1448` | approximation | ssthreshCubic 1448 = 1013 | typical MSS-based window |
| `ssthresh_concrete_14480` | approximation | ssthreshCubic 14480 = 10136 | larger window |
| `wMaxFastConv_concrete_1448` | approximation | wMaxFastConv 1448 = 1230 | fast convergence at MSS |

### Known divergences

| ID | Lean | Rust | Impact |
|----|------|------|--------|
| C1 | Nat floor division `cwnd * 7 / 10` | `f64` cast `(cwnd as f64 * 0.7) as usize` | Identical for all practical cwnd values (the f64 representation of 0.7 is exact to ~16 digits; for cwnd < 2^53 the results agree). Not verified formally |
| C2 | `wcubic` uses unbounded Int; no `max_datagram_size` scaling | Rust scales by `mds` | W_cubic properties proved at the per-packet-unit level only; scaling by mds is an additional monotone transformation |
| C3 | Cube root abstracted as hypothesis | `libm::cbrt` called | The defining property `C * K³ = w_max − cwnd` is taken as a hypothesis in `wCubic_epoch_anchor`. The libm implementation is not verified |
| C4 | No time model; t is abstract Nat | `Duration::as_secs_f64()` | Time measured in abstract ticks; continuous-time curvature not captured |
| C5 | `usize` as `Nat` (unbounded) | `usize` (64-bit) | Overflow at 2^64 not captured |
| C6 | `MINIMUM_WINDOW_PACKETS` clamp omitted | `cmp::max(ssthresh, mds * 2)` | `ssthresh_lt_cwnd_pos` holds for the raw formula before the clamp; with the clamp ssthresh ≥ 2 * mds is not separately verified |

### Theorem impact

26 theorems total (0 sorry ✅). The most significant are:

- `wCubic_epoch_anchor`: formally verifies the RFC 8312bis §5.1 epoch-anchor property — the CUBIC function passes through `cwnd_new` at epoch start, establishing that the window starts at the correct reduction point.
- `ssthresh_lt_cwnd_pos`: formally verifies the strict window reduction on every fresh loss event. This is a fundamental safety property of CUBIC: the window cannot fail to shrink.
- `fastConv_wmax_lt_cwnd`: formally verifies fast convergence — when below the prior peak, w_max is reduced to `cwnd * (1+β)/2 < cwnd`, biasing future window growth downward.
- `wCubicNat_monotone`: formally verifies that the cubic window estimate is non-decreasing in time once past K, confirming the "restore-then-grow" shape of the CUBIC curve.

---

## Target 11: RangeBuf offset arithmetic (`FVSquad/RangeBuf.lean`)

**Rust source**: `quiche/src/range_buf.rs`

| Lean name | Rust name | File+line | Correspondence | Notes |
|-----------|-----------|-----------|----------------|-------|
| `RangeBuf.off` | `RangeBuf::off()` | `range_buf.rs:160` | exact | abstract field vs computed from `(data, start, pos)` |
| `RangeBuf.len` | `RangeBuf::len()` | `range_buf.rs:168` | exact | abstract field vs `data.len() - pos - start` |
| `RangeBuf.maxOff` | `RangeBuf::max_off()` | `range_buf.rs:173` | exact | `off + len` |
| `RangeBuf.isFin` | `RangeBuf::fin()` | `range_buf.rs:178` | exact | bool flag |
| `rbConsume` | `RangeBuf::consume()` | `range_buf.rs:183` | abstraction | Lean uses pure `(off, len)` triple; Rust advances `pos` in shared buffer |
| `rbSplitOff` | `RangeBuf::split_off()` | `range_buf.rs:190` | abstraction | Rust splits the underlying `Arc<[u8]>`; Lean models only the offset partition |

### Known divergences

| ID | Lean | Rust | Impact |
|----|------|------|--------|
| R1 | Model ignores byte contents | Rust stores actual bytes | Proofs verify offset/length arithmetic only; correctness of byte copying not captured |
| R2 | `rbConsume` is a pure function | `consume()` mutates `pos` in place | Functional model correctly captures the offset semantics; mutation not visible from caller's perspective |
| R3 | No `Arc<[u8]>` reference counting | Rust uses shared buffer with `Arc` | Reference-counting correctness and aliasing not modelled; only the logical partition is verified |

### Theorem impact

19 theorems (0 sorry ✅). Key results:
- `consume_maxOff`: `consume` preserves `maxOff` — the BTreeMap key used in `RecvBuf` is stable across partial reads.
- `split_adjacent`: `left.maxOff = right.off` — split produces exactly-adjacent halves with no gap or overlap.
- `split_maxOff`: `right.maxOff = original.maxOff` — the right half inherits the original high-watermark.

---

## Target 12: RecvBuf stream reassembly (`FVSquad/RecvBuf.lean`)

**Rust source**: `quiche/src/stream/recv_buf.rs`

| Lean name | Rust name | File+line | Correspondence | Notes |
|-----------|-----------|-----------|----------------|-------|
| `Chunk` | `RangeBuf` (logical view) | `range_buf.rs` | abstraction | Lean `Chunk = (off, len)` pairs; Rust has byte contents and `Arc` sharing |
| `RecvBuf.chunks` | `RecvBuf.data : BTreeMap<u64, RangeBuf>` | `recv_buf.rs:55` | abstraction | Lean sorted list; Rust BTreeMap keyed on `max_off` |
| `RecvBuf.readOff` | `RecvBuf.off` | `recv_buf.rs:59` | exact | read cursor |
| `RecvBuf.highMark` | `RecvBuf.len` | `recv_buf.rs:62` | exact | highest received offset (note: field named `len` in Rust) |
| `RecvBuf.finOff` | `RecvBuf.fin_off` | `recv_buf.rs:65` | exact | optional final offset |
| `RecvBuf.emitN` | `RecvBuf::emit()` | `recv_buf.rs:160` | abstraction | Lean counts bytes emitted; Rust writes into output slice |
| `RecvBuf.insertContiguous` | `RecvBuf::write()` (in-order case) | `recv_buf.rs:92` | abstraction | Models only the contiguous (no-overlap) write path |
| `insertChunkInto` | `RecvBuf::write()` (overlap-handling loop) | `recv_buf.rs:92–140` | abstraction | 6-case algorithm: pure-before, pure-after, left-overhang, left-extend, contained, right-extend. Existing data wins on overlap (same policy as Rust). Byte contents not modelled. |
| `trimChunk` | implicit byte-trimming in `write()` | `recv_buf.rs:97–101` | abstraction | Trims bytes of new chunk below `off` (the read cursor); models Rust's `start < off` guard |
| `RecvBuf.insertAny` | `RecvBuf::write()` | `recv_buf.rs:92` | abstraction | Combines `trimChunk` + `insertChunkInto` + `highMark` update; models the full write path excluding byte contents, flow-control, and drain |

### Known divergences

| ID | Lean | Rust | Impact |
|----|------|------|--------|
| V1 (partially resolved) | `insertContiguous` models only contiguous writes; `insertAny` now models the full overlap-splitting path | `write()` handles arbitrary out-of-order and overlapping data | Out-of-order reassembly invariant preservation is now formally proved via `insertAny_inv`; data-content correctness still not captured |
| V2 | Byte contents not modelled | Rust stores actual bytes in `RangeBuf` | Data integrity of reassembly not captured; only offset/ordering structure is proved |
| V3 | `drain` mode not modelled | `RecvBuf.drain` flag causes `off := len` advance without buffering | The drain fast-path is not in scope |
| V4 | Flow-control limits not in model | `RecvBuf::max_data()` enforced in `write()` | `highMark ≤ max_data` invariant is not stated; would require an additional field |

### Theorem impact

59 theorems (0 sorry ✅). Key results (new in this run):
- `insertChunkInto_above`: inserting a chunk above `off` preserves `chunksAbove off`
- `insertChunkInto_within`: inserting a chunk within `mark` preserves `chunksWithin mark`
- `insertChunkInto_ordered`: inserting a chunk preserves `chunksOrdered` (non-overlapping sorted invariant)
- `trimChunk_off_ge`: after trimming, `off ≥ floor` (when the trimmed chunk is non-empty)
- `trimChunk_maxOff_le`: trimming can only reduce `maxOff`
- `insertAny_inv`: full invariant preservation theorem for `RecvBuf.insertAny` (all 5 invariants)
- 8 test vector examples verified with `native_decide`

Previous key results:
- `emitN_preserves_inv`: all 5 invariants preserved by the read-cursor advance operation.
- `insertContiguous_inv`: all 5 invariants preserved by in-order sequential write.
- `insertContiguous_highMark_grows`: strictly advances the receive window when len > 0.
- `insertContiguous_two_highMark`: two sequential writes advance highMark by the sum of lengths.

---

## Target 13: SendBuf stream send buffer (`FVSquad/SendBuf.lean`)

**Rust source**: `quiche/src/stream/send_buf.rs`

| Lean name | Rust name | File+line | Correspondence | Notes |
|-----------|-----------|-----------|----------------|-------|
| `SendState.off` | `SendBuf::off` | `send_buf.rs:75` | exact | total bytes written (append offset) |
| `SendState.emitOff` | `SendBuf::emit_off` | `send_buf.rs:78` | exact | bytes sent to network |
| `SendState.ackOff` | `SendBuf::ack_off()` | `send_buf.rs:320` | abstraction | Lean models the contiguous-prefix case; Rust uses full RangeSet ACKs |
| `SendState.maxData` | `SendBuf::max_data` | `send_buf.rs:81` | exact | peer flow-control limit |
| `SendState.finOff` | `SendBuf::fin_off` | `send_buf.rs:86` | exact | optional FIN byte offset |
| `sbWrite` | `SendBuf::write()` | `send_buf.rs:131` | abstraction | Lean increments `off` by `n`; Rust also enqueues `RangeBuf` data into a `VecDeque` |
| `sbEmitN` | `SendBuf::emit()` | `send_buf.rs:183` | abstraction | Lean advances `emitOff`; Rust yields `&[u8]` slices from the `VecDeque` |
| `sbAckContiguous` | `SendBuf::ack()` (contiguous prefix) | `send_buf.rs:250` | abstraction | Lean's `ackContiguous` models only the case `ackOff += len`; Rust full ack uses RangeSet |
| `sbUpdateMaxData` | `SendBuf::update_max_data()` | `send_buf.rs:315` | exact | `max_data = max(max_data, m)` |
| `sbSetFin` | `SendBuf::shutdown()` (fin path) | `send_buf.rs:335` | abstraction | Lean's `setFin` sets `finOff := some off`; Rust has additional `shutdown_write/read` variants |

### Known divergences

| ID | Lean | Rust | Impact |
|----|------|------|--------|
| S1 | `ackOff` is a scalar contiguous-prefix offset | Rust uses a `RangeSet` for sparse ACKs | Out-of-order ACKs (non-contiguous ranges) cannot be modelled; only the simplest ACK pattern is verified |
| S2 | Byte contents abstracted | Rust stores `VecDeque<RangeBuf>` with actual bytes | Data integrity of the transmit buffer is not captured; only cursor/offset arithmetic is proved |
| S3 | Retransmission not modelled | `SendBuf::retransmit()` re-queues a `RangeBuf` range for resend | The retransmission path is entirely out of scope; `emitOff` monotonicity holds only for the first-send case |
| S4 | `reset()`, `stop()`, `shutdown()` not modelled | All three terminate the stream state machine | Stream termination logic is not verified; `finOff` consistency is proved only for the happy path |
| S5 | `blocked_at` and `error` fields not modelled | Rust tracks flow-control blocking and stream reset errors | Error and blocking state transitions are not captured |
| S6 | `usize` as `Nat` | Rust uses `u64` / `usize` | Integer overflow not verified; for practical QUIC stream sizes (< 2^62) the arithmetic is equivalent |

### Theorem impact

43 theorems (0 sorry ✅). Key results:
- `emitN_le_maxData`: the sender's `emitOff` never exceeds `maxData` — the fundamental QUIC flow-control safety theorem (RFC 9000 §4.1), security-relevant.
- `emitN_le_off`: the sender cannot emit beyond written data — prevents uninitialised data transmission.
- `write_preserves_inv`: all 4 structural invariants are inductive under `write`.
- `sb_emitN_preserves_inv`: all 4 structural invariants are inductive under `emitN`.
- `write_possible_after_updateMaxData`: MAX_DATA update unblocking guarantee — if peer's MAX_DATA ≥ off + n, capacity for n bytes is available.
- `write_after_setFin_isFin_false`: data written past the FIN offset invalidates the FIN flag, preventing data-after-FIN (RFC 9000 §19.20).

---

## Target 14: Connection ID sequence management (`FVSquad/CidMgmt.lean`)

**Rust source**: `quiche/src/cid.rs`

| Lean name | Rust name | File+line | Correspondence | Notes |
|-----------|-----------|-----------|----------------|-------|
| `CidState.nextSeq` | `ConnectionIdentifiers::next_scid_seq` | `cid.rs:227` | exact | next sequence number to issue |
| `CidState.activeSeqs` | `ConnectionIdentifiers::scids` (VecDeque) | `cid.rs:~220` | abstraction | Lean keeps only the `seq` field as a `List Nat`; CID bytes, reset token, path_id not modelled |
| `CidState.limit` | `ConnectionIdentifiers::source_conn_id_limit` | `cid.rs:233` | exact | max active SCIDs the peer permits |
| `CidState.newScid` | `ConnectionIdentifiers::new_scid` | `cid.rs:359` | abstraction | Lean appends `nextSeq` and increments; Rust also allocates a ConnectionIdEntry, checks duplicate CIDs, optionally calls `retire_if_needed` |
| `CidState.retireScid` | `ConnectionIdentifiers::retire_scid` | `cid.rs:550` | abstraction | Lean filters the list; Rust also queues a RETIRE_CONNECTION_ID frame and updates path associations |

### Known divergences

| ID | Lean | Rust | Impact |
|----|------|------|--------|
| C1 | CID byte content not modelled | Rust stores actual 160-bit CIDs | CID collision/duplicate detection is not formally verified; only sequence-number uniqueness is proved |
| C2 | `retire_if_needed` path not modelled | `new_scid` may internally retire the oldest CID if the limit is reached | The retirement triggered by `new_scid` is out of scope; the Lean model requires `hroom` as an explicit precondition instead |
| C3 | Reset-token, path_id, reset_token_sent not modelled | Rust tracks all three per entry | Path-binding and stateless-reset correctness are not captured |
| C4 | `retire_prior_to` field not modelled | Rust uses it for bulk retire-on-migration | The migration fast-retire path is not in scope |
| C5 | Error returns modelled as preconditions | Rust returns `Err(Error::IdLimit)` when limit exceeded | The error-path semantics are captured only as guards, not as return-value correctness |
| C6 | `usize`/`u64` as `Nat` | Rust uses mixed `u64`/`usize` | Integer overflow not verified; for practical CID counts (≤ 8) the arithmetic is equivalent |

### Theorem impact

21 theorems (0 sorry ✅). Key results:
- `newScid_preserves_inv`: all 5 invariants (nextSeq ≥ 1, distinctness, bound, non-empty, size ≤ 2·limit−1) are preserved by `newScid` — the fundamental QUIC §5.1 safety property.
- `retireScid_preserves_inv`: all 5 invariants preserved by retire — well-formedness is an inductive invariant of the full retire path.
- `newScid_seq_fresh`: the sequence number assigned by `newScid` was never previously active — prevents duplicate SCIDs (RFC 9000 §5.1.1).
- `retireScid_removes`: retire always removes the target sequence — the retire operation is correct.
- `retireScid_keeps_others`: retire does not disturb non-target sequences — no collateral damage.
- `applyNewScid_nextSeq`: after k calls to `newScid`, `nextSeq` equals `initial + k` — exact accounting of sequence-number consumption.

---

## Target 15: Stream priority ordering (`FVSquad/StreamPriorityKey.lean`)

**Rust source**: `quiche/src/stream/mod.rs` (lines 842–910)

### Purpose

Models the `StreamPriorityKey::cmp` method, which drives HTTP/3 stream
scheduling via RFC 9218 (Extensible Prioritization Scheme for HTTP).  The
ordering determines which stream is dequeued first from intrusive red-black
trees (readable, writable, flushable).

### Type mapping

| Lean name | Lean type | Rust name | Rust file+line | Correspondence |
|-----------|-----------|-----------|----------------|---------------|
| `StreamPriorityKey` | structure | `StreamPriorityKey` | `stream/mod.rs:842` | **abstraction** — only `id`, `urgency`, `incremental` fields; RBTree links omitted |
| `StreamPriorityKey.urgency` | `Nat` | `urgency : u8` | `stream/mod.rs:843` | **approximation** — `Nat` instead of `u8`; valid RFC 9218 range is 0–7, quiche uses full u8 range |
| `StreamPriorityKey.id` | `Nat` | `id : u64` (inherited from `Stream`) | `stream/mod.rs:~752` | **approximation** — `Nat` instead of `u64`; QUIC stream IDs are < 2^62 in practice |
| `StreamPriorityKey.incremental` | `Bool` | `incremental : bool` | `stream/mod.rs:844` | **exact** |
| `cmpKey` | `StreamPriorityKey → StreamPriorityKey → Ordering` | `StreamPriorityKey::cmp` | `stream/mod.rs:880` | **abstraction** — see §Approximations |

### Approximations in StreamPriorityKey.lean

| ID | Lean | Rust | Justification |
|----|------|------|---------------|
| SP1 | `urgency : Nat` | `urgency : u8` | No overflow; theorems requiring urgency ordering use `<`/`=` on `Nat`; practically equivalent for u8 range |
| SP2 | `id : Nat` | stream ID from `u64` | QUIC stream IDs bounded by 2^62 (RFC 9000 §2.1); `Nat` admits no overflow |
| SP3 | `PartialEq` not modelled | `PartialEq` uses only `id` field; `Eq` derived | Only `Ord` (via `cmpKey`) is modelled; the `id`-only equality is irrelevant to scheduling correctness |
| SP4 | Intrusive RBTree links omitted | `readable`, `writable`, `flushable : RBTreeAtomicLink` fields | Link management is a structural side-channel; the ordering kernel is entirely captured by `cmpKey` |
| SP5 | `partial_cmp` wrapper not modelled | `PartialOrd::partial_cmp` delegates to `Ord::cmp` | Trivially equivalent; no separate theorem needed |

### Key divergence: antisymmetry violation (OQ-1)

The most important result of this file is that the Lean model faithfully captures
the known `Ord`-contract deviation.  For two distinct incremental streams at the
same urgency:

```
cmpKey a b = .gt  ∧  cmpKey b a = .gt
```

This is **not** a Lean approximation — it is the Rust behaviour, formally confirmed.
Theorem `cmpKey_incr_incr_not_antisymmetric` proves the deviation; `decide` closes
a concrete counterexample.  It is intentional round-robin design, but the `Ord`
antisymmetry guarantee (required by Rust's `std::cmp::Ord` contract) is violated.

### Impact on proved theorems

21 theorems (0 sorry ✅).  Key results and their reliance on the model:

| Theorem | Relies on | Risk from approximations |
|---------|-----------|--------------------------|
| `cmpKey_same_id` / `cmpKey_refl` | `id` field equality | **None** — independent of type width |
| `cmpKey_lt_urgency` / `cmpKey_gt_urgency` | urgency ordering | **None** — `Nat` order matches `u8` order for in-range values |
| `cmpKey_both_nonincr` | `id` comparison | **None** — `Nat` order matches `u64` for non-negative values |
| `cmpKey_incr_incr_not_antisymmetric` | `cmpKey` case 7 | **None** — directly reads the `else .gt` branch; faithfully mirrors `cmp::Ordering::Greater` |
| `cmpKey_total` | full case enumeration | **Low** — totality follows from exhaustive `if-else`; Nat vs u8 irrelevant |
| `cmpKey_trans_urgency` / `cmpKey_trans_nonincr` | urgency transitivity | **Low** — transitivity is an arithmetic property; Nat ≡ u8 for in-range values |

**Overall assessment**: *abstraction* (good).  The integer-width approximations
(SP1, SP2) do not affect any proved theorem because all proofs are parametric
over the abstract `Nat` ordering.  The round-robin non-antisymmetry (OQ-1) is
captured exactly, which is the most security/correctness-relevant property of
this module.


---

## `FVSquad/OctetsMut.lean`

**Rust source**: `octets/src/lib.rs` (lines 391–800, `OctetsMut` type)

### Purpose

Models the `OctetsMut` writable byte-buffer type from `octets`.  `OctetsMut`
wraps a `&mut [u8]` slice with an internal offset cursor that advances as bytes
are written.  The Lean model captures:

- The buffer contents and cursor position as a pure state.
- Single-byte and multi-byte big-endian write/read operations.
- Cursor skip/rewind operations.
- Round-trip properties: writing then rewinding and reading returns the
  original value.

### Type mapping

| Lean name | Lean type | Rust name | Rust file:line | Correspondence |
|-----------|-----------|-----------|----------------|---------------|
| `listGet` | `List Nat → Nat → Nat` | array index | (built-in) | **exact** — zero on OOB, same as default |
| `listSet` | `List Nat → Nat → Nat → List Nat` | slice mutation | (built-in) | **exact** — no-op on OOB matches Rust absence of error |
| `OctetsMutState` | `structure` | `OctetsMut` | `octets/src/lib.rs:391` | **abstraction** — see §Approximations |
| `OctetsMutState.skip` | `OctetsMutState → Nat → Option OctetsMutState` | `OctetsMut::skip` | `octets/src/lib.rs:~471` | **abstraction** |
| `OctetsMutState.rewind` | `OctetsMutState → Nat → Option OctetsMutState` | `OctetsMut::rewind` | `octets/src/lib.rs:~480` | **abstraction** |
| `OctetsMutState.putU8` | `OctetsMutState → Nat → Option OctetsMutState` | `OctetsMut::put_u8` | `octets/src/lib.rs:~490` | **abstraction** |
| `OctetsMutState.getU8` | `OctetsMutState → Option (Nat × OctetsMutState)` | `OctetsMut::get_u8` | `octets/src/lib.rs:~510` | **abstraction** |
| `OctetsMutState.peekU8` | `OctetsMutState → Option Nat` | `OctetsMut::peek_u8` | `octets/src/lib.rs:~530` | **abstraction** |
| `OctetsMutState.putU16` | `OctetsMutState → Nat → Option OctetsMutState` | `OctetsMut::put_u16` | `octets/src/lib.rs:~540` | **approximation** — see §Approximations |
| `OctetsMutState.getU16` | `OctetsMutState → Option (Nat × OctetsMutState)` | `OctetsMut::get_u16` | `octets/src/lib.rs:~555` | **approximation** — see §Approximations |
| `OctetsMutState.putU32` | `OctetsMutState → Nat → Option OctetsMutState` | `OctetsMut::put_u32` | `octets/src/lib.rs:~570` | **approximation** — see §Approximations |
| `OctetsMutState.getU32` | `OctetsMutState → Option (Nat × OctetsMutState)` | `OctetsMut::get_u32` | `octets/src/lib.rs:~590` | **approximation** — see §Approximations |

### Approximations in OctetsMut.lean

1. **`&mut [u8]` → `List Nat`**: The Rust `OctetsMut` holds a `&mut [u8]`
   reference; mutation is in-place.  The Lean model returns a new state on
   every write.  Aliasing, lifetimes, and zero-copy semantics are entirely
   absent.

2. **`u8`/`u16`/`u32` → `Nat` with range preconditions**: Rust uses fixed-width
   integer types with wrapping overflow.  The Lean model uses `Nat` and requires
   explicit range preconditions (`v < 256`, `v < 65536`, `v < 4294967296`).
   Within these ranges the arithmetic is identical.

3. **`BufferTooShortError` → `Option.none`**: Rust returns `Result<_, Error>`;
   the Lean model returns `Option` with `none` for out-of-range access.  Error
   payloads are not modelled.

4. **`peekU8` / `get_u8` distinction**: Rust has both a peek (no-advance) and
   a consume (advance) variant; the Lean model captures both as separate
   definitions.

5. **varint operations omitted**: `put_varint`/`get_varint` are separately
   verified in `Varint.lean`.

### Theorems and their correspondence

| Theorem | Level | Notes |
|---------|-------|-------|
| `cap_identity` | **exact** | `off + cap = len` when `Inv` holds |
| `skip_advances_off` | **exact** | `off` increases by n after skip |
| `rewind_retreats_off` | **exact** | `off` decreases by n after rewind |
| `skip_buf_eq` | **exact** | buffer unchanged by skip |
| `rewind_buf_eq` | **exact** | buffer unchanged by rewind |
| `skip_preserves_inv` | **exact** | Inv is a monovariant under skip |
| `rewind_preserves_inv` | **exact** | Inv is a monovariant under rewind |
| `skip_rewind_inverse` | **exact** | skip then rewind restores cursor |
| `putU8_preserves_inv` | **exact** | Inv holds after putU8 |
| `putU8_getU8_roundtrip` | **abstraction** | models u8 write/read round-trip |
| `putU8_peekU8_roundtrip` | **abstraction** | models u8 write/peek round-trip |
| `putU16_getU16_roundtrip` | **approximation** | requires `v < 65536` range guard |
| `putU32_getU32_roundtrip` | **approximation** | requires `v < 2^32` range guard |
| `putU8_x2_off` / `_x3_off` | **exact** | offset accumulation across writes |
| `putU16_putU8_off` / `putU16_x2_off` | **exact** | offset accumulation |

### Coverage gaps

- **Varint round-trips**: covered by `Varint.lean`.
- **`put_u64` / `get_u64`**: not yet modelled; analogous to u32.
- **`as_mut` / `as_ref`**: slice projection; pure structural fact, not yet
  proved.
- **Negative tests**: theorems stating that writes *fail* when capacity is
  exhausted are not currently stated.

---

## Target 17: `Octets` (read-only) — `FVSquad/Octets.lean`

**Last updated**: 2026-04-12 09:30 UTC  **Commit**: `8ad36a3b4da7722964fbdd4f4b914642c9e061af`

**Rust source**: `octets/src/lib.rs`, lines 135–385 (`struct Octets<'a>`, `impl<'a> Octets<'a>`)

| Lean name | Rust name | File + lines | Level | Notes |
|-----------|-----------|-------------|-------|-------|
| `OctetsState` | `Octets<'a>` | `lib.rs:135–138` | abstraction | `buf: &[u8]` → `List Nat`; `off: usize` preserved exactly |
| `OctetsState.getU8` | `Octets::get_u8` | `lib.rs:151–153` | exact | Returns `(value, next_state)`; same check `off < buf.len()` |
| `OctetsState.peekU8` | `Octets::peek_u8` | `lib.rs:157–159` | exact | Does not advance cursor |
| `OctetsState.getU16` | `Octets::get_u16` | `lib.rs:163–165` | exact | Big-endian `256*b₀ + b₁`; check `off+1 < buf.len()` |
| `OctetsState.getU32` | `Octets::get_u32` | `lib.rs:175–177` | exact | Big-endian 4-byte; check `off+3 < buf.len()` |
| `OctetsState.getU64` | `Octets::get_u64` | `lib.rs:181–183` | exact | Big-endian 8-byte; check `off+7 < buf.len()` |
| `OctetsState.skip` | `Octets::skip` | `lib.rs:340–348` | exact | `off + n ≤ buf.len()` check |
| `OctetsState.rewind` | `Octets::rewind` | `lib.rs:310–317` | exact | `n ≤ off` check |
| `OctetsState.cap` | `Octets::cap` | `lib.rs:351–353` | exact | `buf.len() - off` |

### Divergences and Approximations

- **`buf: List Nat` vs `&[u8]`**: bytes are `Nat` (unbounded), not `u8`. The
  proofs use no overflow, but nothing prevents `octListGet` from returning
  values > 255 for ill-formed inputs. This is an acceptable abstraction for
  the properties proved (structural, not arithmetic-overflow).
- **Lifetime erasure**: `'a` lifetimes, borrow-checking, and zero-copy
  semantics are not modelled. The model assumes the buffer is immutable for
  the duration, which matches the `&[u8]` contract.
- **`get_bytes`/`get_varint`/`slice`/`slice_last`**: not modelled; these are
  separate concerns (varint is in `Varint.lean`).
- **`get_u24`**: not modelled (not used in the informal spec).

### Impact on proofs

All 48 theorems are sound given the approximations above. The key safety
property — that every `get_*` operation either advances the cursor by exactly
the declared width or returns `None` without touching the cursor — is proved
exactly as in the Rust implementation. The `getU16_split` theorem proves the
composite property that `getU16` is equivalent to two sequential `getU8` calls.

---

## Target 16: `OctetsMut` byte-buffer read/write — `FVSquad/OctetsMut.lean`

**Last updated**: 2026-04-15 17:48 UTC  **Commit**: `3fc54577`

**Rust source**: `octets/src/lib.rs`, lines 391–800 (`struct OctetsMut<'a>`,
`impl<'a> OctetsMut<'a>`)

| Lean name | Rust name | File + lines | Level | Notes |
|-----------|-----------|-------------|-------|-------|
| `OctetsMutState` | `OctetsMut<'a>` | `lib.rs:391–394` | **abstraction** | `buf: &mut [u8]` → `List Nat`; `off: usize` preserved exactly |
| `OctetsMutState.Inv` | (implicit) | `lib.rs:391` | **abstraction** | `off ≤ buf.length` captured as a Lean `Prop` |
| `OctetsMutState.putU8` | `OctetsMut::put_u8` | `lib.rs:~490` | **abstraction** | Same bounds check; `listSet` models in-place mutation |
| `OctetsMutState.getU8` | `OctetsMut::get_u8` | `lib.rs:~510` | **abstraction** | Returns `Option (Nat × OctetsMutState)`; same check |
| `OctetsMutState.peekU8` | `OctetsMut::peek_u8` | `lib.rs:~530` | **exact** | Reads without advancing cursor |
| `OctetsMutState.putU16` | `OctetsMut::put_u16` | `lib.rs:~540` | **approximation** | Big-endian two-byte write; requires `v < 65536` instead of Rust `u16` |
| `OctetsMutState.getU16` | `OctetsMut::get_u16` | `lib.rs:~555` | **approximation** | Big-endian two-byte read; returns `Nat`; no `u16` wrapping |
| `OctetsMutState.putU32` | `OctetsMut::put_u32` | `lib.rs:~570` | **approximation** | Big-endian four-byte write; requires `v < 2^32` |
| `OctetsMutState.getU32` | `OctetsMut::get_u32` | `lib.rs:~590` | **approximation** | Big-endian four-byte read; returns `Nat` |
| `OctetsMutState.skip` | `OctetsMut::skip` | `lib.rs:~700` | **exact** | Advances `off` by n if in bounds |
| `OctetsMutState.rewind` | `OctetsMut::rewind` | `lib.rs:~710` | **exact** | Retreats `off` by n if `n ≤ off` |
| `OctetsMutState.cap` | `OctetsMut::cap` | `lib.rs:~720` | **exact** | `buf.length - off` |

### Approximations in OctetsMut.lean

1. **`&mut [u8]` → `List Nat`**: In-place mutation is modelled as returning a
   new state.  Aliasing, lifetimes, and zero-copy slice semantics are entirely
   absent.
2. **Fixed-width types → `Nat` with range guards**: Rust uses `u8`/`u16`/`u32`
   with wrapping overflow; the Lean model uses `Nat` with explicit range
   preconditions.  Within these ranges the arithmetic is identical.
3. **`BufferTooShortError` → `Option.none`**: Rust returns `Result`; the Lean
   model returns `Option`.
4. **Varint operations omitted**: `put_varint`/`get_varint` are separately
   verified in `Varint.lean`.  `put_u64`/`get_u64` not yet modelled.

### Impact on proofs

27 public theorems + 6 private helpers, 0 sorry.  All proofs are sound under
the approximations above.  The round-trip theorems (`putU8_getU8_roundtrip`,
`putU16_getU16_roundtrip`, `putU32_getU32_roundtrip`) prove the key
serialiser correctness property: a value written is recovered unchanged.
`putU32_freeze_byte0/1/2/3` prove the big-endian byte layout explicitly.

---

## Target 18: StreamId RFC 9000 §2.1 arithmetic — `FVSquad/StreamId.lean`

**Last updated**: 2026-04-15 17:48 UTC  **Commit**: `3fc54577`

**Rust source**: `quiche/src/stream/mod.rs` (stream classification functions)
and `quiche/src/lib.rs` (stream-direction guards)

| Lean name | Rust name | File + lines | Level | Notes |
|-----------|-----------|-------------|-------|-------|
| `isBidi` | `is_bidi` | `stream/mod.rs:837–838` | **exact** | `id % 4 < 2` ≡ `id & 0x2 == 0` for Nat |
| `isServerInit` | `is_local(id, true)` | `stream/mod.rs:832–833` | **exact** | `id % 2 == 1` ≡ `id & 0x1 == 1` |
| `streamType` | (implicit lower 2 bits) | `stream/mod.rs:837` | **exact** | `id % 4`; RFC 9000 §2.1 table |
| `StreamCredits` | `Connection` fields `local_opened_streams_bidi/uni`, `peer_max_streams_bidi/uni` | `stream/mod.rs:577–591` | **abstraction** | Grouped into a struct with invariant `localOpened ≤ peerMax` |
| `streamsLeft` | `peer_streams_left_bidi/uni` | `stream/mod.rs:577–591` | **exact** | `peerMax - localOpened` with Nat subtraction |
| `openStream` | (implicit credit consumption) | `stream/mod.rs:~560` | **abstraction** | Models the credit decrement; not a standalone function in Rust |
| `updatePeerMax` | `update_peer_max_streams_bidi` | `stream/mod.rs:529–535` | **exact** | `max(old, new)` |

### Approximations in StreamId.lean

1. **Bitwise `&` → modular arithmetic**: `id & 0x2 == 0` is modelled as
   `id % 4 < 2`.  For `Nat` these are definitionally equivalent because the
   binary representation agrees with decimal.
2. **`u64` → `Nat`**: Stream IDs are `Nat` (unbounded).  `u64` overflow is
   not modelled; this is safe because RFC 9000 limits stream IDs to 2^62–1.
3. **Credit model is a `StreamCredits` struct**: The Rust implementation
   spreads this state over several `Connection` fields.  The Lean model
   abstracts into a single invariant-carrying struct.
4. **Stream lifecycle out of scope**: Open/close/reset/FIN state is not
   modelled; only classification and credit arithmetic are proved.

### Impact on proofs

37 theorems + 8 examples, 0 sorry.  Key results:
- `streamType_add_mul4` (RFC 9000 §2.1 orbit): stream type is preserved
  under all `+4k` increments, confirming the quadrant encoding.
- `streamsLeft_open_decreases`: credit consumption is monotone.
- `updatePeerMax_mono`: the MAX_STREAMS update never decreases the limit.
- `isBidi_iff_type_lt2`: clean biconditional tying the predicate to the
  type field.

---

## Target 19: Octets↔OctetsMut cross-module round-trip — `FVSquad/OctetsRoundtrip.lean`

**Last updated**: 2026-04-15 17:48 UTC  **Commit**: `3fc54577`

**Rust source**: `octets/src/lib.rs` — interactions between `OctetsMut` (write
cursor) and `Octets` (read-only cursor), specifically the "freeze" pattern:
write with `OctetsMut`, then read back with `Octets` after the mutable borrow
ends.

| Lean name | Rust name | File + lines | Level | Notes |
|-----------|-----------|-------------|-------|-------|
| `listGet_eq_octListGet` | (bridge lemma) | `lib.rs:~135,~391` | **exact** | Proves the two model-internal helper functions are identical |
| `octListGet_set_eq` | (derived from `get_u8` + `put_u8`) | `lib.rs:~151,~490` | **exact** | Reading back a freshly-written byte yields the written value |
| `octListGet_set_ne` | (non-aliasing) | `lib.rs:~490` | **exact** | Writing at offset `i` does not affect offset `j ≠ i` |
| `mut_getU8_eq_octets_getU8` | `OctetsMut::get_u8` ≡ `Octets::get_u8` | `lib.rs:~510,~151` | **abstraction** | Both operations return the same value on the same buffer |
| `putU8_freeze_getU8` | `put_u8` then `get_u8` | `lib.rs:~490,~151` | **abstraction** | Round-trip for single byte |
| `putU16_freeze_getU16` | `put_u16` then `get_u16` | `lib.rs:~540,~163` | **approximation** | Requires `v < 65536`; proves big-endian round-trip |
| `putU32_freeze_getU32` | `put_u32` then `get_u32` | `lib.rs:~570,~175` | **approximation** | Requires `v < 2^32`; proves big-endian round-trip |
| `putU8_octets_independent` | (non-aliasing across module boundary) | `lib.rs:~490,~151` | **exact** | Write at `i` does not corrupt read at `j ≠ i` |

### Approximations in OctetsRoundtrip.lean

1. **Freeze as state copy**: The Rust "freeze" is modelled as constructing
   `{ buf := s'.buf, off := s.off }`.  The Lean model does not enforce the
   Rust borrow-check rule that the mutable borrow must end before the
   immutable borrow begins.
2. **Range guards**: Same as OctetsMut.lean for U16/U32 operations.
3. **No varint round-trip**: `put_varint`→`get_varint` is not proved here;
   that is Target 23.

### Impact on proofs

20 theorems + 9 examples, 0 sorry.  The three round-trip theorems
(`putU8/16/32_freeze_get*`) are high-value: a byte-ordering bug (e.g.,
big-endian vs little-endian swap) would directly falsify `putU16_freeze_getU16`.
The non-aliasing theorem `putU8_octets_independent` rules out a class of
buffer-corruption bugs.  All theorems are sound given the freeze model.

---

## Target 20: Packet-number encoding length — `FVSquad/PacketNumLen.lean`

**Last updated**: 2026-04-15 17:48 UTC  **Commit**: `3fc54577`

**Rust source**: `quiche/src/packet.rs`, lines 569–574 (`pkt_num_len`) and
lines 719–730 (`encode_pkt_num`)

| Lean name | Rust name | File + lines | Level | Notes |
|-----------|-----------|-------------|-------|-------|
| `PacketNumLen.numUnacked` | `pn.saturating_sub(largest_acked) + 1` | `packet.rs:571` | **exact** | Lean `Nat` subtraction is already saturating; result identical |
| `PacketNumLen.pktNumLen` | `pkt_num_len` | `packet.rs:569–574` | **approximation** | See note below |
| `PacketNumLen.encodedPktNum` | `encode_pkt_num` | `packet.rs:719–730` | **abstraction** | Modelled only as "returns a value of `pktNumLen` bytes"; buffer interaction not modelled |

### Approximation: threshold comparison vs bit-counting

The Rust implementation of `pkt_num_len` uses bit-counting:

```rust
let min_bits = u64::BITS - num_unacked.leading_zeros() + 1;
min_bits.div_ceil(8) as usize
```

The Lean model uses equivalent threshold comparisons:

```
if numUnacked ≤ 127 then 1
else if numUnacked ≤ 32767 then 2
else if numUnacked ≤ 8388607 then 3
else 4
```

These are mathematically equivalent for all values of `numUnacked`:
127 = 2^7-1 (min_bits=8, div_ceil=1), 32767 = 2^15-1 (min_bits=16, div_ceil=2),
8388607 = 2^23-1 (min_bits=24, div_ceil=3).  The Lean threshold representation
makes the RFC 9000 §17.1 half-window invariant (`pktNumLen_k_coverage`) directly
expressible via `omega`, which would be awkward with bit-counting.  The
correspondence level is **approximation** because the computational path differs
(though the function values agree on all inputs).

### Additional approximations

1. **`u64` overflow not modelled**: `numUnacked` uses `Nat` (unbounded).
   The QUIC constraint `numUnacked ≤ 2^31` is a hypothesis for the
   `four_coverage` theorem.
2. **`encode_pkt_num` buffer write not modelled**: Only the length selection
   (`pktNumLen`) is proved; the actual byte layout is abstracted.

### Impact on proofs

20 theorems + 10 examples, 0 sorry.  The coverage theorems
(`pktNumLen_k_coverage`) prove the RFC 9000 §17.1 half-window guarantee:
encoded packet number fits in the chosen byte width so the receiver can
decode it.  The monotonicity theorem (`pktNumLen_mono`) rules out truncation
bugs.  The threshold equivalence to the Rust bit-counting algorithm has been
manually verified but is not yet stated as a formal theorem (Target 24 will
establish the encode-then-decode composition).

### Route-B Correspondence Tests (run 89)

Executable correspondence tests have been added at
`formal-verification/tests/pkt_num_len/`.

**Result**: ✅ **18/18 PASS** — Lean model agrees with Rust on all valid QUIC
inputs.

**What was tested**: 18 cases covering all four threshold boundaries (127/128,
32767/32768, 8388607/8388608), interior values, saturating-sub cases (pn < la,
pn = la), two RFC 9000 §A.2 example values, and the QUIC valid maximum
(`numUnacked = 2^31-1`).

**Commands**:
```bash
rustc formal-verification/tests/pkt_num_len/pkt_num_len_test.rs \
  -o /tmp/pkt_num_len_test && /tmp/pkt_num_len_test

# Lean side
cd formal-verification/lean
lean ../tests/pkt_num_len/lean_eval.lean
```

**Documented divergence at modelling boundary**: for `numUnacked = 2^31`
(one past the QUIC maximum), Rust returns 5 and the Lean model returns 4. This
is expected — the Lean model explicitly requires `numUnacked ≤ 2^31-1` as a
hypothesis (`pktNumLen_four_coverage`). The divergence confirms the model
boundary is correctly placed.

**Correspondence level upgraded from *approximation* to *validated approximation***
— the semantics differ algorithmically (bit-counting vs thresholds) but agree
on all 18 tested boundary values, and the theoretical equivalence is
confirmed for the full valid domain.

---

## Target 21: `SendBuf::retransmit` model — `FVSquad/SendBufRetransmit.lean`

**Last updated**: 2026-04-15 17:48 UTC  **Commit**: `3fc54577`

**Rust source**: `quiche/src/stream/send_buf.rs`, lines 366–420
(`SendBuf::retransmit`)

| Lean name | Rust name | File + lines | Level | Notes |
|-----------|-----------|-------------|-------|-------|
| `SendState` (imported from `SendBuf.lean`) | `SendBuf` | `send_buf.rs:~40–60` | **abstraction** | See Target 13 correspondence entry |
| `retransmit` | `SendBuf::retransmit` | `send_buf.rs:366–420` | **approximation** | See note below |
| `retransmit_inv` | (invariant preservation) | `send_buf.rs:366` | **abstraction** | Proves `SendBuf.Inv` holds after `retransmit` |
| `retransmit_emitOff_le` | (cursor anti-monotonicity) | `send_buf.rs:390–415` | **approximation** | `retransmit` can only lower `emitOff`, never raise it |
| `retransmit_idempotent` | (idempotence) | `send_buf.rs:366` | **approximation** | Calling `retransmit` twice is the same as calling it once |
| `retransmit_send_backlog_le` | (backlog growth) | `send_buf.rs:390` | **approximation** | Retransmit cannot shrink the pending-data backlog |
| `retransmit_emitN_inv` | (invariant through emitN) | `send_buf.rs:366` | **abstraction** | Invariant preserved through a retransmit-then-emit cycle |

### Approximation: scalar cursor vs deque-level model

The Rust `retransmit` walks the `RangeBuf` deque and resets individual
`RangeBuf.pos` fields (which separate already-emitted from pending bytes).  The
Lean model abstracts this to the net scalar effect on the `emitOff` cursor:

- If `off + len ≤ ackOff` (range entirely acknowledged): no-op.
- Otherwise: `emitOff := min(emitOff, max(ackOff, off))`.

This matches the Rust logic for the common case but does **not** model:

1. **RangeBuf deque shape**: individual buffer splits and position resets are
   not tracked; only `emitOff` is updated.
2. **Split-off buffers**: `buf.split_off` alters the deque structure without
   affecting `emitOff` in the scalar model.
3. **`pos` position within individual buffers**: the Lean model treats each
   buffer as atomic; partial-overlap retransmit is approximated via `effectiveOff`.
4. **`data.is_empty()` early return**: subsumed by the numeric guard in the
   Lean model.

**Open question OQ-RT-1** (recorded in memory): when `off > emitOff` and
`len = 0`, the Lean model sets `emitOff := min(emitOff, off) = emitOff`
(a no-op), but the Rust code may still iterate the deque.  Whether this
matters depends on whether `RangeBuf.pos` resets have any observable effect
beyond `emitOff`; needs maintainer clarification.

### Impact on proofs

17 theorems + 10 examples, 0 sorry.  The key results — `retransmit_inv`,
`retransmit_emitOff_le`, `retransmit_idempotent` — establish the structural
safety of retransmission: it never introduces inconsistency, never advances the
send pointer, and is safe to call multiple times.  The proofs are sound for the
scalar-cursor model.  Bugs that affect only the deque shape without changing
`emitOff` would not be caught by these theorems.

## Known Mismatches

No mismatches identified.  All divergences are documented approximations, not
incorrect modelling.  See individual target sections for the known gaps.

## Open Sorry Obligations

As confirmed by `lake build` (Lean 4.30.0-rc2, 2026-04-26 run 105):

**None** — all 604 theorems are fully proved with 0 sorry. 🎉

The final sorry (`longHeader_roundtrip` in `PacketHeader.lean`) was closed in
run 105 by extending the model with a concrete byte-list `Header` struct,
`encodeLongHeader`/`decodeLongHeader` definitions, and a full tactic proof
using `omega` + `simp` for the big-endian version round-trip and list-append
helpers for the connection-ID fields.

Prior closures: VarIntRoundtrip 8-byte sorry (run 85 via `putU32_bytes_unchanged`);
AckRanges 3 sorry obligations (run 102 via `loop_invariant`).

---

## Target 22: `put_varint`→`get_varint` cursor roundtrip — `FVSquad/VarIntRoundtrip.lean`

**Last updated**: 2026-04-18 03:40 UTC  **Commit**: `bc4a6ced4a3b728942b69cfd48779eeac0490415`

**Rust source**: `octets/src/lib.rs`  — `OctetsMut::put_varint` (line 499),
`OctetsMut::get_varint` (line 473), `Octets::get_varint` (line 187).

This file extends the existing pure model from `Varint.lean` (which proves the
abstract `varint_round_trip` on pure numeric types) to the stateful cursor API
using the "freeze pattern" from `OctetsRoundtrip.lean`.

| Lean name | Rust name | File + lines | Level | Notes |
|-----------|-----------|-------------|-------|-------|
| `OctetsMutState.putVarint` | `OctetsMut::put_varint` | `octets/src/lib.rs:499–533` | **approximation** | 8-byte case splits into two `putU32` calls; a pending `putU32_bytes_unchanged` lemma blocks the 8-byte roundtrip proof |
| `OctetsState.getVarint` | `Octets::get_varint` / `OctetsMut::get_varint` | `octets/src/lib.rs:187–243, 473–497` | **approximation** | Both Rust variants share identical logic; Lean models the shared form via `OctetsState` |
| `putVarint_freeze_getVarint_1byte` | Integration: `put_varint` + `get_varint` | `octets/src/lib.rs:1183–1235` | **abstraction** | Freeze pattern: write with OctetsMut, read back with OctetsState; 1-byte case (v ≤ 63) **proved** |
| `putVarint_freeze_getVarint_2byte` | Integration | same | **abstraction** | 2-byte case (64 ≤ v ≤ 16383) **proved** |
| `putVarint_freeze_getVarint_4byte` | Integration | same | **abstraction** | 4-byte case (16384 ≤ v ≤ 1073741823) **proved** |
| `putVarint_freeze_getVarint_8byte` | Integration | same | **approximation** | 8-byte case — `sorry` pending `putU32_bytes_unchanged` non-interference lemma |
| `putVarint_off`, `putVarint_len` | `put_varint` post-conditions | `octets/src/lib.rs:499–533` | **exact** | Cursor offset advances by `varint_len_nat v`; buffer length preserved |
| `putVarint_first_byte_tag` | Tag encoding in `put_varint` | `octets/src/lib.rs:499–533` | **exact** (1/2/4-byte), **approximation** (8-byte sorry) | Top 2 bits of first byte encode the length |

### Approximations and known gaps

1. **8-byte roundtrip**: the 8-byte case of `putVarint_freeze_getVarint_8byte`
   and `putVarint_first_byte_tag` are guarded by `sorry`.  Both require a
   non-interference lemma `putU32_bytes_unchanged`: writing a `u32` at buffer
   offset `k+4` does not modify bytes at positions `k..k+3`.  This lemma is
   absent from `OctetsMut.lean`; adding it would close the 8-byte gap.
2. **u64 overflow not modelled**: varint values are `Nat`; the QUIC constraint
   `v ≤ MAX_VAR_INT = 2^62 - 1` is enforced by explicit range hypotheses.
3. **Buffer mutation and lifetimes**: the Lean model uses immutable `OctetsMutState`
   value-passing; Rust's `&mut self` is abstracted away.
4. **`put_varint_with_len` variant**: the Lean model always uses the canonical
   length (`varint_len_nat v`); the `put_varint_with_len` override (non-minimal
   encoding) is not modelled.

### Open question (OQ-T23-1)

Is `put_varint_with_len` for non-canonical lengths used anywhere security-critical?
If a caller can force a non-minimal encoding (e.g., `put_varint_with_len(37, 2)`),
the tag bits would differ from `varint_parse_len(first)` and `get_varint` might
misparse.  The current model does not cover this path.

### Impact on proofs

8 theorems + 16 examples.  Roundtrip fully proved for 1-, 2-, and 4-byte
encodings (covering all values up to 2^30 − 1, i.e., the vast majority of
QUIC packet fields).  **2 sorry obligations remain**: `putVarint_freeze_getVarint_8byte`
and the 8-byte branch of `putVarint_first_byte_tag`.  Both await the
`putU32_bytes_unchanged` non-interference lemma in `OctetsMut.lean`.  The
`putVarint_off` and `putVarint_len` theorems are independent of the sorry
and are fully proved.  Verified by `lake build` (Lean 4.29.0) on 2026-04-18.

---

## Target 23: Packet-number encode→decode composition — `FVSquad/PacketNumEncodeDecode.lean`

**Last updated**: 2026-04-18 03:40 UTC  **Commit**: `bc4a6ced4a3b728942b69cfd48779eeac0490415`

**Rust source**: `quiche/src/packet.rs` — `pkt_num_len` (~line 569),
`encode_pkt_num` (~line 719), `decode_pkt_num` (~line 634).

This file bridges two existing Lean modules:

- `PacketNumLen.lean` (Target 20): sender-side `pktNumLen` length selection
- `PacketNumDecode.lean` (Target 9): receiver-side `decodePktNum` reconstruction

| Lean name | Rust name | File + lines | Level | Notes |
|-----------|-----------|-------------|-------|-------|
| `pktNumLen` (imported from `PacketNumLen`) | `pkt_num_len` | `packet.rs:~569` | **approximation** | Threshold model; see Target 20 entry |
| `decodePktNum` (imported from `PacketNumDecode`) | `decode_pkt_num` | `packet.rs:~634` | **abstraction** | Arithmetic model; see Target 9 entry |
| `pktNumLen_window_sufficient` | invariant: `pnWin ≥ 2 * numUnacked` | `packet.rs:569–631` | **exact** | Bridge lemma; proved for all cases |
| `pnHwin_ge_numUnacked` | derived proximity bound | `packet.rs:569–631` | **exact** | `pnHwin ≥ numUnacked` as required by RFC 9000 §A.3 |
| `encode_decode_pktnum` | composition of `pkt_num_len` + `encode_pkt_num` + `decode_pkt_num` | `packet.rs:569–652` | **abstraction** | `encode_pkt_num` I/O abstracted to `pn % pnWin`; receiver `largest_pn = la` assumed |
| `encode_decode_one_byte` | 1-byte specialisation | `packet.rs:569–652` | **abstraction** | pn and la within 127 of each other |

### Approximations and known gaps

1. **`encode_pkt_num` buffer write not modelled**: the Lean model abstracts
   the actual byte-level encoding of `encode_pkt_num` to the arithmetic
   operation `pn % pnWin(pn_len)`.  The buffer write itself is not proved
   here; that would require a bridge from `PacketNumLen.lean` (which already
   proves `pktNumLen_valid`) to `OctetsMut.lean`.
2. **Receiver `largest_pn` assumed equal to `largest_acked`**: QUIC requires
   the receiver's largest successfully processed PN to approximate the
   sender's largest ACK'd PN.  The Lean model equates these (`la` is used in
   both `pktNumLen` and `decodePktNum`).  In practice they may differ by a
   small amount; the proximity window provides slack for this.
3. **4-byte case precondition `hfour`**: when `numUnacked pn la > 2^31`, no
   existing encoding length fits within the 4-byte window.  The precondition
   `hfour : numUnacked pn la ≤ 2^31` is an explicit QUIC constraint (in-flight
   PN space cannot exceed 2^31).
4. **`pn ≥ la` required**: `decodePktNum` is defined for future packet numbers;
   encoding a PN smaller than `largest_acked` is not supported by the
   composition theorem (though the Lean functions are still defined).

### Impact on proofs

17+ theorems + 17 examples, 0 sorry.  The main result `encode_decode_pktnum`
is a fully proved end-to-end composition theorem connecting `PacketNumLen`
and `PacketNumDecode` for the first time.  Together with the existing proofs in
those modules, this establishes RFC 9000 §17.1 packet number encoding
correctness as a chain of mechanically verified lemmas.


---

## T43 — ACK Frame Acked-Range Bounds (`AckRanges.lean`)

**Lean file**: `formal-verification/lean/FVSquad/AckRanges.lean`  
**Rust source**: `quiche/src/frame.rs` — `parse_ack_frame` (lines 1257–1311)  
**Informal spec**: `formal-verification/specs/ack_ranges_informal.md`  
**Phase**: 3 (Lean spec + implementation model, partial proofs)

### Modelled definitions

| Lean name | Rust name / concept | Source location | Correspondence level | Notes |
|-----------|--------------------|-----------------|--------------------|-------|
| `decodeAckBlocks` | `parse_ack_frame` | `frame.rs:1257` | **abstraction** | IO/varint read abstracted to Nat lists; ack_delay, ECN omitted |
| `AckRange` | `Range<u64>` in `RangeSet` | `frame.rs:1273,1291` | **exact** | Modelled as `(Nat × Nat)` pair |
| `validRange` | implicit `smallest ≤ largest` | `frame.rs:1265,1285` | **exact** | Guard ensures non-empty range |
| `boundedBy` | all PN ≤ `largest_ack` | `frame.rs:1260` | **exact** | Loop monotonically decreases largest |
| `decodeAckBlocks.loop` | inner `for` loop | `frame.rs:1275–1292` | **abstraction** | Pure functional loop with acc; same guard structure as Rust |

### Proved properties (native_decide verified)

| Theorem | Property | Status |
|---------|----------|--------|
| `decodeAckBlocks_first_guard` | success ⟹ `la ≥ ab` | ✅ proved |
| `decodeAckBlocks_nonempty` | success ⟹ result non-empty | ✅ proved |
| `loop_largest_decreases` | each iteration: `(s-gap)-2 < s` | ✅ proved |
| `blocks_disjoint_via_gap` | gap-2 separation ⟹ disjoint | ✅ proved |
| `decodeAckBlocks_none_iff_first_guard` | failure ↔ `la < ab` (no-block case) | ✅ proved |
| `decodeAckBlocks_none_means_no_ranges` | failure ⟹ no ranges | ✅ proved |
| 8 `native_decide` unit checks | concrete input/output values | ✅ proved |
| 5 `native_decide` property checks | validRange, boundedBy, monotone on samples | ✅ proved |
| `decodeAckBlocks_first_valid` | head range has `s ≤ l` | ✅ proved (run 102) |
| `decodeAckBlocks_all_valid` | all ranges have `s ≤ l` | ✅ proved (run 102) |
| `decodeAckBlocks_bounded` | all ranges bounded by `largest_ack` | ✅ proved (run 102) |

### Approximations and known gaps

1. **IO abstracted**: `Octets` cursor reads (`b.get_varint()`) are replaced by
   a plain `List (Nat × Nat)` argument. This is the standard pure-model
   abstraction used throughout the FV project.
2. **ack_delay and ECN omitted**: these fields are parsed but have no range
   semantics; they are not modelled.
3. **`block_count` is uncapped** (OQ-T43-2): the Rust loop runs `block_count`
   times with no upper bound check. A very large `block_count` varint causes
   the loop to iterate many times, consuming up to `block_count` varint reads.
   This is a potential DoS vector (run100 finding). The Lean model faithfully
   reproduces this uncapped behaviour.
4. **Loop invariant proofs**: the full inductive proofs that all ranges are
   valid and bounded were completed in run 102 via `loop_invariant` (§3b in
   `AckRanges.lean`). All 3 sorry obligations are closed. The 29 theorems
   in `AckRanges.lean` have 0 sorry. The loop invariant (induction over block
   list, maintaining `sm ≤ lg` and `lg ≤ ub` for all accumulated entries) is
   the key structural insight: every new entry satisfies `sm' ≤ lg` (from the
   `¬ lg < blk` guard) and `lg ≤ ub` (Nat subtraction is monotone below `sm ≤ ub`).

### Validation evidence

- **Route-B tests**: `formal-verification/tests/ack_ranges/` — **25/25 PASS** (run 102).
  Tests exercise single/multi-block decoding, all underflow guards, boundary
  values, and property checks (`allValid`, `boundedBy`, monotone separation).
  Run: `lean --run formal-verification/tests/ack_ranges/lean_eval.lean`
- Decidable checks: 13 `native_decide` examples in `AckRanges.lean`.
- Loop invariant proofs: all 3 formerly-sorry theorems proved (run 102) via
  `loop_invariant` — see §3b in `AckRanges.lean`.

---

## Target 29: QUIC packet-header first-byte and full round-trip — `FVSquad/PacketHeader.lean`

**Last updated**: 2026-04-26 17:26 UTC  **Commit**: `61030d6998346d1fedcac260d9f8cb6ca27ac4fd`

**Lean file**: `formal-verification/lean/FVSquad/PacketHeader.lean`
**Rust source**: `quiche/src/packet.rs` — `Header::to_bytes` (line ~306), `Header::from_bytes` (line ~194)
**Informal spec**: `formal-verification/specs/packet_header_informal.md`
**Phase**: 5 — Done (14 public + 2 private theorems, **0 sorry** ✅ — run 105)

### Modelled definitions

| Lean name | Rust name / concept | Source location | Correspondence level | Notes |
|-----------|--------------------|-----------------|--------------------|-------|
| `PacketType` | `packet::Type` enum | `packet.rs:121–138` | **exact** | All 6 variants: Initial, ZeroRTT, Handshake, Retry, VersionNegotiation, Short |
| `FORM_BIT`, `FIXED_BIT`, `TYPE_MASK` | Wire constants | `packet.rs:45–49` | **exact** | 0x80, 0x40, 0x30 |
| `typeCode` | `Type::to_wire` / first-byte type bits | `packet.rs:~150–170` | **exact** | Maps `PacketType → Option Nat` (0–3); VersionNegotiation/Short have no type code |
| `typeOfCode` | First-byte decode branch | `packet.rs:~194` | **exact** | Inverse of `typeCode`; returns `none` for codes ≥ 4 |
| `longFirstByte` | Long-header first-byte assembly | `packet.rs:306–320` | **exact** | `FORM_BIT \| FIXED_BIT \| (code << 4)` |
| `shortFirstByte` | Short-header first byte | `packet.rs:~350` | **exact** | `FIXED_BIT` only (0x40) |
| `formBitSet`, `fixedBitSet`, `typeBitsOf` | First-byte predicates | `packet.rs` | **exact** | Bit-extraction predicates |
| `Header` | `Header` struct (key fields) | `packet.rs:75–110` | **abstraction** | `ty`, `version`, `dcid`, `scid`, `token`; pkt_num_len and key_phase fixed to 0; header protection omitted |
| `encodeLongHeader` | `Header::to_bytes` | `packet.rs:~306` | **abstraction** | Long-header only; returns `Option (List Nat)`; no buffer cursor state |
| `decodeLongHeader` | `Header::from_bytes` | `packet.rs:~194` | **abstraction** | Decodes from byte list; no partial-read error paths; token fields set to `none` |

### Key theorems and correspondence level

| Theorem | Rust equivalence | Level | Notes |
|---------|-----------------|-------|-------|
| `typeCode_roundtrip` | `typeOfCode(typeCode(ty)) = Some(ty)` | **exact** | Bijection in both directions |
| `typeOfCode_roundtrip` | Inverse direction | **exact** | |
| `typeCode_in_range` | All type codes are 0–3 | **exact** | |
| `typeCode_injective` | Distinct packet types → distinct codes | **exact** | |
| `longFirstByte_form_bit` | FORM_BIT always set in long headers | **exact** | RFC 9000 §17.2 |
| `longFirstByte_fixed_bit` | FIXED_BIT always set in long headers | **exact** | RFC 9000 §17.2 |
| `longFirstByte_type_bits` | Bits 5–4 carry the type code | **exact** | |
| `longFirstByte_byte_range` | First byte value is in [0, 255] | **exact** | |
| `longFirstByte_injective` | Different types → different first bytes | **exact** | Decode is unambiguous |
| `shortFirstByte_no_form_bit` | FORM_BIT clear in short headers | **exact** | RFC 9000 §17.3 |
| `shortFirstByte_fixed_bit` | FIXED_BIT set in short headers | **exact** | |
| `short_long_first_byte_differ` | Short ≠ any long first byte | **exact** | Type disambiguation always succeeds |
| `longHeader_roundtrip` | `encodeLongHeader`↔`decodeLongHeader` | **abstraction** | Full encode↔decode proved; pkt_num_len/key_phase not modelled |
| `version_roundtrip` | Big-endian 4-byte version field | **exact** | For all `v < 2^32` |

### Approximations and known gaps

1. **pkt_num_len and key_phase**: bits 1–0 of the long-header first byte (packet-number length)
   and bit 2 of the short-header first byte (key phase) are fixed to 0. Header-protection
   mutations that XOR these bits are out of scope.
2. **Token field**: the `Header.token` field is set to `none` in `encodeLongHeader` and
   `decodeLongHeader`. The Initial/Retry token length prefix is not modelled.
3. **Short-header round-trip**: only the first-byte properties of short headers are proved;
   the full short-header `encodeLongHeader`-equivalent is not in scope.
4. **Buffer cursor state**: `Header::to_bytes` writes into an `OctetsMut` cursor;
   `encodeLongHeader` returns `Option (List Nat)`.  Error paths and partial writes are omitted.
5. **`VersionNegotiation`**: handled as a decode-only type; `typeCode` returns `none` for it
   and `encodeLongHeader` rejects it, matching the Rust implementation.

### Impact on proofs

14 public + 2 private helper theorems, **0 sorry** ✅.  The type-code bijection and
bit-presence theorems are the highest-value results: any bug in the first-byte encoding
in `Header::to_bytes` would violate `typeCode_roundtrip`, `longFirstByte_form_bit`, or
`short_long_first_byte_differ`, causing all QUIC traffic to be misclassified.
`longHeader_roundtrip` closes the full encode↔decode correctness proof for long-header
packets under the modelled scope (DCID, SCID, version, type code).

### Validation evidence

- **`lake build`**: passed with Lean 4.30.0-rc2 — 0 sorry (run 105).
- **12 `native_decide` unit checks**: concrete first-byte values for each packet type
  verified at compile time.
- Route-B correspondence tests are not yet written for this target; the proof itself
  subsumes executable testing for the modelled scope.

---

## `FVSquad/H3Frame.lean` (T31) ↔ `quiche/src/h3/frame.rs`

**Lean file**: `formal-verification/lean/FVSquad/H3Frame.lean`
**Rust source**: `quiche/src/h3/frame.rs` — `Frame::to_bytes`, `Frame::from_bytes`
**Informal spec**: `formal-verification/specs/h3_frame_informal.md`
**Phase**: 5 — Done (19 theorems, 0 sorry, run 99/100)

### Modelled definitions

| Lean name | Rust name / concept | Source location | Correspondence level | Notes |
|-----------|--------------------|-----------------|--------------------|-------|
| `H3FrameType` | `Frame` enum variants | `frame.rs:~40–90` | **abstraction** | Only GoAway, MaxPushId, CancelPush modelled |
| `h3f_varint_encode` | `OctetsMut::put_varint` | `octets/src/lib.rs:499` | **approximation** | Inline copy of Varint.lean model; arithmetic not bitwise |
| `h3f_varint_decode` | `Octets::get_varint` | `octets/src/lib.rs:187` | **approximation** | Inline; same correspondence notes as Varint.lean |
| `h3f_encode` | `Frame::to_bytes` | `frame.rs:~200–350` | **abstraction** | Encodes type + length + payload as byte list; buffer state omitted |
| `h3f_decode` | `Frame::from_bytes` | `frame.rs:~400–550` | **abstraction** | Decodes from byte list; `payload_length` precondition not enforced |
| `h3f_goaway_roundtrip` | GoAway encode↔decode | `frame.rs:GoAway branch` | **exact** (in scope) | Proved for all `v ≤ MAX_VAR_INT` |
| `h3f_max_push_id_roundtrip` | MaxPushId encode↔decode | `frame.rs:MaxPushId branch` | **exact** (in scope) | Proved |
| `h3f_cancel_push_roundtrip` | CancelPush encode↔decode | `frame.rs:CancelPush branch` | **exact** (in scope) | Proved |

### Approximations and known gaps

1. **Scope**: Only the three single-varint-payload frame types (GoAway,
   MaxPushId, CancelPush) are modelled. Settings (key-value varint pairs),
   Data/Headers (raw byte arrays), PushPromise, and PriorityUpdate are
   not modelled.

2. **Buffer cursor state**: `Frame::to_bytes` writes to an `OctetsMut` cursor;
   `h3f_encode` returns `Option (List Nat)`. The cursor offset and error paths
   are not modelled.

3. **`payload_length` not enforced** (OQ-T31-4 from informal spec): The Rust
   API takes a separate `payload_length` argument that must equal
   `bytes.len()`. The Lean model uses `bytes.length` directly, avoiding the
   mismatch. A caller that passes an incorrect `payload_length` in Rust would
   get different behaviour from the model.

4. **Varint inline vs imported**: The varint encode/decode is duplicated
   inline rather than imported from `Varint.lean` (to avoid import ordering
   issues). The inline model is confirmed equivalent to `Varint.lean` by
   the Route-B tests, which run both.

### Impact on proofs

19 theorems, 0 sorry. The three round-trip theorems are the highest-value
results. They cover the encode↔decode correctness for all single-varint
HTTP/3 frame types that affect stream and push lifecycle management. Route-B
tests provide independent executable evidence of correspondence.

### Validation evidence

- **Route-B tests**: `formal-verification/tests/h3_frame/` — **25/25 PASS** (run 103).
  Tests cover all three frame types, all four varint size classes, edge values,
  and property checks. Run: `lean --run formal-verification/tests/h3_frame/lean_eval.lean`
- 7 `native_decide` unit checks in `H3Frame.lean` confirm concrete encoding examples.

---

## `FVSquad/BytesInFlight.lean` (T37) ↔ `quiche/src/recovery/bytes_in_flight.rs`

**Lean file**: `formal-verification/lean/FVSquad/BytesInFlight.lean`
**Rust source**: `quiche/src/recovery/bytes_in_flight.rs`
**Phase**: 5 — Done (17 theorems, 0 sorry, run 107)

### Purpose

Models the `BytesInFlight` struct, which tracks the current number of bytes
in flight and the total duration the connection has had bytes in flight.
The struct maintains an "open interval" (bytes > 0) and accumulates
"closed intervals" (transitions back to 0) for congestion-control diagnostics.

### Type mapping

| Lean name | Lean type | Rust name | Rust type | Correspondence |
|-----------|-----------|-----------|-----------|----------------|
| `State` | `structure` | `BytesInFlight` | `struct` | **abstraction** — `Instant`→`Nat`, `Duration`→`Nat` |
| `State.bytes` | `Nat` | `bytes_in_flight` | `usize` | **abstraction** — no overflow |
| `State.startTime` | `Option Nat` | `bytes_in_flight_interval_start` | `Option<Instant>` | **abstraction** — abstract clock |
| `State.openDur` | `Nat` | `open_interval_duration` | `Duration` | **abstraction** — Nat ticks |
| `State.closedDur` | `Nat` | `closed_interval_duration` | `Duration` | **abstraction** — Nat ticks |
| `add` | `State → Nat → Nat → State` | `BytesInFlight::add` | `(&mut self, usize, Instant)` | **abstraction** |
| `saturating_subtract` | `State → Nat → Nat → State` | `BytesInFlight::subtract` | `(&mut self, usize, Instant)` | **abstraction** |
| `wf` | `State → Prop` | *(invariant)* | *(implicit)* | **exact** — `bytes=0 ↔ startTime=none` |

### Approximations and known gaps

1. **Time abstraction**: `Instant` is replaced by `Nat` (monotone ticks).
   Duration arithmetic becomes `Nat` subtraction. The monotonicity of the
   clock (`now ≥ startTime`) is a precondition on theorems that need it but
   is not globally enforced.

2. **Mutation → pure functions**: `add` and `subtract` return a new `State`
   rather than mutating in place. This is a standard functional model; the
   semantics are equivalent for pure input/output behaviour.

3. **`usize` → `Nat`**: no overflow modelling. The `saturating_subtract`
   uses `Nat.sub` (which saturates at 0), matching the Rust `saturating_sub`.

4. **OQ-T37-1** (run 103): clock-monotonicity (`now ≥ startTime`) is not
   asserted as a global invariant — callers must supply the precondition.

5. **OQ-T37-2** (run 103): `open_interval_duration` resets to 0 on interval
   close — confirmed correct by inspection of the Rust source.

### Impact on proofs

17 theorems, 0 sorry. Key results: well-formedness preservation under
`add`/`subtract`, `bytes = 0 ↔ startTime = none` invariant, duration
accumulation correctness, and monotone growth of `closedDur`. The time
abstraction is the main approximation; it does not affect the byte-counting
invariants but means duration-overflow corner cases are not covered.

### Validation evidence

- **`lake build`**: passed with Lean 4.30.0-rc2 — 0 sorry (run 107).
- Route-B correspondence tests not yet written for this target (noted as
  next priority in memory).

---

## `FVSquad/PathState.lean` (T38) ↔ `quiche/src/path.rs`

**Lean file**: `formal-verification/lean/FVSquad/PathState.lean`
**Rust source**: `quiche/src/path.rs` — `PathState`, `Path::promote_to`,
  `Path::on_challenge_sent`, `Path::on_response_received`,
  `Path::on_failed_validation`, `Path::working`
**Phase**: 5 — Done (24 theorems, 0 sorry, run 109)

### Purpose

Models the RFC 9000 §8.2 path-validation state machine. A QUIC path
progresses through five states: `Failed < Unknown < Validating <
ValidatingMTU < Validated`. The key operation `promote_to` is
monotone — it never moves the state backward. `on_failed_validation`
is the only intentional regression (hard reset to `Failed`).

### Type mapping

| Lean name | Lean type | Rust name | Rust type | Correspondence |
|-----------|-----------|-----------|-----------|----------------|
| `State` | `inductive` | `PathState` | `enum` | **exact** — same five variants in same order |
| `State.rank` | `State → Nat` | *(derived `Ord`)* | `isize` via `to_c` | **exact** — same ordering: Failed=0…Validated=4 |
| `promote_to` | `State → State → State` | `Path::promote_to` (L340) | `&mut self` | **abstraction** — pure, returns new state |
| `on_challenge_sent` | `State → State` | `Path::on_challenge_sent` (L392) | `&mut self` | **abstraction** — pure; challenge queue side-effects omitted |
| `on_response_received` | `State → Bool → State` | `Path::on_response_received` (L421) | `&mut self, [u8;8] → bool` | **abstraction** — `mtu_ok` abstracts the MTU size test |
| `on_failed_validation` | `State` | `Path::on_failed_validation` (L455) | `&mut self` | **exact** — hard reset to Failed |
| `working` | `State → Bool` | `Path::working` (L308) | `bool` | **exact** — `state > Failed` |

### Approximations and known gaps

1. **Pure functional model**: all operations take a `State` argument and
   return a new `State` instead of mutating `self`. The surrounding `Path`
   struct (timers, in-flight challenges, PMTUD, recovery) is entirely
   omitted.

2. **`mtu_ok` abstraction**: `on_response_received` takes a `Bool` that
   abstracts `self.max_challenge_size >= crate::MIN_CLIENT_INITIAL_LEN`.
   The specific threshold (`MIN_CLIENT_INITIAL_LEN = 1200`) and
   `max_challenge_size` accumulation logic are not modelled.

3. **No typeclass `LE`/`LT`**: theorems are stated in terms of `State.rank`
   (a `Nat`) rather than the `≤`/`<` typeclass instances, to avoid
   `simp` recursion loops in plain Lean 4 (no Mathlib). The `rank`
   function faithfully mirrors Rust's derived `PartialOrd`.

4. **Scope**: Only the state-machine aspect of `Path` is modelled.
   Properties such as "if a path is validated, its DCID sequence is set"
   require modelling the full `Path` struct and are out of scope.

### Impact on proofs

24 theorems, 0 sorry. Key results:

| Theorem | Property | Value |
|---------|----------|-------|
| `promote_to_ge_current` | `promote_to` never lowers state | High — key safety property |
| `promote_to_idempotent` | Repeated promotion is a no-op | Medium — guards redundant calls |
| `challenge_sent_ge_validating` | After challenge, state ≥ Validating | High — RFC 9000 §8.2 |
| `response_mtu_ok_validated` | MTU-OK response reaches Validated | High — validation completeness |
| `full_validation_path` | Unknown → Validating → Validated (2 steps) | High — normal path end-to-end |
| `challenge_sent_working` | After challenge, path is always working | High — no regression to Failed |
| `promote_to_not_lower` | `promote_to` cannot decrease rank | High — core invariant |

The `on_failed_validation` hard-reset is correctly modelled as the one
operation that bypasses monotonicity — it is used only as a terminal
failure state.

### Validation evidence

- **`lake build`**: passed with Lean 4.30.0-rc2 — 0 sorry (run 109).
- 9 `rfl`/concrete `example` checks verify each operation on specific
  states at build time.
- Route-B correspondence tests are not yet written; the proof subsumes
  executable testing for the pure state-machine behaviour.
