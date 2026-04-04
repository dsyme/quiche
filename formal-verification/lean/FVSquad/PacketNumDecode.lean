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

/-- If a and b are multiples of n, and b + n ≤ a < b + 2*n, then a = b + n.
    Used in `decode_pktnum_correct` to establish which window the candidate
    belongs to relative to the actual packet number. -/
theorem mul_uniq_in_range (a b n : Nat) (ha : a % n = 0) (hb : b % n = 0)
    (hlo : b + n ≤ a) (hhi : a < b + 2 * n) (hn : 0 < n) : a = b + n := by
  have hqa : n * (a / n) = a := by
    have h := Nat.div_add_mod a n; rw [ha] at h; simpa using h
  have hqb : n * (b / n) = b := by
    have h := Nat.div_add_mod b n; rw [hb] at h; simpa using h
  have hq_lo : b / n + 1 ≤ a / n := by
    have h1 : n * (b / n + 1) ≤ n * (a / n) := by
      rw [Nat.mul_add, Nat.mul_one]; omega
    exact Nat.le_of_mul_le_mul_left h1 hn
  have hq_hi : a / n ≤ b / n + 1 := by
    have h1 : n * (a / n) < n * (b / n + 2) := by rw [Nat.mul_add]; omega
    exact Nat.lt_succ_iff.mp (Nat.lt_of_mul_lt_mul_left h1)
  have hq_eq : a / n = b / n + 1 := Nat.le_antisymm hq_hi hq_lo
  rw [← hqa, hq_eq, Nat.mul_add, Nat.mul_one, hqb]

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
-- Correctness under the QUIC invariant (fully proved)
-- ---------------------------------------------------------------------------

/-- Under the QUIC proximity invariant, `decodePktNum` returns `actual_pn`.

    Hypotheses mirror the RFC 9000 §A.3 preconditions in Nat arithmetic:
    • `hprox`    — actual_pn ≤ expected_pn + pnHwin  (upper proximity bound)
    • `hprox2`   — expected_pn < actual_pn + pnHwin  (strict lower bound;
                   the original non-strict ≤ allows a counterexample at
                   actual_pn = expected_pn − pnHwin where branch 1 fires
                   incorrectly)
    • `hoverflow` — actual_pn < 2^62  (mirrors the Rust u64 / QUIC pn cap)
    • `hwin_le`   — pnWin ≤ 2^62  (pn_len ∈ {1…4} so pnWin ≤ 2^32 ≪ 2^62;
                   needed to prevent Nat subtraction underflow in branch 1)

    Proof sketch (3-way case split on window quotients α = exp/win, β = act/win):
    • α = β  → cand = actual_pn, strict hprox2 excludes branch 1, hprox
               excludes branch 2 → result = cand = actual_pn.
    • α = β+1 → cand = actual_pn + win; branch 1 excluded (hprox2), branch 2
               fires → result = cand − win = actual_pn.
    • β = α+1 → cand = actual_pn − win; branch 1 fires (hprox + 2*hwin ≤ win),
               overflow guard holds (hoverflow + hwin_le) → result = cand + win
               = actual_pn.
    The uniqueness of each window assignment uses `mul_uniq_in_range`. -/
