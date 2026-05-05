-- Copyright (C) 2024, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/WindowedFilter.lean
--
namespace WindowedFilter

/-! ## Types -/

/-- Three-slot ordered estimate store: (best, second, third) -/
structure Estimates where
  best   : Nat
  second : Nat
  third  : Nat
  deriving Repr

/-- Ordering invariant: best ≥ second ≥ third -/
def ordered (e : Estimates) : Prop :=
  e.best ≥ e.second ∧ e.second ≥ e.third

/-! ## Operations -/

/-- reset: set all three estimates to the new sample -/
def reset (s : Nat) : Estimates :=
  { best := s, second := s, third := s }

/-- update_second_third: when new_sample > second (but not > best),
    replace second and third with new_sample -/
def update_second_third (e : Estimates) (s : Nat) : Estimates :=
  { e with second := s, third := s }

/-- update_third_only: when new_sample > third (but not > second),
    replace only third -/
def update_third_only (e : Estimates) (s : Nat) : Estimates :=
  { e with third := s }

/-- promote: when best expires, promote second→best, third→second,
    new_sample→third -/
def promote (e : Estimates) (s : Nat) : Estimates :=
  { best := e.second, second := e.third, third := s }

/-- double_promote: when both best and new-best expire, promote twice -/
def double_promote (e : Estimates) (s : Nat) : Estimates :=
  let e1 := promote e s
  { e1 with best := e1.second, second := e1.third }

/-! ## Core invariant lemmas -/

/-- reset always yields an ordered triple (all equal) -/
theorem reset_ordered (s : Nat) : ordered (reset s) := by
  simp [ordered, reset]

/-- reset gives all three estimates equal to the sample -/
theorem reset_all_equal (s : Nat) :
    (reset s).best = s ∧ (reset s).second = s ∧ (reset s).third = s := by
  simp [reset]

/-- If new_sample > second and e is ordered (best ≥ second ≥ third),
    and new_sample ≤ best, then update_second_third preserves ordering -/
theorem update_second_third_ordered (e : Estimates) (s : Nat)
    (h_ord : ordered e)
    (h_le_best : s ≤ e.best) :
    ordered (update_second_third e s) := by
  simp only [ordered, update_second_third]
  omega

/-- update_second_third: second and third become equal to s -/
theorem update_second_third_eq (e : Estimates) (s : Nat) :
    (update_second_third e s).second = s ∧
    (update_second_third e s).third = s := by
  simp [update_second_third]

/-- If new_sample ≤ second and e is ordered, then update_third_only
    preserves ordering -/
theorem update_third_only_ordered (e : Estimates) (s : Nat)
    (h_ord : ordered e)
    (h_le_second : s ≤ e.second) :
    ordered (update_third_only e s) := by
  obtain ⟨h1, _h2⟩ := h_ord
  simp only [ordered, update_third_only]
  exact ⟨h1, h_le_second⟩

/-- update_third_only: best and second are unchanged -/
theorem update_third_only_best_second_unchanged (e : Estimates) (s : Nat) :
    (update_third_only e s).best = e.best ∧
    (update_third_only e s).second = e.second := by
  simp [update_third_only]

/-- promote: if e.second ≥ e.third, then promote is ordered when s ≤ e.third -/
theorem promote_ordered (e : Estimates) (s : Nat)
    (h_ord : ordered e)
    (h_le_third : s ≤ e.third) :
    ordered (promote e s) := by
  obtain ⟨h1, h2⟩ := h_ord
  simp only [ordered, promote]
  exact ⟨h2, h_le_third⟩

/-- promote: new best equals old second -/
theorem promote_best_eq_old_second (e : Estimates) (s : Nat) :
    (promote e s).best = e.second := by
  simp [promote]

/-- promote: new second equals old third -/
theorem promote_second_eq_old_third (e : Estimates) (s : Nat) :
    (promote e s).second = e.third := by
  simp [promote]

/-! ## The key update case analysis -/

-- The three update cases correspond to three non-overlapping regions:
-- * case 1: new > best     → reset (all three become s)
-- * case 2: new > second   → update_second_third
-- * case 3: new > third    → update_third_only
-- * case 4: new ≤ third    → no change (implicit: third unchanged)
-- Each case preserves ordered when starting from an ordered state.

