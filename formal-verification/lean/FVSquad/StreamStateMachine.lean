-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of the QUIC stream state machine:
-- completion, writability, and their invariants.
--
-- Sources:
--   quiche/src/stream/mod.rs  (Stream::is_complete, is_writable)
--   quiche/src/stream/recv_buf.rs  (RecvBuf::is_fin)
--   quiche/src/stream/send_buf.rs  (SendBuf::is_fin, is_complete, is_shutdown)
--   RFC 9000 §3 (Stream States)
--
-- Lean 4 (v4.29.0+), no Mathlib dependency.
--
-- Approximations / abstractions:
--   - RecvBuf and SendBuf are modelled as records capturing only the fields
--     relevant to the state predicates (finOff, off, ackedEnd, shutdown).
--   - Flow-control capacity (`max_off`, `off_back`, `send_lowat`) is abstracted
--     away: `sendIsWritableFc` is an opaque boolean capturing the flow-control
--     part of `is_writable`.  Invariants about writability are proved under
--     the full conjunction `!shutdown ∧ !fin ∧ sendIsWritableFc`.
--   - `acked` range is simplified to `ackedEnd : Nat`; the Rust uses a
--     `RangeSet`; we model only the invariant `acked = 0..finOff`.
--   - u64 overflow is not modelled; offsets are Nat.
--   - `recv.ready()` (readable) is not modelled here; it is a separate concern.

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §1  State records
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Model of the receive-side state relevant to completion.
    `finOff`: the final offset, set once a FIN frame is received.
    `off`: the next byte offset the application has consumed up to. -/
structure StreamRecvState where
  finOff : Option Nat
  off    : Nat
  deriving Repr, DecidableEq

/-- Model of the send-side state relevant to completion and writability.
    `finOff`:   the final offset, set once the application calls stream_send
                with `fin = true`.
    `off`:      the offset of the last byte written by the application.
    `ackedEnd`: contiguous acked bytes from offset 0 (simplification of the
                full acked RangeSet).
    `shutdown`: true once shutdown() is called (RESET_STREAM). -/
structure StreamSendState where
  finOff   : Option Nat
  off      : Nat
  ackedEnd : Nat
  shutdown : Bool
  deriving Repr, DecidableEq

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §2  State predicates
--     Direct translation of the corresponding Rust methods.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- `RecvBuf::is_fin`:
    All expected bytes have been received and the application has consumed
    them up to the final offset.
    Mirrors: `self.fin_off == Some(self.off)` -/
def recvIsFin (r : StreamRecvState) : Bool :=
  r.finOff == some r.off

/-- `SendBuf::is_fin`:
    A FIN has been queued and the application has written all bytes up to
    the final offset.
    Mirrors: `self.fin_off == Some(self.off)` -/
def sendIsFin (s : StreamSendState) : Bool :=
  s.finOff == some s.off

/-- `SendBuf::is_complete`:
    All bytes up to the final offset have been acknowledged by the peer.
    Mirrors: `Some(fin_off) = self.fin_off ∧ self.acked == 0..fin_off`
    Simplified: we use `ackedEnd` as the contiguous acked prefix end. -/
def sendIsComplete (s : StreamSendState) : Bool :=
  match s.finOff with
  | none     => false
  | some fin => s.ackedEnd == fin

/-- `SendBuf::is_shutdown`:
    The send side was shut down (RESET_STREAM sent).
    Mirrors: `self.shutdown` -/
def sendIsShutdown (s : StreamSendState) : Bool :=
  s.shutdown

/-- `Stream::is_complete`:
    A stream may be garbage-collected when this predicate holds.
    Mirrors the three-way match in `Stream::is_complete`. -/
def streamIsComplete (bidi isLocal : Bool) (r : StreamRecvState) (s : StreamSendState) :
    Bool :=
  match bidi, isLocal with
  | true,  _     => recvIsFin r && sendIsComplete s
  | false, true  => sendIsComplete s
  | false, false => recvIsFin r

/-- `Stream::is_writable` (sans flow-control capacity):
    The stream can accept new application data.  `fc` represents the
    flow-control predicate `(off_back + send_lowat) < max_off` which we
    treat as opaque.
    Mirrors: `!shutdown && !is_fin() && fc` -/
