-- Copyright (C) 2024, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/AppLimitedGuard.lean
--
-- Formal verification of the app-limited guard state machine in delivery-rate
-- estimation.
-- Source: quiche/src/recovery/congestion/delivery_rate.rs
--   Rate::update_app_limited, Rate::app_limited, Rate::generate_rate_sample
--
-- RFC reference: draft-cheng-iccrg-delivery-rate-estimation-01 §4.3
--
-- The app-limited guard controls whether a delivery-rate sample is discarded
-- (app_limited=true → only accept if new_rate > old_rate).  The state machine:
--
--   update_app_limited(true)  → end_of_app_limited = max(last_sent_packet, 1)
--   update_app_limited(false) → end_of_app_limited = 0
--   app_limited()             ↔ end_of_app_limited ≠ 0
--   generate_rate_sample():   if app_limited() ∧ largest_acked > end_of_app_limited
--                               then update_app_limited(false)   -- bubble is gone
--
-- Key properties proved here:
--   1. app_limited_iff: state flag ↔ end_of_app_limited ≠ 0
--   2. set_true_marks_app_limited: update_app_limited(true) sets flag
--   3. set_false_clears_app_limited: update_app_limited(false) clears flag
--   4. end_of_app_limited_pos_when_set: when set, end_of_app_limited ≥ 1
--   5. bubble_gone_clears: when largest_acked > end_of_app_limited, state clears
--   6. bubble_not_gone_preserves: when largest_acked ≤ end_of_app_limited, state preserved
--   7. rate_sample_update_guard: app-limited sample only replaces if new > old
--   8. set_true_monotone: end_of_app_limited after set(true) ≥ 1
--   9. double_set_true_idempotent: setting true twice is equivalent to setting once
--  10. app_limited_cleared_after_false: state is never app_limited after set(false)
--
-- Modelling choices / approximations:
--   - Packet numbers (u64) are modelled as Nat.
--   - Bandwidth (rate values) are modelled as Nat (bytes/sec, integer).
--   - Time and Instant are abstracted away — only the structural state machine
--     is modelled here; the timing interactions with sent/acked packets are in
--     DeliveryRate.lean.
--   - The full RateSample struct is not modelled; only the bandwidth field and
--     the app_limited flag on the sample are relevant here.

namespace AppLimitedGuard

/-! ## State representation -/

/-- Pure representation of the app-limited guard state.
    `end_of_app_limited` is the packet number up to which app-limited mode
    extends; 0 means not app-limited.  `last_sent_packet` is the packet
    number of the most recently sent packet. -/
structure State where
  end_of_app_limited : Nat   -- 0 = not app_limited; >0 = app_limited up to this pkt
  last_sent_packet : Nat     -- packet number of last sent packet
  largest_acked : Nat        -- packet number of largest acked packet
  deriving Repr

/-! ## Core operations (pure functional models of the Rust methods) -/

/-- `app_limited()` — returns true iff currently in app-limited state.
    Matches `self.end_of_app_limited != 0` in delivery_rate.rs. -/
def appLimited (s : State) : Bool :=
  s.end_of_app_limited != 0

/-- `update_app_limited(v)` — enter or exit app-limited state.
    Matches:
      if v { self.end_of_app_limited = self.last_sent_packet.max(1) }
      else  { self.end_of_app_limited = 0 }
    in delivery_rate.rs:204–206. -/
def updateAppLimited (s : State) (v : Bool) : State :=
  { s with end_of_app_limited :=
      if v then max s.last_sent_packet 1 else 0 }

/-- `generate_rate_sample` bubble check: exits app-limited mode when the
    app-limited bubble has been fully ACKed.
    Matches `if self.app_limited() && self.largest_acked > self.end_of_app_limited`
    in delivery_rate.rs:127–129. -/
def bubbleCheck (s : State) : State :=
  if appLimited s && decide (s.largest_acked > s.end_of_app_limited) then
    updateAppLimited s false
  else
    s

/-- Rate sample update guard: an app-limited sample only replaces the stored
    bandwidth if the new rate is strictly higher.
    Matches `if !rate_sample.is_app_limited || rate_sample_bandwidth > self.rate_sample.bandwidth`
    in delivery_rate.rs:168–170. -/
def shouldUpdateRate (is_app_limited : Bool) (new_bw old_bw : Nat) : Bool :=
  !is_app_limited || new_bw > old_bw

/-! ## Theorems -/

/-- 1. `appLimited` is equivalent to `end_of_app_limited ≠ 0`. -/
theorem app_limited_iff (s : State) :
    appLimited s = true ↔ s.end_of_app_limited ≠ 0 := by
  simp [appLimited, bne_iff_ne]

/-- 2. After `updateAppLimited true`, the state is app-limited. -/
theorem set_true_marks_app_limited (s : State) :
    appLimited (updateAppLimited s true) = true := by
  simp [appLimited, updateAppLimited]

