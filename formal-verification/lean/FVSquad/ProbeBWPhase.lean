-- Copyright (C) 2025, Cloudflare, Inc.
-- BSD-2-Clause licence (same as quiche)
--
-- 🔬 Lean Squad — formal specification of the BBR2 ProbeBW CyclePhase
-- pacing-gain and cwnd-gain assignments.
--
-- Target T57: BBR2 ProbeBW phase cycle ordering
-- Source: quiche/src/recovery/gcongestion/bbr2/mode.rs (L49–L75)
--         quiche/src/recovery/gcongestion/bbr2.rs (L291–L300)
-- Phase: 5 — Implementation + Proofs
-- Lean 4.29.x, no Mathlib dependency.
--
-- Models:
--   CyclePhase     — BBR2 ProbeBW probe cycle phases
--   pacingGain     — pacing-rate gain multiplier (as rational × 100 to avoid Float)
--   cwndGain       — congestion-window gain multiplier (× 100)
--
-- Omitted / abstracted:
--   * Params struct and Option<f32> overrides — we model the default Params
--     values only; override paths require floating-point arithmetic
--   * f32 arithmetic — all gains are represented as × 100 integers
--   * Phase transition logic (enter_probe_down/up/cruise/refill) — the state
--     machine is modelled only at the level of per-phase gain assignments
--
-- Default param values (from bbr2.rs L291-L300):
--   probe_bw_probe_up_pacing_gain   = 1.25  → 125
--   probe_bw_probe_down_pacing_gain = 0.90  → 90
--   probe_bw_default_pacing_gain    = 1.00  → 100
--   probe_bw_up_cwnd_gain           = 2.25  → 225
--   probe_bw_cwnd_gain              = 2.00  → 200
--
-- Theorems (12 total, 0 sorry):
--   pacingGain_up, pacingGain_down, pacingGain_cruise, pacingGain_refill,
--   pacingGain_notStarted,
--   cwndGain_up, cwndGain_down, cwndGain_cruise, cwndGain_refill,
--   cwndGain_notStarted,
--   pacingGain_gt_100_iff_up, cwndGain_gt_200_iff_up

inductive CyclePhase where
  | notStarted : CyclePhase
  | up         : CyclePhase
  | down       : CyclePhase
  | cruise     : CyclePhase
  | refill     : CyclePhase
  deriving DecidableEq, Repr

/-- Pacing-gain × 100 for default Params (int approximation of f32). -/
def pacingGain (p : CyclePhase) : Nat :=
  match p with
  | .up         => 125  -- 1.25
  | .down       => 90   -- 0.90
  | _           => 100  -- 1.00  (notStarted / cruise / refill)

/-- Congestion-window gain × 100 for default Params. -/
def cwndGain (p : CyclePhase) : Nat :=
  match p with
  | .up  => 225  -- 2.25
  | _    => 200  -- 2.00

-- ---------------------------------------------------------------------------
-- Pacing-gain per-phase lemmas
-- ---------------------------------------------------------------------------

theorem pacingGain_up : pacingGain .up = 125 := rfl
theorem pacingGain_down : pacingGain .down = 90 := rfl
theorem pacingGain_cruise : pacingGain .cruise = 100 := rfl
theorem pacingGain_refill : pacingGain .refill = 100 := rfl
theorem pacingGain_notStarted : pacingGain .notStarted = 100 := rfl

-- ---------------------------------------------------------------------------
-- cwnd-gain per-phase lemmas
-- ---------------------------------------------------------------------------

theorem cwndGain_up : cwndGain .up = 225 := rfl
theorem cwndGain_down : cwndGain .down = 200 := rfl
theorem cwndGain_cruise : cwndGain .cruise = 200 := rfl
theorem cwndGain_refill : cwndGain .refill = 200 := rfl
theorem cwndGain_notStarted : cwndGain .notStarted = 200 := rfl

-- ---------------------------------------------------------------------------
-- Structural / discriminator properties
-- ---------------------------------------------------------------------------

/-- Only the Up phase has an aggressive pacing gain (> 100). -/
theorem pacingGain_gt_100_iff_up (p : CyclePhase) :
    pacingGain p > 100 ↔ p = .up := by
  cases p <;> simp [pacingGain]

/-- Only the Up phase has an elevated cwnd gain (> 200). -/
theorem cwndGain_gt_200_iff_up (p : CyclePhase) :
    cwndGain p > 200 ↔ p = .up := by
  cases p <;> simp [cwndGain]

-- ---------------------------------------------------------------------------
-- Examples (spot-check against mode.rs L303–L316 test values)
-- ---------------------------------------------------------------------------

#eval pacingGain .up      -- 125
#eval pacingGain .down    -- 90
#eval pacingGain .cruise  -- 100
#eval cwndGain .up        -- 225
#eval cwndGain .down      -- 200
