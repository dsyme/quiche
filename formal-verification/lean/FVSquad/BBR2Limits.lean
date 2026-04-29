-- Copyright (C) 2025, Cloudflare, Inc.
-- BSD-2-Clause licence (same as quiche)
--
-- 🔬 Lean Squad — formal specification of the `Limits<T>` struct
-- and `apply_limits` / `no_greater_than` from BBR2.
--
-- Target T32 (partial): BBR2 Limits invariants
-- Source: quiche/src/recovery/gcongestion/bbr2.rs (L391–L412)
-- Phase: 5 — Implementation + Proofs
-- Lean 4.30.0-rc2, no Mathlib dependency.
--
-- Models:
--   Limits         — struct { lo : Nat, hi : Nat } (bandwidth bits/s as Nat)
--   applyLimits    — clamp val into [lo, hi]
--   noGreaterThan  — constructor: { lo = 0, hi = val }
--
-- Omitted / abstracted:
--   * Generic Ord type parameter — specialised to Nat (bandwidth bits/s)
--   * f64 multiplication in pacing-rate calculations — floating-point,
--     not directly modelable in pure Nat; deferred to future target
--   * BBRv2 struct fields beyond pacing limits — irrelevant here
--
-- Note on validity: the Limits struct does NOT enforce lo ≤ hi. When lo > hi
-- the clamped result is hi (< lo). Theorems about output being ≥ lo require
-- the precondition lo ≤ hi, which noGreaterThan always satisfies.
--
-- Theorems (16 total, 0 sorry):
--   noGreaterThan_lo, noGreaterThan_hi, noGreaterThan_valid,
--   noGreaterThan_apply, applyLimits_ge_lo, applyLimits_le_hi,
--   applyLimits_in_range, applyLimits_idempotent, applyLimits_identity,
--   applyLimits_lo_fixed, applyLimits_hi_fixed, min_eq_lo,
--   applyLimits_mono, applyLimits_of_min,
--   + 5 decidable example checks

namespace FVSquad.BBR2Limits

-- ---------------------------------------------------------------------------
-- §1  Types
-- ---------------------------------------------------------------------------

/-- A bandwidth clamp: any value below `lo` is raised; any above `hi` is
    lowered.  Models `Limits<T>` in `bbr2.rs` specialised to Nat. -/
structure Limits where
  lo : Nat
  hi : Nat
  deriving DecidableEq, Repr

/-- A `Limits` value is **valid** when lo ≤ hi (the normal case). -/
def Limits.Valid (l : Limits) : Prop := l.lo ≤ l.hi

-- ---------------------------------------------------------------------------
-- §2  Operations
-- ---------------------------------------------------------------------------

/-- Mirrors `Limits::min(&self)` — returns the lower bound. -/
def Limits.min (l : Limits) : Nat := l.lo

/-- Mirrors `Limits::apply_limits(&self, val)`:
    `val.max(lo).min(hi)` — clamp to [lo, hi].
    Uses `Nat.min`/`Nat.max` (not dot-notation) to allow `simp` rewrites. -/
def Limits.applyLimits (l : Limits) (val : Nat) : Nat :=
  Nat.min (Nat.max val l.lo) l.hi

/-- Mirrors `Limits::no_greater_than(val)`:
    construct limits with lo = 0, hi = val. -/
def Limits.noGreaterThan (val : Nat) : Limits :=
  { lo := 0, hi := val }

-- ---------------------------------------------------------------------------
-- §3  noGreaterThan constructor invariants
-- ---------------------------------------------------------------------------

/-- noGreaterThan always produces lo = 0. -/
theorem noGreaterThan_lo (val : Nat) :
    (Limits.noGreaterThan val).lo = 0 := rfl

/-- noGreaterThan always produces hi = val. -/
theorem noGreaterThan_hi (val : Nat) :
    (Limits.noGreaterThan val).hi = val := rfl

/-- noGreaterThan is always valid (0 ≤ val). -/
theorem noGreaterThan_valid (val : Nat) :
    (Limits.noGreaterThan val).Valid := Nat.zero_le _

/-- noGreaterThan: apply_limits just caps at val (since lo = 0 ≤ any Nat). -/
theorem noGreaterThan_apply (val x : Nat) :
    (Limits.noGreaterThan val).applyLimits x = Nat.min x val := by
  simp only [Limits.applyLimits, Limits.noGreaterThan,
             Nat.max_eq_left (Nat.zero_le x)]

-- ---------------------------------------------------------------------------
-- §4  applyLimits bounds
-- ---------------------------------------------------------------------------

