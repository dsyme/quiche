-- Copyright (C) 2018-2025, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of BBR2 CyclePhase pacing and
-- cwnd gain assignment invariants.
--
-- Target: T73 — BBR2 CyclePhase gain dispatch
-- Source: quiche/src/recovery/gcongestion/bbr2/mode.rs
--         quiche/src/recovery/gcongestion/bbr2.rs (DEFAULT_PARAMS)
-- Spec:   formal-verification/specs/bbr2_cycle_phase_gain_informal.md
-- Phase:  5 — Implementation + Proofs
-- Lean 4 (v4.29.1), no Mathlib dependency.
--
-- Background
-- ──────────
-- BBR2's ProbeBW state is split into five cycle phases:
--   NotStarted, Up, Down, Cruise, Refill
-- Each phase uses a specific pacing gain and cwnd gain taken from the
-- BBR2 parameter set.
--
-- CyclePhase::pacing_gain (Rust):
--   Up   → probe_bw_probe_up_pacing_gain    (DEFAULT: 1.25 = 5/4)
--   Down → probe_bw_probe_down_pacing_gain   (DEFAULT: 0.90 = 9/10)
--   _    → probe_bw_default_pacing_gain      (DEFAULT: 1.00 = 1/1)
--
-- CyclePhase::cwnd_gain (Rust):
--   Up   → probe_bw_up_cwnd_gain             (DEFAULT: 2.25 = 9/4)
--   _    → probe_bw_cwnd_gain                (DEFAULT: 2.00 = 2/1)
--
-- We model f32 gains as exact integer fractions (Gain = num / den).
-- All theorems proved by `decide` or `omega`.
--
-- Sections
-- ────────
--   §1  Gain representation (same Gain structure as T70/T71/T72)
--   §2  CyclePhase type
--   §3  ProbeBWParams record
--   §4  Gain dispatch functions
--   §5  Default parameter values
--   §6  Theorems — individual gain classifications
--   §7  Theorems — pacing gain ordering
--   §8  Theorems — cwnd gain ordering
--   §9  Theorems — phase partition
--   §10 Theorems — applyGain monotonicity

namespace FVSquad.BBR2CyclePhaseGain

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  Gain representation
-- ─────────────────────────────────────────────────────────────────────────────

/-- A non-negative gain represented as an exact fraction `num / den`.
    `den > 0` is a precondition of all arithmetic theorems. -/
structure Gain where
  num : Nat
  den : Nat
  deriving Repr, DecidableEq

/-- Gain is super-unity (> 1.0) when num > den. -/
def Gain.isSuperUnity (g : Gain) : Prop := g.num > g.den

instance Gain.isSuperUnity_decidable (g : Gain) : Decidable (Gain.isSuperUnity g) :=
  inferInstanceAs (Decidable (g.num > g.den))

/-- Gain is unity (= 1.0) when num = den. -/
def Gain.isUnity (g : Gain) : Prop := g.num = g.den

instance Gain.isUnity_decidable (g : Gain) : Decidable (Gain.isUnity g) :=
  inferInstanceAs (Decidable (g.num = g.den))

/-- Gain is sub-unity (< 1.0) when num < den. -/
def Gain.isSubUnity (g : Gain) : Prop := g.num < g.den

instance Gain.isSubUnity_decidable (g : Gain) : Decidable (Gain.isSubUnity g) :=
  inferInstanceAs (Decidable (g.num < g.den))

/-- g1 < g2 as fractions: g1.num * g2.den < g2.num * g1.den. -/
def Gain.lt (g1 g2 : Gain) : Prop := g1.num * g2.den < g2.num * g1.den

instance Gain.lt_decidable (g1 g2 : Gain) : Decidable (Gain.lt g1 g2) :=
  inferInstanceAs (Decidable (g1.num * g2.den < g2.num * g1.den))

/-- g1 ≤ g2 as fractions: g1.num * g2.den ≤ g2.num * g1.den. -/
def Gain.le (g1 g2 : Gain) : Prop := g1.num * g2.den ≤ g2.num * g1.den

instance Gain.le_decidable (g1 g2 : Gain) : Decidable (Gain.le g1 g2) :=
  inferInstanceAs (Decidable (g1.num * g2.den ≤ g2.num * g1.den))

/-- Apply a gain to a bandwidth value: result = bw * num / den.
    Uses natural-number (floor) division. -/
def applyGain (bw : Nat) (g : Gain) : Nat := bw * g.num / g.den

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  CyclePhase type
-- ─────────────────────────────────────────────────────────────────────────────

/-- BBR2 ProbeBW cycle phases.
    Source: enum CyclePhase in mode.rs -/
inductive CyclePhase where
  | NotStarted
  | Up
  | Down
  | Cruise
  | Refill
  deriving Repr, DecidableEq

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  ProbeBWParams record
-- ─────────────────────────────────────────────────────────────────────────────

/-- The subset of BBR2 Params relevant to ProbeBW gain assignment.
    Source: struct Params in bbr2.rs -/
