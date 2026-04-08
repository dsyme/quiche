-- Copyright (C) 2025, Cloudflare, Inc.
-- All rights reserved.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/StreamPriorityKey.lean
-- Lean 4 formal model and proofs for StreamPriorityKey ordering
-- (quiche/src/stream/mod.rs lines 842–910).
--
-- 🔬 Lean Squad — automated formal verification.

-- =============================================================================
-- §1  Abstract model
-- =============================================================================
--
-- StreamPriorityKey drives scheduling in HTTP/3 intrusive red-black trees
-- (RFC 9218 — Extensible Prioritization Scheme for HTTP). The `Ord`
-- implementation defines which stream is served first: the minimum element
-- (by this ordering) is dequeued and sent first.
--
-- Approximations vs. Rust source:
--   • `urgency : u8` → Nat  (no overflow; RFC range is 0–7, quiche uses full u8)
--   • `id : u64`      → Nat  (no overflow; QUIC limits stream IDs to < 2^62)
--   • Intrusive tree links (readable/writable/flushable) not modelled.
--   • PartialEq uses only `id`; the Lean model does not replicate the
--     PartialEq/Eq split — only the Ord ordering is modelled.
--   • The Rust Ord violates antisymmetry for the both-incremental case (OQ-1);
--     this is modelled faithfully and the violation is formally proved below.

/-- Abstract key for stream scheduling priority. -/
structure StreamPriorityKey where
  /-- QUIC stream identifier (unique). -/
  id          : Nat
  /-- Scheduling urgency; lower = more urgent (default 127 in quiche). -/
  urgency     : Nat
  /-- If true, data may be interleaved with other streams of equal urgency. -/
  incremental : Bool
  deriving Repr

-- =============================================================================
-- §2  Core comparison function
-- =============================================================================

/-- Seven-case ordering faithful to `StreamPriorityKey::cmp` in Rust.
    Returns `Ordering.lt` if `a` should be served before `b`. -/
def cmpKey (a b : StreamPriorityKey) : Ordering :=
  -- Case 1: same stream — never schedule against itself.
  if a.id == b.id then .eq
  -- Cases 2–3: urgency dominates.
  else if a.urgency < b.urgency then .lt
  else if a.urgency > b.urgency then .gt
  -- Case 4: both non-incremental at equal urgency — order by stream ID.
  else if !a.incremental && !b.incremental then compare a.id b.id
  -- Case 5: a incremental, b non-incremental — non-incremental b wins.
  else if a.incremental && !b.incremental then .gt
  -- Case 6: a non-incremental, b incremental — non-incremental a wins.
  else if !a.incremental && b.incremental then .lt
  -- Case 7: both incremental at equal urgency — b (the existing occupant)
  -- takes precedence.  `self` always sorts AFTER other same-urgency
  -- incremental entries (round-robin approximation).
  -- NOTE: a.cmpKey(b) = .gt  AND  b.cmpKey(a) = .gt simultaneously →
  --       ANTISYMMETRY VIOLATED (OQ-1).
  else .gt

-- =============================================================================
-- §3  Helper lemmas for Nat.compare
-- =============================================================================

-- (No separate compare helpers needed; proofs inline compare directly.)

-- =============================================================================
-- §4  Basic case facts
-- =============================================================================

/-- Case 1: same id always yields Equal. -/
theorem cmpKey_same_id (a b : StreamPriorityKey) (h : a.id = b.id) :
    cmpKey a b = .eq := by
  simp [cmpKey, h]

/-- Reflexivity: every key compares Equal to itself. -/
theorem cmpKey_refl (a : StreamPriorityKey) : cmpKey a a = .eq := by
  simp [cmpKey]

/-- Case 2: strictly lower urgency ⇒ Less. -/
theorem cmpKey_lt_urgency (a b : StreamPriorityKey)
    (hid : a.id ≠ b.id) (hu : a.urgency < b.urgency) :
    cmpKey a b = .lt := by
  simp [cmpKey, hid, hu]

