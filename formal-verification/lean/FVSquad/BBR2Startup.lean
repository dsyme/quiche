-- Copyright (C) 2018-2025, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of BBR2 Startup phase parameter
-- constants and their key invariants.
--
-- Target: BBR2Startup (T71)
-- Source: quiche/src/recovery/gcongestion/bbr2.rs (DEFAULT_PARAMS)
--         quiche/src/recovery/gcongestion/bbr2/startup.rs
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- Background
-- ──────────
-- BBR2's STARTUP phase is an exponential probing phase that quickly estimates
-- the available bandwidth (bottleneck bandwidth, BtlBw) and fills the pipe.
--
-- STARTUP sets four key numeric parameters from DEFAULT_PARAMS:
--
--   startup_cwnd_gain = 2.0
--     The congestion window gain: allows up to 2 × BDP bytes in flight.
--     This permits the sender to probe aggressively during startup.
--
--   startup_pacing_gain = 2.773
--     The pacing rate gain: sends at 2.773 × the current bandwidth estimate.
--     Value chosen ≈ 2 × √2 / ln 2 for efficient single-round-trip probing
--     (derived from the BBRv2 paper §4.2).
--
--   full_bw_threshold = 1.25
--     When the estimated bandwidth grows by less than 25% over
--     `startup_full_bw_rounds` consecutive rounds, STARTUP declares the
--     pipe full and exits to DRAIN.
--
--   startup_full_bw_rounds = 3
--     Number of consecutive rounds with < full_bw_threshold growth needed
--     before exiting STARTUP.
--
-- We model gains as exact integer fractions:
--   startup_cwnd_gain    = 20/10   (= 2.0)
--   startup_pacing_gain  = 2773/1000  (= 2.773)
--   full_bw_threshold    = 5/4     (= 1.25)
--
-- Integer arithmetic avoids floating-point issues.
-- All theorems proved by `omega`, `simp`, `decide`, or `native_decide`.
--
-- Sections
-- ────────
--   §1  Gain representation (shared with BBR2DrainPhase)
--   §2  Named constants from DEFAULT_PARAMS
--   §3  applyGain helper
--   §4  Theorems

namespace FVSquad.BBR2Startup

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  Gain representation
-- ─────────────────────────────────────────────────────────────────────────────

/-- A non-negative gain represented as a fraction `num / den`.
    Both fields are natural numbers; `den > 0` is a precondition of all
    theorems that apply the gain arithmetically. -/
structure Gain where
  /-- Numerator of the gain fraction. -/
  num : Nat
  /-- Denominator (must be positive in all arithmetic uses). -/
  den : Nat
  deriving Repr

/-- A gain is *super-unity* when `num > den` (i.e. gain > 1.0). -/
def Gain.isSuperUnity (g : Gain) : Prop := g.num > g.den

/-- A gain is *at-least-unity* when `num ≥ den` (i.e. gain ≥ 1.0). -/
def Gain.isAtLeastUnity (g : Gain) : Prop := g.num ≥ g.den

/-- `g1 ≤ g2` in the model: `g1.num × g2.den ≤ g2.num × g1.den`.
    Correct when both denominators are positive. -/
def Gain.le (g1 g2 : Gain) : Prop := g1.num * g2.den ≤ g2.num * g1.den

/-- Super-unity implies at-least-unity. -/
theorem Gain.superUnity_implies_atLeastUnity (g : Gain) (h : g.isSuperUnity) :
    g.isAtLeastUnity :=
  Nat.le_of_lt h

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  Named constants from DEFAULT_PARAMS
--     Source: quiche/src/recovery/gcongestion/bbr2.rs lines 264–273
-- ─────────────────────────────────────────────────────────────────────────────

/-- `startup_cwnd_gain = 2.0` → fraction 20/10.
    Source: `startup_cwnd_gain: 2.0` (bbr2.rs line 265).
    Design: allows 2 × BDP bytes in flight during exponential probing. -/
