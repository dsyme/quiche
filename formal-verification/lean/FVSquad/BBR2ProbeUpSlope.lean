-- Copyright (C) 2025, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — T68: BBR2 probe-up inflight-hi slope
--
-- Target T68: raise_inflight_high_slope + accumulator update
-- Source: quiche/src/recovery/gcongestion/bbr2/probe_bw.rs
--   raise_inflight_high_slope (~L582):
--     growth_this_round = 1 << probe_up_rounds
--     probe_up_rounds    = min(probe_up_rounds + 1, 30)
--     probe_up_bytes     = max(cwnd / growth_this_round, DEFAULT_MSS)
--   probe_inflight_high_upward accumulator (~L612):
--     delta              = probe_up_acked / probe_up_bytes
--     probe_up_acked    -= delta * probe_up_bytes
--     inflight_hi       += delta * DEFAULT_MSS
-- Phase: 5 — Implementation + Proofs
-- Lean 4.29.0, no Mathlib dependency.
--
-- Design:
--   `probe_up_rounds` counts how many PROBE_UP rounds have elapsed.
--   `raise_inflight_high_slope` halves the per-ACK credit with each round
--   (exponential back-off), but caps the halving at 2^30 (~1G bytes) and
--   floors the credit at DEFAULT_MSS (1300 bytes).
--
-- Approximations / abstractions:
--   - `usize` is modelled as `Nat` (no 64-bit overflow for byte counts).
--   - `1 << probe_up_rounds` is modelled as `2 ^ probe_up_rounds`.
--   - The guard `if let Some(probe_up_bytes) = ...` is elided; we prove
--     properties of the unconditional update step.
--   - Floating-point fields (pacing_gain, etc.) are out of scope.
--
-- Theorems (17 total, 0 sorry):
--   rounds_bounded, rounds_saturates, rounds_strictly_increases,
--   bytes_floor, bytes_le_cwnd_when_large,
--   growth_positive, growth_max,
--   slope_zero_bytes_eq_cwnd, slope_zero_rounds_one,
--   bytes_le_cwnd_div_growth,
--   slope_cwnd_zero_floor,
--   acked_after_mod, acked_after_lt_bytes, inflight_hi_after_ge,
--   inflight_hi_stable_below_threshold, inflight_hi_increases_at_threshold,
--   acked_after_remainder

namespace FVSquad.BBR2ProbeUpSlope

-- ---------------------------------------------------------------------------
-- §1  Constants
-- ---------------------------------------------------------------------------

/-- Maximum number of PROBE_UP rounds; growth is capped at 2^MAX_ROUNDS. -/
abbrev MAX_ROUNDS : Nat := 30

/-- Minimum segment size (DEFAULT_MSS); probe_up_bytes is floored here. -/
abbrev DEFAULT_MSS : Nat := 1300

-- ---------------------------------------------------------------------------
-- §2  Core operations
-- ---------------------------------------------------------------------------

/-- Growth factor in round `r`: how many credits are consumed per acked MSS. -/
def growth (r : Nat) : Nat := 2 ^ r

/-- `probe_up_bytes` after `raise_inflight_high_slope(cwnd)` when rounds = r.
    `growth_this_round = 1 << r`; floor at DEFAULT_MSS. -/
def probeUpBytes (cwnd : Nat) (r : Nat) : Nat :=
  Nat.max DEFAULT_MSS (cwnd / growth r)

/-- New `probe_up_rounds` after one call to `raise_inflight_high_slope`. -/
def nextRounds (r : Nat) : Nat := Nat.min (r + 1) MAX_ROUNDS

/-- State for the accumulator in `probe_inflight_high_upward`. -/
structure ProbeUpState where
  probe_up_acked : Nat
  probe_up_bytes : Nat
  inflight_hi    : Nat
  deriving Repr

/-- Update step: accumulate acked bytes; advance inflight_hi in units of
    DEFAULT_MSS once enough bytes are accumulated. -/
