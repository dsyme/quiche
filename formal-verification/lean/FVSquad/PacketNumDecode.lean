-- Copyright (C) 2024, Cloudflare, Inc.
-- BSD license. See LICENSE for details.
--
-- FVSquad/PacketNumDecode.lean
--
-- Formal verification of `decode_pkt_num` (quiche/src/packet.rs:634–652).
-- RFC 9000 Appendix A.3 — Sample Packet Number Decoding Algorithm.
--
-- MODEL SCOPE:
--   • Arithmetic model: candidatePn uses integer division instead of the
--     bitwise `(expected & ~mask) | truncated`. These are equal for power-of-two
--     window sizes when truncated < pnWin, but the arithmetic form is more
--     tractable for `omega`.
--   • Nat arithmetic; u64 overflow (wrap at 2^64) is NOT modelled.
--   • QUIC proximity invariant is a hypothesis, not enforced here.
--   • The two `&&` conditions from Rust are modelled as nested `if` statements
--     to allow `split` and `by_cases` to work on Prop-valued conditions.

-- ---------------------------------------------------------------------------
-- Arithmetic helpers
-- ---------------------------------------------------------------------------

theorem mul_mod_zero (k win : Nat) : k * win % win = 0 := by
  cases Nat.eq_zero_or_pos win with
  | inl h => simp [h]
  | inr h => rw [Nat.mul_comm]; exact Nat.mul_mod_right win k

theorem mul_add_mod (k win m : Nat) (h : m < win) : (k * win + m) % win = m := by
  cases Nat.eq_zero_or_pos win with
  | inl hw => omega
  | inr hw =>
    have hkw : k * win % win = 0 := mul_mod_zero k win
    have hlt : m % win < win := Nat.mod_lt m hw
    rw [Nat.add_mod, hkw, Nat.zero_add, Nat.mod_eq_of_lt hlt, Nat.mod_eq_of_lt h]

theorem sub_add_mod (a win : Nat) (h : a ≥ win) : (a - win) % win = a % win :=
  calc (a - win) % win = (a - win + win) % win := (Nat.add_mod_right _ _).symm
    _ = a % win := by rw [Nat.sub_add_cancel h]

-- ---------------------------------------------------------------------------
-- Window definitions
-- ---------------------------------------------------------------------------

/-- Number of bits in the packet-number field (pn_len bytes). -/
def pnNbits (pn_len : Nat) : Nat := pn_len * 8

/-- Window size: 2^(pn_len*8). -/
def pnWin (pn_len : Nat) : Nat := 1 <<< pnNbits pn_len

/-- Half-window. -/
def pnHwin (pn_len : Nat) : Nat := pnWin pn_len / 2

-- ---------------------------------------------------------------------------
-- Implementation model
-- ---------------------------------------------------------------------------

/-- Arithmetic equivalent of Rust's `(expected_pn & !pn_mask) | truncated_pn`.
    For power-of-2 window sizes this gives the same result when truncated < pnWin. -/
def candidatePn (expected_pn truncated_pn pn_len : Nat) : Nat :=
  (expected_pn / pnWin pn_len) * pnWin pn_len + truncated_pn

/-- Lean model of `decode_pkt_num` (quiche/src/packet.rs:634).
    The two `&&` conditions are split into nested `if`s for tractable proofs.
    Semantics are identical to the Rust. -/
def decodePktNum (largest_pn truncated_pn pn_len : Nat) : Nat :=
  let expected_pn := largest_pn + 1
  let pn_win      := pnWin pn_len
  let pn_hwin     := pnHwin pn_len
  let cand        := candidatePn expected_pn truncated_pn pn_len
  if cand + pn_hwin ≤ expected_pn then
    if cand < (1 <<< 62) - pn_win then cand + pn_win
    else cand
  else if cand > expected_pn + pn_hwin then
    if cand ≥ pn_win then cand - pn_win
    else cand
  else
    cand

-- ---------------------------------------------------------------------------
-- Window lemmas
-- ---------------------------------------------------------------------------

theorem pnWin_pos (pn_len : Nat) : 0 < pnWin pn_len := by
  unfold pnWin pnNbits; simp [Nat.shiftLeft_eq]; exact Nat.two_pow_pos _

theorem pnWin_eq (pn_len : Nat) : pnWin pn_len = 2 ^ (pn_len * 8) := by
  unfold pnWin pnNbits; simp [Nat.shiftLeft_eq]

theorem pnHwin_le_win (pn_len : Nat) : pnHwin pn_len ≤ pnWin pn_len :=
  Nat.div_le_self _ _

-- ---------------------------------------------------------------------------
-- Candidate structure
-- ---------------------------------------------------------------------------

/-- Candidate ≡ truncated_pn (mod pnWin): low bits equal truncated_pn. -/
theorem candidate_mod_win
    (expected_pn truncated_pn pn_len : Nat)
    (h : truncated_pn < pnWin pn_len) :
    candidatePn expected_pn truncated_pn pn_len % pnWin pn_len = truncated_pn := by
  unfold candidatePn
  exact mul_add_mod _ _ _ h

