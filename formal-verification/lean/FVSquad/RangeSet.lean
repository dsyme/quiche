-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of the RangeSet data structure
-- in `quiche/src/ranges.rs`.
--
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- Approximations / abstractions:
--   - The Inline/BTree dual-representation is NOT modelled.
--     Both variants are abstracted to a sorted list of (start, end) pairs.
--   - Capacity eviction is NOT modelled; theorems apply when len < capacity.
--   - All values are Nat (unbounded), not u64. The u64::MAX edge cases
--     (e.g., push_item overflow) are ignored.
--   - Zero-length range insertion (start == end) is not modelled; all
--     theorems assume s < e (valid range).

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §1  Model type
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- A RangeSet is modelled as a sorted list of half-open intervals [start, end).
    Corresponds to `RangeSet` in `quiche/src/ranges.rs`.
    The representation invariant is `sorted_disjoint` (§2). -/
abbrev RangeSetModel := List (Nat × Nat)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §2  Structural invariant
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- A single range is valid if start < end (non-empty half-open interval).
    Invariant I2 in `rangeset_informal.md`. -/
def valid_range (r : Nat × Nat) : Prop :=
  r.1 < r.2

/-- The sorted_disjoint invariant (I1 + I2):
    - All stored ranges are non-empty: `r.start < r.end`.
    - Ranges are sorted and non-overlapping: for consecutive r_i, r_{i+1},
      `r_i.end ≤ r_{i+1}.start`.
    Note: the implementation also merges adjacent ranges (r_i.end = r_{i+1}.start),
    so the invariant is maintained with gap — consecutive ranges have a strict
    gap (r_i.end < r_{i+1}.start) OR are separated by exactly one unit if
    adjacent elements were separately inserted. In practice the implementation
    merges touching/overlapping ranges, so consecutive elements always satisfy
    r_i.end < r_{i+1}.start after any insert. -/
def sorted_disjoint : RangeSetModel → Prop
  | []        => True
  | [r]       => valid_range r
  | r :: s :: rest => valid_range r ∧ r.2 ≤ s.1 ∧ sorted_disjoint (s :: rest)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §3  Coverage predicate
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Whether value `n` falls within half-open range `r`: `r.start ≤ n < r.end`. -/
def in_range (r : Nat × Nat) (n : Nat) : Bool :=
  r.1 ≤ n && n < r.2

/-- Whether value `n` is covered by some range in the set.
    Corresponds to the `covers` / `flatten` membership predicate.
    Used in §7 to state correctness theorems. -/
def covers (rs : RangeSetModel) (n : Nat) : Bool :=
  rs.any (fun r => in_range r n)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §4  Insert operation
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Worker for range_insert: acc_rev accumulates processed ranges in reverse.
-- Terminates because `rest` strictly decreases.
private def range_insert_go
    (acc_rev : RangeSetModel)
    (rest    : RangeSetModel)
    (s e     : Nat)
    : RangeSetModel :=
  match rest with
  | [] =>
      -- Consumed all existing ranges; append the merged range.
      acc_rev.reverse ++ [(s, e)]
  | (rs, re) :: tail =>
      if e < rs then
        -- New range ends strictly before this one: insert here and append tail.
        acc_rev.reverse ++ [(s, e), (rs, re)] ++ tail
      else if s > re then
        -- New range starts strictly after this one: skip it.
        range_insert_go ((rs, re) :: acc_rev) tail s e
      else
        -- Overlapping or adjacent: merge.
        let s' := if s < rs then s else rs
        let e' := if e > re then e else re
        range_insert_go acc_rev tail s' e'
termination_by rest.length

/-- Insert half-open range [s, e) into a sorted_disjoint list, merging any
    overlapping or adjacent ranges.
    Mirrors `InlineRangeSet::insert` / `BTreeRangeSet::insert` in
    `quiche/src/ranges.rs`.
    Approximation: capacity eviction is NOT modelled. -/
def range_insert (rs : RangeSetModel) (s e : Nat) : RangeSetModel :=
  range_insert_go [] rs s e

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §5  remove_until operation
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Remove all values ≤ `largest` from the set.
    - Ranges fully contained in [0, largest] are dropped.
    - The first range that partially overlaps is trimmed at `largest + 1`.
    Mirrors `InlineRangeSet::remove_until` / `BTreeRangeSet::remove_until`
    in `quiche/src/ranges.rs`.
    Postcondition: `covers (range_remove_until rs v) n = false` for all `n ≤ v`. -/
