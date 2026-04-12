-- Copyright (C) 2025, Cloudflare, Inc.
-- All rights reserved.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/OctetsMut.lean
--
-- Formal model and proofs for OctetsMut (octets/src/lib.rs, lines 391–800).
--
-- 🔬 Lean Squad — automated formal verification.
--
-- MODEL SCOPE:
--   • Buffer is modelled as List Nat; bytes are natural numbers.
--   • Range preconditions (v < 256, v < 65536, v < 2^32) replace Rust's
--     fixed-width types; the Nat arithmetic then matches the Rust result.
--   • Operations return Option to signal BufferTooShortError.
--   • Lifetimes, references, and zero-copy slice semantics are NOT modelled.
--   • Varint operations are separately verified in Varint.lean.
--
-- APPROXIMATIONS:
--   • The &mut [u8] slice is modelled as List Nat; listSet models mutation.
--   • No overflow/wrapping: relies on range preconditions instead.
--   • Error handling: BufferTooShortError → Option.none.

-- =============================================================================
-- §1  List helpers
-- =============================================================================

/-- Get the element at index i, returning 0 if out of bounds. -/
def listGet : List Nat → Nat → Nat
  | [],       _     => 0
  | x :: _,  0     => x
  | _ :: xs, n + 1 => listGet xs n

/-- Set the element at index i; no-op if out of bounds. -/
def listSet : List Nat → Nat → Nat → List Nat
  | [],       _,    _  => []
  | _ :: xs,  0,   v   => v :: xs
  | x :: xs, n+1,  v   => x :: listSet xs n v

theorem listSet_length (l : List Nat) (i v : Nat) :
    (listSet l i v).length = l.length := by
  induction l generalizing i with
  | nil => simp [listSet]
  | cons _ xs ih =>
    cases i with
    | zero   => simp [listSet]
    | succ n => simp [listSet, ih]

theorem listGet_set_eq (l : List Nat) (i v : Nat) (h : i < l.length) :
    listGet (listSet l i v) i = v := by
  induction l generalizing i with
  | nil => simp at h
  | cons _ xs ih =>
    cases i with
    | zero   => simp [listGet, listSet]
    | succ n => simp only [listGet, listSet]; exact ih n (by simpa using h)

theorem listGet_set_ne (l : List Nat) (i j v : Nat) (h : i ≠ j) :
    listGet (listSet l i v) j = listGet l j := by
  induction l generalizing i j with
  | nil => simp [listGet, listSet]
  | cons _ xs ih =>
    cases i with
    | zero =>
      cases j with
      | zero   => exact absurd rfl h
      | succ _ => simp [listGet, listSet]
    | succ n =>
      cases j with
      | zero   => simp [listGet, listSet]
      | succ m =>
        simp only [listGet, listSet]
        exact ih n m (fun heq => h (congrArg Nat.succ heq))

-- Four consecutive writes; read at each position.
private theorem read4 (l : List Nat) (i v0 v1 v2 v3 : Nat)
    (h0 : i   < l.length) (h1 : i+1 < l.length)
    (h2 : i+2 < l.length) (h3 : i+3 < l.length) :
    let l4 := listSet (listSet (listSet (listSet l i v0) (i+1) v1) (i+2) v2) (i+3) v3
    listGet l4 i = v0 ∧ listGet l4 (i+1) = v1 ∧
    listGet l4 (i+2) = v2 ∧ listGet l4 (i+3) = v3 := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · rw [listGet_set_ne _ _ _ _ (by omega : i+3 ≠ i),
        listGet_set_ne _ _ _ _ (by omega : i+2 ≠ i),
        listGet_set_ne _ _ _ _ (by omega : i+1 ≠ i)]
    exact listGet_set_eq l i v0 h0
  · rw [listGet_set_ne _ _ _ _ (by omega : i+3 ≠ i+1),
        listGet_set_ne _ _ _ _ (by omega : i+2 ≠ i+1)]
    exact listGet_set_eq (listSet l i v0) (i+1) v1 (by rw [listSet_length]; exact h1)
  · rw [listGet_set_ne _ _ _ _ (by omega : i+3 ≠ i+2)]
    exact listGet_set_eq (listSet (listSet l i v0) (i+1) v1) (i+2) v2
      (by rw [listSet_length, listSet_length]; exact h2)
  · exact listGet_set_eq
      (listSet (listSet (listSet l i v0) (i+1) v1) (i+2) v2)
      (i+3) v3
      (by rw [listSet_length, listSet_length, listSet_length]; exact h3)

