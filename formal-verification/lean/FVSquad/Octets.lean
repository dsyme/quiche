-- Copyright (C) 2025, Cloudflare, Inc.
-- All rights reserved.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/Octets.lean
--
-- Formal model and proofs for Octets<'a> (octets/src/lib.rs, lines 135–385).
--
-- 🔬 Lean Squad — automated formal verification.
--
-- MODEL SCOPE:
--   • Buffer is modelled as List Nat; bytes are natural numbers in [0, 255].
--   • This models the READ-ONLY Octets<'a> cursor type.  The read-write
--     OctetsMut<'a> type is separately modelled in FVSquad/OctetsMut.lean.
--   • Operations return Option to signal BufferTooShortError.
--   • Lifetimes, zero-copy slice semantics are NOT modelled.
--   • Varint operations are separately verified in Varint.lean.
--
-- APPROXIMATIONS:
--   • The &[u8] slice is modelled as List Nat (byte = Nat ∈ [0, 255]).
--   • Error handling: BufferTooShortError → Option.none.
--   • The buffer is never mutated — get_* return a new OctetsState with the
--     same buf and a larger off.
--   • Lifetime and aliasing: not modelled.

-- =============================================================================
-- §1  List helpers
-- =============================================================================

/-- Get the element at index `i`; returns 0 if out of bounds. -/
def octListGet : List Nat → Nat → Nat
  | [],       _     => 0
  | x :: _,  0     => x
  | _ :: xs, n + 1 => octListGet xs n

theorem octListGet_out_of_bounds (l : List Nat) (i : Nat) (h : l.length ≤ i) :
    octListGet l i = 0 := by
  induction l generalizing i with
  | nil => simp [octListGet]
  | cons _ xs ih =>
    cases i with
    | zero   => simp at h
    | succ n => simp [octListGet]; exact ih n (by simpa using h)

-- =============================================================================
-- §2  OctetsState model
-- =============================================================================

/-- Immutable cursor-based byte buffer (models `Octets<'a>`).
    The buffer `buf` is never mutated — all operations preserve `buf`. -/
structure OctetsState where
  buf : List Nat
  off : Nat
  deriving Repr, DecidableEq

namespace OctetsState

/-- Construct from a byte list; cursor starts at 0. -/
def withSlice (b : List Nat) : OctetsState := { buf := b, off := 0 }

def len  (s : OctetsState) : Nat := s.buf.length
def cap  (s : OctetsState) : Nat := s.buf.length - s.off

-- =============================================================================
-- §3  Invariant
-- =============================================================================

/-- Cursor-in-bounds invariant. -/
def Inv (s : OctetsState) : Prop := s.off ≤ s.buf.length

theorem withSlice_inv (b : List Nat) : (withSlice b).Inv := by
  simp [Inv, withSlice]

-- =============================================================================
-- §4  Cursor operations
-- =============================================================================

def skip (s : OctetsState) (n : Nat) : Option OctetsState :=
  if s.off + n ≤ s.buf.length then some { s with off := s.off + n } else none

def rewind (s : OctetsState) (n : Nat) : Option OctetsState :=
  if n ≤ s.off then some { s with off := s.off - n } else none

private theorem skip_unpack (s s' : OctetsState) (n : Nat) (h : s.skip n = some s') :
    s.off + n ≤ s.buf.length ∧ s'.buf = s.buf ∧ s'.off = s.off + n := by
  simp only [OctetsState.skip] at h
  by_cases hc : s.off + n ≤ s.buf.length
  · rw [if_pos hc] at h
    simp only [Option.some.injEq] at h
    subst h
    exact ⟨hc, rfl, rfl⟩
  · rw [if_neg hc] at h; simp at h

private theorem rewind_unpack (s s' : OctetsState) (n : Nat) (h : s.rewind n = some s') :
    n ≤ s.off ∧ s'.buf = s.buf ∧ s'.off = s.off - n := by
  simp only [OctetsState.rewind] at h
  by_cases hc : n ≤ s.off
  · rw [if_pos hc] at h
    simp only [Option.some.injEq] at h
    subst h
    exact ⟨hc, rfl, rfl⟩
  · rw [if_neg hc] at h; simp at h