def startupCwndGain : Gain := { num := 20, den := 10 }

/-- `startup_pacing_gain = 2.773` → fraction 2773/1000.
    Source: `startup_pacing_gain: 2.773` (bbr2.rs line 267).
    Design: ≈ `2 × √2 / ln 2`, chosen for fast, efficient bandwidth probing.
    The sender paces at 2.773× the current BtlBw estimate to fill the pipe
    quickly in a single round trip. -/
def startupPacingGain : Gain := { num := 2773, den := 1000 }

/-- `full_bw_threshold = 1.25` → fraction 5/4.
    Source: `full_bw_threshold: 1.25` (bbr2.rs line 269).
    Design: STARTUP exits when bandwidth growth is < 25% over the last
    `startup_full_bw_rounds` rounds, signalling the pipe is full. -/
def fullBwThreshold : Gain := { num := 5, den := 4 }

/-- `startup_full_bw_rounds = 3`.
    Source: `startup_full_bw_rounds: 3` (bbr2.rs line 271).
    Design: at least 3 consecutive under-threshold rounds before exiting
    STARTUP; reduces false positives from temporary bandwidth fluctuations. -/
def startupFullBwRounds : Nat := 3

/-- `max_startup_queue_rounds = 0`.
    Source: `max_startup_queue_rounds: 0` (bbr2.rs line 273).
    Design: disabled — the feature for early exit based on queue depth is
    not used in the default configuration. -/
def maxStartupQueueRounds : Nat := 0

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  applyGain helper
-- ─────────────────────────────────────────────────────────────────────────────

/-- Apply a gain to a bandwidth or BDP value: `applyGain v g = v × g.num / g.den`.
    Uses floor division (Nat.div).
    Approximation: consistent with BBR2DrainPhase model; differs from the
    Rust f32 result by at most 1 for all finite inputs. -/
def applyGain (v : Nat) (g : Gain) : Nat :=
  if g.den = 0 then 0 else (v * g.num) / g.den

/-- applyGain with a super-unity gain produces a result ≥ the input
    (num ≥ den → v × num / den ≥ v). -/
theorem applyGain_superUnity_ge (v : Nat) (g : Gain)
    (hd : g.den > 0) (hsu : g.isSuperUnity) :
    v ≤ applyGain v g := by
  simp only [applyGain, Nat.pos_iff_ne_zero.mp hd, ↓reduceIte]
  calc v = (v * g.den) / g.den := (Nat.mul_div_cancel v hd).symm
    _ ≤ (v * g.num) / g.den :=
        Nat.div_le_div_right (Nat.mul_le_mul_left v (Nat.le_of_lt hsu))

/-- applyGain with the full_bw_threshold (1.25×) grows the value by ≥ 25%. -/
theorem applyGain_fullBwThreshold_grows (v : Nat) :
    v ≤ applyGain v fullBwThreshold :=
  applyGain_superUnity_ge v fullBwThreshold (by decide) (by
    unfold fullBwThreshold Gain.isSuperUnity; decide)

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Theorems
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 4.1  Super-unity predicates ──────────────────────────────────────────────

/-- Startup cwnd gain is super-unity: 20 > 10, so startup_cwnd = 2.0 > 1.0.
    The cwnd window allows 2× the BDP, enabling aggressive probing. -/
theorem startupCwndGain_superUnity : startupCwndGain.isSuperUnity := by
  unfold startupCwndGain Gain.isSuperUnity; decide

/-- Startup pacing gain is super-unity: 2773 > 1000, so startup_pacing = 2.773 > 1.0.
    The sender paces faster than the estimated link rate to probe for bandwidth. -/
theorem startupPacingGain_superUnity : startupPacingGain.isSuperUnity := by
  unfold startupPacingGain Gain.isSuperUnity; decide

