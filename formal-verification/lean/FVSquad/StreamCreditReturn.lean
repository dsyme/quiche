-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of the QUIC stream credit-return
-- mechanism in `quiche/src/stream/mod.rs`.
--
-- Target T58: QUIC Stream Credit Return (collect + commit)
-- Phase: 4+5 — Implementation Model + Proofs
-- Lean 4 (v4.29.1), no Mathlib dependency.
--
-- Background
-- ──────────
-- RFC 9000 §4.6 specifies that when a peer-created stream completes, the
-- local endpoint SHOULD send a MAX_STREAMS frame to allow the peer to create
-- another stream.  In quiche this is implemented via a two-field staging
-- pattern:
--
--   `local_max_streams_bidi_next`  — the pending limit (incremented on collect)
--   `local_max_streams_bidi`       — the advertised limit (committed on send)
--
-- When a peer-created stream is collected:
--   `local_max_streams_bidi_next = local_max_streams_bidi_next.saturating_add(1)`
--
-- When a MAX_STREAMS frame is about to be sent:
--   `local_max_streams_bidi = local_max_streams_bidi_next`
--
-- The key invariant: the pending limit never drops below the committed limit.
-- This ensures the advertised stream window is monotonically non-decreasing,
-- preventing RFC 9000 §4.6 violations.
--
-- Model abstractions
-- ──────────────────
--   * All u64 fields are modelled as `Nat` — no wraparound.
--   * `saturating_add(1)` on `Nat` is plain addition (no saturation needed).
--   * Only bidi credit-return fields are modelled; uni is symmetric.
--   * The `is_bidi` check and stream removal are omitted — we model only the
--     credit accounting update, not the stream lifecycle bookkeeping.
--   * The two-phase structure (next vs. current) is the focus; other fields
--     (initial_max, local_opened, peer_max) are not included here (see T63).
--
-- Sections
-- ────────
--   §1  State type
--   §2  Implementation model
--   §3  Theorems: credit-return (single collect)        — 4 theorems
--   §4  Theorems: commit semantics                      — 4 theorems
--   §5  Theorems: invariant preservation                — 4 theorems
--   §6  Theorems: composed credit-return + commit       — 5 theorems
--   §7  Theorems: uni credit-return (symmetric)        — 3 theorems

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  State type
-- ─────────────────────────────────────────────────────────────────────────────

/-- Minimal state for the stream credit-return accounting.
    All fields are Nat (Rust u64 without overflow).
    Both bidi and uni directions are modelled. -/
structure CreditState where
  /-- Committed bidi limit (advertised to peer via MAX_STREAMS). -/
  bidiCurrent : Nat
  /-- Pending bidi limit (incremented by collect; committed on send). -/
  bidiNext    : Nat
  /-- Committed uni limit. -/
  uniCurrent  : Nat
  /-- Pending uni limit. -/
  uniNext     : Nat
  deriving DecidableEq, Repr

/-- The credit-return invariant: pending limits are always ≥ committed limits.
    This ensures MAX_STREAMS frames never advertise a smaller window. -/
def creditInvariant (s : CreditState) : Prop :=
  s.bidiNext ≥ s.bidiCurrent ∧
  s.uniNext  ≥ s.uniCurrent

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  Implementation model
-- ─────────────────────────────────────────────────────────────────────────────

/-- Model of the bidi credit-return inside `StreamMap::collect(stream_id, false)`.
    Rust: `self.local_max_streams_bidi_next = self.local_max_streams_bidi_next.saturating_add(1)`
    Nat: plain + 1 (no saturation needed; Nat is unbounded). -/
def returnBidiCredit (s : CreditState) : CreditState :=
  { s with bidiNext := s.bidiNext + 1 }

/-- Model of the uni credit-return inside `StreamMap::collect(stream_id, false)`.
    Rust: `self.local_max_streams_uni_next = self.local_max_streams_uni_next.saturating_add(1)` -/
def returnUniCredit (s : CreditState) : CreditState :=
  { s with uniNext := s.uniNext + 1 }

/-- Model of `StreamMap::update_max_streams_bidi()`.
    Rust: `self.local_max_streams_bidi = self.local_max_streams_bidi_next` -/
def commitBidi (s : CreditState) : CreditState :=
  { s with bidiCurrent := s.bidiNext }

/-- Model of `StreamMap::update_max_streams_uni()`.
    Rust: `self.local_max_streams_uni = self.local_max_streams_uni_next` -/
def commitUni (s : CreditState) : CreditState :=
  { s with uniCurrent := s.uniNext }

/-- Apply n bidi credit-return steps (n peer-created bidi streams collected). -/
def returnBidiCreditN (s : CreditState) : Nat → CreditState
  | 0     => s
  | n + 1 => returnBidiCredit (returnBidiCreditN s n)

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  Theorems: credit-return (single collect)
-- ─────────────────────────────────────────────────────────────────────────────

/-- One bidi credit-return increments bidiNext by exactly 1. -/
theorem returnBidi_increments_next (s : CreditState) :
    (returnBidiCredit s).bidiNext = s.bidiNext + 1 := by
  simp [returnBidiCredit]

/-- Bidi credit-return does not affect uniNext. -/
theorem returnBidi_preserves_uni (s : CreditState) :
    (returnBidiCredit s).uniNext = s.uniNext := by
  simp [returnBidiCredit]

/-- Bidi credit-return does not affect committed limits. -/
theorem returnBidi_preserves_current (s : CreditState) :
    (returnBidiCredit s).bidiCurrent = s.bidiCurrent ∧
    (returnBidiCredit s).uniCurrent  = s.uniCurrent := by
  simp [returnBidiCredit]

