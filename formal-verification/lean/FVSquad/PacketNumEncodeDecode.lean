-- Copyright (C) 2025, Cloudflare, Inc.
-- All rights reserved.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/PacketNumEncodeDecode.lean
--
-- Composition theorem T24: encode_pkt_num → decode_pkt_num = identity.
-- Shows that pktNumLen always selects a precision sufficient for decodePktNum
-- to recover the original packet number.
--
-- 🔬 Lean Squad — automated formal verification.
--
-- MODEL SCOPE:
--   • Imports PacketNumLen.lean (sender side) and PacketNumDecode.lean (receiver).
--   • encode_pkt_num buffer write is abstracted: only the low bits
--     (pn % pnWin(pn_len)) are modelled (the actual wire encoding).
--   • decodePktNum is the arithmetic model from PacketNumDecode.lean.
--   • The receiver is assumed to have largest_pn = largest_acked (= la).
--
-- APPROXIMATIONS:
--   • Only the encode–decode arithmetic is verified; no buffer I/O.
--   • The QUIC "receiver uses sender's largest_acked as its largest_pn"
--     assumption is encoded as la appearing in both pktNumLen and decodePktNum.
--   • pn < 2^62 is required by decodePktNum's overflow guard (QUIC pn cap).
--   • For the 4-byte case, numUnacked ≤ 2^31 is an explicit precondition;
--     this corresponds to the QUIC constraint noted in PacketNumLen.lean.

import FVSquad.PacketNumDecode
import FVSquad.PacketNumLen

open PacketNumLen

namespace PacketNumEncodeDecode

-- ---------------------------------------------------------------------------
-- Concrete window values (proved by decide)
-- ---------------------------------------------------------------------------

private theorem pnWin_one   : pnWin 1 = 256         := by decide
private theorem pnWin_two   : pnWin 2 = 65536        := by decide
private theorem pnWin_three : pnWin 3 = 16777216     := by decide
private theorem pnWin_four  : pnWin 4 = 4294967296   := by decide

private theorem shift62 : (1 : Nat) <<< 62 = 4611686018427387904 := by decide

-- ---------------------------------------------------------------------------
-- Bridge lemma: pktNumLen window ≥ 2 × numUnacked
-- ---------------------------------------------------------------------------

/-- The window selected by pktNumLen is at least twice the unacknowledged
    count.  The 4-byte case requires numUnacked ≤ 2^31 (hfour), matching
    the QUIC constraint noted in PacketNumLen.lean. -/
theorem pktNumLen_window_sufficient (pn la : Nat)
    (hfour : numUnacked pn la ≤ 2147483648) :
    2 * numUnacked pn la ≤ pnWin (pktNumLen pn la) := by
  by_cases c1 : numUnacked pn la ≤ 127
  · have hk : pktNumLen pn la = 1 := by simp [pktNumLen, if_pos c1]
    rw [hk, pnWin_one]; omega
  · by_cases c2 : numUnacked pn la ≤ 32767
    · have hk : pktNumLen pn la = 2 := by
        simp [pktNumLen, if_neg c1, if_pos c2]
      rw [hk, pnWin_two]; omega
    · by_cases c3 : numUnacked pn la ≤ 8388607
      · have hk : pktNumLen pn la = 3 := by
          simp [pktNumLen, if_neg c1, if_neg c2, if_pos c3]
        rw [hk, pnWin_three]; omega
      · have hk : pktNumLen pn la = 4 := by
          simp [pktNumLen, if_neg c1, if_neg c2, if_neg c3]
        rw [hk, pnWin_four]; omega

/-- pnHwin(pktNumLen pn la) ≥ numUnacked pn la. -/
theorem pnHwin_ge_numUnacked (pn la : Nat)
    (hfour : numUnacked pn la ≤ 2147483648) :
    numUnacked pn la ≤ pnHwin (pktNumLen pn la) := by
  have hw := pktNumLen_window_sufficient pn la hfour
  unfold pnHwin
  omega

/-- pnWin(pktNumLen pn la) ≤ 2^62 for all inputs (pktNumLen ≤ 4). -/
theorem pktNumLen_win_le_overflow (pn la : Nat) :
    pnWin (pktNumLen pn la) ≤ (1 : Nat) <<< 62 := by
  by_cases c1 : numUnacked pn la ≤ 127
  · have hk : pktNumLen pn la = 1 := by simp [pktNumLen, if_pos c1]
    rw [hk, pnWin_one, shift62]; omega
  · by_cases c2 : numUnacked pn la ≤ 32767
    · have hk : pktNumLen pn la = 2 := by
        simp [pktNumLen, if_neg c1, if_pos c2]
      rw [hk, pnWin_two, shift62]; omega
    · by_cases c3 : numUnacked pn la ≤ 8388607
      · have hk : pktNumLen pn la = 3 := by
          simp [pktNumLen, if_neg c1, if_neg c2, if_pos c3]
        rw [hk, pnWin_three, shift62]; omega
      · have hk : pktNumLen pn la = 4 := by
          simp [pktNumLen, if_neg c1, if_neg c2, if_neg c3]
        rw [hk, pnWin_four, shift62]; omega