structure ProbeBWParams where
  /-- Pacing gain for the Up phase (default: 1.25 = 5/4). -/
  upPacingGain     : Gain
  /-- Pacing gain for the Down phase (default: 0.90 = 9/10). -/
  downPacingGain   : Gain
  /-- Pacing gain for all other phases (default: 1.00 = 1/1). -/
  defaultPacingGain : Gain
  /-- CWND gain for the Up phase (default: 2.25 = 9/4). -/
  upCwndGain       : Gain
  /-- CWND gain for all non-Up phases (default: 2.00 = 2/1). -/
  cwndGain         : Gain
  deriving Repr

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Gain dispatch functions
-- ─────────────────────────────────────────────────────────────────────────────

/-- Map a CyclePhase to its pacing gain.
    Models CyclePhase::pacing_gain in mode.rs. -/
def pacingGain (p : CyclePhase) (params : ProbeBWParams) : Gain :=
  match p with
  | CyclePhase.Up   => params.upPacingGain
  | CyclePhase.Down => params.downPacingGain
  | _               => params.defaultPacingGain

/-- Map a CyclePhase to its cwnd gain.
    Models CyclePhase::cwnd_gain in mode.rs. -/
def cwndGain (p : CyclePhase) (params : ProbeBWParams) : Gain :=
  match p with
  | CyclePhase.Up => params.upCwndGain
  | _             => params.cwndGain

-- ─────────────────────────────────────────────────────────────────────────────
-- §5  Default parameter values from DEFAULT_PARAMS
-- ─────────────────────────────────────────────────────────────────────────────

/-- DEFAULT_PARAMS values for ProbeBW gains.
    Source: const DEFAULT_PARAMS: Params = Params { ... } in bbr2.rs
      probe_bw_probe_up_pacing_gain:   1.25  → 5/4
      probe_bw_probe_down_pacing_gain: 0.90  → 9/10
      probe_bw_default_pacing_gain:    1.00  → 1/1
      probe_bw_up_cwnd_gain:           2.25  → 9/4
      probe_bw_cwnd_gain:              2.00  → 2/1  -/
def defaultParams : ProbeBWParams := {
  upPacingGain      := { num := 5, den := 4  }
  downPacingGain    := { num := 9, den := 10 }
  defaultPacingGain := { num := 1, den := 1  }
  upCwndGain        := { num := 9, den := 4  }
  cwndGain          := { num := 2, den := 1  }
}

-- ─────────────────────────────────────────────────────────────────────────────
-- §6  Theorems — individual gain classifications
-- ─────────────────────────────────────────────────────────────────────────────

/-- The Up pacing gain (5/4) is super-unity. -/
theorem upPacingGain_superUnity :
    defaultParams.upPacingGain.isSuperUnity := by decide

/-- The Down pacing gain (9/10) is sub-unity. -/
theorem downPacingGain_subUnity :
    defaultParams.downPacingGain.isSubUnity := by decide

/-- The default pacing gain (1/1) is unity. -/
theorem defaultPacingGain_unity :
    defaultParams.defaultPacingGain.isUnity := by decide

/-- The Up cwnd gain (9/4) is super-unity. -/
theorem upCwndGain_superUnity :
    defaultParams.upCwndGain.isSuperUnity := by decide

/-- The non-Up cwnd gain (2/1) is super-unity. -/
theorem cwndGain_superUnity :
    defaultParams.cwndGain.isSuperUnity := by decide

-- ─────────────────────────────────────────────────────────────────────────────
-- §7  Theorems — pacing gain ordering
-- ─────────────────────────────────────────────────────────────────────────────

/-- Down pacing gain < default pacing gain  (9/10 < 1/1, i.e. 9 < 10). -/
theorem downPacingGain_lt_default :
    Gain.lt defaultParams.downPacingGain defaultParams.defaultPacingGain := by
  decide

/-- Default pacing gain < Up pacing gain  (1/1 < 5/4, i.e. 4 < 5). -/
theorem defaultPacingGain_lt_up :
    Gain.lt defaultParams.defaultPacingGain defaultParams.upPacingGain := by
  decide

/-- Down pacing gain < Up pacing gain  (9/10 < 5/4, i.e. 36 < 50). -/
theorem downPacingGain_lt_up :
    Gain.lt defaultParams.downPacingGain defaultParams.upPacingGain := by
  decide

/-- Pacing gains are strictly ordered: Down < Default < Up. -/
theorem pacingGain_ordering :
    Gain.lt defaultParams.downPacingGain defaultParams.defaultPacingGain ∧
    Gain.lt defaultParams.defaultPacingGain defaultParams.upPacingGain := by
  decide

/-- The Up pacing gain is the largest pacing gain. -/
theorem upPacingGain_is_max :
    Gain.le defaultParams.downPacingGain defaultParams.upPacingGain ∧
    Gain.le defaultParams.defaultPacingGain defaultParams.upPacingGain := by
  decide

/-- The Down pacing gain is the smallest pacing gain. -/
theorem downPacingGain_is_min :
    Gain.le defaultParams.downPacingGain defaultParams.defaultPacingGain ∧
    Gain.le defaultParams.downPacingGain defaultParams.upPacingGain := by
  decide

