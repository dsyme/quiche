-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of Pacer.pacing_rate cap invariants.
--
-- Target: quiche/src/recovery/gcongestion/pacer.rs
-- Spec:   formal-verification/specs/pacer_pacing_rate_informal.md
-- Phase:  4/5 — Implementation + Proofs (T41, run 98)
-- Lean 4 (v4.30.0-rc2), no Mathlib dependency.
--
-- Models:
--   Bandwidth          — Nat (bits_per_second), re-used from Bandwidth.lean model
--   pacing_rate_model  — pure functional model of Pacer::pacing_rate
--
-- Excluded from model (documented in CORRESPONDENCE.md):
--   * BBRv2 internals  — sender_rate is an abstract Nat parameter
--   * RttStats         — collapsed into sender_rate parameter
--   * Mul<f32> cap     — floating-point burst cap (max_rate = cap * 1.25); not modelled
--   * bytes_in_flight  — collapsed into sender_rate parameter
--   * enabled field    — modelled as a Bool parameter
--
-- All proofs close with omega, simp, or cases.

namespace FVSquad.Pacer

-- ---------------------------------------------------------------------------
-- §1  Types
-- ---------------------------------------------------------------------------

-- §1b  Bandwidth type
-- BwNat = Nat (bandwidth in bytes per second, re-uses conceptual model from Bandwidth.lean)

-- ---------------------------------------------------------------------------
-- §2  Model
-- ---------------------------------------------------------------------------

/-- Pure functional model of `Pacer::pacing_rate`.
    - `sender_rate`   : the underlying BBRv2 pacing rate (Nat bps)
    - `max_pacing`    : optional cap (Some bps, or None)
    - `enabled`       : whether the pacer is active
    Returns the effective pacing rate after applying the optional cap. -/
def pacing_rate (sender_rate : Nat) (max_pacing : Option Nat)
    (enabled : Bool) : Nat :=
  match max_pacing, enabled with
  | some cap, true => min cap sender_rate
  | _,        _    => sender_rate

-- ---------------------------------------------------------------------------
-- §3  Key propositions
-- ---------------------------------------------------------------------------

-- ▸ When no cap is set, the result equals the sender rate.
theorem pacing_rate_no_cap (r : Nat) (en : Bool) :
    pacing_rate r none en = r := by
  simp [pacing_rate]

-- ▸ When disabled, the cap has no effect even if set.
theorem pacing_rate_disabled (r cap : Nat) :
    pacing_rate r (some cap) false = r := by
  simp [pacing_rate]

-- ▸ When enabled with a cap, the result is at most the cap.
theorem pacing_rate_le_cap (r cap : Nat) :
    pacing_rate r (some cap) true ≤ cap := by
  simp only [pacing_rate]
  exact Nat.min_le_left cap r

-- ▸ When enabled with a cap, the result is at most the sender rate.
theorem pacing_rate_le_sender (r cap : Nat) :
    pacing_rate r (some cap) true ≤ r := by
  simp only [pacing_rate]
  exact Nat.min_le_right cap r

-- ▸ The pacing rate never exceeds the sender rate (regardless of cap/enabled).
theorem pacing_rate_le_sender_always (r cap : Nat) (en : Bool) :
    pacing_rate r (some cap) en ≤ r := by
  cases en
  · simp [pacing_rate]
  · simp only [pacing_rate]; exact Nat.min_le_right cap r

-- ▸ When enabled with a cap ≥ sender rate, the result equals the sender rate.
theorem pacing_rate_cap_ge_sender (r cap : Nat) (h : r ≤ cap) :
    pacing_rate r (some cap) true = r := by
  simp [pacing_rate, Nat.min_eq_right h]

-- ▸ When enabled with a cap ≤ sender rate, the result equals the cap.
theorem pacing_rate_cap_le_sender (r cap : Nat) (h : cap ≤ r) :
    pacing_rate r (some cap) true = cap := by
  simp [pacing_rate, Nat.min_eq_left h]

-- ▸ The pacing rate is at most max(sender_rate, cap).
theorem pacing_rate_le_max (r cap : Nat) (en : Bool) :
    pacing_rate r (some cap) en ≤ max r cap := by
  cases en
  · simp [pacing_rate]; exact Nat.le_max_left r cap
  · simp only [pacing_rate]
    have h1 := Nat.min_le_left cap r
    exact Nat.le_trans h1 (Nat.le_max_right r cap)

