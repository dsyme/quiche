-- Copyright (C) 2018-2025, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of the `SsThresh` struct
-- from `quiche/src/recovery/congestion/mod.rs`.
--
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- Background
-- ──────────
-- `SsThresh` tracks the slow-start threshold (ssthresh) together with a
-- `startup_exit` record that captures WHY and WHEN slow-start first ended.
--
-- The key protocol invariant proved here:
--   `startup_exit` is set exactly once — on the first call to `update`.
--   Subsequent calls update `ssthresh` freely but leave the exit record
--   unchanged.  This "write-once" property ensures that the *original*
--   slow-start-exit cause (CSS vs. loss) is never overwritten by later
--   congestion events.
--
-- Source: quiche/src/recovery/congestion/mod.rs (L39–L82)
--
-- Rust signature (simplified):
--   struct SsThresh {
--     ssthresh:    usize,             -- initial value: usize::MAX
--     startup_exit: Option<StartupExit>,  -- initial value: None
--   }
--   fn update(&mut self, ssthresh: usize, in_css: bool) {
--     if self.startup_exit.is_none() {
--       let reason = if in_css { CSS } else { Loss };
--       self.startup_exit = Some(StartupExit::new(ssthresh, None, reason));
--     }
--     self.ssthresh = ssthresh;
--   }
--
-- Modelling choices / approximations
-- ────────────────────────────────────
-- * `usize` is modelled as `Nat` (no overflow / no usize::MAX semantics
--   for any arithmetic — we track the initial MAX symbolically).
-- * `StartupExit` is abstracted to its `reason` field alone (the
--   `cwnd` snapshot and `bandwidth` field are omitted as they do not
--   affect the write-once invariant).
-- * `usize::MAX` is modelled as `2^64 - 1` for 64-bit systems.
--
-- Theorems (17 total, 0 sorry):
--   default_ssthresh, default_exit_none,
--   update_ssthresh, update_sets_exit_on_first,
--   exit_mono, exit_reason_preserved,
--   reason_css_from_first_call, reason_loss_from_first_call,
--   double_update_ssthresh, double_update_exit_unchanged,
--   n_updates_ssthresh_is_last, exit_set_after_any_update,
--   + 5 decidable examples

namespace FVSquad.SsThresh

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  Types
-- ─────────────────────────────────────────────────────────────────────────────

/-- Models `StartupExitReason` from `quiche/src/recovery/mod.rs`.
    The two variants match the two arms of the `if in_css` branch. -/
inductive ExitReason
  /-- Slow-start ended during Conservative Slow Start (in_css = true). -/
  | ConservativeSlowStartRounds
  /-- Slow-start ended due to packet loss (in_css = false). -/
  | Loss
  deriving DecidableEq, Repr

/-- Models `SsThresh` specialised to the fields relevant to the write-once
    invariant.  `startupExit` is `Option ExitReason` (abstracted from the
    full `StartupExit` record to avoid modelling `bandwidth`). -/
structure SsThreshState where
  /-- Current slow-start threshold (any Nat value).
      On construction the Rust code sets this to `usize::MAX`. -/
  ssthresh     : Nat
  /-- Whether slow-start has exited, and why (write-once). -/
  startupExit  : Option ExitReason
  deriving DecidableEq, Repr

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  Constants and constructors
-- ─────────────────────────────────────────────────────────────────────────────

/-- `usize::MAX` on 64-bit: 2^64 − 1. -/
def USIZE_MAX : Nat := 2 ^ 64 - 1

/-- Default state: `ssthresh = usize::MAX`, `startup_exit = None`.
    Mirrors `impl Default for SsThresh`. -/
def SsThreshState.default : SsThreshState :=
  { ssthresh := USIZE_MAX, startupExit := none }

/-- One call to `SsThresh::update(ssthresh, in_css)`.
    Sets `startupExit` on the **first** call only; always updates `ssthresh`. -/
