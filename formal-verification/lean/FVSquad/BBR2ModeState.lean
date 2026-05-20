-- Copyright (C) 2024, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — T76: BBR2 Abstract Mode State Machine
--
-- Target T76: BBR2ModeState
-- Source: quiche/src/recovery/gcongestion/bbr2/mode.rs
--   Mode enum (lines 153–158)
--   startup.rs: into_drain (lines 160–186)
--   drain.rs:   on_congestion_event exit guard (lines 62–86)
-- Phase: 5 — Implementation + Proofs
-- Lean 4 (v4.29.1), no Mathlib dependency.
--
-- Models the abstract BBR2 four-mode state machine:
--   Startup → Drain → ProbeBW ↔ ProbeRTT
--
-- The key transitions modelled:
--   (T1) Startup  → Drain    when full_bandwidth_reached = true
--   (T2) Drain    → ProbeBW  when bytes_in_flight ≤ bdp0
--   (T3) ProbeBW  → ProbeRTT when probertt_conditions hold (abstracted as Bool)
--   (T4) ProbeRTT → ProbeBW  always (exit ProbeRTT → back to ProbeBW)
--
-- The model is intentionally coarse: it captures the *ordering* of mode
-- transitions (Startup precedes Drain; Drain precedes ProbeBW) and key
-- safety / liveness properties, not the full per-round event logic.
--
-- Approximations / omissions:
--   * Only the guard conditions are modelled; on_enter/on_leave side effects
--     (model updates, inflight_hi, etc.) are not captured.
--   * f32 pacing/cwnd gains inside each mode are not repeated here
--     (see BBR2DrainPhase.lean, BBR2Startup.lean, BBR2CyclePhaseGain.lean).
--   * Loss-triggered exit from Startup is not modelled; only bandwidth-plateau
--     and persistent-queue paths (both set full_bandwidth_reached).
--   * ProbeRTT → ProbeBW is modelled as unconditional (the actual guard is
--     min_rtt timer expiry, abstracted here as the `exit_probertt` Bool).
--   * Placeholder mode is omitted (it is an internal construction artefact).
--
-- Theorems (19 total, 0 sorry):
--   1.  step_startup_stays_when_not_ready
--   2.  step_startup_exits_when_ready
--   3.  step_drain_stays_when_not_ready
--   4.  step_drain_exits_when_ready
--   5.  step_probertt_always_exits
--   6.  step_probebw_stays_when_rtt_not_needed
--   7.  step_probebw_exits_to_probertt_when_needed
--   8.  startup_only_transitions_to_drain
--   9.  drain_only_transitions_to_probebw
--   10. probertt_only_transitions_to_probebw
--   11. step_idempotent_startup_stable
--   12. step_idempotent_drain_stable
--   13. step_idempotent_probebw_stable
--   14. startup_cannot_skip_drain
--   15. initial_mode_is_startup
--   16. mode_eq_decidable
--   17. startup_not_drain
--   18. startup_not_probebw
--   19. drain_not_probebw
--   19. probertt_not_drain

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  Mode enumeration
-- ─────────────────────────────────────────────────────────────────────────────

namespace FVSquad.BBR2ModeState

/-- The four BBRv2 modes.
    Source: `mode.rs` `Mode` enum (lines 153–158). -/
inductive Mode where
  | Startup  : Mode
  | Drain    : Mode
  | ProbeBW  : Mode
  | ProbeRTT : Mode
  deriving Repr, BEq, DecidableEq

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  Transition guard inputs
-- ─────────────────────────────────────────────────────────────────────────────

/-- Inputs consumed by the abstract single-step transition function. -/
structure ModeInput where
  /-- Startup exit guard: true when full_bandwidth_reached is set.
      Source: startup.rs `on_congestion_event` line 69 / line 124. -/
  full_bw_reached    : Bool
  /-- Drain exit guard: true when bytes_in_flight ≤ bdp0.
      Source: drain.rs `on_congestion_event` line 73–75. -/
  should_exit_drain  : Bool
  /-- ProbeRTT exit guard: true when min_rtt probe timer has expired and
      ProbeRTT conditions are satisfied.  Abstracted as an opaque Bool. -/
  exit_probertt      : Bool
  /-- ProbeBW → ProbeRTT guard: true when ProbeBW decides to enter ProbeRTT.
      Abstracted as an opaque Bool. -/
  enter_probertt     : Bool
  deriving Repr

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  Abstract single-step transition function
-- ─────────────────────────────────────────────────────────────────────────────

/-- Abstract single-step mode transition.
    Given the current mode and guard inputs, return the next mode. -/
def step (m : Mode) (i : ModeInput) : Mode :=
  match m with
  | Mode.Startup  =>
      if i.full_bw_reached then Mode.Drain else Mode.Startup
  | Mode.Drain    =>
      if i.should_exit_drain then Mode.ProbeBW else Mode.Drain
  | Mode.ProbeBW  =>
      if i.enter_probertt then Mode.ProbeRTT else Mode.ProbeBW
  | Mode.ProbeRTT =>
      if i.exit_probertt then Mode.ProbeBW else Mode.ProbeRTT

/-- The initial BBRv2 mode is Startup.
    Source: `Mode::startup` constructor (mode.rs line 169). -/
def initialMode : Mode := Mode.Startup

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Correctness theorems
-- ─────────────────────────────────────────────────────────────────────────────

-- §4.1  Per-mode transition theorems