/-- Case 3: strictly higher urgency ⇒ Greater. -/
theorem cmpKey_gt_urgency (a b : StreamPriorityKey)
    (hid : a.id ≠ b.id) (hu : a.urgency > b.urgency) :
    cmpKey a b = .gt := by
  have h1 : ¬(a.urgency < b.urgency) := Nat.not_lt.mpr (Nat.le_of_lt hu)
  simp [cmpKey, hid, h1, hu]

/-- Case 4: both non-incremental, same urgency, different id ⇒ compare by id. -/
theorem cmpKey_both_nonincr (a b : StreamPriorityKey)
    (hid : a.id ≠ b.id) (hu : a.urgency = b.urgency)
    (ha : a.incremental = false) (hb : b.incremental = false) :
    cmpKey a b = compare a.id b.id := by
  have h1 : ¬(a.urgency < b.urgency) := by omega
  have h2 : ¬(a.urgency > b.urgency) := by omega
  simp [cmpKey, hid, h1, h2, ha, hb]

/-- Case 5: a incremental, b non-incremental, same urgency ⇒ Greater. -/
theorem cmpKey_incr_vs_nonincr (a b : StreamPriorityKey)
    (hid : a.id ≠ b.id) (hu : a.urgency = b.urgency)
    (ha : a.incremental = true) (hb : b.incremental = false) :
    cmpKey a b = .gt := by
  have h1 : ¬(a.urgency < b.urgency) := by omega
  have h2 : ¬(a.urgency > b.urgency) := by omega
  simp [cmpKey, hid, h1, h2, ha, hb]

/-- Case 6: a non-incremental, b incremental, same urgency ⇒ Less. -/
theorem cmpKey_nonincr_vs_incr (a b : StreamPriorityKey)
    (hid : a.id ≠ b.id) (hu : a.urgency = b.urgency)
    (ha : a.incremental = false) (hb : b.incremental = true) :
    cmpKey a b = .lt := by
  have h1 : ¬(a.urgency < b.urgency) := by omega
  have h2 : ¬(a.urgency > b.urgency) := by omega
  simp [cmpKey, hid, h1, h2, ha, hb]

/-- Case 7: both incremental, same urgency, different id ⇒ Greater. -/
theorem cmpKey_both_incr (a b : StreamPriorityKey)
    (hid : a.id ≠ b.id) (hu : a.urgency = b.urgency)
    (ha : a.incremental = true) (hb : b.incremental = true) :
    cmpKey a b = .gt := by
  have h1 : ¬(a.urgency < b.urgency) := by omega
  have h2 : ¬(a.urgency > b.urgency) := by omega
  simp [cmpKey, hid, h1, h2, ha, hb]

-- =============================================================================
-- §5  OQ-1: Non-antisymmetry in the both-incremental case
-- =============================================================================
--
-- Standard Ord law (antisymmetry): cmpKey a b = .lt → cmpKey b a = .gt.
-- This fails for case 7 (both incremental, same urgency, different id):
-- cmpKey a b = .gt  AND  cmpKey b a = .gt simultaneously.
--
-- This is a formal proof that the Rust Ord implementation violates the
-- standard antisymmetry contract for the incremental-incremental case.
-- Whether the intrusive RBTree tolerates this is an open design question (OQ-1).

/-- OQ-1: Both-incremental comparison is NOT antisymmetric.
    `cmpKey a b = .gt` even though `cmpKey b a = .gt` too. -/
theorem cmpKey_incr_incr_not_antisymmetric
    (a b : StreamPriorityKey)
    (hid  : a.id ≠ b.id)
    (hu   : a.urgency = b.urgency)
    (ha   : a.incremental = true)
    (hb   : b.incremental = true) :
    cmpKey a b = .gt ∧ cmpKey b a = .gt :=
  ⟨cmpKey_both_incr a b hid hu ha hb,
   cmpKey_both_incr b a (Ne.symm hid) hu.symm hb ha⟩

/-- Concrete counterexample for OQ-1:
    two distinct incremental streams at urgency 3. -/
