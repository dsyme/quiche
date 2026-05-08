-- Copyright (C) 2025, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/LossDetectionThreshold.lean
--
-- 🔬 Lean Squad — formal specification of QUIC loss-detection packet-threshold
-- bounds (RFC 9002 §6.1.1).
--
-- Target T56: Loss detection packet threshold bounds
-- Source: quiche/src/recovery/mod.rs (L51, L53)
--         quiche/src/recovery/congestion/recovery.rs (L655–L660)
-- Phase: 5 — Implementation + Proofs
-- Lean 4.29.x, no Mathlib dependency.
--
-- Models:
--   updatePktThresh  — the spurious-loss-driven threshold update
--   pktThreshInv     — the invariant: INITIAL ≤ thresh ≤ MAX
--
-- Omitted / abstracted:
--   * time_thresh (f64 multiplier) — requires floating-point, out of scope
--   * Detection algorithm (packet enumeration, time comparison) — only the
--     threshold clamping arithmetic is modelled
--
-- Constants (recovery/mod.rs L51, L53):
--   INITIAL_PACKET_THRESHOLD = 3
--   MAX_PACKET_THRESHOLD     = 20
--
-- Theorems (16 total, 0 sorry):
--   initial_ge_3, max_ge_initial,
--   clampToMax_le_max, clampToMax_le_spurious,
--   updatePktThresh_ge_current, updatePktThresh_le_max,
--   updatePktThresh_ge_initial, updatePktThresh_idempotent,
--   updatePktThresh_dominated_by_max, updatePktThresh_mono_spurious,
--   updatePktThresh_preserves_inv, pktThreshInv_initial,
--   foldl_update_preserves_inv, multi_update_preserves_inv,
--   update_at_max, update_spurious_zero

namespace LossDetectionThreshold

/-! ## Constants (recovery/mod.rs L51, L53) -/

def INITIAL_PACKET_THRESHOLD : Nat := 3
def MAX_PACKET_THRESHOLD     : Nat := 20

/-! ## Core operation

`updatePktThresh current spurious` models recovery.rs L655–660:

  ```rust
  self.pkt_thresh = self.pkt_thresh.max(thresh.min(MAX_PACKET_THRESHOLD));
  ```
-/

def clampToMax (s : Nat) : Nat :=
  if s ≤ MAX_PACKET_THRESHOLD then s else MAX_PACKET_THRESHOLD

def updatePktThresh (current spurious : Nat) : Nat :=
  let c := clampToMax spurious
  if current ≤ c then c else current

/-! ## Invariant -/

def pktThreshInv (t : Nat) : Prop :=
  INITIAL_PACKET_THRESHOLD ≤ t ∧ t ≤ MAX_PACKET_THRESHOLD

/-! ## Constant sanity checks -/

theorem initial_ge_3 : INITIAL_PACKET_THRESHOLD = 3 := rfl
theorem max_ge_initial : INITIAL_PACKET_THRESHOLD ≤ MAX_PACKET_THRESHOLD := by decide

/-! ## clampToMax properties -/

theorem clampToMax_le_max (s : Nat) : clampToMax s ≤ MAX_PACKET_THRESHOLD := by
  simp only [clampToMax, MAX_PACKET_THRESHOLD]
  by_cases h : s ≤ 20 <;> simp [h]

theorem clampToMax_le_spurious (s : Nat) : clampToMax s ≤ s := by
  simp only [clampToMax, MAX_PACKET_THRESHOLD]
  by_cases h : s ≤ 20 <;> simp [h] <;> omega

/-! ## Core properties of updatePktThresh -/

theorem updatePktThresh_ge_current (current spurious : Nat) :
    current ≤ updatePktThresh current spurious := by
  simp only [updatePktThresh]
  by_cases h : current ≤ clampToMax spurious <;> simp [h]

theorem updatePktThresh_le_max (current spurious : Nat)
    (hc : current ≤ MAX_PACKET_THRESHOLD) :
    updatePktThresh current spurious ≤ MAX_PACKET_THRESHOLD := by
  simp only [updatePktThresh]
  by_cases h : current ≤ clampToMax spurious
  · simp [h]; exact clampToMax_le_max spurious
  · simp [h]; exact hc

theorem updatePktThresh_ge_initial (current spurious : Nat)
    (h : INITIAL_PACKET_THRESHOLD ≤ current) :
    INITIAL_PACKET_THRESHOLD ≤ updatePktThresh current spurious :=
  Nat.le_trans h (updatePktThresh_ge_current current spurious)

