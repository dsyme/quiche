-- Copyright (C) 2024, Cloudflare, Inc.
-- All rights reserved.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/DatagramQueue.lean
-- Lean 4 formal model and proofs for DatagramQueue (quiche/src/dgram.rs).
--
-- 🔬 Lean Squad — automated formal verification.

-- =============================================================================
-- §1  Abstract model
-- =============================================================================

-- We model a datagram as its byte length (a natural number ≥ 0).
-- The queue is a list of such lengths, together with a capacity bound.
--
-- Approximations / abstractions vs. the Rust source:
--   • F::DgramBuf is abstracted to Nat (the payload length).
--   • VecDeque is modelled as List (both are ordered sequences).
--   • saturating_sub in `pop` is exact under I2 (byte_size ≥ front.len).
--   • The `purge` predicate is a boolean function on Nat.
--   • Error variants (Done, BufferTooShort) are modelled as Option/Bool.

structure DgramQueue where
  /-- Datagrams currently held; head = front of the FIFO. -/
  elems    : List Nat
  /-- Maximum number of datagrams permitted. -/
  maxLen   : Nat
  deriving Repr

-- =============================================================================
-- §2  Derived predicates
-- =============================================================================

def DgramQueue.len (q : DgramQueue) : Nat := q.elems.length

def DgramQueue.isEmpty (q : DgramQueue) : Bool := q.elems.isEmpty

def DgramQueue.isFull (q : DgramQueue) : Bool := q.len == q.maxLen

def DgramQueue.byteSize (q : DgramQueue) : Nat := q.elems.foldl (· + ·) 0

-- =============================================================================
-- §3  Operations
-- =============================================================================

def DgramQueue.new (maxLen : Nat) : DgramQueue :=
  { elems := [], maxLen }

/-- Push returns the updated queue on success, or `none` when full. -/
def DgramQueue.push (q : DgramQueue) (d : Nat) : Option DgramQueue :=
  if q.isFull then none
  else some { q with elems := q.elems ++ [d] }

/-- Pop removes and returns the front datagram. -/
def DgramQueue.pop (q : DgramQueue) : Option (Nat × DgramQueue) :=
  match q.elems with
  | []      => none
  | d :: ds => some (d, { q with elems := ds })

/-- Purge removes all datagrams matching the predicate. -/
def DgramQueue.purge (q : DgramQueue) (f : Nat → Bool) : DgramQueue :=
  { q with elems := q.elems.filter (fun d => !f d) }

/-- Peek returns the length of the front datagram without removing it. -/
def DgramQueue.peekFrontLen (q : DgramQueue) : Option Nat :=
  q.elems.head?

-- =============================================================================
-- §4  Arithmetic helpers
-- =============================================================================

/-- foldl with an accumulator equals acc plus foldl with acc 0. -/
private theorem foldl_add_acc (acc : Nat) (xs : List Nat) :
    xs.foldl (· + ·) acc = acc + xs.foldl (· + ·) 0 := by
  induction xs generalizing acc with
  | nil => simp
  | cons y ys ih =>
    simp only [List.foldl, Nat.zero_add]
    rw [ih (acc + y), ih y]
    omega

/-- Filtering with a constantly-true predicate is the identity. -/
private theorem filter_true_eq_id (xs : List Nat) :
    xs.filter (fun _ => true) = xs := by
  induction xs with
  | nil => rfl
  | cons x xs ih => simp [List.filter, ih]

-- =============================================================================
-- §5  Invariants
-- =============================================================================

/-- I1: The queue never exceeds its capacity. -/
def DgramQueue.CapInv (q : DgramQueue) : Prop := q.len ≤ q.maxLen

/-- I2: byteSize equals the sum of element lengths (trivially true by def). -/
theorem byteInv_trivial (q : DgramQueue) :
    q.byteSize = q.elems.foldl (· + ·) 0 := rfl

-- =============================================================================
-- §6  Properties of `new`
-- =============================================================================

theorem new_len_zero (n : Nat) : (DgramQueue.new n).len = 0 := rfl

theorem new_isEmpty (n : Nat) : (DgramQueue.new n).isEmpty = true := rfl

theorem new_byteSize_zero (n : Nat) : (DgramQueue.new n).byteSize = 0 := rfl

theorem new_cap_inv (n : Nat) : (DgramQueue.new n).CapInv := Nat.zero_le _

-- =============================================================================
-- §7  Properties of `push`
-- =============================================================================