example : cmpKey { id := 4, urgency := 3, incremental := true }
                  { id := 7, urgency := 3, incremental := true } = .gt ∧
          cmpKey { id := 7, urgency := 3, incremental := true }
                  { id := 4, urgency := 3, incremental := true } = .gt := by
  decide

-- =============================================================================
-- §6  Totality
-- =============================================================================

/-- Totality: cmpKey always returns some Ordering value (never panics). -/
theorem cmpKey_total (a b : StreamPriorityKey) :
    cmpKey a b = .lt ∨ cmpKey a b = .eq ∨ cmpKey a b = .gt := by
  cases h : cmpKey a b with
  | lt => exact Or.inl rfl
  | eq => exact Or.inr (Or.inl rfl)
  | gt => exact Or.inr (Or.inr rfl)

-- =============================================================================
-- §7  Antisymmetry (holds everywhere except case 7)
-- =============================================================================

/-- For distinct urgency, antisymmetry holds: lt implies flip-gt. -/
theorem cmpKey_antisymm_urgency_lt (a b : StreamPriorityKey)
    (hid : a.id ≠ b.id) (hu : a.urgency < b.urgency) :
    cmpKey a b = .lt ∧ cmpKey b a = .gt :=
  ⟨cmpKey_lt_urgency a b hid hu,
   cmpKey_gt_urgency b a (Ne.symm hid) hu⟩

/-- Non-incremental case: lower id wins. -/
theorem cmpKey_nonincr_lower_id_wins (a b : StreamPriorityKey)
    (hid : a.id < b.id) (hu : a.urgency = b.urgency)
    (ha : a.incremental = false) (hb : b.incremental = false) :
    cmpKey a b = .lt := by
  rw [cmpKey_both_nonincr a b (Nat.ne_of_lt hid) hu ha hb]
  simp [compare, compareOfLessAndEq, hid]

/-- Non-incremental case: higher id loses. -/
theorem cmpKey_nonincr_higher_id_loses (a b : StreamPriorityKey)
    (hid : a.id > b.id) (hu : a.urgency = b.urgency)
    (ha : a.incremental = false) (hb : b.incremental = false) :
    cmpKey a b = .gt := by
  rw [cmpKey_both_nonincr a b (by omega) hu ha hb]
  simp [compare, compareOfLessAndEq,
        show ¬(a.id < b.id) from Nat.not_lt.mpr (Nat.le_of_lt hid),
        show a.id ≠ b.id from by omega]

/-- Non-incremental case: antisymmetry holds (lower id direction). -/
theorem cmpKey_nonincr_antisymm (a b : StreamPriorityKey)
    (hid : a.id < b.id) (hu : a.urgency = b.urgency)
    (ha : a.incremental = false) (hb : b.incremental = false) :
    cmpKey a b = .lt ∧ cmpKey b a = .gt :=
  ⟨cmpKey_nonincr_lower_id_wins a b hid hu ha hb,
   cmpKey_nonincr_higher_id_loses b a hid hu.symm hb ha⟩

-- =============================================================================
-- §8  Policy theorems
-- =============================================================================

/-- Lower urgency always wins regardless of incremental flag. -/
theorem cmpKey_lower_urgency_wins (a b : StreamPriorityKey)
    (hid : a.id ≠ b.id) (hu : a.urgency < b.urgency) :
    cmpKey a b = .lt := cmpKey_lt_urgency a b hid hu

/-- Non-incremental beats incremental at same urgency. -/
theorem cmpKey_nonincr_beats_incr (a b : StreamPriorityKey)
    (hid : a.id ≠ b.id) (hu : a.urgency = b.urgency)
    (ha : a.incremental = false) (hb : b.incremental = true) :
    cmpKey a b = .lt := cmpKey_nonincr_vs_incr a b hid hu ha hb

/-- Incremental loses to non-incremental. -/
theorem cmpKey_incr_loses_to_nonincr (a b : StreamPriorityKey)
    (hid : a.id ≠ b.id) (hu : a.urgency = b.urgency)
    (ha : a.incremental = true) (hb : b.incremental = false) :
    cmpKey a b = .gt := cmpKey_incr_vs_nonincr a b hid hu ha hb