/-- Each credit-return makes bidiNext strictly larger. -/
theorem returnBidi_next_increases (s : CreditState) :
    (returnBidiCredit s).bidiNext > s.bidiNext := by
  simp [returnBidiCredit]

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Theorems: commit semantics
-- ─────────────────────────────────────────────────────────────────────────────

/-- After commit, bidiCurrent equals the pending limit. -/
theorem commitBidi_equalises (s : CreditState) :
    (commitBidi s).bidiCurrent = s.bidiNext := by
  simp [commitBidi]

/-- Commit is idempotent: double commit gives the same result as single. -/
theorem commitBidi_idempotent (s : CreditState) :
    commitBidi (commitBidi s) = commitBidi s := by
  simp [commitBidi]

/-- Bidi commit does not affect uni fields. -/
theorem commitBidi_preserves_uni (s : CreditState) :
    (commitBidi s).uniCurrent = s.uniCurrent ∧
    (commitBidi s).uniNext    = s.uniNext := by
  simp [commitBidi]

/-- Commit is monotone: bidiCurrent after commit ≥ bidiCurrent before. -/
theorem commitBidi_monotone (s : CreditState) (h : creditInvariant s) :
    (commitBidi s).bidiCurrent ≥ s.bidiCurrent := by
  simp [commitBidi]
  exact h.1

-- ─────────────────────────────────────────────────────────────────────────────
-- §5  Theorems: invariant preservation
-- ─────────────────────────────────────────────────────────────────────────────

/-- Bidi credit-return preserves the invariant. -/
theorem returnBidi_preserves_invariant (s : CreditState) (h : creditInvariant s) :
    creditInvariant (returnBidiCredit s) := by
  simp [creditInvariant, returnBidiCredit] at *
  omega

/-- Uni credit-return preserves the invariant. -/
theorem returnUni_preserves_invariant (s : CreditState) (h : creditInvariant s) :
    creditInvariant (returnUniCredit s) := by
  obtain ⟨hb, hu⟩ := h
  simp [creditInvariant, returnUniCredit, hb]
  omega

/-- Bidi commit preserves the invariant. -/
theorem commitBidi_preserves_invariant (s : CreditState) (h : creditInvariant s) :
    creditInvariant (commitBidi s) := by
  obtain ⟨hb, hu⟩ := h
  exact ⟨Nat.le_refl _, hu⟩

/-- Uni commit preserves the invariant. -/
theorem commitUni_preserves_invariant (s : CreditState) (h : creditInvariant s) :
    creditInvariant (commitUni s) := by
  obtain ⟨hb, hu⟩ := h
  exact ⟨hb, Nat.le_refl _⟩

-- ─────────────────────────────────────────────────────────────────────────────
-- §6  Theorems: composed credit-return + commit
-- ─────────────────────────────────────────────────────────────────────────────

/-- After n bidi credit-return steps, bidiNext = initial + n. -/
theorem returnBidiN_adds_n (s : CreditState) (n : Nat) :
    (returnBidiCreditN s n).bidiNext = s.bidiNext + n := by
  induction n with
  | zero => simp [returnBidiCreditN]
  | succ k ih =>
    simp [returnBidiCreditN, returnBidiCredit, ih]
    omega

/-- After n credit-return steps and a commit, bidiCurrent = initial + n. -/
theorem returnN_then_commit (s : CreditState) (n : Nat) :
    (commitBidi (returnBidiCreditN s n)).bidiCurrent = s.bidiNext + n := by
  simp [commitBidi, returnBidiN_adds_n]

/-- Credit-return and commit together: bidiCurrent strictly increases (given invariant). -/
theorem returnThenCommit_increases_current (s : CreditState) (h : creditInvariant s) :
    (commitBidi (returnBidiCredit s)).bidiCurrent > s.bidiCurrent := by
  obtain ⟨hb, _⟩ := h
  simp [commitBidi, returnBidiCredit]
  omega

/-- Bidi and uni credit-return commute (independent fields). -/
theorem returnBidi_returnUni_commute (s : CreditState) :
    returnUniCredit (returnBidiCredit s) = returnBidiCredit (returnUniCredit s) := by
  simp [returnBidiCredit, returnUniCredit]

/-- After commit, current equals next; a further collect makes next > current again. -/
theorem commit_then_collect_grows_next (s : CreditState) :
    let s1 := commitBidi s
    let s2 := returnBidiCredit s1
    s2.bidiNext > s1.bidiCurrent := by
  simp [commitBidi, returnBidiCredit]

-- ─────────────────────────────────────────────────────────────────────────────
-- §7  Theorems: uni credit-return (symmetric)
-- ─────────────────────────────────────────────────────────────────────────────

/-- Uni credit-return increments uniNext by exactly 1. -/
theorem returnUni_increments_next (s : CreditState) :
    (returnUniCredit s).uniNext = s.uniNext + 1 := by
  simp [returnUniCredit]

/-- Uni credit-return does not affect bidi fields. -/
theorem returnUni_preserves_bidi (s : CreditState) :
    (returnUniCredit s).bidiCurrent = s.bidiCurrent ∧
    (returnUniCredit s).bidiNext    = s.bidiNext := by
  simp [returnUniCredit]

/-- After commit, uniCurrent equals the pending uni limit. -/
theorem commitUni_equalises (s : CreditState) :
    (commitUni s).uniCurrent = s.uniNext := by
  simp [commitUni]

-- End of FVSquad/StreamCreditReturn.lean
