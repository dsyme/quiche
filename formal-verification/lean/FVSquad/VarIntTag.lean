-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of the QUIC varint 2-bit tag
-- structural properties.
--
-- Target: octets/src/lib.rs — varint_len, varint_parse_len, put_varint_with_len
-- Spec: formal-verification/specs/varint_tag_informal.md
-- Phase: 3 — Formal Spec (T30, run 85)
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- This file proves five groups of structural properties about the 2-bit tag
-- subsystem that makes QUIC varints self-delimiting (RFC 9000 §16).  It
-- builds on the codec proofs in FVSquad/Varint.lean.
--
-- §1  varint_parse_len_nat range biconditionals
--     (first byte value uniquely determines parse length)
-- §2  varint_len_nat value-range biconditionals
--     (value range uniquely determines encoding length)
-- §3  Tag-bit / value-bit non-overlap
--     (justifies arithmetic + in place of bitwise |||)
-- §4  varint_tag_consistency — universal first-byte tag theorem
--     (strengthens the existential in Varint.lean to universal)
-- §5  Partition theorems
--     (first-byte ranges and value ranges are disjoint and exhaustive)

import FVSquad.Varint

namespace VarIntTag

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §1  varint_parse_len_nat range biconditionals
--
-- For every first byte in [0,255], the parse length is uniquely
-- determined by — and uniquely determines — the 2-bit prefix.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- The parse length is 1 iff the first byte is in [0, 63]. -/
theorem varint_parse_len_1_iff (first : Nat) (h : first ≤ 255) :
    varint_parse_len_nat first = 1 ↔ first ≤ 63 := by
  unfold varint_parse_len_nat
  match hm : first / 64 with
  | 0 => simp; omega
  | 1 => simp; omega
  | 2 => simp; omega
  | n + 3 => simp; omega

/-- The parse length is 2 iff the first byte is in [64, 127]. -/
theorem varint_parse_len_2_iff (first : Nat) (h : first ≤ 255) :
    varint_parse_len_nat first = 2 ↔ (64 ≤ first ∧ first ≤ 127) := by
  unfold varint_parse_len_nat
  match hm : first / 64 with
  | 0 => simp; omega
  | 1 => simp; omega
  | 2 => simp; omega
  | n + 3 => simp; omega

/-- The parse length is 4 iff the first byte is in [128, 191]. -/
theorem varint_parse_len_4_iff (first : Nat) (h : first ≤ 255) :
    varint_parse_len_nat first = 4 ↔ (128 ≤ first ∧ first ≤ 191) := by
  unfold varint_parse_len_nat
  match hm : first / 64 with
  | 0 => simp; omega
  | 1 => simp; omega
  | 2 => simp; omega
  | n + 3 => simp; omega

/-- The parse length is 8 iff the first byte is in [192, 255]. -/
theorem varint_parse_len_8_iff (first : Nat) (h : first ≤ 255) :
    varint_parse_len_nat first = 8 ↔ (192 ≤ first ∧ first ≤ 255) := by
  unfold varint_parse_len_nat
  match hm : first / 64 with
  | 0 => simp; omega
  | 1 => simp; omega
  | 2 => simp; omega
  | n + 3 => simp; omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §2  varint_len_nat value-range biconditionals
--
-- Strengthens the one-directional lemmas in Varint.lean to ↔ form.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- The encoding length is 1 iff the value is in [0, 63]. -/
theorem varint_len_nat_1_iff (v : Nat) (hv : v ≤ MAX_VAR_INT) :
    varint_len_nat v = 1 ↔ v ≤ 63 := by
  simp only [varint_len_nat]
  by_cases h1 : v ≤ 63 <;>
  by_cases h2 : v ≤ 16383 <;>
  by_cases h3 : v ≤ 1073741823 <;>
  simp [h1, h2, h3] <;> omega

/-- The encoding length is 2 iff the value is in [64, 16383]. -/
theorem varint_len_nat_2_iff (v : Nat) (hv : v ≤ MAX_VAR_INT) :
    varint_len_nat v = 2 ↔ (64 ≤ v ∧ v ≤ 16383) := by
  simp only [varint_len_nat]
  by_cases h1 : v ≤ 63 <;>
  by_cases h2 : v ≤ 16383 <;>
  by_cases h3 : v ≤ 1073741823 <;>
  simp [h1, h2, h3] <;> omega