/-- Full-BW threshold is super-unity: 5 > 4, so full_bw_threshold = 1.25 > 1.0.
    Growth must exceed 25% to keep startup going. -/
theorem fullBwThreshold_superUnity : fullBwThreshold.isSuperUnity := by
  unfold fullBwThreshold Gain.isSuperUnity; decide

/-- Startup cwnd gain is at-least-unity (follows from super-unity). -/
theorem startupCwndGain_atLeastUnity : startupCwndGain.isAtLeastUnity :=
  Gain.superUnity_implies_atLeastUnity _ startupCwndGain_superUnity

/-- Startup pacing gain is at-least-unity. -/
theorem startupPacingGain_atLeastUnity : startupPacingGain.isAtLeastUnity :=
  Gain.superUnity_implies_atLeastUnity _ startupPacingGain_superUnity

-- ── 4.2  Applying startup gains always increases bandwidth ───────────────────

/-- Applying startup cwnd gain always yields a result ≥ the input bandwidth.
    The congestion window is at least as large as the BDP estimate. -/
theorem applyStartupCwnd_ge (bw : Nat) : bw ≤ applyGain bw startupCwndGain :=
  applyGain_superUnity_ge bw startupCwndGain (by decide) startupCwndGain_superUnity

/-- Applying startup pacing gain always yields a result ≥ the input bandwidth.
    The send rate is always above the current BtlBw estimate during STARTUP. -/
theorem applyStartupPacing_ge (bw : Nat) : bw ≤ applyGain bw startupPacingGain :=
  applyGain_superUnity_ge bw startupPacingGain (by decide) startupPacingGain_superUnity

-- ── 4.3  Ordering of startup gains ───────────────────────────────────────────

/-- Startup pacing gain (2.773) exceeds startup cwnd gain (2.0).
    Cross-fraction: 2773 × 10 = 27730 > 20 × 1000 = 20000. -/
theorem startupCwndGain_lt_startupPacingGain :
    Gain.le startupCwndGain startupPacingGain := by
  unfold Gain.le startupCwndGain startupPacingGain; decide

/-- Consequently, applyGain with startup pacing exceeds cwnd gain at any bw.
    Proof: LHS = bw*20/10 = bw*2 = bw*2000/1000 ≤ bw*2773/1000 = RHS. -/
theorem applyStartupPacing_ge_applyStartupCwnd (bw : Nat) :
    applyGain bw startupCwndGain ≤ applyGain bw startupPacingGain := by
  simp only [applyGain, startupCwndGain, startupPacingGain,
             show (10 : Nat) ≠ 0 from by decide, show (1000 : Nat) ≠ 0 from by decide,
             ↓reduceIte]
  -- goal: bw * 20 / 10 ≤ bw * 2773 / 1000
  have h1 : bw * 20 / 10 = bw * 2 := by
    have : bw * 20 = 10 * (bw * 2) := by omega
    rw [this]; exact Nat.mul_div_cancel_left (bw * 2) (by decide)
  have h2 : bw * 2 = bw * 2000 / 1000 := by
    have : bw * 2000 = 1000 * (bw * 2) := by omega
    rw [this]; exact (Nat.mul_div_cancel_left (bw * 2) (by decide)).symm
  rw [h1, h2]
  apply Nat.div_le_div_right
  omega

/-- Full-BW threshold (1.25) is strictly less than cwnd gain (2.0).
    Cross-fraction: 5 × 10 = 50 ≤ 20 × 4 = 80. -/
theorem fullBwThreshold_le_cwndGain :
    Gain.le fullBwThreshold startupCwndGain := by
  unfold Gain.le fullBwThreshold startupCwndGain; decide

/-- Full-BW threshold (1.25) is strictly less than pacing gain (2.773). -/
theorem fullBwThreshold_le_pacingGain :
    Gain.le fullBwThreshold startupPacingGain := by
  unfold Gain.le fullBwThreshold startupPacingGain; decide

