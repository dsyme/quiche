-- Copyright (C) 2025, Cloudflare, Inc.
-- All rights reserved.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/RecvBuf.lean
-- Lean 4 formal spec and proofs for RecvBuf (quiche/src/stream/recv_buf.rs).
--
-- 🔬 Lean Squad — automated formal verification.

-- =============================================================================
-- §1  Abstract model
-- =============================================================================
--
-- RecvBuf is modelled as a sorted list of non-overlapping byte intervals
-- together with a read cursor and a high-watermark offset.
--
-- Approximations vs. the Rust source:
--   • Byte contents are not modelled; only offsets and lengths matter.
--   • BTreeMap is modelled as a sorted List of chunks.
--   • Flow-control state, error codes, and drain mode are not modelled.
--   • The write() overlap-splitting algorithm is not modelled; only
--     its postconditions are stated.

/-- A buffered byte interval: bytes [off, off+len) of the stream. -/
structure Chunk where
  off : Nat
  len : Nat
  deriving Repr, DecidableEq

def Chunk.maxOff (c : Chunk) : Nat := c.off + c.len

/-- The abstract receive buffer state. -/
structure RecvBuf where
  chunks   : List Chunk   -- buffered, ordered by offset
  readOff  : Nat           -- read cursor
  highMark : Nat           -- highest byte offset received
  finOff   : Option Nat    -- final stream offset, if known
  deriving Repr

-- =============================================================================
-- §2  Well-formedness predicates
-- =============================================================================

def chunksOrdered : List Chunk → Prop
  | [] | [_] => True
  | a :: b :: rest => a.maxOff ≤ b.off ∧ chunksOrdered (b :: rest)

def chunksAbove (off : Nat) : List Chunk → Prop
  | []      => True
  | c :: cs => c.off ≥ off ∧ chunksAbove off cs

def chunksWithin (mark : Nat) : List Chunk → Prop
  | []      => True
  | c :: cs => c.maxOff ≤ mark ∧ chunksWithin mark cs

structure RecvBuf.Invariant (rb : RecvBuf) : Prop where
  off_le_mark  : rb.readOff ≤ rb.highMark
  above_cursor : chunksAbove rb.readOff rb.chunks
  ordered      : chunksOrdered rb.chunks
  fin_eq_mark  : ∀ f, rb.finOff = some f → f = rb.highMark
  within_mark  : chunksWithin rb.highMark rb.chunks

-- =============================================================================
-- §3  Observable API model
-- =============================================================================

def RecvBuf.maxOff (rb : RecvBuf) : Nat := rb.highMark

def RecvBuf.isFin (rb : RecvBuf) : Bool :=
  rb.finOff == some rb.readOff

def RecvBuf.ready (rb : RecvBuf) : Bool :=
  match rb.chunks with
  | []     => false
  | c :: _ => c.off == rb.readOff

def RecvBuf.empty : RecvBuf :=
  { chunks := [], readOff := 0, highMark := 0, finOff := none }

-- =============================================================================
-- §4  Invariant lemmas
-- =============================================================================

theorem RecvBuf.empty_inv : RecvBuf.empty.Invariant := {
  off_le_mark  := Nat.le_refl 0
  above_cursor := trivial
  ordered      := trivial
  fin_eq_mark  := fun _ h => by simp [RecvBuf.empty] at h
  within_mark  := trivial }

theorem maxOff_eq_highMark (rb : RecvBuf) : rb.maxOff = rb.highMark := rfl

theorem isFin_iff_off (rb : RecvBuf) :
    rb.isFin = true ↔ rb.finOff = some rb.readOff := by
  simp only [RecvBuf.isFin, beq_iff_eq]

theorem readOff_le_highMark (rb : RecvBuf) (hinv : rb.Invariant) :
    rb.readOff ≤ rb.highMark := hinv.off_le_mark

theorem finOff_eq_highMark (rb : RecvBuf) (hinv : rb.Invariant)
    (f : Nat) (hf : rb.finOff = some f) : f = rb.highMark :=
  hinv.fin_eq_mark f hf

