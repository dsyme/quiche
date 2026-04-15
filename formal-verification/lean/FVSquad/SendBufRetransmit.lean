-- Copyright (C) 2024, Cloudflare, Inc.
-- All rights reserved.
--
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted provided that the following conditions are
-- met:
--
--     * Redistributions of source code must retain the above copyright notice,
--       this list of conditions and the following disclaimer.
--
--     * Redistributions in binary form must reproduce the above copyright
--       notice, this list of conditions and the following disclaimer in the
--       documentation and/or other materials provided with the distribution.
--
-- THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
-- IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
-- THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
-- PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
-- CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
-- EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
-- PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
-- PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
-- LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
-- NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
-- SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

-- =============================================================================
-- FVSquad/SendBufRetransmit.lean
--
-- Formal model and proofs for SendBuf::retransmit
-- (quiche/src/stream/send_buf.rs:366).
--
-- This file extends the abstract SendState model from FVSquad/SendBuf.lean
-- with the retransmit operation, which was explicitly excluded from that
-- module as a known approximation ("retransmit/reset/stop/shutdown not
-- modelled").
--
-- Abstract model of retransmit
-- ----------------------------
-- `retransmit(off, len)` marks bytes in the range [off, off+len) as
-- needing re-transmission.  Concretely, the Rust implementation walks
-- the RangeBuf deque and resets each buffer's `pos` cursor (which separates
-- already-emitted from pending bytes).  The cumulative scalar effect is:
--
--   • If off + len ≤ ackOff (range entirely acknowledged): no-op.
--   • Otherwise let effectiveOff := max(ackOff, off).
--     The emitOff cursor is lowered to min(emitOff, effectiveOff):
--     — off ≥ emitOff: range is beyond what was sent → emitOff unchanged.
--     — ackOff ≤ off < emitOff: bytes in [off, emitOff) put back to resend.
--     — off < ackOff: clamped to ackOff (cannot un-acknowledge bytes).
--
-- Approximations (documented):
--   • Byte contents abstracted: only offset cursors are modelled.
--   • The Rust `retransmit` adjusts individual RangeBuf.pos fields; here
--     we capture only the net effect on the scalar emitOff cursor.
--   • `data.is_empty()` early return is subsumed by the numeric guard.
--   • split_off operations affect the deque shape but not invariant scalars.
-- =============================================================================

import FVSquad.SendBuf

-- =============================================================================
-- §1  Retransmit operation
-- =============================================================================

/-- Mark bytes in [off, off+len) as requiring retransmission.
    In the abstract model this lowers `emitOff` to the start of the
    retransmit range, clamped below by `ackOff`.
    Corresponds to `SendBuf::retransmit` in send_buf.rs:366. -/
def SendState.retransmit (s : SendState) (off len : Nat) : SendState :=
  -- Early return: the range is entirely within the already-acknowledged prefix.
  if off + len ≤ s.ackOff then s
  else
    -- Bytes below ackOff are permanently committed; retransmit can only start
    -- at ackOff at the earliest.
    let effectiveOff := max s.ackOff off
    { s with emitOff := min s.emitOff effectiveOff }

-- =============================================================================
-- §2  Accessor simp lemmas
-- =============================================================================

@[simp] theorem retransmit_off (s : SendState) (off len : Nat) :
    (s.retransmit off len).off = s.off := by
  unfold SendState.retransmit
  by_cases h : off + len ≤ s.ackOff <;> simp [h]

@[simp] theorem retransmit_ackOff (s : SendState) (off len : Nat) :
    (s.retransmit off len).ackOff = s.ackOff := by
  unfold SendState.retransmit
  by_cases h : off + len ≤ s.ackOff <;> simp [h]

@[simp] theorem retransmit_maxData (s : SendState) (off len : Nat) :
    (s.retransmit off len).maxData = s.maxData := by
  unfold SendState.retransmit
  by_cases h : off + len ≤ s.ackOff <;> simp [h]

@[simp] theorem retransmit_finOff (s : SendState) (off len : Nat) :
    (s.retransmit off len).finOff = s.finOff := by
  unfold SendState.retransmit
  by_cases h : off + len ≤ s.ackOff <;> simp [h]

-- =============================================================================
-- §3  Core semantic lemmas
-- =============================================================================

/-- If the entire range is already acknowledged, retransmit is a no-op. -/
theorem retransmit_noop_acked (s : SendState) (off len : Nat)
    (h : off + len ≤ s.ackOff) :
    s.retransmit off len = s := by
  unfold SendState.retransmit; simp [h]

/-- The emitOff after retransmit equals min(emitOff, max(ackOff, off)),
    in the non-noop case. -/
theorem retransmit_emitOff_formula (s : SendState) (off len : Nat)
    (h : ¬ (off + len ≤ s.ackOff)) :
    (s.retransmit off len).emitOff = min s.emitOff (max s.ackOff off) := by
  unfold SendState.retransmit; simp [h]

/-- The emitOff after retransmit never exceeds the emitOff before.
    Retransmit can only lower (or preserve) the send cursor — the
    key monotonicity property of the retransmit operation. -/