/-- Candidate is at most expected_pn + pnWin - 1. -/
theorem candidate_lt_expected_plus_win
    (expected_pn truncated_pn pn_len : Nat)
    (h : truncated_pn < pnWin pn_len) :
    candidatePn expected_pn truncated_pn pn_len < expected_pn + pnWin pn_len := by
  unfold candidatePn
  -- alpha-trick: name α := (exp/win)*win as an opaque Nat variable.
  -- Then α + exp%win = expected_pn (linear), and cand = α + trunc.
  -- Goal: α + trunc < α + exp%win + win ↔ trunc < exp%win + win. omega closes.
  have hα : expected_pn / pnWin pn_len * pnWin pn_len +
            expected_pn % pnWin pn_len = expected_pn := by
    rw [Nat.mul_comm]; exact Nat.div_add_mod expected_pn (pnWin pn_len)
  have hme := Nat.mod_lt expected_pn (pnWin_pos pn_len)
  omega

/-- Expected_pn is less than candidate + pnWin. -/
theorem expected_lt_candidate_plus_win
    (expected_pn truncated_pn pn_len : Nat)
    (_h : truncated_pn < pnWin pn_len) :
    expected_pn < candidatePn expected_pn truncated_pn pn_len + pnWin pn_len := by
  unfold candidatePn
  have hα : expected_pn / pnWin pn_len * pnWin pn_len +
            expected_pn % pnWin pn_len = expected_pn := by
    rw [Nat.mul_comm]; exact Nat.div_add_mod expected_pn (pnWin pn_len)
  have hme := Nat.mod_lt expected_pn (pnWin_pos pn_len)
  omega

-- ---------------------------------------------------------------------------
-- Core congruence: RFC 9000 §17.1
-- ---------------------------------------------------------------------------

/-- The decoded packet number is congruent to `truncated_pn` modulo `pnWin`.
    This is the fundamental RFC 9000 §17.1 invariant. -/
theorem decode_mod_win_exact
    (largest_pn truncated_pn pn_len : Nat)
    (h : truncated_pn < pnWin pn_len) :
    decodePktNum largest_pn truncated_pn pn_len % pnWin pn_len = truncated_pn := by
  have hcb := candidate_mod_win (largest_pn + 1) truncated_pn pn_len h
  have hadd : (candidatePn (largest_pn + 1) truncated_pn pn_len + pnWin pn_len) % pnWin pn_len =
              truncated_pn := by rw [Nat.add_mod_right, hcb]
  have hsub : ∀ h2 : candidatePn (largest_pn + 1) truncated_pn pn_len ≥ pnWin pn_len,
              (candidatePn (largest_pn + 1) truncated_pn pn_len - pnWin pn_len) % pnWin pn_len =
              truncated_pn := by
    intro h2; rw [sub_add_mod _ _ h2, hcb]
  simp only [decodePktNum]
  by_cases hb1 : candidatePn (largest_pn + 1) truncated_pn pn_len + pnHwin pn_len ≤ largest_pn + 1
  · simp only [hb1, ite_true]
    by_cases hb2 : candidatePn (largest_pn + 1) truncated_pn pn_len < (1 <<< 62) - pnWin pn_len
    · simp only [hb2, ite_true, hadd]
    · simp only [hb2, ite_false, hcb]
  · simp only [hb1, ite_false]
    by_cases hb3 : candidatePn (largest_pn + 1) truncated_pn pn_len > largest_pn + 1 + pnHwin pn_len
    · simp only [hb3, ite_true]
      by_cases hb4 : candidatePn (largest_pn + 1) truncated_pn pn_len ≥ pnWin pn_len
      · simp only [hb4, ite_true, hsub hb4]
      · simp only [hb4, ite_false, hcb]
    · simp only [hb3, ite_false, hcb]

-- ---------------------------------------------------------------------------
-- Branch upper bounds
-- ---------------------------------------------------------------------------

/-- Branch 2 (downward adjustment) keeps result ≤ expected_pn + hwin. -/
theorem decode_branch2_upper
    (largest_pn truncated_pn pn_len : Nat)
    (htrun : truncated_pn < pnWin pn_len) :
    let expected_pn := largest_pn + 1
    let win  := pnWin pn_len
    let hwin := pnHwin pn_len
    let cand := candidatePn expected_pn truncated_pn pn_len
    cand > expected_pn + hwin → cand ≥ win → cand - win ≤ expected_pn + hwin := by
  intro expected_pn win hwin cand h1 h2
  have hclt := candidate_lt_expected_plus_win expected_pn truncated_pn pn_len htrun
  exact Nat.le_of_lt_succ (by omega)

-- ---------------------------------------------------------------------------
-- Concrete test vectors (from quiche test suite and RFC 9000 §A.3)
-- ---------------------------------------------------------------------------

/-- RFC A.3 example: largest=0xa82f30ea, trunc=0x9b32, len=2 → 0xa82f9b32 -/
theorem test_vector_rfc_example :
    decodePktNum 0xa82f30ea 0x9b32 2 = 0xa82f9b32 := by native_decide