def range_remove_until : RangeSetModel → Nat → RangeSetModel
  | [],          _       => []
  | (s, e) :: tail, v =>
      if e ≤ v + 1 then
        -- Entire range: all values in [s,e) satisfy x < e ≤ v+1, so x ≤ v. Drop.
        range_remove_until tail v
      else if s ≤ v then
        -- Partial overlap: trim start to v+1, keep the rest unchanged.
        (v + 1, e) :: tail
      else
        -- Range starts after v: keep everything.
        (s, e) :: tail

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §6  Concrete verification with native_decide
--     Based on test cases in `quiche/src/ranges.rs` (lines 398–636).
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- insert_non_overlapping test
example : range_insert []        4  7 = [(4, 7)]              := by native_decide
example : range_insert [(4, 7)]  9 12 = [(4, 7), (9, 12)]    := by native_decide

-- insert_contained test: re-inserting a contained range changes nothing
example : range_insert [(4, 7), (9, 12)]  4  7 = [(4, 7), (9, 12)] := by native_decide
example : range_insert [(4, 7), (9, 12)]  5  6 = [(4, 7), (9, 12)] := by native_decide

-- insert_overlapping: extending ranges
example : range_insert [(3, 6), (9, 12)]  5  7 = [(3, 7), (9, 12)] := by native_decide
example : range_insert [(3, 7), (9, 15)]  2  5 = [(2, 7), (9, 15)] := by native_decide

-- Bridging two ranges
example : range_insert [(2, 7), (8, 15)]  6 10 = [(2, 15)]         := by native_decide

-- remove_until tests
example : range_remove_until [(3, 6), (9, 11), (13, 14), (16, 20)] 2 =
            [(3, 6), (9, 11), (13, 14), (16, 20)]                   := by native_decide
example : range_remove_until [(3, 6), (9, 11), (13, 14), (16, 20)] 4 =
            [(5, 6), (9, 11), (13, 14), (16, 20)]                   := by native_decide
example : range_remove_until [(5, 6), (9, 11), (13, 14), (16, 20)] 6 =
            [(9, 11), (13, 14), (16, 20)]                           := by native_decide
example : range_remove_until [(9, 11), (13, 14), (16, 20)] 10 =
            [(13, 14), (16, 20)]                                     := by native_decide

-- Membership examples
example : covers [(4, 7), (9, 12)] 5  = true  := by native_decide
example : covers [(4, 7), (9, 12)] 7  = false := by native_decide
example : covers [(4, 7), (9, 12)] 9  = true  := by native_decide
example : covers [(4, 7), (9, 12)] 12 = false := by native_decide

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §7  Structural lemmas (proved — no sorry)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- The empty set satisfies the invariant. -/
theorem empty_sorted_disjoint : sorted_disjoint [] :=
  trivial

/-- A single valid range satisfies the invariant. -/
theorem singleton_sorted_disjoint (s e : Nat) (h : s < e) :
    sorted_disjoint [(s, e)] := by
  simp [sorted_disjoint, valid_range, h]

/-- The empty set covers nothing. -/
theorem empty_covers_nothing (n : Nat) : covers [] n = false := by
  simp [covers, List.any]

/-- A value is covered by a singleton iff it falls inside the range. -/
theorem singleton_covers_iff (s e n : Nat) :
    covers [(s, e)] n = (s ≤ n && n < e) := by
  simp [covers, List.any, in_range]

/-- Inserting into the empty set produces a singleton (when s < e). -/
theorem insert_empty (s e : Nat) :
    range_insert [] s e = [(s, e)] := by
  simp [range_insert, range_insert_go]

/-- remove_until from the empty set is empty. -/
theorem remove_until_empty (v : Nat) : range_remove_until [] v = [] := by
  simp [range_remove_until]

/-- Inserting a range into the empty set covers exactly [s, e). -/
theorem insert_empty_covers (s e n : Nat) :
    covers (range_insert [] s e) n = (s ≤ n && n < e) := by
  rw [insert_empty, singleton_covers_iff]

