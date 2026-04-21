-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of Bandwidth arithmetic invariants.
--
-- Target: quiche/src/recovery/bandwidth.rs
-- Spec:   formal-verification/specs/bandwidth_arithmetic_informal.md
-- Phase:  4 — Implementation + Proofs (T36, run 90)
-- Lean 4 (v4.30.0-rc2), no Mathlib dependency.
--
-- Models:
--   Bandwidth          — wrapper over Nat (bits_per_second)
--   Duration           — Nat nanoseconds
--
-- Excluded from model (documented in CORRESPONDENCE.md):
--   * Mul<f64> / Mul<f32>  — floating-point, not modelable in pure Nat
--   * transfer_time        — duration/speed inversion, not needed for invariants
--   * Debug formatting     — display logic, irrelevant to correctness
--   * u64 overflow         — Nat is unbounded; overflow-free model
--
-- All proofs close with omega or simp+omega.

namespace FVSquad.Bandwidth

-- ---------------------------------------------------------------------------
-- §1  Types
-- ---------------------------------------------------------------------------

/-- A network bandwidth value, stored as bits-per-second (Nat). -/
structure Bandwidth where
  bits_per_second : Nat
  deriving DecidableEq, Repr

/-- Nanoseconds, representing a time duration. -/
abbrev Nanos := Nat

-- ---------------------------------------------------------------------------
-- §2  Constants
-- ---------------------------------------------------------------------------

def NUM_NANOS_PER_SECOND : Nat := 1_000_000_000

-- ---------------------------------------------------------------------------
-- §3  Constructors (pure models of Rust const fn)
-- ---------------------------------------------------------------------------

def fromKbitsPerSecond (k : Nat) : Bandwidth :=
  { bits_per_second := k * 1000 }

def fromMbitsPerSecond (m : Nat) : Bandwidth :=
  fromKbitsPerSecond (m * 1000)

def fromBytesPerSecond (bps : Nat) : Bandwidth :=
  { bits_per_second := bps * 8 }

def zero : Bandwidth := { bits_per_second := 0 }

/-- The infinite sentinel — Lean Nat has no MAX, but we use 2^64 - 1 to
    match the Rust u64::MAX. -/
def infinite : Bandwidth := { bits_per_second := 2^64 - 1 }

/-- Model of from_bytes_and_time_delta.
    If bytes = 0 → result is 0.
    If nanos = 0 → clamp to 1.
    If 8*bytes*1e9 < nanos → result is 1.
    Otherwise result is 8*bytes*1e9 / nanos. -/
def fromBytesAndTimeDelta (bytes : Nat) (nanos : Nanos) : Bandwidth :=
  if bytes = 0 then
    { bits_per_second := 0 }
  else
    let n := if nanos = 0 then 1 else nanos
    let num_nano_bits := 8 * bytes * NUM_NANOS_PER_SECOND
    if num_nano_bits < n then
      { bits_per_second := 1 }
    else
      { bits_per_second := num_nano_bits / n }

-- ---------------------------------------------------------------------------
-- §4  Accessors / conversions
-- ---------------------------------------------------------------------------

def toBitsPerSecond (bw : Bandwidth) : Nat := bw.bits_per_second

def toBytesPerSecond (bw : Bandwidth) : Nat := bw.bits_per_second / 8

/-- to_bytes_per_period: bps * nanos / 8 / 1e9. -/
def toBytesPerPeriod (bw : Bandwidth) (period_nanos : Nanos) : Nat :=
  bw.bits_per_second * period_nanos / 8 / NUM_NANOS_PER_SECOND

-- ---------------------------------------------------------------------------
-- §5  Arithmetic operations
-- ---------------------------------------------------------------------------

def add (a b : Bandwidth) : Bandwidth :=
  { bits_per_second := a.bits_per_second + b.bits_per_second }

/-- Saturating subtraction; returns None when b > a (matches Rust checked_sub). -/
def sub (a b : Bandwidth) : Option Bandwidth :=
  if a.bits_per_second ≥ b.bits_per_second then
    some { bits_per_second := a.bits_per_second - b.bits_per_second }
  else
    none

-- ---------------------------------------------------------------------------
-- §6  Ordering
-- ---------------------------------------------------------------------------

def le (a b : Bandwidth) : Prop := a.bits_per_second ≤ b.bits_per_second

-- ---------------------------------------------------------------------------
-- §7  Constructor round-trip / unit-conversion theorems
-- ---------------------------------------------------------------------------

/-- fromKbitsPerSecond stores k * 1000 bps. -/
theorem fromKbits_bits (k : Nat) :
    (fromKbitsPerSecond k).bits_per_second = k * 1000 := by
  simp [fromKbitsPerSecond]