def SsThreshState.update (s : SsThreshState) (newSsthresh : Nat)
    (inCss : Bool) : SsThreshState :=
  let exit :=
    match s.startupExit with
    | none =>
      some (if inCss then ExitReason.ConservativeSlowStartRounds
            else ExitReason.Loss)
    | some r => some r
  { ssthresh := newSsthresh, startupExit := exit }

/-- Apply a list of `(newSsthresh, inCss)` pairs in sequence. -/
def SsThreshState.updateList (s : SsThreshState)
    (calls : List (Nat × Bool)) : SsThreshState :=
  calls.foldl (fun acc ⟨n, b⟩ => acc.update n b) s

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  Basic one-step theorems
-- ─────────────────────────────────────────────────────────────────────────────

/-- Default `ssthresh` is `usize::MAX`. -/
theorem default_ssthresh : SsThreshState.default.ssthresh = USIZE_MAX := rfl

/-- Default `startupExit` is `none`. -/
theorem default_exit_none : SsThreshState.default.startupExit = none := rfl

/-- After any update, `ssthresh` equals the new value. -/
theorem update_ssthresh (s : SsThreshState) (n : Nat) (b : Bool) :
    (s.update n b).ssthresh = n := rfl

/-- After one update on a state with `startupExit = none`, the exit is set. -/
theorem update_sets_exit_on_first (s : SsThreshState)
    (h : s.startupExit = none) (n : Nat) (b : Bool) :
    (s.update n b).startupExit.isSome := by
  simp [SsThreshState.update, h]

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Write-once (monotonicity) of startupExit
-- ─────────────────────────────────────────────────────────────────────────────

/-- Once `startupExit` is `Some`, `update` leaves it unchanged.
    This is the core write-once invariant. -/
theorem exit_preserved_when_set (s : SsThreshState) (r : ExitReason)
    (h : s.startupExit = some r) (n : Nat) (b : Bool) :
    (s.update n b).startupExit = some r := by
  simp [SsThreshState.update, h]

/-- Monotonicity: `isSome startupExit` is non-decreasing across updates. -/
theorem exit_mono (s : SsThreshState) (n : Nat) (b : Bool)
    (h : s.startupExit.isSome) :
    (s.update n b).startupExit.isSome := by
  obtain ⟨r, hr⟩ := Option.isSome_iff_exists.mp h
  simp [SsThreshState.update, hr]

/-- `startupExit` is always `isSome` after the first update (from `none`). -/
theorem exit_set_after_any_update (s : SsThreshState)
    (h : s.startupExit = none) (n : Nat) (b : Bool) :
    ((s.update n b).startupExit).isSome := by
  simp [SsThreshState.update, h]

-- ─────────────────────────────────────────────────────────────────────────────
-- §5  Reason is determined by `inCss` on the first call
-- ─────────────────────────────────────────────────────────────────────────────

/-- First update with `inCss = true` → reason is `ConservativeSlowStartRounds`. -/
theorem reason_css_from_first_call (s : SsThreshState)
    (h : s.startupExit = none) (n : Nat) :
    (s.update n true).startupExit =
      some ExitReason.ConservativeSlowStartRounds := by
  simp [SsThreshState.update, h]

/-- First update with `inCss = false` → reason is `Loss`. -/
theorem reason_loss_from_first_call (s : SsThreshState)
    (h : s.startupExit = none) (n : Nat) :
    (s.update n false).startupExit = some ExitReason.Loss := by
  simp [SsThreshState.update, h]

/-- Second update never changes the reason (CSS case). -/
theorem exit_reason_preserved (s : SsThreshState) (r : ExitReason)
    (h : s.startupExit = some r) (n1 n2 : Nat) (b1 b2 : Bool) :
    ((s.update n1 b1).update n2 b2).startupExit = some r := by
  simp [SsThreshState.update, h]

