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
-- §8  Unfolding helper for sorted_disjoint
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- A simp lemma that reliably unfolds `sorted_disjoint (r :: s :: rest)` without
-- risk of looping (the recursive call is a strict subterm).
@[simp]
private theorem sorted_disjoint_cons2_iff
    (r s : Nat × Nat) (rest : RangeSetModel) :
    sorted_disjoint (r :: s :: rest) ↔
    valid_range r ∧ r.2 ≤ s.1 ∧ sorted_disjoint (s :: rest) :=
  Iff.rfl

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §9  Auxiliary lemmas
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- If every element of `rs` starts at or after `bound`, and `n < bound`,
    then `n` is not covered by `rs`.
    Used to show that all tail elements of a sorted_disjoint list
    miss a value below the head's end. -/
private theorem covers_above_bound_false
    (rs : RangeSetModel) (bound n : Nat)
    (h_lt : n < bound)
    (h_ge : ∀ r ∈ rs, bound ≤ r.1) :
    covers rs n = false := by
  induction rs with
  | nil => rfl
  | cons r rest ih =>
      have h_eq : covers (r :: rest) n = (in_range r n || covers rest n) := rfl
      rw [h_eq]
      have hr : bound ≤ r.1 := h_ge r List.mem_cons_self
      have h_not_in : in_range r n = false := by simp [in_range]; omega
      rw [h_not_in, Bool.false_or]
      exact ih (fun s hs => h_ge s (List.mem_cons.mpr (Or.inr hs)))

/-- In a `sorted_disjoint` list, every element of the tail starts at or
    after the head's end.  This is the key monotonicity property used in
    both `remove_until` proofs to discharge the tail coverage goal. -/
private theorem sorted_disjoint_all_ge_head_end
    (head : Nat × Nat) (rs : RangeSetModel)
    (h_inv : sorted_disjoint (head :: rs)) :
    ∀ s ∈ rs, head.2 ≤ s.1 := by
  induction rs generalizing head with
  | nil => intro s hs; simp at hs
  | cons hd rest ih =>
      intro s hs
      rw [sorted_disjoint_cons2_iff] at h_inv
      obtain ⟨_, h_le, h_rest⟩ := h_inv
      cases List.mem_cons.mp hs with
      | inl h =>
          -- s is the immediate next element: head.2 ≤ hd.1 = s.1
          rw [h]; exact h_le
      | inr h =>
          -- s is deeper in the tail; chain through hd
          have h_vhd : valid_range hd :=
            sorted_disjoint_head_valid hd rest h_rest
          have h_hd_ge : ∀ x ∈ rest, hd.2 ≤ x.1 := ih hd h_rest
          have hs_ge : hd.2 ≤ s.1 := h_hd_ge s h
          simp [valid_range] at h_vhd
          -- head.2 ≤ hd.1 < hd.2 ≤ s.1
          omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §10  Helpers for insert proofs
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Bool equality from a propositional iff on the `= true` form. -/
private theorem bool_eq_of_iff {a b : Bool} (h : a = true ↔ b = true) : a = b := by
  cases a <;> cases b <;> simp_all

/-- in_range as a proposition. -/
private theorem in_range_iff_prop (lo hi n : Nat) :
    in_range (lo, hi) n = true ↔ lo ≤ n ∧ n < hi := by
  simp [in_range, Bool.and_eq_true, decide_eq_true_eq]

/-- covers distributes over list append. -/
private theorem covers_append (l1 l2 : RangeSetModel) (n : Nat) :
    covers (l1 ++ l2) n = (covers l1 n || covers l2 n) := by
  unfold covers; rw [List.any_append]

/-- covers of a singleton list equals in_range. -/
private theorem covers_singleton (r : Nat × Nat) (n : Nat) :
    covers [r] n = in_range r n := by
  simp [covers, List.any, in_range]

/-- The merged interval [min s rs, max e re) covers the union of [s,e) and
    [rs,re) when those intervals overlap or are adjacent. -/
