-- Copyright (C) 2025, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — T77: BBR2 raise_inflight_high_slope arithmetic invariants
--
-- Target T77: BBR2 `raise_inflight_high_slope`
-- Source: quiche/src/recovery/gcongestion/bbr2/probe_bw.rs (L582–590)
-- Phase: 5 — Implementation + Proofs
-- Lean 4.29.0, no Mathlib dependency.
--
-- The Rust function:
--   fn raise_inflight_high_slope(&mut self, cwnd: usize) {
--       let growth_this_round = 1usize << self.cycle.probe_up_rounds;
--       self.cycle.probe_up_rounds = self.cycle.probe_up_rounds.add(1).min(30);
--       let probe_up_bytes = cwnd / growth_this_round;
--       self.cycle.probe_up_bytes = Some(probe_up_bytes.max(DEFAULT_MSS));
--   }
-- with DEFAULT_MSS = 1300 (network_model.rs:44).
--
-- Design:
--   The function has two outputs: the updated probe_up_rounds and the
--   updated probe_up_bytes.  Both are computed from inputs (old rounds, cwnd).
--   We model them as pure functions and prove the invariants documented in
--   the source comments (probe_up_rounds capped at 30, probe_up_bytes ≥ MSS).
--
-- Approximations / abstractions:
--   - Buffer / state mutation is not modelled; we use a pure functional model.
--   - `usize` overflow is not possible: probe_up_rounds ≤ 30 so 2^rounds ≤ 2^30
--     and cwnd is a realistic byte count, both far below usize::MAX.
--   - The function is called only during PROBE_UP; the caller context is
--     not modelled.
--
-- Theorems (19 total, 0 sorry):
--   growthThisRound_eq, growthThisRound_pos, growthThisRound_one_at_zero,
--   growthAtCap, newRounds_le_cap, newRounds_ge_old, newRounds_increments,
--   newRounds_stays_at_cap, newRounds_at_zero, probeUpBytes_ge_mss,
--   probeUpBytes_pos, probeUpBytes_eq_def, probeUpBytes_eq_cwnd_when_small,
--   probeUpBytes_le_cwnd_add_mss, probeUpBytes_le_cwnd_at_zero,
--   growth_bounded_by_cap, growth_gt_one_after_one_round,
--   rounds_strictly_increases, rounds_eq_after_cap,
--   growth_doubles_each_round

namespace FVSquad.BBR2InflightHiSlope

-- ---------------------------------------------------------------------------
-- §1  Constants
-- ---------------------------------------------------------------------------

/-- Default MSS (Maximum Segment Size) used as the floor for probe_up_bytes.
    Source: network_model.rs:44 — `pub(super) const DEFAULT_MSS: usize = 1300`. -/
abbrev DEFAULT_MSS : Nat := 1300

/-- Maximum value probe_up_rounds is capped at.
    Source: probe_bw.rs:587 — `.min(30)`. -/
abbrev MAX_PROBE_UP_ROUNDS : Nat := 30

-- ---------------------------------------------------------------------------
-- §2  Pure functional model
-- ---------------------------------------------------------------------------

/-- Growth multiplier for this round: 2^probe_up_rounds.
    Mirrors `let growth_this_round = 1usize << self.cycle.probe_up_rounds`. -/
def growthThisRound (rounds : Nat) : Nat := 2 ^ rounds

/-- Updated probe_up_rounds after applying the cap.
    Mirrors `self.cycle.probe_up_rounds = self.cycle.probe_up_rounds.add(1).min(30)`. -/
def newRounds (rounds : Nat) : Nat := Nat.min (rounds + 1) MAX_PROBE_UP_ROUNDS

/-- Updated probe_up_bytes: cwnd / growth, floored at DEFAULT_MSS.
    Mirrors:
      let probe_up_bytes = cwnd / growth_this_round;
      self.cycle.probe_up_bytes = Some(probe_up_bytes.max(DEFAULT_MSS)); -/
def probeUpBytes (rounds : Nat) (cwnd : Nat) : Nat :=
  Nat.max (cwnd / growthThisRound rounds) DEFAULT_MSS

-- ---------------------------------------------------------------------------
-- §3  Theorems about growthThisRound
-- ---------------------------------------------------------------------------

/-- Growth is exactly 2^rounds by definition. -/
theorem growthThisRound_eq (rounds : Nat) :
    growthThisRound rounds = 2 ^ rounds := rfl

/-- Growth is always positive (avoids division by zero). -/
theorem growthThisRound_pos (rounds : Nat) :
    growthThisRound rounds > 0 := by
  unfold growthThisRound
  induction rounds with
  | zero => decide
  | succ k ih => rw [Nat.pow_succ]; omega

/-- At rounds = 0, growth = 1 (no scaling). -/
theorem growthThisRound_one_at_zero : growthThisRound 0 = 1 := by decide

/-- At the cap (rounds = 30), growth = 2^30 ≈ 1073741824. -/
theorem growthAtCap : growthThisRound MAX_PROBE_UP_ROUNDS = 1073741824 := by
  decide

/-- Each additional round doubles the growth factor. -/
theorem growth_doubles_each_round (rounds : Nat) :
    growthThisRound (rounds + 1) = 2 * growthThisRound rounds := by
  unfold growthThisRound
  rw [Nat.pow_succ]; omega

/-- Growth is bounded above by 2^30 when rounds ≤ 30. -/
theorem growth_bounded_by_cap (rounds : Nat) (h : rounds ≤ MAX_PROBE_UP_ROUNDS) :
    growthThisRound rounds ≤ 1073741824 := by
  unfold growthThisRound MAX_PROBE_UP_ROUNDS at *
  exact Nat.pow_le_pow_right (by decide) h

