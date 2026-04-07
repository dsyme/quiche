-- Copyright (C) 2025, Cloudflare, Inc.
-- All rights reserved.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/CidMgmt.lean
-- Formal specification and proofs for Connection ID sequence management
-- (quiche/src/cid.rs — ConnectionIdentifiers, new_scid, retire_scid).
--
-- 🔬 Lean Squad — automated formal verification.

-- =============================================================================
-- §1  Abstract model
-- =============================================================================
--
-- CidState captures the security-relevant scalar fields of
-- ConnectionIdentifiers:
--
--   nextSeq   : the next sequence number to assign (Rust: next_scid_seq)
--   activeSeqs: the list of sequence numbers currently in `scids`
--   limit     : source_conn_id_limit (max active SCIDs the peer allows)
--
-- Approximations vs. the Rust source:
--   • Byte contents of CIDs are not modelled; only sequence numbers matter.
--   • VecDeque<ConnectionIdEntry> → List Nat.
--   • reset_token, path_id, zero_length_scid, retire_prior_to not modelled.
--   • The `retire_if_needed` path is not modelled (only the simple case).
--   • Error returns are modelled as precondition guards.

/-- Abstract model of the CID sequence manager. -/
structure CidState where
  /-- Next sequence number to assign (`next_scid_seq` in Rust). -/
  nextSeq    : Nat
  /-- Sequence numbers of currently active source CIDs. -/
  activeSeqs : List Nat
  /-- Maximum active SCID count the peer permits (`source_conn_id_limit`). -/
  limit      : Nat
  deriving Repr

-- =============================================================================
-- §2  Well-formedness predicates
-- =============================================================================

/-- All elements of a list are pairwise distinct. -/
def allDistinct : List Nat → Prop
  | []      => True
  | x :: xs => x ∉ xs ∧ allDistinct xs

/-- The five-part well-formedness invariant for the CID sequence state.
    I1: nextSeq ≥ 1      (initial CID seq 0 was already issued)
    I2: all activeSeqs are pairwise distinct
    I3: every active seq < nextSeq (issued in a prior call)
    I4: activeSeqs is non-empty   (at least one CID on the initial path)
    I5: |activeSeqs| ≤ 2 * limit − 1  (storage bound; limit ≥ 1) -/
structure CidInv (s : CidState) : Prop where
  i1_pos     : s.nextSeq ≥ 1
  i2_distinct: allDistinct s.activeSeqs
  i3_bound   : ∀ n ∈ s.activeSeqs, n < s.nextSeq
  i4_nonempty: s.activeSeqs ≠ []
  i5_size    : s.activeSeqs.length ≤ 2 * s.limit - 1

-- =============================================================================
-- §3  Operations
-- =============================================================================

/-- Add a fresh new source CID: assign `nextSeq`, then increment nextSeq.
    Corresponds to `ConnectionIdentifiers::new_scid` for a non-duplicate CID. -/
def CidState.newScid (s : CidState) : CidState :=
  { s with
    activeSeqs := s.activeSeqs ++ [s.nextSeq]
    nextSeq    := s.nextSeq + 1 }

/-- Retire the source CID with the given sequence number (if present).
    Corresponds to `ConnectionIdentifiers::retire_scid`. -/
def CidState.retireScid (s : CidState) (seq : Nat) : CidState :=
  { s with activeSeqs := s.activeSeqs.filter (· ≠ seq) }

-- =============================================================================
-- §4  Constructor lemma
-- =============================================================================

/-- Initial state: seq 0 is active, nextSeq = 1, limit ≥ 1.
    Corresponds to ConnectionIdentifiers::new with initial SCID seq 0. -/
def initState (limit : Nat) : CidState :=
  { nextSeq := 1, activeSeqs := [0], limit := limit }

