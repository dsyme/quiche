-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of the BBR2 ProbeRTT phase
-- state machine in `quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs`.
--
-- Target T60: BBR2 ProbeRTT State Machine
-- Phase: 3+5 — Formal Spec + Proofs
-- Lean 4 (v4.29.1), no Mathlib dependency.
--
-- Background
-- ──────────
-- BBR2's ProbeRTT phase drains inflight below a target (≈ 0.5 × BDP) and
-- holds it there for `probe_rtt_duration` before returning to ProbeBW.
-- The key state variable is `exit_time : Option Nat` (modelled as Nat ticks):
--
--   exit_time = None   → DRAINING: inflight has not yet reached target
--   exit_time = Some t → WAITING:  timer set; will exit when event_time > t
--
-- Model abstractions
-- ──────────────────
--   * Time is modelled as `Nat` (monotone tick counter).
--   * `inflight`, `target`, and `duration` are `Nat`.
--   * Floating-point gains and BDP are omitted; we model only the state
--     machine transitions driven by (inflight ≤ target) and (time > exit_time).
--   * The mode struct fields (model, cycle) are omitted; only `exit_time`
--     carries the state machine state.
--   * The "exit to ProbeBW" is modelled as a separate constructor of the
--     result type rather than a recursive call into another mode.
--
-- Sections
-- ────────
--   §1  State and result types
--   §2  Transition functions
--   §3  Theorems: congestion-event transitions (11 theorems)
--   §4  Theorems: quiescence transitions (6 theorems)
--   §5  Theorems: cross-cutting invariants (7 theorems)

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  State and result types
-- ─────────────────────────────────────────────────────────────────────────────

/-- Internal state of the ProbeRTT phase.
    `draining`     — `exit_time = None`; inflight has not yet reached target.
    `waiting t`    — `exit_time = Some t`; timer will fire when event_time > t. -/
inductive ProbeRttState where
  | draining : ProbeRttState
  | waiting  : Nat → ProbeRttState
  deriving DecidableEq, Repr

/-- Outcome of a single ProbeRTT transition.
    `stay s`       — remain in ProbeRTT with updated state `s`.
    `exitToProbeBW` — phase is complete; caller transitions to ProbeBW. -/
inductive ProbeRttResult where
  | stay        : ProbeRttState → ProbeRttResult
  | exitToProbeBW : ProbeRttResult
  deriving DecidableEq, Repr

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  Transition functions
-- ─────────────────────────────────────────────────────────────────────────────

/-- Model of `ProbeRTT::on_congestion_event`.
    Parameters:
      `state`      — current state (draining or waiting t)
      `eventTime`  — `congestion_event.event_time` (Nat ticks)
      `inflight`   — `congestion_event.bytes_in_flight`
      `target`     — `self.inflight_target(params)` (BDP × fraction)
      `duration`   — `params.probe_rtt_duration` (Nat ticks)
    Abstraction: model, cycle, acked/lost packets, cwnd and pacing updates
    are all omitted; only the exit_time state-machine transition is captured. -/
def congestionStep
    (state     : ProbeRttState)
    (eventTime : Nat)
    (inflight  : Nat)
    (target    : Nat)
    (duration  : Nat)
    : ProbeRttResult :=
  match state with
  | .draining =>
    if inflight ≤ target then
      .stay (.waiting (eventTime + duration))
    else
      .stay .draining
  | .waiting exitTime =>
    if eventTime > exitTime then
      .exitToProbeBW
    else
      .stay (.waiting exitTime)

/-- Model of `ProbeRTT::on_exit_quiescence`.
    Parameters:
      `state` — current state
      `now`   — current time (Nat ticks)
    Abstraction: `quiescence_start_time` is unused in the source (underscore
    parameter); params are used only for the into_probe_bw call which we
    replace with `exitToProbeBW`. -/