theorem retransmit_emitOff_le (s : SendState) (off len : Nat) :
    (s.retransmit off len).emitOff ≤ s.emitOff := by
  unfold SendState.retransmit
  by_cases h : off + len ≤ s.ackOff <;> simp [h]; omega

/-- If the range starts at or beyond emitOff (nothing in this range was emitted),
    retransmit does not change emitOff. -/
theorem retransmit_noop_unemitted (s : SendState) (off len : Nat)
    (h : s.emitOff ≤ off) :
    (s.retransmit off len).emitOff = s.emitOff := by
  unfold SendState.retransmit
  by_cases hac : off + len ≤ s.ackOff
  · simp [hac]
  · simp [hac]; omega

/-- The emitOff after retransmit is at least ackOff.
    Retransmit cannot move the emit cursor below the acknowledged prefix. -/
theorem retransmit_emitOff_ge_ackOff (s : SendState) (off len : Nat)
    (hinv : s.Inv) :
    (s.retransmit off len).emitOff ≥ s.ackOff := by
  obtain ⟨hack, _, _, _⟩ := hinv
  unfold SendState.retransmit
  by_cases h : off + len ≤ s.ackOff
  · simp [h]; exact hack
  · simp [h]; omega

-- =============================================================================
-- §4  Invariant preservation
-- =============================================================================

/-- Retransmit preserves the SendState well-formedness invariant.
    This is the central theorem of this module: even after marking bytes
    for re-transmission, all four invariants (I1–I4) continue to hold.

    I1: ackOff ≤ emitOff  — emitOff is clamped to ≥ ackOff.
    I2: emitOff ≤ off     — emitOff can only decrease; off unchanged.
    I3: emitOff ≤ maxData — emitOff decreases; maxData unchanged.
    I4: finOff consistency — finOff is not touched. -/
theorem retransmit_inv (s : SendState) (off len : Nat) (hinv : s.Inv) :
    (s.retransmit off len).Inv := by
  obtain ⟨hack, heo, hem, hfin⟩ := hinv
  unfold SendState.retransmit SendState.Inv
  by_cases h : off + len ≤ s.ackOff
  · simp [h]; exact ⟨hack, heo, hem, hfin⟩
  · simp [h]; exact ⟨by omega, by omega, by omega, hfin⟩

-- =============================================================================
-- §5  Effect theorems
-- =============================================================================

/-- The total bytes written (off) is unchanged by retransmit. -/
theorem retransmit_off_unchanged (s : SendState) (off len : Nat) :
    (s.retransmit off len).off = s.off :=
  retransmit_off s off len

/-- The acknowledged prefix (ackOff) is unchanged by retransmit. -/
theorem retransmit_ackOff_unchanged (s : SendState) (off len : Nat) :
    (s.retransmit off len).ackOff = s.ackOff :=
  retransmit_ackOff s off len

/-- The flow-control limit (maxData) is unchanged by retransmit. -/
theorem retransmit_maxData_unchanged (s : SendState) (off len : Nat) :
    (s.retransmit off len).maxData = s.maxData :=
  retransmit_maxData s off len

/-- The FIN offset (finOff) is unchanged by retransmit. -/
theorem retransmit_finOff_unchanged (s : SendState) (off len : Nat) :
    (s.retransmit off len).finOff = s.finOff :=
  retransmit_finOff s off len

-- =============================================================================
-- §6  Send-backlog monotonicity
-- =============================================================================

/-- After retransmit, ackOff ≤ emitOff still holds (I1 is preserved). -/
theorem retransmit_pending_nonneg (s : SendState) (off len : Nat)
    (hinv : s.Inv) :
    (s.retransmit off len).ackOff ≤ (s.retransmit off len).emitOff :=
  (retransmit_inv s off len hinv).1

/-- After retransmit, the bytes-pending-send (off − emitOff) is at least
    as large as before.  Retransmit increases (or preserves) the send backlog.
    This is a direct consequence of emitOff decreasing while off is unchanged. -/
theorem retransmit_send_backlog_le (s : SendState) (off len : Nat) :
    s.off - s.emitOff ≤
    (s.retransmit off len).off - (s.retransmit off len).emitOff := by
  have hle := retransmit_emitOff_le s off len
  simp only [retransmit_off]; omega

/-- Retransmit is anti-monotone on emitOff: the send cursor never advances. -/
theorem retransmit_emitOff_anti_mono (s : SendState) (off len : Nat) :
    (s.retransmit off len).emitOff ≤ s.emitOff :=
  retransmit_emitOff_le s off len

-- =============================================================================
-- §7  Idempotence
-- =============================================================================

/-- Retransmit is idempotent: applying it twice with the same range produces
    the same state as applying it once.  Marking bytes as "needs resend" is
    a set-like operation — doing it twice has no extra effect. -/
