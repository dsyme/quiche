-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of QUIC ACK frame acked-range bounds
-- (T43).
--
-- Source: `quiche/src/frame.rs` — `parse_ack_frame` (lines 1257–1311)
-- RFC:    RFC 9000 §19.3 (ACK Frames)
-- Informal spec: `formal-verification/specs/ack_ranges_informal.md`
--
-- Lean 4 (v4.30.0-rc2), no Mathlib dependency.
--
-- What is modelled:
--   - The wire-level decoding logic of `parse_ack_frame` as a pure function
--     over lists of (gap, ack_block) pairs.
--   - The sequential cursor state: (largest_ack, smallest_ack) tracking.
--   - Success / failure outcome: Option (List (Nat × Nat)).
--   - Properties: no-underflow, validity of ranges, bounded coverage.
--
-- Approximations / abstractions:
--   - IO (Octets cursor) is abstracted away; decoded varint values are
--     provided directly as Nat lists.
--   - ack_delay and ECN counts are omitted (no range semantics).
--   - RangeSet insertion order is modelled as a plain List (Nat × Nat).
--   - All arithmetic uses Nat (underflow prevented by guards).

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- § 1  Core model: range list decoder
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- A decoded ACK range is a pair (smallest, largest) with smallest ≤ largest.
abbrev AckRange := Nat × Nat

-- `decodeAckBlocks largest_ack ack_block blocks` mirrors the loop in
-- `parse_ack_frame`. Returns none if any underflow guard fires.
def decodeAckBlocks (largest_ack ack_block : Nat)
    (blocks : List (Nat × Nat)) : Option (List AckRange) :=
  if h : largest_ack < ack_block then
    none
  else
    let smallest_ack := largest_ack - ack_block
    let first : AckRange := (smallest_ack, largest_ack)
    let rec loop (smallest : Nat) (acc : List AckRange)
        : List (Nat × Nat) → Option (List AckRange)
      | [] => some acc.reverse
      | (gap, blk) :: rest =>
        if smallest < 2 + gap then none
        else
          let lg := (smallest - gap) - 2
          if lg < blk then none
          else
            let sm := lg - blk
            loop sm ((sm, lg) :: acc) rest
    loop smallest_ack [first] blocks

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- § 2  Helper predicates
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def validRange (r : AckRange) : Prop := r.1 ≤ r.2

def allValid (rs : List AckRange) : Prop := ∀ r ∈ rs, validRange r

def boundedBy (n : Nat) (rs : List AckRange) : Prop :=
  ∀ r ∈ rs, r.2 ≤ n

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- § 3  Arithmetic lemmas
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

theorem nat_sub_le_self (a b : Nat) : a - b ≤ a := Nat.sub_le a b

theorem nat_sub_sub_nonneg {a b c : Nat} (h1 : a ≥ b + 2) : a - b ≥ 2 := by
  omega

theorem first_no_underflow {la ab : Nat} (h : ¬ la < ab) : la - ab ≤ la := by
  omega

