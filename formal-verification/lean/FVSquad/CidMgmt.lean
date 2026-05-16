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
--   • The `retire_if_needed` path is now modelled in §10 (T27).
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
-- §10  retire_if_needed path (T27)  RFC 9000 §5.1.1
-- =============================================================================
--
-- When `new_scid` is called with `retire_if_needed = true` and the active CID
-- count equals `limit`, the Rust code retires the lowest-sequence CID before
-- inserting the new one.  This keeps `|activeSeqs| ≤ limit` under this path.
--
-- Model: `lowestSeq xs` returns the minimum element of `xs`; `newScidRetire`
-- encapsulates retire-lowest + add-new as a single atomic step.
--
-- Approximation: `retire_prior_to` bookkeeping is not modelled; we only track
-- the count invariant (|activeSeqs| ≤ limit) which is the RFC 9000 §5.1.1
-- property.

/-- Minimum of a non-empty list of naturals. -/
def lowestSeq : List Nat → Nat
  | []      => 0
  | [x]     => x
  | x :: xs => Nat.min x (lowestSeq xs)

/-- `newScidRetire s` models the retire-if-needed path of `new_scid`:
    If `|activeSeqs| ≥ limit`, retire the lowest seq first, then add new one.
    Otherwise behaves identically to `newScid`. -/
def CidState.newScidRetire (s : CidState) : CidState :=
  if s.activeSeqs.length < s.limit then
    -- Normal path: just add the new CID.
    s.newScid
  else
    -- retire_if_needed path: drop lowest seq, then add new one.
    let trimmed := { s with
      activeSeqs := s.activeSeqs.filter
        (fun seq => seq != lowestSeq s.activeSeqs) }
    trimmed.newScid

-- ─── Lemmas about lowestSeq ──────────────────────────────────────────────────

/-- The lowest seq is a member of any non-empty list. -/
theorem lowestSeq_mem (xs : List Nat) (h : xs ≠ []) :
    lowestSeq xs ∈ xs := by
  induction xs with
  | nil => exact absurd rfl h
  | cons x rest ih =>
    cases rest with
    | nil => simp [lowestSeq]
    | cons y ys =>
      simp only [lowestSeq, Nat.min_def]
      by_cases hle : x ≤ lowestSeq (y :: ys)
      · simp only [hle, ite_true, List.mem_cons, true_or]
      · simp only [hle, ite_false, List.mem_cons]
        have hmem := ih (by simp)
        simp [List.mem_cons] at hmem
        exact Or.inr hmem

/-- Every element of the list is at least `lowestSeq`. -/
theorem lowestSeq_le_all (xs : List Nat) (n : Nat) (hn : n ∈ xs) :
    lowestSeq xs ≤ n := by
  induction xs with
  | nil => simp at hn
  | cons x rest ih =>
    simp [List.mem_cons] at hn
    cases hn with
    | inl hx =>
      subst hx
      cases rest with
      | nil => simp [lowestSeq]
      | cons y ys => simp [lowestSeq]; exact Nat.min_le_left _ _
    | inr hmem =>
      cases rest with
      | nil => simp at hmem
      | cons y ys =>
        simp [lowestSeq]
        exact Nat.le_trans (Nat.min_le_right _ _) (ih hmem)

-- ─── Key properties of newScidRetire ─────────────────────────────────────────

-- Helper: filtering out a member strictly reduces the list length.
private theorem filter_neq_length_lt (xs : List Nat) (v : Nat) (hmem : v ∈ xs) :
    (xs.filter (fun x => x != v)).length < xs.length := by
  induction xs with
  | nil => simp at hmem
  | cons a rest ih =>
    simp [List.mem_cons] at hmem
    cases hmem with
    | inl ha =>
      subst ha
      simp [List.filter, bne_self_eq_false]
      exact Nat.lt_succ_of_le (List.length_filter_le _ _)
    | inr hmem2 =>
      have ihlt := ih hmem2
      by_cases hav : a = v
      · subst hav
        simp [List.filter, bne_self_eq_false]
        exact Nat.lt_succ_of_le (List.length_filter_le _ _)
      · have hbne : (a != v) = true := by simp [bne_iff_ne, hav]
        have hfilt : List.filter (fun x => x != v) (a :: rest) =
            a :: List.filter (fun x => x != v) rest :=
          List.filter_cons_of_pos hbne
        rw [hfilt, List.length_cons, List.length_cons]
        omega

