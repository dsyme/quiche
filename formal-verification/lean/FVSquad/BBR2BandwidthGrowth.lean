-- Copyright (C) 2025, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — T80: BBR2 has_bandwidth_growth — full model with is_valid
--
-- Target T80: BBR2 `has_bandwidth_growth` (and `check_persistent_queue`)
-- Source: quiche/src/recovery/gcongestion/bbr2/network_model.rs
--   has_bandwidth_growth  (L630–662)
--   check_persistent_queue (L669–686)
-- Phase: 5 — Implementation + Proofs
-- Lean 4.29.1, no Mathlib dependency.
--
-- Relationship to T55 (BBR2StartupExit.lean):
--   T55 models a simplified version of has_bandwidth_growth without the
--   `is_valid` guard (the early-return when send-state is unavailable).
--   T80 models the full function including that guard, proving properties
--   that depend on it: in particular, the invalid-send-state path never
--   increments the counter, and the baseline is non-decreasing.
--
-- The Rust function (full):
--   fn has_bandwidth_growth(&mut self, ev: &Event, params: &Params) -> bool {
--     let threshold = self.full_bandwidth_baseline * params.full_bw_threshold;
--     if self.max_bandwidth() >= threshold {        // growth path
--       self.full_bandwidth_baseline = self.max_bandwidth();
--       self.rounds_without_bandwidth_growth = 0;
--       return true;
--     }
--     if !ev.is_valid { return false; }             // invalid guard
--     let ignore = self.ignore_app_limited && ev.is_app_limited;
--     if !ignore { self.rounds_without_bandwidth_growth += 1; }
--     if self.rounds ≥ params.startup_full_bw_rounds && !ev.is_app_limited {
--       self.full_bandwidth_reached = true;
--     }
--     false
--   }
--
-- Modelling choices:
--   * Bandwidth as Nat; full_bw_threshold as ratio (threshNum / threshDen).
--   * Growth condition: maxBw * threshDen ≥ baseline * threshNum.
--   * is_valid modelled as Bool (adds the guard omitted in T55).
--   * usize / u64 overflow not modelled.
--
-- Theorems (20 total, 0 sorry):
--   growth_path_returns_true, growth_path_resets_counter,
--   growth_path_updates_baseline, growth_path_fullBwReached_unchanged,
--   noGrowth_returns_false, baseline_only_increases,
--   baseline_ge_after_growth,
--   counter_monotone_on_noGrowth, counter_resets_on_growth,
--   counter_le_old_plus_one, fullBwReached_monotone,
--   invalidSendState_no_counter_inc, invalidSendState_returns_false,
--   appLimited_guard_no_counter_inc,
--   counter_inc_on_valid_notAppLimited,
--   fullBwReached_not_set_when_appLimited,
--   queue_sets_fullBwReached, queue_resets_on_noQueue,
--   queue_counter_monotone, queue_fullBwReached_monotone

namespace FVSquad.BBR2BandwidthGrowth

-- ---------------------------------------------------------------------------
-- §1  Types
-- ---------------------------------------------------------------------------

structure BwState where
  maxBandwidth            : Nat
  fullBandwidthBaseline   : Nat
  roundsWithoutGrowth     : Nat
  ignoreAppLimited        : Bool
  fullBwReached           : Bool
  roundsWithQueueing      : Nat
  minBytesInFlightInRound : Nat

structure SendState where
  isValid      : Bool
  isAppLimited : Bool

structure BwParams where
  threshNum             : Nat
  threshDen             : Nat
  startupFullBwRounds   : Nat
  maxStartupQueueRounds : Nat
  persistentQueueTarget : Nat

-- ---------------------------------------------------------------------------
-- §2  Model
-- ---------------------------------------------------------------------------

