-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of the QUIC variable-length integer
-- codec in `octets/src/lib.rs`.
--
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- Approximations / abstractions:
--   - Buffer mutation, offsets, and error paths are NOT modelled.
--     Only the pure "value → byte list → value" mapping is captured.
--   - All functions operate on Nat (unbounded natural numbers).
--   - Bitwise OR (|||) in the Rust encoder is modelled as addition (+),
--     which is equivalent when the operands share no set bits (the tag
--     constant occupies a bit position that the value cannot reach given
--     the range guard). This is the key abstraction in the model.
--   - The Lean encode uses arithmetic (addition/division/mod) to enable
--     round-trip proofs using `omega` alone, without Mathlib bitwise lemmas.

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §1 Constants
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Maximum representable QUIC variable-length integer (2^62 - 1).
def MAX_VAR_INT : Nat := 4611686018427387903

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §2 Length helper functions
--    Mirror `varint_len` and `varint_parse_len` in octets/src/lib.rs.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Number of bytes required to encode `v` as a QUIC varint.
    Mirrors `varint_len` (octets/src/lib.rs:810-822). -/
def varint_len_nat (v : Nat) : Nat :=
  if v ≤ 63 then 1
  else if v ≤ 16383 then 2
  else if v ≤ 1073741823 then 4
  else 8

/-- Parse the encoded length from the first byte.
    Mirrors `varint_parse_len` (octets/src/lib.rs:825-833).
    `first / 64` extracts the top 2 bits (equivalent to `first >> 6`). -/
def varint_parse_len_nat (first : Nat) : Nat :=
  match first / 64 with
  | 0 => 1
  | 1 => 2
  | 2 => 4
  | _ => 8

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §3 Codec — arithmetic formulation
--
-- The Rust encoder uses bitwise OR to set the 2-bit tag in the first byte.
-- The Lean model uses addition, which is equivalent when the operands have
-- no overlapping bits (the tag bit position is strictly above any bit that
-- `v` can set, given the range guard):
--   1-byte: v ≤ 63 = 2^6-1, tag = 0, no overlap possible
--   2-byte: v ≤ 16383 = 2^14-1, tag = 0x4000 = 2^14, no overlap
--   4-byte: v ≤ 2^30-1, tag = 0x80000000 = 2^31, no overlap
--   8-byte: v ≤ 2^62-1, tag = 0xC000000000000000 = 3*2^62, no overlap
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Encode `v` as a big-endian list of bytes.  Returns `none` if `v` exceeds
    MAX_VAR_INT (mirrors the `unreachable!()` / panic path in the Rust).
    The 2-bit tag is written by ADDING the appropriate constant rather than
    OR-ing it — they are equivalent (see §3 above). -/
def varint_encode (v : Nat) : Option (List Nat) :=
  if v ≤ 63 then
    some [v]
  else if v ≤ 16383 then
    let w := v + 16384
    some [w / 256, w % 256]
  else if v ≤ 1073741823 then
    let w := v + 2147483648
    some [w / 16777216, (w / 65536) % 256, (w / 256) % 256, w % 256]
  else if v ≤ MAX_VAR_INT then
    let w := v + 13835058055282163712
    some [w / 72057594037927936,
          (w / 281474976710656) % 256,
          (w / 1099511627776) % 256,
          (w / 4294967296) % 256,
          (w / 16777216) % 256,
          (w / 65536) % 256,
          (w / 256) % 256,
          w % 256]
  else
    none

/-- Decode a big-endian byte list to a value, stripping the 2-bit tag.
    The tag is stripped by `% mask` (arithmetic modulo), equivalent to the
    Rust masking (`& 0x3FFF`, etc.) since mask = 2^k - 1. -/
def varint_decode (bytes : List Nat) : Option Nat :=
  match bytes with
  | [b0] =>
    some (b0 % 64)
  | [b0, b1] =>
    some ((b0 * 256 + b1) % 16384)
  | [b0, b1, b2, b3] =>
    some ((b0 * 16777216 + b1 * 65536 + b2 * 256 + b3) % 1073741824)
  | [b0, b1, b2, b3, b4, b5, b6, b7] =>
    some ((b0 * 72057594037927936 + b1 * 281474976710656 +
           b2 * 1099511627776 + b3 * 4294967296 +
           b4 * 16777216 + b5 * 65536 + b6 * 256 + b7) %
          4611686018427387904)
  | _ =>
    none

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §4 Proved theorems — structural properties of varint_len_nat
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

