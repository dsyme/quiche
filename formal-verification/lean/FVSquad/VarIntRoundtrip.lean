-- Copyright (C) 2025, Cloudflare, Inc.
-- All rights reserved.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/VarIntRoundtrip.lean
--
-- Cursor-level round-trip for QUIC variable-length integers (T23).
-- Proves: put_varint then freeze-get_varint = identity.
--
-- 🔬 Lean Squad — automated formal verification.
--
-- MODEL SCOPE:
--   • Imports FVSquad.Varint (pure model) and FVSquad.OctetsRoundtrip (cursor
--     infrastructure and freeze-pattern lemmas).
--   • OctetsMutState.putVarint: writes a QUIC varint into a mutable buffer.
--   • OctetsState.getVarint: reads a QUIC varint from a read-only cursor.
--   • The "freeze" pattern: write with putVarint, then read from OctetsState
--     positioned at the original offset.
--   • Roundtrip proved for 1-byte (v ≤ 63), 2-byte (v ≤ 16383), and 4-byte
--     (v ≤ 1073741823) encodings. 8-byte case (v ≥ 1073741824) is stated
--     with sorry pending a two-putU32-chain proof.
--
-- APPROXIMATIONS:
--   • Buffer mutation, lifetimes, and borrow semantics are not modelled.
--   • Error paths (BufferTooShortError) → Option.none.
--   • Byte values are Nat (unbounded). Range preconditions replace u8/u64.
--   • The Rust get_varint reads from OctetsMut; we model read-back from an
--     OctetsState (the freeze pattern), mirroring octets::OctetsMut::get_varint
--     called on a freshly-written buffer slice.

import FVSquad.Varint
import FVSquad.OctetsRoundtrip

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §1  putVarint — write a QUIC variable-length integer
--     Mirrors put_varint (octets/src/lib.rs:835–857).
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Write `v` as a QUIC varint (1, 2, 4, or 8 bytes) into `s`.
    The 2-bit length tag is embedded in the most-significant two bits of the
    first encoded byte using the arithmetic tag constants from Varint.lean.
    Returns `none` if the buffer lacks capacity or `v > MAX_VAR_INT`. -/
def OctetsMutState.putVarint (s : OctetsMutState) (v : Nat) : Option OctetsMutState :=
  if v ≤ 63 then
    s.putU8 v                              -- tag 00: 1 byte, top 2 bits = 00
  else if v ≤ 16383 then
    s.putU16 (v + 16384)                   -- tag 01: 2 bytes, +0x4000
  else if v ≤ 1073741823 then
    s.putU32 (v + 2147483648)              -- tag 10: 4 bytes, +0x80000000
  else if v ≤ MAX_VAR_INT then
    -- tag 11: 8 bytes, +0xC000000000000000
    -- Written as two consecutive u32 writes (big-endian high word, then low word).
    let w := v + 13835058055282163712      -- 0xC000000000000000
    match s.putU32 (w / 4294967296) with
    | some s' => s'.putU32 (w % 4294967296)
    | none    => none
  else none

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §2  getVarint — read a QUIC variable-length integer from OctetsState
--     Mirrors get_varint (octets/src/lib.rs:859–898).
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Read a QUIC varint from `s`.
    The top 2 bits of the first byte indicate the encoding length (1/2/4/8).
    Returns `none` if capacity is insufficient. -/
