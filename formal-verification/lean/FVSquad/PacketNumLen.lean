-- Copyright (C) 2024, Cloudflare, Inc.
-- BSD license. See LICENSE for details.
--
-- FVSquad/PacketNumLen.lean
--
-- Formal verification of `pkt_num_len` (quiche/src/packet.rs ~569) and
-- `encode_pkt_num` (quiche/src/packet.rs ~719).
--
-- RFC 9000 §17.1: packet number length selection for header encoding.
-- Companion to PacketNumDecode.lean (receiver side decode_pkt_num).
--
-- MODEL SCOPE:
--   • Pure arithmetic model; u64 overflow not modelled.
--   • `numUnacked` uses Lean's truncated Nat subtraction (= saturating_sub).
--   • `encode_pkt_num` byte-buffer interaction is abstracted: only the
--     pn_len ∈ {1,2,3,4} validity contract is proved.
--   • The QUIC constraint numUnacked ≤ 2^31-1 is a hypothesis where needed.

namespace PacketNumLen

-- ---------------------------------------------------------------------------
-- Implementation model
-- ---------------------------------------------------------------------------

/-- Number of logically-unacknowledged packet numbers.
    Lean Nat subtraction is already saturating (pn - la = 0 when pn ≤ la),
    so numUnacked = 1 when pn ≤ la. Matches Rust `pn.saturating_sub(la) + 1`. -/
def numUnacked (pn la : Nat) : Nat := pn - la + 1

/-- Minimum bytes to encode `pn` given largest-acked `la`.
    Matches Rust `pkt_num_len`. Does not use a let-binding so simp unfolds cleanly.
    Thresholds: 1↔≤127, 2↔≤32767, 3↔≤8388607, 4↔otherwise. -/
def pktNumLen (pn la : Nat) : Nat :=
  if numUnacked pn la ≤ 127 then 1
  else if numUnacked pn la ≤ 32767 then 2
  else if numUnacked pn la ≤ 8388607 then 3
  else 4

-- ---------------------------------------------------------------------------
-- Basic properties of numUnacked
-- ---------------------------------------------------------------------------

theorem numUnacked_pos (pn la : Nat) : 0 < numUnacked pn la := by
  unfold numUnacked; omega

theorem numUnacked_ge_one (pn la : Nat) : 1 ≤ numUnacked pn la :=
  numUnacked_pos pn la

theorem numUnacked_self (la : Nat) : numUnacked la la = 1 := by
  unfold numUnacked; omega

theorem numUnacked_lt (pn la : Nat) (h : pn < la) :
    numUnacked pn la = 1 := by
  unfold numUnacked; omega

-- ---------------------------------------------------------------------------
-- Shared case-split helper
-- ---------------------------------------------------------------------------

private theorem split3 (P : Prop) (u : Nat)
    (h1 : u ≤ 127 → P) (h2 : ¬ u ≤ 127 → u ≤ 32767 → P)
    (h3 : ¬ u ≤ 127 → ¬ u ≤ 32767 → u ≤ 8388607 → P)
    (h4 : ¬ u ≤ 127 → ¬ u ≤ 32767 → ¬ u ≤ 8388607 → P) : P := by
  by_cases c1 : u ≤ 127
  · exact h1 c1
  · by_cases c2 : u ≤ 32767
    · exact h2 c1 c2
    · by_cases c3 : u ≤ 8388607
      · exact h3 c1 c2 c3
      · exact h4 c1 c2 c3

-- ---------------------------------------------------------------------------
-- Range of pktNumLen
-- ---------------------------------------------------------------------------

theorem pktNumLen_ge_one (pn la : Nat) : 1 ≤ pktNumLen pn la :=
  split3 _ (numUnacked pn la)
    (fun c1 => by simp [pktNumLen, if_pos c1])
    (fun c1 c2 => by simp [pktNumLen, if_neg c1, if_pos c2])
    (fun c1 c2 c3 => by simp [pktNumLen, if_neg c1, if_neg c2, if_pos c3])
    (fun c1 c2 c3 => by simp [pktNumLen, if_neg c1, if_neg c2, if_neg c3])

theorem pktNumLen_le_four (pn la : Nat) : pktNumLen pn la ≤ 4 :=
  split3 _ (numUnacked pn la)
    (fun c1 => by simp [pktNumLen, if_pos c1])
    (fun c1 c2 => by simp [pktNumLen, if_neg c1, if_pos c2])
    (fun c1 c2 c3 => by simp [pktNumLen, if_neg c1, if_neg c2, if_pos c3])
    (fun c1 c2 c3 => by simp [pktNumLen, if_neg c1, if_neg c2, if_neg c3])

theorem pktNumLen_self (la : Nat) : pktNumLen la la = 1 := by
  simp [pktNumLen, numUnacked]

-- ---------------------------------------------------------------------------
-- Characterisation theorems
-- ---------------------------------------------------------------------------

