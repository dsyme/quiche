-- Copyright (C) 2025, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause

/-!
# QPACK/HPACK Integer Encoding — RFC 7541 §5.1

Formal verification of `encode_int` and `decode_int` from
`quiche/src/h3/qpack/encoder.rs` and `quiche/src/h3/qpack/decoder.rs`.

QPACK (RFC 9204) and HPACK (RFC 7541) encode unsigned integers using a
variable-length base-128 continuation scheme.  A `prefix` parameter (1–7 bits)
controls how many low bits of the first byte carry the integer; the remaining
high bits hold flags or opcodes set by the caller via the `first` parameter.

## What this file verifies

1. **Auxiliary round-trip**: `decodeAux (encodeAux v) = some v` for all `v`.
2. **Top-level round-trip**: `decodeInt (encodeInt v p) p = some v` for `p ≥ 1`.
3. **Single-byte case**: `v < 2^p - 1 → encodeInt v p = [v]`.
4. **Minimum multi-byte**: `encodeInt (2^p - 1) p = [2^p - 1, 0]` (two bytes).
5. **`encodeAux` / `encodeInt` non-empty** for all inputs.
6. **Zero encoding**: `encodeInt 0 p = [0]` for `p ≥ 1`.
7. **Decode single byte**: `v < 2^p - 1 → decodeInt [v] p = some v`.
8. **`decodeAux` single last byte**: `b < 128 → decodeAux [b] = some b`.
9. **`encodeInt` multi-byte head**: first byte equals `2^p - 1` when `v ≥ 2^p-1`.
10. **RFC 7541 §5.1 Example** and concrete round-trips (`native_decide`).

## Modelling choices

