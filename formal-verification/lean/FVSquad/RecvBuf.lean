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

-- =============================================================================
-- §11  insertChunkInto: merge a chunk into a sorted non-overlapping list
-- =============================================================================
--
-- Models the inner loop of `RecvBuf::write()` in recv_buf.rs (lines ~150–210).
-- Existing data wins: any bytes of `c` that overlap existing chunks are
-- silently discarded (matching the Rust `continue 'tmp` / trim-start logic).
--
-- The algorithm walks the sorted list left-to-right and handles six cases:
--   1. c.len = 0 : nothing to insert
--   2. c ends before e starts (c.maxOff ≤ e.off) : prepend c
--   3. e ends before c starts (e.maxOff ≤ c.off) : keep e, recurse
--   4a. c has a left overhang AND fits within e's right end : insert left part
--   4b. c has a left overhang AND extends past e           : insert left part,
--       recurse with right remainder [e.maxOff, c.maxOff)
--   5a. c starts inside e and fits within e                : discard (existing wins)
--   5b. c starts inside e but extends past e               : recurse with
--       right remainder [e.maxOff, c.maxOff)

/-- Insert chunk `c` into sorted non-overlapping `cs`. Existing data wins. -/
def insertChunkInto : List Chunk → Chunk → List Chunk
  | [], c => if c.len = 0 then [] else [c]
  | e :: rest, c =>
    if c.len = 0 then e :: rest
    else if c.maxOff ≤ e.off then c :: e :: rest           -- case 2
    else if e.maxOff ≤ c.off then                          -- case 3
      e :: insertChunkInto rest c
    else if c.off < e.off then                             -- cases 4a/4b
      let leftPart := { off := c.off, len := e.off - c.off }
      if c.maxOff ≤ e.maxOff then leftPart :: e :: rest   -- case 4a
      else                                                  -- case 4b
        leftPart :: e ::
          insertChunkInto rest { off := e.maxOff, len := c.maxOff - e.maxOff }
    else if c.maxOff ≤ e.maxOff then e :: rest             -- case 5a: discard
    else                                                    -- case 5b
      e :: insertChunkInto rest { off := e.maxOff, len := c.maxOff - e.maxOff }

-- Equational lemmas for each branch (used in proof automation)
private theorem ici_nil_zero (c : Chunk) (h : c.len = 0) :
    insertChunkInto [] c = [] := by simp [insertChunkInto, h]

private theorem ici_nil_pos (c : Chunk) (h : c.len > 0) :
    insertChunkInto [] c = [c] := by
  simp [insertChunkInto, Nat.ne_of_gt h]

private theorem ici_cons_zero (e : Chunk) (rest : List Chunk) (c : Chunk)
    (h : c.len = 0) :
    insertChunkInto (e :: rest) c = e :: rest := by
  simp [insertChunkInto, h]

private theorem ici_cons_before (e : Chunk) (rest : List Chunk) (c : Chunk)
    (hp : c.len > 0) (h : c.maxOff ≤ e.off) :
    insertChunkInto (e :: rest) c = c :: e :: rest := by
  simp [insertChunkInto, Nat.ne_of_gt hp, h]

private theorem ici_cons_after (e : Chunk) (rest : List Chunk) (c : Chunk)
    (hp : c.len > 0) (h1 : ¬(c.maxOff ≤ e.off)) (h2 : e.maxOff ≤ c.off) :
    insertChunkInto (e :: rest) c = e :: insertChunkInto rest c := by
  simp [insertChunkInto, Nat.ne_of_gt hp, h1, h2]

private theorem ici_cons_leftfit (e : Chunk) (rest : List Chunk) (c : Chunk)
    (hp : c.len > 0) (h1 : ¬(c.maxOff ≤ e.off)) (h2 : ¬(e.maxOff ≤ c.off))
    (h3 : c.off < e.off) (h4 : c.maxOff ≤ e.maxOff) :
    insertChunkInto (e :: rest) c =
      { off := c.off, len := e.off - c.off } :: e :: rest := by
  simp [insertChunkInto, Nat.ne_of_gt hp, h1, h2, h3, h4]

private theorem ici_cons_leftext (e : Chunk) (rest : List Chunk) (c : Chunk)
    (hp : c.len > 0) (h1 : ¬(c.maxOff ≤ e.off)) (h2 : ¬(e.maxOff ≤ c.off))
    (h3 : c.off < e.off) (h4 : ¬(c.maxOff ≤ e.maxOff)) :
    insertChunkInto (e :: rest) c =
      { off := c.off, len := e.off - c.off } :: e ::
        insertChunkInto rest { off := e.maxOff, len := c.maxOff - e.maxOff } := by
  simp [insertChunkInto, Nat.ne_of_gt hp, h1, h2, h3, h4]