/-- When valid, the clamped value is always ≥ lo. -/
theorem applyLimits_ge_lo {l : Limits} (hv : l.Valid) (val : Nat) :
    l.applyLimits val ≥ l.lo := by
  simp only [Limits.applyLimits, Limits.Valid] at *
  exact Nat.le_min.mpr ⟨Nat.le_max_right val l.lo, hv⟩

/-- The clamped value is always ≤ hi (no validity needed). -/
theorem applyLimits_le_hi (l : Limits) (val : Nat) :
    l.applyLimits val ≤ l.hi :=
  Nat.min_le_right _ _

/-- When valid, the clamped value lies in [lo, hi]. -/
theorem applyLimits_in_range {l : Limits} (hv : l.Valid) (val : Nat) :
    l.lo ≤ l.applyLimits val ∧ l.applyLimits val ≤ l.hi :=
  ⟨applyLimits_ge_lo hv val, applyLimits_le_hi l val⟩

-- ---------------------------------------------------------------------------
-- §5  Idempotence (requires validity)
-- ---------------------------------------------------------------------------

/-- Clamping twice gives the same result as clamping once. -/
theorem applyLimits_idempotent {l : Limits} (hv : l.Valid) (val : Nat) :
    l.applyLimits (l.applyLimits val) = l.applyLimits val := by
  simp only [Limits.applyLimits]
  have h1 : l.lo ≤ Nat.min (Nat.max val l.lo) l.hi :=
    Nat.le_min.mpr ⟨Nat.le_max_right val l.lo, hv⟩
  have h2 : Nat.min (Nat.max val l.lo) l.hi ≤ l.hi :=
    Nat.min_le_right _ _
  simp only [Nat.max_eq_left h1, Nat.min_eq_left h2]

-- ---------------------------------------------------------------------------
-- §6  Fixed-point at lo and hi
-- ---------------------------------------------------------------------------

/-- If val is already in [lo, hi], applyLimits is the identity. -/
theorem applyLimits_identity (l : Limits) (val : Nat)
    (hlo : l.lo ≤ val) (hhi : val ≤ l.hi) :
    l.applyLimits val = val := by
  simp only [Limits.applyLimits, Nat.max_eq_left hlo, Nat.min_eq_left hhi]

/-- When valid, clamping lo gives lo. -/
theorem applyLimits_lo_fixed {l : Limits} (hv : l.Valid) :
    l.applyLimits l.lo = l.lo :=
  applyLimits_identity l l.lo (Nat.le_refl _) hv

/-- When valid, clamping hi gives hi. -/
theorem applyLimits_hi_fixed {l : Limits} (hv : l.Valid) :
    l.applyLimits l.hi = l.hi :=
  applyLimits_identity l l.hi hv (Nat.le_refl _)

-- ---------------------------------------------------------------------------
-- §7  min() accessor
-- ---------------------------------------------------------------------------

/-- min() returns lo. -/
theorem min_eq_lo (l : Limits) : l.min = l.lo := rfl

/-- When valid, apply_limits of min() returns min(). -/
theorem applyLimits_of_min {l : Limits} (hv : l.Valid) :
    l.applyLimits l.min = l.min :=
  applyLimits_lo_fixed hv

-- ---------------------------------------------------------------------------
-- §8  Monotonicity
-- ---------------------------------------------------------------------------

/-- applyLimits is monotone: larger input → larger (or equal) output. -/
theorem applyLimits_mono (l : Limits) (a b : Nat) (h : a ≤ b) :
    l.applyLimits a ≤ l.applyLimits b := by
  simp only [Limits.applyLimits]
  have h_max : Nat.max a l.lo ≤ Nat.max b l.lo :=
    Nat.max_le.mpr ⟨Nat.le_trans h (Nat.le_max_left b l.lo),
                    Nat.le_max_right b l.lo⟩
  exact Nat.le_min.mpr
    ⟨Nat.le_trans (Nat.min_le_left _ _) h_max, Nat.min_le_right _ _⟩

-- ---------------------------------------------------------------------------
-- §9  Decidable sanity checks
-- ---------------------------------------------------------------------------

example : (Limits.mk 10 100).applyLimits 50  = 50  := by decide
example : (Limits.mk 10 100).applyLimits 5   = 10  := by decide
example : (Limits.mk 10 100).applyLimits 200 = 100 := by decide
example : (Limits.noGreaterThan 50).applyLimits 75 = 50 := by decide
example : (Limits.noGreaterThan 50).applyLimits 30 = 30 := by decide

end FVSquad.BBR2Limits