theorem retransmit_idempotent (s : SendState) (off len : Nat) :
    (s.retransmit off len).retransmit off len = s.retransmit off len := by
  -- Key algebraic fact used in the non-noop branch:
  -- min (min e m) m = min e m, because min e m ≤ m by Nat.min_le_right.
  have hmin : ∀ (e m : Nat),
      min (min e m) m = min e m :=
    fun e m => Nat.min_eq_left (Nat.min_le_right e m)
  unfold SendState.retransmit
  by_cases h : off + len ≤ s.ackOff
  · -- Noop branch: first retransmit is identity, so second is also identity.
    simp [h]
  · -- Active branch: first retransmit sets emitOff' := min emitOff (max ackOff off).
    -- Second retransmit: ackOff unchanged, so same guard (¬h).
    -- new emitOff := min emitOff' (max ackOff off) = emitOff' by hmin.
    simp only [h, ite_false]
    -- Goal: { s with emitOff := min (min s.emitOff (max s.ackOff off)) (max s.ackOff off) }
    --     = { s with emitOff := min s.emitOff (max s.ackOff off) }
    congr 1
    exact hmin s.emitOff (max s.ackOff off)

-- =============================================================================
-- §8  Interaction with emitN
-- =============================================================================

/-- After retransmit, a subsequent emitN can resend up to the write cursor. -/
theorem retransmit_emitN_bounded (s : SendState) (off len n : Nat)
    (hinv : s.Inv) :
    ((s.retransmit off len).emitN n).emitOff ≤ s.off := by
  have hinv' := retransmit_inv s off len hinv
  calc ((s.retransmit off len).emitN n).emitOff
      ≤ (s.retransmit off len).off := emitN_le_off _ n hinv'
    _ = s.off                       := retransmit_off s off len

/-- After retransmit then emitN, the flow-control limit still holds. -/
theorem retransmit_emitN_le_maxData (s : SendState) (off len n : Nat)
    (hinv : s.Inv) :
    ((s.retransmit off len).emitN n).emitOff ≤ s.maxData := by
  have hinv' := retransmit_inv s off len hinv
  calc ((s.retransmit off len).emitN n).emitOff
      ≤ (s.retransmit off len).maxData := emitN_le_maxData _ n hinv'
    _ = s.maxData                       := retransmit_maxData s off len

/-- After retransmit then emitN, the full invariant holds. -/
theorem retransmit_emitN_inv (s : SendState) (off len n : Nat)
    (hinv : s.Inv) :
    ((s.retransmit off len).emitN n).Inv :=
  sb_emitN_preserves_inv (s.retransmit off len) n (retransmit_inv s off len hinv)

-- =============================================================================
-- §9  Concrete examples (verified by decide)
-- Fields are checked individually since SendState lacks DecidableEq.
-- =============================================================================

-- State: off=100, emitOff=80, ackOff=40, maxData=200, finOff=none

/-- Example 1: range entirely beyond emitOff — emitOff is unchanged. -/
example : ((⟨100, 80, 40, 200, none⟩ : SendState).retransmit 90 10).emitOff = 80 :=
  by decide

/-- Example 2: range overlaps the emitted region — emitOff is lowered to off. -/
example : ((⟨100, 80, 40, 200, none⟩ : SendState).retransmit 60 10).emitOff = 60 :=
  by decide

/-- Example 3: range starts before ackOff — emitOff is clamped to ackOff. -/
example : ((⟨100, 80, 40, 200, none⟩ : SendState).retransmit 20 30).emitOff = 40 :=
  by decide

/-- Example 4: range fully acked — no-op; emitOff is unchanged. -/
example : ((⟨100, 80, 40, 200, none⟩ : SendState).retransmit 10 20).emitOff = 80 :=
  by decide

/-- Example 5: retransmit the entire emitted range — emitOff returns to ackOff. -/
example : ((⟨100, 80, 40, 200, none⟩ : SendState).retransmit 40 50).emitOff = 40 :=
  by decide

/-- Example 6: off is always preserved by retransmit. -/
example : ((⟨100, 80, 40, 200, none⟩ : SendState).retransmit 60 10).off = 100 :=
  by decide

/-- Example 7: FIN offset is preserved by retransmit. -/
example :
    ((⟨100, 80, 40, 200, some 100⟩ : SendState).retransmit 60 10).finOff = some 100 :=
  by decide

/-- Example 8: retransmit is idempotent (checking emitOff). -/
example :
    let s : SendState := ⟨100, 80, 40, 200, none⟩
    ((s.retransmit 60 10).retransmit 60 10).emitOff = (s.retransmit 60 10).emitOff :=
  by decide

/-- Example 9: emitOff is anti-monotone across two successive retransmits. -/
example :
    let s : SendState := ⟨100, 80, 40, 200, none⟩
    ((s.retransmit 70 5).retransmit 60 5).emitOff ≤ (s.retransmit 70 5).emitOff :=
  by decide

/-- Example 10: send backlog strictly increases after retransmitting emitted bytes. -/
example :
    let s : SendState := ⟨100, 80, 40, 200, none⟩
    let s' := s.retransmit 60 10
    s.off - s.emitOff < s'.off - s'.emitOff :=
  by decide