- The `first` parameter (flag bits OR-ed into the first byte's high bits) is
  abstracted away — the model sets `first = 0`.  All callers ensure
  `first & mask == 0`, so the round-trip holds.
- Buffer mutation, cursor state, and error propagation are NOT modelled.
- Integer overflow (checked via `checked_shl`/`checked_add` in Rust) is NOT
  modelled; the Lean model uses unbounded `Nat` arithmetic.
- `decodeAux` uses a `List Nat → Option Nat` formulation matching the structure
  of the Rust `while` loop; the continuation bit is `b ≥ 128`.
-/

namespace QPACKInteger

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §1  Pure functional model
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Encode base-128 continuation bytes for residual value `v`.
    Mirrors the `while v >= 128` loop in `encode_int` (encoder.rs:133-138):
      - If `v < 128`: write one byte `v` (no continuation bit, bit 7 clear).
      - Otherwise: write `v % 128 + 128` (low 7 bits + continuation bit),
        then recurse on `v / 128`. -/
def encodeAux (v : Nat) : List Nat :=
  if v < 128 then [v]
  else (v % 128 + 128) :: encodeAux (v / 128)
termination_by v
decreasing_by apply Nat.div_lt_self <;> omega

/-- Encode integer `v` with a `p`-bit prefix (1 ≤ p ≤ 7).
    Models `encode_int(v, first=0, prefix=p, buf)` from encoder.rs:120-147.
    Returns the bytes written (excluding any `first` high-bit flags). -/
def encodeInt (v : Nat) (p : Nat) : List Nat :=
  let mask := 2 ^ p - 1
  if v < mask then [v]
  else mask :: encodeAux (v - mask)

/-- Decode base-128 continuation bytes, reconstructing the residual value.
    Mirrors the `while b.cap() > 0` loop in `decode_int` (decoder.rs:221-237).
    All bytes except the last have bit 7 set (`b ≥ 128`); the last byte has
    bit 7 clear (`b < 128`). -/
def decodeAux : List Nat → Option Nat
  | []        => none
  | b :: rest =>
    if b < 128 then some b
    else match decodeAux rest with
         | none   => none
         | some r => some (b % 128 + 128 * r)

/-- Decode an integer from byte list `bytes` with prefix `p`.
    Models `decode_int(b, prefix=p)` from decoder.rs:212-240.
    Uses `b % 2^p` (arithmetic mask) instead of `b & (2^p - 1)` (bitwise);
    they are equivalent when `b < 2^p`, which holds for all encoded first bytes. -/
def decodeInt (bytes : List Nat) (p : Nat) : Option Nat :=
  match bytes with
  | []        => none
  | b :: rest =>
    let mask := 2 ^ p - 1
    let val  := b % 2 ^ p
    if val < mask then some val
    else match decodeAux rest with
         | none       => none
         | some extra => some (mask + extra)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §2  Helper: 2^p ≥ 1 and related power-of-two bounds
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- `2^p ≥ 2` for `p ≥ 1`. -/
private theorem two_pow_ge_two {p : Nat} (hp : 1 ≤ p) : 2 ≤ 2 ^ p := by
  cases p with
  | zero     => omega
  | succ n   =>
    simp only [Nat.pow_succ]
    have : 1 ≤ 2 ^ n := Nat.one_le_two_pow
    omega

/-- `2^p - 1 < 2^p`. -/
private theorem mask_lt_pow {p : Nat} : 2 ^ p - 1 < 2 ^ p := by
  have : 1 ≤ 2 ^ p := Nat.one_le_two_pow
  omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §3  Auxiliary lemmas
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- `encodeAux` always produces at least one byte. -/
theorem encodeAux_nonempty (v : Nat) : encodeAux v ≠ [] := by
  unfold encodeAux
  by_cases h : v < 128
  · simp [h]
  · simp [h]

/-- `encodeInt` always produces at least one byte. -/
theorem encodeInt_nonempty (v : Nat) (p : Nat) : encodeInt v p ≠ [] := by
  unfold encodeInt
  simp only []
  by_cases h : v < 2 ^ p - 1
  · simp [h]
  · simp [h]

/-- The single last continuation byte (bit 7 clear) decodes to itself. -/
theorem decodeAux_single (b : Nat) (h : b < 128) : decodeAux [b] = some b := by
  simp [decodeAux, h]

/-- `decodeAux` round-trip: `decodeAux (encodeAux v) = some v` for all `v`. -/
theorem decodeAux_encodeAux (v : Nat) : decodeAux (encodeAux v) = some v :=
  Nat.strongRecOn v fun n ih => by
    unfold encodeAux
    by_cases h : n < 128
    · -- n < 128: single byte, decodes directly
      simp [h, decodeAux]
    · -- n ≥ 128: encodeAux n = (n%128+128) :: encodeAux (n/128)
      have hlt : n / 128 < n := Nat.div_lt_self (by omega) (by omega)
      have hih := ih (n / 128) hlt
      simp only [if_neg h]
      -- b = n % 128 + 128; since n%128 < 128, we have 128 ≤ b < 256
      have hb : ¬(n % 128 + 128 < 128) := by omega
      -- unfold decodeAux for the cons case
      unfold decodeAux
      rw [if_neg hb, hih]
      simp only []
      -- goal: some ((n%128+128) % 128 + 128 * (n/128)) = some n
      congr 1
      have hmod : (n % 128 + 128) % 128 = n % 128 := by omega
      rw [hmod]; omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §4  Key theorems
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- **Single-byte case**: when `v < 2^p - 1`, the encoding is a single byte
    containing `v`.  Mirrors `encode_int` line 127: `b.put_u8(first | v as u8)`. -/
theorem encodeInt_single_byte (v : Nat) (p : Nat) (h : v < 2 ^ p - 1) :
    encodeInt v p = [v] := by
  unfold encodeInt; simp only []; rw [if_pos h]

/-- **Minimum multi-byte**: `v = mask = 2^p - 1` requires exactly two bytes:
    `[mask, 0]`.  The first byte is the sentinel; `0` is the single continuation
    byte encoding the zero residual. -/
theorem encodeInt_min_multibyte (p : Nat) :
    encodeInt (2 ^ p - 1) p = [2 ^ p - 1, 0] := by
  unfold encodeInt; simp only []
  rw [if_neg (Nat.lt_irrefl _), Nat.sub_self]
  simp [encodeAux]

/-- **Zero encoding**: `encodeInt 0 p = [0]` for any `p ≥ 1`. -/
theorem encodeInt_zero (p : Nat) (hp : 1 ≤ p) : encodeInt 0 p = [0] := by
  unfold encodeInt; simp only []
  have hlt : 0 < 2 ^ p - 1 := by
    have := two_pow_ge_two hp; omega
  exact if_pos hlt

/-- **Decode single byte**: `decodeInt [v] p = some v` when `v < 2^p - 1`. -/
theorem decodeInt_single_byte (v : Nat) (p : Nat) (h : v < 2 ^ p - 1) :
    decodeInt [v] p = some v := by
  unfold decodeInt; simp only []
  rw [Nat.mod_eq_of_lt (by omega), if_pos h]

/-- **Multi-byte head byte**: when `v ≥ 2^p - 1`, the first encoded byte is
    the sentinel value `2^p - 1`.  This signals to the decoder that
    continuation bytes follow (RFC 7541 §5.1). -/
theorem encodeInt_multibyte_head (v : Nat) (p : Nat) (h : 2 ^ p - 1 ≤ v) :    (encodeInt v p).head? = some (2 ^ p - 1) := by
  unfold encodeInt; simp only []
  rw [if_neg (by omega : ¬v < 2 ^ p - 1)]
  simp

/-- **Top-level round-trip**: `decodeInt (encodeInt v p) p = some v`
    for all `v` and all `p ≥ 1`.
    This is the central correctness property of the RFC 7541 §5.1 codec. -/
theorem decodeInt_encodeInt (v : Nat) (p : Nat) :
    decodeInt (encodeInt v p) p = some v := by
  by_cases hv : v < 2 ^ p - 1
  · -- Single-byte case
    rw [encodeInt_single_byte v p hv]
    exact decodeInt_single_byte v p hv
  · -- Multi-byte case: encodeInt v p = (2^p-1) :: encodeAux (v - (2^p-1))
    have hv' : 2 ^ p - 1 ≤ v := Nat.not_lt.mp hv
    have henc : encodeInt v p = (2 ^ p - 1) :: encodeAux (v - (2 ^ p - 1)) := by
      unfold encodeInt; simp only []; rw [if_neg hv]
    rw [henc]
    unfold decodeInt
    simp only []
    rw [Nat.mod_eq_of_lt mask_lt_pow, if_neg (Nat.lt_irrefl _)]
    rw [decodeAux_encodeAux]
    simp only []
    congr 1
    omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §5  Concrete examples (native_decide)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- RFC 7541 §5.1 example: encode(1337, prefix=5) = [0x1F, 0x9A, 0x0A]
-- mask=31; 1337-31=1306; 1306%128+128=154=0x9A; 1306/128=10=0x0A
example : encodeInt 1337 5 = [31, 154, 10] := by native_decide

-- RFC 7541 §5.1: encode(10, prefix=5) = [0x0A] (single byte, 10 < 31)
example : encodeInt 10 5 = [10] := by native_decide

-- encode(42, prefix=8) = [42] per Rust test encode_int3
-- (mask=255; 42 < 255 so single byte)
example : encodeInt 42 8 = [42] := by native_decide

-- Round-trip for RFC 7541 example value
example : decodeInt (encodeInt 1337 5) 5 = some 1337 := by native_decide

-- Round-trip for v=0 with various prefixes
example : decodeInt (encodeInt 0 5) 5 = some 0 := by native_decide
example : decodeInt (encodeInt 0 1) 1 = some 0 := by native_decide
example : decodeInt (encodeInt 0 7) 7 = some 0 := by native_decide

-- Round-trip at boundary: v = mask (minimum multi-byte value)
example : decodeInt (encodeInt 31 5) 5 = some 31 := by native_decide
example : decodeInt (encodeInt 1 1) 1 = some 1 := by native_decide

-- Large value round-trip (validates the continuation chain)
example : decodeInt (encodeInt 100000 7) 7 = some 100000 := by native_decide

end QPACKInteger
