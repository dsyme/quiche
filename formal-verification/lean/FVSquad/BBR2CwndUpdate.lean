-- Copyright (C) 2025, Cloudflare, Inc.
-- BSD-2-Clause licence (same as quiche)
--
-- 🔬 Lean Squad — formal specification of `update_congestion_window`
-- from BBR2.
--
-- Target T81: BBR2 `update_congestion_window` growth and clamp bounds
-- Source: quiche/src/recovery/gcongestion/bbr2.rs L603–L621
-- Phase: 5 — Implementation + Proofs
-- Lean 4.29.1, no Mathlib dependency.
--
-- The Rust function has two code paths:
--
--   (A) full_bandwidth_reached = true:
--       target' = target_cwnd + max_ack_height
--       cwnd    = min(target', prior_cwnd + bytes_acked)
--
--   (B) full_bandwidth_reached = false:
--       if prior_cwnd < target_cwnd OR prior_cwnd < 2 * initial_cwnd:
--         cwnd = prior_cwnd + bytes_acked
--       else:
--         cwnd unchanged
--
--   followed by two apply_limits clamping passes (mode-limits and cwnd_limits).
--
-- Modelled abstractions:
--   * get_target_congestion_window (f32 gain) is abstracted as an opaque
--     parameter `target_cwnd : Nat`.  The f64 arithmetic is not modelled.
--   * The two apply_limits calls are modelled as a generic `clamp` that
--     keeps cwnd in [lo, hi].  lo/hi are left as parameters so all clamp
--     properties hold without knowing the mode-specific limits.
--   * `full_bandwidth_reached` is a Boolean parameter.
--   * All sizes are Nat (no overflow/underflow, no usize wraparound).
--   * Note: clamping can *raise* cwnd above prior+bytes_acked (if the floor
--     exceeds the pre-clamp value).  Key monotone property: clamping is
--     order-preserving, so cwnd_A ≤ prior+bytes_acked implies
--     clamp(cwnd_A, ·, ·) ≤ clamp(prior+bytes_acked, ·, ·).
--
-- Theorems (18 total, 0 sorry):
--   clamp_le_hi, clamp_ge_lo, clamp_in_range, clamp_identity,
--   clamp_idempotent, clamp_mono,
--   pathA_le_acked, pathA_le_targetPlus, pathA_growth_bounded,
--   pathA_clamp_mono,
--   pathB_grow_cwnd, pathB_grow_ge_prior, pathB_grow_mono,
--   pathB_noop_unchanged,
--   clamp2_le_hi2, clamp2_mono,
--   clamp2_pathA_growth_bounded, clamp2_pathB_grow_eq

namespace FVSquad.BBR2CwndUpdate

-- ---------------------------------------------------------------------------
-- §1  Clamp primitive
--     Mirrors Limits::apply_limits: val.max(lo).min(hi)
--     = Nat.min (Nat.max val lo) hi
-- ---------------------------------------------------------------------------

/-- Generic clamp: raise `val` to `lo`, then cap at `hi`. -/
def clamp (val lo hi : Nat) : Nat :=
  Nat.min (Nat.max val lo) hi

-- ---------------------------------------------------------------------------
-- §2  Clamp lemmas
-- ---------------------------------------------------------------------------

/-- Clamp output ≤ hi (always). -/
theorem clamp_le_hi (val lo hi : Nat) :
    clamp val lo hi ≤ hi :=
  Nat.min_le_right _ _

/-- When lo ≤ hi, clamp output ≥ lo. -/
theorem clamp_ge_lo {val lo hi : Nat} (hv : lo ≤ hi) :
    lo ≤ clamp val lo hi := by
  simp only [clamp]
  exact Nat.le_min.mpr ⟨Nat.le_max_right val lo, hv⟩

/-- When lo ≤ hi, clamp is in [lo, hi]. -/
theorem clamp_in_range {val lo hi : Nat} (hv : lo ≤ hi) :
    lo ≤ clamp val lo hi ∧ clamp val lo hi ≤ hi :=
  ⟨clamp_ge_lo hv, clamp_le_hi val lo hi⟩

/-- If val is already in [lo, hi], clamp is the identity. -/
theorem clamp_identity {val lo hi : Nat} (hl : lo ≤ val) (hh : val ≤ hi) :
    clamp val lo hi = val := by
  simp only [clamp, Nat.max_eq_left hl, Nat.min_eq_left hh]

/-- Clamp is idempotent (applying it twice gives the same result). -/
theorem clamp_idempotent (val lo hi : Nat) :
    clamp (clamp val lo hi) lo hi = clamp val lo hi := by
  by_cases hv : lo ≤ hi
  · exact clamp_identity (clamp_ge_lo hv) (clamp_le_hi val lo hi)
  · have hlt : hi < lo := Nat.lt_of_not_le hv
    have hle : hi ≤ lo := Nat.le_of_lt hlt
    simp only [clamp]
    have hxeq : Nat.min (Nat.max val lo) hi = hi :=
      Nat.min_eq_right (Nat.le_trans hle (Nat.le_max_right val lo))
    rw [hxeq]
    exact Nat.min_eq_right (Nat.le_trans hle (Nat.le_max_right hi lo))

/-- Clamp is monotone: larger input → larger (or equal) output. -/
theorem clamp_mono {a b lo hi : Nat} (h : a ≤ b) :
    clamp a lo hi ≤ clamp b lo hi := by
  simp only [clamp]
  have h_max : Nat.max a lo ≤ Nat.max b lo :=
    Nat.max_le.mpr ⟨Nat.le_trans h (Nat.le_max_left b lo), Nat.le_max_right b lo⟩
  exact Nat.le_min.mpr ⟨Nat.le_trans (Nat.min_le_left _ _) h_max, Nat.min_le_right _ _⟩

-- ---------------------------------------------------------------------------
-- §3  Path A: full_bandwidth_reached = true
--
--   target' = target_cwnd + max_ack_height
--   cwnd_A  = min(target', prior + bytes_acked)
-- ---------------------------------------------------------------------------

/-- Raw (pre-clamp) cwnd for path A. -/
def cwndA (prior bytes_acked target_cwnd ack_height : Nat) : Nat :=
  Nat.min (target_cwnd + ack_height) (prior + bytes_acked)

/-- Path A: cwnd ≤ prior + bytes_acked (growth capped by acked bytes). -/
theorem pathA_le_acked (prior bytes_acked target_cwnd ack_height : Nat) :
    cwndA prior bytes_acked target_cwnd ack_height ≤ prior + bytes_acked :=
  Nat.min_le_right _ _

/-- Path A: cwnd ≤ target_cwnd + ack_height. -/
theorem pathA_le_targetPlus (prior bytes_acked target_cwnd ack_height : Nat) :
    cwndA prior bytes_acked target_cwnd ack_height ≤ target_cwnd + ack_height :=
  Nat.min_le_left _ _

/-- Monotone bound: clamp(cwnd_A) ≤ clamp(prior + bytes_acked). -/
theorem pathA_growth_bounded (prior bytes_acked target_cwnd ack_height lo hi : Nat) :
    clamp (cwndA prior bytes_acked target_cwnd ack_height) lo hi ≤
    clamp (prior + bytes_acked) lo hi :=
  clamp_mono (pathA_le_acked prior bytes_acked target_cwnd ack_height)

/-- Clamping is monotone in path A: larger bytes_acked → larger (or equal) cwnd. -/
theorem pathA_clamp_mono
    (prior ba1 ba2 tc ah lo hi : Nat) (h : ba1 ≤ ba2) :
    clamp (cwndA prior ba1 tc ah) lo hi ≤ clamp (cwndA prior ba2 tc ah) lo hi := by
  apply clamp_mono
  simp only [cwndA]
  exact Nat.le_min.mpr
    ⟨Nat.min_le_left _ _, Nat.le_trans (Nat.min_le_right _ _) (Nat.add_le_add_left h _)⟩

-- ---------------------------------------------------------------------------
-- §4  Path B: full_bandwidth_reached = false
-- ---------------------------------------------------------------------------

/-- The "grow" condition: prior < target OR prior < 2 * initial_cwnd. -/
def growCondition (prior target_cwnd initial_cwnd : Nat) : Prop :=
  prior < target_cwnd ∨ prior < 2 * initial_cwnd

/-- Raw cwnd for path B. -/
def cwndB (prior bytes_acked target_cwnd initial_cwnd : Nat) : Nat :=
  if prior < target_cwnd ∨ prior < 2 * initial_cwnd
  then prior + bytes_acked
  else prior

/-- Path B grow case: cwnd = prior + bytes_acked. -/
theorem pathB_grow_cwnd (prior bytes_acked target_cwnd initial_cwnd : Nat)
    (h : growCondition prior target_cwnd initial_cwnd) :
    cwndB prior bytes_acked target_cwnd initial_cwnd = prior + bytes_acked :=
  if_pos h

/-- Path B grow case: cwnd ≥ prior (never shrinks). -/
theorem pathB_grow_ge_prior (prior bytes_acked target_cwnd initial_cwnd : Nat)
    (h : growCondition prior target_cwnd initial_cwnd) :
    prior ≤ cwndB prior bytes_acked target_cwnd initial_cwnd := by
  rw [pathB_grow_cwnd prior bytes_acked target_cwnd initial_cwnd h]
  exact Nat.le_add_right _ _

/-- Path B grow case: monotone in bytes_acked. -/
theorem pathB_grow_mono (prior ba1 ba2 target_cwnd initial_cwnd : Nat)
    (h : growCondition prior target_cwnd initial_cwnd) (hba : ba1 ≤ ba2) :
    cwndB prior ba1 target_cwnd initial_cwnd ≤
    cwndB prior ba2 target_cwnd initial_cwnd := by
  rw [pathB_grow_cwnd prior ba1 target_cwnd initial_cwnd h,
      pathB_grow_cwnd prior ba2 target_cwnd initial_cwnd h]
  exact Nat.add_le_add_left hba _

/-- Path B noop case: cwnd is unchanged. -/
theorem pathB_noop_unchanged (prior bytes_acked target_cwnd initial_cwnd : Nat)
    (h : ¬growCondition prior target_cwnd initial_cwnd) :
    cwndB prior bytes_acked target_cwnd initial_cwnd = prior :=
  if_neg h

-- ---------------------------------------------------------------------------
-- §5  Two-stage clamping
--
--   The Rust code applies two clamp passes in sequence:
--     cwnd := mode_limits.apply_limits(cwnd)    -- mode-specific limits
--     cwnd := cwnd_limits.apply_limits(cwnd)     -- per-connection limits
--
--   Modelled as clamp(clamp(x, lo1, hi1), lo2, hi2).
-- ---------------------------------------------------------------------------

/-- Two-stage clamp. -/
def clamp2 (val lo1 hi1 lo2 hi2 : Nat) : Nat :=
  clamp (clamp val lo1 hi1) lo2 hi2

/-- Two-stage clamp stays ≤ hi2 (the outer cap). -/
theorem clamp2_le_hi2 (val lo1 hi1 lo2 hi2 : Nat) :
    clamp2 val lo1 hi1 lo2 hi2 ≤ hi2 :=
  clamp_le_hi _ lo2 hi2

/-- Two-stage clamp is monotone. -/
theorem clamp2_mono {a b lo1 hi1 lo2 hi2 : Nat} (h : a ≤ b) :
    clamp2 a lo1 hi1 lo2 hi2 ≤ clamp2 b lo1 hi1 lo2 hi2 :=
  clamp_mono (clamp_mono h)

/-- Two-stage clamp in path A: monotone bound by clamp2(prior + bytes_acked). -/
theorem clamp2_pathA_growth_bounded
    (prior bytes_acked target_cwnd ack_height lo1 hi1 lo2 hi2 : Nat) :
    clamp2 (cwndA prior bytes_acked target_cwnd ack_height) lo1 hi1 lo2 hi2 ≤
    clamp2 (prior + bytes_acked) lo1 hi1 lo2 hi2 :=
  clamp2_mono (pathA_le_acked prior bytes_acked target_cwnd ack_height)

/-- Two-stage clamp in path B (grow case) equals clamp2(prior + bytes_acked). -/
theorem clamp2_pathB_grow_eq
    (prior bytes_acked target_cwnd initial_cwnd lo1 hi1 lo2 hi2 : Nat)
    (h : growCondition prior target_cwnd initial_cwnd) :
    clamp2 (cwndB prior bytes_acked target_cwnd initial_cwnd) lo1 hi1 lo2 hi2 =
    clamp2 (prior + bytes_acked) lo1 hi1 lo2 hi2 := by
  rw [pathB_grow_cwnd prior bytes_acked target_cwnd initial_cwnd h]

-- ---------------------------------------------------------------------------
-- §6  Sanity checks (decidable)
-- ---------------------------------------------------------------------------

-- Path A: target + height wins (min(80+30, 100+50) = min(110, 150) = 110)
example : cwndA 100 50 80 30 = 110 := by decide
-- Path A: prior + acked wins (min(200+30, 100+50) = min(230, 150) = 150)
example : cwndA 100 50 200 30 = 150 := by decide
-- Path B grow (prior=80 < target=100): cwnd = 80+50 = 130
example : cwndB 80 50 100 60 = 130 := by decide
-- Path B grow (prior=80 < 2*50=100): cwnd = 80+50 = 130
example : cwndB 80 50 80 50 = 130 := by decide
-- Path B noop (120 ≥ 100 AND 120 ≥ 2*60=120): unchanged
example : cwndB 120 50 100 60 = 120 := by decide
-- clamp in range
example : clamp 50 10 100 = 50 := by decide
-- clamp raises to lo
example : clamp 5 10 100 = 10 := by decide
-- clamp caps at hi
example : clamp 150 10 100 = 100 := by decide
-- two-stage clamp
example : clamp2 150 10 100 20 80 = 80 := by decide

end FVSquad.BBR2CwndUpdate