private theorem in_range_merge_bool (s e rs re n : Nat)
    (h1 : ¬ (e < rs)) (h2 : ¬ (s > re)) :
    in_range (if s < rs then s else rs, if e > re then e else re) n =
    (in_range (s, e) n || in_range (rs, re) n) := by
  apply bool_eq_of_iff
  simp only [in_range_iff_prop, Bool.or_eq_true]
  by_cases hs : s < rs
  · simp only [if_pos hs]
    by_cases he : e > re
    · simp only [if_pos he]
      constructor
      · intro ⟨h_le, h_lt⟩; exact Or.inl ⟨by omega, h_lt⟩
      · rintro (⟨h_le, h_lt⟩ | ⟨h_le, h_lt⟩) <;> exact ⟨by omega, by omega⟩
    · simp only [if_neg he]
      constructor
      · intro ⟨h_le, h_lt⟩
        by_cases hlt : n < e
        · exact Or.inl ⟨h_le, hlt⟩
        · exact Or.inr ⟨by omega, h_lt⟩
      · rintro (⟨h_le, h_lt⟩ | ⟨h_le, h_lt⟩) <;> exact ⟨by omega, by omega⟩
  · simp only [if_neg hs]
    by_cases he : e > re
    · simp only [if_pos he]
      constructor
      · intro ⟨h_le, h_lt⟩
        by_cases hlt : n < re
        · exact Or.inr ⟨h_le, hlt⟩
        · exact Or.inl ⟨by omega, h_lt⟩
      · rintro (⟨h_le, h_lt⟩ | ⟨h_le, h_lt⟩) <;> exact ⟨by omega, by omega⟩
    · simp only [if_neg he]
      constructor
      · intro h; exact Or.inr h
      · rintro (⟨h_le, h_lt⟩ | h)
        · exact ⟨by omega, by omega⟩
        · exact h

/-- Append a valid range (lo, hi) to a sorted list whose elements all end ≤ lo. -/
private theorem sorted_disjoint_snoc (l : RangeSetModel) (lo hi : Nat)
    (h_inv : sorted_disjoint l)
    (h_bound : ∀ r ∈ l, r.2 ≤ lo)
    (h_range : lo < hi) :
    sorted_disjoint (l ++ [(lo, hi)]) := by
  induction l with
  | nil => simp [sorted_disjoint, valid_range, h_range]
  | cons hd rest ih =>
      cases rest with
      | nil =>
          simp only [List.cons_append, List.nil_append, sorted_disjoint_cons2_iff]
          exact ⟨h_inv, h_bound hd List.mem_cons_self,
                 by simp [sorted_disjoint, valid_range, h_range]⟩
      | cons next more =>
          simp only [List.cons_append, sorted_disjoint_cons2_iff]
          simp only [sorted_disjoint_cons2_iff] at h_inv
          obtain ⟨h_hd, h_le, h_rest⟩ := h_inv
          exact ⟨h_hd, h_le,
                 ih h_rest (fun r hr => h_bound r (List.mem_cons.mpr (Or.inr hr)))⟩

/-- Concatenate two sorted_disjoint lists given a separation bound. -/
private theorem sorted_disjoint_concat (l1 l2 : RangeSetModel)
    (h1 : sorted_disjoint l1)
    (h2 : sorted_disjoint l2)
    (h_bound : ∀ r ∈ l1, ∀ q ∈ l2, r.2 ≤ q.1) :
    sorted_disjoint (l1 ++ l2) := by
  induction l2 generalizing l1 with
  | nil => simp [h1]
  | cons qhd qtl ih =>
      rw [show l1 ++ (qhd :: qtl) = (l1 ++ [qhd]) ++ qtl from by simp [List.append_assoc]]
      apply ih
      · apply sorted_disjoint_snoc l1 qhd.1 qhd.2 h1
        · intro r hr; exact h_bound r hr qhd List.mem_cons_self
        · exact sorted_disjoint_head_valid qhd qtl h2
      · exact sorted_disjoint_tail qhd qtl h2
      · intro r hr q hq
        simp only [List.mem_append, List.mem_singleton] at hr
        cases hr with
        | inl hr => exact h_bound r hr q (List.mem_cons.mpr (Or.inr hq))
        | inr hr =>
            rw [hr]
            exact sorted_disjoint_all_ge_head_end qhd qtl h2 q hq

/-- Generalised covers lemma: range_insert_go acc_rev rest s e covers exactly
    the union of acc_rev.reverse, rest, and [s,e). -/