/-- Case 2 of update preserves ordering -/
theorem update_case2_ordered (e : Estimates) (s : Nat)
    (h_ord : ordered e)
    (h_gt_second : s > e.second)
    (h_le_best : s ≤ e.best) :
    ordered (update_second_third e s) :=
  update_second_third_ordered e s h_ord h_le_best

/-- Case 3 of update preserves ordering -/
theorem update_case3_ordered (e : Estimates) (s : Nat)
    (h_ord : ordered e)
    (h_gt_third : s > e.third)
    (h_le_second : s ≤ e.second) :
    ordered (update_third_only e s) :=
  update_third_only_ordered e s h_ord h_le_second

/-- Case 4 (no change) trivially preserves ordering -/
theorem update_case4_ordered (e : Estimates)
    (h_ord : ordered e) :
    ordered e := h_ord

/-! ## Combined update correctness -/

/-- Model of the pure update logic (abstracting time checks):
    Given the current estimates and a new sample, choose the update case. -/
def update_pure (e : Estimates) (s : Nat) : Estimates :=
  if s > e.best then
    reset s
  else if s > e.second then
    update_second_third e s
  else if s > e.third then
    update_third_only e s
  else
    e

/-- The pure update always produces an ordered result from an ordered input -/
theorem update_pure_preserves_ordered (e : Estimates) (s : Nat)
    (h_ord : ordered e) :
    ordered (update_pure e s) := by
  simp only [update_pure]
  by_cases h1 : s > e.best
  · simp [h1, reset_ordered]
  · simp only [h1, ite_false]
    by_cases h2 : s > e.second
    · simp [h2, update_second_third_ordered e s h_ord (Nat.le_of_not_lt h1)]
    · simp only [h2, ite_false]
      by_cases h3 : s > e.third
      · simp [h3, update_third_only_ordered e s h_ord (Nat.le_of_not_lt h2)]
      · simp [h3, h_ord]

/-- update_pure best is always ≥ the new sample (the best never decreases) -/
theorem update_pure_best_ge_sample (e : Estimates) (s : Nat)
    (h_ord : ordered e) :
    (update_pure e s).best ≥ s := by
  simp only [update_pure]
  by_cases h1 : s > e.best
  · simp [h1, reset]
  · simp only [h1, ite_false]
    by_cases h2 : s > e.second
    · simp [h2, update_second_third]; exact Nat.le_of_not_lt h1
    · simp only [h2, ite_false]
      by_cases h3 : s > e.third
      · simp [h3, update_third_only]; exact Nat.le_of_not_lt h1
      · simp [h3]; exact Nat.le_of_not_lt h1

/-- Iterated updates preserve ordering -/
theorem update_pure_iter_ordered (e : Estimates) (samples : List Nat)
    (h_ord : ordered e) :
    ordered (samples.foldl update_pure e) := by
  induction samples generalizing e with
  | nil => exact h_ord
  | cons s ss ih =>
    apply ih
    exact update_pure_preserves_ordered e s h_ord

/-! ## Examples -/

-- update_pure (reset 10) 7: 7 ≤ 10, so unchanged → all 10
#eval reset 10          -- { best := 10, second := 10, third := 10 }
#eval update_pure (reset 10) 7   -- all 10 (7 ≤ third=10, no change)
#eval update_pure (reset 10) 11  -- resets to all 11
-- update_pure after a non-uniform state
#eval update_pure { best := 15, second := 10, third := 5 } 8
  -- 8 > third=5, so third becomes 8

example : ordered (reset 42) := reset_ordered 42

example : (update_pure (reset 10) 7).best = 10 := by native_decide
example : (update_pure (reset 10) 7).second = 10 := by native_decide
-- 7 ≤ third (10), so third stays 10
example : (update_pure (reset 10) 7).third = 10 := by native_decide
example : (update_pure (reset 10) 11).best = 11 := by native_decide
-- After reset 10 then update 8: 8 > 10 false, 8 > 10 false, 8 > 10 false → no change
example : (update_pure (reset 10) 8).best = 10 := by native_decide
-- Non-uniform: update { best=15, second=10, third=5 } 8 → third=8
example : (update_pure { best := 15, second := 10, third := 5 } 8).third = 8 :=
  by native_decide
example : (update_pure { best := 15, second := 10, third := 5 } 8).best = 15 :=
  by native_decide

end WindowedFilter