theorem varint_len_nat_1 {v : Nat} (h : v ≤ 63) : varint_len_nat v = 1 := by
  simp [varint_len_nat, if_pos h]

theorem varint_len_nat_2 {v : Nat} (h1 : 64 ≤ v) (h2 : v ≤ 16383) :
    varint_len_nat v = 2 := by
  simp [varint_len_nat, if_neg (by omega : ¬v ≤ 63), if_pos (by omega : v ≤ 16383)]

theorem varint_len_nat_4 {v : Nat} (h1 : 16384 ≤ v) (h2 : v ≤ 1073741823) :
    varint_len_nat v = 4 := by
  simp [varint_len_nat,
        if_neg (by omega : ¬v ≤ 63),
        if_neg (by omega : ¬v ≤ 16383),
        if_pos (by omega : v ≤ 1073741823)]

theorem varint_len_nat_8 {v : Nat} (h1 : 1073741824 ≤ v) (h2 : v ≤ MAX_VAR_INT) :
    varint_len_nat v = 8 := by
  simp [varint_len_nat,
        if_neg (by omega : ¬v ≤ 63),
        if_neg (by omega : ¬v ≤ 16383),
        if_neg (by omega : ¬v ≤ 1073741823)]

/-- varint_len_nat always returns a value in {1, 2, 4, 8} for valid inputs. -/
theorem varint_len_nat_valid (v : Nat) (hv : v ≤ MAX_VAR_INT) :
    varint_len_nat v = 1 ∨ varint_len_nat v = 2 ∨
    varint_len_nat v = 4 ∨ varint_len_nat v = 8 := by
  unfold varint_len_nat MAX_VAR_INT at *
  by_cases h1 : v ≤ 63
  · left; simp [if_pos h1]
  · by_cases h2 : v ≤ 16383
    · right; left; simp [if_neg h1, if_pos h2]
    · by_cases h3 : v ≤ 1073741823
      · right; right; left; simp [if_neg h1, if_neg h2, if_pos h3]
      · right; right; right; simp [if_neg h1, if_neg h2, if_neg h3]

/-- varint_parse_len_nat always returns a value in {1, 2, 4, 8}. -/
theorem varint_parse_len_nat_valid (first : Nat) :
    varint_parse_len_nat first = 1 ∨ varint_parse_len_nat first = 2 ∨
    varint_parse_len_nat first = 4 ∨ varint_parse_len_nat first = 8 := by
  unfold varint_parse_len_nat
  match h : first / 64 with
  | 0 => simp
  | 1 => simp
  | 2 => simp
  | n + 3 => simp

/-- varint_len_nat is monotone: larger values need at least as many bytes. -/
theorem varint_len_nat_mono {a b : Nat} (h : a ≤ b) :
    varint_len_nat a ≤ varint_len_nat b := by
  simp only [varint_len_nat]
  by_cases ha1 : a ≤ 63 <;> by_cases ha2 : a ≤ 16383 <;> by_cases ha3 : a ≤ 1073741823 <;>
  by_cases hb1 : b ≤ 63 <;> by_cases hb2 : b ≤ 16383 <;> by_cases hb3 : b ≤ 1073741823 <;>
  simp [ha1, ha2, ha3, hb1, hb2, hb3] <;> omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §5 Encoding length theorem
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- varint_encode produces exactly varint_len_nat v bytes. -/
theorem varint_encode_length (v : Nat) (hv : v ≤ MAX_VAR_INT) :
    ∃ bytes, varint_encode v = some bytes ∧ bytes.length = varint_len_nat v := by
  unfold varint_encode varint_len_nat MAX_VAR_INT at *
  by_cases h1 : v ≤ 63
  · exact ⟨[v], by simp [h1]⟩
  · by_cases h2 : v ≤ 16383
    · refine ⟨[(v + 16384) / 256, (v + 16384) % 256], ?_⟩
      simp [if_neg h1, if_pos h2]
    · by_cases h3 : v ≤ 1073741823
      · refine ⟨[(v + 2147483648) / 16777216,
                 (v + 2147483648) / 65536 % 256,
                 (v + 2147483648) / 256 % 256,
                 (v + 2147483648) % 256], ?_⟩
        simp [if_neg h1, if_neg h2, if_pos h3]
      · refine ⟨[(v + 13835058055282163712) / 72057594037927936,
                 (v + 13835058055282163712) / 281474976710656 % 256,
                 (v + 13835058055282163712) / 1099511627776 % 256,
                 (v + 13835058055282163712) / 4294967296 % 256,
                 (v + 13835058055282163712) / 16777216 % 256,
                 (v + 13835058055282163712) / 65536 % 256,
                 (v + 13835058055282163712) / 256 % 256,
                 (v + 13835058055282163712) % 256], ?_⟩
        simp [if_neg h1, if_neg h2, if_neg h3, (by omega : v ≤ 4611686018427387903)]

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §6 Round-trip correctness  decode(encode(v)) = v
--
-- The proof uses two arithmetic facts, both proved by `omega`:
--
--   (A) Byte reconstruction:
--       (w/256) * 256 + w%256 = w            (2-byte)
--       (w/16777216)*16777216 + ... + w%256 = w   (4-byte)
--       Generalisation: `omega` handles nested div/mod telescoping
--       for constant divisors via `(a/b)/c = a/(b*c)`.
--
--   (B) Modulo cancellation:
--       v < 2^k  →  (v + 2^k) % 2^k = v
--       Combined with (A): (w % 2^k = v) where w = v + tag.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- **THE KEY SAFETY PROPERTY**: For every valid QUIC integer value v,
    encoding v and then decoding the resulting bytes gives back v.

    The proof uses only `omega` (linear arithmetic with div/mod over Nat),
    without any bitwise lemmas or Mathlib. This is possible because:
    (1) The `%`-based decoder is arithmetically equivalent to the Rust
        bitwise-mask decoder (for power-of-2-minus-1 masks).
    (2) `omega` in Lean 4.29 handles nested div/mod for constant divisors,
        including the byte reconstruction and modulo cancellation steps. -/