theorem pktNumLen_eq_one_iff (pn la : Nat) :
    pktNumLen pn la = 1 ↔ numUnacked pn la ≤ 127 := by
  constructor
  · intro h
    simp only [pktNumLen] at h
    by_cases c1 : numUnacked pn la ≤ 127
    · exact c1
    · rw [if_neg c1] at h
      by_cases c2 : numUnacked pn la ≤ 32767
      · simp [if_pos c2] at h
      · rw [if_neg c2] at h
        by_cases c3 : numUnacked pn la ≤ 8388607
        · simp [if_pos c3] at h
        · simp [if_neg c3] at h
  · intro h; simp [pktNumLen, if_pos h]

theorem pktNumLen_eq_two_iff (pn la : Nat) :
    pktNumLen pn la = 2 ↔ 128 ≤ numUnacked pn la ∧ numUnacked pn la ≤ 32767 := by
  constructor
  · intro h
    simp only [pktNumLen] at h
    by_cases c1 : numUnacked pn la ≤ 127
    · simp [if_pos c1] at h
    · rw [if_neg c1] at h
      by_cases c2 : numUnacked pn la ≤ 32767
      · exact ⟨by omega, c2⟩
      · rw [if_neg c2] at h
        by_cases c3 : numUnacked pn la ≤ 8388607
        · simp [if_pos c3] at h
        · simp [if_neg c3] at h
  · rintro ⟨h128, h32k⟩
    have c1 : ¬ numUnacked pn la ≤ 127 := by omega
    simp [pktNumLen, if_neg c1, if_pos h32k]

theorem pktNumLen_eq_three_iff (pn la : Nat) :
    pktNumLen pn la = 3 ↔
    32768 ≤ numUnacked pn la ∧ numUnacked pn la ≤ 8388607 := by
  constructor
  · intro h
    simp only [pktNumLen] at h
    by_cases c1 : numUnacked pn la ≤ 127
    · simp [if_pos c1] at h
    · rw [if_neg c1] at h
      by_cases c2 : numUnacked pn la ≤ 32767
      · simp [if_pos c2] at h
      · rw [if_neg c2] at h
        by_cases c3 : numUnacked pn la ≤ 8388607
        · exact ⟨by omega, c3⟩
        · simp [if_neg c3] at h
  · rintro ⟨h32k, h8m⟩
    have c1 : ¬ numUnacked pn la ≤ 127 := by omega
    have c2 : ¬ numUnacked pn la ≤ 32767 := by omega
    simp [pktNumLen, if_neg c1, if_neg c2, if_pos h8m]

theorem pktNumLen_eq_four_iff (pn la : Nat) :
    pktNumLen pn la = 4 ↔ 8388608 ≤ numUnacked pn la := by
  constructor
  · intro h
    simp only [pktNumLen] at h
    by_cases c1 : numUnacked pn la ≤ 127
    · simp [if_pos c1] at h
    · rw [if_neg c1] at h
      by_cases c2 : numUnacked pn la ≤ 32767
      · simp [if_pos c2] at h
      · rw [if_neg c2] at h
        by_cases c3 : numUnacked pn la ≤ 8388607
        · simp [if_pos c3] at h
        · omega
  · intro h
    have c1 : ¬ numUnacked pn la ≤ 127 := by omega
    have c2 : ¬ numUnacked pn la ≤ 32767 := by omega
    have c3 : ¬ numUnacked pn la ≤ 8388607 := by omega
    simp [pktNumLen, if_neg c1, if_neg c2, if_neg c3]

-- ---------------------------------------------------------------------------
-- RFC 9000 §17.1 coverage theorem
-- ---------------------------------------------------------------------------

/-- If pktNumLen selects 1 byte, numUnacked fits in the 1-byte half-window. -/
theorem pktNumLen_one_coverage (pn la : Nat) (h : pktNumLen pn la = 1) :
    numUnacked pn la ≤ 128 := by
  rw [pktNumLen_eq_one_iff] at h; omega

/-- If pktNumLen selects 2 bytes, numUnacked fits in the 2-byte half-window. -/
theorem pktNumLen_two_coverage (pn la : Nat) (h : pktNumLen pn la = 2) :
    numUnacked pn la ≤ 32768 := by
  have := (pktNumLen_eq_two_iff pn la).mp h; omega

/-- If pktNumLen selects 3 bytes, numUnacked fits in the 3-byte half-window. -/
theorem pktNumLen_three_coverage (pn la : Nat) (h : pktNumLen pn la = 3) :
    numUnacked pn la ≤ 8388608 := by
  have := (pktNumLen_eq_three_iff pn la).mp h; omega

/-- If pktNumLen selects 4 bytes AND the QUIC invariant holds (numUnacked < 2^31),
    then numUnacked fits in the 4-byte half-window (= 2^31 = 2147483648).
    The upper bound is not derivable from pktNumLen alone (our model returns 4
    for any numUnacked ≥ 8388608, including values ≥ 2^31). -/
theorem pktNumLen_four_coverage (pn la : Nat) (_ : pktNumLen pn la = 4)
    (hquic : numUnacked pn la ≤ 2147483647) :
    numUnacked pn la ≤ 2147483648 := by
  omega