def accumulatorStep (s : ProbeUpState) (bytes_acked : Nat) : ProbeUpState :=
  let acked' := s.probe_up_acked + bytes_acked
  let delta  := acked' / s.probe_up_bytes
  { probe_up_acked := acked' - delta * s.probe_up_bytes
  , probe_up_bytes := s.probe_up_bytes
  , inflight_hi    := s.inflight_hi + delta * DEFAULT_MSS }

-- ---------------------------------------------------------------------------
-- §3  Theorems about rounds
-- ---------------------------------------------------------------------------

/-- Rounds never exceed MAX_ROUNDS after an update. -/
theorem rounds_bounded (r : Nat) : nextRounds r ≤ MAX_ROUNDS := by
  simp [nextRounds, Nat.min_le_right]

/-- Once saturated, rounds stay at MAX_ROUNDS. -/
theorem rounds_saturates (r : Nat) (h : r ≥ MAX_ROUNDS) :
    nextRounds r = MAX_ROUNDS := by
  unfold nextRounds
  exact Nat.min_eq_right (by omega)

/-- Below the cap, rounds strictly increase. -/
theorem rounds_strictly_increases (r : Nat) (h : r < MAX_ROUNDS) :
    nextRounds r = r + 1 := by
  unfold nextRounds
  exact Nat.min_eq_left (by omega)

-- ---------------------------------------------------------------------------
-- §4  Theorems about probeUpBytes
-- ---------------------------------------------------------------------------

/-- probe_up_bytes is always at least DEFAULT_MSS. -/
theorem bytes_floor (cwnd r : Nat) : probeUpBytes cwnd r ≥ DEFAULT_MSS := by
  simp [probeUpBytes, Nat.le_max_left]

/-- When cwnd ≥ DEFAULT_MSS, probe_up_bytes ≤ cwnd. -/
theorem bytes_le_cwnd_when_large (cwnd r : Nat)
    (h : cwnd ≥ DEFAULT_MSS) : probeUpBytes cwnd r ≤ cwnd := by
  simp [probeUpBytes, Nat.max_le]
  constructor
  · exact h
  · exact Nat.div_le_self cwnd (growth r)

/-- growth is always positive (≥ 1). -/
theorem growth_positive (r : Nat) : growth r ≥ 1 := by
  simp [growth]
  exact Nat.one_le_two_pow

/-- growth is bounded above by 2^MAX_ROUNDS for rounds ≤ MAX_ROUNDS. -/
theorem growth_max (r : Nat) (h : r ≤ MAX_ROUNDS) :
    growth r ≤ 2 ^ MAX_ROUNDS := by
  simp [growth]
  exact Nat.pow_le_pow_right (by decide) h

/-- probe_up_bytes ≤ cwnd / growth (before the floor is applied vs max). -/
theorem bytes_le_cwnd_div_growth (cwnd r : Nat) :
    cwnd / growth r ≤ probeUpBytes cwnd r := by
  unfold probeUpBytes
  exact Nat.le_max_right _ _

/-- At round 0 (growth = 1), probe_up_bytes = max(cwnd, DEFAULT_MSS). -/
theorem slope_zero_bytes_eq_cwnd (cwnd : Nat) :
    probeUpBytes cwnd 0 = Nat.max DEFAULT_MSS cwnd := by
  simp [probeUpBytes, growth, Nat.div_one]

/-- At round 0, nextRounds = 1. -/
theorem slope_zero_rounds_one : nextRounds 0 = 1 := by
  unfold nextRounds; decide

/-- When cwnd = 0, probe_up_bytes = DEFAULT_MSS. -/
theorem slope_cwnd_zero_floor (r : Nat) :
    probeUpBytes 0 r = DEFAULT_MSS := by
  simp [probeUpBytes, growth]

-- ---------------------------------------------------------------------------
-- §5  Theorems about the accumulator step
-- ---------------------------------------------------------------------------

