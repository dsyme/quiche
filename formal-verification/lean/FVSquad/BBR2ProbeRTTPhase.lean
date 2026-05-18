-- Copyright (C) 2018-2025, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of BBR2 PROBE_RTT phase parameter
-- constants and their key invariants.
--
-- Target: BBR2ProbeRTTPhase (T72)
-- Source: quiche/src/recovery/gcongestion/bbr2.rs (DEFAULT_PARAMS)
--         quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs
-- Lean 4 (v4.29.1), no Mathlib dependency.
--
-- Background
-- ──────────
-- BBR2's PROBE_RTT phase briefly reduces the in-flight data to a small
-- fraction of the estimated BDP in order to obtain an unloaded RTT
-- measurement.  This measurement drives the min-RTT estimate that BBR2
-- uses to compute its BDP target.
--
-- Key constants from DEFAULT_PARAMS
-- ──────────────────────────────────
--   probe_rtt_pacing_gain  = 1.0      (= 10/10)
--     Send at the estimated bandwidth — do not throttle pacing.
--
--   probe_rtt_cwnd_gain    = 1.0      (= 10/10)
--     Do not grow the cwnd beyond BDP during PROBE_RTT.
--
--   probe_rtt_inflight_target_bdp_fraction = 0.5  (= 1/2)
--     Target inflight = 50 % of BDP.  Enough to keep ACK clocking
--     while giving the network queue time to drain.
--
--   probe_rtt_period   = 10 000 ms  (minimum inter-PROBE_RTT interval)
--   probe_rtt_duration =    200 ms  (how long the probe lasts)
--
-- Both pacing and cwnd gains are *exactly unity*; the inflight fraction
-- is *strictly sub-unity*.
--
-- We model gains as exact integer fractions (same representation as T70/T71).
-- Durations are modelled as natural-number milliseconds.
-- All theorems proved by `omega`, `decide`, or `simp`.
--
-- Sections
-- ────────
--   §1  Gain representation (reused from T70/T71 pattern)
--   §2  Named constants from DEFAULT_PARAMS
--   §3  applyGain helper
--   §4  Theorems — gain unity properties
--   §5  Theorems — inflight fraction sub-unity
--   §6  Theorems — cross-phase ordering (vs STARTUP and DRAIN)
--   §7  Theorems — duration constants

namespace FVSquad.BBR2ProbeRTTPhase

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  Gain representation
-- ─────────────────────────────────────────────────────────────────────────────

/-- A non-negative gain represented as an exact fraction `num / den`.
    Both fields are natural numbers; `den > 0` is a precondition of all
    arithmetic theorems. -/
structure Gain where
  /-- Numerator of the gain fraction. -/
  num : Nat
  /-- Denominator (must be positive in all arithmetic uses). -/
  den : Nat
  deriving Repr

/-- A gain is *at-unity* when `num = den` (i.e. gain = 1.0). -/
def Gain.isUnity (g : Gain) : Prop := g.num = g.den

/-- A gain is *sub-unity* when `num < den` (i.e. gain < 1.0). -/
def Gain.isSubUnity (g : Gain) : Prop := g.num < g.den

/-- A gain is *super-unity* when `num > den` (i.e. gain > 1.0). -/
def Gain.isSuperUnity (g : Gain) : Prop := g.num > g.den

/-- A gain is *at-most-unity* when `num ≤ den`. -/
def Gain.isAtMostUnity (g : Gain) : Prop := g.num ≤ g.den

/-- `g1 ≤ g2` in the fraction model: `g1.num * g2.den ≤ g2.num * g1.den`.
    Correct when both denominators are positive. -/
def Gain.le (g1 g2 : Gain) : Prop := g1.num * g2.den ≤ g2.num * g1.den

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  Named constants from DEFAULT_PARAMS
--     Source: quiche/src/recovery/gcongestion/bbr2.rs lines 305–313
-- ─────────────────────────────────────────────────────────────────────────────

-- PROBE_RTT phase gains
/-- `probe_rtt_pacing_gain = 1.0` → fraction 10/10.
    Source: `probe_rtt_pacing_gain: 1.0` (bbr2.rs line 311). -/
def probeRttPacingGain : Gain := { num := 10, den := 10 }

/-- `probe_rtt_cwnd_gain = 1.0` → fraction 10/10.
    Source: `probe_rtt_cwnd_gain: 1.0` (bbr2.rs line 313). -/
def probeRttCwndGain : Gain := { num := 10, den := 10 }

/-- The inflight target fraction: 0.5 = 1/2.
    Source: `probe_rtt_inflight_target_bdp_fraction: 0.5` (bbr2.rs line 305). -/
def probeRttInflightFrac : Gain := { num := 1, den := 2 }

-- Cross-phase reference constants (from T70/T71)
/-- `startup_cwnd_gain = 2.0` → fraction 20/10. -/
def startupCwndGain : Gain := { num := 20, den := 10 }

/-- `startup_pacing_gain = 2.773` → fraction 2773/1000. -/
def startupPacingGain : Gain := { num := 2773, den := 1000 }