-- =============================================================================
-- §9  Round-robin policy for incremental streams
-- =============================================================================

/-- Both-incremental: newly inserted stream (a) sorts AFTER existing (b).
    The tree picks the minimum, so b is dequeued before a. -/
theorem cmpKey_incr_new_after_existing (a b : StreamPriorityKey)
    (hid : a.id ≠ b.id) (hu : a.urgency = b.urgency)
    (ha : a.incremental = true) (hb : b.incremental = true) :
    cmpKey a b = .gt := cmpKey_both_incr a b hid hu ha hb

/-- Round-robin symmetry: both a-after-b and b-after-a hold simultaneously.
    Positive restatement of OQ-1 as intended round-robin policy: neither
    stream permanently dominates the other. -/
theorem cmpKey_incr_round_robin (a b : StreamPriorityKey)
    (hid : a.id ≠ b.id) (hu : a.urgency = b.urgency)
    (ha : a.incremental = true) (hb : b.incremental = true) :
    cmpKey a b = .gt ∧ cmpKey b a = .gt :=
  cmpKey_incr_incr_not_antisymmetric a b hid hu ha hb

-- =============================================================================
-- §10  Transitivity
-- =============================================================================

/-- Urgency is a total order; so transitivity holds for urgency-separated keys. -/
theorem cmpKey_trans_urgency (a b c : StreamPriorityKey)
    (hab : a.urgency < b.urgency) (hbc : b.urgency < c.urgency)
    (hac_id : a.id ≠ c.id) :
    cmpKey a c = .lt :=
  cmpKey_lt_urgency a c hac_id (Nat.lt_trans hab hbc)

/-- Transitivity for non-incremental streams at same urgency. -/
theorem cmpKey_trans_nonincr (a b c : StreamPriorityKey)
    (hu_ab : a.urgency = b.urgency) (hu_bc : b.urgency = c.urgency)
    (ha : a.incremental = false) (hb : b.incremental = false)
    (hc : c.incremental = false)
    (h1 : a.id < b.id) (h2 : b.id < c.id) :
    cmpKey a c = .lt :=
  cmpKey_nonincr_lower_id_wins a c (Nat.lt_trans h1 h2)
    (hu_ab.trans hu_bc) ha hc

-- =============================================================================
-- §11  Concrete test vectors
-- =============================================================================

/-- Test vector 1: lower urgency wins (case 2). -/
example : cmpKey { id := 4, urgency := 1, incremental := true }
                  { id := 7, urgency := 3, incremental := false } = .lt := by decide

/-- Test vector 2: non-incremental beats incremental at same urgency (case 6). -/
example : cmpKey { id := 4, urgency := 3, incremental := false }
                  { id := 7, urgency := 3, incremental := true } = .lt := by decide

/-- Test vector 3: incremental vs non-incremental at same urgency (case 5). -/
example : cmpKey { id := 4, urgency := 3, incremental := true }
                  { id := 7, urgency := 3, incremental := false } = .gt := by decide

/-- Test vector 4: both non-incremental, same urgency, lower id wins (case 4). -/
example : cmpKey { id := 4, urgency := 3, incremental := false }
                  { id := 7, urgency := 3, incremental := false } = .lt := by decide

/-- Test vector 5: same id → Equal (case 1). -/
example : cmpKey { id := 5, urgency := 3, incremental := true }
                  { id := 5, urgency := 3, incremental := false } = .eq := by decide

/-- Test vector 6: both incremental, same urgency → Greater (case 7 / OQ-1). -/
example : cmpKey { id := 4, urgency := 3, incremental := true }
                  { id := 7, urgency := 3, incremental := true } = .gt := by decide

/-- Test vector 7: urgency 0 (max priority) beats urgency 255. -/
example : cmpKey { id := 1, urgency := 0, incremental := false }
                  { id := 2, urgency := 255, incremental := false } = .lt := by decide
