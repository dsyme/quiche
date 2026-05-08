-- Copyright (C) 2024, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — T55: BBR2 startup exit — full_bandwidth_reached monotonicity
--
-- Target T55: BBR2StartupExit
-- Source: quiche/src/recovery/gcongestion/bbr2/network_model.rs
--   has_bandwidth_growth (lines 632–659)
--   check_persistent_queue (lines 661–685)
--   set_full_bandwidth_reached (lines 708–710)
-- Phase: 5 — Implementation + Proofs
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- Models two startup-exit paths:
--   (A) has_bandwidth_growth — no growth for ≥ startup_full_bw_rounds rounds
--       (when not app-limited) ⟹ full_bandwidth_reached := true
--   (B) check_persistent_queue — rounds_with_queueing ≥ max_startup_queue_rounds
--       ⟹ full_bandwidth_reached := true
--   (C) set_full_bandwidth_reached — unconditional setter
--
-- Approximations / omissions:
--   * Bandwidth modelled as Nat (no f64 multiplication, no overflow).
--   * full_bw_threshold modelled as a Nat multiplier threshold (exact integer
--     comparison rather than fractional).  The key property — once set, never
--     cleared — holds regardless of the threshold arithmetic.
--   * is_app_limited modelled as Bool; ignore_app_limited flag retained.
--   * bytes_lost, loss_events, and BDP helpers are not modelled.
--
-- Theorems (15 total, 0 sorry):
--   1.  set_full_bandwidth_reached_sets
--   2.  set_full_bandwidth_reached_monotone
--   3.  has_bw_growth_reached_monotone
--   4.  has_bw_growth_growth_sets
--   5.  has_bw_growth_no_growth_rounds_inc
--   6.  has_bw_growth_no_growth_rounds_inc_applimited
--   7.  has_bw_growth_growth_rounds_reset
--   8.  has_bw_growth_reached_already_set
--   9.  check_queue_monotone
--   10. check_queue_resets_on_inflight_low
--   11. check_queue_sets_on_threshold
--   12. check_queue_reached_already_set
--   13. full_bw_reached_never_cleared_has_bw
--   14. full_bw_reached_never_cleared_check_queue
--   15. full_bw_reached_never_cleared_set

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  Types
-- ─────────────────────────────────────────────────────────────────────────────

/-- Minimal model of the startup-exit state in BBRv2NetworkModel. -/
structure StartupState where
  full_bandwidth_reached        : Bool
  full_bandwidth_baseline       : Nat   -- Bandwidth (bits/s), modelled as Nat
  rounds_without_bandwidth_growth : Nat
  rounds_with_queueing          : Nat
  deriving Repr

/-- Parameters needed by the startup-exit logic. -/
structure StartupParams where
  startup_full_bw_rounds    : Nat   -- rounds of no-growth before exit
  max_startup_queue_rounds  : Nat   -- rounds of queueing before exit
  full_bw_threshold_num     : Nat   -- numerator of full_bw_threshold (e.g. 125)
  full_bw_threshold_den     : Nat   -- denominator             (e.g. 100)
  h_den_pos : 0 < full_bw_threshold_den

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  Operations
-- ─────────────────────────────────────────────────────────────────────────────

/-- Unconditionally set full_bandwidth_reached to true. -/
def setFullBwReached (s : StartupState) : StartupState :=
  { s with full_bandwidth_reached := true }

/-- Model has_bandwidth_growth.
    Returns (new_state, growth_detected).
    `max_bw` : current max-bandwidth reading
    `is_app_limited` : last_packet_send_state.is_app_limited
    `ignore_app_limited` : ignore_app_limited_for_no_bandwidth_growth -/
def hasBandwidthGrowth
    (s : StartupState) (p : StartupParams)
    (max_bw : Nat) (is_app_limited ignore_app_limited : Bool) :
    StartupState × Bool :=
  -- threshold = full_bandwidth_baseline * (full_bw_threshold_num / den)
  -- Integer version: max_bw * den ≥ baseline * num
  let threshold_lhs := max_bw * p.full_bw_threshold_den
  let threshold_rhs := s.full_bandwidth_baseline * p.full_bw_threshold_num
  if threshold_lhs ≥ threshold_rhs then
    -- bandwidth grew: reset counters
    ({ s with
         full_bandwidth_baseline       := max_bw,
         rounds_without_bandwidth_growth := 0 },
     true)
  else
    -- no growth observed
    let ignore_round := ignore_app_limited && is_app_limited
    let new_rounds :=
      if ignore_round then s.rounds_without_bandwidth_growth
      else s.rounds_without_bandwidth_growth + 1
    let new_reached :=
      s.full_bandwidth_reached ||
      (new_rounds ≥ p.startup_full_bw_rounds && !is_app_limited)
    ({ s with
         rounds_without_bandwidth_growth := new_rounds,
         full_bandwidth_reached          := new_reached },
     false)