/-- After retire-if-needed, active count ≤ limit (the RFC 9000 §5.1.1
    property).  Precondition: the count is ≤ limit before the call. -/
theorem newScidRetire_count_le_limit (s : CidState)
    (hinv : CidInv s)
    (hbound : s.activeSeqs.length ≤ s.limit) :
    (s.newScidRetire).activeSeqs.length ≤ s.limit := by
  unfold CidState.newScidRetire
  by_cases h : s.activeSeqs.length < s.limit
  · simp [h, CidState.newScid, List.length_append]; omega
  · -- exactly at limit: remove one, add one → stays at limit
    have _heq : s.activeSeqs.length = s.limit := by omega
    simp only [h, ite_false, CidState.newScid, List.length_append,
               List.length_singleton]
    have hmem : lowestSeq s.activeSeqs ∈ s.activeSeqs :=
      lowestSeq_mem _ hinv.i4_nonempty
    have hfilt := filter_neq_length_lt s.activeSeqs (lowestSeq s.activeSeqs) hmem
    omega

/-- The `newScidRetire` always increments `nextSeq` by exactly 1. -/
theorem newScidRetire_nextSeq_inc (s : CidState) :
    (s.newScidRetire).nextSeq = s.nextSeq + 1 := by
  unfold CidState.newScidRetire CidState.newScid
  by_cases h : s.activeSeqs.length < s.limit <;> simp [h]

/-- The new seq is in the active list after retire-if-needed. -/
theorem newScidRetire_new_seq_in_active (s : CidState) :
    s.nextSeq ∈ (s.newScidRetire).activeSeqs := by
  unfold CidState.newScidRetire CidState.newScid
  by_cases h : s.activeSeqs.length < s.limit
  · simp [h, List.mem_append]
  · simp only [h, ite_false, List.mem_append, List.mem_singleton]
    exact Or.inr trivial

/-- The lowest (retired) seq is removed from the active list after
    retire-if-needed (when the retire path is taken and the retired seq
    differs from the newly issued seq). -/
theorem newScidRetire_lowest_removed (s : CidState)
    (h : ¬(s.activeSeqs.length < s.limit))
    (hne : lowestSeq s.activeSeqs ≠ s.nextSeq) :
    lowestSeq s.activeSeqs ∉ (s.newScidRetire).activeSeqs := by
  unfold CidState.newScidRetire CidState.newScid
  simp only [h, ite_false, List.mem_append, List.mem_filter, List.mem_singleton]
  intro hmem
  cases hmem with
  | inl hfilt =>
    simp [ne_eq] at hfilt
  | inr heq => exact hne heq

-- ─── Test vectors for retire_if_needed ───────────────────────────────────────

-- Scenario: limit=2, activeSeqs=[0,1] (at limit), retire-if-needed called.
private def tv_at_limit : CidState :=
  { nextSeq := 2, activeSeqs := [0, 1], limit := 2 }

-- After retire-if-needed: lowest (0) retired, seq 2 added → [1, 2], count ≤ 2.
example : tv_at_limit.newScidRetire.activeSeqs.length ≤ 2 := by native_decide
example : 0 ∉ tv_at_limit.newScidRetire.activeSeqs := by native_decide
example : 2 ∈ tv_at_limit.newScidRetire.activeSeqs  := by native_decide
example : 1 ∈ tv_at_limit.newScidRetire.activeSeqs  := by native_decide

-- Scenario: below limit → normal path, all seqs preserved.
private def tv_below_limit : CidState :=
  { nextSeq := 2, activeSeqs := [0, 1], limit := 4 }

example : tv_below_limit.newScidRetire.activeSeqs.length = 3 := by native_decide
example : 0 ∈ tv_below_limit.newScidRetire.activeSeqs := by native_decide
example : 2 ∈ tv_below_limit.newScidRetire.activeSeqs := by native_decide

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