/-- Startup stays in Startup when full_bw_reached is false. -/
theorem step_startup_stays_when_not_ready (i : ModeInput)
    (h : i.full_bw_reached = false) :
    step Mode.Startup i = Mode.Startup := by
  simp [step, h]

/-- Startup exits to Drain when full_bw_reached is true. -/
theorem step_startup_exits_when_ready (i : ModeInput)
    (h : i.full_bw_reached = true) :
    step Mode.Startup i = Mode.Drain := by
  simp [step, h]

/-- Drain stays in Drain when should_exit_drain is false. -/
theorem step_drain_stays_when_not_ready (i : ModeInput)
    (h : i.should_exit_drain = false) :
    step Mode.Drain i = Mode.Drain := by
  simp [step, h]

/-- Drain exits to ProbeBW when should_exit_drain is true. -/
theorem step_drain_exits_when_ready (i : ModeInput)
    (h : i.should_exit_drain = true) :
    step Mode.Drain i = Mode.ProbeBW := by
  simp [step, h]

/-- ProbeRTT always exits to ProbeBW when exit_probertt is true. -/
theorem step_probertt_always_exits (i : ModeInput)
    (h : i.exit_probertt = true) :
    step Mode.ProbeRTT i = Mode.ProbeBW := by
  simp [step, h]

/-- ProbeBW stays in ProbeBW when enter_probertt is false. -/
theorem step_probebw_stays_when_rtt_not_needed (i : ModeInput)
    (h : i.enter_probertt = false) :
    step Mode.ProbeBW i = Mode.ProbeBW := by
  simp [step, h]

/-- ProbeBW exits to ProbeRTT when enter_probertt is true. -/
theorem step_probebw_exits_to_probertt_when_needed (i : ModeInput)
    (h : i.enter_probertt = true) :
    step Mode.ProbeBW i = Mode.ProbeRTT := by
  simp [step, h]

-- §4.2  Safety: each mode can only transition to its allowed successor(s)

/-- Startup can only stay in Startup or move to Drain — never to
    ProbeBW or ProbeRTT directly. -/
theorem startup_only_transitions_to_drain (i : ModeInput) :
    step Mode.Startup i = Mode.Startup ∨ step Mode.Startup i = Mode.Drain := by
  simp only [step]
  by_cases h : i.full_bw_reached <;> simp [h]

/-- Drain can only stay in Drain or move to ProbeBW — never back to
    Startup or to ProbeRTT directly. -/
theorem drain_only_transitions_to_probebw (i : ModeInput) :
    step Mode.Drain i = Mode.Drain ∨ step Mode.Drain i = Mode.ProbeBW := by
  simp only [step]
  by_cases h : i.should_exit_drain <;> simp [h]

/-- ProbeRTT can only stay in ProbeRTT or return to ProbeBW. -/
theorem probertt_only_transitions_to_probebw (i : ModeInput) :
    step Mode.ProbeRTT i = Mode.ProbeRTT ∨ step Mode.ProbeRTT i = Mode.ProbeBW := by
  simp only [step]
  by_cases h : i.exit_probertt <;> simp [h]

-- §4.3  Ordering: Startup must precede Drain must precede ProbeBW

/-- Startup cannot skip Drain and go directly to ProbeBW.
    The step from Startup lands either in Startup or Drain, never ProbeBW. -/
theorem startup_cannot_skip_drain (i : ModeInput) :
    step Mode.Startup i ≠ Mode.ProbeBW := by
  simp only [step]
  by_cases h : i.full_bw_reached <;> simp [h]

-- §4.4  Stable-state (idempotent) theorems

/-- Startup is stable when full_bw_reached is false:
    repeated steps stay in Startup. -/
theorem step_idempotent_startup_stable (i : ModeInput)
    (h : i.full_bw_reached = false) :
    step (step Mode.Startup i) i = Mode.Startup := by
  simp [step, h]

/-- Drain is stable when should_exit_drain is false:
    repeated steps stay in Drain. -/
theorem step_idempotent_drain_stable (i : ModeInput)
    (h : i.should_exit_drain = false) :
    step (step Mode.Drain i) i = Mode.Drain := by
  simp [step, h]

/-- ProbeBW is stable when enter_probertt is false:
    repeated steps stay in ProbeBW. -/
theorem step_idempotent_probebw_stable (i : ModeInput)
    (h : i.enter_probertt = false) :
    step (step Mode.ProbeBW i) i = Mode.ProbeBW := by
  simp [step, h]

-- §4.5  Initial mode and mode-distinctness

/-- The initial mode is Startup. -/
theorem initial_mode_is_startup : initialMode = Mode.Startup := by
  rfl

/-- Mode equality is decidable (follows from DecidableEq instance). -/
example (m1 m2 : Mode) : Decidable (m1 = m2) := inferInstance

/-- Startup ≠ Drain. -/
theorem startup_not_drain : Mode.Startup ≠ Mode.Drain := by decide

/-- Startup ≠ ProbeBW. -/
theorem startup_not_probebw : Mode.Startup ≠ Mode.ProbeBW := by decide

/-- Drain ≠ ProbeBW. -/
theorem drain_not_probebw : Mode.Drain ≠ Mode.ProbeBW := by decide

/-- ProbeRTT ≠ Drain. -/
theorem probertt_not_drain : Mode.ProbeRTT ≠ Mode.Drain := by decide

end FVSquad.BBR2ModeState
