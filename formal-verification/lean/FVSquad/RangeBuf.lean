-- Copyright (C) 2025, Cloudflare, Inc.
-- All rights reserved.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/RangeBuf.lean
-- Lean 4 formal model and proofs for RangeBuf (quiche/src/range_buf.rs).
--
-- 🔬 Lean Squad — automated formal verification.

-- =============================================================================
-- §1  Abstract model
-- =============================================================================
--
-- A RangeBuf carries a slice of bytes at a specific stream offset.
-- We abstract away the actual byte data and the internal start/pos/data
-- fields, retaining only the quantities observable through the public API:
--
--   off      : Nat  — stream offset at construction (= buf.off - buf.start)
--   len      : Nat  — total byte count at construction (= buf.len)
--   consumed : Nat  — bytes consumed so far via consume() (= buf.pos - buf.start)
--   fin      : Bool — whether this buffer carries the FIN flag
--
-- The key observable quantities are:
--   curOff  = off + consumed          (≈ buf.off())
--   curLen  = len - consumed          (≈ buf.len())
--   maxOff  = off + len               (≈ buf.max_off())
--
-- Fundamental identity: maxOff = curOff + curLen   (always holds)
--
-- Approximations vs. the Rust source:
--   • Byte contents are abstracted away (only lengths matter for offset proofs).
--   • split_off(at) requires at ≤ len (matching the Rust assert).
--   • pos/start internals are collapsed into a single `consumed` counter.
--   • fin flag is tracked but only its preservation through split is proved.
--   • Flow-control and BufFactory type parameters are not modelled.

structure RangeBuf where
  /-- Stream offset at construction. -/
  off      : Nat
  /-- Total byte length at construction (fixed; ≤ 2^62 in practice). -/
  len      : Nat
  /-- Bytes consumed via `consume()`. -/
  consumed : Nat
  /-- Whether this carries the final byte of the stream. -/
  fin      : Bool
  /-- Invariant: consumed ≤ len. -/
  hcons    : consumed ≤ len
  deriving Repr

-- =============================================================================
-- §2  Observable API
-- =============================================================================

/-- Current stream offset of the first unconsumed byte.
    Corresponds to `buf.off()` in Rust. -/
def RangeBuf.curOff (rb : RangeBuf) : Nat := rb.off + rb.consumed

/-- Number of unconsumed bytes remaining.
    Corresponds to `buf.len()` in Rust. -/
def RangeBuf.curLen (rb : RangeBuf) : Nat := rb.len - rb.consumed

/-- One-past-last stream offset (= off + len, invariant under consume).
    Corresponds to `buf.max_off()` in Rust. -/
def RangeBuf.maxOff (rb : RangeBuf) : Nat := rb.off + rb.len

-- =============================================================================
-- §3  Operations
-- =============================================================================

/-- Consume the first `count` bytes. Requires count ≤ curLen.
    Corresponds to `buf.consume(count)`. -/
def RangeBuf.consume (rb : RangeBuf) (count : Nat) (h : count ≤ rb.curLen) :
    RangeBuf :=
  { rb with
    consumed := rb.consumed + count,
    hcons    := by
      have hcons := rb.hcons
      simp only [RangeBuf.curLen] at h
      omega }

/-- Helper: Nat.max a b = if a ≤ b then b else a, useful for proofs. -/
private theorem max_split (a b : Nat) :
    (Nat.max a b = b ∧ a ≤ b) ∨ (Nat.max a b = a ∧ b ≤ a) := by
  simp only [Nat.max_def]
  split <;> omega

/-- Split the buffer at byte offset `at_` (relative to construction start).
    Returns (left, right) such that left covers [off, off+at_) and
    right covers [off+at_, off+len).
    Requires at_ ≤ len (matching the Rust assert).
    Corresponds to `self.split_off(at_)` which mutates self (left) and
    returns the right half. -/
def RangeBuf.splitOff (rb : RangeBuf) (at_ : Nat) (hat : at_ ≤ rb.len) :
    RangeBuf × RangeBuf :=
  let leftConsumed  := Nat.min rb.consumed at_
  let rightConsumed := Nat.max rb.consumed at_ - at_
  let left : RangeBuf :=
    { off      := rb.off
      len      := at_
      consumed := leftConsumed
      fin      := false
      hcons    := Nat.min_le_right rb.consumed at_ }
  let right : RangeBuf :=
    { off      := rb.off + at_
      len      := rb.len - at_
      consumed := rightConsumed
      fin      := rb.fin
      hcons    := by
        simp only [rightConsumed, Nat.max_def]
        have hcons := rb.hcons
        split <;> omega }
  (left, right)