def streamIsWritable (s : StreamSendState) (fc : Bool) : Bool :=
  !sendIsShutdown s && !sendIsFin s && fc

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §3  Well-formedness invariant for StreamSendState
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- A StreamSendState is well-formed when:
    (a) the application cannot write past the final offset: off ≤ finOff,
    (b) acknowledged bytes cannot exceed written bytes: ackedEnd ≤ off.
    Both invariants hold in the Rust `SendBuf` because writes are blocked
    once `finOff` is set, and acks only arrive for bytes already sent. -/
def WFStreamSend (s : StreamSendState) : Prop :=
  (∀ fin, s.finOff = some fin → s.off ≤ fin) ∧
  s.ackedEnd ≤ s.off

-- ── Key lemma: complete ⇒ fin under well-formedness ─────────────────────

/-- Under well-formedness, `sendIsComplete` implies `sendIsFin`.
    Proof: ackedEnd = fin (from complete), off ≤ fin (from wf.1),
    ackedEnd ≤ off (from wf.2), hence off = fin. -/
theorem send_complete_implies_fin (s : StreamSendState) (wf : WFStreamSend s) :
    sendIsComplete s = true → sendIsFin s = true := by
  intro hc
  simp [sendIsComplete] at hc
  cases hf : s.finOff with
  | none     => simp [hf] at hc
  | some fin =>
    simp [hf] at hc
    -- hc : s.ackedEnd = fin
    have hle : s.off ≤ fin := wf.1 fin hf
    have hage : s.ackedEnd ≤ s.off := wf.2
    -- therefore s.off = fin
    have heq : s.off = fin := by omega
    simp [sendIsFin, hf, heq]

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §4  Invariants proved
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- ── 3.1  Shutdown excludes writability ───────────────────────────────────

/-- A shutdown send side is never writable, regardless of flow-control. -/
theorem shutdown_not_writable (s : StreamSendState) (fc : Bool) :
    sendIsShutdown s = true → streamIsWritable s fc = false := by
  intro h
  simp [streamIsWritable, sendIsShutdown] at *
  simp [h]

-- ── 3.2  Fin excludes writability ────────────────────────────────────────

/-- A send side that has queued a FIN is never writable. -/
theorem fin_not_writable (s : StreamSendState) (fc : Bool) :
    sendIsFin s = true → streamIsWritable s fc = false := by
  intro h
  simp [streamIsWritable, sendIsFin] at *
  cases sendIsShutdown s <;> simp [h]

-- ── 3.3  Complete implies fin (send side) ────────────────────────────────

/-- If all bytes are acked up to finOff, then finOff is set. -/
theorem send_complete_has_fin (s : StreamSendState) :
    sendIsComplete s = true → s.finOff.isSome = true := by
  intro h
  simp [sendIsComplete] at h
  cases hf : s.finOff with
  | none     => simp [hf] at h
  | some _fin => simp

-- ── 3.4  Recv fin monotonicity model ────────────────────────────────────
-- Once recvIsFin holds for a given (finOff, off) pair, raising off past
-- finOff breaks it.  The invariant is that off increases monotonically and
-- never exceeds finOff once set.

/-- If `recvIsFin r` and we advance `off` beyond `finOff`, the predicate
    becomes false: the app cannot read past the final offset. -/
theorem recv_fin_past_final (r : StreamRecvState) (k : Nat) (hk : k > 0) :
    recvIsFin r = true →
    recvIsFin { r with off := r.off + k } = false := by
  intro h
  simp [recvIsFin] at *
  cases hf : r.finOff with
  | none     => simp [hf] at h
  | some fin =>
    simp [hf] at h
    simp [h]
    omega

-- ── 3.5  Bidi stream: complete decomposes into both halves ───────────────

/-- Bidirectional stream is complete iff both sides are complete. -/
theorem bidi_complete_iff (r : StreamRecvState) (s : StreamSendState) (b : Bool) :
    streamIsComplete true b r s = (recvIsFin r && sendIsComplete s) := by
  simp [streamIsComplete]

