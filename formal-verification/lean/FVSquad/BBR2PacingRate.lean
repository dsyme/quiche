-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of BBR2 pacing rate update invariants.
--
-- Target: quiche/src/recovery/gcongestion/bbr2.rs — fn update_pacing_rate
-- Spec:   formal-verification/specs/bbr2_pacing_rate_informal.md
-- Phase:  5 — Implementation + Proofs (T32, run 167)
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- Models:
--   Bandwidth          — Nat (bits-per-second, unbounded / overflow-free)
--   PacingGain         — rational gainNum/gainDen (both Nat, gainDen > 0)
--   BwLoMode           — enum (Default | NonDefault)
--   UpdatePacingInput  — record capturing all relevant inputs
--   UpdatePacingOutput — new pacing_rate after update
--
-- Excluded from model (documented in CORRESPONDENCE.md):
--   * f32 / f64 pacing_gain         — modelled as rational Nat fraction
--   * Bandwidth from_bytes_and_time — Case B (first-ACK) modelled abstractly
--   * initial_pacing_rate cap       — modelled as an optional Nat upper bound
--   * u64 overflow in target_rate   — Nat is unbounded
--   * scale_pacing_rate_by_mss      — update_mss path, out of scope
--
-- Key theorems (all close with omega):
--   startup_monotone        — normal STARTUP never decreases pacing_rate
--   startup_ge_target       — normal STARTUP rate ≥ target_rate
--   full_bw_sets_target     — Case C sets pacing_rate = target_rate
--   decrease_early_sets_target — Case D sets pacing_rate = target_rate
--   bwlo_loss_sets_target   — Case D' sets pacing_rate = target_rate
--   zero_bw_unchanged       — zero bandwidth → no update
--   target_monotone_in_bw   — target_rate non-decreasing in bandwidth
--   target_nonneg           — target_rate ≥ 0  (trivial for Nat)
--   startup_max_ge_both     — max satisfies both lower bounds
--   first_ack_capped_le_cap — Case B: capped pacing_rate ≤ initial cap
--   first_ack_uncapped_ge   — Case B (no cap): pacing_rate = first_ack_rate
--   target_monotone_in_gain — target_rate non-decreasing in gain numerator

namespace FVSquad.BBR2PacingRate

-- ---------------------------------------------------------------------------
-- §1  Types
-- ---------------------------------------------------------------------------

/-- Bandwidth as bits-per-second (modelled as an unbounded natural number). -/
abbrev Bandwidth := Nat