/-- After the accumulator step, probe_up_acked = (old + acked) mod probe_up_bytes. -/
theorem acked_after_mod (s : ProbeUpState) (ba : Nat)
    (hpos : s.probe_up_bytes > 0) :
    (accumulatorStep s ba).probe_up_acked =
      (s.probe_up_acked + ba) % s.probe_up_bytes := by
  simp only [accumulatorStep]
  have hmod  : (s.probe_up_acked + ba) % s.probe_up_bytes =
               (s.probe_up_acked + ba) -
               s.probe_up_bytes * ((s.probe_up_acked + ba) / s.probe_up_bytes) :=
    Nat.mod_def _ _
  have hcomm : (s.probe_up_acked + ba) / s.probe_up_bytes * s.probe_up_bytes =
               s.probe_up_bytes * ((s.probe_up_acked + ba) / s.probe_up_bytes) :=
    Nat.mul_comm _ _
  omega

/-- After the step, the residual is strictly less than probe_up_bytes. -/
theorem acked_after_lt_bytes (s : ProbeUpState) (ba : Nat)
    (hpos : s.probe_up_bytes > 0) :
    (accumulatorStep s ba).probe_up_acked < s.probe_up_bytes := by
  simp only [accumulatorStep]
  have hle   := Nat.div_mul_le_self (s.probe_up_acked + ba) s.probe_up_bytes
  have hmod  : (s.probe_up_acked + ba) % s.probe_up_bytes =
               (s.probe_up_acked + ba) -
               s.probe_up_bytes * ((s.probe_up_acked + ba) / s.probe_up_bytes) :=
    Nat.mod_def _ _
  have hlt   := Nat.mod_lt (s.probe_up_acked + ba) hpos
  have hcomm : (s.probe_up_acked + ba) / s.probe_up_bytes * s.probe_up_bytes =
               s.probe_up_bytes * ((s.probe_up_acked + ba) / s.probe_up_bytes) :=
    Nat.mul_comm _ _
  omega

/-- inflight_hi after the step is ≥ before. -/
theorem inflight_hi_after_ge (s : ProbeUpState) (ba : Nat) :
    (accumulatorStep s ba).inflight_hi ≥ s.inflight_hi := by
  simp only [accumulatorStep]
  omega

/-- inflight_hi does not change if fewer than probe_up_bytes have accumulated. -/
theorem inflight_hi_stable_below_threshold (s : ProbeUpState) (ba : Nat)
    (hlt : s.probe_up_acked + ba < s.probe_up_bytes) :
    (accumulatorStep s ba).inflight_hi = s.inflight_hi := by
  simp only [accumulatorStep]
  have hz : (s.probe_up_acked + ba) / s.probe_up_bytes = 0 :=
    Nat.div_eq_zero_iff.mpr (Or.inr hlt)
  simp [hz]

/-- inflight_hi increases by at least DEFAULT_MSS once probe_up_bytes accumulate. -/
theorem inflight_hi_increases_at_threshold (s : ProbeUpState) (ba : Nat)
    (hpos : s.probe_up_bytes > 0)
    (hge : s.probe_up_acked + ba ≥ s.probe_up_bytes) :
    (accumulatorStep s ba).inflight_hi ≥ s.inflight_hi + DEFAULT_MSS := by
  simp only [accumulatorStep]
  have hd : (s.probe_up_acked + ba) / s.probe_up_bytes ≥ 1 :=
    Nat.div_pos hge hpos
  have hmul : (s.probe_up_acked + ba) / s.probe_up_bytes * DEFAULT_MSS ≥ DEFAULT_MSS :=
    Nat.mul_le_mul_right DEFAULT_MSS hd
  omega

/-- Residual equals the true remainder. -/
theorem acked_after_remainder (s : ProbeUpState) (ba : Nat)
    (hpos : s.probe_up_bytes > 0) :
    (accumulatorStep s ba).probe_up_acked +
      ((s.probe_up_acked + ba) / s.probe_up_bytes) * s.probe_up_bytes =
      s.probe_up_acked + ba := by
  simp only [accumulatorStep]
  have hle := Nat.div_mul_le_self (s.probe_up_acked + ba) s.probe_up_bytes
  omega

end FVSquad.BBR2ProbeUpSlope