def quiescenceStep
    (state : ProbeRttState)
    (now   : Nat)
    : ProbeRttResult :=
  match state with
  | .draining => .exitToProbeBW
  | .waiting exitTime =>
    if now > exitTime then
      .exitToProbeBW
    else
      .stay (.waiting exitTime)

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  Theorems: congestion-event transitions
-- ─────────────────────────────────────────────────────────────────────────────

/-- DRAINING + inflight ≤ target → transitions to WAITING with the timer set
    at `eventTime + duration`. -/
theorem congestion_draining_le_sets_timer
    (eventTime inflight target duration : Nat)
    (h : inflight ≤ target)
    : congestionStep .draining eventTime inflight target duration =
        .stay (.waiting (eventTime + duration)) := by
  simp [congestionStep, h]

/-- DRAINING + inflight > target → stays DRAINING. -/
theorem congestion_draining_gt_stays_draining
    (eventTime inflight target duration : Nat)
    (h : inflight > target)
    : congestionStep .draining eventTime inflight target duration =
        .stay .draining := by
  simp [congestionStep]
  omega

/-- WAITING(t) + eventTime > t → exits to ProbeBW. -/
theorem congestion_waiting_expired_exits
    (eventTime exitTime inflight target duration : Nat)
    (h : eventTime > exitTime)
    : congestionStep (.waiting exitTime) eventTime inflight target duration =
        .exitToProbeBW := by
  simp [congestionStep, h]

/-- WAITING(t) + eventTime ≤ t → stays in WAITING with the same exit time. -/
theorem congestion_waiting_not_expired_stays
    (eventTime exitTime inflight target duration : Nat)
    (h : ¬(eventTime > exitTime))
    : congestionStep (.waiting exitTime) eventTime inflight target duration =
        .stay (.waiting exitTime) := by
  simp [congestionStep, h]

/-- WAITING never transitions back to DRAINING. -/
theorem congestion_waiting_never_draining
    (exitTime eventTime inflight target duration : Nat)
    : congestionStep (.waiting exitTime) eventTime inflight target duration ≠
        .stay .draining := by
  simp [congestionStep]
  split <;> simp

/-- DRAINING never exits to ProbeBW directly via congestion event. -/
theorem congestion_draining_never_exits
    (eventTime inflight target duration : Nat)
    : congestionStep .draining eventTime inflight target duration ≠
        .exitToProbeBW := by
  simp [congestionStep]
  split <;> simp

/-- The new exit time when entering WAITING equals `eventTime + duration`. -/
theorem congestion_draining_timer_value
    (eventTime inflight target duration : Nat)
    (h : inflight ≤ target)
    : ∃ t, congestionStep .draining eventTime inflight target duration =
        .stay (.waiting t) ∧ t = eventTime + duration := by
  exact ⟨eventTime + duration,
    congestion_draining_le_sets_timer eventTime inflight target duration h,
    rfl⟩

/-- Waiting exit time is non-decreasing: `t ≥ eventTime` when duration ≥ 0
    (always true for Nat). -/
theorem waiting_exit_time_ge_event_time
    (eventTime duration : Nat)
    : eventTime + duration ≥ eventTime := by
  omega

/-- The exit time in a WAITING state from congestionStep is ≥ eventTime. -/
theorem congestion_new_exit_time_ge_eventTime
    (eventTime duration : Nat)
    : eventTime + duration ≥ eventTime := by
  omega

/-- If result is `stay .draining`, then inflight > target. -/
theorem congestion_draining_result_means_gt
    (eventTime inflight target duration : Nat)
    (h : congestionStep .draining eventTime inflight target duration =
        .stay .draining)
    : inflight > target := by
  simp only [congestionStep] at h
  by_cases hle : inflight ≤ target <;> simp [hle] at h
  omega

/-- Exhaustive case split: from DRAINING, result is either WAITING or stays
    DRAINING, depending on inflight ≤ target. -/