/-- `drain_pacing_gain ≈ 0.3466` → fraction 1000/2885. -/
def drainPacingGain : Gain := { num := 1000, den := 2885 }

-- Duration constants (in milliseconds)
/-- Minimum interval between PROBE_RTT episodes: 10 000 ms.
    Source: `probe_rtt_period: Duration::from_millis(10000)` (bbr2.rs line 307). -/
def probeRttPeriodMs : Nat := 10000

/-- How long a PROBE_RTT episode lasts: 200 ms.
    Source: `probe_rtt_duration: Duration::from_millis(200)` (bbr2.rs line 309). -/
def probeRttDurationMs : Nat := 200

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  applyGain helper
-- ─────────────────────────────────────────────────────────────────────────────

/-- Apply a gain to a bandwidth value `bw` using integer arithmetic:
    `result = bw * g.num / g.den`.
    Rounds down (Nat division). -/
def applyGain (bw : Nat) (g : Gain) : Nat := bw * g.num / g.den

/-- Apply the inflight fraction to a BDP value. -/
def inflightTarget (bdp : Nat) : Nat := applyGain bdp probeRttInflightFrac

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Theorems — pacing and cwnd gain unity
-- ─────────────────────────────────────────────────────────────────────────────

/-- The PROBE_RTT pacing gain is exactly unity: num = den. -/
theorem probeRttPacingGain_unity : probeRttPacingGain.isUnity := by
  unfold probeRttPacingGain Gain.isUnity; decide

/-- The PROBE_RTT cwnd gain is exactly unity: num = den. -/
theorem probeRttCwndGain_unity : probeRttCwndGain.isUnity := by
  unfold probeRttCwndGain Gain.isUnity; decide

/-- A unity gain applied to any bandwidth returns the same bandwidth
    (requires denominator is positive). -/
theorem applyGain_unity (bw : Nat) (g : Gain) (hd : g.den > 0) (h : g.isUnity) :
    applyGain bw g = bw := by
  unfold applyGain Gain.isUnity at *
  rw [h, Nat.mul_div_cancel bw hd]

/-- Applying the PROBE_RTT pacing gain is the identity. -/
theorem applyProbeRttPacing_identity (bw : Nat) :
    applyGain bw probeRttPacingGain = bw :=
  applyGain_unity bw probeRttPacingGain (by decide) probeRttPacingGain_unity

/-- Applying the PROBE_RTT cwnd gain is the identity. -/
theorem applyProbeRttCwnd_identity (bw : Nat) :
    applyGain bw probeRttCwndGain = bw :=
  applyGain_unity bw probeRttCwndGain (by decide) probeRttCwndGain_unity

/-- A unity gain is at-most-unity. -/
theorem Gain.unity_implies_atMostUnity (g : Gain) (h : g.isUnity) :
    g.isAtMostUnity := by
  unfold Gain.isUnity Gain.isAtMostUnity at *; omega

/-- PROBE_RTT pacing gain is at-most-unity. -/
theorem probeRttPacingGain_atMostUnity : probeRttPacingGain.isAtMostUnity :=
  Gain.unity_implies_atMostUnity _ probeRttPacingGain_unity

/-- PROBE_RTT cwnd gain is at-most-unity. -/
theorem probeRttCwndGain_atMostUnity : probeRttCwndGain.isAtMostUnity :=
  Gain.unity_implies_atMostUnity _ probeRttCwndGain_unity

/-- Applying an at-most-unity gain never exceeds the input. -/
theorem applyGain_atMostUnity_le (bw : Nat) (g : Gain) (hd : g.den > 0)
    (h : g.isAtMostUnity) : applyGain bw g ≤ bw := by
  unfold applyGain Gain.isAtMostUnity at *
  calc bw * g.num / g.den
      ≤ bw * g.den / g.den := by
        apply Nat.div_le_div_right
        exact Nat.mul_le_mul_left bw h
    _ = bw := Nat.mul_div_cancel bw hd

/-- Applying PROBE_RTT pacing gain to any bandwidth ≤ that bandwidth. -/
theorem applyProbeRttPacing_le (bw : Nat) : applyGain bw probeRttPacingGain ≤ bw :=
  applyGain_atMostUnity_le bw probeRttPacingGain (by decide) probeRttPacingGain_atMostUnity

/-- Applying PROBE_RTT cwnd gain to any bandwidth ≤ that bandwidth. -/
theorem applyProbeRttCwnd_le (bw : Nat) : applyGain bw probeRttCwndGain ≤ bw :=
  applyGain_atMostUnity_le bw probeRttCwndGain (by decide) probeRttCwndGain_atMostUnity

-- ─────────────────────────────────────────────────────────────────────────────
-- §5  Theorems — inflight fraction sub-unity
-- ─────────────────────────────────────────────────────────────────────────────

/-- The inflight fraction is strictly sub-unity (0.5 < 1). -/
theorem probeRttInflightFrac_subUnity : probeRttInflightFrac.isSubUnity := by
  unfold probeRttInflightFrac Gain.isSubUnity; decide