-- =============================================================================
-- §4  Basic identities
-- =============================================================================

/-- maxOff equals the sum of curOff and curLen (fundamental identity). -/
theorem maxOff_identity (rb : RangeBuf) :
    rb.maxOff = rb.curOff + rb.curLen := by
  have hcons := rb.hcons
  simp only [RangeBuf.maxOff, RangeBuf.curOff, RangeBuf.curLen]
  omega

/-- curOff never exceeds maxOff. -/
theorem curOff_le_maxOff (rb : RangeBuf) : rb.curOff ≤ rb.maxOff := by
  have hcons := rb.hcons
  simp only [RangeBuf.curOff, RangeBuf.maxOff]
  omega

/-- curLen never exceeds the construction length. -/
theorem curLen_le_len (rb : RangeBuf) : rb.curLen ≤ rb.len := by
  have hcons := rb.hcons
  simp only [RangeBuf.curLen]
  omega

-- =============================================================================
-- §5  Properties of consume
-- =============================================================================

/-- consume increases curOff by exactly count. -/
theorem consume_curOff (rb : RangeBuf) (count : Nat) (h : count ≤ rb.curLen) :
    (rb.consume count h).curOff = rb.curOff + count := by
  simp only [RangeBuf.consume, RangeBuf.curOff]
  omega

/-- consume decreases curLen by exactly count. -/
theorem consume_curLen (rb : RangeBuf) (count : Nat) (h : count ≤ rb.curLen) :
    (rb.consume count h).curLen = rb.curLen - count := by
  have hcons := rb.hcons
  simp only [RangeBuf.consume, RangeBuf.curLen]
  omega

/-- consume does NOT change maxOff — this is the core reassembler invariant. -/
theorem consume_maxOff (rb : RangeBuf) (count : Nat) (h : count ≤ rb.curLen) :
    (rb.consume count h).maxOff = rb.maxOff := by
  simp only [RangeBuf.consume, RangeBuf.maxOff]

/-- After consuming all bytes, curLen = 0. -/
theorem consume_all_curLen (rb : RangeBuf) :
    (rb.consume rb.curLen (Nat.le_refl _)).curLen = 0 := by
  have hcons := rb.hcons
  simp only [RangeBuf.consume, RangeBuf.curLen]
  omega

/-- Consuming 0 bytes is a no-op on curOff. -/
theorem consume_zero_curOff (rb : RangeBuf) :
    (rb.consume 0 (Nat.zero_le _)).curOff = rb.curOff := by
  simp only [RangeBuf.consume, RangeBuf.curOff]
  omega

-- =============================================================================
-- §6  Properties of splitOff
-- =============================================================================

/-- The left half's maxOff equals rb.off + at_ (the split point). -/
theorem split_left_maxOff (rb : RangeBuf) (at_ : Nat) (hat : at_ ≤ rb.len) :
    (rb.splitOff at_ hat).1.maxOff = rb.off + at_ := by
  simp only [RangeBuf.splitOff, RangeBuf.maxOff]

/-- The right half's construction start equals rb.off + at_. -/
theorem split_right_off (rb : RangeBuf) (at_ : Nat) (hat : at_ ≤ rb.len) :
    (rb.splitOff at_ hat).2.off = rb.off + at_ := by
  simp only [RangeBuf.splitOff]

/-- split is adjacent: left.maxOff = right.off (no gap, no overlap). -/
theorem split_adjacent (rb : RangeBuf) (at_ : Nat) (hat : at_ ≤ rb.len) :
    (rb.splitOff at_ hat).1.maxOff = (rb.splitOff at_ hat).2.off := by
  simp only [RangeBuf.splitOff, RangeBuf.maxOff]

/-- splitOff preserves the original maxOff in the right half. -/
theorem split_maxOff (rb : RangeBuf) (at_ : Nat) (hat : at_ ≤ rb.len) :
    (rb.splitOff at_ hat).2.maxOff = rb.maxOff := by
  simp only [RangeBuf.splitOff, RangeBuf.maxOff]
  omega

