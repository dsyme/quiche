-- Copyright (C) 2025, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — T67: BBR2 inflight-lo lower-bound guard
--
-- Target T67: BBR2 inflight_lo sentinel-guarded minimum
-- Source: quiche/src/recovery/gcongestion/bbr2/network_model.rs
--   clear_inflight_lo (~L750):  inflight_lo = usize::MAX
--   cap_inflight_lo   (~L754):
--     if inflight_lo != usize::MAX { inflight_lo = cap.min(inflight_lo) }
-- Phase: 5 — Implementation + Proofs
-- Lean 4.29.0, no Mathlib dependency.
--
-- Design: `usize::MAX` (modelled as SENTINEL = 2^64-1) marks "no lower bound
-- set".  `cap_inflight_lo` only applies when the sentinel is absent.
-- This creates a guard: once cleared, cap has no effect.
--
-- We only consider cap values v where v < SENTINEL (i.e. realistic byte counts).
-- This is captured by the `SafeCap v` predicate.
--
-- Theorems (15 total, 0 sorry):
--   clear_sets_sentinel, cap_after_clear_noop, cap_decreasing,
--   cap_le_cap_arg, cap_le_old, cap_never_raises, cap_idempotent,
--   double_cap_eq_min, cap_commutative,
--   init_then_cap_le_init, init_then_cap_le_cap,
--   cap_at_self_noop, cap_zero_active,
--   clear_makes_inactive, init_makes_active

namespace FVSquad.BBR2InflightLo

-- ---------------------------------------------------------------------------
-- §1  Constants and types
-- ---------------------------------------------------------------------------

/-- usize::MAX sentinel — any realistic inflight byte count is far below this. -/
abbrev SENTINEL : Nat := 2^64 - 1

/-- `SafeCap v` means v is a realistic cap value (not the sentinel itself). -/
def SafeCap (v : Nat) : Prop := v < SENTINEL

/-- Model of the mutable `inflight_lo` field. -/
structure InflightLo where
  lo : Nat
  deriving DecidableEq, Repr

-- ---------------------------------------------------------------------------
-- §2  Operations
-- ---------------------------------------------------------------------------

/-- Mirror `clear_inflight_lo`: reset to sentinel (no lower bound). -/
def InflightLo.clear : InflightLo := { lo := SENTINEL }

/-- Mirror `cap_inflight_lo(cap)`:
    if lo is the sentinel, do nothing;
    otherwise set lo := min(cap, lo). -/
def InflightLo.cap (s : InflightLo) (c : Nat) : InflightLo :=
  if s.lo = SENTINEL then s else { lo := Nat.min c s.lo }

/-- Initialise to a concrete (non-sentinel) value. -/
def InflightLo.init (v : Nat) : InflightLo := { lo := v }

/-- Active means a lower bound IS set (not the sentinel). -/
def InflightLo.active (s : InflightLo) : Prop := s.lo ≠ SENTINEL

-- ---------------------------------------------------------------------------
-- §3  Theorems
-- ---------------------------------------------------------------------------

/-- 1. After clear, lo = SENTINEL. -/
theorem clear_sets_sentinel :
    InflightLo.clear.lo = SENTINEL := rfl

/-- 2. cap after clear has no effect. -/
theorem cap_after_clear_noop (c : Nat) :
    InflightLo.clear.cap c = InflightLo.clear := by
  simp [InflightLo.cap, InflightLo.clear]

/-- 3. cap (when active) produces lo ≤ old lo. -/
theorem cap_decreasing (s : InflightLo) (c : Nat) (h : s.active) :
    (s.cap c).lo ≤ s.lo := by
  simp only [InflightLo.cap, InflightLo.active] at *
  simp only [h, ite_false]
  exact Nat.min_le_right c s.lo

/-- 4. cap (when active) produces lo ≤ cap argument. -/
theorem cap_le_cap_arg (s : InflightLo) (c : Nat) (h : s.active) :
    (s.cap c).lo ≤ c := by
  simp only [InflightLo.cap, InflightLo.active] at *
  simp only [h, ite_false]
  exact Nat.min_le_left c s.lo

/-- 5. cap (when active) produces lo ≤ old lo (alias). -/
theorem cap_le_old (s : InflightLo) (c : Nat) (h : s.active) :
    (s.cap c).lo ≤ s.lo := cap_decreasing s c h

/-- 6. cap never raises lo. -/
theorem cap_never_raises (s : InflightLo) (c : Nat) :
    (s.cap c).lo ≤ s.lo := by
  simp only [InflightLo.cap]
  by_cases h : s.lo = SENTINEL
  · simp [h]
  · simp [h]
    exact Nat.min_le_right c s.lo