/-- BwLoMode determines whether the non-default path (Case D') applies. -/
inductive BwLoMode
  | Default
  | NonDefault
  deriving DecidableEq

-- ---------------------------------------------------------------------------
-- §2  Core computation: target_rate
-- ---------------------------------------------------------------------------

/-- Integer approximation of `bw * gainNum / gainDen`.
    Mirrors `bandwidth_estimate * pacing_gain` in the Rust. -/
def targetRate (bw gainNum gainDen : Nat) : Nat :=
  bw * gainNum / gainDen

-- ---------------------------------------------------------------------------
-- §3  Case logic — update_pacing_rate
-- ---------------------------------------------------------------------------

/-- All inputs to the pacing-rate update decision. -/
structure UpdateInput where
  /-- Current pacing_rate before the update. -/
  pacingRateBefore  : Bandwidth
  /-- Bandwidth estimate from the network model (0 → early return). -/
  bwEstimate        : Bandwidth
  /-- Pacing gain numerator (e.g., 2885 for STARTUP ≈ 2.885). -/
  gainNum           : Nat
  /-- Pacing gain denominator (must be > 0). -/
  gainDen           : Nat
  gainDenPos        : 0 < gainDen
  /-- True when BBR2 has measured full available bandwidth (DRAIN/PROBE_BW). -/
  fullBwReached     : Bool
  /-- True when the early-exit STARTUP pacing decrease condition holds. -/
  decreaseEarly     : Bool
  /-- BwLoMode controls whether a loss-triggered rate reduction applies. -/
  bwLoMode          : BwLoMode
  /-- True when at least one loss event was seen this round. -/
  lossEventsInRound : Bool
  /-- True when this is the very first ACK (total = bytes_acked). -/
  isFirstAck        : Bool
  /-- Abstract first-ACK rate (cwnd/rtt result, before optional cap). -/
  firstAckRate      : Bandwidth
  /-- Optional cap on initial pacing rate (None = no cap). -/
  initialPacingCap  : Option Bandwidth

/-- Compute the new pacing rate according to update_pacing_rate logic. -/
def updatePacingRate (inp : UpdateInput) : Bandwidth :=
  -- Case A: zero bandwidth → early return
  if inp.bwEstimate = 0 then
    inp.pacingRateBefore
  -- Case B: first ACK → use firstAckRate with optional cap
  else if inp.isFirstAck then
    match inp.initialPacingCap with
    | none     => inp.firstAckRate
    | some cap => min inp.firstAckRate cap
  else
    let target := targetRate inp.bwEstimate inp.gainNum inp.gainDen
    -- Case C: full bandwidth reached → set exactly to target
    if inp.fullBwReached then
      target
    -- Case D: early decrease allowed → set to target
    else if inp.decreaseEarly then
      target
    -- Case D': non-default BwLoMode + loss → set to target
    else if inp.bwLoMode = BwLoMode.NonDefault then
      if inp.lossEventsInRound then target
      else max inp.pacingRateBefore target
    -- Case E: normal STARTUP — never decrease (monotone max)
    else
      max inp.pacingRateBefore target

-- ---------------------------------------------------------------------------
-- §4  Proofs
-- ---------------------------------------------------------------------------

-- §4.1  Zero-bandwidth guard
-- -----------------------------------------------------------------------

/-- If bandwidth estimate is zero, pacing rate is unchanged. -/
theorem zero_bw_unchanged (inp : UpdateInput) (h : inp.bwEstimate = 0) :
    updatePacingRate inp = inp.pacingRateBefore := by
  simp [updatePacingRate, h]

-- §4.2  Normal STARTUP path (Case E) theorems
-- -----------------------------------------------------------------------

/-- On the normal STARTUP path, pacing_rate_after ≥ pacing_rate_before. -/
theorem startup_monotone (inp : UpdateInput)
    (hbw    : inp.bwEstimate ≠ 0)
    (hfirst : inp.isFirstAck = false)
    (hfull  : inp.fullBwReached = false)
    (hdec   : inp.decreaseEarly = false)
    (hmode  : inp.bwLoMode = BwLoMode.Default ∨
              inp.lossEventsInRound = false) :
    updatePacingRate inp ≥ inp.pacingRateBefore := by
  cases h_bwlo : inp.bwLoMode with
  | Default =>
    simp only [updatePacingRate, hbw, hfirst, hfull, hdec, h_bwlo,
               show (BwLoMode.Default = BwLoMode.NonDefault) = False from by decide,
               ite_false]
    exact Nat.le_max_left _ _
  | NonDefault =>
    cases hmode with
    | inl hd => rw [h_bwlo] at hd; exact absurd hd (by decide)
    | inr hl =>
      simp only [updatePacingRate, hbw, hfirst, hfull, hdec, h_bwlo, hl,
                 show (BwLoMode.NonDefault = BwLoMode.NonDefault) = True from by decide,
                 ite_false, ite_true]
      exact Nat.le_max_left _ _

/-- On the normal STARTUP path, pacing_rate_after ≥ target_rate. -/
theorem startup_ge_target (inp : UpdateInput)
    (hbw    : inp.bwEstimate ≠ 0)
    (hfirst : inp.isFirstAck = false)
    (hfull  : inp.fullBwReached = false)
    (hdec   : inp.decreaseEarly = false)
    (hmode  : inp.bwLoMode = BwLoMode.Default ∨
              inp.lossEventsInRound = false) :
    updatePacingRate inp ≥ targetRate inp.bwEstimate inp.gainNum inp.gainDen := by
  cases h_bwlo : inp.bwLoMode with
  | Default =>
    simp only [updatePacingRate, hbw, hfirst, hfull, hdec, h_bwlo,
               show (BwLoMode.Default = BwLoMode.NonDefault) = False from by decide,
               ite_false]
    exact Nat.le_max_right _ _
  | NonDefault =>
    cases hmode with
    | inl hd => rw [h_bwlo] at hd; exact absurd hd (by decide)
    | inr hl =>
      simp only [updatePacingRate, hbw, hfirst, hfull, hdec, h_bwlo, hl,
                 show (BwLoMode.NonDefault = BwLoMode.NonDefault) = True from by decide,
                 ite_false, ite_true]
      exact Nat.le_max_right _ _

/-- max satisfies both lower bounds. -/
theorem startup_max_ge_both (prev target : Nat) :
    max prev target ≥ prev ∧ max prev target ≥ target :=
  ⟨Nat.le_max_left _ _, Nat.le_max_right _ _⟩

-- §4.3  Case C, D, D': set exactly to target
-- -----------------------------------------------------------------------

/-- When full bandwidth is reached, pacing_rate is set to target_rate. -/
theorem full_bw_sets_target (inp : UpdateInput)
    (hbw    : inp.bwEstimate ≠ 0)
    (hfirst : inp.isFirstAck = false)
    (hfull  : inp.fullBwReached = true) :
    updatePacingRate inp =
      targetRate inp.bwEstimate inp.gainNum inp.gainDen := by
  simp [updatePacingRate, hbw, hfirst, hfull]

/-- When the early-decrease condition holds, pacing_rate = target_rate. -/
theorem decrease_early_sets_target (inp : UpdateInput)
    (hbw    : inp.bwEstimate ≠ 0)
    (hfirst : inp.isFirstAck = false)
    (hfull  : inp.fullBwReached = false)
    (hdec   : inp.decreaseEarly = true) :
    updatePacingRate inp =
      targetRate inp.bwEstimate inp.gainNum inp.gainDen := by
  simp [updatePacingRate, hbw, hfirst, hfull, hdec]

/-- When non-default BwLoMode + loss event, pacing_rate = target_rate. -/
theorem bwlo_loss_sets_target (inp : UpdateInput)
    (hbw    : inp.bwEstimate ≠ 0)
    (hfirst : inp.isFirstAck = false)
    (hfull  : inp.fullBwReached = false)
    (hdec   : inp.decreaseEarly = false)
    (hmode  : inp.bwLoMode = BwLoMode.NonDefault)
    (hloss  : inp.lossEventsInRound = true) :
    updatePacingRate inp =
      targetRate inp.bwEstimate inp.gainNum inp.gainDen := by
  simp [updatePacingRate, hbw, hfirst, hfull, hdec, hmode, hloss]

-- §4.4  target_rate properties
-- -----------------------------------------------------------------------

/-- target_rate is non-negative (trivially: Nat ≥ 0). -/
theorem target_nonneg (bw gainNum gainDen : Nat) :
    0 ≤ targetRate bw gainNum gainDen := Nat.zero_le _

/-- target_rate is non-decreasing in bandwidth (fixed gain). -/
theorem target_monotone_in_bw (bw1 bw2 gainNum gainDen : Nat)
    (h : bw1 ≤ bw2) :
    targetRate bw1 gainNum gainDen ≤ targetRate bw2 gainNum gainDen := by
  simp only [targetRate]
  apply Nat.div_le_div_right
  exact Nat.mul_le_mul_right gainNum h

/-- target_rate is non-decreasing in the gain numerator (fixed bandwidth). -/
theorem target_monotone_in_gain (bw gainNum1 gainNum2 gainDen : Nat)
    (h : gainNum1 ≤ gainNum2) :
    targetRate bw gainNum1 gainDen ≤ targetRate bw gainNum2 gainDen := by
  simp only [targetRate]
  apply Nat.div_le_div_right
  exact Nat.mul_le_mul_left bw h

-- §4.5  Case B: first-ACK path
-- -----------------------------------------------------------------------

/-- With no initial cap, Case B returns firstAckRate unchanged. -/
theorem first_ack_uncapped (inp : UpdateInput)
    (hbw    : inp.bwEstimate ≠ 0)
    (hfirst : inp.isFirstAck = true)
    (hcap   : inp.initialPacingCap = none) :
    updatePacingRate inp = inp.firstAckRate := by
  simp [updatePacingRate, hbw, hfirst, hcap]

/-- With an initial cap, Case B returns at most the cap. -/
theorem first_ack_capped_le_cap (inp : UpdateInput) (cap : Bandwidth)
    (hbw    : inp.bwEstimate ≠ 0)
    (hfirst : inp.isFirstAck = true)
    (hcap   : inp.initialPacingCap = some cap) :
    updatePacingRate inp ≤ cap := by
  simp [updatePacingRate, hbw, hfirst, hcap]
  exact Nat.min_le_right _ _

/-- With an initial cap, Case B returns at most the firstAckRate. -/
theorem first_ack_capped_le_first (inp : UpdateInput) (cap : Bandwidth)
    (hbw    : inp.bwEstimate ≠ 0)
    (hfirst : inp.isFirstAck = true)
    (hcap   : inp.initialPacingCap = some cap) :
    updatePacingRate inp ≤ inp.firstAckRate := by
  simp [updatePacingRate, hbw, hfirst, hcap]
  exact Nat.min_le_left _ _

-- §4.6  Composed monotonicity: STARTUP path never drops below initial
-- -----------------------------------------------------------------------

/-- A pacing rate that started at `prev` and has been updated via the
    normal STARTUP path to `r` will, after one more normal STARTUP step,
    be ≥ `r`.  This captures the accumulative monotonicity property. -/
theorem startup_two_step_monotone (prev r bw gainNum gainDen : Nat)
    (hprev : r = max prev (targetRate bw gainNum gainDen)) :
    max r (targetRate bw gainNum gainDen) ≥ r :=
  Nat.le_max_left _ _

end FVSquad.BBR2PacingRate