-- =============================================================================
-- §2  Buffer state
-- =============================================================================

structure OctetsMutState where
  buf : List Nat
  off : Nat
  deriving Repr, DecidableEq

def OctetsMutState.len (s : OctetsMutState) : Nat := s.buf.length
def OctetsMutState.cap (s : OctetsMutState) : Nat := s.buf.length - s.off
def OctetsMutState.Inv (s : OctetsMutState) : Prop := s.off ≤ s.buf.length

-- =============================================================================
-- §3  Capacity identity
-- =============================================================================

theorem cap_identity (s : OctetsMutState) (h : s.Inv) :
    s.off + s.cap = s.len := by
  simp only [OctetsMutState.cap, OctetsMutState.len, OctetsMutState.Inv] at *
  omega

-- =============================================================================
-- §4  Cursor operations: skip and rewind
-- =============================================================================

def OctetsMutState.skip (s : OctetsMutState) (n : Nat) : Option OctetsMutState :=
  if s.off + n ≤ s.buf.length then some { s with off := s.off + n } else none

def OctetsMutState.rewind (s : OctetsMutState) (n : Nat) : Option OctetsMutState :=
  if n ≤ s.off then some { s with off := s.off - n } else none

-- Extract the condition and the structural equality from skip/rewind results.
private theorem skip_unpack (s s' : OctetsMutState) (n : Nat) (h : s.skip n = some s') :
    s.off + n ≤ s.buf.length ∧ s'.buf = s.buf ∧ s'.off = s.off + n := by
  simp only [OctetsMutState.skip] at h
  by_cases hc : s.off + n ≤ s.buf.length
  · simp only [if_pos hc, Option.some.injEq] at h; subst h; exact ⟨hc, rfl, rfl⟩
  · simp [if_neg hc] at h

private theorem rewind_unpack (s s' : OctetsMutState) (n : Nat) (h : s.rewind n = some s') :
    n ≤ s.off ∧ s'.buf = s.buf ∧ s'.off = s.off - n := by
  simp only [OctetsMutState.rewind] at h
  by_cases hc : n ≤ s.off
  · simp only [if_pos hc, Option.some.injEq] at h; subst h; exact ⟨hc, rfl, rfl⟩
  · simp [if_neg hc] at h