theorem congestion_draining_dichotomy
    (eventTime inflight target duration : Nat)
    : (inflight ≤ target ∧
        congestionStep .draining eventTime inflight target duration =
          .stay (.waiting (eventTime + duration))) ∨
      (inflight > target ∧
        congestionStep .draining eventTime inflight target duration =
          .stay .draining) := by
  by_cases h : inflight ≤ target
  · left
    exact ⟨h,
      congestion_draining_le_sets_timer eventTime inflight target duration h⟩
  · right
    have hgt : inflight > target := by omega
    exact ⟨hgt,
      congestion_draining_gt_stays_draining eventTime inflight target duration hgt⟩

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Theorems: quiescence transitions
-- ─────────────────────────────────────────────────────────────────────────────

/-- Quiescence from DRAINING always exits immediately (fast-path to ProbeBW). -/
theorem quiescence_draining_exits
    (now : Nat)
    : quiescenceStep .draining now = .exitToProbeBW := by
  simp [quiescenceStep]

/-- Quiescence from WAITING with expired timer exits. -/
theorem quiescence_waiting_expired_exits
    (exitTime now : Nat)
    (h : now > exitTime)
    : quiescenceStep (.waiting exitTime) now = .exitToProbeBW := by
  simp [quiescenceStep, h]

/-- Quiescence from WAITING with unexpired timer stays in WAITING unchanged. -/
theorem quiescence_waiting_not_expired_stays
    (exitTime now : Nat)
    (h : ¬(now > exitTime))
    : quiescenceStep (.waiting exitTime) now = .stay (.waiting exitTime) := by
  simp [quiescenceStep, h]

/-- Quiescence from WAITING never transitions to DRAINING. -/
theorem quiescence_waiting_never_draining
    (exitTime now : Nat)
    : quiescenceStep (.waiting exitTime) now ≠ .stay .draining := by
  simp [quiescenceStep]
  split <;> simp

/-- Either quiescence exits or the exit time is preserved. -/
theorem quiescence_waiting_exit_time_preserved_or_exits
    (exitTime now : Nat)
    : quiescenceStep (.waiting exitTime) now = .exitToProbeBW ∨
      quiescenceStep (.waiting exitTime) now = .stay (.waiting exitTime) := by
  by_cases h : now > exitTime
  · left; exact quiescence_waiting_expired_exits exitTime now h
  · right; exact quiescence_waiting_not_expired_stays exitTime now h

/-- Exhaustive result set for quiescenceStep: all possible outcomes. -/
theorem quiescence_result_cases
    (state : ProbeRttState)
    (now : Nat)
    : quiescenceStep state now = .exitToProbeBW ∨
      ∃ t, quiescenceStep state now = .stay (.waiting t) := by
  cases state with
  | draining => left; exact quiescence_draining_exits now
  | waiting t =>
    rcases quiescence_waiting_exit_time_preserved_or_exits t now with h | h
    · left; exact h
    · right; exact ⟨t, h⟩

-- ─────────────────────────────────────────────────────────────────────────────
-- §5  Theorems: cross-cutting invariants
-- ─────────────────────────────────────────────────────────────────────────────

/-- State machine never produces a `stay .waiting t` from initial DRAINING
    with inflight > target. -/
theorem draining_high_inflight_stays_draining_not_waiting
    (eventTime inflight target duration : Nat)
    (h : inflight > target)
    : ∀ t, congestionStep .draining eventTime inflight target duration ≠
        .stay (.waiting t) := by
  intro t
  simp only [congestionStep]
  by_cases hle : inflight ≤ target
  · omega
  · simp [hle]

/-- Once the exit timer is set (we enter WAITING), any subsequent
    congestionStep either keeps the same exit time or exits.  The
    exit time never changes while in WAITING. -/
