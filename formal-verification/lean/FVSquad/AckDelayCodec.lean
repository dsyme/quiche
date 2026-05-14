-- Copyright (C) 2018-2025, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- AckDelayCodec.lean
--
-- Formal specification and proofs for the QUIC ACK delay encode/decode codec.
--
-- Source: quiche/src/lib.rs (~L4487-4497 encoder, ~L8173-8182 decoder)
--         quiche/src/transport_params.rs (ack_delay_exponent validation)
--
-- Model:
--   encode(delay_micros, exp) = delay_micros / 2^exp
--   decode(encoded,      exp) = encoded * 2^exp
--
-- The exponent satisfies 0 ≤ exp ≤ 20 (validated at transport parameter
-- negotiation; RFC 9000 §18.2).  Default is 3.
--
-- What this model captures:
--   ✅ Integer encode/decode arithmetic
--   ✅ Round-trip identity on multiples of 2^exp
--   ✅ Floor property for non-multiples
--   ✅ Monotonicity of encode and decode
--   ✅ Exponent bound enforcement
--   ✅ Edge cases: exp=0, delay=0, exp=20
-- What is abstracted/omitted:
--   ⚠️  u64 overflow on decode (modelled as unbounded Nat)
--   ⚠️  varint size limit on encoded value (MAX_VAR_INT = 2^62 - 1)
--   ⚠️  Connection-level negotiation of the exponent

namespace AckDelayCodec

-- ---------------------------------------------------------------------------
-- Constants

/-- Maximum allowed ack_delay_exponent (RFC 9000 §18.2). -/
def MAX_EXPONENT : Nat := 20

-- ---------------------------------------------------------------------------
-- Model functions

/-- Encode an ACK delay: divide the raw microsecond value by 2^exp.
    Models: `ack_delay / 2^ack_delay_exponent` in lib.rs ~L4490. -/
def encode (delayMicros : Nat) (exp : Nat) : Nat :=
  delayMicros / 2^exp

/-- Decode an ACK delay: multiply the wire value by 2^exp.
    Models: `ack_delay * 2^ack_delay_exponent` in lib.rs ~L8178.
    Overflow is modelled as unbounded Nat (Rust uses checked_mul). -/
def decode (encoded : Nat) (exp : Nat) : Nat :=
  encoded * 2^exp

-- ---------------------------------------------------------------------------
-- Basic evaluation examples

#eval encode 1000 3   -- 125
#eval decode 125 3    -- 1000
#eval encode 0 3      -- 0
#eval encode 1001 3   -- 125 (truncation)
#eval decode (encode 1001 3) 3  -- 1000 (floor to multiple of 8)
#eval encode 42 0     -- 42

-- ---------------------------------------------------------------------------
-- Core round-trip theorem: exact round-trip on multiples of 2^exp

/-- If `d` is exactly divisible by `2^exp`, encoding then decoding recovers `d`. -/
theorem roundtrip_exact (d exp : Nat) (h : 2^exp ∣ d) :
    decode (encode d exp) exp = d :=
  Nat.div_mul_cancel h

-- ---------------------------------------------------------------------------
-- Floor property

/-- The round-trip is always ≤ the original value. -/
theorem roundtrip_le (d exp : Nat) :
    decode (encode d exp) exp ≤ d :=
  Nat.div_mul_le_self d (2^exp)

/-- The round-trip value is always divisible by 2^exp. -/
theorem roundtrip_divisible (d exp : Nat) :
    2^exp ∣ decode (encode d exp) exp :=
  Nat.dvd_mul_left _ _

/-- The gap between original and round-trip is strictly less than 2^exp.
    Equivalently, decode(encode(d)) is the floor of d to the nearest
    multiple of 2^exp. -/
theorem roundtrip_gap_lt (d exp : Nat) :
    d - decode (encode d exp) exp < 2^exp := by
  simp only [encode, decode]
  have hlt  : d % 2^exp < 2^exp   := Nat.mod_lt d (Nat.pow_pos (by decide))
  have hmod : d % 2^exp = d - 2^exp * (d / 2^exp) := Nat.mod_def d (2^exp)
  have hcomm : d / 2^exp * 2^exp = 2^exp * (d / 2^exp) := Nat.mul_comm _ _
  omega