theorem chunksAbove_mono (off off' : Nat) (h : off ≤ off') (cs : List Chunk)
    (ha : chunksAbove off' cs) : chunksAbove off cs := by
  induction cs with
  | nil => exact trivial
  | cons c rest ih => exact ⟨Nat.le_trans h ha.1, ih ha.2⟩

theorem chunksWithin_mono (m m' : Nat) (h : m ≤ m') (cs : List Chunk)
    (hw : chunksWithin m cs) : chunksWithin m' cs := by
  induction cs with
  | nil => exact trivial
  | cons _ rest ih => exact ⟨Nat.le_trans hw.1 h, ih hw.2⟩

theorem chunksOrdered_tail (c : Chunk) (cs : List Chunk)
    (h : chunksOrdered (c :: cs)) : chunksOrdered cs := by
  cases cs with
  | nil      => exact trivial
  | cons _ _ => exact h.2

-- =============================================================================
-- §5  emitN: advance the read cursor
-- =============================================================================

def RecvBuf.emitN (rb : RecvBuf) (n : Nat) : RecvBuf :=
  match rb.chunks with
  | [] => rb
  | c :: rest =>
    if c.len ≤ n then
      { rb with chunks := rest, readOff := rb.readOff + c.len }
    else
      { rb with
        chunks  := { off := c.off + n, len := c.len - n } :: rest
        readOff := rb.readOff + n }

private theorem emitN_nil (rb : RecvBuf) (n : Nat) (h : rb.chunks = []) :
    rb.emitN n = rb := by simp only [RecvBuf.emitN, h]

private theorem emitN_cons_ge (rb : RecvBuf) (n : Nat) (c : Chunk)
    (rest : List Chunk) (hrb : rb.chunks = c :: rest) (h : c.len ≤ n) :
    rb.emitN n = { rb with chunks := rest, readOff := rb.readOff + c.len } := by
  simp only [RecvBuf.emitN, hrb, h, ite_true]

private theorem emitN_cons_lt (rb : RecvBuf) (n : Nat) (c : Chunk)
    (rest : List Chunk) (hrb : rb.chunks = c :: rest) (h : ¬ c.len ≤ n) :
    rb.emitN n = { rb with
      chunks  := { off := c.off + n, len := c.len - n } :: rest
      readOff := rb.readOff + n } := by
  simp only [RecvBuf.emitN, hrb, h, ite_false]

theorem emitN_highMark (rb : RecvBuf) (n : Nat) :
    (rb.emitN n).highMark = rb.highMark := by
  cases hrb : rb.chunks with
  | nil => simp [emitN_nil rb n hrb]
  | cons c rest =>
    by_cases h : c.len ≤ n
    · simp [emitN_cons_ge rb n c rest hrb h]
    · simp [emitN_cons_lt rb n c rest hrb h]

theorem emitN_finOff (rb : RecvBuf) (n : Nat) :
    (rb.emitN n).finOff = rb.finOff := by
  cases hrb : rb.chunks with
  | nil => simp [emitN_nil rb n hrb]
  | cons c rest =>
    by_cases h : c.len ≤ n
    · simp [emitN_cons_ge rb n c rest hrb h]
    · simp [emitN_cons_lt rb n c rest hrb h]

theorem emitN_readOff_nondecreasing (rb : RecvBuf) (n : Nat) :
    (rb.emitN n).readOff ≥ rb.readOff := by
  cases hrb : rb.chunks with
  | nil => simp [emitN_nil rb n hrb]
  | cons c rest =>
    by_cases h : c.len ≤ n
    · simp [emitN_cons_ge rb n c rest hrb h]
    · simp [emitN_cons_lt rb n c rest hrb h]

-- =============================================================================
-- §6  emitN preserves invariants
-- =============================================================================

private theorem emitN_chunks_nil (rb : RecvBuf) (n : Nat) (hrb : rb.chunks = []) :
    (rb.emitN n).chunks = [] := by simp [emitN_nil rb n hrb, hrb]

theorem emitN_off_le_mark (rb : RecvBuf) (n : Nat) (hinv : rb.Invariant) :
    (rb.emitN n).readOff ≤ (rb.emitN n).highMark := by
  rw [emitN_highMark]
  cases hrb : rb.chunks with
  | nil =>
    simp [emitN_nil rb n hrb]
    exact hinv.off_le_mark
  | cons c rest =>
    have habove := hinv.above_cursor
    have hwithin := hinv.within_mark
    rw [hrb] at habove hwithin
    by_cases h : c.len ≤ n
    · simp [emitN_cons_ge rb n c rest hrb h]
      have hge : c.off ≥ rb.readOff := habove.1
      have hmk : c.maxOff ≤ rb.highMark := hwithin.1
      simp only [Chunk.maxOff] at hmk; omega
    · simp [emitN_cons_lt rb n c rest hrb h]
      -- n < c.len, c.maxOff ≤ highMark, c.off ≥ readOff → readOff + n ≤ highMark
      have hge : c.off ≥ rb.readOff := habove.1
      have hmk : c.maxOff ≤ rb.highMark := hwithin.1
      simp only [Chunk.maxOff] at hmk; omega

theorem emitN_within_mark (rb : RecvBuf) (n : Nat) (hinv : rb.Invariant) :
    chunksWithin (rb.emitN n).highMark (rb.emitN n).chunks := by
  rw [emitN_highMark]
  cases hrb : rb.chunks with
  | nil =>
    have hc : (rb.emitN n).chunks = [] := emitN_chunks_nil rb n hrb
    rw [hc]
    exact trivial
  | cons c rest =>
    have hwithin := hinv.within_mark
    rw [hrb] at hwithin
    by_cases h : c.len ≤ n
    · simp [emitN_cons_ge rb n c rest hrb h]
      exact hwithin.2
    · simp [emitN_cons_lt rb n c rest hrb h]
      constructor
      · simp only [Chunk.maxOff]
        have hmk := hwithin.1
        simp only [Chunk.maxOff] at hmk
        omega
      · exact hwithin.2

theorem emitN_fin_eq_mark (rb : RecvBuf) (n : Nat) (hinv : rb.Invariant) :
    ∀ f, (rb.emitN n).finOff = some f → f = (rb.emitN n).highMark := by
  intro f hf
  rw [emitN_finOff] at hf
  rw [emitN_highMark]
  exact hinv.fin_eq_mark f hf

theorem emitN_ordered (rb : RecvBuf) (n : Nat) (hinv : rb.Invariant) :
    chunksOrdered (rb.emitN n).chunks := by
  cases hrb : rb.chunks with
  | nil =>
    have hc : (rb.emitN n).chunks = [] := emitN_chunks_nil rb n hrb
    rw [hc]
    exact trivial
  | cons c rest =>
    have hord := hinv.ordered
    rw [hrb] at hord
    by_cases h : c.len ≤ n
    · simp [emitN_cons_ge rb n c rest hrb h]
      exact chunksOrdered_tail c rest hord
    · simp [emitN_cons_lt rb n c rest hrb h]
      cases hrest : rest with
      | nil   => exact trivial
      | cons d ds =>
        constructor
        · simp only [Chunk.maxOff]
          rw [hrest] at hord
          have hle := hord.1
          simp only [Chunk.maxOff] at hle
          omega
        · rw [← hrest]
          exact chunksOrdered_tail c rest hord

/-- Helper: from an ordered list starting at c, all subsequent chunks
    are above c's maxOff. -/
private theorem chunksAbove_of_ordered (c : Chunk) (cs : List Chunk)
    (hord : chunksOrdered (c :: cs)) : chunksAbove c.maxOff cs := by
  induction cs generalizing c with
  | nil => exact trivial
  | cons d ds ih =>
    have hle : c.maxOff ≤ d.off := hord.1
    have hd_above : chunksAbove d.maxOff ds := ih d hord.2
    exact ⟨hle, chunksAbove_mono c.maxOff d.maxOff
      (by simp only [Chunk.maxOff] at hle ⊢; omega) ds hd_above⟩

theorem emitN_above_cursor
    (rb : RecvBuf) (n : Nat)
    (hinv : rb.Invariant)
    (hready : rb.ready = true) :
    chunksAbove (rb.emitN n).readOff (rb.emitN n).chunks := by
  simp only [RecvBuf.ready] at hready
  cases hrb : rb.chunks with
  | nil => simp [hrb] at hready
  | cons c rest =>
    rw [hrb] at hready
    have hoffC : c.off = rb.readOff := by
      simp only [beq_iff_eq] at hready; exact hready
    have habove := hinv.above_cursor
    have hord   := hinv.ordered
    rw [hrb] at habove hord
    by_cases h : c.len ≤ n
    · -- Full consume: new readOff = rb.readOff + c.len
      simp [emitN_cons_ge rb n c rest hrb h]
      have above_cmax : chunksAbove c.maxOff rest :=
        chunksAbove_of_ordered c rest hord
      exact chunksAbove_mono (rb.readOff + c.len) c.maxOff
        (by simp only [Chunk.maxOff]; omega) rest above_cmax
    · -- Partial consume: new readOff = rb.readOff + n
      simp [emitN_cons_lt rb n c rest hrb h]
      have above_cmax : chunksAbove c.maxOff rest :=
        chunksAbove_of_ordered c rest hord
      constructor
      · -- New front chunk: {off := c.off + n}.off ≥ rb.readOff + n
        have : ({ off := c.off + n, len := c.len - n } : Chunk).off = c.off + n :=
          rfl
        rw [this]; omega
      · -- rest: above c.maxOff, and c.maxOff > rb.readOff + n
        exact chunksAbove_mono (rb.readOff + n) c.maxOff
          (by simp only [Chunk.maxOff]; omega) rest above_cmax

/-- Key theorem: emitN (when ready) preserves all invariants. -/
theorem emitN_preserves_inv
    (rb : RecvBuf) (n : Nat)
    (hinv : rb.Invariant)
    (hready : rb.ready = true) :
    (rb.emitN n).Invariant := {
  off_le_mark  := emitN_off_le_mark rb n hinv
  above_cursor := emitN_above_cursor rb n hinv hready
  ordered      := emitN_ordered rb n hinv
  fin_eq_mark  := emitN_fin_eq_mark rb n hinv
  within_mark  := emitN_within_mark rb n hinv }

-- =============================================================================
-- §7  Key safety properties
-- =============================================================================

/-- readOff never moves backward. -/
theorem emitN_readOff_monotone (rb : RecvBuf) (n : Nat) :
    (rb.emitN n).readOff ≥ rb.readOff :=
  emitN_readOff_nondecreasing rb n

/-- highMark never changes under emit. -/
theorem emitN_highMark_stable (rb : RecvBuf) (n : Nat) :
    (rb.emitN n).highMark = rb.highMark :=
  emitN_highMark rb n

/-- If isFin is true, there is nothing more to read: readOff = fin_off. -/
theorem isFin_readOff_eq_finOff
    (rb : RecvBuf) (_hinv : rb.Invariant) (hfin : rb.isFin = true) :
    rb.finOff = some rb.readOff := by
  rwa [isFin_iff_off] at hfin

/-- Under the invariant, if isFin then readOff = highMark. -/
theorem isFin_readOff_eq_highMark
    (rb : RecvBuf) (hinv : rb.Invariant) (hfin : rb.isFin = true) :
    rb.readOff = rb.highMark := by
  have hfo := isFin_readOff_eq_finOff rb hinv hfin
  have heq := finOff_eq_highMark rb hinv rb.readOff hfo
  exact heq

-- =============================================================================
-- §9  insertContiguous: in-order sequential write
-- =============================================================================
--
-- Models the common case where new data arrives exactly at highMark
-- (in-order delivery). This is the simplest non-trivial write path:
-- it avoids the BTreeMap overlap-splitting of the general write() algorithm.
--
-- Preconditions for invariant preservation:
--   • c.off = rb.highMark     (chunk is contiguous with end of buffer)
--   • c.len > 0               (chunk is non-empty)
--   • rb.finOff = none        (stream not yet finished)

/-- Append a new chunk starting exactly at highMark. -/
def RecvBuf.insertContiguous (rb : RecvBuf) (c : Chunk) : RecvBuf :=
  { rb with chunks := rb.chunks ++ [c], highMark := c.maxOff }

theorem insertContiguous_chunks (rb : RecvBuf) (c : Chunk) :
    (rb.insertContiguous c).chunks = rb.chunks ++ [c] := rfl

theorem insertContiguous_readOff (rb : RecvBuf) (c : Chunk) :
    (rb.insertContiguous c).readOff = rb.readOff := rfl

theorem insertContiguous_highMark (rb : RecvBuf) (c : Chunk) :
    (rb.insertContiguous c).highMark = c.maxOff := rfl

theorem insertContiguous_finOff (rb : RecvBuf) (c : Chunk) :
    (rb.insertContiguous c).finOff = rb.finOff := rfl

/-- A contiguous non-empty write strictly advances highMark. -/
theorem insertContiguous_highMark_grows
    (rb : RecvBuf) (c : Chunk) (hoff : c.off = rb.highMark) (hlen : c.len > 0) :
    (rb.insertContiguous c).highMark > rb.highMark := by
  simp only [insertContiguous_highMark, Chunk.maxOff]; omega

private theorem chunksAbove_snoc (off : Nat) (cs : List Chunk) (c : Chunk)
    (ha : chunksAbove off cs) (hc : c.off ≥ off) :
    chunksAbove off (cs ++ [c]) := by
  induction cs with
  | nil => exact ⟨hc, trivial⟩
  | cons _ rest ih =>
    simp only [List.cons_append]
    exact ⟨ha.1, ih ha.2⟩

private theorem chunksWithin_snoc (mark : Nat) (cs : List Chunk) (c : Chunk)
    (hw : chunksWithin mark cs) (hc : c.maxOff ≤ mark) :
    chunksWithin mark (cs ++ [c]) := by
  induction cs with
  | nil => exact ⟨hc, trivial⟩
  | cons _ rest ih =>
    simp only [List.cons_append]
    exact ⟨hw.1, ih hw.2⟩

private theorem chunksOrdered_snoc (cs : List Chunk) (c : Chunk)
    (hord : chunksOrdered cs) (hw : chunksWithin c.off cs) :
    chunksOrdered (cs ++ [c]) := by
  induction cs with
  | nil => exact trivial
  | cons a rest ih =>
    cases hrest : rest with
    | nil =>
      subst hrest
      show a.maxOff ≤ c.off ∧ chunksOrdered [c]
      exact ⟨hw.1, trivial⟩
    | cons b bs =>
      subst hrest
      show a.maxOff ≤ b.off ∧ chunksOrdered ((b :: bs) ++ [c])
      exact ⟨hord.1, ih hord.2 hw.2⟩

/-- insertContiguous preserves all buffer invariants
    when the chunk is contiguous, non-empty, and the stream is open. -/
theorem insertContiguous_inv
    (rb : RecvBuf) (c : Chunk)
    (hinv : rb.Invariant)
    (hoff  : c.off = rb.highMark)
    (hlen  : c.len > 0)
    (hfin  : rb.finOff = none) :
    (rb.insertContiguous c).Invariant := {
  off_le_mark := by
    simp only [insertContiguous_readOff, insertContiguous_highMark, Chunk.maxOff]
    exact Nat.le_trans hinv.off_le_mark (by omega)
  above_cursor := by
    simp only [insertContiguous_readOff, insertContiguous_chunks]
    exact chunksAbove_snoc rb.readOff rb.chunks c
      hinv.above_cursor (by rw [hoff]; exact hinv.off_le_mark)
  ordered := by
    simp only [insertContiguous_chunks]
    exact chunksOrdered_snoc rb.chunks c hinv.ordered (by rw [hoff]; exact hinv.within_mark)
  fin_eq_mark := by
    simp only [insertContiguous_finOff, insertContiguous_highMark]
    intro f hf; rw [hfin] at hf; exact absurd hf (by simp)
  within_mark := by
    simp only [insertContiguous_chunks, insertContiguous_highMark]
    apply chunksWithin_snoc
    · exact chunksWithin_mono rb.highMark c.maxOff
        (by simp only [Chunk.maxOff]; omega) rb.chunks hinv.within_mark
    · exact Nat.le_refl _ }

-- =============================================================================
-- §10  Monotonicity of highMark under write
-- =============================================================================
--
-- The general write() algorithm (out-of-order, overlap-handling) is not
-- concretely modelled here. We state the key safety property — highMark is
-- non-decreasing — as a theorem for the concrete insertContiguous model
-- and note it holds for the general write() by the same Rust-side argument.

/-- After a contiguous write, highMark does not decrease.
    (A non-strict bound; strict when hlen : c.len > 0.) -/
theorem insertContiguous_highMark_mono
    (rb : RecvBuf) (c : Chunk) (hoff : c.off = rb.highMark) :
    (rb.insertContiguous c).highMark ≥ rb.highMark := by
  simp only [insertContiguous_highMark, Chunk.maxOff]; omega

/-- Two sequential contiguous writes advance highMark by the sum of lengths. -/
theorem insertContiguous_two_highMark
    (rb : RecvBuf) (c1 c2 : Chunk)
    (hoff1 : c1.off = rb.highMark)
    (hoff2 : c2.off = (rb.insertContiguous c1).highMark) :
    (rb.insertContiguous c1 |>.insertContiguous c2).highMark =
      rb.highMark + c1.len + c2.len := by
  simp only [insertContiguous_highMark, Chunk.maxOff] at *; omega

-- =============================================================================
-- §8  Test vectors
-- =============================================================================

private def mkRecv (cs : List Chunk) (r m : Nat) (f : Option Nat) : RecvBuf :=
  { chunks := cs, readOff := r, highMark := m, finOff := f }

example : RecvBuf.empty.isFin = false := by native_decide
example : RecvBuf.empty.ready = false := by native_decide

example :
    (mkRecv [{ off := 0, len := 10 }] 0 10 none).ready = true := by
  native_decide

example :
    let rb  := mkRecv [{ off := 0, len := 10 }] 0 10 none
    let rb2 := rb.emitN 10
    rb2.readOff = 10 ∧ rb2.chunks = [] ∧ rb2.highMark = 10 := by
  native_decide

example :
    let rb  := mkRecv [{ off := 0, len := 10 }] 0 10 none
    let rb2 := rb.emitN 3
    rb2.readOff = 3 ∧ rb2.chunks = [{ off := 3, len := 7 }] := by
  native_decide

example :
    (mkRecv [] 10 10 (some 10)).isFin = true := by native_decide

example :
    (mkRecv [{ off := 5, len := 5 }] 0 10 (some 10)).isFin = false := by
  native_decide

-- insertContiguous test vectors
example :
    let rb  := RecvBuf.empty
    let c   := (Chunk.mk 0 10)
    (rb.insertContiguous c).highMark = 10 ∧
    (rb.insertContiguous c).readOff  = 0  ∧
    (rb.insertContiguous c).chunks   = [c] := by
  native_decide

example :
    let rb  := mkRecv [{ off := 0, len := 10 }] 0 10 none
    let c   := Chunk.mk 10 5
    (rb.insertContiguous c).highMark = 15 ∧
    (rb.insertContiguous c).chunks   = [{ off := 0, len := 10 }, c] := by
  native_decide

example :
    let rb  := RecvBuf.empty
    let c1  := Chunk.mk 0 10
    let c2  := Chunk.mk 10 5
    (rb.insertContiguous c1 |>.insertContiguous c2).highMark = 15 := by
  native_decide
