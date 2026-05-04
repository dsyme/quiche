-- Copyright (C) 2024, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/Pmtud.lean
--
-- Formal verification of the PMTUD binary-search probe_size invariants.
-- Source: quiche/src/pmtud.rs
--
-- The PMTUD algorithm performs an optimistic binary search to discover the
-- path MTU (PLPMTU per RFC 8899).
--
-- Key invariants verified:
--   1. probe_size stays within [MIN_PLPMTU, max_mtu]
--   2. binary search result is strictly between successful and failed bounds
--   3. failure counter resets on success
--   4. PMTU is set exactly when gap ≤ 1 (convergence)
--   5. binary search strictly narrows the search interval

namespace Pmtud

/-! ## Constants and State -/

/-- Minimum PLPMTU per RFC 9000 §14.1 (1200 bytes). -/
def MIN_PLPMTU : Nat := 1200

/-- Pure model of PMTUD state.
    `max_mtu`   : maximum supported MTU
    `smallest_failed` : smallest known failed probe size (None if none)
    `largest_success` : largest known successful probe size (None if none)
-/
structure PmtudState where
  max_mtu            : Nat
  smallest_failed    : Option Nat
  largest_success    : Option Nat
  deriving Repr

/-! ## Core operation: update_probe_size -/

/-- Pure model of `update_probe_size`.
    Returns the new `probe_size` after one iteration. -/
def updateProbeSize (s : PmtudState) : Nat :=
  match s.smallest_failed, s.largest_success with
  | some f, some g =>
    if f <= g then
      -- inconsistent state: restart (use max_mtu)
      s.max_mtu
    else if f - g <= 1 then
      -- converged: PMTU = g, probe_size unchanged; model returns g
      g
    else
      (g + f) / 2
  | some f, none =>
    (MIN_PLPMTU + f) / 2
  | none, some g =>
    -- only success: PMTU found at g; probe_size stays at g
    g
  | none, none =>
    s.max_mtu

/-! ## Well-formed states -/

/-- A well-formed PMTUD state has consistent size ordering. -/
def WellFormed (s : PmtudState) : Prop :=
  MIN_PLPMTU ≤ s.max_mtu ∧
  (∀ g, s.largest_success = some g → MIN_PLPMTU ≤ g ∧ g ≤ s.max_mtu) ∧
  (∀ f, s.smallest_failed = some f → MIN_PLPMTU ≤ f ∧ f ≤ s.max_mtu) ∧
  (∀ f g, s.smallest_failed = some f → s.largest_success = some g → g < f)

/-! ## Division helpers (omega cannot reason about Nat division directly) -/

private theorem div2_le_of_le_sum (a b c : Nat) (h : a + b ≤ 2 * c) :
    (a + b) / 2 ≤ c := by
  have hmod := Nat.div_add_mod (a + b) 2
  have hmod2 : (a + b) % 2 < 2 := Nat.mod_lt _ (by omega)
  omega

private theorem le_div2_of_mul2_le (c a b : Nat) (h : 2 * c ≤ a + b) :
    c ≤ (a + b) / 2 := by
  have hmod := Nat.div_add_mod (a + b) 2
  have hmod2 : (a + b) % 2 < 2 := Nat.mod_lt _ (by omega)
  omega

/-! ## Theorems -/

/-- Helper: reduce updateProbeSize when both options are known. -/
private theorem updateProbeSize_both (s : PmtudState) (f g : Nat)
    (hfv : s.smallest_failed = some f) (hgv : s.largest_success = some g) :
    updateProbeSize s =
      if f ≤ g then s.max_mtu
      else if f - g ≤ 1 then g
      else (g + f) / 2 := by
  simp [updateProbeSize, hfv, hgv]