/-- Model check_persistent_queue.
    `min_inflight` : min_bytes_in_flight_in_round
    `target`       : BDP-derived target (pre-computed by caller) -/
def checkPersistentQueue
    (s : StartupState) (p : StartupParams)
    (min_inflight target : Nat) : StartupState :=
  if min_inflight < target then
    { s with rounds_with_queueing := 0 }
  else
    let new_q := s.rounds_with_queueing + 1
    let new_reached := s.full_bandwidth_reached || (new_q ≥ p.max_startup_queue_rounds)
    { s with
        rounds_with_queueing := new_q,
        full_bandwidth_reached := new_reached }

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  Theorems
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. setFullBwReached always yields true
theorem set_full_bandwidth_reached_sets (s : StartupState) :
    (setFullBwReached s).full_bandwidth_reached = true := by
  simp [setFullBwReached]

-- 2. setFullBwReached is monotone on full_bandwidth_reached
theorem set_full_bandwidth_reached_monotone (s : StartupState) :
    s.full_bandwidth_reached → (setFullBwReached s).full_bandwidth_reached := by
  intro _; simp [setFullBwReached]

-- 3. hasBandwidthGrowth never clears full_bandwidth_reached
theorem has_bw_growth_reached_monotone
    (s : StartupState) (p : StartupParams)
    (max_bw : Nat) (app_lim ign : Bool)
    (h : s.full_bandwidth_reached = true) :
    (hasBandwidthGrowth s p max_bw app_lim ign).1.full_bandwidth_reached = true := by
  simp [hasBandwidthGrowth]
  split <;> simp [h]