theorem initState_inv (limit : Nat) (hlim : limit ≥ 1) :
    CidInv (initState limit) := by
  constructor
  · -- I1: nextSeq ≥ 1
    show 1 ≥ 1; omega
  · -- I2: [0] has distinct elements: 0 ∉ [] ∧ allDistinct []
    show (0 : Nat) ∉ ([] : List Nat) ∧ allDistinct []
    exact ⟨List.not_mem_nil, trivial⟩
  · -- I3: every n ∈ [0] satisfies n < 1
    intro n hn
    simp only [initState, List.mem_singleton] at *
    omega
  · -- I4: [0] ≠ []
    exact List.cons_ne_nil 0 []
  · -- I5: 1 ≤ 2 * limit − 1 (limit ≥ 1)
    show [0].length ≤ 2 * limit - 1
    simp only [List.length_singleton]
    have : 2 * limit ≥ 2 := by omega
    omega

-- =============================================================================
-- §5  Auxiliary lemmas for list reasoning
-- =============================================================================

/-- Appending a fresh element preserves allDistinct. -/
theorem allDistinct_append_fresh (xs : List Nat) (x : Nat)
    (hfresh : x ∉ xs) (hdist : allDistinct xs) : allDistinct (xs ++ [x]) := by
  induction xs with
  | nil  =>
    show x ∉ [] ∧ allDistinct []
    exact ⟨List.not_mem_nil, trivial⟩
  | cons h t ih =>
    -- hfresh : x ∉ h :: t  →  x ≠ h  ∧  x ∉ t
    simp only [List.mem_cons, not_or] at hfresh
    obtain ⟨hne, hnin⟩ := hfresh
    -- hdist : allDistinct (h :: t)  →  h ∉ t  ∧  allDistinct t
    show h ∉ t ++ [x] ∧ allDistinct (t ++ [x])
    obtain ⟨hnotin, hdist_t⟩ := hdist
    refine ⟨?_, ih hnin hdist_t⟩
    -- h ∉ t ++ [x]: h ∉ t (from inv) and h ≠ x (from hne : x ≠ h)
    simp only [List.mem_append, List.mem_singleton]
    intro hmem
    cases hmem with
    | inl h_in_t => exact hnotin h_in_t
    | inr h_eq_x => exact hne h_eq_x.symm

/-- Membership in `xs ++ [x]` decomposes into membership in xs or equality. -/
theorem mem_append_singleton (xs : List Nat) (x n : Nat) :
    n ∈ xs ++ [x] ↔ n ∈ xs ∨ n = x := by
  simp [List.mem_append]

/-- If all elements of xs satisfy `< n`, then all elements of `xs ++ [n]`
    satisfy `< n + 1`. -/
theorem allBound_append (xs : List Nat) (n : Nat)
    (hb : ∀ k ∈ xs, k < n) : ∀ k ∈ xs ++ [n], k < n + 1 := by
  intro k hk
  rw [mem_append_singleton] at hk
  cases hk with
  | inl h => exact Nat.lt_succ_of_lt (hb k h)
  | inr h => omega

/-- filter preserves allDistinct. -/
theorem allDistinct_filter (p : Nat → Bool) (xs : List Nat)
    (h : allDistinct xs) : allDistinct (xs.filter p) := by
  induction xs with
  | nil  => exact trivial
  | cons x t ih =>
    obtain ⟨hnotin, hdist_t⟩ := h
    simp only [List.filter]
    split
    · -- x kept by p: x ∉ t.filter p ∧ allDistinct (t.filter p)
      refine ⟨?_, ih hdist_t⟩
      intro hmem
      exact hnotin (List.mem_filter.mp hmem).1
    · -- x dropped by p
      exact ih hdist_t

/-- filter preserves the upper-bound property. -/
theorem allBound_filter (p : Nat → Bool) (xs : List Nat) (n : Nat)
    (h : ∀ k ∈ xs, k < n) : ∀ k ∈ xs.filter p, k < n := by
  intro k hk
  exact h k (List.mem_filter.mp hk).1

/-- filter never increases the list length. -/
theorem filter_length_le (p : Nat → Bool) (xs : List Nat) :
    (xs.filter p).length ≤ xs.length := by
  induction xs with
  | nil  => simp
  | cons x t ih =>
    simp only [List.filter]
    split <;> simp only [List.length_cons] <;> omega