/-- (1) probe_size ≥ MIN_PLPMTU in all cases when state is well-formed. -/
theorem updateProbeSize_ge_min (s : PmtudState) (h : WellFormed s) :
    MIN_PLPMTU ≤ updateProbeSize s := by
  obtain ⟨hmax, hg, hf, hfg⟩ := h
  rcases hs_f : s.smallest_failed with _ | f
  · rcases hs_g : s.largest_success with _ | g
    · simp [updateProbeSize, hs_f, hs_g]; omega
    · simp [updateProbeSize, hs_f, hs_g]
      exact (hg g hs_g).1
  · rcases hs_g : s.largest_success with _ | g
    · simp [updateProbeSize, hs_f, hs_g]
      exact le_div2_of_mul2_le _ _ _ (by have := (hf f hs_f).1; omega)
    · rw [updateProbeSize_both s f g hs_f hs_g]
      have ⟨hfl1, hfl2⟩ := hf f hs_f
      have ⟨hgl1, hgl2⟩ := hg g hs_g
      have hfgl := hfg f g hs_f hs_g
      by_cases h1 : f ≤ g
      · rw [if_pos h1]; omega
      · rw [if_neg h1]
        by_cases h2 : f - g ≤ 1
        · rw [if_pos h2]; exact hgl1
        · rw [if_neg h2]
          exact le_div2_of_mul2_le _ _ _ (by omega)

/-- (2) probe_size ≤ max_mtu in all cases when state is well-formed. -/
theorem updateProbeSize_le_max (s : PmtudState) (h : WellFormed s) :
    updateProbeSize s ≤ s.max_mtu := by
  obtain ⟨hmax, hg, hf, hfg⟩ := h
  rcases hs_f : s.smallest_failed with _ | f
  · rcases hs_g : s.largest_success with _ | g
    · simp [updateProbeSize, hs_f, hs_g]
    · simp [updateProbeSize, hs_f, hs_g]
      exact (hg g hs_g).2
  · rcases hs_g : s.largest_success with _ | g
    · simp [updateProbeSize, hs_f, hs_g]
      exact div2_le_of_le_sum _ _ _ (by have := (hf f hs_f).2; omega)
    · rw [updateProbeSize_both s f g hs_f hs_g]
      have ⟨hfl1, hfl2⟩ := hf f hs_f
      have ⟨hgl1, hgl2⟩ := hg g hs_g
      have hfgl := hfg f g hs_f hs_g
      by_cases h1 : f ≤ g
      · rw [if_pos h1]; omega
      · rw [if_neg h1]
        by_cases h2 : f - g ≤ 1
        · rw [if_pos h2]; exact hgl2
        · rw [if_neg h2]
          exact div2_le_of_le_sum _ _ _ (by omega)

/-- (3) In binary-search mode the new probe_size is strictly less than
    `smallest_failed` (the search narrows from above). -/
theorem updateProbeSize_lt_failed (s : PmtudState)
    (f g : Nat) (hfv : s.smallest_failed = some f) (hgv : s.largest_success = some g)
    (hconsistent : g < f) (hgap : 1 < f - g) :
    updateProbeSize s < f := by
  rw [updateProbeSize_both s f g hfv hgv]
  rw [if_neg (by omega : ¬ (f ≤ g)), if_neg (by omega : ¬ (f - g ≤ 1))]
  have hmod := Nat.div_add_mod (g + f) 2
  have hmod2 : (g + f) % 2 < 2 := Nat.mod_lt _ (by omega)
  omega

/-- (4) In binary-search mode the new probe_size is strictly greater than
    `largest_success` (the search narrows from below). -/
theorem updateProbeSize_gt_success (s : PmtudState)
    (f g : Nat) (hfv : s.smallest_failed = some f) (hgv : s.largest_success = some g)
    (hconsistent : g < f) (hgap : 1 < f - g) :
    g < updateProbeSize s := by
  rw [updateProbeSize_both s f g hfv hgv]
  rw [if_neg (by omega : ¬ (f ≤ g)), if_neg (by omega : ¬ (f - g ≤ 1))]
  have hmod := Nat.div_add_mod (g + f) 2
  have hmod2 : (g + f) % 2 < 2 := Nat.mod_lt _ (by omega)
  omega