/-- Push succeeds iff the queue is not full. -/
theorem push_succeeds_iff_not_full (q : DgramQueue) (d : Nat) :
    (q.push d).isSome ↔ !q.isFull := by
  simp [DgramQueue.push, DgramQueue.isFull, DgramQueue.len]

/-- Push fails iff the queue is full. -/
theorem push_fails_iff_full (q : DgramQueue) (d : Nat) :
    (q.push d).isNone ↔ q.isFull := by
  simp [DgramQueue.push, DgramQueue.isFull, DgramQueue.len]

/-- On success, push increases len by 1. -/
theorem push_len_inc (q : DgramQueue) (d : Nat) (q' : DgramQueue)
    (h : q.push d = some q') : q'.len = q.len + 1 := by
  simp [DgramQueue.push, DgramQueue.isFull] at h
  obtain ⟨_, rfl⟩ := h
  simp [DgramQueue.len, List.length_append]

/-- On success, push increases byteSize by the datagram length. -/
theorem push_byteSize_inc (q : DgramQueue) (d : Nat) (q' : DgramQueue)
    (h : q.push d = some q') : q'.byteSize = q.byteSize + d := by
  simp [DgramQueue.push, DgramQueue.isFull] at h
  obtain ⟨_, rfl⟩ := h
  simp [DgramQueue.byteSize, List.foldl_append]

/-- Successful push preserves CapInv. -/
theorem push_preserves_cap_inv (q : DgramQueue) (d : Nat) (q' : DgramQueue)
    (hcap : q.CapInv) (h : q.push d = some q') : q'.CapInv := by
  simp [DgramQueue.push, DgramQueue.isFull] at h
  obtain ⟨hne, rfl⟩ := h
  simp only [DgramQueue.CapInv, DgramQueue.len, List.length_append,
             List.length_singleton]
  simp only [DgramQueue.CapInv, DgramQueue.len] at hcap hne
  omega

/-- Failed push (full queue) leaves the queue unchanged. -/
theorem push_full_unchanged (q : DgramQueue) (d : Nat)
    (hfull : q.isFull = true) : q.push d = none := by
  simp [DgramQueue.push, hfull]

-- =============================================================================
-- §8  Properties of `pop`
-- =============================================================================

/-- Pop on an empty queue returns none. -/
theorem pop_empty_none (q : DgramQueue) (h : q.isEmpty = true) :
    q.pop = none := by
  cases hq : q.elems with
  | nil       => simp [DgramQueue.pop, hq]
  | cons x xs => simp [DgramQueue.isEmpty, hq] at h

/-- Pop on a non-empty queue returns some. -/
theorem pop_nonempty_some (q : DgramQueue) (h : q.isEmpty = false) :
    (q.pop).isSome = true := by
  cases hq : q.elems with
  | nil       => simp [DgramQueue.isEmpty, hq] at h
  | cons x xs => simp [DgramQueue.pop, hq]

/-- Pop decreases len by 1. -/
theorem pop_len_dec (q : DgramQueue) (d : Nat) (q' : DgramQueue)
    (h : q.pop = some (d, q')) : q'.len + 1 = q.len := by
  cases hq : q.elems with
  | nil       => simp [DgramQueue.pop, hq] at h
  | cons x xs =>
    simp [DgramQueue.pop, hq] at h
    obtain ⟨rfl, rfl⟩ := h
    simp [DgramQueue.len, hq]

/-- Pop decreases byteSize by the front element's length. -/
theorem pop_byteSize_dec (q : DgramQueue) (d : Nat) (q' : DgramQueue)
    (h : q.pop = some (d, q')) : q'.byteSize + d = q.byteSize := by
  cases hq : q.elems with
  | nil       => simp [DgramQueue.pop, hq] at h
  | cons x xs =>
    simp [DgramQueue.pop, hq] at h
    obtain ⟨rfl, rfl⟩ := h
    simp [DgramQueue.byteSize, hq]
    rw [foldl_add_acc x xs]
    omega

/-- Pop preserves CapInv. -/
theorem pop_preserves_cap_inv (q : DgramQueue) (d : Nat) (q' : DgramQueue)
    (hcap : q.CapInv) (h : q.pop = some (d, q')) : q'.CapInv := by
  cases hq : q.elems with
  | nil       => simp [DgramQueue.pop, hq] at h
  | cons x xs =>
    simp [DgramQueue.pop, hq] at h
    obtain ⟨rfl, rfl⟩ := h
    simp only [DgramQueue.CapInv, DgramQueue.len]
    simp only [DgramQueue.CapInv, DgramQueue.len, hq, List.length_cons] at hcap
    omega

-- =============================================================================
-- §9  Round-trip properties
-- =============================================================================

/-- Push then pop on a fresh non-trivial queue recovers the pushed element. -/
theorem push_pop_singleton (n : Nat) (hn : 0 < n) (d : Nat) :
    (DgramQueue.new n).push d = some { elems := [d], maxLen := n } ∧
    ({ elems := [d], maxLen := n } : DgramQueue).pop =
      some (d, DgramQueue.new n) := by
  refine ⟨?_, ?_⟩
  · simp [DgramQueue.new, DgramQueue.push, DgramQueue.isFull, DgramQueue.len]
    omega
  · simp [DgramQueue.pop, DgramQueue.new]

/-- Push places a datagram behind existing ones (FIFO order preserved). -/
theorem push_then_pop_front_unchanged (q : DgramQueue) (d : Nat)
    (q' : DgramQueue) (hpush : q.push d = some q')
    (front : Nat) (hfront : q.elems.head? = some front) :
    ∃ q'', q'.pop = some (front, q'') := by
  simp [DgramQueue.push, DgramQueue.isFull] at hpush
  obtain ⟨_, rfl⟩ := hpush
  cases hq : q.elems with
  | nil       => simp [hq] at hfront
  | cons x xs =>
    simp [hq] at hfront
    subst hfront
    simp [DgramQueue.pop]

-- =============================================================================
-- §10  Properties of `purge`
-- =============================================================================

/-- Purge removes all elements matching the predicate. -/
theorem purge_removes_matching (q : DgramQueue) (f : Nat → Bool) :
    ∀ d, d ∈ (q.purge f).elems → f d = false := by
  intro d hd
  simp [DgramQueue.purge, List.mem_filter] at hd
  obtain ⟨_, hf⟩ := hd
  simpa using hf

/-- Purge keeps elements not matching the predicate. -/
theorem purge_keeps_non_matching (q : DgramQueue) (f : Nat → Bool) :
    ∀ d, d ∈ q.elems → f d = false → d ∈ (q.purge f).elems := by
  intro d hd hf
  simp [DgramQueue.purge, List.mem_filter]
  exact ⟨hd, by simpa using hf⟩

/-- Purge preserves CapInv (removing elements can only decrease len). -/
theorem purge_preserves_cap_inv (q : DgramQueue) (f : Nat → Bool)
    (hcap : q.CapInv) : (q.purge f).CapInv := by
  simp [DgramQueue.CapInv, DgramQueue.len, DgramQueue.purge]
  calc (q.elems.filter fun d => !f d).length
      ≤ q.elems.length := List.length_filter_le _ _
    _ ≤ q.maxLen        := hcap

/-- Purge with always-false predicate is identity. -/
theorem purge_noop (q : DgramQueue) : q.purge (fun _ => false) = q := by
  simp only [DgramQueue.purge, Bool.not_false]
  have h : q.elems.filter (fun _ => true) = q.elems := filter_true_eq_id q.elems
  simp [h]

/-- Purge with always-true predicate empties the queue. -/
theorem purge_all (q : DgramQueue) : (q.purge (fun _ => true)).len = 0 := by
  simp [DgramQueue.len, DgramQueue.purge]

-- =============================================================================
-- §11  isEmpty / isFull consistency
-- =============================================================================

/-- isEmpty iff len = 0. -/
theorem isEmpty_iff_len_zero (q : DgramQueue) :
    q.isEmpty = true ↔ q.len = 0 := by
  cases q.elems with
  | nil       => simp [DgramQueue.isEmpty, DgramQueue.len]
  | cons x xs => simp [DgramQueue.isEmpty, DgramQueue.len]

/-- isFull iff len = maxLen. -/
theorem isFull_iff_len_eq_maxLen (q : DgramQueue) :
    q.isFull = true ↔ q.len = q.maxLen := by
  simp [DgramQueue.isFull, DgramQueue.len]

/-- A fresh queue is not full when capacity is positive. -/
theorem new_not_full_when_max_pos (n : Nat) (hn : n > 0) :
    (DgramQueue.new n).isFull = false := by
  simp [DgramQueue.isFull, DgramQueue.len, DgramQueue.new]
  omega