/-- The inflight target is strictly below the full BDP for any bw > 0. -/
theorem inflightTarget_lt_bdp (bdp : Nat) (h : bdp > 0) :
    inflightTarget bdp < bdp := by
  unfold inflightTarget applyGain probeRttInflightFrac
  simp only
  omega

/-- The inflight target is at most half the BDP. -/
theorem inflightTarget_le_half (bdp : Nat) :
    inflightTarget bdp ≤ bdp / 2 := by
  unfold inflightTarget applyGain probeRttInflightFrac
  simp only
  omega

/-- The inflight target is non-negative for any bdp. -/
theorem inflightTarget_nonneg (bdp : Nat) : inflightTarget bdp ≥ 0 :=
  Nat.zero_le _

-- ─────────────────────────────────────────────────────────────────────────────
-- §6  Theorems — cross-phase ordering (PROBE_RTT vs STARTUP vs DRAIN)
-- ─────────────────────────────────────────────────────────────────────────────

/-- PROBE_RTT pacing gain ≤ STARTUP pacing gain.
    1.0 ≤ 2.773.  Proof: 10*1000 ≤ 2773*10. -/
theorem probeRttPacing_le_startupPacing :
    Gain.le probeRttPacingGain startupPacingGain := by
  unfold Gain.le probeRttPacingGain startupPacingGain; decide

/-- PROBE_RTT cwnd gain ≤ STARTUP cwnd gain.
    1.0 ≤ 2.0.  Proof: 10*10 ≤ 20*10. -/
theorem probeRttCwnd_le_startupCwnd :
    Gain.le probeRttCwndGain startupCwndGain := by
  unfold Gain.le probeRttCwndGain startupCwndGain; decide

/-- DRAIN pacing gain ≤ PROBE_RTT pacing gain.
    ≈0.3466 ≤ 1.0.  Proof: 1000*10 ≤ 10*2885. -/
theorem drainPacing_le_probeRttPacing :
    Gain.le drainPacingGain probeRttPacingGain := by
  unfold Gain.le drainPacingGain probeRttPacingGain; decide

/-- PROBE_RTT pacing gain is strictly greater than DRAIN pacing gain.
    1.0 > ≈0.3466.  Useful for showing PROBE_RTT doesn't throttle as hard. -/
theorem probeRttPacing_gt_drainPacing :
    drainPacingGain.num * probeRttPacingGain.den <
    probeRttPacingGain.num * drainPacingGain.den := by
  unfold drainPacingGain probeRttPacingGain; decide

/-- PROBE_RTT inflight fraction ≤ PROBE_RTT cwnd gain (0.5 ≤ 1.0).
    Ensures inflight target is always within the cwnd window. -/
theorem inflightFrac_le_cwndGain :
    Gain.le probeRttInflightFrac probeRttCwndGain := by
  unfold Gain.le probeRttInflightFrac probeRttCwndGain; decide

/-- The inflight fraction numerator equals 1. -/
theorem inflightFrac_num_eq_one : probeRttInflightFrac.num = 1 := by
  unfold probeRttInflightFrac; decide

/-- The inflight fraction denominator equals 2. -/
theorem inflightFrac_den_eq_two : probeRttInflightFrac.den = 2 := by
  unfold probeRttInflightFrac; decide

-- ─────────────────────────────────────────────────────────────────────────────
-- §7  Theorems — duration constants
-- ─────────────────────────────────────────────────────────────────────────────

/-- The PROBE_RTT period is longer than the PROBE_RTT duration.
    A probe lasts at most 200 ms; probes are at least 10 000 ms apart. -/
theorem probeRttPeriod_gt_duration :
    probeRttDurationMs < probeRttPeriodMs := by decide

/-- The period-to-duration ratio is at least 50. -/
theorem probeRttPeriod_ratio_ge_50 :
    probeRttDurationMs * 50 ≤ probeRttPeriodMs := by decide

/-- The overhead fraction: duration/period ≤ 2%.  (200/10000 = 1/50.) -/
theorem probeRttDuration_small_fraction :
    probeRttDurationMs * 100 ≤ probeRttPeriodMs * 2 := by decide

-- ─────────────────────────────────────────────────────────────────────────────
-- §8  Concrete numeric examples
-- ─────────────────────────────────────────────────────────────────────────────

-- These confirm the model produces the expected Rust values on concrete inputs.

/-- Applying pacing gain 1.0 to bw=10000 yields 10000 (identity). -/
example : applyGain 10000 probeRttPacingGain = 10000 := by decide

/-- Applying cwnd gain 1.0 to bw=10000 yields 10000 (identity). -/
example : applyGain 10000 probeRttCwndGain = 10000 := by decide

/-- Inflight target for bdp=10000: 10000 * 1 / 2 = 5000. -/
example : inflightTarget 10000 = 5000 := by decide

/-- Inflight target for bdp=1000: 1000 * 1 / 2 = 500. -/
example : inflightTarget 1000 = 500 := by decide

/-- Inflight target for bdp=1: 1 * 1 / 2 = 0 (Nat floor). -/
example : inflightTarget 1 = 0 := by decide

/-- Inflight target for bdp=0: 0. -/
example : inflightTarget 0 = 0 := by decide

end FVSquad.BBR2ProbeRTTPhase