/-- fromBytesPerSecond stores b * 8 bps. -/
theorem fromBytes_bits (b : Nat) :
    (fromBytesPerSecond b).bits_per_second = b * 8 := by
  simp [fromBytesPerSecond]

/-- toBytesPerSecond ∘ fromBytesPerSecond = id (exact round-trip). -/
theorem fromBytes_toBytes_roundtrip (b : Nat) :
    toBytesPerSecond (fromBytesPerSecond b) = b := by
  simp [toBytesPerSecond, fromBytesPerSecond]

/-- fromMbits = fromKbits * 1000. -/
theorem fromMbits_eq (m : Nat) :
    (fromMbitsPerSecond m).bits_per_second = m * 1_000_000 := by
  simp [fromMbitsPerSecond, fromKbitsPerSecond]
  omega

-- ---------------------------------------------------------------------------
-- §8  Special-value theorems
-- ---------------------------------------------------------------------------

theorem zero_bits : zero.bits_per_second = 0 := by simp [zero]

theorem infinite_bits : infinite.bits_per_second = 2^64 - 1 := by
  simp [infinite]

/-- zero ≤ every bandwidth. -/
theorem zero_le (bw : Bandwidth) : le zero bw := by
  simp [le, zero]

-- ---------------------------------------------------------------------------
-- §9  Addition theorems
-- ---------------------------------------------------------------------------

/-- Addition is commutative. -/
theorem add_comm (a b : Bandwidth) :
    (add a b).bits_per_second = (add b a).bits_per_second := by
  simp [add]
  omega

/-- Addition is associative. -/
theorem add_assoc (a b c : Bandwidth) :
    (add (add a b) c).bits_per_second =
      (add a (add b c)).bits_per_second := by
  simp [add]
  omega

/-- Adding zero is identity. -/
theorem add_zero (a : Bandwidth) : (add a zero).bits_per_second =
    a.bits_per_second := by
  simp [add, zero]

theorem zero_add (a : Bandwidth) : (add zero a).bits_per_second =
    a.bits_per_second := by
  simp [add, zero]

-- ---------------------------------------------------------------------------
-- §10  Subtraction theorems
-- ---------------------------------------------------------------------------

/-- If a ≥ b, sub succeeds and gives a - b. -/
theorem sub_some (a b : Bandwidth) (h : a.bits_per_second ≥ b.bits_per_second) :
    ∃ c, sub a b = some c ∧
         c.bits_per_second = a.bits_per_second - b.bits_per_second := by
  simp [sub, h]

/-- If a < b, sub returns None. -/
theorem sub_none (a b : Bandwidth) (h : a.bits_per_second < b.bits_per_second) :
    sub a b = none := by
  simp [sub]
  omega

/-- Sub self = Some zero. -/
theorem sub_self (a : Bandwidth) :
    ∃ c, sub a a = some c ∧ c.bits_per_second = 0 := by
  simp [sub]

-- ---------------------------------------------------------------------------
-- §11  toBytesPerPeriod monotonicity
-- ---------------------------------------------------------------------------

/-- More bandwidth → more bytes per period. -/
theorem toBytesPerPeriod_mono_bw (a b : Bandwidth) (t : Nanos)
    (h : a.bits_per_second ≤ b.bits_per_second) :
    toBytesPerPeriod a t ≤ toBytesPerPeriod b t := by
  simp [toBytesPerPeriod]
  apply Nat.div_le_div_right
  apply Nat.div_le_div_right
  apply Nat.mul_le_mul_right
  exact h

/-- Longer period → more bytes per period. -/
theorem toBytesPerPeriod_mono_time (bw : Bandwidth) (s t : Nanos)
    (h : s ≤ t) :
    toBytesPerPeriod bw s ≤ toBytesPerPeriod bw t := by
  simp [toBytesPerPeriod]
  apply Nat.div_le_div_right
  apply Nat.div_le_div_right
  apply Nat.mul_le_mul_left
  exact h

/-- zero bandwidth → zero bytes per period. -/
theorem toBytesPerPeriod_zero_bw (t : Nanos) :
    toBytesPerPeriod zero t = 0 := by
  simp [toBytesPerPeriod, zero]

/-- zero time period → zero bytes per period. -/
theorem toBytesPerPeriod_zero_time (bw : Bandwidth) :
    toBytesPerPeriod bw 0 = 0 := by
  simp [toBytesPerPeriod]

-- ---------------------------------------------------------------------------
-- §12  fromKbitsPerSecond monotonicity and fromBytesPerSecond ordering
-- ---------------------------------------------------------------------------