theorem decode_pktnum_correct
    (largest_pn truncated_pn pn_len actual_pn : Nat)
    (hlen      : 0 < pn_len)
    (htrun     : truncated_pn < pnWin pn_len)
    (hmod      : actual_pn % pnWin pn_len = truncated_pn)
    (hprox     : actual_pn ≤ largest_pn + 1 + pnHwin pn_len)
    (hprox2    : largest_pn + 1 < actual_pn + pnHwin pn_len)
    (hoverflow : actual_pn < (1 : Nat) <<< 62)
    (hwin_le   : pnWin pn_len ≤ (1 : Nat) <<< 62) :
    decodePktNum largest_pn truncated_pn pn_len = actual_pn := by
  have hwin_pos := pnWin_pos pn_len
  have h2hwin : 2 * pnHwin pn_len ≤ pnWin pn_len := by unfold pnHwin; omega
  -- α + exp%win = exp  (α = floor multiple of win below exp)
  have hα_sum : (largest_pn + 1) / pnWin pn_len * pnWin pn_len +
                (largest_pn + 1) % pnWin pn_len = largest_pn + 1 := by
    rw [Nat.mul_comm]; exact Nat.div_add_mod _ _
  -- β + trunc = actual_pn  (β = floor multiple of win below actual_pn)
  have hβ_sum : actual_pn / pnWin pn_len * pnWin pn_len + truncated_pn = actual_pn := by
    have h := Nat.div_add_mod actual_pn (pnWin pn_len)
    rw [Nat.mul_comm, hmod] at h; exact h
  have hrexp  : (largest_pn + 1) % pnWin pn_len < pnWin pn_len := Nat.mod_lt _ hwin_pos
  have hα_le  : (largest_pn + 1) / pnWin pn_len * pnWin pn_len ≤ largest_pn + 1 := by omega
  have hβ_le  : actual_pn / pnWin pn_len * pnWin pn_len ≤ actual_pn := by omega
  have hα_mod : (largest_pn + 1) / pnWin pn_len * pnWin pn_len % pnWin pn_len = 0 :=
    mul_mod_zero _ _
  have hβ_mod : actual_pn / pnWin pn_len * pnWin pn_len % pnWin pn_len = 0 :=
    mul_mod_zero _ _
  simp only [decodePktNum]
  -- 3-way split on which window α and β inhabit
  rcases Nat.lt_or_ge (actual_pn / pnWin pn_len)
                      ((largest_pn + 1) / pnWin pn_len) with h_lt | h_ge
  · -- α = β + win: cand = actual_pn + win, branch 2 fires, result = actual_pn
    have hαβ : (largest_pn + 1) / pnWin pn_len * pnWin pn_len =
               actual_pn / pnWin pn_len * pnWin pn_len + pnWin pn_len := by
      apply mul_uniq_in_range _ _ _ hα_mod hβ_mod _ _ hwin_pos
      · have hle := Nat.mul_le_mul_right (pnWin pn_len) h_lt
        rw [Nat.succ_mul] at hle; omega
      · omega
    have hcand_eq : candidatePn (largest_pn + 1) truncated_pn pn_len =
                    actual_pn + pnWin pn_len := by unfold candidatePn; omega
    rw [hcand_eq]
    by_cases hb1 : actual_pn + pnWin pn_len + pnHwin pn_len ≤ largest_pn + 1
    · exfalso; omega
    · simp only [hb1, ite_false]
      by_cases hb2 : actual_pn + pnWin pn_len > largest_pn + 1 + pnHwin pn_len
      · simp only [hb2, ite_true]
        have hcw : actual_pn + pnWin pn_len ≥ pnWin pn_len := Nat.le_add_left _ _
        simp only [hcw, ite_true]; omega
      · exfalso; omega
  · rcases Nat.lt_or_ge ((largest_pn + 1) / pnWin pn_len)
                        (actual_pn / pnWin pn_len) with h_lt2 | h_eq
    · -- β = α + win: cand = actual_pn − win, branch 1 fires, result = actual_pn
      have hβα : actual_pn / pnWin pn_len * pnWin pn_len =
                 (largest_pn + 1) / pnWin pn_len * pnWin pn_len + pnWin pn_len := by
        apply mul_uniq_in_range _ _ _ hβ_mod hα_mod _ _ hwin_pos
        · have hle := Nat.mul_le_mul_right (pnWin pn_len) h_lt2
          rw [Nat.succ_mul] at hle; omega
        · omega
      have hact_ge_win : pnWin pn_len ≤ actual_pn := by omega
      have hcand_eq : candidatePn (largest_pn + 1) truncated_pn pn_len =
                      actual_pn - pnWin pn_len := by unfold candidatePn; omega
      rw [hcand_eq]
      by_cases hb1 : actual_pn - pnWin pn_len + pnHwin pn_len ≤ largest_pn + 1
      · simp only [hb1, ite_true]
        have hov : actual_pn - pnWin pn_len < (1 : Nat) <<< 62 - pnWin pn_len := by
          omega
        simp only [hov, ite_true]; omega
      · exfalso; omega
    · -- α = β: cand = actual_pn, neither branch fires, result = actual_pn
      have h_quot_eq : (largest_pn + 1) / pnWin pn_len = actual_pn / pnWin pn_len :=
        Nat.le_antisymm h_ge h_eq
      have hcand_eq : candidatePn (largest_pn + 1) truncated_pn pn_len = actual_pn := by
        unfold candidatePn; rw [h_quot_eq]; exact hβ_sum
      rw [hcand_eq]
      by_cases hb1 : actual_pn + pnHwin pn_len ≤ largest_pn + 1
      · exfalso; omega
      · simp only [hb1, ite_false]
        by_cases hb2 : actual_pn > largest_pn + 1 + pnHwin pn_len
        · exfalso; omega
        · simp only [hb2, ite_false]

-- ---------------------------------------------------------------------------
-- Summary
-- ---------------------------------------------------------------------------
-- Theorems (24 total, 0 sorry):
--
-- Helpers (4): mul_mod_zero, mul_add_mod, sub_add_mod, mul_uniq_in_range
-- Window (3): pnWin_pos, pnWin_eq, pnHwin_le_win
-- Candidate (3): candidate_mod_win, candidate_lt_expected_plus_win,
--                expected_lt_candidate_plus_win
-- Core (1): decode_mod_win_exact  ← RFC 9000 §17.1 congruence property
-- Branch bounds (2): decode_branch2_upper, decode_branch1_overflow_guard
-- Test vectors (7): rfc_example, quiche_2byte, quiche_3byte,
--                   roundtrip_1byte, roundtrip_2byte, branch1, branch2
-- Structural (4): decode_nonneg, candidate_shift_win, decode_pktnum_correct,
--                 (mul_uniq_in_range counted in Helpers)
--
-- decode_pktnum_correct: FULLY PROVED (0 sorry).
--   Hypotheses refined from run 37-38:
--   • hprox2 strengthened to strict < (edge case at equality is a genuine bug)
--   • hoverflow : actual_pn < 2^62 added (mirrors QUIC packet number cap)
--   • hwin_le   : pnWin ≤ 2^62 added (prevents Nat subtraction underflow)
