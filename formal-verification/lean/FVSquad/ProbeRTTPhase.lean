-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of BBR2 ProbeRTT phase parameter
-- constants in `quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs` and
-- `quiche/src/recovery/gcongestion/bbr2.rs`.
--
-- Lean 4 (v4.29.1), no Mathlib dependency.
--
-- Background
-- ──────────
-- BBR2's PROBE_RTT phase drains in-flight data below a target so the
-- path's minimum RTT can be measured accurately.  Three dimensionless
-- gains control how aggressively the phase drains:
--
--   pacing_gain (default 1.0, custom 0.8)
--     Scales the pacing rate.  A value < 1 causes the sender to pace
--     *below* the estimated bandwidth, reducing in-flight bytes.
--
--   cwnd_gain (default 1.0, custom 0.5)
--     Scales the congestion window.  A value < 1 caps inflight below
--     the BDP estimate.
--
--   inflight_target_bdp_fraction (always 0.5)
--     Computes the inflight target as `bdp × fraction`.
--     Must be ≤ 1 for the target to be ≤ BDP.
--
-- We model gains as exact rational numbers with a common denominator of 10
-- (one decimal place).  A gain `g = k / 10` is *sub-unity* iff `k < 10`,
-- and *at-most-unity* iff `k ≤ 10`.
--
-- §1  Gain representation and basic lemmas
-- §2  Named constant gains (default and custom ProbeRTT values)
-- §3  Inflight-target computation
-- §4  Theorems
--       sub-unity predicates on custom gains
--       inflight target ≤ BDP (for any sub-unity fraction)
--       pacing below link rate → inflight drains (directional theorem)
--       gain comparison lemmas

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  Gain representation
-- ─────────────────────────────────────────────────────────────────────────────

/-- A non-negative gain represented as an exact fraction `num / den`.
    Both `num` and `den` are natural numbers; we never divide by zero
    in the model — all computations are multiplication-then-division. -/
structure Gain where
  /-- Numerator of the gain fraction. -/
  num : Nat
  /-- Denominator of the gain fraction (must be positive in all uses). -/
  den : Nat

/-- A gain is *sub-unity* when `num < den`, i.e. `num/den < 1`. -/
def Gain.isSubUnity (g : Gain) : Prop := g.num < g.den

/-- A gain is *at-most-unity* when `num ≤ den`, i.e. `num/den ≤ 1`. -/
def Gain.isAtMostUnity (g : Gain) : Prop := g.num ≤ g.den

/-- Sub-unity implies at-most-unity. -/
theorem Gain.subUnity_implies_atMostUnity (g : Gain) (h : g.isSubUnity) :
    g.isAtMostUnity := Nat.le_of_lt h

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  Named constant gains
--     Source: quiche/src/recovery/gcongestion/bbr2.rs (DEFAULT_PARAMS struct)
--     and quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs (test at line 163)
-- ─────────────────────────────────────────────────────────────────────────────

/-- Default ProbeRTT pacing gain: 1.0 (= 10/10).
    Used when no custom `BbrParams.probe_rtt_pacing_gain` override is set.
    Source: `probe_rtt_pacing_gain: 1.0` in DEFAULT_PARAMS (bbr2.rs line 311). -/
def pacingGainDefault : Gain := { num := 10, den := 10 }

/-- Default ProbeRTT cwnd gain: 1.0 (= 10/10).
    Source: `probe_rtt_cwnd_gain: 1.0` in DEFAULT_PARAMS (bbr2.rs line 313). -/
def cwndGainDefault : Gain := { num := 10, den := 10 }

/-- Custom ProbeRTT pacing gain: 0.8 (= 8/10).
    Used when `BbrParams.probe_rtt_pacing_gain = Some(0.8)`.
    Source: probe_rtt.rs test at line 163. -/
def pacingGainCustom : Gain := { num := 8, den := 10 }

/-- Custom ProbeRTT cwnd gain: 0.5 (= 5/10).
    Used when `BbrParams.probe_rtt_cwnd_gain = Some(0.5)`.
    Source: probe_rtt.rs test at line 164. -/
def cwndGainCustom : Gain := { num := 5, den := 10 }

/-- ProbeRTT inflight-target BDP fraction: 0.5 (= 5/10).
    `inflight_target = bdp × probe_rtt_inflight_target_bdp_fraction`.
    Source: `probe_rtt_inflight_target_bdp_fraction: 0.5` in DEFAULT_PARAMS
    (bbr2.rs line 305). -/
def inflightBdpFraction : Gain := { num := 5, den := 10 }

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  Inflight-target computation
-- ─────────────────────────────────────────────────────────────────────────────

/-- Compute the effective inflight target from the BDP and the fraction gain.
    `inflightTarget bdp g = (bdp × g.num) / g.den`
    Uses `Nat.div` (floor division).
    Approximation: the Rust uses `f32` multiplication; the Lean model
    multiplies then integer-divides, which may differ by at most 1 for
    finite BDP values. -/