private theorem ici_cons_contained (e : Chunk) (rest : List Chunk) (c : Chunk)
    (hp : c.len > 0) (h1 : ¬(c.maxOff ≤ e.off)) (h2 : ¬(e.maxOff ≤ c.off))
    (h3 : ¬(c.off < e.off)) (h4 : c.maxOff ≤ e.maxOff) :
    insertChunkInto (e :: rest) c = e :: rest := by
  simp [insertChunkInto, Nat.ne_of_gt hp, h1, h2, h3, h4]

private theorem ici_cons_rightext (e : Chunk) (rest : List Chunk) (c : Chunk)
    (hp : c.len > 0) (h1 : ¬(c.maxOff ≤ e.off)) (h2 : ¬(e.maxOff ≤ c.off))
    (h3 : ¬(c.off < e.off)) (h4 : ¬(c.maxOff ≤ e.maxOff)) :
    insertChunkInto (e :: rest) c =
      e :: insertChunkInto rest { off := e.maxOff, len := c.maxOff - e.maxOff } := by
  simp [insertChunkInto, Nat.ne_of_gt hp, h1, h2, h3, h4]

-- =============================================================================
-- §12  insertChunkInto: structural invariant preservation
-- =============================================================================

/-- In a sorted list, all elements after the head have `off ≥ head.maxOff`. -/
private theorem chunksOrdered_head_above :
    ∀ (e : Chunk) (cs : List Chunk),
    chunksOrdered (e :: cs) → chunksAbove e.maxOff cs := by
  intro e cs
  induction cs generalizing e with
  | nil => intro; exact trivial
  | cons f rest ih =>
    intro hord
    -- hord unfolds to: e.maxOff ≤ f.off ∧ chunksOrdered (f :: rest)
    obtain ⟨h1, h2⟩ := hord
    refine ⟨h1, ?_⟩
    -- Need: chunksAbove e.maxOff rest.
    -- IH gives: chunksAbove f.maxOff rest (from chunksOrdered (f :: rest))
    -- Since e.maxOff ≤ f.off ≤ f.maxOff, apply monotonicity.
    have hfm : f.maxOff ≥ e.maxOff := Nat.le_trans h1 (Nat.le_add_right f.off f.len)
    exact chunksAbove_mono e.maxOff f.maxOff hfm rest (ih f h2)

/-- `insertChunkInto` preserves `chunksAbove`: every element of the result
    has `off ≥ off'` when the inserted chunk and the input list do too. -/