-- ---------------------------------------------------------------------------
-- Monotonicity

/-- Encoding is monotone: larger delay → larger encoded value. -/
theorem encode_mono (d1 d2 exp : Nat) (h : d1 ≤ d2) :
    encode d1 exp ≤ encode d2 exp :=
  Nat.div_le_div_right h

/-- Decoding is monotone: larger encoded value → larger decoded value. -/
theorem decode_mono (e1 e2 exp : Nat) (h : e1 ≤ e2) :
    decode e1 exp ≤ decode e2 exp :=
  Nat.mul_le_mul_right _ h

/-- Encoding is antitone in the exponent: larger exponent → smaller encoded value. -/
theorem encode_antitone_exp (d exp1 exp2 : Nat) (h : exp1 ≤ exp2) :
    encode d exp2 ≤ encode d exp1 := by
  simp only [encode]
  apply Nat.div_le_div_left
  · exact Nat.pow_le_pow_right (by decide) h
  · exact Nat.pow_pos (by decide)

-- ---------------------------------------------------------------------------
-- Identity at exponent 0

/-- With exponent 0, encoding is the identity. -/
theorem encode_exp_zero (d : Nat) : encode d 0 = d := by simp [encode]

/-- With exponent 0, decoding is the identity. -/
theorem decode_exp_zero (e : Nat) : decode e 0 = e := by simp [decode]

/-- With exponent 0, round-trip is exact for all values. -/
theorem roundtrip_exp_zero (d : Nat) : decode (encode d 0) 0 = d := by
  simp [encode, decode]

-- ---------------------------------------------------------------------------
-- Zero delay

/-- Encoding zero gives zero. -/
theorem encode_zero (exp : Nat) : encode 0 exp = 0 := by simp [encode]

/-- Decoding zero gives zero. -/
theorem decode_zero (exp : Nat) : decode 0 exp = 0 := by simp [decode]

-- ---------------------------------------------------------------------------
-- Exponent bounds

/-- Valid exponents are at most MAX_EXPONENT (20). -/
abbrev validExponent (exp : Nat) : Prop := exp ≤ MAX_EXPONENT

/-- The default exponent (3) is valid. -/
theorem default_exponent_valid : validExponent 3 := by decide

/-- The maximum exponent (20) is valid. -/
theorem max_exponent_valid : validExponent MAX_EXPONENT := by decide

-- ---------------------------------------------------------------------------
-- Encoded value bound

/-- If the raw delay ≤ bound * 2^exp, the encoded value ≤ bound. -/
theorem encode_bound (d exp bound : Nat) (h : d ≤ bound * 2^exp) :
    encode d exp ≤ bound :=
  calc d / 2^exp ≤ (bound * 2^exp) / 2^exp := Nat.div_le_div_right h
    _ = bound := Nat.mul_div_cancel bound (Nat.pow_pos (by decide))

-- ---------------------------------------------------------------------------
-- Idempotence: decode ∘ encode is idempotent

/-- Applying encode-decode twice gives the same result as once.
    After one round-trip the value is already a multiple of 2^exp. -/
theorem roundtrip_idempotent (d exp : Nat) :
    decode (encode (decode (encode d exp) exp) exp) exp =
    decode (encode d exp) exp := by
  simp only [encode, decode]
  rw [Nat.mul_div_cancel _ (Nat.pow_pos (by decide))]

-- ---------------------------------------------------------------------------
-- Decidable spot checks (mirror Rust unit tests / transport_params.rs)

example : encode 1000 3 = 125                        := by decide
example : decode 125  3 = 1000                       := by decide
example : decode (encode 1000 3) 3 = 1000            := by decide
example : encode 1007 3 = 125                        := by decide  -- truncation
example : decode (encode 1007 3) 3 = 1000            := by decide  -- floor
example : encode 42 0 = 42                           := by decide  -- exp=0 identity
example : decode 42 0 = 42                           := by decide
example : encode (2^20) 20 = 1                       := by decide  -- max exponent
example : decode 1 20 = 2^20                         := by decide
example : decode (encode (2^20 * 5) 20) 20 = 2^20*5 := by decide
example : encode 0 5 = 0                             := by decide  -- zero delay
example : decode 0 5 = 0                             := by decide

end AckDelayCodec