-- ─────────────────────────────────────────────────────────────────────────────
-- §8  Theorems — cwnd gain ordering
-- ─────────────────────────────────────────────────────────────────────────────

/-- Non-Up cwnd gain < Up cwnd gain  (2/1 < 9/4, i.e. 8 < 9). -/
theorem cwndGain_lt_upCwndGain :
    Gain.lt defaultParams.cwndGain defaultParams.upCwndGain := by
  decide

/-- Up cwnd gain (9/4) is strictly greater than non-Up cwnd gain (2/1). -/
theorem upCwndGain_gt_cwndGain :
    defaultParams.upCwndGain.num * defaultParams.cwndGain.den >
    defaultParams.cwndGain.num * defaultParams.upCwndGain.den := by
  decide

-- ─────────────────────────────────────────────────────────────────────────────
-- §9  Theorems — phase partition
-- ─────────────────────────────────────────────────────────────────────────────

/-- Only the Up phase uses the elevated pacing gain. -/
theorem up_is_only_elevated_pacing :
    ∀ p : CyclePhase,
      pacingGain p defaultParams = defaultParams.upPacingGain ↔
      p = CyclePhase.Up := by
  intro p; cases p <;> decide

/-- Only the Down phase uses the sub-default pacing gain. -/
theorem down_is_only_reduced_pacing :
    ∀ p : CyclePhase,
      pacingGain p defaultParams = defaultParams.downPacingGain ↔
      p = CyclePhase.Down := by
  intro p; cases p <;> decide

/-- NotStarted, Cruise, and Refill all use the default pacing gain. -/
theorem default_pacing_phases :
    pacingGain CyclePhase.NotStarted defaultParams =
      defaultParams.defaultPacingGain ∧
    pacingGain CyclePhase.Cruise defaultParams =
      defaultParams.defaultPacingGain ∧
    pacingGain CyclePhase.Refill defaultParams =
      defaultParams.defaultPacingGain := by
  decide

/-- Only the Up phase uses the elevated cwnd gain. -/
theorem up_is_only_elevated_cwnd :
    ∀ p : CyclePhase,
      cwndGain p defaultParams = defaultParams.upCwndGain ↔
      p = CyclePhase.Up := by
  intro p; cases p <;> decide

/-- All non-Up phases use the same cwnd gain. -/
theorem nonUp_cwnd_gain_uniform :
    cwndGain CyclePhase.NotStarted defaultParams = defaultParams.cwndGain ∧
    cwndGain CyclePhase.Down defaultParams = defaultParams.cwndGain ∧
    cwndGain CyclePhase.Cruise defaultParams = defaultParams.cwndGain ∧
    cwndGain CyclePhase.Refill defaultParams = defaultParams.cwndGain := by
  decide

/-- The Up phase uses BOTH the elevated pacing gain and the elevated cwnd gain.
    No other phase uses both elevated gains simultaneously. -/
theorem up_uses_both_elevated_gains :
    ∀ p : CyclePhase,
      (pacingGain p defaultParams = defaultParams.upPacingGain ∧
       cwndGain p defaultParams = defaultParams.upCwndGain) ↔
      p = CyclePhase.Up := by
  intro p; cases p <;> decide

-- ─────────────────────────────────────────────────────────────────────────────
-- §10  Theorems — applyGain monotonicity
-- ─────────────────────────────────────────────────────────────────────────────

/-- applyGain is monotone in bandwidth: if bw1 ≤ bw2 then
    applyGain bw1 g ≤ applyGain bw2 g. -/
theorem applyGain_mono (bw1 bw2 : Nat) (g : Gain) (h : bw1 ≤ bw2) :
    applyGain bw1 g ≤ applyGain bw2 g := by
  unfold applyGain
  apply Nat.div_le_div_right
  exact Nat.mul_le_mul_right g.num h

/-- applyGain with a zero bandwidth yields zero. -/
theorem applyGain_zero (g : Gain) : applyGain 0 g = 0 := by
  unfold applyGain
  simp

/-- Applying the unity gain (num = den, den > 0) preserves bandwidth exactly. -/
theorem applyGain_unity (bw : Nat) (g : Gain) (hu : g.isUnity) (hd : g.den > 0) :
    applyGain bw g = bw := by
  unfold applyGain Gain.isUnity at *
  rw [hu]
  exact Nat.mul_div_cancel bw hd

/-- Applying the Up pacing gain to any bandwidth yields at least that bandwidth.
    (5/4 ≥ 1, so bw * 5 / 4 ≥ bw because bw * 4 ≤ bw * 5.) -/
theorem upPacingGain_ge_unity_applied (bw : Nat) :
    applyGain bw defaultParams.upPacingGain ≥ bw := by
  unfold applyGain
  simp only [defaultParams]
  -- Goal: bw * 5 / 4 ≥ bw
  have hle : bw * 4 ≤ bw * 5 := Nat.mul_le_mul_left bw (by decide)
  have hdiv : bw * 4 / 4 ≤ bw * 5 / 4 := Nat.div_le_div_right hle
  have heq : bw * 4 / 4 = bw := Nat.mul_div_cancel bw (by decide)
  omega

end FVSquad.BBR2CyclePhaseGain