-- =============================================================================
-- §6  newScid preserves the invariant
-- =============================================================================

/-- `newScid` preserves CidInv.
    Precondition: the active set has room below limit.
    (Simplified: no retire_if_needed.) -/
theorem newScid_preserves_inv (s : CidState) (hinv : CidInv s)
    (hroom : s.activeSeqs.length < s.limit) :
    CidInv s.newScid := by
  constructor
  · -- I1: nextSeq + 1 ≥ 1
    show s.nextSeq + 1 ≥ 1; omega
  · -- I2: distinct — nextSeq is fresh (all active seqs < nextSeq by I3)
    apply allDistinct_append_fresh
    · intro hmem
      exact Nat.lt_irrefl s.nextSeq (hinv.i3_bound s.nextSeq hmem)
    · exact hinv.i2_distinct
  · -- I3: all new seqs < nextSeq + 1
    exact allBound_append s.activeSeqs s.nextSeq hinv.i3_bound
  · -- I4: non-empty (appended list is always non-empty)
    show s.activeSeqs ++ [s.nextSeq] ≠ []
    exact List.append_ne_nil_of_right_ne_nil _ (List.cons_ne_nil _ _)
  · -- I5: length ≤ 2 * limit − 1
    simp only [CidState.newScid, List.length_append, List.length_singleton]
    omega

-- =============================================================================
-- §7  retireScid preserves the invariant
-- =============================================================================

/-- `retireScid` preserves CidInv (given the filtered list remains non-empty). -/
theorem retireScid_preserves_inv (s : CidState) (seq : Nat)
    (hinv : CidInv s)
    (hne : (s.activeSeqs.filter (· ≠ seq)) ≠ []) :
    CidInv (s.retireScid seq) := by
  constructor
  · exact hinv.i1_pos
  · exact allDistinct_filter _ s.activeSeqs hinv.i2_distinct
  · exact allBound_filter _ s.activeSeqs s.nextSeq hinv.i3_bound
  · exact hne
  · show (s.activeSeqs.filter (· ≠ seq)).length ≤ 2 * s.limit - 1
    exact Nat.le_trans (filter_length_le _ _) hinv.i5_size

-- =============================================================================
-- §8  Core sequence-number properties
-- =============================================================================

/-- P1: `nextSeq` strictly increases after `newScid`. -/
theorem newScid_nextSeq_strict (s : CidState) :
    s.nextSeq < s.newScid.nextSeq := by
  show s.nextSeq < s.nextSeq + 1; omega

/-- P2: The sequence number assigned by `newScid` equals the pre-call `nextSeq`. -/
theorem newScid_seq_in_active (s : CidState) :
    s.nextSeq ∈ s.newScid.activeSeqs := by
  show s.nextSeq ∈ s.activeSeqs ++ [s.nextSeq]
  exact List.mem_append_right _ (List.mem_singleton.mpr rfl)

/-- P3: The new seq was not in the active set before the call (freshness). -/
theorem newScid_seq_fresh (s : CidState) (hinv : CidInv s) :
    s.nextSeq ∉ s.activeSeqs := by
  intro hmem
  exact Nat.lt_irrefl s.nextSeq (hinv.i3_bound s.nextSeq hmem)

/-- P4: All active seqs are always strictly below `nextSeq` (I3 restatement). -/
theorem activeSeqs_lt_nextSeq (s : CidState) (hinv : CidInv s)
    (n : Nat) (hmem : n ∈ s.activeSeqs) : n < s.nextSeq :=
  hinv.i3_bound n hmem

/-- P5: Two successive `newScid` calls yield distinct sequence numbers. -/
theorem newScid_two_distinct (s : CidState) :
    s.nextSeq ≠ s.newScid.nextSeq := by
  show s.nextSeq ≠ s.nextSeq + 1; omega

/-- P6: `retireScid` does not change `nextSeq`. -/
theorem retireScid_nextSeq_unchanged (s : CidState) (seq : Nat) :
    (s.retireScid seq).nextSeq = s.nextSeq := rfl