-- ---------------------------------------------------------------------------
-- Thresholds: pktNumLen ≥ k when gap exceeds previous threshold
-- ---------------------------------------------------------------------------

theorem pktNumLen_ge_two (pn la : Nat) (h : 128 ≤ numUnacked pn la) :
    2 ≤ pktNumLen pn la := by
  have c1 : ¬ numUnacked pn la ≤ 127 := by omega
  simp only [pktNumLen, if_neg c1]
  by_cases c2 : numUnacked pn la ≤ 32767
  · simp [if_pos c2]
  · simp only [if_neg c2]
    by_cases c3 : numUnacked pn la ≤ 8388607
    · simp [if_pos c3]
    · simp [if_neg c3]

theorem pktNumLen_ge_three (pn la : Nat) (h : 32768 ≤ numUnacked pn la) :
    3 ≤ pktNumLen pn la := by
  have c1 : ¬ numUnacked pn la ≤ 127 := by omega
  have c2 : ¬ numUnacked pn la ≤ 32767 := by omega
  simp only [pktNumLen, if_neg c1, if_neg c2]
  by_cases c3 : numUnacked pn la ≤ 8388607
  · simp [if_pos c3]
  · simp [if_neg c3]

theorem pktNumLen_ge_four (pn la : Nat) (h : 8388608 ≤ numUnacked pn la) :
    4 ≤ pktNumLen pn la := by
  have c1 : ¬ numUnacked pn la ≤ 127 := by omega
  have c2 : ¬ numUnacked pn la ≤ 32767 := by omega
  have c3 : ¬ numUnacked pn la ≤ 8388607 := by omega
  simp [pktNumLen, if_neg c1, if_neg c2, if_neg c3]

-- ---------------------------------------------------------------------------
-- Monotonicity
-- ---------------------------------------------------------------------------

/-- `pktNumLen` is monotone: a larger gap requires at least as many bytes. -/
theorem pktNumLen_mono (pn la pn' la' : Nat)
    (h : numUnacked pn la ≤ numUnacked pn' la') :
    pktNumLen pn la ≤ pktNumLen pn' la' := by
  by_cases c1 : numUnacked pn la ≤ 127
  · have hk : pktNumLen pn la = 1 := (pktNumLen_eq_one_iff pn la).mpr c1
    simp [hk]; exact pktNumLen_ge_one pn' la'
  · by_cases c2 : numUnacked pn la ≤ 32767
    · have hk : pktNumLen pn la = 2 :=
        (pktNumLen_eq_two_iff pn la).mpr ⟨by omega, c2⟩
      simp [hk]
      exact pktNumLen_ge_two pn' la' (by omega)
    · by_cases c3 : numUnacked pn la ≤ 8388607
      · have hk : pktNumLen pn la = 3 :=
          (pktNumLen_eq_three_iff pn la).mpr ⟨by omega, c3⟩
        simp [hk]
        exact pktNumLen_ge_three pn' la' (by omega)
      · have hk : pktNumLen pn la = 4 :=
          (pktNumLen_eq_four_iff pn la).mpr (by omega)
        simp [hk]
        exact pktNumLen_ge_four pn' la' (by omega)

-- ---------------------------------------------------------------------------
-- encode_pkt_num validity
-- ---------------------------------------------------------------------------

/-- `pktNumLen` always produces a value in {1,2,3,4}, which is the valid
    domain where `encode_pkt_num` returns `Ok` (not `InvalidPacket`). -/
theorem pktNumLen_valid (pn la : Nat) :
    1 ≤ pktNumLen pn la ∧ pktNumLen pn la ≤ 4 :=
  ⟨pktNumLen_ge_one pn la, pktNumLen_le_four pn la⟩

-- ---------------------------------------------------------------------------
-- Worked examples (verified by `decide`)
-- ---------------------------------------------------------------------------

-- numUnacked = 11 (≤ 127) → 1 byte.
example : pktNumLen 10 0 = 1 := by decide
-- numUnacked = 127 (max for 1 byte) → 1 byte.
example : pktNumLen 126 0 = 1 := by decide
-- numUnacked = 128 (first case for 2 bytes) → 2 bytes.
example : pktNumLen 127 0 = 2 := by decide
-- numUnacked = 32767 (max for 2 bytes) → 2 bytes.
example : pktNumLen 32766 0 = 2 := by decide
-- numUnacked = 32768 (first case for 3 bytes) → 3 bytes.
example : pktNumLen 32767 0 = 3 := by decide
-- numUnacked = 8388607 (max for 3 bytes) → 3 bytes.
example : pktNumLen 8388606 0 = 3 := by decide
-- numUnacked = 8388608 (first case for 4 bytes) → 4 bytes.
example : pktNumLen 8388607 0 = 4 := by decide
-- pn < la: saturating sub → numUnacked = 1 → 1 byte.
example : pktNumLen 5 10 = 1 := by decide
-- pn == la: numUnacked = 1 → 1 byte.
example : pktNumLen 42 42 = 1 := by decide
-- Large gap within 2-byte range.
example : pktNumLen 1000 0 = 2 := by decide

end PacketNumLen