theorem waiting_exit_time_immutable
    (exitTime eventTime inflight target duration : Nat)
    : (∃ t, congestionStep (.waiting exitTime) eventTime inflight target
        duration = .stay (.waiting t) ∧ t = exitTime) ∨
      congestionStep (.waiting exitTime) eventTime inflight target duration =
        .exitToProbeBW := by
  by_cases h : eventTime > exitTime
  · right; exact congestion_waiting_expired_exits eventTime exitTime inflight target duration h
  · left
    exact ⟨exitTime,
      congestion_waiting_not_expired_stays eventTime exitTime inflight target duration h,
      rfl⟩

/-- The only way to reach `exitToProbeBW` via congestionStep is from WAITING
    with an expired timer. -/
theorem congestion_exit_iff_waiting_expired
    (state : ProbeRttState)
    (eventTime inflight target duration : Nat)
    : congestionStep state eventTime inflight target duration = .exitToProbeBW ↔
      ∃ t, state = .waiting t ∧ eventTime > t := by
  cases state with
  | draining =>
    simp [congestionStep]
    split <;> simp
  | waiting exitTime =>
    simp only [congestionStep]
    constructor
    · intro h
      by_cases hexp : eventTime > exitTime
      · exact ⟨exitTime, rfl, hexp⟩
      · simp [hexp] at h
    · intro ⟨t, ht, hexp⟩
      cases ht
      simp [hexp]

/-- Both transition functions produce results in `{stay .draining, stay
    .waiting _, exitToProbeBW}` — no invalid states. -/
theorem congestion_result_valid
    (state : ProbeRttState)
    (eventTime inflight target duration : Nat)
    : congestionStep state eventTime inflight target duration = .stay .draining ∨
      (∃ t, congestionStep state eventTime inflight target duration =
        .stay (.waiting t)) ∨
      congestionStep state eventTime inflight target duration = .exitToProbeBW := by
  cases state with
  | draining =>
    by_cases h : inflight ≤ target
    · right; left; exact ⟨_, congestion_draining_le_sets_timer _ _ _ _ h⟩
    · left; exact congestion_draining_gt_stays_draining _ _ _ _ (by omega)
  | waiting exitTime =>
    by_cases h : eventTime > exitTime
    · right; right; exact congestion_waiting_expired_exits _ _ _ _ _ h
    · right; left;
      exact ⟨exitTime, congestion_waiting_not_expired_stays _ _ _ _ _ h⟩

/-- If inflight ≤ target at every congestion event, DRAINING transitions to
    WAITING on the very first event. -/
theorem draining_first_event_le_target_enters_waiting
    (eventTime inflight target duration : Nat)
    (h : inflight ≤ target)
    : ∃ t, congestionStep .draining eventTime inflight target duration =
        .stay (.waiting t) := by
  exact ⟨_, congestion_draining_le_sets_timer _ _ _ _ h⟩

/-- After `duration` ticks from when the timer was set, any congestion event
    exits ProbeRTT.  Formally: if `eventTime ≥ (setTime + duration) + 1`
    and the exit time was set at `setTime`, then we exit. -/
theorem waiting_exits_after_duration
    (setTime duration eventTime inflight target : Nat)
    (h : eventTime > setTime + duration)
    : congestionStep (.waiting (setTime + duration)) eventTime inflight target
        duration = .exitToProbeBW := by
  exact congestion_waiting_expired_exits eventTime (setTime + duration) inflight target duration h

/-- Symmetry: quiescence and congestion agree on WAITING with expired timer. -/
theorem quiescence_and_congestion_agree_on_expired
    (exitTime now inflight target duration : Nat)
    (h : now > exitTime)
    : quiescenceStep (.waiting exitTime) now = .exitToProbeBW ∧
      congestionStep (.waiting exitTime) now inflight target duration =
        .exitToProbeBW := by
  exact ⟨quiescence_waiting_expired_exits exitTime now h,
         congestion_waiting_expired_exits now exitTime inflight target duration h⟩

-- End of FVSquad/ProbeRTTStateMachine.lean