/-- P7: `retireScid` removes the given seq from `activeSeqs`. -/
theorem retireScid_removes (s : CidState) (seq : Nat) :
    seq ∉ (s.retireScid seq).activeSeqs := by
  show seq ∉ s.activeSeqs.filter (· ≠ seq)
  intro hmem
  have h := (List.mem_filter.mp hmem).2
  simp at h

/-- P8: `retireScid` does not remove seqs other than the target. -/
theorem retireScid_keeps_others (s : CidState) (seq n : Nat) (hne : n ≠ seq)
    (hmem : n ∈ s.activeSeqs) : n ∈ (s.retireScid seq).activeSeqs := by
  show n ∈ s.activeSeqs.filter (· ≠ seq)
  rw [List.mem_filter]
  exact ⟨hmem, by simp [hne]⟩

/-- P9: `nextSeq` is non-decreasing across `retireScid`. -/
theorem retireScid_nextSeq_ge (s : CidState) (seq : Nat) :
    s.nextSeq ≤ (s.retireScid seq).nextSeq := Nat.le_refl _

-- =============================================================================
-- §9  Monotonicity across multiple newScid calls
-- =============================================================================

/-- Apply `newScid` k times. -/
def applyNewScid : Nat → CidState → CidState
  | 0,   s => s
  | n+1, s => applyNewScid n s.newScid

theorem applyNewScid_nextSeq (k : Nat) (s : CidState) :
    (applyNewScid k s).nextSeq = s.nextSeq + k := by
  induction k generalizing s with
  | zero     => rfl
  | succ k ih => simp only [applyNewScid, ih, CidState.newScid]; omega

/-- After k `newScid` calls, `nextSeq` is strictly larger (if k > 0). -/
theorem applyNewScid_nextSeq_strict (k : Nat) (s : CidState) (hk : k > 0) :
    s.nextSeq < (applyNewScid k s).nextSeq := by
  rw [applyNewScid_nextSeq]; omega

/-- After k `newScid` calls, the active set has grown by exactly k. -/
theorem applyNewScid_length (k : Nat) (s : CidState) :
    (applyNewScid k s).activeSeqs.length = s.activeSeqs.length + k := by
  induction k generalizing s with
  | zero     => rfl
  | succ k ih =>
    simp only [applyNewScid, ih, CidState.newScid,
               List.length_append, List.length_singleton]; omega

-- =============================================================================
-- §10  Test vectors
-- =============================================================================

private def tv_init : CidState :=
  { nextSeq := 1, activeSeqs := [0], limit := 4 }

-- After one newScid: seq 1 added, nextSeq = 2.
private def tv_s1 := tv_init.newScid
example : tv_s1.nextSeq = 2              := by native_decide
example : 0 ∈ tv_s1.activeSeqs           := by native_decide
example : 1 ∈ tv_s1.activeSeqs           := by native_decide
example : tv_s1.activeSeqs.length = 2    := by native_decide

-- After two newScid calls: seqs [0, 1, 2], nextSeq = 3.
private def tv_s2 := tv_s1.newScid
example : tv_s2.nextSeq = 3              := by native_decide
example : tv_s2.activeSeqs.length = 3   := by native_decide

-- Retire seq 0: seqs [1, 2], nextSeq still 3.
private def tv_r0 := tv_s2.retireScid 0
example : tv_r0.nextSeq = 3             := by native_decide
example : 0 ∉ tv_r0.activeSeqs          := by native_decide
example : 1 ∈ tv_r0.activeSeqs           := by native_decide
example : tv_r0.activeSeqs.length = 2   := by native_decide

-- All seqs strictly below nextSeq after retire.
example : ∀ n ∈ tv_r0.activeSeqs, n < tv_r0.nextSeq := by native_decide

-- monotonicity: 3 calls → nextSeq = 4.
example : (applyNewScid 3 tv_init).nextSeq = 4 := by native_decide
-- active set grows by 3
example : (applyNewScid 3 tv_init).activeSeqs.length = 4 := by native_decide
