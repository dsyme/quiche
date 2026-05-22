-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- Formal specification and proofs for the BBR2 ProbeBW cycle-phase state
-- machine in quiche/src/recovery/gcongestion/bbr2/probe_bw.rs.
--
-- Target: T78 — BBR2 ProbeBW abstract cycle-phase state machine
-- Source: quiche/src/recovery/gcongestion/bbr2/probe_bw.rs (L60–L445)
--         quiche/src/recovery/gcongestion/bbr2/mode.rs   (L48–56)
-- Phase: 5 — Proofs complete, 0 sorry
--
-- ## What is modelled
--
-- The ProbeBW component of BBR2 cycles through five phases:
--
--   NotStarted  (initial sentinel — immediately transitions to Down)
--   Down        (drain inflight; wait for bdp or timeout)
--   Cruise      (steady-state; maintain bdp)
--   Refill      (re-fill pipe one round before probing)
--   Up          (probe for more bandwidth)
--
-- We model the *which-phase-can-follow-which* relationship as a decidable
-- boolean predicate `validTransition`, abstracting away timing, bytes-in-
-- flight, and model state.
--
-- ## What is NOT modelled
--
-- * Timing / duration conditions (has_phase_lasted, is_time_to_probe_bandwidth)
-- * Bytes-in-flight thresholds
-- * Network model state (inflight_hi, bandwidth_lo, etc.)
-- * The distinction between which sub-condition caused Down→Refill vs Down→Cruise

namespace FVSquad.BBR2ProbeBWCycle

-- ============================================================
-- §1  Phase enumeration
-- ============================================================

/-- The five phases of the BBR2 ProbeBW sub-state machine. -/
inductive CyclePhase where
  | NotStarted
  | Down
  | Cruise
  | Refill
  | Up
  deriving DecidableEq, Repr

open CyclePhase

-- ============================================================
-- §2  Valid transitions (abstract)
-- ============================================================

/--
  `validTransition p q` holds iff the ProbeBW state machine may move from
  phase `p` to phase `q` in a single update step.

  Derived from probe_bw.rs:
    NotStarted → Down    (enter_probe_down called from start_probe, L83–86)
    Down       → Down    (stay in Down when bdp/timeout conditions not met)
    Down       → Refill  (is_time_to_probe_bandwidth, or risky+non-high, L303/319)
    Down       → Cruise  (has_stayed_long_enough, or bytes_in_flight < bdp, L327/343)
    Cruise     → Cruise  (stay if not is_time_to_probe_bandwidth)
    Cruise     → Refill  (is_time_to_probe_bandwidth, L362)
    Refill     → Refill  (stay until end_of_round_trip)
    Refill     → Up      (end_of_round_trip after ≥1 round, L376–381)
    Up         → Up      (stay while not risky/queuing/probed_too_high)
    Up         → Down    (enter_probe_down on risky/queuing/probed_too_high, L394/439)
-/
def validTransition : CyclePhase → CyclePhase → Bool
  | NotStarted, Down   => true
  | Down,       Down   => true
  | Down,       Refill => true
  | Down,       Cruise => true
  | Cruise,     Cruise => true
  | Cruise,     Refill => true
  | Refill,     Refill => true
  | Refill,     Up     => true
  | Up,         Up     => true
  | Up,         Down   => true
  | _,          _      => false

-- ============================================================
-- §3  Steady phases (phases that validly self-loop)
-- ============================================================

/-- A phase is *steady* if it can persist across update steps. -/
def isSteady (p : CyclePhase) : Bool :=
  validTransition p p

theorem down_steady   : isSteady Down   = true := by decide
theorem cruise_steady : isSteady Cruise = true := by decide
theorem refill_steady : isSteady Refill = true := by decide
theorem up_steady     : isSteady Up     = true := by decide

theorem notStarted_not_steady : isSteady NotStarted = false := by decide

-- ============================================================
-- §4  Which phases each phase can reach in one step
-- ============================================================

/-- Successors of Down: Down, Refill, Cruise (never Up or NotStarted). -/
theorem down_successors (q : CyclePhase) :
    validTransition Down q = true ↔
      q = Down ∨ q = Refill ∨ q = Cruise := by
  cases q <;> decide

/-- Successors of Cruise: Cruise, Refill (never Down, Up, or NotStarted). -/
theorem cruise_successors (q : CyclePhase) :
    validTransition Cruise q = true ↔
      q = Cruise ∨ q = Refill := by
  cases q <;> decide

/-- Successors of Refill: Refill, Up (never Down, Cruise, or NotStarted). -/
theorem refill_successors (q : CyclePhase) :
    validTransition Refill q = true ↔
      q = Refill ∨ q = Up := by
  cases q <;> decide

/-- Successors of Up: Up, Down (never Cruise, Refill, or NotStarted). -/
theorem up_successors (q : CyclePhase) :
    validTransition Up q = true ↔
      q = Up ∨ q = Down := by
  cases q <;> decide

/-- NotStarted has exactly one successor: Down. -/
theorem notStarted_successor (q : CyclePhase) :
    validTransition NotStarted q = true ↔ q = Down := by
  cases q <;> decide