private theorem range_insert_go_covers_gen
    (acc_rev rest : RangeSetModel) (s e n : Nat) :
    covers (range_insert_go acc_rev rest s e) n =
    (covers acc_rev.reverse n || covers rest n || in_range (s, e) n) := by
  induction rest generalizing acc_rev s e with
  | nil =>
      simp only [range_insert_go, covers_append, covers_singleton]
      simp [covers]
  | cons hd rest ih =>
      obtain ⟨rs, re⟩ := hd
      simp only [range_insert_go]
      by_cases h1 : e < rs
      · rw [if_pos h1]
        rw [show acc_rev.reverse ++ [(s, e), (rs, re)] ++ rest =
              (acc_rev.reverse ++ [(s, e)]) ++ ((rs, re) :: rest) from
            by simp [List.append_assoc]]
        rw [covers_append, covers_append, covers_singleton]
        generalize covers acc_rev.reverse n = a
        generalize in_range (s, e) n = b
        generalize covers ((rs, re) :: rest) n = c
        cases a <;> cases b <;> cases c <;> rfl
      · rw [if_neg h1]
        by_cases h2 : s > re
        · rw [if_pos h2, ih, List.reverse_cons, covers_append, covers_singleton]
          have : covers ((rs, re) :: rest) n = (in_range (rs, re) n || covers rest n) := rfl
          rw [this]
          generalize covers acc_rev.reverse n = a
          generalize in_range (s, e) n = b
          generalize in_range (rs, re) n = c
          generalize covers rest n = d
          cases a <;> cases b <;> cases c <;> cases d <;> rfl
        · rw [if_neg h2, ih, in_range_merge_bool s e rs re n h1 h2]
          have : covers ((rs, re) :: rest) n = (in_range (rs, re) n || covers rest n) := rfl
          rw [this]
          generalize covers acc_rev.reverse n = a
          generalize in_range (s, e) n = b
          generalize in_range (rs, re) n = c
          generalize covers rest n = d
          cases a <;> cases b <;> cases c <;> cases d <;> rfl

/-- Generalised invariant lemma: range_insert_go preserves sorted_disjoint
    given an appropriate accumulator invariant. -/
private theorem range_insert_go_preserves_inv
    (acc_rev rest : RangeSetModel) (s e : Nat)
    -- acc_rev.reverse is sorted_disjoint
    (h_acc_inv : sorted_disjoint acc_rev.reverse)
    -- all acc elements end ≤ s (the current merge window start)
    (h_acc_bound : ∀ r ∈ acc_rev, r.2 ≤ s)
    -- acc ends before rest begins (separation invariant)
    (h_sep : ∀ r ∈ acc_rev, ∀ q ∈ rest, r.2 ≤ q.1)
    -- rest is sorted_disjoint
    (h_rest_inv : sorted_disjoint rest)
    -- current window is a valid non-empty range
    (h_range : s < e) :
    sorted_disjoint (range_insert_go acc_rev rest s e) := by
  induction rest generalizing acc_rev s e with
  | nil =>
      simp only [range_insert_go]
      exact sorted_disjoint_snoc acc_rev.reverse s e h_acc_inv
              (fun r hr => h_acc_bound r (List.mem_reverse.mp hr)) h_range
  | cons hd rest ih =>
      obtain ⟨rs, re⟩ := hd
      simp only [range_insert_go]
      by_cases h1 : e < rs
      · -- Insert before (rs,re): result = acc.rev ++ [(s,e)] ++ (rs,re) :: rest
        rw [if_pos h1]
        rw [show acc_rev.reverse ++ [(s, e), (rs, re)] ++ rest =
              (acc_rev.reverse ++ [(s, e)]) ++ ((rs, re) :: rest) from
            by simp [List.append_assoc]]
        apply sorted_disjoint_concat
        · exact sorted_disjoint_snoc acc_rev.reverse s e h_acc_inv
                    (fun r hr => h_acc_bound r (List.mem_reverse.mp hr)) h_range
        · exact h_rest_inv
        · intro r hr q hq
          simp only [List.mem_append, List.mem_singleton] at hr
          cases hr with
          | inl hr => exact h_sep r (List.mem_reverse.mp hr) q hq
          | inr hr =>
              rw [hr]
              cases List.mem_cons.mp hq with
              | inl h => rw [h]; omega
              | inr h =>
                  have hge := sorted_disjoint_all_ge_head_end (rs, re) rest h_rest_inv q h
                  have hv := sorted_disjoint_head_valid (rs, re) rest h_rest_inv
                  simp [valid_range] at hv; omega
      · rw [if_neg h1]
        by_cases h2 : s > re
        · -- Skip (rs,re): recurse with updated acc
          rw [if_pos h2]
          apply ih
          · -- sorted_disjoint ((rs,re) :: acc_rev).reverse
            rw [List.reverse_cons]
            apply sorted_disjoint_snoc acc_rev.reverse rs re h_acc_inv
            · intro r hr
              exact h_sep r (List.mem_reverse.mp hr) (rs, re) List.mem_cons_self
            · exact sorted_disjoint_head_valid (rs, re) rest h_rest_inv
          · -- all new acc elements end ≤ s
            intro r hr
            cases List.mem_cons.mp hr with
            | inl h => rw [h]; omega
            | inr h => exact h_acc_bound r h
          · -- separation: new acc ends before rest
            intro r hr q hq
            cases List.mem_cons.mp hr with
            | inl h =>
                rw [h]
                exact sorted_disjoint_all_ge_head_end (rs, re) rest h_rest_inv q hq
            | inr h =>
                exact h_sep r h q (List.mem_cons.mpr (Or.inr hq))
          · exact sorted_disjoint_tail (rs, re) rest h_rest_inv
          · exact h_range
        · -- Overlap: merge (s,e) with (rs,re) and recurse
          rw [if_neg h2]
          apply ih
          · exact h_acc_inv
          · -- new s' = min s rs; all acc elements end ≤ s and ≤ rs, so ≤ min s rs
            intro r hr
            have hb := h_acc_bound r hr
            have hs' := h_sep r hr (rs, re) List.mem_cons_self
            by_cases hlt : s < rs
            · simp only [if_pos hlt]; omega
            · simp only [if_neg hlt]; omega
          · -- separation: acc still ends before rest (tail only)
            intro r hr q hq
            exact h_sep r hr q (List.mem_cons.mpr (Or.inr hq))
          · exact sorted_disjoint_tail (rs, re) rest h_rest_inv
          · -- min s rs < max e re
            have h_valid := sorted_disjoint_head_valid (rs, re) rest h_rest_inv
            simp [valid_range] at h_valid
            by_cases hlt : s < rs <;> by_cases hlt2 : e > re
            · simp only [if_pos hlt, if_pos hlt2]; omega
            · simp only [if_pos hlt, if_neg hlt2]; omega
            · simp only [if_neg hlt, if_pos hlt2]; omega
            · simp only [if_neg hlt, if_neg hlt2]; omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §11  Key propositions
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- I1+I2: insert preserves the sorted_disjoint invariant.
    This is the fundamental correctness property: every insert leaves the
    RangeSet in a valid state. -/