/-- quiche test: largest=0xac5c01, 2-byte truncation of 0xac5c02 -/
theorem test_vector_quiche_2byte :
    decodePktNum 0xac5c01 (0xac5c02 % (1 <<< 16)) 2 = 0xac5c02 := by native_decide

/-- quiche test: largest=0xace9fa, 3-byte truncation of 0xace9fe -/
theorem test_vector_quiche_3byte :
    decodePktNum 0xace9fa (0xace9fe % (1 <<< 24)) 3 = 0xace9fe := by native_decide

/-- Round-trip 1-byte -/
theorem test_vector_roundtrip_1byte :
    decodePktNum 0xdeadbeef (0xdeadbef0 % (1 <<< 8)) 1 = 0xdeadbef0 := by native_decide

/-- Round-trip 2-byte -/
theorem test_vector_roundtrip_2byte :
    decodePktNum 0xdeadbeef (0xdeadbf05 % (1 <<< 16)) 2 = 0xdeadbf05 := by native_decide

/-- Branch 1 fires (upward): largest=0x100, trunc=0x7f, pn_len=1 → 0x17f -/
theorem test_vector_branch1 :
    decodePktNum 0x100 0x7f 1 = 0x17f := by native_decide

/-- Branch 2 fires (downward): largest=0x8100, trunc=0xfe, pn_len=1 → 0x80fe -/
theorem test_vector_branch2 :
    decodePktNum 0x8100 0xfe 1 = 0x80fe := by native_decide

-- ---------------------------------------------------------------------------
-- Non-negativity
-- ---------------------------------------------------------------------------

theorem decode_nonneg (largest_pn truncated_pn pn_len : Nat) :
    0 ≤ decodePktNum largest_pn truncated_pn pn_len := Nat.zero_le _

-- ---------------------------------------------------------------------------
-- Overflow guard
-- ---------------------------------------------------------------------------

/-- Branch 1 is suppressed before result exceeds 2^62. -/
theorem decode_branch1_overflow_guard
    (largest_pn truncated_pn pn_len : Nat) :
    let win  := pnWin pn_len
    let hwin := pnHwin pn_len
    let cand := candidatePn (largest_pn + 1) truncated_pn pn_len
    cand + hwin ≤ largest_pn + 1 → cand < (1 <<< 62) - win →
    cand + win < (1 <<< 62) := by
  intro win hwin cand _ h2; omega

-- ---------------------------------------------------------------------------
-- Monotonicity
-- ---------------------------------------------------------------------------

/-- Shifting expected_pn by one window shifts the candidate by the same amount. -/
theorem candidate_shift_win
    (expected_pn truncated_pn pn_len : Nat) :
    candidatePn (expected_pn + pnWin pn_len) truncated_pn pn_len =
    candidatePn expected_pn truncated_pn pn_len + pnWin pn_len := by
  unfold candidatePn
  rw [Nat.add_div_right expected_pn (pnWin_pos pn_len), Nat.add_mul]
  omega

-- ---------------------------------------------------------------------------
-- Correctness under the QUIC invariant (partial proof)
-- ---------------------------------------------------------------------------

/-- Under the QUIC invariant (actual_pn ≡ truncated_pn mod win and within
    pn_hwin of expected_pn), decodePktNum returns actual_pn.
    Proof: sorry — the α=β case split requires additional lemmas. -/
theorem decode_pktnum_correct
    (largest_pn truncated_pn pn_len actual_pn : Nat)
    (hlen  : 0 < pn_len)
    (htrun : truncated_pn < pnWin pn_len)
    (hmod  : actual_pn % pnWin pn_len = truncated_pn)
    (hprox : actual_pn ≤ largest_pn + 1 + pnHwin pn_len)
    (hprox2 : largest_pn + 1 ≤ actual_pn + pnHwin pn_len) :
    decodePktNum largest_pn truncated_pn pn_len = actual_pn := by
  -- The proof requires showing that the candidate equals actual_pn
  -- (i.e., both live in the same window) and that neither adjustment fires.
  -- This follows from the proximity bounds but requires case analysis.
  sorry

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------
-- Theorems (22 total, 1 sorry):
--
-- Helpers (3): mul_mod_zero, mul_add_mod, sub_add_mod
-- Window (3): pnWin_pos, pnWin_eq, pnHwin_le_win
-- Candidate (3): candidate_mod_win, candidate_lt_expected_plus_win,
--                expected_lt_candidate_plus_win
-- Core (1): decode_mod_win_exact  ← RFC 9000 §17.1 congruence property
-- Branch bounds (2): decode_branch2_upper, decode_branch1_overflow_guard
-- Test vectors (7): rfc_example, quiche_2byte, quiche_3byte,
--                   roundtrip_1byte, roundtrip_2byte, branch1, branch2
-- Structural (3): decode_nonneg, candidate_shift_win, decode_pktnum_correct*
-- (* decode_pktnum_correct has 1 sorry)