theorem skip_advances_off (s s' : OctetsState) (n : Nat)
    (h : s.skip n = some s') : s'.off = s.off + n :=
  (skip_unpack s s' n h).2.2

theorem rewind_retreats_off (s s' : OctetsState) (n : Nat)
    (h : s.rewind n = some s') : s'.off = s.off - n :=
  (rewind_unpack s s' n h).2.2

theorem skip_buf_eq (s s' : OctetsState) (n : Nat)
    (h : s.skip n = some s') : s'.buf = s.buf :=
  (skip_unpack s s' n h).2.1

theorem rewind_buf_eq (s s' : OctetsState) (n : Nat)
    (h : s.rewind n = some s') : s'.buf = s.buf :=
  (rewind_unpack s s' n h).2.1

theorem skip_preserves_inv (s s' : OctetsState) (n : Nat)
    (hinv : s.Inv) (h : s.skip n = some s') : s'.Inv := by
  obtain ⟨hc, hb, ho⟩ := skip_unpack s s' n h
  simp only [Inv, hb, ho]; exact hc

theorem rewind_preserves_inv (s s' : OctetsState) (n : Nat)
    (hinv : s.Inv) (h : s.rewind n = some s') : s'.Inv := by
  obtain ⟨hc, hb, ho⟩ := rewind_unpack s s' n h
  simp only [Inv] at *; rw [hb, ho]; omega

/-- skip then rewind restores cursor. -/
theorem skip_rewind_inverse (s s' s'' : OctetsState) (n : Nat)
    (hs : s.skip n = some s') (hr : s'.rewind n = some s'') :
    s''.off = s.off ∧ s''.buf = s.buf := by
  obtain ⟨_, hb', ho'⟩ := skip_unpack s s' n hs
  obtain ⟨_, hb'', ho''⟩ := rewind_unpack s' s'' n hr
  exact ⟨by rw [ho'', ho']; omega, by rw [hb'', hb']⟩

/-- rewind then skip restores cursor. -/
theorem rewind_skip_inverse (s s' s'' : OctetsState) (n : Nat)
    (hr : s.rewind n = some s') (hs : s'.skip n = some s'') :
    s''.off = s.off ∧ s''.buf = s.buf := by
  obtain ⟨hc, hb', ho'⟩ := rewind_unpack s s' n hr
  obtain ⟨_, hb'', ho''⟩ := skip_unpack s' s'' n hs
  exact ⟨by rw [ho'', ho']; omega, by rw [hb'', hb']⟩

-- =============================================================================
-- §5  Read operations
-- =============================================================================

/-- Read one byte; cursor advances by 1. -/
def getU8 (s : OctetsState) : Option (Nat × OctetsState) :=
  if s.off < s.buf.length then
    some (octListGet s.buf s.off, { s with off := s.off + 1 })
  else none

/-- Read one byte; cursor unchanged. -/
def peekU8 (s : OctetsState) : Option Nat :=
  if s.off < s.buf.length then some (octListGet s.buf s.off) else none

/-- Read two bytes big-endian; cursor advances by 2. -/
def getU16 (s : OctetsState) : Option (Nat × OctetsState) :=
  if s.off + 1 < s.buf.length then
    some (256 * octListGet s.buf s.off + octListGet s.buf (s.off + 1),
          { s with off := s.off + 2 })
  else none

/-- Read four bytes big-endian; cursor advances by 4. -/
def getU32 (s : OctetsState) : Option (Nat × OctetsState) :=
  if s.off + 3 < s.buf.length then
    some (  16777216 * octListGet s.buf  s.off
          +    65536 * octListGet s.buf (s.off + 1)
          +      256 * octListGet s.buf (s.off + 2)
          +            octListGet s.buf (s.off + 3),
            { s with off := s.off + 4 })
  else none

/-- Read eight bytes big-endian; cursor advances by 8. -/
def getU64 (s : OctetsState) : Option (Nat × OctetsState) :=
  if s.off + 7 < s.buf.length then
    some (  72057594037927936 * octListGet s.buf  s.off
          +   281474976710656 * octListGet s.buf (s.off + 1)
          +     1099511627776 * octListGet s.buf (s.off + 2)
          +        4294967296 * octListGet s.buf (s.off + 3)
          +          16777216 * octListGet s.buf (s.off + 4)
          +             65536 * octListGet s.buf (s.off + 5)
          +               256 * octListGet s.buf (s.off + 6)
          +                     octListGet s.buf (s.off + 7),
            { s with off := s.off + 8 })
  else none

-- =============================================================================
-- §6  Unpack lemmas for read operations (structural facts only)
-- =============================================================================

private theorem getU8_unpack (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU8 = some (v, s')) :
    s.off < s.buf.length ∧ s'.buf = s.buf ∧ s'.off = s.off + 1 := by
  simp only [OctetsState.getU8] at h
  by_cases hc : s.off < s.buf.length
  · rw [if_pos hc] at h
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨_, hs'⟩ := h; subst hs'
    exact ⟨hc, rfl, rfl⟩
  · rw [if_neg hc] at h; simp at h

private theorem getU16_unpack (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU16 = some (v, s')) :
    s.off + 1 < s.buf.length ∧ s'.buf = s.buf ∧ s'.off = s.off + 2 := by
  simp only [OctetsState.getU16] at h
  by_cases hc : s.off + 1 < s.buf.length
  · rw [if_pos hc] at h
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨_, hs'⟩ := h; subst hs'
    exact ⟨hc, rfl, rfl⟩
  · rw [if_neg hc] at h; simp at h

private theorem getU32_unpack (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU32 = some (v, s')) :
    s.off + 3 < s.buf.length ∧ s'.buf = s.buf ∧ s'.off = s.off + 4 := by
  simp only [OctetsState.getU32] at h
  by_cases hc : s.off + 3 < s.buf.length
  · rw [if_pos hc] at h
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨_, hs'⟩ := h; subst hs'
    exact ⟨hc, rfl, rfl⟩
  · rw [if_neg hc] at h; simp at h

private theorem getU64_unpack (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU64 = some (v, s')) :
    s.off + 7 < s.buf.length ∧ s'.buf = s.buf ∧ s'.off = s.off + 8 := by
  simp only [OctetsState.getU64] at h
  by_cases hc : s.off + 7 < s.buf.length
  · rw [if_pos hc] at h
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨_, hs'⟩ := h; subst hs'
    exact ⟨hc, rfl, rfl⟩
  · rw [if_neg hc] at h; simp at h

-- =============================================================================
-- §7  Invariant preservation under reads
-- =============================================================================

theorem getU8_preserves_inv (s : OctetsState) (v : Nat) (s' : OctetsState)
    (hinv : s.Inv) (h : s.getU8 = some (v, s')) : s'.Inv := by
  obtain ⟨hc, hb, ho⟩ := getU8_unpack s v s' h
  simp only [Inv, hb, ho]; omega

theorem getU16_preserves_inv (s : OctetsState) (v : Nat) (s' : OctetsState)
    (hinv : s.Inv) (h : s.getU16 = some (v, s')) : s'.Inv := by
  obtain ⟨hc, hb, ho⟩ := getU16_unpack s v s' h
  simp only [Inv, hb, ho]; omega

theorem getU32_preserves_inv (s : OctetsState) (v : Nat) (s' : OctetsState)
    (hinv : s.Inv) (h : s.getU32 = some (v, s')) : s'.Inv := by
  obtain ⟨hc, hb, ho⟩ := getU32_unpack s v s' h
  simp only [Inv, hb, ho]; omega

theorem getU64_preserves_inv (s : OctetsState) (v : Nat) (s' : OctetsState)
    (hinv : s.Inv) (h : s.getU64 = some (v, s')) : s'.Inv := by
  obtain ⟨hc, hb, ho⟩ := getU64_unpack s v s' h
  simp only [Inv, hb, ho]; omega

-- =============================================================================
-- §8  Cursor advance amounts
-- =============================================================================

theorem getU8_off (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU8 = some (v, s')) : s'.off = s.off + 1 :=
  (getU8_unpack s v s' h).2.2

theorem getU16_off (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU16 = some (v, s')) : s'.off = s.off + 2 :=
  (getU16_unpack s v s' h).2.2

theorem getU32_off (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU32 = some (v, s')) : s'.off = s.off + 4 :=
  (getU32_unpack s v s' h).2.2

theorem getU64_off (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU64 = some (v, s')) : s'.off = s.off + 8 :=
  (getU64_unpack s v s' h).2.2

-- =============================================================================
-- §9  Buffer is unchanged by read operations
-- =============================================================================

theorem getU8_buf (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU8 = some (v, s')) : s'.buf = s.buf :=
  (getU8_unpack s v s' h).2.1

theorem getU16_buf (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU16 = some (v, s')) : s'.buf = s.buf :=
  (getU16_unpack s v s' h).2.1

theorem getU32_buf (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU32 = some (v, s')) : s'.buf = s.buf :=
  (getU32_unpack s v s' h).2.1

-- =============================================================================
-- §10  getU8 reads the correct byte; peekU8 is non-destructive
-- =============================================================================

theorem getU8_reads_off (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU8 = some (v, s')) : v = octListGet s.buf s.off := by
  simp only [OctetsState.getU8] at h
  by_cases hc : s.off < s.buf.length
  · rw [if_pos hc] at h
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    exact h.1.symm
  · rw [if_neg hc] at h; simp at h

theorem peekU8_reads_off (s : OctetsState) (v : Nat)
    (h : s.peekU8 = some v) : v = octListGet s.buf s.off := by
  simp only [OctetsState.peekU8] at h
  by_cases hc : s.off < s.buf.length
  · rw [if_pos hc] at h
    exact (Option.some.injEq _ _).mp h.symm
  · rw [if_neg hc] at h; simp at h

/-- peekU8 returns the same value as getU8 (when getU8 succeeds). -/
theorem peekU8_eq_getU8_value (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU8 = some (v, s')) : s.peekU8 = some v := by
  obtain ⟨hc, _, _⟩ := getU8_unpack s v s' h
  simp only [OctetsState.peekU8, if_pos hc]
  exact congrArg some (getU8_reads_off s v s' h).symm

-- =============================================================================
-- §11  cap_identity: off + cap = len (requires Inv)
-- =============================================================================

theorem cap_identity (s : OctetsState) (h : s.Inv) :
    s.off + s.cap = s.len := by
  simp only [OctetsState.cap, OctetsState.len, OctetsState.Inv] at *; omega

theorem cap_zero_iff_at_end (s : OctetsState) (h : s.Inv) :
    s.cap = 0 ↔ s.off = s.len := by
  simp only [cap, len, Inv] at *; omega

theorem withSlice_cap (b : List Nat) : (withSlice b).cap = b.length := by
  simp [cap, withSlice]

theorem withSlice_off (b : List Nat) : (withSlice b).off = 0 := rfl
theorem withSlice_len (b : List Nat) : (withSlice b).len = b.length := rfl

-- =============================================================================
-- §12  Error / None conditions
-- =============================================================================

theorem getU8_none_of_empty (s : OctetsState) (h : s.cap = 0) :
    s.getU8 = none := by simp [getU8, cap] at *; omega

theorem peekU8_none_of_empty (s : OctetsState) (h : s.cap = 0) :
    s.peekU8 = none := by simp [peekU8, cap] at *; omega

theorem getU16_none_of_small_cap (s : OctetsState) (h : s.cap < 2) :
    s.getU16 = none := by simp [getU16, cap] at *; omega

theorem getU32_none_of_small_cap (s : OctetsState) (h : s.cap < 4) :
    s.getU32 = none := by simp [getU32, cap] at *; omega

theorem getU64_none_of_small_cap (s : OctetsState) (h : s.cap < 8) :
    s.getU64 = none := by simp [getU64, cap] at *; omega

theorem skip_none_of_insufficient_cap (s : OctetsState) (n : Nat)
    (h : s.buf.length < s.off + n) : s.skip n = none := by
  simp [skip]; omega

theorem rewind_none_of_insufficient_off (s : OctetsState) (n : Nat)
    (h : s.off < n) : s.rewind n = none := by
  simp [rewind]; omega

-- =============================================================================
-- §13  Success conditions
-- =============================================================================

theorem getU8_some_of_nonempty (s : OctetsState) (h : 0 < s.cap) :
    (s.getU8).isSome := by simp [getU8, cap] at *; omega

theorem getU16_some_of_cap_ge_2 (s : OctetsState) (h : 2 ≤ s.cap) :
    (s.getU16).isSome := by simp [getU16, cap] at *; omega

theorem getU32_some_of_cap_ge_4 (s : OctetsState) (h : 4 ≤ s.cap) :
    (s.getU32).isSome := by simp [getU32, cap] at *; omega

theorem getU64_some_of_cap_ge_8 (s : OctetsState) (h : 8 ≤ s.cap) :
    (s.getU64).isSome := by simp [getU64, cap] at *; omega

-- =============================================================================
-- §14  Sequential reads advance cursor additively
-- =============================================================================

/-- Two successive getU8 calls advance cursor by 2. -/
theorem getU8_x2_off (s s1 s2 : OctetsState) (a b : Nat)
    (h1 : s.getU8 = some (a, s1)) (h2 : s1.getU8 = some (b, s2)) :
    s2.off = s.off + 2 := by
  have := getU8_off s a s1 h1; have := getU8_off s1 b s2 h2; omega

/-- Three successive getU8 calls advance cursor by 3. -/
theorem getU8_x3_off (s s1 s2 s3 : OctetsState) (a b c : Nat)
    (h1 : s.getU8 = some (a, s1)) (h2 : s1.getU8 = some (b, s2))
    (h3 : s2.getU8 = some (c, s3)) :
    s3.off = s.off + 3 := by
  have := getU8_off s a s1 h1; have := getU8_off s1 b s2 h2
  have := getU8_off s2 c s3 h3; omega

/-- getU16 then getU8 advances cursor by 3. -/
theorem getU16_getU8_off (s s1 s2 : OctetsState) (v w : Nat)
    (h1 : s.getU16 = some (v, s1)) (h2 : s1.getU8 = some (w, s2)) :
    s2.off = s.off + 3 := by
  have := getU16_off s v s1 h1; have := getU8_off s1 w s2 h2; omega

-- =============================================================================
-- §15  Big-endian decoding correctness
-- =============================================================================

/-- getU16 value = 256 * byte₀ + byte₁. -/
theorem getU16_eq_byte_pair (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU16 = some (v, s')) :
    v = 256 * octListGet s.buf s.off + octListGet s.buf (s.off + 1) := by
  simp only [OctetsState.getU16] at h
  by_cases hc : s.off + 1 < s.buf.length
  · rw [if_pos hc] at h
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    omega
  · rw [if_neg hc] at h; simp at h

/-- getU32 value = big-endian combination of four bytes. -/
theorem getU32_eq_four_bytes (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU32 = some (v, s')) :
    v =   16777216 * octListGet s.buf  s.off
        +    65536 * octListGet s.buf (s.off + 1)
        +      256 * octListGet s.buf (s.off + 2)
        +            octListGet s.buf (s.off + 3) := by
  simp only [OctetsState.getU32] at h
  by_cases hc : s.off + 3 < s.buf.length
  · rw [if_pos hc] at h
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    omega
  · rw [if_neg hc] at h; simp at h

/-- getU64 value = big-endian combination of eight bytes. -/
theorem getU64_eq_eight_bytes (s : OctetsState) (v : Nat) (s' : OctetsState)
    (h : s.getU64 = some (v, s')) :
    v =   72057594037927936 * octListGet s.buf  s.off
        +   281474976710656 * octListGet s.buf (s.off + 1)
        +     1099511627776 * octListGet s.buf (s.off + 2)
        +        4294967296 * octListGet s.buf (s.off + 3)
        +          16777216 * octListGet s.buf (s.off + 4)
        +             65536 * octListGet s.buf (s.off + 5)
        +               256 * octListGet s.buf (s.off + 6)
        +                     octListGet s.buf (s.off + 7) := by
  simp only [OctetsState.getU64] at h
  by_cases hc : s.off + 7 < s.buf.length
  · rw [if_pos hc] at h
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    omega
  · rw [if_neg hc] at h; simp at h

-- =============================================================================
-- §16  getU16 decomposes into two sequential getU8 calls
-- =============================================================================

/-- getU16 succeeds iff two sequential getU8 calls succeed, and the values
    satisfy the big-endian relation. -/
theorem getU16_split (s : OctetsState) (v : Nat) (s2 : OctetsState)
    (h16 : s.getU16 = some (v, s2)) :
    ∃ v1 v2 s1,
      s.getU8 = some (v1, s1) ∧
      s1.getU8 = some (v2, s2) ∧
      v = 256 * v1 + v2 := by
  simp only [OctetsState.getU16] at h16
  by_cases hc : s.off + 1 < s.buf.length
  · rw [if_pos hc] at h16
    simp only [Option.some.injEq, Prod.mk.injEq] at h16
    obtain ⟨hv, hs2⟩ := h16
    subst hs2
    -- s2 = { s with off := s.off + 2 }; build s1 = { s with off := s.off + 1 }
    let s1 : OctetsState := { s with off := s.off + 1 }
    refine ⟨octListGet s.buf s.off, octListGet s.buf (s.off + 1), s1, ?_, ?_, ?_⟩
    · simp only [OctetsState.getU8, s1, if_pos (show s.off < s.buf.length by omega)]
    · simp only [OctetsState.getU8, s1, if_pos hc]
    · omega
  · rw [if_neg hc] at h16; simp at h16

-- =============================================================================
-- §17  Buffer preservation across multiple reads
-- =============================================================================

theorem two_getU8_buf_preserved (s s1 s2 : OctetsState) (a b : Nat)
    (h1 : s.getU8 = some (a, s1)) (h2 : s1.getU8 = some (b, s2)) :
    s2.buf = s.buf :=
  (getU8_buf s1 b s2 h2).trans (getU8_buf s a s1 h1)

-- =============================================================================
-- §18  native_decide test vectors
-- =============================================================================

private def testOct : OctetsState :=
  withSlice [0xAB, 0xCD, 0x01, 0x02, 0x03, 0x04, 0x00, 0xFF]

example : testOct.cap  = 8 := by native_decide
example : testOct.len  = 8 := by native_decide
example : (withSlice ([] : List Nat)).Inv := withSlice_inv []

-- Single-byte read returns buf[0] = 0xAB.
example : testOct.getU8 =
    some (0xAB, { buf := testOct.buf, off := 1 }) := by native_decide

-- peekU8 does not advance cursor.
example : testOct.peekU8 = some 0xAB := by native_decide

-- getU16 decodes big-endian: 0xAB * 256 + 0xCD = 43981.
example : testOct.getU16 =
    some (43981, { buf := testOct.buf, off := 2 }) := by native_decide

-- getU32 decodes big-endian: 0xAB * 2^24 + 0xCD * 2^16 + 1 * 256 + 2
--   = 2882339074.
example : testOct.getU32 =
    some (2882339074, { buf := testOct.buf, off := 4 }) := by native_decide

-- Skip then rewind restores cursor.
example : (testOct.skip 3 >>= (·.rewind 3)) =
    some { buf := testOct.buf, off := 0 } := by native_decide

-- getU8 on empty buffer = none.
example : (withSlice ([] : List Nat)).getU8 = none := by native_decide

end OctetsState
