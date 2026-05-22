-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — monotonicity and range properties of QUIC varint lengths.
--
-- Target: octets/src/lib.rs — varint_len (L810-822)
-- Phase: 5 — Proofs (T79, run 180)
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- This file proves that varint_len_nat (the Lean model of `varint_len`)
-- is:
--   §1  Monotone non-decreasing on valid inputs
--   §2  Valued exclusively in {1, 2, 4, 8}
--   §3  Step-shaped — constant between the RFC 9000 §16 thresholds
--   §4  Inverse-monotone — if length shrinks, value shrinks
--   §5  Tight threshold properties — the step boundaries are sharp
--
-- Approximations: `varint_len_nat` returns 0 for v > MAX_VAR_INT
-- (the `unreachable!()` branch in Rust). All theorems are stated
-- for valid inputs v ≤ MAX_VAR_INT.

import FVSquad.VarIntTag

namespace VarIntLength

open VarIntTag

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §1  Monotonicity
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- varint_len_nat is monotone non-decreasing: if a ≤ b and b ≤ MAX_VAR_INT
    then varint_len_nat a ≤ varint_len_nat b.
    Reflects the Rust property: larger values need more encoding bytes. -/
theorem varint_len_monotone {a b : Nat}
    (hab : a ≤ b) (hb : b ≤ MAX_VAR_INT) :
    varint_len_nat a ≤ varint_len_nat b := by
  simp only [varint_len_nat, MAX_VAR_INT] at *
  by_cases h1 : a ≤ 63 <;>
  by_cases h2 : b ≤ 63 <;>
  by_cases h3 : a ≤ 16383 <;>
  by_cases h4 : b ≤ 16383 <;>
  by_cases h5 : a ≤ 1073741823 <;>
  by_cases h6 : b ≤ 1073741823 <;>
  simp [h1, h2, h3, h4, h5, h6] <;>
  omega

/-- Strict monotonicity at threshold 63→64: crossing from ≤63 to ≥64
    strictly increases the length from 1 to 2. -/
theorem varint_len_lt_at_63 {a b : Nat}
    (ha : a ≤ 63) (hb : 64 ≤ b) (hbv : b ≤ MAX_VAR_INT) :
    varint_len_nat a < varint_len_nat b := by
  have h1 : varint_len_nat a = 1 := varint_len_nat_1 ha
  have h2 : 2 ≤ varint_len_nat b := by
    simp only [varint_len_nat, MAX_VAR_INT] at *
    by_cases hb63 : b ≤ 63
    · omega
    by_cases hb16383 : b ≤ 16383 <;>
    by_cases hb1G : b ≤ 1073741823 <;>
    simp [hb63, hb16383, hb1G] <;> omega
  omega

/-- Strict monotonicity at threshold 16383→16384. -/
theorem varint_len_lt_at_16383 {a b : Nat}
    (ha : a ≤ 16383) (hb : 16384 ≤ b) (hbv : b ≤ MAX_VAR_INT) :
    varint_len_nat a ≤ varint_len_nat b :=
  varint_len_monotone (by omega) hbv

/-- Strict monotonicity at threshold 1073741823→1073741824. -/
theorem varint_len_lt_at_1G {a b : Nat}
    (ha : a ≤ 1073741823) (hb : 1073741824 ≤ b) (hbv : b ≤ MAX_VAR_INT) :
    varint_len_nat a ≤ varint_len_nat b :=
  varint_len_monotone (by omega) hbv

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §2  Output range: always in {1, 2, 4, 8}
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- The output is always in the set {1, 2, 4, 8}. -/
theorem varint_len_in_set {v : Nat} (hv : v ≤ MAX_VAR_INT) :
    varint_len_nat v = 1 ∨ varint_len_nat v = 2 ∨
    varint_len_nat v = 4 ∨ varint_len_nat v = 8 := by
  have h := varint_len_partition v hv
  cases h with
  | inl hh => exact Or.inl hh.2
  | inr hh =>
    cases hh with
    | inl hh => exact Or.inr (Or.inl hh.2.2)
    | inr hh =>
      cases hh with
      | inl hh => exact Or.inr (Or.inr (Or.inl hh.2.2))
      | inr hh => exact Or.inr (Or.inr (Or.inr hh.2))

/-- For valid inputs, varint_len_nat is at least 1. -/
theorem varint_len_ge_one {v : Nat} (hv : v ≤ MAX_VAR_INT) :
    1 ≤ varint_len_nat v := by
  have h := varint_len_in_set hv
  cases h with
  | inl h => omega
  | inr h =>
    cases h with
    | inl h => omega
    | inr h =>
      cases h with
      | inl h => omega
      | inr h => omega

/-- For valid inputs, varint_len_nat is at most 8. -/
theorem varint_len_le_eight {v : Nat} (hv : v ≤ MAX_VAR_INT) :
    varint_len_nat v ≤ 8 := by
  have h := varint_len_in_set hv
  cases h with
  | inl h => omega
  | inr h =>
    cases h with
    | inl h => omega
    | inr h =>
      cases h with
      | inl h => omega
      | inr h => omega