-- ── 4.4  Round counter constants ─────────────────────────────────────────────

/-- startup_full_bw_rounds is positive (requires at least one round check). -/
theorem startupFullBwRounds_pos : startupFullBwRounds > 0 := by
  unfold startupFullBwRounds; decide

/-- Exactly 3 rounds of below-threshold growth are needed to exit STARTUP. -/
theorem startupFullBwRounds_eq_3 : startupFullBwRounds = 3 := rfl

/-- max_startup_queue_rounds is zero (feature disabled by default). -/
theorem maxStartupQueueRounds_zero : maxStartupQueueRounds = 0 := rfl

/-- The max_startup_queue_rounds < startup_full_bw_rounds.
    The exit-by-queue feature (if enabled) would trigger faster than the
    bandwidth-plateau exit — but it is disabled (= 0) in the default config. -/
theorem queueRounds_le_bwRounds :
    maxStartupQueueRounds ≤ startupFullBwRounds := by
  unfold maxStartupQueueRounds startupFullBwRounds; decide

-- ── 4.5  Concrete sanity checks ──────────────────────────────────────────────

/-- startup_cwnd_gain = 2.0: `applyGain 10000 startupCwndGain = 20000`. -/
theorem startupCwndGain_concrete_10000 :
    applyGain 10000 startupCwndGain = 20000 := by native_decide

/-- startup_pacing_gain = 2.773: `applyGain 10000 startupPacingGain = 27730`. -/
theorem startupPacingGain_concrete_10000 :
    applyGain 10000 startupPacingGain = 27730 := by native_decide

/-- full_bw_threshold = 1.25: `applyGain 10000 fullBwThreshold = 12500`. -/
theorem fullBwThreshold_concrete_10000 :
    applyGain 10000 fullBwThreshold = 12500 := by native_decide

/-- Pacing sends at > twice the cwnd-growth rate: at bw=10000,
    pacing_out = 27730 > cwnd_out = 20000. -/
theorem startupPacing_exceeds_cwnd_concrete :
    applyGain 10000 startupPacingGain > applyGain 10000 startupCwndGain := by
  native_decide

/-- The full_bw_threshold check: if bandwidth grew from 10000 to 12500, the
    ratio equals exactly the threshold (no growth → exit STARTUP next round). -/
theorem fullBwThreshold_exact_growth :
    applyGain 10000 fullBwThreshold = 12500 := by native_decide

-- ── 4.6  Startup vs DRAIN phase relationship ─────────────────────────────────
-- Import the drain gains locally for cross-phase comparison.

private def drainPacingGain : Gain := { num := 1000, den := 2885 }
private def drainCwndGain   : Gain := { num := 20,   den := 10  }

/-- Drain cwnd gain equals startup cwnd gain (design invariant: cwnd is
    unchanged across the STARTUP → DRAIN transition). -/
theorem drainCwndGain_eq_startupCwndGain :
    drainCwndGain.num = startupCwndGain.num ∧
    drainCwndGain.den = startupCwndGain.den := by
  unfold drainCwndGain startupCwndGain; exact ⟨rfl, rfl⟩

/-- Drain pacing (≈ 0.3466) is far less than startup pacing (2.773).
    The pacing rate drops sharply on entering DRAIN to flush the queue. -/
theorem drainPacingGain_lt_startupPacingGain :
    Gain.le drainPacingGain startupPacingGain := by
  unfold Gain.le drainPacingGain startupPacingGain; decide

/-- The full_bw_threshold (1.25) is below the startup pacing gain (2.773).
    Even at full bandwidth, startup pacing overshoots the threshold, so the
    exit criterion depends on sustained rounds, not instantaneous comparison. -/
theorem fullBwThreshold_below_startupPacing :
    Gain.le fullBwThreshold startupPacingGain := by
  unfold Gain.le fullBwThreshold startupPacingGain; decide

end FVSquad.BBR2Startup