/-- Local unidirectional stream is complete iff send side is complete. -/
theorem local_uni_complete_iff (r : StreamRecvState) (s : StreamSendState) :
    streamIsComplete false true r s = sendIsComplete s := by
  simp [streamIsComplete]

/-- Remote unidirectional stream is complete iff recv side is done. -/
theorem remote_uni_complete_iff (r : StreamRecvState) (s : StreamSendState) :
    streamIsComplete false false r s = recvIsFin r := by
  simp [streamIsComplete]

-- ── 3.6  Complete bidi stream is not writable ────────────────────────────

/-- A complete bidirectional stream is not writable.
    Uses `WFStreamSend` which encodes that off ≤ finOff and ackedEnd ≤ off.
    From these: sendIsComplete ⇒ sendIsFin ⇒ not writable. -/
theorem bidi_complete_not_writable
    (r : StreamRecvState) (s : StreamSendState) (fc b : Bool)
    (wf : WFStreamSend s) :
    streamIsComplete true b r s = true →
    streamIsWritable s fc = false := by
  intro hcomp
  simp [streamIsComplete] at hcomp
  obtain ⟨_hrecv, hsc⟩ := hcomp
  have hfin : sendIsFin s = true := send_complete_implies_fin s wf hsc
  exact fin_not_writable s fc hfin

-- ── 3.7  Local-uni complete is not writable ─────────────────────────────

/-- A complete local-unidirectional stream is not writable. -/
theorem local_uni_complete_not_writable
    (r : StreamRecvState) (s : StreamSendState) (fc : Bool)
    (wf : WFStreamSend s) :
    streamIsComplete false true r s = true →
    streamIsWritable s fc = false := by
  intro hcomp
  simp [streamIsComplete] at hcomp
  have hfin : sendIsFin s = true := send_complete_implies_fin s wf hcomp
  exact fin_not_writable s fc hfin

-- ── 3.8  Not-complete when neither side is done ──────────────────────────

/-- If both recv and send sides are not done, no stream variant is complete. -/
theorem not_complete_when_neither_done
    (r : StreamRecvState) (s : StreamSendState) (bidi isLocal : Bool) :
    recvIsFin r = false → sendIsComplete s = false →
    streamIsComplete bidi isLocal r s = false := by
  intro hr hs
  cases bidi <;> cases isLocal <;> simp [streamIsComplete, hr, hs]

-- ── 3.9  Shutdown ⇒ not sendIsFin (independent) ─────────────────────────
-- The Rust implementation allows shutdown and fin to coexist (e.g., sending
-- RESET_STREAM after writing data).  Our model captures this: shutdown is
-- independent of finOff.

/-- Shutdown and fin are independently settable in the model
    (no algebraic constraint forces one to imply the other). -/
theorem shutdown_fin_independent :
    ∃ s : StreamSendState,
      sendIsShutdown s = true ∧ sendIsFin s = true := by
  exact ⟨{ finOff := some 0, off := 0, ackedEnd := 0, shutdown := true },
         by simp [sendIsShutdown, sendIsFin]⟩

theorem not_shutdown_fin_independent :
    ∃ s : StreamSendState,
      sendIsShutdown s = false ∧ sendIsFin s = false := by
  exact ⟨{ finOff := none, off := 0, ackedEnd := 0, shutdown := false },
         by simp [sendIsShutdown, sendIsFin]⟩

-- ── 3.10  Directionality is determined by stream ID ──────────────────────
-- Imported from StreamId.lean: isBidi and isLocal.
-- We reproduce the key fact here for self-containedness.

/-- Stream 0 is bidirectional (client-initiated). -/
example : (0 % 4 : Nat) < 2 := by decide

/-- Stream 3 is unidirectional (server-initiated). -/
example : ¬ ((3 % 4 : Nat) < 2) := by decide

/-- Stream directionality alternates: stream id and id+2 have opposite
    directionality. -/
theorem bidi_flip (id : Nat) :
    (id % 4 < 2) ↔ ¬ ((id + 2) % 4 < 2) := by omega

/-- Stream locality flips between id and id+1 (different initiator). -/
theorem local_flip (id : Nat) :
    (id % 2 = 0) ↔ ¬ ((id + 1) % 2 = 0) := by omega