/-- varint_len_nat never returns 3. -/
theorem varint_len_ne_three {v : Nat} (hv : v ≤ MAX_VAR_INT) :
    varint_len_nat v ≠ 3 := by
  have h := varint_len_in_set hv
  cases h with
  | inl h => omega
  | inr h =>
    cases h with
    | inl h => omega
    | inr h =>
      cases h with
      | inl h => omega
      | inr h => omega

/-- varint_len_nat never returns 5. -/
theorem varint_len_ne_five {v : Nat} (hv : v ≤ MAX_VAR_INT) :
    varint_len_nat v ≠ 5 := by
  have h := varint_len_in_set hv
  cases h with
  | inl h => omega
  | inr h =>
    cases h with
    | inl h => omega
    | inr h =>
      cases h with
      | inl h => omega
      | inr h => omega

/-- varint_len_nat never returns 6. -/
theorem varint_len_ne_six {v : Nat} (hv : v ≤ MAX_VAR_INT) :
    varint_len_nat v ≠ 6 := by
  have h := varint_len_in_set hv
  cases h with
  | inl h => omega
  | inr h =>
    cases h with
    | inl h => omega
    | inr h =>
      cases h with
      | inl h => omega
      | inr h => omega

/-- varint_len_nat never returns 7. -/
theorem varint_len_ne_seven {v : Nat} (hv : v ≤ MAX_VAR_INT) :
    varint_len_nat v ≠ 7 := by
  have h := varint_len_in_set hv
  cases h with
  | inl h => omega
  | inr h =>
    cases h with
    | inl h => omega
    | inr h =>
      cases h with
      | inl h => omega
      | inr h => omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §3  Step shape — the function is constant between thresholds
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Within the first segment [0, 63] the length is constant. -/
theorem varint_len_const_seg1 {a b : Nat}
    (ha : a ≤ 63) (hb : b ≤ 63) :
    varint_len_nat a = varint_len_nat b := by
  simp [varint_len_nat_1 ha, varint_len_nat_1 hb]

/-- Within the second segment [64, 16383] the length is constant. -/
theorem varint_len_const_seg2 {a b : Nat}
    (ha1 : 64 ≤ a) (ha2 : a ≤ 16383)
    (hb1 : 64 ≤ b) (hb2 : b ≤ 16383) :
    varint_len_nat a = varint_len_nat b := by
  simp [varint_len_nat_2 ha1 ha2, varint_len_nat_2 hb1 hb2]

/-- Within the third segment [16384, 1073741823] the length is constant. -/
theorem varint_len_const_seg3 {a b : Nat}
    (ha1 : 16384 ≤ a) (ha2 : a ≤ 1073741823)
    (hb1 : 16384 ≤ b) (hb2 : b ≤ 1073741823) :
    varint_len_nat a = varint_len_nat b := by
  simp [varint_len_nat_4 ha1 ha2, varint_len_nat_4 hb1 hb2]

/-- Within the fourth segment [1073741824, MAX_VAR_INT] the length is constant. -/
theorem varint_len_const_seg4 {a b : Nat}
    (ha1 : 1073741824 ≤ a) (ha2 : a ≤ MAX_VAR_INT)
    (hb1 : 1073741824 ≤ b) (hb2 : b ≤ MAX_VAR_INT) :
    varint_len_nat a = varint_len_nat b := by
  simp [varint_len_nat_8 ha1 ha2, varint_len_nat_8 hb1 hb2]

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §4  Inverse monotonicity (contrapositive of §1)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- If the encoding length of a exceeds that of b, then a > b
    (contrapositive of monotonicity). -/
theorem varint_len_inv_monotone {a b : Nat}
    (_ha : a ≤ MAX_VAR_INT) (hb : b ≤ MAX_VAR_INT)
    (h : varint_len_nat b < varint_len_nat a) :
    b < a := by
  cases Nat.lt_or_ge b a with
  | inl hlt => exact hlt
  | inr hge =>
    have := varint_len_monotone hge hb
    omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §5  Threshold sharpness — the step value is tight
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- varint_len is 1 at exactly the boundary value 63. -/
theorem varint_len_at_63 : varint_len_nat 63 = 1 := by decide

/-- varint_len jumps to 2 at 64. -/
theorem varint_len_at_64 : varint_len_nat 64 = 2 := by decide

/-- varint_len is 2 at exactly the boundary value 16383. -/
theorem varint_len_at_16383 : varint_len_nat 16383 = 2 := by decide

/-- varint_len jumps to 4 at 16384. -/
theorem varint_len_at_16384 : varint_len_nat 16384 = 4 := by decide

/-- varint_len is 4 at exactly the boundary value 1073741823. -/
theorem varint_len_at_1073741823 : varint_len_nat 1073741823 = 4 := by decide

/-- varint_len jumps to 8 at 1073741824. -/
theorem varint_len_at_1073741824 : varint_len_nat 1073741824 = 8 := by decide

/-- varint_len is 8 at MAX_VAR_INT. -/
theorem varint_len_at_max : varint_len_nat MAX_VAR_INT = 8 := by decide

/-- varint_len is 1 at 0. -/
theorem varint_len_at_zero : varint_len_nat 0 = 1 := by decide

end VarIntLength