def OctetsState.getVarint (s : OctetsState) : Option (Nat × OctetsState) :=
  if s.off < s.buf.length then
    if (octListGet s.buf s.off) / 64 = 0 then
      -- 1-byte: top 2 bits = 00; value = byte0 (already ≤ 63)
      some (octListGet s.buf s.off, { s with off := s.off + 1 })
    else if (octListGet s.buf s.off) / 64 = 1 then
      -- 2-byte: top 2 bits = 01; strip tag, combine with byte1
      if s.off + 1 < s.buf.length then
        some ((octListGet s.buf s.off % 64) * 256 +
               octListGet s.buf (s.off + 1),
              { s with off := s.off + 2 })
      else none
    else if (octListGet s.buf s.off) / 64 = 2 then
      -- 4-byte: top 2 bits = 10; strip tag, combine with bytes 1-3
      if s.off + 3 < s.buf.length then
        some ((octListGet s.buf s.off % 64) * 16777216 +
               octListGet s.buf (s.off + 1) * 65536 +
               octListGet s.buf (s.off + 2) * 256 +
               octListGet s.buf (s.off + 3),
              { s with off := s.off + 4 })
      else none
    else
      -- 8-byte: top 2 bits = 11; strip tag, combine with bytes 1-7
      if s.off + 7 < s.buf.length then
        some ((octListGet s.buf s.off % 64) * 72057594037927936 +  -- 2^56
               octListGet s.buf (s.off + 1) * 281474976710656 +    -- 2^48
               octListGet s.buf (s.off + 2) * 1099511627776 +      -- 2^40
               octListGet s.buf (s.off + 3) * 4294967296 +         -- 2^32
               octListGet s.buf (s.off + 4) * 16777216 +
               octListGet s.buf (s.off + 5) * 65536 +
               octListGet s.buf (s.off + 6) * 256 +
               octListGet s.buf (s.off + 7),
              { s with off := s.off + 8 })
      else none
  else none

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §3  getVarint dispatch lemmas
--     These helpers resolve the if-chain in getVarint given a known tag value.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private theorem getVarint_tag0 (s : OctetsState)
    (hoff : s.off < s.buf.length)
    (htag : octListGet s.buf s.off / 64 = 0) :
    OctetsState.getVarint s =
      some (octListGet s.buf s.off, { s with off := s.off + 1 }) := by
  simp only [OctetsState.getVarint, if_pos hoff, if_pos htag]

private theorem getVarint_tag1 (s : OctetsState)
    (hoff1 : s.off + 1 < s.buf.length)
    (htag : octListGet s.buf s.off / 64 = 1) :
    OctetsState.getVarint s =
      some ((octListGet s.buf s.off % 64) * 256 +
             octListGet s.buf (s.off + 1),
            { s with off := s.off + 2 }) := by
  have hoff0 : s.off < s.buf.length := by omega
  simp only [OctetsState.getVarint, if_pos hoff0,
             if_neg (show octListGet s.buf s.off / 64 ≠ 0 by omega),
             if_pos htag, if_pos hoff1]

private theorem getVarint_tag2 (s : OctetsState)
    (hoff3 : s.off + 3 < s.buf.length)
    (htag : octListGet s.buf s.off / 64 = 2) :
    OctetsState.getVarint s =
      some ((octListGet s.buf s.off % 64) * 16777216 +
             octListGet s.buf (s.off + 1) * 65536 +
             octListGet s.buf (s.off + 2) * 256 +
             octListGet s.buf (s.off + 3),
            { s with off := s.off + 4 }) := by
  have hoff0 : s.off < s.buf.length := by omega
  simp only [OctetsState.getVarint, if_pos hoff0,
             if_neg (show octListGet s.buf s.off / 64 ≠ 0 by omega),
             if_neg (show octListGet s.buf s.off / 64 ≠ 1 by omega),
             if_pos htag, if_pos hoff3]

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §4  Roundtrip proofs — one theorem per encoding length
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- §4.1  1-byte case (v ≤ 63)

/-- Write v (≤ 63) with putU8, then read back with getVarint: returns v.
    Precondition: s.putU8 v = some s' (the put succeeded).
    The buffer at s.off contains v; the top 2 bits are 00 (tag = 0). -/