/-- A value outside [s, e) is not covered by the singleton {(s, e)}.
    Both sides of the range are handled. -/
theorem singleton_not_covers_left (s e n : Nat) (h : n < s) :
    covers [(s, e)] n = false := by
  simp [covers, List.any, in_range]
  omega

theorem singleton_not_covers_right (s e n : Nat) (h : e ≤ n) :
    covers [(s, e)] n = false := by
  simp [covers, List.any, in_range]
  omega

/-- sorted_disjoint is monotone: if we drop the first element we preserve it. -/
theorem sorted_disjoint_tail (r : Nat × Nat) (rs : RangeSetModel)
    (h : sorted_disjoint (r :: rs)) : sorted_disjoint rs := by
  cases rs with
  | nil => trivial
  | cons s rest =>
      simp [sorted_disjoint] at h
      exact h.2.2

/-- The head of a sorted_disjoint list is a valid range. -/
theorem sorted_disjoint_head_valid (r : Nat × Nat) (rs : RangeSetModel)
    (h : sorted_disjoint (r :: rs)) : valid_range r := by
  cases rs with
  | nil => exact h
  | cons s rest =>
      simp [sorted_disjoint] at h
      exact h.1

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §8  Key propositions (sorry — proof engineering in future runs)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Proof strategy for insert_preserves_invariant:
-- Induction on rs. Base case: singleton after insert_empty.
-- Inductive step: case-split on the three branches of range_insert_go.
-- The merge branch requires showing that the new merged range is valid
-- and correctly positioned relative to the remaining tail.

/-- I1+I2: insert preserves the sorted_disjoint invariant.
    This is the fundamental correctness property: every insert leaves the
    RangeSet in a valid state. -/
theorem insert_preserves_invariant (rs : RangeSetModel) (s e : Nat)
    (h_inv : sorted_disjoint rs) (h_range : s < e) :
    sorted_disjoint (range_insert rs s e) := by
  sorry

-- Proof strategy for insert_covers_union:
-- By induction on rs.
-- For the "skip" branch: the head range is disjoint from [s,e) and untouched.
-- For the "insert before" branch: trivial by definition.
-- For the "merge" branch: the merged range covers (acc ∪ [s,e)), and by induction.

/-- I3: insert is semantically correct — it is a set union.
    `covers (range_insert S [s,e)) n = covers S n ∨ s ≤ n < e`
    (expressed as Bool equality since both sides are Bool-valued).
    Approximation: capacity eviction is not modelled; this property holds
    unconditionally in the pure functional model. -/
theorem insert_covers_union (rs : RangeSetModel) (s e n : Nat)
    (h_inv : sorted_disjoint rs) :
    covers (range_insert rs s e) n = (covers rs n || (s ≤ n && n < e)) := by
  sorry

-- Proof strategy for remove_until_removes_small:
-- By induction on rs. For each range [r_s, r_e):
--   Case e ≤ v+1: range dropped; induction on tail.
--   Case s ≤ v < e: trimmed to [v+1, e); show v+1 > n (since n ≤ v).
--   Case s > v: range unchanged; but n ≤ v < s, so n < r_s, not covered.

/-- I4a: remove_until removes exactly the values ≤ `largest`.
    No value ≤ `largest` is covered after `remove_until`. -/
theorem remove_until_removes_small (rs : RangeSetModel) (largest n : Nat)
    (h_inv : sorted_disjoint rs)
    (h_small : n ≤ largest) :
    covers (range_remove_until rs largest) n = false := by
  sorry

/-- I4b: remove_until preserves values strictly above `largest`.
    Any value > `largest` that was covered remains covered. -/
theorem remove_until_preserves_large (rs : RangeSetModel) (largest n : Nat)
    (h_inv : sorted_disjoint rs)
    (h_large : n > largest)
    (h_covered : covers rs n = true) :
    covers (range_remove_until rs largest) n = true := by
  sorry

/-- remove_until preserves the sorted_disjoint invariant. -/
theorem remove_until_preserves_invariant (rs : RangeSetModel) (largest : Nat)
    (h_inv : sorted_disjoint rs) :
    sorted_disjoint (range_remove_until rs largest) := by
  sorry