theorem skip_advances_off (s s' : OctetsMutState) (n : Nat)
    (h : s.skip n = some s') : s'.off = s.off + n :=
  (skip_unpack s s' n h).2.2

theorem rewind_retreats_off (s s' : OctetsMutState) (n : Nat)
    (h : s.rewind n = some s') : s'.off = s.off - n :=
  (rewind_unpack s s' n h).2.2

theorem skip_buf_eq (s s' : OctetsMutState) (n : Nat)
    (h : s.skip n = some s') : s'.buf = s.buf :=
  (skip_unpack s s' n h).2.1

theorem rewind_buf_eq (s s' : OctetsMutState) (n : Nat)
    (h : s.rewind n = some s') : s'.buf = s.buf :=
  (rewind_unpack s s' n h).2.1

theorem skip_preserves_inv (s s' : OctetsMutState) (n : Nat)
    (hinv : s.Inv) (h : s.skip n = some s') : s'.Inv := by
  obtain ⟨hc, hb, ho⟩ := skip_unpack s s' n h
  simp only [OctetsMutState.Inv, hb, ho]; exact hc

theorem rewind_preserves_inv (s s' : OctetsMutState) (n : Nat)
    (hinv : s.Inv) (h : s.rewind n = some s') : s'.Inv := by
  obtain ⟨hc, hb, ho⟩ := rewind_unpack s s' n h
  simp only [OctetsMutState.Inv, OctetsMutState.Inv] at *
  rw [hb, ho]; omega

/-- skip followed by rewind restores offset and buffer. -/
theorem skip_rewind_inverse (s s' s'' : OctetsMutState) (n : Nat)
    (hs : s.skip n = some s') (hr : s'.rewind n = some s'') :
    s''.off = s.off ∧ s''.buf = s.buf := by
  obtain ⟨_, hb', ho'⟩ := skip_unpack s s' n hs
  obtain ⟨_, hb'', ho''⟩ := rewind_unpack s' s'' n hr
  constructor
  · rw [ho'', ho']; omega
  · rw [hb'', hb']

-- =============================================================================
-- §5  Single-byte operations
-- =============================================================================

def OctetsMutState.putU8 (s : OctetsMutState) (v : Nat) : Option OctetsMutState :=
  if s.off < s.buf.length then
    some { buf := listSet s.buf s.off v, off := s.off + 1 }
  else none

def OctetsMutState.getU8 (s : OctetsMutState) : Option (Nat × OctetsMutState) :=
  if s.off < s.buf.length then
    some (listGet s.buf s.off, { s with off := s.off + 1 })
  else none

def OctetsMutState.peekU8 (s : OctetsMutState) : Option Nat :=
  if s.off < s.buf.length then some (listGet s.buf s.off) else none

private theorem putU8_unpack (s s' : OctetsMutState) (v : Nat) (h : s.putU8 v = some s') :
    s.off < s.buf.length ∧ s'.buf = listSet s.buf s.off v ∧ s'.off = s.off + 1 := by
  simp only [OctetsMutState.putU8] at h
  by_cases hc : s.off < s.buf.length
  · simp only [if_pos hc, Option.some.injEq] at h; subst h; exact ⟨hc, rfl, rfl⟩
  · simp [if_neg hc] at h

theorem putU8_off (s s' : OctetsMutState) (v : Nat) (h : s.putU8 v = some s') :
    s'.off = s.off + 1 := (putU8_unpack s s' v h).2.2

theorem putU8_len (s s' : OctetsMutState) (v : Nat) (h : s.putU8 v = some s') :
    s'.buf.length = s.buf.length := by
  have := (putU8_unpack s s' v h).2.1
  rw [this, listSet_length]

theorem putU8_preserves_inv (s s' : OctetsMutState) (v : Nat)
    (hinv : s.Inv) (h : s.putU8 v = some s') : s'.Inv := by
  obtain ⟨hc, hb, ho⟩ := putU8_unpack s s' v h
  simp only [OctetsMutState.Inv, hb, ho, listSet_length]; omega

theorem peekU8_reads_off (s : OctetsMutState) (v : Nat)
    (h : s.peekU8 = some v) : v = listGet s.buf s.off := by
  simp only [OctetsMutState.peekU8] at h
  by_cases hc : s.off < s.buf.length
  · simp only [if_pos hc, Option.some.injEq] at h; exact h.symm
  · simp [if_neg hc] at h

/-- put_u8 / get_u8 round-trip: writing v then rewinding 1 and reading
    returns v. -/
theorem putU8_getU8_roundtrip (s s' s'' : OctetsMutState) (v : Nat)
    (hinv : s.Inv) (hp : s.putU8 v = some s') (hr : s'.rewind 1 = some s'') :
    ∃ r, s''.getU8 = some (v, r) := by
  obtain ⟨hc, hb', ho'⟩ := putU8_unpack s s' v hp
  obtain ⟨_, hb'', ho''⟩ := rewind_unpack s' s'' 1 hr
  -- s''.buf = s'.buf = listSet s.buf s.off v
  -- s''.off = s'.off - 1 = s.off
  have hs''off : s''.off = s.off := by rw [ho'', ho']; omega
  have hs''buf : s''.buf = listSet s.buf s.off v := by rw [hb'', hb']
  simp only [OctetsMutState.getU8, hs''off, hs''buf, listSet_length, if_pos hc]
  exact ⟨_, by rw [listGet_set_eq s.buf s.off v hc]⟩

/-- put_u8 / peek_u8 round-trip. -/
theorem putU8_peekU8_roundtrip (s s' s'' : OctetsMutState) (v : Nat)
    (hinv : s.Inv) (hp : s.putU8 v = some s') (hr : s'.rewind 1 = some s'') :
    s''.peekU8 = some v := by
  obtain ⟨hc, hb', ho'⟩ := putU8_unpack s s' v hp
  obtain ⟨_, hb'', ho''⟩ := rewind_unpack s' s'' 1 hr
  have hs''off : s''.off = s.off := by rw [ho'', ho']; omega
  have hs''buf : s''.buf = listSet s.buf s.off v := by rw [hb'', hb']
  simp only [OctetsMutState.peekU8, hs''off, hs''buf, listSet_length, if_pos hc,
             listGet_set_eq s.buf s.off v hc]

-- =============================================================================
-- §6  Two-byte big-endian: put_u16 / get_u16
-- =============================================================================

def OctetsMutState.putU16 (s : OctetsMutState) (v : Nat) : Option OctetsMutState :=
  if s.off + 1 < s.buf.length then
    some { buf := listSet (listSet s.buf s.off (v / 256)) (s.off + 1) (v % 256),
           off := s.off + 2 }
  else none

def OctetsMutState.getU16 (s : OctetsMutState) : Option (Nat × OctetsMutState) :=
  if s.off + 1 < s.buf.length then
    some (256 * listGet s.buf s.off + listGet s.buf (s.off + 1),
          { s with off := s.off + 2 })
  else none

private theorem putU16_unpack (s s' : OctetsMutState) (v : Nat) (h : s.putU16 v = some s') :
    s.off + 1 < s.buf.length ∧
    s'.buf = listSet (listSet s.buf s.off (v / 256)) (s.off + 1) (v % 256) ∧
    s'.off = s.off + 2 := by
  simp only [OctetsMutState.putU16] at h
  by_cases hc : s.off + 1 < s.buf.length
  · simp only [if_pos hc, Option.some.injEq] at h; subst h; exact ⟨hc, rfl, rfl⟩
  · simp [if_neg hc] at h

theorem putU16_off (s s' : OctetsMutState) (v : Nat) (h : s.putU16 v = some s') :
    s'.off = s.off + 2 := (putU16_unpack s s' v h).2.2

theorem putU16_len (s s' : OctetsMutState) (v : Nat) (h : s.putU16 v = some s') :
    s'.buf.length = s.buf.length := by
  rw [(putU16_unpack s s' v h).2.1, listSet_length, listSet_length]

/-- put_u16 / get_u16 round-trip for v < 65536 (after rewind by 2). -/
theorem putU16_getU16_roundtrip (s s' s'' : OctetsMutState) (v : Nat)
    (hv : v < 65536) (hinv : s.Inv)
    (hp : s.putU16 v = some s') (hr : s'.rewind 2 = some s'') :
    ∃ r, s''.getU16 = some (v, r) := by
  obtain ⟨hc, hb', ho'⟩ := putU16_unpack s s' v hp
  obtain ⟨_, hb'', ho''⟩ := rewind_unpack s' s'' 2 hr
  have hs''off : s''.off = s.off := by rw [ho'', ho']; omega
  have hs''buf : s''.buf = listSet (listSet s.buf s.off (v / 256)) (s.off + 1) (v % 256) :=
    by rw [hb'', hb']
  have rb0 : listGet s''.buf s.off = v / 256 := by
    rw [hs''buf]
    rw [listGet_set_ne _ _ _ _ (by omega : s.off + 1 ≠ s.off)]
    exact listGet_set_eq s.buf s.off (v / 256) (by omega)
  have rb1 : listGet s''.buf (s.off + 1) = v % 256 := by
    rw [hs''buf]
    exact listGet_set_eq _ _ _ (by simp only [listSet_length]; exact hc)
  refine ⟨⟨s''.buf, s.off + 2⟩, ?_⟩
  simp only [OctetsMutState.getU16, hs''off]
  have hlen : s''.buf.length = s.buf.length := by rw [hs''buf]; simp [listSet_length]
  rw [hlen, if_pos hc, rb0, rb1]
  simp only [Option.some.injEq, Prod.mk.injEq, eq_self_iff_true, and_true]
  omega

def OctetsMutState.putU32 (s : OctetsMutState) (v : Nat) : Option OctetsMutState :=
  if s.off + 3 < s.buf.length then
    some { buf := listSet (listSet (listSet (listSet s.buf
                    s.off       (v / 16777216))
                    (s.off + 1) (v / 65536 % 256))
                    (s.off + 2) (v / 256 % 256))
                    (s.off + 3) (v % 256),
           off := s.off + 4 }
  else none

def OctetsMutState.getU32 (s : OctetsMutState) : Option (Nat × OctetsMutState) :=
  if s.off + 3 < s.buf.length then
    some (  16777216 * listGet s.buf  s.off
          +    65536 * listGet s.buf (s.off + 1)
          +      256 * listGet s.buf (s.off + 2)
          +            listGet s.buf (s.off + 3),
            { s with off := s.off + 4 })
  else none

private theorem putU32_unpack (s s' : OctetsMutState) (v : Nat) (h : s.putU32 v = some s') :
    s.off + 3 < s.buf.length ∧
    s'.buf = listSet (listSet (listSet (listSet s.buf
                s.off       (v / 16777216))
                (s.off + 1) (v / 65536 % 256))
                (s.off + 2) (v / 256 % 256))
                (s.off + 3) (v % 256) ∧
    s'.off = s.off + 4 := by
  simp only [OctetsMutState.putU32] at h
  by_cases hc : s.off + 3 < s.buf.length
  · simp only [if_pos hc, Option.some.injEq] at h; subst h; exact ⟨hc, rfl, rfl⟩
  · simp [if_neg hc] at h

theorem putU32_off (s s' : OctetsMutState) (v : Nat) (h : s.putU32 v = some s') :
    s'.off = s.off + 4 := (putU32_unpack s s' v h).2.2

theorem putU32_len (s s' : OctetsMutState) (v : Nat) (h : s.putU32 v = some s') :
    s'.buf.length = s.buf.length := by
  rw [(putU32_unpack s s' v h).2.1]; simp [listSet_length]

/-- put_u32 / get_u32 round-trip for v < 2^32 (after rewind by 4). -/
theorem putU32_getU32_roundtrip (s s' s'' : OctetsMutState) (v : Nat)
    (hv : v < 4294967296) (hinv : s.Inv)
    (hp : s.putU32 v = some s') (hr : s'.rewind 4 = some s'') :
    ∃ r, s''.getU32 = some (v, r) := by
  obtain ⟨hc, hb', ho'⟩ := putU32_unpack s s' v hp
  obtain ⟨_, hb'', ho''⟩ := rewind_unpack s' s'' 4 hr
  have hs''off : s''.off = s.off := by rw [ho'', ho']; omega
  -- Buffer after writing 4 bytes then rewinding
  have hs''buf : s''.buf = listSet (listSet (listSet (listSet s.buf
                    s.off       (v / 16777216))
                    (s.off + 1) (v / 65536 % 256))
                    (s.off + 2) (v / 256 % 256))
                    (s.off + 3) (v % 256) := by rw [hb'', hb']
  -- Prove byte reads directly on the concrete buffer expression
  have eq0 : listGet s''.buf s.off = v / 16777216 := by
    rw [hs''buf]
    have : listGet (listSet s.buf s.off (v / 16777216)) s.off = v / 16777216 :=
      listGet_set_eq s.buf s.off _ (by omega)
    simp only [listGet_set_ne _ _ _ _ (by omega : s.off + 3 ≠ s.off),
               listGet_set_ne _ _ _ _ (by omega : s.off + 2 ≠ s.off),
               listGet_set_ne _ _ _ _ (by omega : s.off + 1 ≠ s.off)]
    exact listGet_set_eq s.buf s.off _ (by omega)
  have eq1 : listGet s''.buf (s.off + 1) = v / 65536 % 256 := by
    rw [hs''buf]
    simp only [listGet_set_ne _ _ _ _ (by omega : s.off + 3 ≠ s.off + 1),
               listGet_set_ne _ _ _ _ (by omega : s.off + 2 ≠ s.off + 1)]
    exact listGet_set_eq _ _ _ (by simp only [listSet_length]; omega)
  have eq2 : listGet s''.buf (s.off + 2) = v / 256 % 256 := by
    rw [hs''buf]
    simp only [listGet_set_ne _ _ _ _ (by omega : s.off + 3 ≠ s.off + 2)]
    exact listGet_set_eq _ _ _ (by simp only [listSet_length, listSet_length]; omega)
  have eq3 : listGet s''.buf (s.off + 3) = v % 256 := by
    rw [hs''buf]
    exact listGet_set_eq _ _ _ (by simp only [listSet_length, listSet_length]; omega)
  refine ⟨⟨s''.buf, s.off + 4⟩, ?_⟩
  simp only [OctetsMutState.getU32, hs''off]
  have hlen : s''.buf.length = s.buf.length := by rw [hs''buf]; simp [listSet_length]
  rw [hlen, if_pos hc, eq0, eq1, eq2, eq3]
  simp only [Option.some.injEq, Prod.mk.injEq, eq_self_iff_true, and_true]
  omega

-- =============================================================================
-- §8  Successive writes: offset accumulation
-- =============================================================================

theorem putU8_x2_off (s s1 s2 : OctetsMutState) (a b : Nat)
    (h1 : s.putU8 a = some s1) (h2 : s1.putU8 b = some s2) :
    s2.off = s.off + 2 := by
  have := putU8_off s s1 a h1; have := putU8_off s1 s2 b h2; omega

theorem putU8_x3_off (s s1 s2 s3 : OctetsMutState) (a b c : Nat)
    (h1 : s.putU8 a = some s1) (h2 : s1.putU8 b = some s2) (h3 : s2.putU8 c = some s3) :
    s3.off = s.off + 3 := by
  have := putU8_off s s1 a h1; have := putU8_off s1 s2 b h2
  have := putU8_off s2 s3 c h3; omega

theorem putU16_putU8_off (s s1 s2 : OctetsMutState) (v w : Nat)
    (h1 : s.putU16 v = some s1) (h2 : s1.putU8 w = some s2) :
    s2.off = s.off + 3 := by
  have := putU16_off s s1 v h1; have := putU8_off s1 s2 w h2; omega

theorem putU16_x2_off (s s1 s2 : OctetsMutState) (v w : Nat)
    (h1 : s.putU16 v = some s1) (h2 : s1.putU16 w = some s2) :
    s2.off = s.off + 4 := by
  have := putU16_off s s1 v h1; have := putU16_off s1 s2 w h2; omega

-- =============================================================================
-- §9  Concrete examples
-- =============================================================================

def exBuf : OctetsMutState := { buf := [0, 0, 0, 0], off := 0 }

example : exBuf.Inv := by simp [OctetsMutState.Inv, exBuf]
example : exBuf.len = 4 := by native_decide
example : exBuf.cap = 4 := by native_decide

-- put_u8 writes the byte and advances the cursor.
example : exBuf.putU8 42 = some { buf := [42, 0, 0, 0], off := 1 } := by
  native_decide

-- put_u16 big-endian: 1000 = 0x03E8 → [0x03, 0xE8].
example : exBuf.putU16 1000 = some { buf := [3, 232, 0, 0], off := 2 } := by
  native_decide

-- put_u32 big-endian: 0x12345678 = 305419896 → [18, 52, 86, 120].
example : exBuf.putU32 305419896 =
    some { buf := [18, 52, 86, 120], off := 4 } := by native_decide

-- Round-trip: write u32, rewind 4, read back.
example :
    (do let s ← exBuf.putU32 305419896
        let s ← s.rewind 4
        s.getU32) =
    some (305419896, { buf := [18, 52, 86, 120], off := 4 }) := by
  native_decide