theorem putVarint_freeze_getVarint_1byte (s s' : OctetsMutState) (v : Nat)
    (hv : v ≤ 63) (h : s.putU8 v = some s') :
    OctetsState.getVarint { buf := s'.buf, off := s.off } =
      some (v, { buf := s'.buf, off := s.off + 1 }) := by
  -- Extract buffer contents from putU8 result
  simp only [OctetsMutState.putU8] at h
  by_cases hc : s.off < s.buf.length
  · rw [if_pos hc] at h; simp only [Option.some.injEq] at h; subst h
    -- s' = { buf := listSet s.buf s.off v, off := s.off + 1 }
    have hlen : (listSet s.buf s.off v).length = s.buf.length := listSet_length ..
    have hb0 : octListGet (listSet s.buf s.off v) s.off = v := by
      rw [← listGet_eq_octListGet]; exact listGet_set_eq s.buf s.off v hc
    -- Dispatch getVarint: tag = v / 64 = 0
    have htag : octListGet (listSet s.buf s.off v) s.off / 64 = 0 := by
      rw [hb0]; omega
    rw [getVarint_tag0 { buf := listSet s.buf s.off v, off := s.off }
          (by rw [hlen]; exact hc) htag, hb0]
  · rw [if_neg hc] at h; simp at h

-- §4.2  2-byte case (64 ≤ v ≤ 16383)

/-- Write v (64 ≤ v ≤ 16383) with putU16 (v + 0x4000), then read with
    getVarint: returns v.
    The first byte has top 2 bits = 01 (tag = 1); stripping gives v. -/
theorem putVarint_freeze_getVarint_2byte (s s' : OctetsMutState) (v : Nat)
    (hv1 : 64 ≤ v) (hv2 : v ≤ 16383) (h : s.putU16 (v + 16384) = some s') :
    OctetsState.getVarint { buf := s'.buf, off := s.off } =
      some (v, { buf := s'.buf, off := s.off + 2 }) := by
  -- Byte values after putU16 (v + 16384)
  have hb0 := putU16_freeze_byte0 s s' (v + 16384) h
  have hb1 := putU16_freeze_byte1 s s' (v + 16384) h
  have hlen : s'.buf.length = s.buf.length := putU16_len s s' (v + 16384) h
  -- Capacity: putU16 requires s.off + 1 < s.buf.length
  have hcap : s.off + 1 < s.buf.length := by
    simp only [OctetsMutState.putU16] at h
    by_cases hc : s.off + 1 < s.buf.length
    · exact hc
    · simp [if_neg hc] at h
  -- Tag check: b0 = (v + 16384) / 256 ∈ [64, 127], so b0 / 64 = 1
  have htag : octListGet s'.buf s.off / 64 = 1 := by
    rw [hb0]; omega
  -- Capacity for tag-1 read
  have hoff1 : s.off + 1 < s'.buf.length := by rw [hlen]; exact hcap
  -- Evaluate getVarint
  rw [getVarint_tag1 { buf := s'.buf, off := s.off } hoff1 htag, hb0, hb1]
  -- Prove arithmetic: ((v+16384)/256 % 64) * 256 + (v+16384)%256 = v
  simp only [Option.some.injEq, Prod.mk.injEq, OctetsState.mk.injEq,
             eq_self_iff_true, and_true]
  omega

-- §4.3  4-byte case (16384 ≤ v ≤ 1073741823)

/-- Write v (16384 ≤ v ≤ 1073741823) with putU32 (v + 0x80000000), then
    read with getVarint: returns v.
    The first byte has top 2 bits = 10 (tag = 2); stripping gives v. -/
theorem putVarint_freeze_getVarint_4byte (s s' : OctetsMutState) (v : Nat)
    (hv1 : 16384 ≤ v) (hv2 : v ≤ 1073741823) (h : s.putU32 (v + 2147483648) = some s') :
    OctetsState.getVarint { buf := s'.buf, off := s.off } =
      some (v, { buf := s'.buf, off := s.off + 4 }) := by
  -- Byte values after putU32 (v + 2147483648)
  have hb0 := putU32_freeze_byte0 s s' (v + 2147483648) h
  have hb1 := putU32_freeze_byte1 s s' (v + 2147483648) h
  have hb2 := putU32_freeze_byte2 s s' (v + 2147483648) h
  have hb3 := putU32_freeze_byte3 s s' (v + 2147483648) h
  have hlen : s'.buf.length = s.buf.length := putU32_len s s' (v + 2147483648) h
  -- Capacity: putU32 requires s.off + 3 < s.buf.length
  have hcap : s.off + 3 < s.buf.length := by
    simp only [OctetsMutState.putU32] at h
    by_cases hc : s.off + 3 < s.buf.length
    · exact hc
    · simp [if_neg hc] at h
  -- Tag check: b0 = (v + 2147483648) / 16777216 ∈ [128, 191], so b0 / 64 = 2
  have htag : octListGet s'.buf s.off / 64 = 2 := by
    rw [hb0]; omega
  -- Capacity for tag-2 read
  have hoff3 : s.off + 3 < s'.buf.length := by rw [hlen]; exact hcap
  -- Evaluate getVarint
  rw [getVarint_tag2 { buf := s'.buf, off := s.off } hoff3 htag, hb0, hb1, hb2, hb3]
  -- Prove arithmetic: strip tag bits and reassemble = v
  -- getU32 of (v + 0x80000000) = v + 2147483648, tag bits contribute 128 * 2^24
  simp only [Option.some.injEq, Prod.mk.injEq, OctetsState.mk.injEq,
             eq_self_iff_true, and_true]
  omega

-- §4.4  8-byte case (1073741824 ≤ v ≤ MAX_VAR_INT)
-- Proof sketch: putVarint writes w = v + 0xC000000000000000 as two u32s
-- (high word wH = w / 2^32 and low word wL = w % 2^32). After the two writes:
--   • b0 = wH / 16777216 ∈ [192, 255], so tag = b0 / 64 = 3.
--   • getVarint reads all 8 bytes and reconstructs v by stripping the top 2 bits.
-- The proof follows the same pattern as the 4-byte case but requires chaining
-- through two putU32 calls and proving non-interference of the second write
-- on bytes 0–3 written by the first.

theorem putVarint_freeze_getVarint_8byte (s s' : OctetsMutState) (v : Nat)
    (hv1 : 1073741824 ≤ v) (hv2 : v ≤ MAX_VAR_INT)
    (h : (match s.putU32 ((v + 13835058055282163712) / 4294967296) with
          | some s₁ => s₁.putU32 ((v + 13835058055282163712) % 4294967296)
          | none => none) = some s') :
    OctetsState.getVarint { buf := s'.buf, off := s.off } =
      some (v, { buf := s'.buf, off := s.off + 8 }) := by
  sorry
  -- TODO: chain through s₁, use putU32_freeze_byte0..3 for each half,
  -- prove non-interference (write at s.off+4 does not affect s.off..s.off+3),
  -- and close with omega as in the 4-byte proof.

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §5  Combined roundtrip theorem
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Main roundtrip: writing any valid QUIC varint `v` with putVarint and
    reading back with getVarint (at the original offset) recovers `v`.
    The cursor advances by exactly `varint_len_nat v` bytes. -/
theorem putVarint_freeze_getVarint (s s' : OctetsMutState) (v : Nat)
    (hv : v ≤ MAX_VAR_INT) (h : s.putVarint v = some s') :
    OctetsState.getVarint { buf := s'.buf, off := s.off } =
      some (v, { buf := s'.buf, off := s.off + varint_len_nat v }) := by
  simp only [OctetsMutState.putVarint] at h
  by_cases h1 : v ≤ 63
  · -- 1-byte
    simp only [if_pos h1] at h
    rw [putVarint_freeze_getVarint_1byte s s' v h1 h]
    simp only [varint_len_nat, if_pos h1]
  · simp only [if_neg h1] at h
    by_cases h2 : v ≤ 16383
    · -- 2-byte
      simp only [if_pos h2] at h
      rw [putVarint_freeze_getVarint_2byte s s' v (by omega) h2 h]
      simp only [varint_len_nat, if_neg h1, if_pos h2]
    · simp only [if_neg h2] at h
      by_cases h3 : v ≤ 1073741823
      · -- 4-byte
        simp only [if_pos h3] at h
        rw [putVarint_freeze_getVarint_4byte s s' v (by omega) h3 h]
        simp only [varint_len_nat, if_neg h1, if_neg h2, if_pos h3]
      · -- 8-byte
        simp only [if_neg h3] at h
        by_cases h4 : v ≤ MAX_VAR_INT
        · simp only [if_pos h4] at h
          rw [putVarint_freeze_getVarint_8byte s s' v (by omega) h4 h]
          simp only [varint_len_nat, if_neg h1, if_neg h2, if_neg h3]
        · exact absurd hv h4

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §6  Cursor advance theorem
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- putVarint advances the cursor by exactly varint_len_nat v bytes. -/
theorem putVarint_off (s s' : OctetsMutState) (v : Nat)
    (hv : v ≤ MAX_VAR_INT) (h : s.putVarint v = some s') :
    s'.off = s.off + varint_len_nat v := by
  simp only [OctetsMutState.putVarint] at h
  by_cases h1 : v ≤ 63
  · simp only [if_pos h1] at h
    have := putU8_off s s' v h
    simp only [varint_len_nat, if_pos h1]; omega
  · simp only [if_neg h1] at h
    by_cases h2 : v ≤ 16383
    · simp only [if_pos h2] at h
      have := putU16_off s s' (v + 16384) h
      simp only [varint_len_nat, if_neg h1, if_pos h2]; omega
    · simp only [if_neg h2] at h
      by_cases h3 : v ≤ 1073741823
      · simp only [if_pos h3] at h
        have := putU32_off s s' (v + 2147483648) h
        simp only [varint_len_nat, if_neg h1, if_neg h2, if_pos h3]; omega
      · simp only [if_neg h3] at h
        by_cases h4 : v ≤ MAX_VAR_INT
        · simp only [if_pos h4] at h
          simp only [varint_len_nat, if_neg h1, if_neg h2, if_neg h3]
          -- 8-byte case: two putU32 calls, each advances by 4 → total 8
          match hm : s.putU32 ((v + 13835058055282163712) / 4294967296) with
          | some s₁ =>
            rw [hm] at h
            have ho1 := putU32_off s s₁ _ hm
            have ho2 := putU32_off s₁ s' _ h
            omega
          | none => simp [hm] at h
        · exact absurd hv h4

/-- putVarint preserves the buffer length. -/
theorem putVarint_len (s s' : OctetsMutState) (v : Nat)
    (hv : v ≤ MAX_VAR_INT) (h : s.putVarint v = some s') :
    s'.buf.length = s.buf.length := by
  simp only [OctetsMutState.putVarint] at h
  by_cases h1 : v ≤ 63
  · simp only [if_pos h1] at h; exact putU8_len s s' v h
  · simp only [if_neg h1] at h
    by_cases h2 : v ≤ 16383
    · simp only [if_pos h2] at h; exact putU16_len s s' (v + 16384) h
    · simp only [if_neg h2] at h
      by_cases h3 : v ≤ 1073741823
      · simp only [if_pos h3] at h; exact putU32_len s s' (v + 2147483648) h
      · simp only [if_neg h3] at h
        by_cases h4 : v ≤ MAX_VAR_INT
        · simp only [if_pos h4] at h
          match hm : s.putU32 ((v + 13835058055282163712) / 4294967296) with
          | some s₁ =>
            rw [hm] at h
            have hlen1 := putU32_len s s₁ _ hm
            have hlen2 := putU32_len s₁ s' _ h
            omega
          | none => simp [hm] at h
        · exact absurd hv h4

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §7  Tag consistency (bridge to Varint.lean)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Helper lemmas: reduce varint_parse_len_nat given a known tag bits value.
-- omega proves the divisor fact; unfold+rw reduces the match on a literal.
private theorem varint_parse_len_nat_eq1 {b : Nat} (h : b / 64 = 0) :
    varint_parse_len_nat b = 1 := by
  unfold varint_parse_len_nat; rw [h]

private theorem varint_parse_len_nat_eq2 {b : Nat} (h : b / 64 = 1) :
    varint_parse_len_nat b = 2 := by
  unfold varint_parse_len_nat; rw [h]

private theorem varint_parse_len_nat_eq4 {b : Nat} (h : b / 64 = 2) :
    varint_parse_len_nat b = 4 := by
  unfold varint_parse_len_nat; rw [h]

/-- The first byte written by putVarint has tag bits consistent with
    varint_parse_len_nat: the encoded length equals varint_len_nat v. -/
theorem putVarint_first_byte_tag (s s' : OctetsMutState) (v : Nat)
    (hv : v ≤ MAX_VAR_INT) (h : s.putVarint v = some s') :
    varint_parse_len_nat (octListGet s'.buf s.off) = varint_len_nat v := by
  simp only [OctetsMutState.putVarint] at h
  by_cases h1 : v ≤ 63
  · simp only [if_pos h1] at h
    have hb0 : octListGet s'.buf s.off = v := by
      simp only [OctetsMutState.putU8] at h
      by_cases hc : s.off < s.buf.length
      · rw [if_pos hc] at h; simp only [Option.some.injEq] at h; subst h
        rw [← listGet_eq_octListGet]; exact listGet_set_eq s.buf s.off v hc
      · rw [if_neg hc] at h; simp at h
    rw [hb0, varint_parse_len_nat_eq1 (show v / 64 = 0 by omega)]
    simp only [varint_len_nat, if_pos h1]
  · simp only [if_neg h1] at h
    by_cases h2 : v ≤ 16383
    · simp only [if_pos h2] at h
      have hb0 := putU16_freeze_byte0 s s' (v + 16384) h
      rw [hb0,
        varint_parse_len_nat_eq2 (show (v + 16384) / 256 / 64 = 1 by omega)]
      simp only [varint_len_nat, if_neg h1, if_pos h2]
    · simp only [if_neg h2] at h
      by_cases h3 : v ≤ 1073741823
      · simp only [if_pos h3] at h
        have hb0 := putU32_freeze_byte0 s s' (v + 2147483648) h
        rw [hb0,
          varint_parse_len_nat_eq4
            (show (v + 2147483648) / 16777216 / 64 = 2 by omega)]
        simp only [varint_len_nat, if_neg h1, if_neg h2, if_pos h3]
      · simp only [if_neg h3] at h
        by_cases h4 : v ≤ MAX_VAR_INT
        · simp only [if_pos h4] at h
          simp only [varint_parse_len_nat, varint_len_nat, if_neg h1, if_neg h2, if_neg h3]
          -- 8-byte case: first byte written by first putU32
          match hm : s.putU32 ((v + 13835058055282163712) / 4294967296) with
          | some s₁ =>
            rw [hm] at h
            -- The second putU32 writes at offset s₁.off = s.off + 4, so bytes
            -- at positions s.off..s.off+3 are unchanged.
            have hb0_s1 := putU32_freeze_byte0 s s₁ _ hm
            -- s' = result of writing low word at s₁.off = s.off + 4 into s₁.buf
            -- Since the second putU32 writes at s.off+4..s.off+7, it doesn't
            -- change byte at s.off. We need octListGet s'.buf s.off = same as s₁.
            sorry
            -- TODO: once putU32_bytes_unchanged is available, use it here.
            -- Arithmetic: b0 = (v + 0xC000000000000000) / 2^32 / 2^24
            --             b0 / 64 = 3 (omega from hv1: v ≥ 1073741824)
            --             varint_parse_len_nat b0 = 8 ✓
          | none => simp [hm] at h
        · exact absurd hv h4

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §8  Concrete examples (native_decide)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- 1-byte: v = 37 (RFC 9000 §16 example)
example : OctetsMutState.putVarint { buf := [0, 0], off := 0 } 37 =
    some { buf := [37, 0], off := 1 } := by native_decide

example : OctetsState.getVarint { buf := [37, 0], off := 0 } =
    some (37, { buf := [37, 0], off := 1 }) := by native_decide

-- 1-byte: v = 0 (minimum)
example : OctetsMutState.putVarint { buf := [0, 0], off := 0 } 0 =
    some { buf := [0, 0], off := 1 } := by native_decide

-- 1-byte: v = 63 (maximum 1-byte value)
example : OctetsMutState.putVarint { buf := [0, 0], off := 0 } 63 =
    some { buf := [63, 0], off := 1 } := by native_decide

-- 2-byte: v = 15293 (RFC 9000 §16 example)
example : OctetsMutState.putVarint { buf := [0, 0, 0], off := 0 } 15293 =
    some { buf := [0x7b, 0xbd, 0], off := 2 } := by native_decide

example : OctetsState.getVarint { buf := [0x7b, 0xbd, 0], off := 0 } =
    some (15293, { buf := [0x7b, 0xbd, 0], off := 2 }) := by native_decide

-- 2-byte: v = 64 (minimum 2-byte value)
example : OctetsMutState.putVarint { buf := [0, 0, 0], off := 0 } 64 =
    some { buf := [0x40, 0x40, 0], off := 2 } := by native_decide

example : OctetsState.getVarint { buf := [0x40, 0x40, 0], off := 0 } =
    some (64, { buf := [0x40, 0x40, 0], off := 2 }) := by native_decide

-- 2-byte: v = 16383 (maximum 2-byte value)
example : OctetsMutState.putVarint { buf := [0, 0, 0], off := 0 } 16383 =
    some { buf := [0x7f, 0xff, 0], off := 2 } := by native_decide

-- 4-byte: v = 494878333 (RFC 9000 §16 example)
example : OctetsMutState.putVarint { buf := [0, 0, 0, 0, 0], off := 0 } 494878333 =
    some { buf := [0x9d, 0x7f, 0x3e, 0x7d, 0], off := 4 } := by native_decide

example : OctetsState.getVarint { buf := [0x9d, 0x7f, 0x3e, 0x7d, 0], off := 0 } =
    some (494878333, { buf := [0x9d, 0x7f, 0x3e, 0x7d, 0], off := 4 }) := by native_decide

-- 4-byte: v = 16384 (minimum 4-byte value)
example : OctetsMutState.putVarint { buf := [0, 0, 0, 0, 0], off := 0 } 16384 =
    some { buf := [0x80, 0x00, 0x40, 0x00, 0], off := 4 } := by native_decide

-- Roundtrip check at a non-zero offset (v=37 is 1-byte; v=100 encodes as 2 bytes)
example :
    let s : OctetsMutState := { buf := [0xFF, 0, 0, 0xFF], off := 1 }
    OctetsMutState.putVarint s 37 = some { buf := [0xFF, 37, 0, 0xFF], off := 2 } := by
  native_decide

-- Consistency with pure Varint.lean model:
-- varint_encode 37 = some [37] and getVarint reads back 37
example : (OctetsState.getVarint { buf := [37], off := 0 }).map Prod.fst = some 37 := by
  native_decide

example : (OctetsState.getVarint { buf := [0x7b, 0xbd], off := 0 }).map Prod.fst =
    some 15293 := by native_decide

example : (OctetsState.getVarint { buf := [0x9d, 0x7f, 0x3e, 0x7d], off := 0 }).map Prod.fst
    = some 494878333 := by native_decide