-- ---------------------------------------------------------------------------
-- Proximity conditions
-- ---------------------------------------------------------------------------

/-- pnHwin is always at least 128 (the minimum is pnWin 1 / 2 = 128). -/
private theorem pnHwin_ge_two (pn la : Nat) : 2 ≤ pnHwin (pktNumLen pn la) := by
  have hw1 : pnHwin 1 = 128        := by decide
  have hw2 : pnHwin 2 = 32768      := by decide
  have hw3 : pnHwin 3 = 8388608    := by decide
  have hw4 : pnHwin 4 = 2147483648 := by decide
  by_cases c1 : numUnacked pn la ≤ 127
  · have hk : pktNumLen pn la = 1 := by simp [pktNumLen, if_pos c1]
    rw [hk, hw1]; omega
  · by_cases c2 : numUnacked pn la ≤ 32767
    · have hk : pktNumLen pn la = 2 := by simp [pktNumLen, if_neg c1, if_pos c2]
      rw [hk, hw2]; omega
    · by_cases c3 : numUnacked pn la ≤ 8388607
      · have hk : pktNumLen pn la = 3 := by
            simp [pktNumLen, if_neg c1, if_neg c2, if_pos c3]
        rw [hk, hw3]; omega
      · have hk : pktNumLen pn la = 4 := by
            simp [pktNumLen, if_neg c1, if_neg c2, if_neg c3]
        rw [hk, hw4]; omega

/-- Upper proximity bound: pn ≤ la + 1 + pnHwin(pktNumLen pn la).
    Required by decode_pktnum_correct as hprox. -/
theorem pn_le_la_plus_hwin (pn la : Nat)
    (hge   : la ≤ pn)
    (hfour : numUnacked pn la ≤ 2147483648) :
    pn ≤ la + 1 + pnHwin (pktNumLen pn la) := by
  have hh := pnHwin_ge_numUnacked pn la hfour
  have hnu : numUnacked pn la = pn - la + 1 := rfl
  have h1 : pn - la + 1 ≤ pnHwin (pktNumLen pn la) := hnu ▸ hh
  -- Explicitly bind pn = la + (pn - la) so omega sees the connection
  have h3 : la + (pn - la) = pn := Nat.add_sub_cancel' hge
  omega

/-- Lower proximity bound: la + 1 < pn + pnHwin(pktNumLen pn la).
    Required by decode_pktnum_correct as hprox2. -/
theorem la_plus1_lt_pn_plus_hwin (pn la : Nat)
    (hge   : la ≤ pn)
    (hfour : numUnacked pn la ≤ 2147483648) :
    la + 1 < pn + pnHwin (pktNumLen pn la) := by
  have hh := pnHwin_ge_numUnacked pn la hfour
  have hnu : numUnacked pn la = pn - la + 1 := rfl
  have h1 : pn - la + 1 ≤ pnHwin (pktNumLen pn la) := hnu ▸ hh
  -- pnHwin ≥ 128 ensures the bound even when pn = la (gap = 0)
  have h2 := pnHwin_ge_two pn la
  have h3 : la + (pn - la) = pn := Nat.add_sub_cancel' hge
  omega

-- ---------------------------------------------------------------------------
-- Main composition theorem (T24)
-- ---------------------------------------------------------------------------

/-- **Composition theorem (T24)**: QUIC packet number encode–decode round-trip.

    The sender computes `pn_len = pktNumLen pn la` and transmits only the low
    `pn_len * 8` bits: `truncated_pn = pn % pnWin pn_len`.  The receiver, whose
    largest received packet number equals `la`, recovers the full `pn` via
    `decodePktNum la truncated_pn pn_len = pn`.

    This bridges PacketNumLen.lean (sender) and PacketNumDecode.lean (receiver):
    `pktNumLen` always selects a window width satisfying the proximity
    preconditions of `decode_pktnum_correct`.

    Preconditions:
    - `hge`   : `la ≤ pn`  — sender encodes future (or current) packets only
    - `hpn`   : `pn < 2^62` — QUIC packet number cap (matches decodePktNum guard)
    - `hfour` : `numUnacked pn la ≤ 2^31` — needed for 4-byte encoding case;
                subsumes the QUIC constraint that PN space ≤ 2^31 in flight -/
theorem encode_decode_pktnum (pn la : Nat)
    (hge   : la ≤ pn)
    (hpn   : pn < (1 : Nat) <<< 62)
    (hfour : numUnacked pn la ≤ 2147483648) :
    decodePktNum la (pn % pnWin (pktNumLen pn la)) (pktNumLen pn la) = pn :=
  decode_pktnum_correct la (pn % pnWin (pktNumLen pn la)) (pktNumLen pn la) pn
    (pktNumLen_ge_one pn la)
    (Nat.mod_lt _ (pnWin_pos _))
    rfl
    (pn_le_la_plus_hwin pn la hge hfour)
    (la_plus1_lt_pn_plus_hwin pn la hge hfour)
    hpn
    (pktNumLen_win_le_overflow pn la)