/-- fromKbits is monotone. -/
theorem fromKbits_mono (a b : Nat) (h : a ≤ b) :
    le (fromKbitsPerSecond a) (fromKbitsPerSecond b) := by
  simp [le, fromKbitsPerSecond]
  omega

/-- fromKbits is strictly monotone. -/
theorem fromKbits_strict_mono (a b : Nat) (h : a < b) :
    (fromKbitsPerSecond a).bits_per_second <
      (fromKbitsPerSecond b).bits_per_second := by
  simp [fromKbitsPerSecond]
  omega

-- ---------------------------------------------------------------------------
-- §13  fromBytesAndTimeDelta lower-bound theorem
-- ---------------------------------------------------------------------------

/-- Zero bytes → zero bps. -/
theorem fromBytesAndTimeDelta_zero_bytes (nanos : Nanos) :
    (fromBytesAndTimeDelta 0 nanos).bits_per_second = 0 := by
  simp [fromBytesAndTimeDelta]

/-- Positive bytes → at least 1 bps. -/
theorem fromBytesAndTimeDelta_pos (bytes : Nat) (nanos : Nanos)
    (hb : 0 < bytes) :
    (fromBytesAndTimeDelta bytes nanos).bits_per_second ≥ 1 := by
  have hne : bytes ≠ 0 := by omega
  simp only [fromBytesAndTimeDelta, if_neg hne]
  -- After unfolding, goal is:
  --   (if 8*b*NUM < (if nanos=0 then 1 else nanos) then {1} else {8*b*NUM / n}).bps ≥ 1
  have hn_pos : 0 < if nanos = 0 then 1 else nanos := by
    by_cases h : nanos = 0
    · simp [h]
    · rw [if_neg h]; exact Nat.pos_of_ne_zero h
  rcases Nat.lt_or_ge (8 * bytes * NUM_NANOS_PER_SECOND)
      (if nanos = 0 then 1 else nanos) with hlt | hge
  · simp [if_pos hlt]  -- reduces to 1 ≥ 1
  · simp only [if_neg (Nat.not_lt.mpr hge)]
    exact Nat.div_pos hge hn_pos

-- ---------------------------------------------------------------------------
-- §14  Concrete examples (match Rust test suite)
-- ---------------------------------------------------------------------------

-- from_kbits_per_second(1).to_bytes_per_period(10_000ms) = 1250
example : toBytesPerPeriod (fromKbitsPerSecond 1)
    (10_000 * 1_000_000) = 1250 := by
  simp [toBytesPerPeriod, fromKbitsPerSecond, NUM_NANOS_PER_SECOND]

-- from_kbits_per_second(1).to_bytes_per_period(1000ms) = 125
example : toBytesPerPeriod (fromKbitsPerSecond 1)
    (1_000 * 1_000_000) = 125 := by
  simp [toBytesPerPeriod, fromKbitsPerSecond, NUM_NANOS_PER_SECOND]

-- from_kbits_per_second(1).to_bytes_per_period(100ms) = 12
example : toBytesPerPeriod (fromKbitsPerSecond 1)
    (100 * 1_000_000) = 12 := by
  simp [toBytesPerPeriod, fromKbitsPerSecond, NUM_NANOS_PER_SECOND]

-- from_kbits_per_second(1).to_bytes_per_period(10ms) = 1
example : toBytesPerPeriod (fromKbitsPerSecond 1)
    (10 * 1_000_000) = 1 := by
  simp [toBytesPerPeriod, fromKbitsPerSecond, NUM_NANOS_PER_SECOND]

-- from_kbits_per_second(1).to_bytes_per_period(1ms) = 0
example : toBytesPerPeriod (fromKbitsPerSecond 1)
    (1 * 1_000_000) = 0 := by
  simp [toBytesPerPeriod, fromKbitsPerSecond, NUM_NANOS_PER_SECOND]

-- from_bytes_and_time_delta(10, 1000ms).bits_per_second = 80
example : (fromBytesAndTimeDelta 10 (1_000 * 1_000_000)).bits_per_second
    = 80 := by
  simp [fromBytesAndTimeDelta, NUM_NANOS_PER_SECOND]

-- from_bytes_and_time_delta(10, 100ms).bits_per_second = 800
example : (fromBytesAndTimeDelta 10 (100 * 1_000_000)).bits_per_second
    = 800 := by
  simp [fromBytesAndTimeDelta, NUM_NANOS_PER_SECOND]

-- zero.bits_per_second = 0
example : zero.bits_per_second = 0 := by simp [zero]

-- from_bytes_per_second(125).to_bytes_per_second = 125
example : toBytesPerSecond (fromBytesPerSecond 125) = 125 := by
  simp [toBytesPerSecond, fromBytesPerSecond]

end FVSquad.Bandwidth
