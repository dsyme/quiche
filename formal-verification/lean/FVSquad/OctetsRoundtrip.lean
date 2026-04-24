-- Copyright (C) 2025, Cloudflare, Inc.
-- All rights reserved.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/OctetsRoundtrip.lean
--
-- Cross-module consistency between OctetsMut (write cursor) and Octets
-- (read-only cursor) from octets/src/lib.rs.
--
-- 🔬 Lean Squad — automated formal verification.
--
-- MODEL SCOPE:
--   • Imports FVSquad.OctetsMut and FVSquad.Octets.
--   • The "freeze" pattern: write bytes with OctetsMutState, then construct
--     an OctetsState from the resulting buf for read-back.
--   • Proves that listGet (OctetsMut) = octListGet (Octets), making both
--     models consistent on the same underlying List Nat.
--   • Round-trip theorems for U8, U16, U32: put then freeze-and-get = id.
--
-- APPROXIMATIONS:
--   • The Rust borrow checker enforces that the mutable borrow ends before
--     the immutable Octets borrow begins.  In Lean we model this as simply
--     constructing { buf := s'.buf, off := s.off } — there is no aliasing.
--   • Buffer length is preserved by all put_* operations (proved here from
--     existing OctetsMut lemmas).

import FVSquad.OctetsMut
import FVSquad.Octets

-- =============================================================================
-- §1  Bridge: listGet (OctetsMut) ≡ octListGet (Octets)
-- =============================================================================

-- Both helpers have identical definitions over List Nat.  This theorem makes
-- the identity explicit so we can substitute freely in cross-module proofs.
theorem listGet_eq_octListGet (l : List Nat) (i : Nat) :
    listGet l i = octListGet l i := by
  induction l generalizing i with
  | nil => simp [listGet, octListGet]
  | cons x xs ih =>
    cases i with
    | zero   => simp [listGet, octListGet]
    | succ n => simp only [listGet, octListGet]; exact ih n

-- After writing v at position i, reading with octListGet at i yields v.
theorem octListGet_set_eq (l : List Nat) (i v : Nat) (h : i < l.length) :
    octListGet (listSet l i v) i = v := by
  rw [← listGet_eq_octListGet]; exact listGet_set_eq l i v h

-- After writing v at position i, reading with octListGet at j ≠ i is unchanged.
theorem octListGet_set_ne (l : List Nat) (i j v : Nat) (h : i ≠ j) :
    octListGet (listSet l i v) j = octListGet l j := by
  rw [← listGet_eq_octListGet, ← listGet_eq_octListGet]
  exact listGet_set_ne l i j v h

-- =============================================================================
-- §2  Mutual consistency: OctetsMutState.getU8 ≡ OctetsState.getU8
-- =============================================================================

-- Reading a byte using the mutable cursor is identical to reading it using
-- the immutable cursor when both are positioned at the same offset on the
-- same buffer.
theorem mut_getU8_eq_octets_getU8 (buf : List Nat) (off : Nat) :
    OctetsMutState.getU8 { buf := buf, off := off } =
      (OctetsState.getU8 { buf := buf, off := off }).map
        fun (v, s') => (v, { buf := s'.buf, off := s'.off }) := by
  simp only [OctetsMutState.getU8, OctetsState.getU8]
  by_cases hc : off < buf.length
  · rw [if_pos hc, if_pos hc]
    simp [listGet_eq_octListGet]
  · rw [if_neg hc, if_neg hc]; simp

-- The immutable cursor cap equals the mutable cursor cap on the same state.
theorem freeze_cap_eq (s : OctetsMutState) (hinv : s.Inv) :
    OctetsState.cap { buf := s.buf, off := s.off } = s.cap := by
  simp [OctetsState.cap, OctetsMutState.cap]

-- =============================================================================
-- §3  putU8 freeze round-trip
-- =============================================================================

-- After putU8 v, the byte at position s.off in s'.buf is v.
theorem putU8_byte_at_off (s s' : OctetsMutState) (v : Nat)
    (h : s.putU8 v = some s') :
    octListGet s'.buf s.off = v := by
  simp only [OctetsMutState.putU8] at h
  by_cases hc : s.off < s.buf.length
  · rw [if_pos hc] at h
    simp only [Option.some.injEq] at h
    subst h
    exact octListGet_set_eq s.buf s.off v hc
  · rw [if_neg hc] at h; simp at h

-- After putU8 v, bytes at other positions in s'.buf are unchanged.
theorem putU8_bytes_unchanged (s s' : OctetsMutState) (v j : Nat)
    (h : s.putU8 v = some s') (hj : j ≠ s.off) :
    octListGet s'.buf j = octListGet s.buf j := by
  simp only [OctetsMutState.putU8] at h
  by_cases hc : s.off < s.buf.length
  · rw [if_pos hc] at h; simp only [Option.some.injEq] at h; subst h
    exact octListGet_set_ne s.buf s.off j v (Ne.symm hj)
  · rw [if_neg hc] at h; simp at h

-- KEY: put with OctetsMut then freeze-read with OctetsState returns v.
-- The "freeze" is: construct OctetsState from s'.buf positioned at s.off.
theorem putU8_freeze_getU8 (s s' : OctetsMutState) (v : Nat)
    (h : s.putU8 v = some s') :
    OctetsState.getU8 { buf := s'.buf, off := s.off } =
      some (v, { buf := s'.buf, off := s.off + 1 }) := by
  have hbyte := putU8_byte_at_off s s' v h
  simp only [OctetsMutState.putU8] at h
  by_cases hc : s.off < s.buf.length
  · rw [if_pos hc] at h; simp only [Option.some.injEq] at h; subst h
    simp only [OctetsState.getU8,
               if_pos (show s.off < (listSet s.buf s.off v).length by rw [listSet_length]; exact hc)]
    rw [hbyte]
  · rw [if_neg hc] at h; simp at h

-- putU8 does not change the buffer length (needed below).
theorem putU8_freeze_len (s s' : OctetsMutState) (v : Nat)
    (h : s.putU8 v = some s') :
    s'.buf.length = s.buf.length :=
  putU8_len s s' v h

-- =============================================================================
-- §4  putU16 freeze round-trip
-- =============================================================================

-- Helper: extract buf/off from putU16 result inline (putU16_unpack is private).
private theorem putU16_buf_off (s s' : OctetsMutState) (v : Nat)
    (h : s.putU16 v = some s') :
    s.off + 1 < s.buf.length ∧
    s'.buf = listSet (listSet s.buf s.off (v / 256)) (s.off + 1) (v % 256) ∧
    s'.off = s.off + 2 := by
  simp only [OctetsMutState.putU16] at h
  by_cases hc : s.off + 1 < s.buf.length
  · rw [if_pos hc] at h; simp only [Option.some.injEq] at h; subst h
    exact ⟨hc, rfl, rfl⟩
  · rw [if_neg hc] at h; simp at h

-- High byte of v is at s.off, low byte is at s.off + 1.
theorem putU16_freeze_byte0 (s s' : OctetsMutState) (v : Nat)
    (h : s.putU16 v = some s') :
    octListGet s'.buf s.off = v / 256 := by
  obtain ⟨hc, hb, _⟩ := putU16_buf_off s s' v h
  rw [hb]
  rw [octListGet_set_ne _ _ _ _ (by omega : s.off + 1 ≠ s.off)]
  exact octListGet_set_eq s.buf s.off (v / 256) (by omega)

theorem putU16_freeze_byte1 (s s' : OctetsMutState) (v : Nat)
    (h : s.putU16 v = some s') :
    octListGet s'.buf (s.off + 1) = v % 256 := by
  obtain ⟨hc, hb, _⟩ := putU16_buf_off s s' v h
  rw [hb]
  exact octListGet_set_eq _ _ _ (by simp [listSet_length]; exact hc)

-- KEY: put_u16 then freeze-read with Octets.getU16 = v (for v < 65536).
theorem putU16_freeze_getU16 (s s' : OctetsMutState) (v : Nat)
    (hv : v < 65536) (h : s.putU16 v = some s') :
    OctetsState.getU16 { buf := s'.buf, off := s.off } =
      some (v, { buf := s'.buf, off := s.off + 2 }) := by
  obtain ⟨hc, hb, ho'⟩ := putU16_buf_off s s' v h
  have hlen : s'.buf.length = s.buf.length := by rw [hb]; simp [listSet_length]
  have b0   := putU16_freeze_byte0 s s' v h
  have b1   := putU16_freeze_byte1 s s' v h
  simp only [OctetsState.getU16, hlen, if_pos hc, b0, b1]
  simp only [Option.some.injEq, Prod.mk.injEq, eq_self_iff_true, and_true]
  omega

-- =============================================================================
-- §5  putU32 freeze round-trip
-- =============================================================================

-- Helper: extract buf/off from putU32 result inline (putU32_unpack is private).
private theorem putU32_buf_off (s s' : OctetsMutState) (v : Nat)
    (h : s.putU32 v = some s') :
    s.off + 3 < s.buf.length ∧
    s'.buf = listSet (listSet (listSet (listSet s.buf
                s.off       (v / 16777216))
                (s.off + 1) (v / 65536 % 256))
                (s.off + 2) (v / 256 % 256))
                (s.off + 3) (v % 256) ∧
    s'.off = s.off + 4 := by
  simp only [OctetsMutState.putU32] at h
  by_cases hc : s.off + 3 < s.buf.length
  · rw [if_pos hc] at h; simp only [Option.some.injEq] at h; subst h
    exact ⟨hc, rfl, rfl⟩
  · rw [if_neg hc] at h; simp at h

theorem putU32_freeze_byte0 (s s' : OctetsMutState) (v : Nat)
    (h : s.putU32 v = some s') :
    octListGet s'.buf s.off = v / 16777216 := by
  obtain ⟨hc, hb, _⟩ := putU32_buf_off s s' v h
  rw [hb]
  simp only [octListGet_set_ne _ _ _ _ (by omega : s.off + 3 ≠ s.off),
             octListGet_set_ne _ _ _ _ (by omega : s.off + 2 ≠ s.off),
             octListGet_set_ne _ _ _ _ (by omega : s.off + 1 ≠ s.off)]
  exact octListGet_set_eq s.buf s.off _ (by omega)

theorem putU32_freeze_byte1 (s s' : OctetsMutState) (v : Nat)
    (h : s.putU32 v = some s') :
    octListGet s'.buf (s.off + 1) = v / 65536 % 256 := by
  obtain ⟨hc, hb, _⟩ := putU32_buf_off s s' v h
  rw [hb]
  simp only [octListGet_set_ne _ _ _ _ (by omega : s.off + 3 ≠ s.off + 1),
             octListGet_set_ne _ _ _ _ (by omega : s.off + 2 ≠ s.off + 1)]
  exact octListGet_set_eq _ _ _ (by simp [listSet_length]; omega)

theorem putU32_freeze_byte2 (s s' : OctetsMutState) (v : Nat)
    (h : s.putU32 v = some s') :
    octListGet s'.buf (s.off + 2) = v / 256 % 256 := by
  obtain ⟨hc, hb, _⟩ := putU32_buf_off s s' v h
  rw [hb]
  simp only [octListGet_set_ne _ _ _ _ (by omega : s.off + 3 ≠ s.off + 2)]
  exact octListGet_set_eq _ _ _ (by simp [listSet_length]; omega)

theorem putU32_freeze_byte3 (s s' : OctetsMutState) (v : Nat)
    (h : s.putU32 v = some s') :
    octListGet s'.buf (s.off + 3) = v % 256 := by
  obtain ⟨hc, hb, _⟩ := putU32_buf_off s s' v h
  rw [hb]
  exact octListGet_set_eq _ _ _ (by simp [listSet_length]; omega)

-- KEY: put_u32 then freeze-read with Octets.getU32 = v (for v < 2^32).
theorem putU32_freeze_getU32 (s s' : OctetsMutState) (v : Nat)
    (hv : v < 4294967296) (h : s.putU32 v = some s') :
    OctetsState.getU32 { buf := s'.buf, off := s.off } =
      some (v, { buf := s'.buf, off := s.off + 4 }) := by
  obtain ⟨hc, hb, ho'⟩ := putU32_buf_off s s' v h
  have hlen : s'.buf.length = s.buf.length := by rw [hb]; simp [listSet_length]
  have b0   := putU32_freeze_byte0 s s' v h
  have b1   := putU32_freeze_byte1 s s' v h
  have b2   := putU32_freeze_byte2 s s' v h
  have b3   := putU32_freeze_byte3 s s' v h
  simp only [OctetsState.getU32, hlen, if_pos hc, b0, b1, b2, b3]
  simp only [Option.some.injEq, Prod.mk.injEq, eq_self_iff_true, and_true]
  omega

-- =============================================================================
-- §6  Independence: put at one offset does not affect other offsets (Octets view)
-- =============================================================================

-- Writing at s.off with putU8 leaves all other positions unchanged in the
-- Octets view.
theorem putU8_octets_independent (s s' : OctetsMutState) (v j : Nat)
    (h : s.putU8 v = some s') (hj : j ≠ s.off) :
    octListGet s'.buf j = octListGet s.buf j :=
  putU8_bytes_unchanged s s' v j h hj

-- Writing 4 bytes at s.off..s.off+3 with putU32 leaves all other positions
-- unchanged.  Useful for chaining two consecutive putU32 calls (8-byte varint).
theorem putU32_bytes_unchanged (s s' : OctetsMutState) (v j : Nat)
    (h : s.putU32 v = some s')
    (hj : j ≠ s.off ∧ j ≠ s.off + 1 ∧ j ≠ s.off + 2 ∧ j ≠ s.off + 3) :
    octListGet s'.buf j = octListGet s.buf j := by
  obtain ⟨_, hb, _⟩ := putU32_buf_off s s' v h
  rw [hb]
  simp only [octListGet_set_ne _ _ _ _ (by omega : s.off + 3 ≠ j),
             octListGet_set_ne _ _ _ _ (by omega : s.off + 2 ≠ j),
             octListGet_set_ne _ _ _ _ (by omega : s.off + 1 ≠ j),
             octListGet_set_ne _ _ _ _ (by omega : s.off ≠ j)]

-- =============================================================================
-- §7  Sequential freeze: write two bytes, then read both with Octets
-- =============================================================================

-- After writing bytes a and b at consecutive offsets off and off+1,
-- the Octets view at off reads a.
theorem putU8_x2_freeze_byte0 (s s1 s2 : OctetsMutState) (a b : Nat)
    (h1 : s.putU8 a = some s1) (h2 : s1.putU8 b = some s2) :
    octListGet s2.buf s.off = a := by
  have hoff1 := putU8_off s s1 a h1
  have hbyte1 := putU8_byte_at_off s s1 a h1
  -- s1.off = s.off + 1, so when s1.putU8 b at s1.off (= s.off+1),
  -- it writes at s.off+1 ≠ s.off; so byte at s.off is unchanged.
  have hunchanged := putU8_bytes_unchanged s1 s2 b s.off h2 (by omega)
  rw [hunchanged, hbyte1]

-- After writing bytes a and b at offsets off and off+1, Octets at off+1
-- reads b.
theorem putU8_x2_freeze_byte1 (s s1 s2 : OctetsMutState) (a b : Nat)
    (h1 : s.putU8 a = some s1) (h2 : s1.putU8 b = some s2) :
    octListGet s2.buf (s.off + 1) = b := by
  have hoff1 := putU8_off s s1 a h1
  -- s1.off = s.off + 1; putU8 b at s1.off writes at s.off+1
  rw [← hoff1]
  exact putU8_byte_at_off s1 s2 b h2

-- =============================================================================
-- §8  Concrete examples: freeze round-trips at offset 0
-- =============================================================================

-- All examples assume a buffer of zeros of sufficient length.

example : OctetsMutState.putU8 { buf := [0, 0, 0, 0], off := 0 } 0x42 =
    some { buf := [0x42, 0, 0, 0], off := 1 } := by decide

example : OctetsMutState.putU8 { buf := [0, 0, 0, 0], off := 0 } 0xFF =
    some { buf := [0xFF, 0, 0, 0], off := 1 } := by decide

-- Freeze example: write 0x42, read back with OctetsState at offset 0.
example :
    OctetsState.getU8 { buf := [0x42, 0, 0, 0], off := 0 } =
      some (0x42, { buf := [0x42, 0, 0, 0], off := 1 }) := by decide

-- Concrete U16 freeze: write 0x0102 at offset 0.
example :
    let s : OctetsMutState := { buf := [0, 0, 0, 0], off := 0 }
    OctetsState.getU16 { buf := [1, 2, 0, 0], off := 0 } = some (258, { buf := [1, 2, 0, 0], off := 2 }) := by
  decide

-- Concrete U16 freeze round-trip: write 300 then read with Octets.
example :
    OctetsMutState.putU16 { buf := [0, 0, 0, 0], off := 0 } 300 =
      some { buf := [1, 44, 0, 0], off := 2 } := by decide

example :
    OctetsState.getU16 { buf := [1, 44, 0, 0], off := 0 } =
      some (300, { buf := [1, 44, 0, 0], off := 2 }) := by decide

-- Concrete U32 freeze round-trip: write 0x01020304 then read with Octets.
example :
    OctetsMutState.putU32 { buf := [0, 0, 0, 0], off := 0 } 0x01020304 =
      some { buf := [1, 2, 3, 4], off := 4 } := by decide

example :
    OctetsState.getU32 { buf := [1, 2, 3, 4], off := 0 } =
      some (0x01020304, { buf := [1, 2, 3, 4], off := 4 }) := by decide

-- Bytes at other offsets are not disturbed.
example :
    let s  : OctetsMutState := { buf := [0xAA, 0, 0, 0xBB], off := 1 }
    OctetsMutState.putU8 s 0x42 = some { buf := [0xAA, 0x42, 0, 0xBB], off := 2 } := by decide