/-- The encoding length is 4 iff the value is in [16384, 1073741823]. -/
theorem varint_len_nat_4_iff (v : Nat) (hv : v ≤ MAX_VAR_INT) :
    varint_len_nat v = 4 ↔ (16384 ≤ v ∧ v ≤ 1073741823) := by
  simp only [varint_len_nat]
  by_cases h1 : v ≤ 63 <;>
  by_cases h2 : v ≤ 16383 <;>
  by_cases h3 : v ≤ 1073741823 <;>
  simp [h1, h2, h3] <;> omega

/-- The encoding length is 8 iff the value is in [1073741824, MAX_VAR_INT]. -/
theorem varint_len_nat_8_iff (v : Nat) (hv : v ≤ MAX_VAR_INT) :
    varint_len_nat v = 8 ↔ (1073741824 ≤ v ∧ v ≤ MAX_VAR_INT) := by
  unfold MAX_VAR_INT at *
  simp only [varint_len_nat]
  by_cases h1 : v ≤ 63 <;>
  by_cases h2 : v ≤ 16383 <;>
  by_cases h3 : v ≤ 1073741823 <;>
  simp [h1, h2, h3] <;> omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §3  Tag-bit / value-bit non-overlap
--
-- For each encoding length, the 2-bit tag constant and the value bits
-- occupy non-overlapping bit positions.  This justifies the use of
-- arithmetic addition in place of bitwise OR in the Lean model.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- 2-byte tag (0x4000 = 2^14) does not overlap with value bits (v ≤ 2^14−1).
    Proves: v + 0x4000 < 0x8000, so bit 14 is the tag, bits 0–13 are value. -/
theorem varint_tag2_nooverlap (v : Nat) (h : v ≤ 16383) :
    v + 16384 < 32768 := by omega

/-- 4-byte tag (0x80000000 = 2^31) does not overlap with value bits (v ≤ 2^30−1).
    Proves: v + 2^31 < 2^32, so bits 31 is the tag, bits 0–29 are value. -/
theorem varint_tag4_nooverlap (v : Nat) (h : v ≤ 1073741823) :
    v + 2147483648 < 4294967296 := by omega

/-- 8-byte tag (0xC000000000000000 = 3·2^62) does not overlap with value bits
    (v ≤ 2^62−1).  Proves: v + 3·2^62 < 2^64 (tag bits 62–63, value bits 0–61).
    Note: omega handles 64-bit scale arithmetic in Lean 4 without Mathlib. -/
theorem varint_tag8_nooverlap (v : Nat) (h : v ≤ 4611686018427387903) :
    v + 13835058055282163712 < 18446744073709551616 := by omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §4  varint_tag_consistency — universal first-byte tag theorem
--
-- Strengthens `varint_first_byte_tag` (existential) to universal: for
-- ANY first byte `b` obtained from `varint_encode v`, the parse length
-- equals the encoding length.  This follows from determinism of
-- `varint_encode`.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- For any encoding of `v`, the first byte's 2-bit tag records exactly
    `varint_len_nat v`.  This is the universal form of RFC 9000 §16's
    self-delimiting property. -/
theorem varint_tag_consistency (v : Nat) (hv : v ≤ MAX_VAR_INT) :
    ∀ (b : Nat) (rest : List Nat),
    varint_encode v = some (b :: rest) →
    varint_parse_len_nat b = varint_len_nat v := by
  -- Extract the canonical (b₀, rest₀) from the existential
  obtain ⟨b₀, rest₀, henc₀, htag₀⟩ := varint_first_byte_tag v hv
  intro b rest henc
  -- varint_encode is a function, so both encodings must agree
  have hlist : b :: rest = b₀ :: rest₀ := by
    have := Option.some.inj (henc.symm.trans henc₀)
    exact this
  have hb : b = b₀ := by
    have := List.cons.inj hlist
    exact this.1
  rw [hb]
  exact htag₀

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §5  Partition theorems
--
-- The four first-byte ranges partition [0, 255]; the four value ranges
-- partition [0, MAX_VAR_INT].  Together these confirm that every valid
-- varint input and every valid first byte falls into exactly one class.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Every first byte in [0,255] belongs to exactly one of the four
    length classes, with the parse length given. -/