-- ▸ When enabled with Some cap, result = min cap sender_rate (explicit form).
theorem pacing_rate_enabled_some (r cap : Nat) :
    pacing_rate r (some cap) true = min cap r := by
  simp [pacing_rate]

-- ▸ Idempotence: applying pacing_rate twice with the same cap is idempotent.
theorem pacing_rate_idempotent (r cap : Nat) :
    pacing_rate (pacing_rate r (some cap) true) (some cap) true =
    pacing_rate r (some cap) true := by
  simp only [pacing_rate, Nat.min_def]
  by_cases h1 : cap ≤ r
  · simp [h1]
  · simp [h1]

-- ▸ Monotonicity: increasing sender_rate cannot decrease pacing_rate.
theorem pacing_rate_mono_sender (r1 r2 cap : Nat) (en : Bool) (h : r1 ≤ r2) :
    pacing_rate r1 (some cap) en ≤ pacing_rate r2 (some cap) en := by
  cases en
  · simp only [pacing_rate]; exact h
  · simp only [pacing_rate, Nat.min_def]
    by_cases hcr1 : cap ≤ r1 <;> by_cases hcr2 : cap ≤ r2
    · rw [if_pos hcr1, if_pos hcr2]; exact Nat.le.refl
    · rw [if_pos hcr1, if_neg hcr2]; omega
    · rw [if_neg hcr1, if_pos hcr2]; omega
    · rw [if_neg hcr1, if_neg hcr2]; omega

-- ▸ Monotonicity: increasing the cap cannot decrease pacing_rate.
theorem pacing_rate_mono_cap (r cap1 cap2 : Nat) (h : cap1 ≤ cap2) :
    pacing_rate r (some cap1) true ≤ pacing_rate r (some cap2) true := by
  simp only [pacing_rate, Nat.min_def]
  by_cases hc1 : cap1 ≤ r <;> by_cases hc2 : cap2 ≤ r
  · rw [if_pos hc1, if_pos hc2]; omega
  · rw [if_pos hc1, if_neg hc2]; exact hc1
  · omega
  · rw [if_neg hc1, if_neg hc2]; exact Nat.le.refl

-- ▸ When cap = sender_rate, result equals both.
theorem pacing_rate_equal_cap_sender (r : Nat) :
    pacing_rate r (some r) true = r := by
  simp [pacing_rate]

-- ▸ Zero sender rate always yields zero (no pacing without traffic).
theorem pacing_rate_zero_sender (cap : Nat) (en : Bool) :
    pacing_rate 0 (some cap) en = 0 := by
  cases en <;> simp [pacing_rate]

-- ▸ Zero cap with enabled yields zero.
theorem pacing_rate_zero_cap (r : Nat) :
    pacing_rate r (some 0) true = 0 := by
  simp [pacing_rate]

-- ▸ Correctness: pacing_rate satisfies the RFC-style bound:
--   result ≤ sender_rate  AND  (Some cap, enabled → result ≤ cap).
theorem pacing_rate_bounds (r : Nat) (mp : Option Nat) (en : Bool) :
    pacing_rate r mp en ≤ r ∧
    (∀ cap, mp = some cap → en = true → pacing_rate r mp en ≤ cap) := by
  constructor
  · cases mp with
    | none   => simp [pacing_rate]
    | some c =>
      cases en
      · simp [pacing_rate]
      · simp only [pacing_rate]; exact Nat.min_le_right c r
  · intro cap hmp hen
    cases mp with
    | none => simp at hmp
    | some c =>
      simp only [Option.some.injEq] at hmp; subst hmp
      rw [hen]; simp only [pacing_rate]; exact Nat.min_le_left c r

-- ---------------------------------------------------------------------------
-- §4  Concrete examples (decide)
-- ---------------------------------------------------------------------------

example : pacing_rate 1000 (some 800) true = 800 := by decide
example : pacing_rate 1000 (some 1200) true = 1000 := by decide
example : pacing_rate 1000 none true = 1000 := by decide
example : pacing_rate 1000 (some 500) false = 1000 := by decide
example : pacing_rate 0 (some 1000) true = 0 := by decide

end FVSquad.Pacer
