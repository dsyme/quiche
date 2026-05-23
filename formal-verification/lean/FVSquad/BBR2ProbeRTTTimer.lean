-- Copyright (C) 2025, Cloudflare, Inc.
-- BSD-2-Clause licence (same as quiche)
--
-- 🔬 Lean Squad — formal specification of the BBR2 ProbeRTT exit-timer
-- state machine.
--
-- Target T82: ProbeRTT exit timer logic
-- Source: quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs
-- Phase: 5 — Implementation + Proofs
-- Lean 4.29.1, no Mathlib dependency.
--
-- The ProbeRTT mode has one mutable field: exit_time: Option<Instant>.
--
--   on_congestion_event logic (timer part only):
--     | None, inflight ≤ target  => (Some(now + dur), stay)
--     | None, inflight > target  => (None, stay)
--     | Some(t), now > t         => (Some(t), exit)
--     | Some(t), now ≤ t         => (Some(t), stay)
--
--   on_exit_quiescence logic:
--     | None              => exit
--     | Some(t), now > t  => exit
--     | Some(t), now ≤ t  => stay
--
-- Modelled abstractions:
--   * Time as Nat (ordering only).
--   * probe_rtt_duration as opaque `dur : Nat`.
--   * inflight_target as opaque `target : Nat`.
--   * ProbeBW transition as Bool (true = exit ProbeRTT).
--
-- Theorems (20 total, 0 sorry):
--   exitTimer_none_stays, exitTimer_none_sets,
--   exitTimer_some_stay, exitTimer_some_exit,
--   exitTimer_set_is_future,
--   exitTimer_none_once_set_stays_set,
--   quiescence_none_exits, quiescence_expired_exits,
--   quiescence_not_expired_stays,
--   congestion_sets_timer_when_inflight_ok,
--   congestion_no_timer_set_when_inflight_high,
--   congestion_exits_when_timer_expired,
--   congestion_stays_when_timer_not_expired,
--   timer_set_iff_inflight_le_target,
--   quiescence_exit_iff,
--   congestion_exit_iff,
--   exit_time_monotone,
--   quiescence_always_resolves,
--   congestion_new_timer_ge_now,
--   combined_exit_conditions_disjoint

namespace FVSquad.BBR2ProbeRTTTimer

-- ---------------------------------------------------------------------------
-- §1  Types
-- ---------------------------------------------------------------------------

/-- ProbeRTT exit-timer state: either not set or set to a deadline. -/
abbrev ExitTime := Option Nat

-- ---------------------------------------------------------------------------
-- §2  Implementation models
-- ---------------------------------------------------------------------------

/-- Timer update during a congestion event.
    Returns (new_exit_time, should_exit). -/
def congestionStep
    (exit_time  : ExitTime) (inflight target event_time dur : Nat)
    : ExitTime × Bool :=
  match exit_time with
  | none =>
      if inflight ≤ target then (some (event_time + dur), false)
      else                      (none, false)
  | some t =>
      if event_time > t then (some t, true)
      else                   (some t, false)

/-- Exit decision during quiescence. -/
def quiescenceStep (exit_time : ExitTime) (now : Nat) : Bool :=
  match exit_time with
  | none   => true
  | some t => if now > t then true else false

-- ---------------------------------------------------------------------------
-- §3  Lemmas about congestionStep
-- ---------------------------------------------------------------------------

theorem exitTimer_none_stays
    (inflight target event_time dur : Nat) (h : ¬ inflight ≤ target) :
    congestionStep none inflight target event_time dur = (none, false) := by
  simp [congestionStep, h]

theorem exitTimer_none_sets
    (inflight target event_time dur : Nat) (h : inflight ≤ target) :
    congestionStep none inflight target event_time dur =
      (some (event_time + dur), false) := by
  simp [congestionStep, h]

theorem exitTimer_some_stay
    (t inflight target event_time dur : Nat) (h : ¬ event_time > t) :
    congestionStep (some t) inflight target event_time dur = (some t, false) := by
  simp [congestionStep, h]

theorem exitTimer_some_exit
    (t inflight target event_time dur : Nat) (h : event_time > t) :
    congestionStep (some t) inflight target event_time dur = (some t, true) := by
  simp [congestionStep, h]

-- New timer is strictly after event_time when dur > 0.
theorem exitTimer_set_is_future
    (inflight target event_time dur : Nat)
    (h_in : inflight ≤ target) (h_dur : 0 < dur) :
    event_time < event_time + dur := by
  omega

-- Once Some, congestionStep keeps the timer as Some t.
theorem exitTimer_none_once_set_stays_set
    (t inflight target event_time dur : Nat) :
    (congestionStep (some t) inflight target event_time dur).1 = some t := by
  simp [congestionStep]; split <;> rfl