theorem varint_parse_len_partition (first : Nat) (h : first ≤ 255) :
    (first ≤ 63 ∧ varint_parse_len_nat first = 1) ∨
    (64 ≤ first ∧ first ≤ 127 ∧ varint_parse_len_nat first = 2) ∨
    (128 ≤ first ∧ first ≤ 191 ∧ varint_parse_len_nat first = 4) ∨
    (192 ≤ first ∧ varint_parse_len_nat first = 8) := by
  unfold varint_parse_len_nat
  match hm : first / 64 with
  | 0 => exact Or.inl ⟨by omega, by simp⟩
  | 1 => exact Or.inr (Or.inl ⟨by omega, by omega, by simp⟩)
  | 2 => exact Or.inr (Or.inr (Or.inl ⟨by omega, by omega, by simp⟩))
  | n + 3 => exact Or.inr (Or.inr (Or.inr ⟨by omega, by simp⟩))

/-- Every valid varint value belongs to exactly one of the four
    length classes, with the encoding length given. -/
theorem varint_len_partition (v : Nat) (hv : v ≤ MAX_VAR_INT) :
    (v ≤ 63 ∧ varint_len_nat v = 1) ∨
    (64 ≤ v ∧ v ≤ 16383 ∧ varint_len_nat v = 2) ∨
    (16384 ≤ v ∧ v ≤ 1073741823 ∧ varint_len_nat v = 4) ∨
    (1073741824 ≤ v ∧ varint_len_nat v = 8) := by
  simp only [varint_len_nat]
  by_cases h1 : v ≤ 63 <;>
  by_cases h2 : v ≤ 16383 <;>
  by_cases h3 : v ≤ 1073741823 <;>
  simp [h1, h2, h3] <;> omega

/-- The two-length class (parse length = 2) and the one-length class
    (parse length = 1) have non-overlapping first-byte ranges.
    Derived from the §1 biconditionals. -/
theorem varint_parse_len_1_2_disjoint (first : Nat) (h : first ≤ 255) :
    ¬ (varint_parse_len_nat first = 1 ∧ varint_parse_len_nat first = 2) := by
  intro ⟨h1, h2⟩; simp [h1] at h2

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- Concrete examples
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- §1 boundary examples
example : varint_parse_len_nat 0 = 1 := by decide
example : varint_parse_len_nat 63 = 1 := by decide
example : varint_parse_len_nat 64 = 2 := by decide
example : varint_parse_len_nat 127 = 2 := by decide
example : varint_parse_len_nat 128 = 4 := by decide
example : varint_parse_len_nat 191 = 4 := by decide
example : varint_parse_len_nat 192 = 8 := by decide
example : varint_parse_len_nat 255 = 8 := by decide

-- §2 boundary examples
example : varint_len_nat 0 = 1 := by decide
example : varint_len_nat 63 = 1 := by decide
example : varint_len_nat 64 = 2 := by decide
example : varint_len_nat 16383 = 2 := by decide
example : varint_len_nat 16384 = 4 := by decide
example : varint_len_nat 1073741823 = 4 := by decide
example : varint_len_nat 1073741824 = 8 := by decide
example : varint_len_nat MAX_VAR_INT = 8 := by decide

-- §3 non-overlap: concrete values
example : (37 : Nat) + 16384 < 32768 := by decide
example : (16383 : Nat) + 16384 < 32768 := by decide
example : (1073741823 : Nat) + 2147483648 < 4294967296 := by decide

-- §4 tag consistency: specific encodings
example : varint_encode 37 = some [37] := by decide
example : varint_encode 15293 = some [123, 189] := by native_decide
example : ∀ b rest, varint_encode 37 = some (b :: rest) →
    varint_parse_len_nat b = varint_len_nat 37 :=
  varint_tag_consistency 37 (by decide)

end VarIntTag