def inflightTarget (bdp : Nat) (g : Gain) : Nat :=
  if g.den = 0 then 0 else (bdp * g.num) / g.den

/-- Apply a gain to an arbitrary value (e.g. bandwidth × gain).
    Same integer-arithmetic model as `inflightTarget`. -/
def applyGain (v : Nat) (g : Gain) : Nat :=
  if g.den = 0 then 0 else (v * g.num) / g.den

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Theorems
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 4.1  Sub-unity predicates on named constants ─────────────────────────────

/-- The default pacing gain (1.0) is at-most-unity (not strictly sub-unity). -/
theorem pacingGainDefault_atMostUnity : pacingGainDefault.isAtMostUnity := by
  simp [Gain.isAtMostUnity, pacingGainDefault]

/-- The default cwnd gain (1.0) is at-most-unity. -/
theorem cwndGainDefault_atMostUnity : cwndGainDefault.isAtMostUnity := by
  simp [Gain.isAtMostUnity, cwndGainDefault]

/-- The custom pacing gain (0.8) is strictly sub-unity. -/
theorem pacingGainCustom_subUnity : pacingGainCustom.isSubUnity := by
  simp [Gain.isSubUnity, pacingGainCustom]

/-- The custom cwnd gain (0.5) is strictly sub-unity. -/
theorem cwndGainCustom_subUnity : cwndGainCustom.isSubUnity := by
  simp [Gain.isSubUnity, cwndGainCustom]

/-- The inflight BDP fraction (0.5) is strictly sub-unity. -/
theorem inflightBdpFraction_subUnity : inflightBdpFraction.isSubUnity := by
  simp [Gain.isSubUnity, inflightBdpFraction]

/-- Custom pacing gain numerator is 8, denominator is 10. -/
theorem pacingGainCustom_values : pacingGainCustom.num = 8 ∧ pacingGainCustom.den = 10 := by
  decide

/-- Custom cwnd gain numerator is 5, denominator is 10. -/
theorem cwndGainCustom_values : cwndGainCustom.num = 5 ∧ cwndGainCustom.den = 10 := by
  decide

-- ── 4.2  inflightTarget ≤ BDP when fraction is at-most-unity ─────────────────

/-- When the gain is at-most-unity, `inflightTarget` does not exceed `bdp`.
    Key safety property: with `inflightBdpFraction = 0.5`, the inflight
    target is at most half the BDP, guaranteeing that ProbeRTT can drain
    in-flight data below the BDP. -/
theorem inflightTarget_le_bdp (bdp : Nat) (g : Gain) (hg : g.isAtMostUnity)
    (hd : 0 < g.den) :
    inflightTarget bdp g ≤ bdp := by
  simp only [inflightTarget, Nat.pos_iff_ne_zero.mp hd, ite_false]
  calc bdp * g.num / g.den
      ≤ bdp * g.den / g.den := Nat.div_le_div_right (Nat.mul_le_mul_left bdp hg)
    _ = bdp               := Nat.mul_div_cancel bdp hd

/-- For the concrete inflight fraction 0.5, `inflightTarget bdp ≤ bdp`. -/
theorem inflightTarget_bdpFraction_le_bdp (bdp : Nat) :
    inflightTarget bdp inflightBdpFraction ≤ bdp :=
  inflightTarget_le_bdp bdp inflightBdpFraction
    (Gain.subUnity_implies_atMostUnity _ inflightBdpFraction_subUnity) (by decide)

/-- Concrete: `inflightTarget bdp inflightBdpFraction = bdp / 2`. -/
theorem inflightTarget_bdpFraction_eq_half (bdp : Nat) :
    inflightTarget bdp inflightBdpFraction = bdp / 2 := by
  simp only [inflightTarget, inflightBdpFraction]
  -- bdp * 5 / 10 = bdp / 2
  -- 10 = 5 * 2, and Nat.mul_div_mul_left : m * n / (m * k) = n / k
  rw [show (10 : Nat) = 5 * 2 from by decide,
      Nat.mul_comm bdp 5, Nat.mul_div_mul_left _ _ (by decide)]
  simp

-- ── 4.3  applyGain ≤ v when gain is at-most-unity ────────────────────────────

/-- When `g` is at-most-unity, `applyGain v g ≤ v`. -/
theorem applyGain_le_of_atMostUnity (v : Nat) (g : Gain) (hg : g.isAtMostUnity)
    (hd : 0 < g.den) :
    applyGain v g ≤ v := by
  simp only [applyGain, Nat.pos_iff_ne_zero.mp hd, ite_false]
  calc v * g.num / g.den
      ≤ v * g.den / g.den := Nat.div_le_div_right (Nat.mul_le_mul_left v hg)
    _ = v               := Nat.mul_div_cancel v hd