/-- NotStarted has no predecessors among steady phases. -/
theorem notStarted_no_predecessor (p : CyclePhase) (h : isSteady p = true) :
    validTransition p NotStarted = false := by
  cases p <;> simp_all [isSteady, validTransition]

-- ============================================================
-- §5  Phase ordering in the probe cycle
-- ============================================================

/-- Numeric level in the probe cycle: Down < Cruise < Refill < Up.
    NotStarted is assigned level 0 (immediately leaves). -/
def phaseLevel : CyclePhase → Nat
  | NotStarted => 0
  | Down       => 1
  | Cruise     => 2
  | Refill     => 3
  | Up         => 4

/--
  Non-self-loop transitions always change the phase level.
-/
theorem non_loop_changes_level (p q : CyclePhase)
    (htrans : validTransition p q = true)
    (hneq   : p ≠ q) :
    phaseLevel p ≠ phaseLevel q := by
  cases p <;> cases q <;> simp_all [validTransition, phaseLevel]

/-- Down never moves to Up in one step (must go through Refill). -/
theorem down_not_to_up : validTransition Down Up = false := by decide

/-- Cruise never moves to Up in one step (must go through Refill). -/
theorem cruise_not_to_up : validTransition Cruise Up = false := by decide

/-- Cruise never moves to Down (cruise is upstream from down in the cycle). -/
theorem cruise_not_to_down : validTransition Cruise Down = false := by decide

/-- Refill never moves to Down (would skip Up). -/
theorem refill_not_to_down : validTransition Refill Down = false := by decide

/-- Refill never moves to Cruise (probe has started — no going back). -/
theorem refill_not_to_cruise : validTransition Refill Cruise = false := by decide

/-- Up never moves to Cruise or Refill (must drain via Down first). -/
theorem up_not_to_cruise : validTransition Up Cruise = false := by decide
theorem up_not_to_refill : validTransition Up Refill = false := by decide

-- ============================================================
-- §6  Reachability (n-step transitive closure)
-- ============================================================

/-- `reachable n p q`: q is reachable from p in exactly n valid steps. -/
def reachable : Nat → CyclePhase → CyclePhase → Bool
  | 0,     p, q => p == q
  | n + 1, p, q =>
    [NotStarted, Down, Cruise, Refill, Up].any fun r =>
      reachable n p r && validTransition r q

/-- Reflexivity: every phase is reachable from itself in 0 steps. -/
theorem reachable_refl (p : CyclePhase) : reachable 0 p p = true := by
  cases p <;> decide

/-- From Down, Refill is reachable in 1 step. -/
theorem down_reaches_refill_1 : reachable 1 Down Refill = true := by decide

/-- From Down, Up is reachable in 2 steps (Down→Refill→Up). -/
theorem down_reaches_up_2 : reachable 2 Down Up = true := by decide

/-- From Cruise, Up is reachable in 2 steps (Cruise→Refill→Up). -/
theorem cruise_reaches_up_2 : reachable 2 Cruise Up = true := by decide

/-- From Refill, Up is reachable in 1 step. -/
theorem refill_reaches_up_1 : reachable 1 Refill Up = true := by decide

/-- From Up, Down is reachable in 1 step. -/
theorem up_reaches_down_1 : reachable 1 Up Down = true := by decide

/-- From Up, the full cycle completes and Up is reachable again in 4 steps. -/
theorem up_full_cycle_4 : reachable 4 Up Up = true := by decide

/-- From Down, the cycle Down→Refill→Up→Down completes in 3 steps. -/
theorem down_cycle_3 : reachable 3 Down Down = true := by decide

/-- From any steady phase, every other steady phase is eventually reachable
    (within 4 steps), confirming the cycle is strongly connected. -/
theorem cycle_strongly_connected (p q : CyclePhase)
    (hp : isSteady p = true) (hq : isSteady q = true) :
    reachable 4 p q = true := by
  cases p <;> cases q <;> simp_all [isSteady, reachable, validTransition]

-- ============================================================
-- §7  isProbing predicate
-- ============================================================

/-- A phase is *probing* (actively sending above the estimated bdp) iff it is
    Refill or Up.  Corresponds to `ProbeBW::is_probing_for_bandwidth` (L180–183). -/
def isProbing (p : CyclePhase) : Bool :=
  p == Refill || p == Up

theorem probing_iff_refill_or_up (p : CyclePhase) :
    isProbing p = true ↔ p = Refill ∨ p = Up := by
  cases p <;> decide

/-- Down and Cruise are never probing. -/
theorem down_not_probing   : isProbing Down   = false := by decide
theorem cruise_not_probing : isProbing Cruise = false := by decide

/-- If we are probing, the next step either continues probing or enters Down. -/
theorem probing_successor_options (p q : CyclePhase)
    (hprobe : isProbing p = true) (htrans : validTransition p q = true) :
    isProbing q = true ∨ q = Down := by
  cases p <;> cases q <;> simp_all [isProbing, validTransition]

end FVSquad.BBR2ProbeBWCycle