theorem varint_round_trip (v : Nat) (hv : v ≤ MAX_VAR_INT) :
    ∃ bytes, varint_encode v = some bytes ∧ varint_decode bytes = some v := by
  simp only [varint_encode, varint_decode, MAX_VAR_INT] at *
  by_cases h1 : v ≤ 63
  · exact ⟨[v], by simp [h1], by simp; omega⟩
  · by_cases h2 : v ≤ 16383
    · exact ⟨[(v + 16384) / 256, (v + 16384) % 256],
             by simp [h1, h2],
             by simp; omega⟩
    · by_cases h3 : v ≤ 1073741823
      · exact ⟨[(v + 2147483648) / 16777216,
                (v + 2147483648) / 65536 % 256,
                (v + 2147483648) / 256 % 256,
                (v + 2147483648) % 256],
               by simp [h1, h2, h3],
               by simp; omega⟩
      · have hv' : v ≤ 4611686018427387903 := hv
        exact ⟨[(v + 13835058055282163712) / 72057594037927936,
                (v + 13835058055282163712) / 281474976710656 % 256,
                (v + 13835058055282163712) / 1099511627776 % 256,
                (v + 13835058055282163712) / 4294967296 % 256,
                (v + 13835058055282163712) / 16777216 % 256,
                (v + 13835058055282163712) / 65536 % 256,
                (v + 13835058055282163712) / 256 % 256,
                (v + 13835058055282163712) % 256],
               by simp [varint_encode, MAX_VAR_INT, h1, h2, h3, hv'],
               by simp [varint_decode]; omega⟩

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §7 First-byte tag theorem  (self-delimiting property)
--
-- The top 2 bits of the first encoded byte encode the length class.
-- `varint_parse_len_nat` applied to the first byte agrees with
-- `varint_len_nat` on the original value.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- The first byte of every encoded varint carries the 2-bit length tag,
    so `varint_parse_len_nat(first_byte) = varint_len_nat(v)`.
    This is the self-delimiting property of RFC 9000 §16. -/
theorem varint_first_byte_tag (v : Nat) (hv : v ≤ MAX_VAR_INT) :
    ∃ (b : Nat) (rest : List Nat),
    varint_encode v = some (b :: rest) ∧
    varint_parse_len_nat b = varint_len_nat v := by
  by_cases h1 : v ≤ 63
  · refine ⟨v, [], by simp [varint_encode, if_pos h1], ?_⟩
    simp only [varint_parse_len_nat, varint_len_nat, if_pos h1]
    -- b = v, v/64 = 0 since v ≤ 63
    have : v / 64 = 0 := by omega
    rw [this]
  · by_cases h2 : v ≤ 16383
    · refine ⟨(v + 16384) / 256, [(v + 16384) % 256],
             by simp [varint_encode, if_neg h1, if_pos h2], ?_⟩
      simp only [varint_parse_len_nat, varint_len_nat, if_neg h1, if_pos h2]
      -- b = (v+16384)/256, b/64 = (v+16384)/16384 = 1 for v ∈ [64,16383]
      have hb : (v + 16384) / 256 / 64 = 1 := by omega
      rw [hb]
    · by_cases h3 : v ≤ 1073741823
      · refine ⟨(v + 2147483648) / 16777216,
               [(v + 2147483648) / 65536 % 256,
                (v + 2147483648) / 256 % 256,
                (v + 2147483648) % 256],
               by simp [varint_encode, if_neg h1, if_neg h2, if_pos h3], ?_⟩
        simp only [varint_parse_len_nat, varint_len_nat, if_neg h1, if_neg h2, if_pos h3]
        -- b = (v+2^31)/2^24, b/64 = (v+2^31)/2^30 = 2 for v ∈ [16384,2^30-1]
        have hb : (v + 2147483648) / 16777216 / 64 = 2 := by omega
        rw [hb]
      · have hv' : v ≤ 4611686018427387903 := hv
        refine ⟨(v + 13835058055282163712) / 72057594037927936,
               [(v + 13835058055282163712) / 281474976710656 % 256,
                (v + 13835058055282163712) / 1099511627776 % 256,
                (v + 13835058055282163712) / 4294967296 % 256,
                (v + 13835058055282163712) / 16777216 % 256,
                (v + 13835058055282163712) / 65536 % 256,
                (v + 13835058055282163712) / 256 % 256,
                (v + 13835058055282163712) % 256],
               by simp [varint_encode, MAX_VAR_INT, if_neg h1, if_neg h2, if_neg h3, hv'], ?_⟩
        simp only [varint_parse_len_nat, varint_len_nat,
                   if_neg h1, if_neg h2, if_neg h3]
        -- b = (v+3*2^62)/2^56, b/64 = (v+3*2^62)/2^62 = 3 for v ∈ [2^30,2^62-1]
        have hb : (v + 13835058055282163712) / 72057594037927936 / 64 = 3 := by omega
        rw [hb]

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §8 UInt64 wrappers (for Rust type correspondence)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def varint_len (v : UInt64) : Nat := varint_len_nat v.toNat

def varint_parse_len (first : UInt8) : Nat := varint_parse_len_nat first.toNat

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §9 Concrete verification by native_decide
--     RFC 9000 §A.1 test vectors and boundary values
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Test vectors from RFC 9000 Appendix A
example : varint_encode 37 = some [0x25] := by native_decide
example : varint_encode 15293 = some [0x7b, 0xbd] := by native_decide
example : varint_encode 494878333 = some [0x9d, 0x7f, 0x3e, 0x7d] := by native_decide
example : varint_encode 151288809941952652 =
          some [0xc2, 0x19, 0x7c, 0x5e, 0xff, 0x14, 0xe8, 0x8c] := by native_decide

-- Decode round-trips for test vectors
example : varint_decode [0x25] = some 37 := by native_decide
example : varint_decode [0x7b, 0xbd] = some 15293 := by native_decide
example : varint_decode [0x9d, 0x7f, 0x3e, 0x7d] = some 494878333 := by native_decide
example : varint_decode [0xc2, 0x19, 0x7c, 0x5e, 0xff, 0x14, 0xe8, 0x8c] =
          some 151288809941952652 := by native_decide

-- Non-minimal encoding (37 encoded in 2 bytes) — also round-trips
example : varint_decode [0x40, 0x25] = some 37 := by native_decide

-- Boundary values for varint_len_nat
example : varint_len_nat 0 = 1 := by native_decide
example : varint_len_nat 63 = 1 := by native_decide
example : varint_len_nat 64 = 2 := by native_decide
example : varint_len_nat 16383 = 2 := by native_decide
example : varint_len_nat 16384 = 4 := by native_decide
example : varint_len_nat 1073741823 = 4 := by native_decide
example : varint_len_nat 1073741824 = 8 := by native_decide
example : varint_len_nat MAX_VAR_INT = 8 := by native_decide

-- varint_parse_len_nat for all 4 tag regions
example : varint_parse_len_nat 0x00 = 1 := by native_decide
example : varint_parse_len_nat 0x3F = 1 := by native_decide
example : varint_parse_len_nat 0x40 = 2 := by native_decide
example : varint_parse_len_nat 0x7F = 2 := by native_decide
example : varint_parse_len_nat 0x80 = 4 := by native_decide
example : varint_parse_len_nat 0xBF = 4 := by native_decide
example : varint_parse_len_nat 0xC0 = 8 := by native_decide
example : varint_parse_len_nat 0xFF = 8 := by native_decide