/-- 7. cap idempotent: cap(c) twice = cap(c) once (when active).
    Requires SafeCap c so the first cap does not accidentally produce SENTINEL. -/
theorem cap_idempotent (s : InflightLo) (c : Nat)
    (h : s.active) (hc : SafeCap c) :
    (s.cap c).cap c = s.cap c := by
  simp only [InflightLo.cap, InflightLo.active, SafeCap] at *
  simp only [h, ite_false]
  -- now need: (if Nat.min c s.lo = SENTINEL then …) … = …
  have hmin : Nat.min c s.lo < SENTINEL := by
    exact Nat.lt_of_le_of_lt (Nat.min_le_left c s.lo) hc
  have hmin_ne : Nat.min c s.lo ≠ SENTINEL := Nat.ne_of_lt hmin
  simp [hmin_ne]

/-- 8. Two sequential safe caps equal the min of the bounds.
    Requires SafeCap c1 to avoid the sentinel edge case. -/
theorem double_cap_eq_min (s : InflightLo) (c1 c2 : Nat)
    (h : s.active) (hc1 : SafeCap c1) :
    ((s.cap c1).cap c2).lo = Nat.min c2 (Nat.min c1 s.lo) := by
  simp only [InflightLo.cap, InflightLo.active, SafeCap] at *
  simp only [h, ite_false]
  have hmin : Nat.min c1 s.lo < SENTINEL :=
    Nat.lt_of_le_of_lt (Nat.min_le_left c1 s.lo) hc1
  have hmin_ne : Nat.min c1 s.lo ≠ SENTINEL := Nat.ne_of_lt hmin
  simp [hmin_ne]

/-- 9. cap commutative (for safe caps). -/
theorem cap_commutative (s : InflightLo) (c1 c2 : Nat)
    (h : s.active) (hc1 : SafeCap c1) (hc2 : SafeCap c2) :
    ((s.cap c1).cap c2).lo = ((s.cap c2).cap c1).lo := by
  rw [double_cap_eq_min s c1 c2 h hc1, double_cap_eq_min s c2 c1 h hc2]
  simp only [Nat.min_left_comm]

/-- 10. init(v) then cap(c): result ≤ v. -/
theorem init_then_cap_le_init (v c : Nat) (hv : v ≠ SENTINEL) :
    ((InflightLo.init v).cap c).lo ≤ v := by
  simp only [InflightLo.cap, InflightLo.init, hv, ite_false]
  exact Nat.min_le_right c v

/-- 11. init(v) then cap(c): result ≤ c. -/
theorem init_then_cap_le_cap (v c : Nat) (hv : v ≠ SENTINEL) :
    ((InflightLo.init v).cap c).lo ≤ c := by
  simp only [InflightLo.cap, InflightLo.init, hv, ite_false]
  exact Nat.min_le_left c v

/-- 12. cap(s.lo) when active: lo is unchanged. -/
theorem cap_at_self_noop (s : InflightLo) (h : s.active) :
    (s.cap s.lo).lo = s.lo := by
  simp only [InflightLo.cap, InflightLo.active] at *
  simp [h]

/-- 13. cap(0) when active: lo becomes 0. -/
theorem cap_zero_active (s : InflightLo) (h : s.active) :
    (s.cap 0).lo = 0 := by
  simp only [InflightLo.cap, InflightLo.active] at *
  simp [h]

/-- 14. clear makes lo inactive. -/
theorem clear_makes_inactive : ¬InflightLo.clear.active := by
  simp [InflightLo.active, InflightLo.clear]

/-- 15. init(v) with v ≠ SENTINEL makes lo active. -/
theorem init_makes_active (v : Nat) (hv : v ≠ SENTINEL) :
    (InflightLo.init v).active := by
  simp [InflightLo.active, InflightLo.init, hv]

-- ---------------------------------------------------------------------------
-- §4  Example sanity checks
-- ---------------------------------------------------------------------------

#eval (InflightLo.clear).lo               -- SENTINEL = 18446744073709551615
#eval (InflightLo.clear.cap 100).lo       -- SENTINEL (no effect)
#eval ((InflightLo.init 500).cap 300).lo  -- 300
#eval ((InflightLo.init 500).cap 700).lo  -- 500
#eval ((InflightLo.init 500).cap 300).cap 200 |>.lo  -- 200
#eval ((InflightLo.init 500).cap 300).cap 400 |>.lo  -- 300

end FVSquad.BBR2InflightLo