theorem updatePktThresh_idempotent (current spurious : Nat) :
    updatePktThresh (updatePktThresh current spurious) spurious =
    updatePktThresh current spurious := by
  simp only [updatePktThresh]
  by_cases h1 : current ≤ clampToMax spurious
  · simp only [h1, ite_true, Nat.le_refl, ite_self]
  · simp only [h1, ite_false]

theorem updatePktThresh_dominated_by_max (current spurious : Nat)
    (hc : current ≤ MAX_PACKET_THRESHOLD) (hs : MAX_PACKET_THRESHOLD ≤ spurious) :
    updatePktThresh current spurious = MAX_PACKET_THRESHOLD := by
  have hcl : clampToMax spurious = MAX_PACKET_THRESHOLD := by
    simp only [clampToMax, MAX_PACKET_THRESHOLD] at *
    by_cases h : spurious ≤ 20 <;> simp [h] <;> omega
  simp only [updatePktThresh, hcl]
  by_cases h : current ≤ MAX_PACKET_THRESHOLD <;> simp [h]
  omega

theorem updatePktThresh_mono_spurious (current s1 s2 : Nat) (h : s1 ≤ s2) :
    updatePktThresh current s1 ≤ updatePktThresh current s2 := by
  simp only [updatePktThresh]
  have hcl : clampToMax s1 ≤ clampToMax s2 := by
    simp only [clampToMax, MAX_PACKET_THRESHOLD]
    by_cases h1 : s1 ≤ 20 <;> by_cases h2 : s2 ≤ 20 <;> simp [h1, h2] <;> omega
  by_cases h1 : current ≤ clampToMax s1
  · simp only [h1, ite_true]
    by_cases h2 : current ≤ clampToMax s2
    · simp [h2]; exact hcl
    · exact absurd (Nat.le_trans h1 hcl) h2
  · simp only [h1, ite_false]
    by_cases h2 : current ≤ clampToMax s2 <;> simp [h2] <;> omega

/-! ## Invariant preservation -/

theorem updatePktThresh_preserves_inv (current spurious : Nat)
    (hinv : pktThreshInv current) :
    pktThreshInv (updatePktThresh current spurious) :=
  ⟨Nat.le_trans hinv.1 (updatePktThresh_ge_current _ _),
   updatePktThresh_le_max _ _ hinv.2⟩

theorem pktThreshInv_initial : pktThreshInv INITIAL_PACKET_THRESHOLD :=
  ⟨Nat.le_refl _, by decide⟩

theorem foldl_update_preserves_inv (spuriousList : List Nat) (start : Nat)
    (hinv : pktThreshInv start) :
    pktThreshInv (spuriousList.foldl updatePktThresh start) := by
  induction spuriousList generalizing start with
  | nil => exact hinv
  | cons s ss ih =>
    simp only [List.foldl_cons]
    exact ih (updatePktThresh start s) (updatePktThresh_preserves_inv _ _ hinv)

theorem multi_update_preserves_inv (spuriousList : List Nat) :
    pktThreshInv (spuriousList.foldl updatePktThresh INITIAL_PACKET_THRESHOLD) :=
  foldl_update_preserves_inv spuriousList _ pktThreshInv_initial

/-! ## Edge cases -/

theorem update_at_max (spurious : Nat) :
    updatePktThresh MAX_PACKET_THRESHOLD spurious = MAX_PACKET_THRESHOLD := by
  simp only [updatePktThresh, clampToMax, MAX_PACKET_THRESHOLD]
  by_cases h : spurious ≤ 20
  · simp [h]; omega
  · simp [h]

theorem update_spurious_zero (current : Nat) :
    updatePktThresh current 0 = current := by
  simp only [updatePktThresh, clampToMax, MAX_PACKET_THRESHOLD]
  by_cases h : current ≤ 0 <;> simp [h] <;> omega

/-! ## #eval spot-checks (match recovery.rs test assertions) -/

#eval updatePktThresh 3 3   -- 3  (initial, no change)
#eval updatePktThresh 3 4   -- 4  (spurious reorder of 4)
#eval updatePktThresh 4 3   -- 4  (current dominates)
#eval updatePktThresh 3 25  -- 20 (clamped to MAX)
#eval updatePktThresh 20 30 -- 20 (already at MAX)

end LossDetectionThreshold