theorem insert_preserves_invariant (rs : RangeSetModel) (s e : Nat)
    (h_inv : sorted_disjoint rs) (h_range : s < e) :
    sorted_disjoint (range_insert rs s e) := by
  simp only [range_insert]
  apply range_insert_go_preserves_inv
  · simp [sorted_disjoint]
  · intro r hr; simp at hr
  · intro r hr q hq; simp at hr
  · exact h_inv
  · exact h_range

/-- I3: insert is semantically correct — it is a set union.
    `covers (range_insert S [s,e)) n = covers S n ∨ s ≤ n < e`
    (expressed as Bool equality since both sides are Bool-valued).
    Approximation: capacity eviction is not modelled; this property holds
    unconditionally in the pure functional model. -/
theorem insert_covers_union (rs : RangeSetModel) (s e n : Nat)
    (h_inv : sorted_disjoint rs) :
    covers (range_insert rs s e) n = (covers rs n || (s ≤ n && n < e)) := by
  simp only [range_insert]
  rw [range_insert_go_covers_gen]
  simp [covers, in_range]

/-- I4a: remove_until removes exactly the values ≤ `largest`.
    No value ≤ `largest` is covered after `remove_until`. -/
theorem remove_until_removes_small (rs : RangeSetModel) (largest n : Nat)
    (h_inv : sorted_disjoint rs)
    (h_small : n ≤ largest) :
    covers (range_remove_until rs largest) n = false := by
  induction rs with
  | nil => rfl
  | cons hd tl ih =>
      obtain ⟨hs, he⟩ := hd
      simp only [range_remove_until]
      by_cases h1 : he ≤ largest + 1
      · -- Entire range [hs,he) ⊆ [0,largest]: drop it and recurse.
        rw [if_pos h1]
        exact ih (sorted_disjoint_tail _ _ h_inv)
      · rw [if_neg h1]
        by_cases h2 : hs ≤ largest
        · -- Partial overlap: trim start to largest+1.
          rw [if_pos h2]
          have h_eq : covers ((largest + 1, he) :: tl) n =
              (in_range (largest + 1, he) n || covers tl n) := rfl
          rw [h_eq]
          have h_not_in : in_range (largest + 1, he) n = false := by
            simp [in_range]; omega
          rw [h_not_in, Bool.false_or]
          -- All tail elements start ≥ he > largest+1 > n.
          apply covers_above_bound_false tl he n (by omega)
          exact sorted_disjoint_all_ge_head_end (hs, he) tl h_inv
        · -- Range starts after largest: return unchanged.
          rw [if_neg h2]
          have h_eq : covers ((hs, he) :: tl) n =
              (in_range (hs, he) n || covers tl n) := rfl
          rw [h_eq]
          have h_not_in : in_range (hs, he) n = false := by
            simp [in_range]; omega
          rw [h_not_in, Bool.false_or]
          -- All tail elements start ≥ he > hs > largest ≥ n.
          have h_vhd : valid_range (hs, he) :=
            sorted_disjoint_head_valid _ _ h_inv
          simp [valid_range] at h_vhd
          apply covers_above_bound_false tl he n (by omega)
          exact sorted_disjoint_all_ge_head_end (hs, he) tl h_inv

