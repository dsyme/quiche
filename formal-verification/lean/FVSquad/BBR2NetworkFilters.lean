-- Copyright (C) 2024, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of BBR2 MaxBandwidthFilter and
-- RoundTripCounter from quiche/src/recovery/gcongestion/bbr2/network_model.rs
--
-- Target T54: BBR2 two-slot MaxBandwidthFilter and RoundTripCounter invariants
-- Source: quiche/src/recovery/gcongestion/bbr2/network_model.rs (lines 47–127)
-- Phase: 5 — Implementation + Proofs
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- Models:
--   MaxBandwidthFilter — two-slot sliding-window max over round trips (Nat BW)
--   RoundTripCounter   — counts completed BBR2 round trips
--
-- Omitted / abstracted:
--   * Bandwidth type   — modelled as Nat (bits/s); Mul<f64> ignored
--   * Instant/Duration — time not needed for filter invariants
--   * BandwidthSampler — complex sub-system, not needed here
--
-- Theorems (19 total, 0 sorry):
--   MaxBandwidthFilter: get_ge_slot0, get_ge_slot1, update_get_ge_sample,
--     update_get_ge_old, update_slot0_unchanged, advance_slot0_eq_old_slot1,
--     advance_slot1_zero, advance_zero_noop, advance_get_ge_old_slot1,
--     update_then_advance_slot0, update_get_monotone (11)
--   RoundTripCounter: on_acked_count_nondecreasing, on_acked_true_count_inc,
--     on_acked_false_count_unchanged, on_acked_none_always_true,
--     on_acked_within_boundary_false, on_acked_beyond_boundary_true,
--     on_sent_updates_last, restart_sets_boundary,
--     round_trip_count_monotone_two (8)

namespace FVSquad.BBR2NetworkFilters

-- ---------------------------------------------------------------------------
-- §1  MaxBandwidthFilter
-- ---------------------------------------------------------------------------

/-- Two-slot sliding-window max bandwidth filter.
    `slot0` = max BW from the previous round; `slot1` = running max this round.
    Models `MaxBandwidthFilter` in network_model.rs. -/
structure MaxBandwidthFilter where
  slot0 : Nat
  slot1 : Nat
  deriving DecidableEq, Repr

/-- `get` returns the maximum over both slots.
    Mirrors `MaxBandwidthFilter::get`. -/
def MaxBandwidthFilter.get (f : MaxBandwidthFilter) : Nat :=
  Nat.max f.slot0 f.slot1

/-- `update` widens slot1 to include the new sample.
    Mirrors `MaxBandwidthFilter::update`. -/
def MaxBandwidthFilter.update (f : MaxBandwidthFilter) (sample : Nat) :
    MaxBandwidthFilter :=
  { f with slot1 := Nat.max f.slot1 sample }

/-- `advance` rotates the window: slot0 := slot1, slot1 := 0.
    If slot1 is 0 (no samples this round), the filter does not rotate.
    Mirrors `MaxBandwidthFilter::advance`. -/
def MaxBandwidthFilter.advance (f : MaxBandwidthFilter) : MaxBandwidthFilter :=
  if f.slot1 = 0 then f
  else { slot0 := f.slot1, slot1 := 0 }

-- get ≥ slot0
theorem MaxBandwidthFilter.get_ge_slot0 (f : MaxBandwidthFilter) :
    f.slot0 ≤ f.get :=
  Nat.le_max_left f.slot0 f.slot1

-- get ≥ slot1
theorem MaxBandwidthFilter.get_ge_slot1 (f : MaxBandwidthFilter) :
    f.slot1 ≤ f.get :=
  Nat.le_max_right f.slot0 f.slot1

-- after update, get ≥ sample
theorem MaxBandwidthFilter.update_get_ge_sample (f : MaxBandwidthFilter)
    (s : Nat) : s ≤ (f.update s).get := by
  simp only [MaxBandwidthFilter.update, MaxBandwidthFilter.get]
  exact Nat.le_trans (Nat.le_max_right f.slot1 s) (Nat.le_max_right f.slot0 _)

-- update never decreases get
theorem MaxBandwidthFilter.update_get_ge_old (f : MaxBandwidthFilter) (s : Nat) :
    f.get ≤ (f.update s).get := by
  simp only [MaxBandwidthFilter.update, MaxBandwidthFilter.get]
  apply Nat.max_le.mpr
  exact ⟨Nat.le_max_left _ _,
    Nat.le_trans (Nat.le_max_left f.slot1 s) (Nat.le_max_right f.slot0 _)⟩

-- update does not change slot0
theorem MaxBandwidthFilter.update_slot0_unchanged (f : MaxBandwidthFilter)
    (s : Nat) : (f.update s).slot0 = f.slot0 := by
  simp [MaxBandwidthFilter.update]