-- ---------------------------------------------------------------------------
-- Corollaries
-- ---------------------------------------------------------------------------

/-- When pn = la (no unacknowledged packets), pktNumLen = 1 and
    the 1-byte encoding round-trips. -/
theorem encode_decode_same (la : Nat) (hla : la < (1 : Nat) <<< 62) :
    decodePktNum la (la % pnWin (pktNumLen la la)) (pktNumLen la la) = la :=
  encode_decode_pktnum la la (Nat.le_refl _) hla (by simp [numUnacked])

/-- pktNumLen la la = 1: encoding a packet equal to largest_acked uses 1 byte. -/
theorem pktNumLen_self_eq_one (la : Nat) : pktNumLen la la = 1 :=
  pktNumLen_self la

/-- For pn = la, the truncated packet number is la % 256. -/
theorem encode_decode_same_1byte (la : Nat) (hla : la < (1 : Nat) <<< 62) :
    decodePktNum la (la % 256) 1 = la := by
  have hk : pktNumLen la la = 1 := pktNumLen_self la
  have hw : pnWin 1 = 256 := pnWin_one
  have := encode_decode_same la hla
  rwa [hk, hw] at this

/-- For pn > la by at most 127, pktNumLen = 1 and encoding round-trips. -/
theorem encode_decode_one_byte (pn la : Nat) (hge : la ≤ pn)
    (hclose : pn - la ≤ 126) (hpn : pn < (1 : Nat) <<< 62) :
    decodePktNum la (pn % 256) 1 = pn := by
  have hnu : numUnacked pn la ≤ 127 := by unfold numUnacked; omega
  have hk : pktNumLen pn la = 1 := by simp [pktNumLen, if_pos hnu]
  have hw : pnWin 1 = 256 := pnWin_one
  have h4 : numUnacked pn la ≤ 2147483648 := by unfold numUnacked; omega
  have := encode_decode_pktnum pn la hge hpn h4
  rwa [hk, hw] at this

end PacketNumEncodeDecode

-- ---------------------------------------------------------------------------
-- Examples (native_decide)
-- ---------------------------------------------------------------------------

section PacketNumExamples

open PacketNumLen PacketNumEncodeDecode

-- pktNumLen boundary examples
example : pktNumLen 10 0   = 1 := by decide
example : pktNumLen 127 0  = 2 := by decide   -- numUnacked=128, needs 2 bytes
example : pktNumLen 128 1  = 2 := by decide   -- numUnacked=128, needs 2 bytes
example : pktNumLen 32767 0 = 3 := by decide  -- numUnacked=32768, needs 3 bytes
example : pktNumLen 8388607 0 = 4 := by decide -- numUnacked=8388608, needs 4 bytes

-- Window sizes
example : pnWin 1 = 256       := by decide
example : pnWin 2 = 65536     := by decide
example : pnWin 3 = 16777216  := by decide
example : pnWin 4 = 4294967296 := by decide

-- Half-window sizes
example : pnHwin 1 = 128      := by decide
example : pnHwin 2 = 32768    := by decide
example : pnHwin 3 = 8388608  := by decide
example : pnHwin 4 = 2147483648 := by decide

-- Roundtrip at each encoding length
-- 1-byte: pn ≈ la (numUnacked ≤ 127)
example : decodePktNum 100 (125 % pnWin (pktNumLen 125 100)) (pktNumLen 125 100) = 125 := by
  native_decide
example : decodePktNum 0 (63 % pnWin (pktNumLen 63 0)) (pktNumLen 63 0) = 63 := by
  native_decide

-- 2-byte: numUnacked 128..32767
example : decodePktNum 0 (200 % pnWin (pktNumLen 200 0)) (pktNumLen 200 0) = 200 := by
  native_decide
example : decodePktNum 1000 (32000 % pnWin (pktNumLen 32000 1000))
    (pktNumLen 32000 1000) = 32000 := by
  native_decide

-- 3-byte: numUnacked 32768..8388607
example : decodePktNum 0 (40000 % pnWin (pktNumLen 40000 0)) (pktNumLen 40000 0) = 40000 := by
  native_decide
example : decodePktNum 1000000 (4000000 % pnWin (pktNumLen 4000000 1000000))
    (pktNumLen 4000000 1000000) = 4000000 := by
  native_decide

-- 4-byte: numUnacked 8388608..2147483648
example : decodePktNum 0 (10000000 % pnWin (pktNumLen 10000000 0))
    (pktNumLen 10000000 0) = 10000000 := by
  native_decide
example : decodePktNum 0 (1000000000 % pnWin (pktNumLen 1000000000 0))
    (pktNumLen 1000000000 0) = 1000000000 := by
  native_decide

-- Corollary examples
example : pktNumLen 50 50 = 1   := by decide
example : pktNumLen 500 500 = 1 := by decide

end PacketNumExamples