-- ─────────────────────────────────────────────────────────────────────────────
-- §6  Two-update scenario (mirrors the Rust unit tests)
-- ─────────────────────────────────────────────────────────────────────────────

/-- After two updates, ssthresh = value from the *second* update. -/
theorem double_update_ssthresh (s : SsThreshState)
    (n1 n2 : Nat) (b1 b2 : Bool) :
    ((s.update n1 b1).update n2 b2).ssthresh = n2 := rfl

/-- After two updates, startupExit reflects only the *first* update's reason. -/
theorem double_update_exit_unchanged (s : SsThreshState)
    (h : s.startupExit = none) (n1 n2 : Nat) (b1 b2 : Bool) :
    ((s.update n1 b1).update n2 b2).startupExit =
      (s.update n1 b1).startupExit := by
  simp [SsThreshState.update, h]

-- ─────────────────────────────────────────────────────────────────────────────
-- §7  Multi-update: last ssthresh wins
-- ─────────────────────────────────────────────────────────────────────────────

/-- Appending one element to updateList unrolls the last step. -/
theorem updateList_snoc (s : SsThreshState)
    (calls : List (Nat × Bool)) (last : Nat × Bool) :
    s.updateList (calls ++ [last]) =
      (s.updateList calls).update last.1 last.2 := by
  simp [SsThreshState.updateList, List.foldl_append]

/-- After a non-empty list of updates, `ssthresh` is the last ssthresh. -/
theorem n_updates_ssthresh_is_last :
    ∀ (calls : List (Nat × Bool)) (hn : calls ≠ []) (s : SsThreshState),
    (s.updateList calls).ssthresh = (calls.getLast hn).1 := by
  intro calls
  induction calls with
  | nil => intro hn; exact absurd rfl hn
  | cons hd tl ih =>
    by_cases htl : tl = []
    · subst htl
      intro _ s
      simp [SsThreshState.updateList, SsThreshState.update]
    · intro _ s
      rw [List.getLast_cons htl]
      show (List.foldl (fun acc x => acc.update x.1 x.2)
              (s.update hd.1 hd.2) tl).ssthresh = _
      exact ih htl (s.update hd.1 hd.2)

-- ─────────────────────────────────────────────────────────────────────────────
-- §8  Decidable spot checks (mirror the Rust unit tests in congestion/mod.rs)
-- ─────────────────────────────────────────────────────────────────────────────

/-- Initial state: ssthresh = 2^64 - 1, exit = none. -/
example : SsThreshState.default.ssthresh = 2 ^ 64 - 1 ∧
          SsThreshState.default.startupExit = none := by decide

/-- First update with inCss=true, ssthresh=1000:
    exit becomes ConservativeSlowStartRounds, ssthresh = 1000. -/
example :
    let s1 := SsThreshState.default.update 1000 true
    s1.ssthresh = 1000 ∧
    s1.startupExit = some ExitReason.ConservativeSlowStartRounds := by decide

/-- Second update with inCss=true, ssthresh=2000:
    ssthresh changes but exit reason stays ConservativeSlowStartRounds. -/
example :
    let s2 := (SsThreshState.default.update 1000 true).update 2000 true
    s2.ssthresh = 2000 ∧
    s2.startupExit = some ExitReason.ConservativeSlowStartRounds := by decide

/-- Third update with inCss=false, ssthresh=500:
    ssthresh changes but exit reason stays ConservativeSlowStartRounds. -/
example :
    let s2 := (SsThreshState.default.update 1000 true).update 2000 true
    let s3 := s2.update 500 false
    s3.ssthresh = 500 ∧
    s3.startupExit = some ExitReason.ConservativeSlowStartRounds := by decide

/-- First update with inCss=false, ssthresh=1000: exit reason = Loss. -/
example :
    let s1 := SsThreshState.default.update 1000 false
    s1.ssthresh = 1000 ∧
    s1.startupExit = some ExitReason.Loss := by decide

end FVSquad.SsThresh