-- 4. Growth path sets full_bandwidth_baseline := max_bw and resets counter
theorem has_bw_growth_growth_sets
    (s : StartupState) (p : StartupParams)
    (max_bw : Nat) (app_lim ign : Bool)
    (hgrow : max_bw * p.full_bw_threshold_den ≥
             s.full_bandwidth_baseline * p.full_bw_threshold_num) :
    let (s', grew) := hasBandwidthGrowth s p max_bw app_lim ign
    grew = true ∧
    s'.full_bandwidth_baseline = max_bw ∧
    s'.rounds_without_bandwidth_growth = 0 := by
  simp [hasBandwidthGrowth, hgrow]

-- 5. No-growth path (not app-limited, ignore=false) increments counter
theorem has_bw_growth_no_growth_rounds_inc
    (s : StartupState) (p : StartupParams)
    (max_bw : Nat)
    (hnogrow : ¬(max_bw * p.full_bw_threshold_den ≥
                 s.full_bandwidth_baseline * p.full_bw_threshold_num)) :
    let (s', _) := hasBandwidthGrowth s p max_bw false false
    s'.rounds_without_bandwidth_growth =
      s.rounds_without_bandwidth_growth + 1 := by
  simp only [hasBandwidthGrowth]
  have hlt : ¬(s.full_bandwidth_baseline * p.full_bw_threshold_num ≤
               max_bw * p.full_bw_threshold_den) := by omega
  simp [hlt]

-- 6. No-growth path with app-limited + ignore=true does NOT increment counter
theorem has_bw_growth_no_growth_rounds_inc_applimited
    (s : StartupState) (p : StartupParams) (max_bw : Nat)
    (hnogrow : ¬(max_bw * p.full_bw_threshold_den ≥
                 s.full_bandwidth_baseline * p.full_bw_threshold_num)) :
    let (s', _) := hasBandwidthGrowth s p max_bw true true
    s'.rounds_without_bandwidth_growth = s.rounds_without_bandwidth_growth := by
  simp only [hasBandwidthGrowth]
  have hlt : ¬(s.full_bandwidth_baseline * p.full_bw_threshold_num ≤
               max_bw * p.full_bw_threshold_den) := by omega
  simp [hlt]

-- 7. Growth path resets rounds counter to 0
theorem has_bw_growth_growth_rounds_reset
    (s : StartupState) (p : StartupParams) (max_bw : Nat)
    (app_lim ign : Bool)
    (hgrow : max_bw * p.full_bw_threshold_den ≥
             s.full_bandwidth_baseline * p.full_bw_threshold_num) :
    (hasBandwidthGrowth s p max_bw app_lim ign).1.rounds_without_bandwidth_growth = 0 := by
  simp [hasBandwidthGrowth, hgrow]

-- 8. If already reached, hasBandwidthGrowth keeps it true
theorem has_bw_growth_reached_already_set
    (s : StartupState) (p : StartupParams) (max_bw : Nat) (app_lim ign : Bool)
    (h : s.full_bandwidth_reached = true) :
    (hasBandwidthGrowth s p max_bw app_lim ign).1.full_bandwidth_reached = true :=
  has_bw_growth_reached_monotone s p max_bw app_lim ign h

-- 9. checkPersistentQueue never clears full_bandwidth_reached
theorem check_queue_monotone
    (s : StartupState) (p : StartupParams) (min_inf target : Nat)
    (h : s.full_bandwidth_reached = true) :
    (checkPersistentQueue s p min_inf target).full_bandwidth_reached = true := by
  simp [checkPersistentQueue]
  split <;> simp [h]

-- 10. checkPersistentQueue resets rounds_with_queueing when inflight is low
theorem check_queue_resets_on_inflight_low
    (s : StartupState) (p : StartupParams) (min_inf target : Nat)
    (hlt : min_inf < target) :
    (checkPersistentQueue s p min_inf target).rounds_with_queueing = 0 := by
  simp [checkPersistentQueue, hlt]

-- 11. checkPersistentQueue sets full_bandwidth_reached when threshold reached
theorem check_queue_sets_on_threshold
    (s : StartupState) (p : StartupParams) (min_inf target : Nat)
    (hge : min_inf ≥ target)
    (hthresh : s.rounds_with_queueing + 1 ≥ p.max_startup_queue_rounds) :
    (checkPersistentQueue s p min_inf target).full_bandwidth_reached = true := by
  simp [checkPersistentQueue, Nat.not_lt.mpr hge, hthresh]

-- 12. If already reached, checkPersistentQueue keeps it true
theorem check_queue_reached_already_set
    (s : StartupState) (p : StartupParams) (min_inf target : Nat)
    (h : s.full_bandwidth_reached = true) :
    (checkPersistentQueue s p min_inf target).full_bandwidth_reached = true :=
  check_queue_monotone s p min_inf target h

-- 13. full_bandwidth_reached never cleared by repeated hasBandwidthGrowth calls
theorem full_bw_reached_never_cleared_has_bw
    (s : StartupState) (p : StartupParams)
    (steps : List (Nat × Bool × Bool))
    (h : s.full_bandwidth_reached = true) :
    (steps.foldl
      (fun acc (bw, al, ig) => (hasBandwidthGrowth acc p bw al ig).1)
      s).full_bandwidth_reached = true := by
  induction steps generalizing s with
  | nil => simpa
  | cons hd tl ih =>
    simp only [List.foldl]
    apply ih
    exact has_bw_growth_reached_monotone s p hd.1 hd.2.1 hd.2.2 h

-- 14. full_bandwidth_reached never cleared by repeated checkPersistentQueue calls
theorem full_bw_reached_never_cleared_check_queue
    (s : StartupState) (p : StartupParams)
    (inputs : List (Nat × Nat))
    (h : s.full_bandwidth_reached = true) :
    (inputs.foldl
      (fun acc (mi, tgt) => checkPersistentQueue acc p mi tgt)
      s).full_bandwidth_reached = true := by
  induction inputs generalizing s with
  | nil => simpa
  | cons hd tl ih =>
    simp only [List.foldl]
    apply ih
    exact check_queue_monotone s p hd.1 hd.2 h

-- 15. full_bandwidth_reached never cleared by setFullBwReached
theorem full_bw_reached_never_cleared_set (s : StartupState) :
    (setFullBwReached s).full_bandwidth_reached = true :=
  set_full_bandwidth_reached_sets s

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Concrete examples
-- ─────────────────────────────────────────────────────────────────────────────

private def defaultParams : StartupParams :=
  ⟨3, 4, 125, 100, by decide⟩

-- hasBandwidthGrowth: growth detected when max_bw exceeds threshold
#eval
  let s : StartupState := ⟨false, 1000, 0, 0⟩
  let p := defaultParams
  -- max_bw=1251: 1251*100=125100 ≥ 1000*125=125000 → growth
  let (s', grew) := hasBandwidthGrowth s p 1251 false false
  grew == true && s'.rounds_without_bandwidth_growth == 0  -- expect true

-- hasBandwidthGrowth: no growth, 3rd round, not app-limited → exit
#eval
  let s : StartupState := ⟨false, 1000, 2, 0⟩
  let p := defaultParams
  -- max_bw=1100: 1100*100=110000 < 1000*125=125000 → no growth
  let (s', _) := hasBandwidthGrowth s p 1100 false false
  s'.full_bandwidth_reached  -- expect true (rounds=3 ≥ threshold=3)

-- checkPersistentQueue: queueing for max_startup_queue_rounds → exit
#eval
  let s : StartupState := ⟨false, 1000, 0, 3⟩
  let p := defaultParams
  let s' := checkPersistentQueue s p 100 50  -- inflight ≥ target
  s'.full_bandwidth_reached  -- expect true (rounds=4 ≥ max=4)

-- setFullBwReached works unconditionally
#eval (setFullBwReached ⟨false, 0, 0, 0⟩).full_bandwidth_reached  -- expect true