/-- The left half's construction length equals at_. -/
theorem split_left_len (rb : RangeBuf) (at_ : Nat) (hat : at_ ≤ rb.len) :
    (rb.splitOff at_ hat).1.len = at_ := by
  simp only [RangeBuf.splitOff]

/-- The right half's construction length equals rb.len - at_. -/
theorem split_right_len (rb : RangeBuf) (at_ : Nat) (hat : at_ ≤ rb.len) :
    (rb.splitOff at_ hat).2.len = rb.len - at_ := by
  simp only [RangeBuf.splitOff]

/-- Construction lengths partition the original: left.len + right.len = rb.len. -/
theorem split_len_partition (rb : RangeBuf) (at_ : Nat) (hat : at_ ≤ rb.len) :
    (rb.splitOff at_ hat).1.len + (rb.splitOff at_ hat).2.len = rb.len := by
  simp only [RangeBuf.splitOff]
  omega

/-- The left fin flag is always false after a split. -/
theorem split_left_fin_false (rb : RangeBuf) (at_ : Nat) (hat : at_ ≤ rb.len) :
    (rb.splitOff at_ hat).1.fin = false := by
  simp only [RangeBuf.splitOff]

/-- The right half inherits the original fin flag. -/
theorem split_right_fin (rb : RangeBuf) (at_ : Nat) (hat : at_ ≤ rb.len) :
    (rb.splitOff at_ hat).2.fin = rb.fin := by
  simp only [RangeBuf.splitOff]

-- =============================================================================
-- §7  Composition: consume then splitOff
-- =============================================================================

/-- After consuming c bytes then splitting at at_, the right half's maxOff
    equals the original maxOff.  This is the property that guarantees the
    stream reassembler never loses track of where a buffer ends. -/
theorem consume_split_maxOff
    (rb : RangeBuf) (c : Nat) (hc : c ≤ rb.curLen)
    (at_ : Nat) (hat : at_ ≤ (rb.consume c hc).len) :
    ((rb.consume c hc).splitOff at_ hat).2.maxOff = rb.maxOff := by
  have hlen : (rb.consume c hc).len = rb.len := rfl
  rw [hlen] at hat
  simp only [RangeBuf.consume, RangeBuf.splitOff, RangeBuf.maxOff]
  omega

/-- The sum of curLen of the two halves equals the curLen of the original,
    when no bytes have been consumed yet (consumed = 0). -/
theorem split_curLen_partition_fresh
    (rb : RangeBuf) (hc : rb.consumed = 0)
    (at_ : Nat) (hat : at_ ≤ rb.len) :
    (rb.splitOff at_ hat).1.curLen + (rb.splitOff at_ hat).2.curLen =
      rb.curLen := by
  simp only [RangeBuf.splitOff, RangeBuf.curLen, hc]
  simp only [Nat.max_def, Nat.min_def]
  split <;> omega

-- =============================================================================
-- §8  Test vectors (decidable ground-truth checks)
-- =============================================================================

private def mkRb (off len consumed : Nat) (hc : consumed ≤ len)
    (fin : Bool) : RangeBuf :=
  { off, len, consumed, fin, hcons := hc }

/-- A fresh buffer has curOff = off and curLen = len. -/
example : (mkRb 100 50 0 (by omega) false).curOff = 100 := by native_decide
example : (mkRb 100 50 0 (by omega) false).curLen = 50 := by native_decide
example : (mkRb 100 50 0 (by omega) false).maxOff = 150 := by native_decide

/-- After consuming 20 bytes, curOff = 120, curLen = 30, maxOff still 150. -/
example :
    let rb  := mkRb 100 50 0 (by omega) false
    let rb2 := rb.consume 20 (by native_decide)
    rb2.curOff = 120 ∧ rb2.curLen = 30 ∧ rb2.maxOff = 150 := by native_decide

/-- splitOff(25) on a 50-byte buffer: left [100,125), right [125,150). -/
example :
    let rb := mkRb 100 50 0 (by omega) false
    let (l, r) := rb.splitOff 25 (by native_decide)
    l.maxOff = 125 ∧ r.off = 125 ∧ r.maxOff = 150 := by native_decide