theorem insertChunkInto_above (off : Nat) :
    ∀ (cs : List Chunk) (c : Chunk),
    chunksAbove off cs → c.off ≥ off → c.len > 0 →
    chunksAbove off (insertChunkInto cs c) := by
  intro cs
  induction cs generalizing off with
  | nil =>
    intro c _ hc hp
    rw [ici_nil_pos c hp]
    exact ⟨hc, trivial⟩
  | cons e rest ih =>
    intro c ha hc hp
    by_cases h1 : c.len = 0
    · omega
    · have hp' : c.len > 0 := Nat.pos_of_ne_zero h1
      by_cases h2 : c.maxOff ≤ e.off
      · rw [ici_cons_before e rest c hp' h2]
        exact ⟨hc, ha⟩
      · by_cases h3 : e.maxOff ≤ c.off
        · rw [ici_cons_after e rest c hp' h2 h3]
          exact ⟨ha.1, ih off c ha.2 hc hp'⟩
        · by_cases h4 : c.off < e.off
          · have he_above : e.off ≥ off := ha.1
            have hem : e.maxOff ≥ off := Nat.le_trans ha.1 (Nat.le_add_right e.off e.len)
            by_cases h5 : c.maxOff ≤ e.maxOff
            · rw [ici_cons_leftfit e rest c hp' h2 (by omega) h4 h5]
              exact ⟨hc, ha⟩
            · rw [ici_cons_leftext e rest c hp' h2 (by omega) h4 h5]
              refine ⟨hc, ⟨he_above, ?_⟩⟩
              exact ih off { off := e.maxOff, len := c.maxOff - e.maxOff }
                ha.2 hem (show c.maxOff - e.maxOff > 0 from by omega)
          · have hem : e.maxOff ≥ off := Nat.le_trans ha.1 (Nat.le_add_right e.off e.len)
            by_cases h5 : c.maxOff ≤ e.maxOff
            · rw [ici_cons_contained e rest c hp' h2 (by omega) (by omega) h5]
              exact ha
            · rw [ici_cons_rightext e rest c hp' h2 (by omega) (by omega) h5]
              exact ⟨ha.1, ih off { off := e.maxOff, len := c.maxOff - e.maxOff }
                ha.2 hem (show c.maxOff - e.maxOff > 0 from by omega)⟩

/-- `insertChunkInto` preserves `chunksWithin`: all elements stay within `mark`
    when the new chunk's maxOff ≤ mark and the existing list is within mark. -/
theorem insertChunkInto_within (mark : Nat) :
    ∀ (cs : List Chunk) (c : Chunk),
    chunksWithin mark cs → c.maxOff ≤ mark → c.len > 0 →
    chunksWithin mark (insertChunkInto cs c) := by
  intro cs
  induction cs generalizing mark with
  | nil =>
    intro c _ hm hp
    rw [ici_nil_pos c hp]
    exact ⟨hm, trivial⟩
  | cons e rest ih =>
    intro c hw hm hp
    by_cases h1 : c.len = 0; · omega
    have hp' : c.len > 0 := Nat.pos_of_ne_zero h1
    by_cases h2 : c.maxOff ≤ e.off
    · rw [ici_cons_before e rest c hp' h2]
      exact ⟨hm, hw⟩
    · by_cases h3 : e.maxOff ≤ c.off
      · rw [ici_cons_after e rest c hp' h2 h3]
        exact ⟨hw.1, ih mark c hw.2 hm hp'⟩
      · by_cases h4 : c.off < e.off
        · have hlp_max : (Chunk.maxOff { off := c.off, len := e.off - c.off }) ≤ mark := by
            simp [Chunk.maxOff]; omega
          by_cases h5 : c.maxOff ≤ e.maxOff
          · rw [ici_cons_leftfit e rest c hp' h2 (by omega) h4 h5]
            exact ⟨hlp_max, hw⟩
          · rw [ici_cons_leftext e rest c hp' h2 (by omega) h4 h5]
            have hrp_max : (Chunk.maxOff { off := e.maxOff, len := c.maxOff - e.maxOff }) ≤ mark := by
              simp only [Chunk.maxOff] at *; omega
            exact ⟨hlp_max, ⟨hw.1, ih mark _ hw.2 hrp_max
              (show c.maxOff - e.maxOff > 0 from by omega)⟩⟩
        · by_cases h5 : c.maxOff ≤ e.maxOff
          · rw [ici_cons_contained e rest c hp' h2 (by omega) (by omega) h5]
            exact hw
          · rw [ici_cons_rightext e rest c hp' h2 (by omega) (by omega) h5]
            have hrp_max : (Chunk.maxOff { off := e.maxOff, len := c.maxOff - e.maxOff }) ≤ mark := by
              simp only [Chunk.maxOff] at *; omega
            exact ⟨hw.1, ih mark _ hw.2 hrp_max
              (show c.maxOff - e.maxOff > 0 from by omega)⟩

/-- `insertChunkInto` preserves sorted non-overlapping order. -/
theorem insertChunkInto_ordered :
    ∀ (cs : List Chunk) (c : Chunk),
    chunksOrdered cs → chunksOrdered (insertChunkInto cs c) := by
  intro cs
  induction cs with
  | nil =>
    intro c _
    by_cases h : c.len = 0
    · rw [ici_nil_zero c h]; trivial
    · rw [ici_nil_pos c (Nat.pos_of_ne_zero h)]; trivial
  | cons e rest ih =>
    intro c hord
    by_cases h1 : c.len = 0
    · rw [ici_cons_zero e rest c h1]; exact hord
    · have hp : c.len > 0 := Nat.pos_of_ne_zero h1
      by_cases h2 : c.maxOff ≤ e.off
      · -- case 2: c :: e :: rest
        rw [ici_cons_before e rest c hp h2]
        exact ⟨h2, hord⟩
      · by_cases h3 : e.maxOff ≤ c.off
        · -- case 3: e :: insertChunkInto rest c
          rw [ici_cons_after e rest c hp h2 h3]
          have hrest_ord : chunksOrdered rest := chunksOrdered_tail e rest hord
          have hins_ord   : chunksOrdered (insertChunkInto rest c) := ih c hrest_ord
          have hrest_above : chunksAbove e.maxOff rest :=
            chunksOrdered_head_above e rest hord
          have hins_above : chunksAbove e.maxOff (insertChunkInto rest c) :=
            insertChunkInto_above e.maxOff rest c hrest_above h3 hp
          cases hins : insertChunkInto rest c with
          | nil => simpa [hins] using hins_ord
          | cons g gs =>
            have hg : g.off ≥ e.maxOff := by
              have := hins ▸ hins_above; exact this.1
            exact ⟨hg, hins ▸ hins_ord⟩
        · -- overlap: c.off < e.maxOff
          by_cases h4 : c.off < e.off
          · by_cases h5 : c.maxOff ≤ e.maxOff
            · -- case 4a: leftPart :: e :: rest
              rw [ici_cons_leftfit e rest c hp h2 (by omega) h4 h5]
              constructor
              · simp [Chunk.maxOff]; omega
              · exact hord
            · -- case 4b: leftPart :: e :: insertChunkInto rest rp
              rw [ici_cons_leftext e rest c hp h2 (by omega) h4 h5]
              have hrp_len : (0 : Nat) < c.maxOff - e.maxOff := by omega
              have hrest_ord : chunksOrdered rest := chunksOrdered_tail e rest hord
              have hrest_above : chunksAbove e.maxOff rest :=
                chunksOrdered_head_above e rest hord
              have hins_ord : chunksOrdered (insertChunkInto rest ⟨e.maxOff, c.maxOff - e.maxOff⟩) :=
                ih ⟨e.maxOff, c.maxOff - e.maxOff⟩ hrest_ord
              have hins_above : chunksAbove e.maxOff
                  (insertChunkInto rest ⟨e.maxOff, c.maxOff - e.maxOff⟩) :=
                insertChunkInto_above e.maxOff rest ⟨e.maxOff, c.maxOff - e.maxOff⟩
                  hrest_above (Nat.le_refl _) hrp_len
              refine ⟨by simp only [Chunk.maxOff] at *; omega, ?_⟩
              cases hins : insertChunkInto rest ⟨e.maxOff, c.maxOff - e.maxOff⟩ with
              | nil => trivial
              | cons g gs =>
                exact ⟨(hins ▸ hins_above).1, hins ▸ hins_ord⟩
          · by_cases h5 : c.maxOff ≤ e.maxOff
            · -- case 5a: discard c
              rw [ici_cons_contained e rest c hp h2 (by omega) (by omega) h5]
              exact hord
            · -- case 5b: e :: insertChunkInto rest rp
              rw [ici_cons_rightext e rest c hp h2 (by omega) (by omega) h5]
              have hrp_len : (0 : Nat) < c.maxOff - e.maxOff := by omega
              have hrest_ord : chunksOrdered rest := chunksOrdered_tail e rest hord
              have hrest_above : chunksAbove e.maxOff rest :=
                chunksOrdered_head_above e rest hord
              have hins_ord : chunksOrdered
                  (insertChunkInto rest ⟨e.maxOff, c.maxOff - e.maxOff⟩) :=
                ih ⟨e.maxOff, c.maxOff - e.maxOff⟩ hrest_ord
              have hins_above : chunksAbove e.maxOff
                  (insertChunkInto rest ⟨e.maxOff, c.maxOff - e.maxOff⟩) :=
                insertChunkInto_above e.maxOff rest ⟨e.maxOff, c.maxOff - e.maxOff⟩
                  hrest_above (Nat.le_refl _) hrp_len
              cases hins : insertChunkInto rest ⟨e.maxOff, c.maxOff - e.maxOff⟩ with
              | nil => trivial
              | cons g gs =>
                exact ⟨(hins ▸ hins_above).1, hins ▸ hins_ord⟩

-- =============================================================================
-- §13  insertAny: general write (out-of-order, overlap-safe)
-- =============================================================================
--
-- Models `RecvBuf::write()` in recv_buf.rs.  The preconditions mirror the
-- Rust invariants upheld by the caller:
--   • hfin: if the stream is finished, the new chunk does not extend beyond
--     the known final offset (preventing FinalSize errors).
--   • Byte contents, flow-control limits, and the `drain` flag are not modelled.

/-- Trim a chunk to start at `floor`, discarding bytes before `floor`. -/
private def trimChunk (c : Chunk) (floor : Nat) : Chunk :=
  if floor ≤ c.off then c
  else
    let drop := min (floor - c.off) c.len
    { off := c.off + drop, len := c.len - drop }

private theorem trimChunk_off_ge (c : Chunk) (floor : Nat)
    (hp : (trimChunk c floor).len > 0) :
    (trimChunk c floor).off ≥ floor := by
  by_cases h : floor ≤ c.off
  · simp only [trimChunk, if_pos h] at *; exact h
  · simp only [trimChunk, if_neg h] at *
    have h1 : min (floor - c.off) c.len ≤ floor - c.off := Nat.min_le_left _ _
    have h2 : min (floor - c.off) c.len ≤ c.len := Nat.min_le_right _ _
    omega

private theorem trimChunk_maxOff_le (c : Chunk) (floor : Nat) :
    (trimChunk c floor).maxOff ≤ c.maxOff := by
  by_cases h : floor ≤ c.off
  · simp only [trimChunk, if_pos h, Chunk.maxOff]; omega
  · simp only [trimChunk, if_neg h, Chunk.maxOff]
    have h1 : min (floor - c.off) c.len ≤ c.len := Nat.min_le_right _ _
    omega

/-- `insertChunkInto` with a zero-length chunk is the identity. -/
private theorem insertChunkInto_zero (cs : List Chunk) (c : Chunk) (h : c.len = 0) :
    insertChunkInto cs c = cs := by
  cases cs with
  | nil => simp [ici_nil_zero c h]
  | cons e rest => simp [ici_cons_zero e rest c h]

/-- General write: insert `c` into the buffer, trimming bytes below `readOff`
    and discarding any bytes of `c` that overlap existing buffered data. -/
def RecvBuf.insertAny (rb : RecvBuf) (c : Chunk) : RecvBuf :=
  let c' := trimChunk c rb.readOff
  { rb with
    chunks   := insertChunkInto rb.chunks c'
    highMark := Nat.max rb.highMark c.maxOff }

theorem insertAny_readOff_unchanged (rb : RecvBuf) (c : Chunk) :
    (rb.insertAny c).readOff = rb.readOff := rfl

theorem insertAny_finOff_unchanged (rb : RecvBuf) (c : Chunk) :
    (rb.insertAny c).finOff = rb.finOff := rfl

theorem insertAny_highMark_mono (rb : RecvBuf) (c : Chunk) :
    (rb.insertAny c).highMark ≥ rb.highMark := Nat.le_max_left _ _

theorem insertAny_highMark_ge_chunk (rb : RecvBuf) (c : Chunk) :
    (rb.insertAny c).highMark ≥ c.maxOff := Nat.le_max_right _ _

theorem insertAny_highMark_eq (rb : RecvBuf) (c : Chunk) :
    (rb.insertAny c).highMark = Nat.max rb.highMark c.maxOff := rfl

/-- `insertAny` preserves all buffer invariants when:
    - the inserted chunk is within flow-control bounds (c.maxOff ≤ new highMark,
      which is trivially satisfied since highMark := max rb.highMark c.maxOff), and
    - the finOff invariant is respected: if the stream is already FIN'd, the
      chunk does not extend beyond the known final offset. -/
theorem insertAny_inv
    (rb : RecvBuf) (c : Chunk)
    (hinv  : rb.Invariant)
    (hfin  : ∀ f, rb.finOff = some f → c.maxOff ≤ f) :
    (rb.insertAny c).Invariant := by
  constructor
  · -- off_le_mark: readOff ≤ max highMark c.maxOff
    simp only [insertAny_readOff_unchanged, insertAny_highMark_eq]
    exact Nat.le_trans hinv.off_le_mark (Nat.le_max_left _ _)
  · -- above_cursor: chunks above readOff
    simp only [RecvBuf.insertAny]
    by_cases hp : (trimChunk c rb.readOff).len > 0
    · have hc'_off : (trimChunk c rb.readOff).off ≥ rb.readOff :=
        trimChunk_off_ge c rb.readOff hp
      exact insertChunkInto_above rb.readOff rb.chunks (trimChunk c rb.readOff)
        hinv.above_cursor hc'_off hp
    · simp only [Nat.not_lt, Nat.le_zero] at hp
      rw [insertChunkInto_zero _ _ hp]
      exact hinv.above_cursor
  · -- ordered
    simp only [RecvBuf.insertAny]
    by_cases hp : (trimChunk c rb.readOff).len > 0
    · exact insertChunkInto_ordered rb.chunks (trimChunk c rb.readOff) hinv.ordered
    · simp only [Nat.not_lt, Nat.le_zero] at hp
      rw [insertChunkInto_zero _ _ hp]
      exact hinv.ordered
  · -- fin_eq_mark: if finOff = some f then f = new highMark
    intro f hf
    simp only [insertAny_finOff_unchanged] at hf
    simp only [insertAny_highMark_eq]
    -- f = old highMark (by hinv)
    have hfm : f = rb.highMark := hinv.fin_eq_mark f hf
    -- c.maxOff ≤ f = old highMark (by precondition hfin)
    have hcf : c.maxOff ≤ f := hfin f hf
    -- max rb.highMark c.maxOff = rb.highMark = f
    subst hfm; simp [Nat.max_eq_left hcf]
  · -- within_mark: all chunks ≤ new highMark
    simp only [RecvBuf.insertAny]
    have hc'_max : (trimChunk c rb.readOff).maxOff ≤ Nat.max rb.highMark c.maxOff := by
      exact Nat.le_trans (trimChunk_maxOff_le c rb.readOff) (Nat.le_max_right _ _)
    have hw_mono : chunksWithin (Nat.max rb.highMark c.maxOff) rb.chunks := by
      exact chunksWithin_mono rb.highMark _ (Nat.le_max_left _ _) _ hinv.within_mark
    by_cases hp : (trimChunk c rb.readOff).len > 0
    · exact insertChunkInto_within _ rb.chunks (trimChunk c rb.readOff) hw_mono hc'_max hp
    · simp only [Nat.not_lt, Nat.le_zero] at hp
      rw [insertChunkInto_zero _ _ hp]
      exact hw_mono

-- =============================================================================
-- §14  insertAny test vectors
-- =============================================================================

/-- Insert non-overlapping chunk into empty buffer. -/
example :
    let rb  := RecvBuf.empty
    let c   := Chunk.mk 0 10
    (rb.insertAny c).highMark = 10 ∧
    (rb.insertAny c).readOff  = 0  ∧
    (rb.insertAny c).chunks   = [c] := by
  native_decide

/-- Fully duplicate chunk (covered by existing) is silently dropped. -/
example :
    let rb := mkRecv [{ off := 0, len := 10 }] 0 10 none
    let c  := Chunk.mk 3 5   -- [3,8) ⊆ [0,10)
    (rb.insertAny c).chunks = [{ off := 0, len := 10 }] ∧
    (rb.insertAny c).highMark = 10 := by
  native_decide

/-- Out-of-order chunk before existing data. -/
example :
    let rb := mkRecv [{ off := 5, len := 5 }] 0 10 none
    let c  := Chunk.mk 0 5   -- [0,5) before [5,10)
    (rb.insertAny c).chunks = [{ off := 0, len := 5 }, { off := 5, len := 5 }] ∧
    (rb.insertAny c).highMark = 10 := by
  native_decide

/-- Chunk that extends the buffer beyond existing highMark. -/
example :
    let rb := mkRecv [{ off := 0, len := 10 }] 0 10 none
    let c  := Chunk.mk 10 5  -- [10,15) contiguous
    (rb.insertAny c).chunks   = [{ off := 0, len := 10 }, { off := 10, len := 5 }] ∧
    (rb.insertAny c).highMark = 15 := by
  native_decide

/-- Left-overhang chunk: [0,7) with existing [5,10) → keeps [0,5) only. -/
example :
    let rb := mkRecv [{ off := 5, len := 5 }] 0 10 none
    let c  := Chunk.mk 0 7   -- [0,7) overlaps [5,10) at [5,7)
    -- left part [0,5) inserted; [5,7) discarded (existing wins); result [0,5),[5,10)
    (rb.insertAny c).chunks = [{ off := 0, len := 5 }, { off := 5, len := 5 }] ∧
    (rb.insertAny c).highMark = 10 := by
  native_decide

/-- Chunk below readOff is trimmed away. -/
example :
    let rb := mkRecv [] 5 5 none  -- readOff = 5
    let c  := Chunk.mk 0 5        -- [0,5) fully below cursor
    (rb.insertAny c).chunks   = [] ∧
    (rb.insertAny c).highMark = 5 := by
  native_decide

/-- Chunk partially below readOff is trimmed to [readOff, c.maxOff). -/
example :
    let rb := mkRecv [] 3 3 none  -- readOff = 3
    let c  := Chunk.mk 0 8        -- [0,8) → trimmed to [3,8)
    (rb.insertAny c).chunks   = [{ off := 3, len := 5 }] ∧
    (rb.insertAny c).highMark = 8 := by
  native_decide