-- after advance with nonzero slot1, slot0 = old slot1
theorem MaxBandwidthFilter.advance_slot0_eq_old_slot1 (f : MaxBandwidthFilter)
    (h : f.slot1 ≠ 0) : (f.advance).slot0 = f.slot1 := by
  simp [MaxBandwidthFilter.advance, h]

-- after advance with nonzero slot1, slot1 = 0
theorem MaxBandwidthFilter.advance_slot1_zero (f : MaxBandwidthFilter)
    (h : f.slot1 ≠ 0) : (f.advance).slot1 = 0 := by
  simp [MaxBandwidthFilter.advance, h]

-- advance with zero slot1 is a no-op
theorem MaxBandwidthFilter.advance_zero_noop (f : MaxBandwidthFilter)
    (h : f.slot1 = 0) : f.advance = f := by
  simp [MaxBandwidthFilter.advance, h]

-- after advance, get ≥ old slot1 (previous round's max is not lost)
theorem MaxBandwidthFilter.advance_get_ge_old_slot1 (f : MaxBandwidthFilter) :
    f.slot1 ≤ (f.advance).get := by
  unfold MaxBandwidthFilter.advance MaxBandwidthFilter.get
  by_cases h : f.slot1 = 0
  · simp [h]
  · simp [h]

-- update then advance: slot0 reflects the update
theorem MaxBandwidthFilter.update_then_advance_slot0 (f : MaxBandwidthFilter)
    (s : Nat) (h : Nat.max f.slot1 s ≠ 0) :
    ((f.update s).advance).slot0 = Nat.max f.slot1 s := by
  simp [MaxBandwidthFilter.update, MaxBandwidthFilter.advance, h]

-- update is monotone: larger sample gives larger get
theorem MaxBandwidthFilter.update_get_monotone (f : MaxBandwidthFilter)
    (s t : Nat) (h : s ≤ t) :
    (f.update s).get ≤ (f.update t).get := by
  simp only [MaxBandwidthFilter.update, MaxBandwidthFilter.get]
  have h1 : Nat.max f.slot1 s ≤ Nat.max f.slot1 t :=
    Nat.max_le.mpr ⟨Nat.le_max_left _ _,
      Nat.le_trans h (Nat.le_max_right _ _)⟩
  exact Nat.max_le.mpr ⟨Nat.le_max_left _ _,
    Nat.le_trans h1 (Nat.le_max_right _ _)⟩

-- ---------------------------------------------------------------------------
-- §2  RoundTripCounter
-- ---------------------------------------------------------------------------

/-- Tracks the number of completed BBR2 round trips.
    `roundTripCount` is non-decreasing; `endOfRoundTrip` is the packet
    boundary beyond which the next ack completes a new round.
    Models `RoundTripCounter` in network_model.rs. -/
structure RoundTripCounter where
  roundTripCount : Nat
  lastSentPacket : Nat
  endOfRoundTrip : Option Nat
  deriving DecidableEq, Repr

/-- Record that a packet was sent. Must be called in ascending packet order.
    Mirrors `RoundTripCounter::on_packet_sent`. -/
def RoundTripCounter.onPacketSent (c : RoundTripCounter) (pkt : Nat) :
    RoundTripCounter :=
  { c with lastSentPacket := pkt }

/-- Acknowledge received; returns (updated counter, completed_round).
    A round completes when `ack > endOfRoundTrip` (or boundary is None).
    Mirrors `RoundTripCounter::on_packets_acked`. -/
def RoundTripCounter.onPacketsAcked (c : RoundTripCounter) (ack : Nat) :
    RoundTripCounter × Bool :=
  match c.endOfRoundTrip with
  | some boundary =>
    if ack ≤ boundary then (c, false)
    else
      ({ c with
           roundTripCount := c.roundTripCount + 1
           endOfRoundTrip := some c.lastSentPacket },
       true)
  | none =>
    ({ c with
         roundTripCount := c.roundTripCount + 1
         endOfRoundTrip := some c.lastSentPacket },
     true)

/-- Reset the round boundary to lastSentPacket.
    Mirrors `RoundTripCounter::restart_round`. -/
def RoundTripCounter.restartRound (c : RoundTripCounter) : RoundTripCounter :=
  { c with endOfRoundTrip := some c.lastSentPacket }

-- roundTripCount never decreases after onPacketsAcked
theorem RoundTripCounter.on_acked_count_nondecreasing (c : RoundTripCounter)
    (ack : Nat) :
    c.roundTripCount ≤ (c.onPacketsAcked ack).1.roundTripCount := by
  cases hrt : c.endOfRoundTrip with
  | none => simp [RoundTripCounter.onPacketsAcked, hrt]
  | some boundary =>
    simp only [RoundTripCounter.onPacketsAcked, hrt]
    by_cases hle : ack ≤ boundary
    · simp [hle]
    · simp [hle]

-- when onPacketsAcked returns true, roundTripCount increases by 1
theorem RoundTripCounter.on_acked_true_count_inc (c : RoundTripCounter)
    (ack : Nat) (h : (c.onPacketsAcked ack).2 = true) :
    (c.onPacketsAcked ack).1.roundTripCount = c.roundTripCount + 1 := by
  cases hrt : c.endOfRoundTrip with
  | none => simp [RoundTripCounter.onPacketsAcked, hrt]
  | some boundary =>
    simp only [RoundTripCounter.onPacketsAcked, hrt] at h ⊢
    by_cases hle : ack ≤ boundary
    · simp only [if_pos hle] at h; contradiction
    · simp only [if_neg hle]

-- when onPacketsAcked returns false, roundTripCount is unchanged
theorem RoundTripCounter.on_acked_false_count_unchanged (c : RoundTripCounter)
    (ack : Nat) (h : (c.onPacketsAcked ack).2 = false) :
    (c.onPacketsAcked ack).1.roundTripCount = c.roundTripCount := by
  cases hrt : c.endOfRoundTrip with
  | none => simp [RoundTripCounter.onPacketsAcked, hrt] at h
  | some boundary =>
    simp only [RoundTripCounter.onPacketsAcked, hrt] at h ⊢
    by_cases hle : ack ≤ boundary
    · simp only [if_pos hle]
    · simp only [if_neg hle] at h; contradiction

-- when endOfRoundTrip is none, onPacketsAcked always returns true
theorem RoundTripCounter.on_acked_none_always_true (c : RoundTripCounter)
    (ack : Nat) (h : c.endOfRoundTrip = none) :
    (c.onPacketsAcked ack).2 = true := by
  simp [RoundTripCounter.onPacketsAcked, h]

-- when ack ≤ boundary, onPacketsAcked returns false
theorem RoundTripCounter.on_acked_within_boundary_false (c : RoundTripCounter)
    (ack boundary : Nat) (hb : c.endOfRoundTrip = some boundary)
    (hle : ack ≤ boundary) :
    (c.onPacketsAcked ack).2 = false := by
  simp [RoundTripCounter.onPacketsAcked, hb, hle]

-- when ack > boundary, onPacketsAcked returns true
theorem RoundTripCounter.on_acked_beyond_boundary_true (c : RoundTripCounter)
    (ack boundary : Nat) (hb : c.endOfRoundTrip = some boundary)
    (hgt : boundary < ack) :
    (c.onPacketsAcked ack).2 = true := by
  simp [RoundTripCounter.onPacketsAcked, hb, Nat.not_le.mpr hgt]

-- onPacketSent updates lastSentPacket
theorem RoundTripCounter.on_sent_updates_last (c : RoundTripCounter) (pkt : Nat) :
    (c.onPacketSent pkt).lastSentPacket = pkt := by
  simp [RoundTripCounter.onPacketSent]

-- restartRound sets endOfRoundTrip = some lastSentPacket
theorem RoundTripCounter.restart_sets_boundary (c : RoundTripCounter) :
    (c.restartRound).endOfRoundTrip = some c.lastSentPacket := by
  simp [RoundTripCounter.restartRound]

-- roundTripCount is monotone over two acks (transitivity)
theorem RoundTripCounter.round_trip_count_monotone_two (c : RoundTripCounter)
    (a1 a2 : Nat) :
    c.roundTripCount ≤
      ((c.onPacketsAcked a1).1.onPacketsAcked a2).1.roundTripCount := by
  have h1 := RoundTripCounter.on_acked_count_nondecreasing c a1
  have h2 := RoundTripCounter.on_acked_count_nondecreasing
    (c.onPacketsAcked a1).1 a2
  omega

-- ---------------------------------------------------------------------------
-- §3  Decidable examples (sanity checks)
-- ---------------------------------------------------------------------------

-- MaxBandwidthFilter examples
#eval (MaxBandwidthFilter.mk 100 200).get            -- 200
#eval (MaxBandwidthFilter.mk 100 200).update 150     -- slot1 stays 200
#eval (MaxBandwidthFilter.mk 100 200).update 250     -- slot1 becomes 250
#eval (MaxBandwidthFilter.mk 100 200).advance        -- slot0=200, slot1=0
#eval (MaxBandwidthFilter.mk 100 0).advance          -- unchanged (slot1=0)

-- RoundTripCounter examples
#eval (RoundTripCounter.mk 0 5 none).onPacketsAcked 3     -- (count=1, true)
#eval (RoundTripCounter.mk 1 5 (some 4)).onPacketsAcked 3 -- (count=1, false)
#eval (RoundTripCounter.mk 1 5 (some 4)).onPacketsAcked 5 -- (count=2, true)

end FVSquad.BBR2NetworkFilters