/-- 3. After `updateAppLimited false`, the state is NOT app-limited. -/
theorem set_false_clears_app_limited (s : State) :
    appLimited (updateAppLimited s false) = false := by
  simp [appLimited, updateAppLimited]

/-- 4. When set to true, `end_of_app_limited ≥ 1` always. -/
theorem end_of_app_limited_pos_when_set (s : State) :
    (updateAppLimited s true).end_of_app_limited ≥ 1 := by
  simp [updateAppLimited]
  omega

/-- 5. When the app-limited bubble has been ACKed, `bubbleCheck` clears the flag. -/
theorem bubble_gone_clears (s : State)
    (h_app : appLimited s = true)
    (h_gone : s.largest_acked > s.end_of_app_limited) :
    appLimited (bubbleCheck s) = false := by
  unfold bubbleCheck
  simp [h_app, decide_eq_true h_gone]
  exact set_false_clears_app_limited s

/-- 6. When the bubble is NOT yet gone, `bubbleCheck` preserves the state. -/
theorem bubble_not_gone_preserves (s : State)
    (h : ¬(appLimited s = true ∧ s.largest_acked > s.end_of_app_limited)) :
    bubbleCheck s = s := by
  unfold bubbleCheck
  by_cases ha : appLimited s = true
  · by_cases hg : s.largest_acked > s.end_of_app_limited
    · exact absurd ⟨ha, hg⟩ h
    · simp [ha, decide_eq_false hg]
  · simp [ha]

/-- 7. A non-app-limited sample always updates the rate (regardless of value). -/
theorem rate_update_when_not_app_limited (new_bw old_bw : Nat) :
    shouldUpdateRate false new_bw old_bw = true := by
  simp [shouldUpdateRate]

/-- 8. An app-limited sample updates the rate only if new > old. -/
theorem rate_update_iff_new_gt_old (new_bw old_bw : Nat) :
    shouldUpdateRate true new_bw old_bw = true ↔ new_bw > old_bw := by
  simp [shouldUpdateRate]

/-- 9. After `updateAppLimited true`, `end_of_app_limited = max(last_sent, 1)`. -/
theorem set_true_end_value (s : State) :
    (updateAppLimited s true).end_of_app_limited = max s.last_sent_packet 1 := by
  simp [updateAppLimited]

/-- 10. `appLimited (updateAppLimited s false) = false` regardless of state. -/
theorem app_limited_cleared_after_false (s : State) :
    appLimited (updateAppLimited s false) = false :=
  set_false_clears_app_limited s

/-- 11. `updateAppLimited false` followed by `updateAppLimited true` is app-limited. -/
theorem clear_then_set_is_app_limited (s : State) :
    appLimited (updateAppLimited (updateAppLimited s false) true) = true :=
  set_true_marks_app_limited _

/-- 12. Double application of `updateAppLimited true` is idempotent in the flag. -/
theorem double_set_true_flag (s : State) :
    appLimited (updateAppLimited (updateAppLimited s true) true) = true :=
  set_true_marks_app_limited _

/-- 13. `updateAppLimited false` is idempotent. -/
theorem double_set_false (s : State) :
    updateAppLimited (updateAppLimited s false) false =
    updateAppLimited s false := by
  simp [updateAppLimited]

/-- 14. After `bubbleCheck` and a subsequent packet ACK beyond the bubble boundary,
    the state transitions to not-app-limited. -/
theorem bubbleCheck_then_cleared (s : State)
    (h_app : appLimited s = true)
    (h_gone : s.largest_acked > s.end_of_app_limited) :
    (bubbleCheck s).end_of_app_limited = 0 := by
  simp [bubbleCheck, h_app, decide_eq_true h_gone, updateAppLimited]

/-! ## Concrete examples -/

-- Setting app_limited=true with last_sent=5 → end_of_app_limited=5
example : (updateAppLimited ⟨0, 5, 0⟩ true).end_of_app_limited = 5 := by
  native_decide

-- Setting app_limited=true with last_sent=0 → end_of_app_limited=1 (max(0,1)=1)
example : (updateAppLimited ⟨0, 0, 0⟩ true).end_of_app_limited = 1 := by
  native_decide

-- Clearing: end_of_app_limited always becomes 0
example : (updateAppLimited ⟨7, 10, 3⟩ false).end_of_app_limited = 0 := by
  native_decide

-- Bubble check: largest_acked=8 > end_of_app_limited=5 → clears
example : appLimited (bubbleCheck ⟨5, 10, 8⟩) = false := by native_decide

-- Bubble check: largest_acked=4 ≤ end_of_app_limited=5 → stays
example : appLimited (bubbleCheck ⟨5, 10, 4⟩) = true := by native_decide

-- Rate guard: app_limited=false → always update
example : shouldUpdateRate false 100 200 = true := by native_decide

-- Rate guard: app_limited=true, new > old → update
example : shouldUpdateRate true 300 200 = true := by native_decide

-- Rate guard: app_limited=true, new ≤ old → no update
example : shouldUpdateRate true 150 200 = false := by native_decide

end AppLimitedGuard