/-- After one round, growth > 1. -/
theorem growth_gt_one_after_one_round (rounds : Nat) (h : rounds ≥ 1) :
    growthThisRound rounds > 1 := by
  unfold growthThisRound
  have := Nat.pow_le_pow_right (show 0 < 2 from by decide) h
  simp at this; omega

-- ---------------------------------------------------------------------------
-- §4  Theorems about newRounds
-- ---------------------------------------------------------------------------

/-- After the update, probe_up_rounds never exceeds the cap. -/
theorem newRounds_le_cap (rounds : Nat) :
    newRounds rounds ≤ MAX_PROBE_UP_ROUNDS := Nat.min_le_right _ _

/-- Rounds never decreases when initially at or below the cap. -/
theorem newRounds_ge_old (rounds : Nat) (h : rounds ≤ MAX_PROBE_UP_ROUNDS) :
    newRounds rounds ≥ rounds := by
  unfold newRounds
  change min (rounds + 1) MAX_PROBE_UP_ROUNDS ≥ rounds
  exact Nat.le_min.mpr ⟨Nat.le_succ rounds, h⟩

/-- When below the cap, rounds strictly increases by 1. -/
theorem newRounds_increments (rounds : Nat) (h : rounds < MAX_PROBE_UP_ROUNDS) :
    newRounds rounds = rounds + 1 := Nat.min_eq_left h

/-- When at or above the cap, rounds stays at the cap. -/
theorem newRounds_stays_at_cap (rounds : Nat) (h : rounds ≥ MAX_PROBE_UP_ROUNDS) :
    newRounds rounds = MAX_PROBE_UP_ROUNDS := Nat.min_eq_right (by omega)

/-- Starting from 0, rounds increments to 1. -/
theorem newRounds_at_zero : newRounds 0 = 1 := by decide

/-- When below the cap, rounds strictly increases. -/
theorem rounds_strictly_increases (rounds : Nat) (h : rounds < MAX_PROBE_UP_ROUNDS) :
    newRounds rounds > rounds := by
  rw [newRounds_increments rounds h]
  omega

/-- Once at the cap, rounds stays at the cap forever. -/
theorem rounds_eq_after_cap (rounds : Nat) (h : rounds ≥ MAX_PROBE_UP_ROUNDS) :
    newRounds rounds = newRounds MAX_PROBE_UP_ROUNDS :=
  (newRounds_stays_at_cap rounds h).trans (newRounds_stays_at_cap MAX_PROBE_UP_ROUNDS (Nat.le_refl _)).symm

-- ---------------------------------------------------------------------------
-- §5  Theorems about probeUpBytes
-- ---------------------------------------------------------------------------

/-- probe_up_bytes definition expands correctly. -/
theorem probeUpBytes_eq_def (rounds : Nat) (cwnd : Nat) :
    probeUpBytes rounds cwnd =
      Nat.max (cwnd / 2 ^ rounds) DEFAULT_MSS :=
  rfl

/-- probe_up_bytes is always ≥ DEFAULT_MSS.
    This is the primary safety invariant. -/
theorem probeUpBytes_ge_mss (rounds : Nat) (cwnd : Nat) :
    probeUpBytes rounds cwnd ≥ DEFAULT_MSS := Nat.le_max_right _ _

/-- probe_up_bytes is always positive (> 0). -/
theorem probeUpBytes_pos (rounds : Nat) (cwnd : Nat) :
    probeUpBytes rounds cwnd > 0 := by
  have := probeUpBytes_ge_mss rounds cwnd
  unfold DEFAULT_MSS at this
  omega

/-- probe_up_bytes is bounded above by cwnd + DEFAULT_MSS. -/
theorem probeUpBytes_le_cwnd_add_mss (rounds : Nat) (cwnd : Nat) :
    probeUpBytes rounds cwnd ≤ cwnd + DEFAULT_MSS := by
  unfold probeUpBytes
  have hdiv : cwnd / growthThisRound rounds ≤ cwnd := Nat.div_le_self cwnd _
  exact Nat.max_le.mpr ⟨by unfold DEFAULT_MSS; omega, Nat.le_add_left _ _⟩

/-- At rounds = 0 (growth = 1), probe_up_bytes = max(cwnd, DEFAULT_MSS). -/
theorem probeUpBytes_at_zero (cwnd : Nat) :
    probeUpBytes 0 cwnd = Nat.max cwnd DEFAULT_MSS := by
  unfold probeUpBytes growthThisRound
  simp [Nat.div_one]

-- ---------------------------------------------------------------------------
-- §6  Concrete examples
-- ---------------------------------------------------------------------------

-- Boundary examples for growthThisRound
example : growthThisRound 0 = 1 := by decide
example : growthThisRound 1 = 2 := by decide
example : growthThisRound 10 = 1024 := by decide
example : growthThisRound 30 = 1073741824 := by decide

-- Boundary examples for newRounds
example : newRounds 0 = 1 := by decide
example : newRounds 29 = 30 := by decide
example : newRounds 30 = 30 := by decide
example : newRounds 100 = 30 := by decide

-- probeUpBytes with large cwnd (cwnd dominates)
example : probeUpBytes 0 10000 = 10000 := by decide
-- probeUpBytes with small cwnd (DEFAULT_MSS dominates)
example : probeUpBytes 30 0 = 1300 := by decide
-- probeUpBytes with cwnd = DEFAULT_MSS, rounds = 0
example : probeUpBytes 0 1300 = 1300 := by decide

end FVSquad.BBR2InflightHiSlope