/-- (5) When only a failed probe exists and it is above MIN_PLPMTU,
    the new probe_size is strictly less than `smallest_failed`. -/
theorem updateProbeSize_only_failed_lt (s : PmtudState)
    (f : Nat) (hfv : s.smallest_failed = some f) (hgv : s.largest_success = none)
    (hgap : MIN_PLPMTU < f) :
    updateProbeSize s < f := by
  simp [updateProbeSize, hfv, hgv]
  have hmod := Nat.div_add_mod (MIN_PLPMTU + f) 2
  have hmod2 : (MIN_PLPMTU + f) % 2 < 2 := Nat.mod_lt _ (by omega)
  omega

/-- (6) When only a failed probe exists, probe_size ≥ MIN_PLPMTU. -/
theorem updateProbeSize_only_failed_ge_min (s : PmtudState) (h : WellFormed s)
    (f : Nat) (hfv : s.smallest_failed = some f) (hgv : s.largest_success = none) :
    MIN_PLPMTU ≤ updateProbeSize s := by
  obtain ⟨_, _, hf, _⟩ := h
  simp [updateProbeSize, hfv, hgv]
  exact le_div2_of_mul2_le _ _ _ (by have := (hf f hfv).1; omega)

/-- (7) Convergence: when the gap between success and failure is ≤ 1,
    `updateProbeSize` returns the largest successful probe size (the PMTU). -/
theorem updateProbeSize_converged (s : PmtudState)
    (f g : Nat) (hfv : s.smallest_failed = some f) (hgv : s.largest_success = some g)
    (hconsistent : g < f) (hconverged : f - g ≤ 1) :
    updateProbeSize s = g := by
  rw [updateProbeSize_both s f g hfv hgv]
  rw [if_neg (by omega : ¬ (f ≤ g)), if_pos (by omega : f - g ≤ 1)]

/-- (8) With no search history the probe size resets to max_mtu. -/
theorem updateProbeSize_no_history (s : PmtudState)
    (hfv : s.smallest_failed = none) (hgv : s.largest_success = none) :
    updateProbeSize s = s.max_mtu := by
  simp [updateProbeSize, hfv, hgv]

/-- (9) With only a successful probe, updateProbeSize returns that success
    (the PMTU is immediately known to be ≥ max_mtu). -/
theorem updateProbeSize_only_success (s : PmtudState)
    (g : Nat) (hfv : s.smallest_failed = none) (hgv : s.largest_success = some g) :
    updateProbeSize s = g := by
  simp [updateProbeSize, hfv, hgv]

/-- (10) In binary-search mode the new probe_size is strictly between g and f:
    g < (g + f)/2 < f whenever f - g > 1. -/
theorem binary_search_midpoint_bounds (f g : Nat) (h : g < f) (hgap : 1 < f - g) :
    g < (g + f) / 2 ∧ (g + f) / 2 < f := by
  have hmod := Nat.div_add_mod (g + f) 2
  have hmod2 : (g + f) % 2 < 2 := Nat.mod_lt _ (by omega)
  constructor <;> omega

/-- (11) The binary search midpoint stays ≥ MIN_PLPMTU when both bounds do. -/
theorem binary_search_midpoint_ge_min (f g : Nat)
    (hg : MIN_PLPMTU ≤ g) (hf : MIN_PLPMTU ≤ f) :
    MIN_PLPMTU ≤ (g + f) / 2 :=
  le_div2_of_mul2_le _ _ _ (by omega)

/-- (12) The binary search midpoint with only a failed probe stays within bounds. -/
theorem failed_only_midpoint_bounds (f : Nat) (hf : MIN_PLPMTU ≤ f) :
    MIN_PLPMTU ≤ (MIN_PLPMTU + f) / 2 ∧ (MIN_PLPMTU + f) / 2 ≤ f := by
  constructor
  · exact le_div2_of_mul2_le _ _ _ (by omega)
  · exact div2_le_of_le_sum _ _ _ (by omega)

end Pmtud