/-- Full model of has_bandwidth_growth, including the is_valid guard. -/
def hasBwGrowth (s : BwState) (ev : SendState) (p : BwParams)
    : Bool × BwState :=
  if s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum then
    (true,  { s with fullBandwidthBaseline := s.maxBandwidth
                     roundsWithoutGrowth   := 0 })
  else if !ev.isValid then
    (false, s)
  else
    let ign := s.ignoreAppLimited && ev.isAppLimited
    let r'  := if ign then s.roundsWithoutGrowth else s.roundsWithoutGrowth + 1
    let f'  := s.fullBwReached ||
               (r' ≥ p.startupFullBwRounds && !ev.isAppLimited)
    (false, { s with roundsWithoutGrowth := r'
                     fullBwReached        := f' })

/-- Model of check_persistent_queue. -/
def checkQueue (s : BwState) (p : BwParams) : BwState :=
  if s.minBytesInFlightInRound < p.persistentQueueTarget then
    { s with roundsWithQueueing := 0 }
  else
    let rq' := s.roundsWithQueueing + 1
    { s with roundsWithQueueing := rq'
             fullBwReached      := s.fullBwReached ||
                                   (rq' ≥ p.maxStartupQueueRounds) }

-- ---------------------------------------------------------------------------
-- §3  Theorems
-- ---------------------------------------------------------------------------

-- §3.1 Growth path

theorem growth_path_returns_true (s : BwState) (ev : SendState) (p : BwParams)
    (h : s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum) :
    (hasBwGrowth s ev p).1 = true := by
  simp [hasBwGrowth, h]

theorem growth_path_resets_counter (s : BwState) (ev : SendState) (p : BwParams)
    (h : s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum) :
    (hasBwGrowth s ev p).2.roundsWithoutGrowth = 0 := by
  simp [hasBwGrowth, h]

theorem growth_path_updates_baseline (s : BwState) (ev : SendState) (p : BwParams)
    (h : s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum) :
    (hasBwGrowth s ev p).2.fullBandwidthBaseline = s.maxBandwidth := by
  simp [hasBwGrowth, h]

theorem growth_path_fullBwReached_unchanged
    (s : BwState) (ev : SendState) (p : BwParams)
    (h : s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum) :
    (hasBwGrowth s ev p).2.fullBwReached = s.fullBwReached := by
  simp [hasBwGrowth, h]

-- §3.2 No-growth path always returns false

theorem noGrowth_returns_false (s : BwState) (ev : SendState) (p : BwParams)
    (h : ¬(s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum)) :
    (hasBwGrowth s ev p).1 = false := by
  simp only [hasBwGrowth]
  have hlt : ¬(s.fullBandwidthBaseline * p.threshNum ≤
               s.maxBandwidth * p.threshDen) := by omega
  simp [hlt]
  split <;> simp

-- §3.3 Baseline: non-growth paths don't change the baseline

/-- The no-growth paths (invalid or counter-increment) preserve the baseline. -/
theorem baseline_unchanged_on_noGrowth (s : BwState) (ev : SendState) (p : BwParams)
    (h : ¬(s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum)) :
    (hasBwGrowth s ev p).2.fullBandwidthBaseline = s.fullBandwidthBaseline := by
  simp only [hasBwGrowth]
  have hlt : ¬(s.fullBandwidthBaseline * p.threshNum ≤
               s.maxBandwidth * p.threshDen) := by omega
  simp [hlt]
  split
  · rfl
  · split <;> simp

-- §3.4 Baseline is ≥ old baseline when growth threshold ≥ 1

/-- If the threshold is ≥ 1 (threshNum ≥ threshDen > 0) and growth was
    detected, then the new baseline ≥ the old baseline. -/
theorem baseline_ge_after_growth
    (s : BwState) (ev : SendState) (p : BwParams)
    (hge : s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum)
    (hthresh : p.threshNum ≥ p.threshDen) (hden : 0 < p.threshDen) :
    (hasBwGrowth s ev p).2.fullBandwidthBaseline ≥ s.fullBandwidthBaseline := by
  rw [growth_path_updates_baseline s ev p hge]
  have hle : s.fullBandwidthBaseline * p.threshDen ≤ s.maxBandwidth * p.threshDen :=
    Nat.le_trans (Nat.mul_le_mul_left _ hthresh) hge
  exact Nat.le_of_mul_le_mul_right hle hden

-- §3.5 Counter monotone on no-growth

theorem counter_monotone_on_noGrowth
    (s : BwState) (ev : SendState) (p : BwParams)
    (h : ¬(s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum)) :
    (hasBwGrowth s ev p).2.roundsWithoutGrowth ≥ s.roundsWithoutGrowth := by
  unfold hasBwGrowth
  simp [h]
  by_cases hv : ev.isValid
  · simp [hv]
    split
    · exact Nat.le_refl _
    · omega
  · simp [hv]

theorem counter_resets_on_growth (s : BwState) (ev : SendState) (p : BwParams)
    (h : s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum) :
    (hasBwGrowth s ev p).2.roundsWithoutGrowth = 0 :=
  growth_path_resets_counter s ev p h

theorem counter_le_old_plus_one (s : BwState) (ev : SendState) (p : BwParams) :
    (hasBwGrowth s ev p).2.roundsWithoutGrowth ≤ s.roundsWithoutGrowth + 1 := by
  unfold hasBwGrowth
  by_cases hg : s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum
  · simp [hg]
  · simp [hg]
    by_cases hv : ev.isValid
    · simp [hv]
      split
      · omega
      · omega
    · simp [hv]

-- §3.6 fullBwReached monotone

theorem fullBwReached_monotone (s : BwState) (ev : SendState) (p : BwParams)
    (h : s.fullBwReached = true) :
    (hasBwGrowth s ev p).2.fullBwReached = true := by
  unfold hasBwGrowth
  by_cases hg : s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum
  · simp [hg, h]
  · simp [hg]
    by_cases hv : ev.isValid
    · simp [hv, h]
    · simp [hv, h]

-- §3.7 Invalid send state: no counter or flag update

theorem invalidSendState_no_counter_inc
    (s : BwState) (ev : SendState) (p : BwParams)
    (hno : ¬(s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum))
    (hinv : ev.isValid = false) :
    (hasBwGrowth s ev p).2.roundsWithoutGrowth = s.roundsWithoutGrowth := by
  simp only [hasBwGrowth]
  have hlt : ¬(s.fullBandwidthBaseline * p.threshNum ≤
               s.maxBandwidth * p.threshDen) := by omega
  simp [hlt, hinv]

theorem invalidSendState_returns_false
    (s : BwState) (ev : SendState) (p : BwParams)
    (hno : ¬(s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum))
    (hinv : ev.isValid = false) :
    (hasBwGrowth s ev p).1 = false := by
  simp only [hasBwGrowth]
  have hlt : ¬(s.fullBandwidthBaseline * p.threshNum ≤
               s.maxBandwidth * p.threshDen) := by omega
  simp [hlt, hinv]

-- §3.8 App-limited guard

theorem appLimited_guard_no_counter_inc
    (s : BwState) (ev : SendState) (p : BwParams)
    (hno : ¬(s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum))
    (hval : ev.isValid = true)
    (hign : s.ignoreAppLimited = true)
    (happ : ev.isAppLimited = true) :
    (hasBwGrowth s ev p).2.roundsWithoutGrowth = s.roundsWithoutGrowth := by
  simp only [hasBwGrowth]
  have hlt : ¬(s.fullBandwidthBaseline * p.threshNum ≤
               s.maxBandwidth * p.threshDen) := by omega
  simp [hlt, hval, hign, happ]

theorem counter_inc_on_valid_notAppLimited
    (s : BwState) (ev : SendState) (p : BwParams)
    (hno : ¬(s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum))
    (hval : ev.isValid = true)
    (happ : ev.isAppLimited = false) :
    (hasBwGrowth s ev p).2.roundsWithoutGrowth = s.roundsWithoutGrowth + 1 := by
  simp only [hasBwGrowth]
  have hlt : ¬(s.fullBandwidthBaseline * p.threshNum ≤
               s.maxBandwidth * p.threshDen) := by omega
  simp [hlt, hval, happ]

/-- fullBwReached is never set via the app-limited path. -/
theorem fullBwReached_not_set_when_appLimited
    (s : BwState) (ev : SendState) (p : BwParams)
    (hno : ¬(s.maxBandwidth * p.threshDen ≥ s.fullBandwidthBaseline * p.threshNum))
    (hval : ev.isValid = true)
    (hnfbr : s.fullBwReached = false)
    (happ : ev.isAppLimited = true) :
    (hasBwGrowth s ev p).2.fullBwReached = false := by
  simp only [hasBwGrowth]
  have hlt : ¬(s.fullBandwidthBaseline * p.threshNum ≤
               s.maxBandwidth * p.threshDen) := by omega
  simp [hlt, hval, hnfbr, happ]

-- §3.9 check_persistent_queue

theorem queue_sets_fullBwReached (s : BwState) (p : BwParams)
    (hge : ¬(s.minBytesInFlightInRound < p.persistentQueueTarget))
    (hthresh : s.roundsWithQueueing + 1 ≥ p.maxStartupQueueRounds) :
    (checkQueue s p).fullBwReached = true := by
  simp [checkQueue]
  split
  · omega
  · simp [hthresh]

theorem queue_resets_on_noQueue (s : BwState) (p : BwParams)
    (hlt : s.minBytesInFlightInRound < p.persistentQueueTarget) :
    (checkQueue s p).roundsWithQueueing = 0 := by
  simp [checkQueue, hlt]

theorem queue_counter_monotone (s : BwState) (p : BwParams)
    (hge : ¬(s.minBytesInFlightInRound < p.persistentQueueTarget)) :
    (checkQueue s p).roundsWithQueueing = s.roundsWithQueueing + 1 := by
  simp only [checkQueue]
  split
  · omega
  · rfl

theorem queue_fullBwReached_monotone (s : BwState) (p : BwParams)
    (h : s.fullBwReached = true) :
    (checkQueue s p).fullBwReached = true := by
  simp [checkQueue]
  split <;> simp [h]

end FVSquad.BBR2BandwidthGrowth