/-- I4b: remove_until preserves values strictly above `largest`.
    Any value > `largest` that was covered remains covered. -/
theorem remove_until_preserves_large (rs : RangeSetModel) (largest n : Nat)
    (h_inv : sorted_disjoint rs)
    (h_large : n > largest)
    (h_covered : covers rs n = true) :
    covers (range_remove_until rs largest) n = true := by
  induction rs with
  | nil => simp [covers] at h_covered
  | cons hd tl ih =>
      obtain ⟨hs, he⟩ := hd
      simp only [range_remove_until]
      have h_eq_src : covers ((hs, he) :: tl) n =
          (in_range (hs, he) n || covers tl n) := rfl
      by_cases h1 : he ≤ largest + 1
      · -- Range fully below threshold: it cannot cover n > largest.
        rw [if_pos h1]
        apply ih (sorted_disjoint_tail _ _ h_inv)
        rw [h_eq_src] at h_covered
        have h_not_in : in_range (hs, he) n = false := by
          simp [in_range]; omega
        rw [h_not_in, Bool.false_or] at h_covered
        exact h_covered
      · rw [if_neg h1]
        by_cases h2 : hs ≤ largest
        · -- Trimmed to (largest+1, he) :: tl.
          rw [if_pos h2]
          have h_eq_res : covers ((largest + 1, he) :: tl) n =
              (in_range (largest + 1, he) n || covers tl n) := rfl
          rw [h_eq_res]
          rw [h_eq_src] at h_covered
          cases h3 : in_range (hs, he) n with
          | false =>
              -- n not in (hs,he), so n must be in tl.
              rw [h3, Bool.false_or] at h_covered
              rw [h_covered, Bool.or_true]
          | true =>
              -- n ∈ [hs, he); since n > largest, n ∈ [largest+1, he).
              have h_in_trim : in_range (largest + 1, he) n = true := by
                simp [in_range] at h3 ⊢; omega
              rw [h_in_trim, Bool.true_or]
        · -- Range unchanged.
          rw [if_neg h2]
          exact h_covered

/-- I4c: remove_until preserves the sorted_disjoint invariant. -/
theorem remove_until_preserves_invariant (rs : RangeSetModel) (largest : Nat)
    (h_inv : sorted_disjoint rs) :
    sorted_disjoint (range_remove_until rs largest) := by
  induction rs with
  | nil => exact h_inv
  | cons hd tl ih =>
      obtain ⟨hs, he⟩ := hd
      simp only [range_remove_until]
      by_cases h1 : he ≤ largest + 1
      · -- Drop the range; invariant holds by induction.
        rw [if_pos h1]
        exact ih (sorted_disjoint_tail _ _ h_inv)
      · rw [if_neg h1]
        by_cases h2 : hs ≤ largest
        · -- Result: (largest+1, he) :: tl.
          rw [if_pos h2]
          cases tl with
          | nil =>
              -- Singleton; just need valid_range.
              simp [sorted_disjoint, valid_range]; omega
          | cons next rest =>
              obtain ⟨ts, te⟩ := next
              rw [sorted_disjoint_cons2_iff]
              rw [sorted_disjoint_cons2_iff] at h_inv
              obtain ⟨_, h_le, h_rest⟩ := h_inv
              -- valid_range (largest+1, he): he ≥ largest+2 since ¬(he ≤ largest+1)
              -- (largest+1, he).2 ≤ (ts, te).1: both equal he ≤ ts from h_inv
              exact ⟨by simp [valid_range]; omega, h_le, h_rest⟩
        · -- Range unchanged.
          rw [if_neg h2]
          exact h_inv