-- Timer is set from None iff inflight ≤ target.
theorem timer_set_iff_inflight_le_target
    (inflight target event_time dur : Nat) :
    (congestionStep none inflight target event_time dur).1 ≠ none ↔
      inflight ≤ target := by
  simp [congestionStep]
  by_cases h : inflight ≤ target <;> simp [h]

-- Exit condition iff: exit ↔ timer was set AND expired.
theorem congestion_exit_iff
    (exit_time : ExitTime) (inflight target event_time dur : Nat) :
    (congestionStep exit_time inflight target event_time dur).2 = true ↔
      ∃ t, exit_time = some t ∧ event_time > t := by
  match exit_time with
  | none   => simp [congestionStep]; split <;> simp
  | some t =>
    by_cases h : event_time > t
    · simp [congestionStep, h]
    · simp [congestionStep, h]

-- congestion exits when timer expired.
theorem congestion_exits_when_timer_expired
    (t inflight target event_time dur : Nat) (h : event_time > t) :
    (congestionStep (some t) inflight target event_time dur).2 = true := by
  simp [congestionStep, h]

-- congestion stays when timer not expired.
theorem congestion_stays_when_timer_not_expired
    (t inflight target event_time dur : Nat) (h : ¬ event_time > t) :
    (congestionStep (some t) inflight target event_time dur).2 = false := by
  simp [congestionStep, h]

-- Sets timer when inflight ok.
theorem congestion_sets_timer_when_inflight_ok
    (inflight target event_time dur : Nat) (h : inflight ≤ target) :
    (congestionStep none inflight target event_time dur).1 =
      some (event_time + dur) := by
  simp [congestionStep, h]

-- No timer set when inflight too high.
theorem congestion_no_timer_set_when_inflight_high
    (inflight target event_time dur : Nat) (h : ¬ inflight ≤ target) :
    (congestionStep none inflight target event_time dur).1 = none := by
  simp [congestionStep, h]

-- New timer deadline ≥ event_time.
theorem congestion_new_timer_ge_now
    (inflight target event_time dur : Nat) (h : inflight ≤ target) :
    ∃ t, (congestionStep none inflight target event_time dur).1 = some t ∧
         t ≥ event_time := by
  exact ⟨event_time + dur,
         congestion_sets_timer_when_inflight_ok inflight target event_time dur h,
         Nat.le_add_right _ _⟩

-- ---------------------------------------------------------------------------
-- §4  Lemmas about quiescenceStep
-- ---------------------------------------------------------------------------

theorem quiescence_none_exits (now : Nat) :
    quiescenceStep none now = true := by
  simp [quiescenceStep]

theorem quiescence_expired_exits (t now : Nat) (h : now > t) :
    quiescenceStep (some t) now = true := by
  simp [quiescenceStep, h]

theorem quiescence_not_expired_stays (t now : Nat) (h : ¬ now > t) :
    quiescenceStep (some t) now = false := by
  simp [quiescenceStep, h]

-- Iff: quiescenceStep exits iff None or expired.
theorem quiescence_exit_iff (exit_time : ExitTime) (now : Nat) :
    quiescenceStep exit_time now = true ↔
      (exit_time = none ∨ ∃ t, exit_time = some t ∧ now > t) := by
  match exit_time with
  | none   => simp [quiescenceStep]
  | some t =>
    by_cases h : now > t
    · simp [quiescenceStep, h]
    · simp [quiescenceStep, h]

-- quiescenceStep is always true or false (totality witness).
theorem quiescence_always_resolves (exit_time : ExitTime) (now : Nat) :
    quiescenceStep exit_time now = true ∨
    quiescenceStep exit_time now = false := by
  cases quiescenceStep exit_time now
  · exact Or.inr rfl
  · exact Or.inl rfl

-- ---------------------------------------------------------------------------
-- §5  Cross-cutting properties
-- ---------------------------------------------------------------------------

-- Quiescence exits from None; congestion from None never exits.
theorem combined_exit_conditions_disjoint
    (inflight target event_time dur now : Nat) :
    quiescenceStep none now = true ∧
    (congestionStep none inflight target event_time dur).2 = false := by
  refine ⟨quiescence_none_exits now, ?_⟩
  simp [congestionStep]; split <;> rfl

-- exit_time is monotone: Some stays Some through congestionStep.
theorem exit_time_monotone
    (exit_time : ExitTime) (inflight target event_time dur : Nat)
    (h : exit_time ≠ none) :
    (congestionStep exit_time inflight target event_time dur).1 ≠ none := by
  match exit_time with
  | none   => exact absurd rfl h
  | some t =>
    rw [exitTimer_none_once_set_stays_set]
    simp

end FVSquad.BBR2ProbeRTTTimer