/-- Custom cwnd gain (0.5): effective cwnd is at most the full value. -/
theorem applyGain_cwndCustom_le (v : Nat) :
    applyGain v cwndGainCustom ≤ v :=
  applyGain_le_of_atMostUnity v cwndGainCustom
    (Gain.subUnity_implies_atMostUnity _ cwndGainCustom_subUnity) (by decide)

/-- Custom pacing gain (0.8): effective pacing rate is ≤ full bandwidth. -/
theorem applyGain_pacingCustom_le (v : Nat) :
    applyGain v pacingGainCustom ≤ v :=
  applyGain_le_of_atMostUnity v pacingGainCustom
    (Gain.subUnity_implies_atMostUnity _ pacingGainCustom_subUnity) (by decide)

-- ── 4.4  Inflight drain directional theorem ──────────────────────────────────

/-- If the pacing rate is scaled by a sub-unity gain, the applied rate is
    strictly less than the original rate (when `v > 0`).
    This formalises the key ProbeRTT invariant: a sub-unity pacing gain
    *causes* inflight to drain, because the sender paces below the BDP. -/
theorem applyGain_subUnity_lt (v : Nat) (g : Gain) (hg : g.isSubUnity)
    (hd : 0 < g.den) (hv : 0 < v) :
    applyGain v g < v := by
  simp only [applyGain, Nat.pos_iff_ne_zero.mp hd, ite_false]
  rw [Nat.div_lt_iff_lt_mul hd]
  exact Nat.mul_lt_mul_of_pos_left hg hv

/-- Custom pacing gain (0.8): when `v > 0`, pacing rate strictly decreases. -/
theorem applyGain_pacingCustom_lt (v : Nat) (hv : 0 < v) :
    applyGain v pacingGainCustom < v :=
  applyGain_subUnity_lt v pacingGainCustom pacingGainCustom_subUnity (by decide) hv

/-- Custom cwnd gain (0.5): when `v > 0`, cwnd strictly decreases. -/
theorem applyGain_cwndCustom_lt (v : Nat) (hv : 0 < v) :
    applyGain v cwndGainCustom < v :=
  applyGain_subUnity_lt v cwndGainCustom cwndGainCustom_subUnity (by decide) hv

-- ── 4.5  Gain ordering lemmas ─────────────────────────────────────────────────

/-- The custom cwnd gain (0.5) is less than or equal to the custom pacing
    gain (0.8) — i.e. the cwnd is constrained more tightly. -/
theorem cwndGainCustom_le_pacingGainCustom :
    cwndGainCustom.num * pacingGainCustom.den ≤
    pacingGainCustom.num * cwndGainCustom.den := by
  decide

/-- The inflight fraction (0.5) equals the custom cwnd gain (0.5) component-wise. -/
theorem inflightBdpFraction_eq_cwndGainCustom :
    inflightBdpFraction.num = cwndGainCustom.num ∧
    inflightBdpFraction.den = cwndGainCustom.den := by
  decide

/-- For same-denominator gains, larger `num` gives larger `applyGain`. -/
theorem applyGain_mono_num (v : Nat) (g1 g2 : Gain)
    (hd : g1.den = g2.den) (hd_pos : 0 < g1.den)
    (h : g1.num ≤ g2.num) :
    applyGain v g1 ≤ applyGain v g2 := by
  simp only [applyGain, Nat.pos_iff_ne_zero.mp hd_pos, ite_false]
  rw [← hd]
  simp only [Nat.pos_iff_ne_zero.mp hd_pos, ite_false]
  apply Nat.div_le_div_right
  exact Nat.mul_le_mul_left v h

/-- Applying a smaller gain gives ≤ result: cwnd gain ≤ pacing gain ⇒
    effective cwnd ≤ effective pacing (for the same base value). -/
theorem applyGain_cwnd_le_pacing (v : Nat) :
    applyGain v cwndGainCustom ≤ applyGain v pacingGainCustom :=
  applyGain_mono_num v cwndGainCustom pacingGainCustom rfl (by decide) (by decide)

-- ── 4.6  Concrete value checks ───────────────────────────────────────────────

/-- Concrete: `applyGain 100 pacingGainCustom = 80` (pacing rate 80% of bw). -/
example : applyGain 100 pacingGainCustom = 80 := by decide

/-- Concrete: `applyGain 100 cwndGainCustom = 50` (cwnd 50% of bdp). -/
example : applyGain 100 cwndGainCustom = 50 := by decide

/-- Concrete: `inflightTarget 10000 inflightBdpFraction = 5000`. -/
example : inflightTarget 10000 inflightBdpFraction = 5000 := by decide

/-- Concrete: `inflightTarget 1500 inflightBdpFraction = 750`. -/
example : inflightTarget 1500 inflightBdpFraction = 750 := by decide

/-- Concrete: `inflightTarget 1 inflightBdpFraction = 0` (floor division). -/
example : inflightTarget 1 inflightBdpFraction = 0 := by decide