-- If largest_ack ≥ ack_block then smallest_ack ≤ largest_ack.
theorem smallest_le_largest {la ab : Nat} (h : ¬ la < ab) :
    la - ab ≤ la := by omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- § 3b  Loop invariant (key lemma underlying §4.3–4.5)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- At each iteration the new entry (sm', lg) satisfies sm' ≤ lg ≤ ub because:
--   • guard  ¬ sm < 2 + gap  gives  sm ≥ 2 + gap  so lg = sm-gap-2 ≥ 0
--   • guard  ¬ lg < blk      gives  lg ≥ blk      so sm' = lg-blk ≤ lg
--   • lg = sm - gap - 2 ≤ sm ≤ ub  (Nat subtraction is monotone below sm)
-- Inductively this holds for all entries accumulated in `acc`.
private theorem loop_invariant
    (ub sm : Nat) (acc : List AckRange) (bl : List (Nat × Nat))
    (hsm : sm ≤ ub)
    (hva : ∀ r ∈ acc, validRange r)
    (hba : ∀ r ∈ acc, r.2 ≤ ub)
    (rs : List AckRange)
    (h : decodeAckBlocks.loop sm acc bl = some rs)
    : (∀ r ∈ rs, validRange r) ∧ (∀ r ∈ rs, r.2 ≤ ub) := by
  induction bl generalizing sm acc with
  | nil =>
    simp [decodeAckBlocks.loop] at h
    subst h
    exact ⟨fun r hr => hva r (List.mem_reverse.mp hr),
           fun r hr => hba r (List.mem_reverse.mp hr)⟩
  | cons hd tl ih =>
    simp only [decodeAckBlocks.loop] at h
    split at h; · simp at h
    rename_i hgap
    split at h; · simp at h
    rename_i hblk
    apply ih (sm - hd.1 - 2 - hd.2)
        ((sm - hd.1 - 2 - hd.2, sm - hd.1 - 2) :: acc)
    · omega
    · intro r hr
      simp [List.mem_cons] at hr
      rcases hr with rfl | hr
      · simp [validRange]
      · exact hva r hr
    · intro r hr
      simp [List.mem_cons] at hr
      rcases hr with rfl | hr
      · simp; omega
      · exact hba r hr
    · exact h

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- § 4  Core safety theorems
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- § 4.1  Success implies no-underflow on the first block guard.
theorem decodeAckBlocks_first_guard
    (la ab : Nat) (blocks : List (Nat × Nat))
    (rs : List AckRange)
    (h : decodeAckBlocks la ab blocks = some rs) :
    la ≥ ab := by
  unfold decodeAckBlocks at h
  by_cases hlt : la < ab
  · simp [hlt] at h
  · omega

-- § 4.2  The result is non-empty on success.
theorem decodeAckBlocks_nonempty
    (la ab : Nat) (blocks : List (Nat × Nat))
    (rs : List AckRange)
    (h : decodeAckBlocks la ab blocks = some rs) :
    rs ≠ [] := by
  intro heq
  subst heq
  unfold decodeAckBlocks at h
  split at h; · simp at h
  rename_i hlt; simp only at h
  have aux : ∀ (s : Nat) (acc : List AckRange) (bl : List (Nat × Nat)),
      acc ≠ [] → decodeAckBlocks.loop s acc bl ≠ some [] := by
    intro s acc bl hne hloop
    induction bl generalizing s acc with
    | nil =>
      simp [decodeAckBlocks.loop] at hloop
      exact hne hloop
    | cons hd tl ih =>
      simp only [decodeAckBlocks.loop] at hloop
      split at hloop; · simp at hloop
      split at hloop; · simp at hloop
      exact ih _ _ (by simp) hloop
  exact aux _ _ _ (by simp) h

-- § 4.3 / § 4.4 / § 4.5  Core safety theorems (proved via loop_invariant)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- § 4.4  All ranges are valid on success.
-- The loop invariant (§3b) carries `allValid acc` through every iteration.
theorem decodeAckBlocks_all_valid
    (la ab : Nat) (blocks : List (Nat × Nat))
    (rs : List AckRange)
    (h : decodeAckBlocks la ab blocks = some rs) :
    allValid rs := by
  unfold decodeAckBlocks at h
  split at h; · simp at h
  rename_i hlt; simp only at h
  exact (loop_invariant la (la - ab) [(la - ab, la)] blocks (Nat.sub_le la ab)
    (by intro r hr; simp at hr; subst hr; simp [validRange])
    (by intro r hr; simp at hr; subst hr; simp)
    rs h).1

-- § 4.5  All ranges are bounded by largest_ack on success.
-- The loop invariant (§3b) carries `boundedBy la acc` through every iteration.
theorem decodeAckBlocks_bounded
    (la ab : Nat) (blocks : List (Nat × Nat))
    (rs : List AckRange)
    (h : decodeAckBlocks la ab blocks = some rs) :
    boundedBy la rs := by
  unfold decodeAckBlocks at h
  split at h; · simp at h
  rename_i hlt; simp only at h
  exact (loop_invariant la (la - ab) [(la - ab, la)] blocks (Nat.sub_le la ab)
    (by intro r hr; simp at hr; subst hr; simp [validRange])
    (by intro r hr; simp at hr; subst hr; simp)
    rs h).2

-- § 4.3  The first range has smallest ≤ largest (validRange).
-- Follows immediately from decodeAckBlocks_all_valid.
theorem decodeAckBlocks_first_valid
    (la ab : Nat) (blocks : List (Nat × Nat))
    (rs : List AckRange)
    (h : decodeAckBlocks la ab blocks = some rs) :
    ∃ s l tail, rs = (s, l) :: tail ∧ s ≤ l := by
  have hav := decodeAckBlocks_all_valid la ab blocks rs h
  have hne := decodeAckBlocks_nonempty la ab blocks rs h
  obtain ⟨hd, tl, rfl⟩ := List.exists_cons_of_ne_nil hne
  exact ⟨hd.1, hd.2, tl, rfl, hav hd List.mem_cons_self⟩

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- § 5  Decidable unit checks (native_decide)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Single block: largest=10, ack_block=3 → range (7, 10).
example : decodeAckBlocks 10 3 [] = some [(7, 10)] := by native_decide

-- Two blocks: largest=20, first=4, gap=2, second=3 → (16,20),(9,12).
example : decodeAckBlocks 20 4 [(2, 3)] = some [(16, 20), (9, 12)] := by
  native_decide

-- Underflow on first block guard.
example : decodeAckBlocks 3 5 [] = none := by native_decide

-- Underflow in loop: smallest=7, gap=6 → 7 < 8.
example : decodeAckBlocks 10 3 [(6, 0)] = none := by native_decide

-- Underflow: second block ack_block too large.
example : decodeAckBlocks 10 3 [(2, 20)] = none := by native_decide

-- Edge: zero-span, largest=0, ack_block=0.
example : decodeAckBlocks 0 0 [] = some [(0, 0)] := by native_decide

-- Three blocks, valid.
example : decodeAckBlocks 100 10 [(5, 8), (3, 4)] =
    some [(90, 100), (75, 83), (66, 70)] := by native_decide

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- § 6  Decidable property checks on sample outputs
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- All ranges valid (s ≤ l) in three-block sample.
example :
    (decodeAckBlocks 100 10 [(5, 8), (3, 4)]).map
      (fun rs => rs.all (fun r => r.1 ≤ r.2)) = some true := by
  native_decide

-- All ranges bounded by 100.
example :
    (decodeAckBlocks 100 10 [(5, 8), (3, 4)]).map
      (fun rs => rs.all (fun r => r.2 ≤ 100)) = some true := by
  native_decide

-- Strict monotone decrease (gap ≥ 2 between consecutive blocks).
-- Check: for each consecutive pair (a,_),(b,_): a ≥ b + 2.
example :
    (decodeAckBlocks 100 10 [(5, 8), (3, 4)]).map (fun rs =>
      (List.zip rs rs.tail).all (fun (r1, r2) => r2.2 + 2 ≤ r1.1)) =
    some true := by native_decide

-- Two-block sample: second range's largest < first range's smallest.
example :
    (decodeAckBlocks 20 4 [(2, 3)]).map (fun rs =>
      match rs with
      | (s1, _) :: (_, l2) :: _ => l2 + 2 ≤ s1
      | _ => True) = some true := by native_decide

-- Non-empty result on valid input.
example :
    (decodeAckBlocks 50 0 [(0, 0), (0, 0)]).isSome = true := by
  native_decide

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- § 7  Monotonicity of loop: decreasing largest_ack across blocks
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- At each iteration: new_largest = (smallest - gap) - 2 < smallest ≤ prev_largest.
-- So the sequence of `largest` values is strictly decreasing.
theorem loop_largest_decreases
    {smallest gap : Nat} (h : smallest ≥ 2 + gap) :
    (smallest - gap) - 2 < smallest := by omega

-- The gap-2 separation ensures disjointness:
-- If block i covers [s, l] and block i+1 has largest_next = (s - gap) - 2,
-- then largest_next ≤ s - 2 < s ≤ l + 1.
theorem blocks_disjoint_via_gap
    {s l gap : Nat} (hsl : s ≤ l) (hge : s ≥ 2 + gap) :
    (s - gap) - 2 < s := by omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- § 8  Failure characterisation
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- None ↔ first guard fired (la < ab).
theorem decodeAckBlocks_none_iff_first_guard
    (la ab : Nat) :
    decodeAckBlocks la ab [] = none ↔ la < ab := by
  unfold decodeAckBlocks
  by_cases h : la < ab
  · simp [h]
  · simp [h]
    unfold decodeAckBlocks.loop
    simp

-- On failure, no ranges are produced (trivially: none ≠ some _).
theorem decodeAckBlocks_none_means_no_ranges
    (la ab : Nat) (blocks : List (Nat × Nat)) :
    decodeAckBlocks la ab blocks = none →
    ∀ rs, decodeAckBlocks la ab blocks ≠ some rs := by
  intro h rs heq; exact absurd heq (by rw [h]; simp)
