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
-- FVSquad/SendBuf.lean
--
-- Formal specification and invariant proofs for the stream send buffer
-- (quiche/src/stream/send_buf.rs).
--
-- Abstract model
-- --------------
-- SendState tracks the byte-offset cursors and flow-control limit.
-- Byte contents, VecDeque structure, retransmission queue, and pos cursor
-- are all abstracted away.
--
-- Key invariants (see SendBuf struct in send_buf.rs):
--   I1: ackOff  ≤ emitOff              can't ack what wasn't sent
--   I2: emitOff ≤ off                  can't send what wasn't written
--   I3: emitOff ≤ maxData              flow-control safety (security-relevant)
--   I4: finOff = some f → f = off      FIN consistency
--
-- Operations modelled:
--   write n          append n bytes: off += n
--   emitN n          send up to n bytes: emitOff advances by
--                      min(n, off − emitOff, maxData − emitOff)
--   ackContiguous    advance ackOff by len (contiguous prefix only)
--   updateMaxData    raise flow-control limit: maxData := max(maxData, m)
--   setFin           set finOff := some off
--
-- Approximations (documented):
--   • Byte contents abstracted: only offsets/lengths.
--   • VecDeque<RangeBuf> → scalar off/emitOff; no fragmentation, pos cursor,
--     or retransmission queue (retransmit/reset/stop/shutdown not modelled).
--   • ack() in Rust uses RangeSet; here we model only the contiguous-prefix
--     case (ackOff = highest-contiguous-ack with start = 0).
--   • error/blocked_at/shutdown fields not modelled.
-- =============================================================================

-- =============================================================================
-- §1  Abstract state
-- =============================================================================

/-- Abstract model of the stream send buffer's cursor state.
    Corresponds to the scalar fields of `SendBuf` in send_buf.rs:
    `off`, `emit_off`, `acked.iter().next()` (contiguous prefix),
    `max_data`, and `fin_off`. -/
structure SendState where
  /-- Next write offset: total bytes appended (`off` in Rust). -/
  off     : Nat
  /-- Highest byte offset sent (`emit_off` in Rust).
      Invariant: emitOff ≤ off. -/
  emitOff : Nat
  /-- Highest contiguously acknowledged offset (`ack_off()` in Rust,
      the `end` of the first acked range when `start = 0`). -/
  ackOff  : Nat
  /-- Flow-control send limit (`max_data` in Rust).
      Invariant: emitOff ≤ maxData. -/
  maxData : Nat
  /-- Final stream size, once the FIN flag has been set (`fin_off` in Rust). -/
  finOff  : Option Nat

-- =============================================================================
-- §2  Well-formedness invariant
-- =============================================================================

/-- Well-formedness invariant for SendState.
    I1: ackOff  ≤ emitOff       can't ack what wasn't sent
    I2: emitOff ≤ off           can't send what wasn't written
    I3: emitOff ≤ maxData       flow-control safety — SECURITY-RELEVANT
    I4: finOff = some f → f=off FIN consistency -/
def SendState.Inv (s : SendState) : Prop :=
  s.ackOff ≤ s.emitOff ∧
  s.emitOff ≤ s.off ∧
  s.emitOff ≤ s.maxData ∧
  (∀ f, s.finOff = some f → f = s.off)

-- =============================================================================
-- §3  Operations
-- =============================================================================

/-- Append n bytes: advances the write cursor.
    Corresponds to `SendBuf::write` / `reserve_for_write` + `append_buf`. -/
def SendState.write (s : SendState) (n : Nat) : SendState :=
  { s with off := s.off + n }

/-- Available send capacity: bytes writable before exhausting the peer's window.
    Corresponds to `SendBuf::cap()`. -/
def SendState.cap (s : SendState) : Nat :=
  s.maxData - s.off  -- natural subtraction: 0 when off ≥ maxData

/-- Send up to n bytes: emitOff advances by min(n, off−emitOff, maxData−emitOff).
    Corresponds to the `emit_off` advancement in `SendBuf::emit`. -/
def SendState.emitN (s : SendState) (n : Nat) : SendState :=
  let avail := min (s.off - s.emitOff) (s.maxData - s.emitOff)
  { s with emitOff := s.emitOff + min n avail }

/-- Acknowledge a contiguous prefix of length len: advance ackOff.
    Models the contiguous-prefix case of `ack_off()` in send_buf.rs. -/
def SendState.ackContiguous (s : SendState) (len : Nat) : SendState :=
  { s with ackOff := s.ackOff + len }

/-- Raise the flow-control limit (monotone).
    Corresponds to `SendBuf::update_max_data`: `max_data = cmp::max(max_data, m)`. -/
def SendState.updateMaxData (s : SendState) (m : Nat) : SendState :=
  { s with maxData := max s.maxData m }

/-- Set the FIN flag: records the current write cursor as the final stream size.
    Corresponds to setting `fin_off = Some(off)` in `reserve_for_write`. -/
def SendState.setFin (s : SendState) : SendState :=
  { s with finOff := some s.off }

/-- Predicate: FIN has been set and all data has been written.
    Corresponds to `SendBuf::is_fin()`. -/
def SendState.isFin (s : SendState) : Bool :=
  match s.finOff with
  | some f => f == s.off
  | none   => false

-- =============================================================================
-- §4  Accessor simp lemmas
-- =============================================================================

@[simp] theorem write_off (s : SendState) (n : Nat) :
    (s.write n).off = s.off + n := rfl

@[simp] theorem write_emitOff (s : SendState) (n : Nat) :
    (s.write n).emitOff = s.emitOff := rfl

@[simp] theorem write_ackOff (s : SendState) (n : Nat) :
    (s.write n).ackOff = s.ackOff := rfl

@[simp] theorem write_maxData (s : SendState) (n : Nat) :
    (s.write n).maxData = s.maxData := rfl

@[simp] theorem write_finOff (s : SendState) (n : Nat) :
    (s.write n).finOff = s.finOff := rfl

/-- The emitOff formula after emitN — key simp lemma for all emitN proofs. -/
@[simp] theorem emitN_emitOff (s : SendState) (n : Nat) :
    (s.emitN n).emitOff =
      s.emitOff + min n (min (s.off - s.emitOff) (s.maxData - s.emitOff)) := rfl

@[simp] theorem emitN_ackOff (s : SendState) (n : Nat) :
    (s.emitN n).ackOff = s.ackOff := rfl

@[simp] theorem emitN_off (s : SendState) (n : Nat) :
    (s.emitN n).off = s.off := rfl

@[simp] theorem emitN_maxData (s : SendState) (n : Nat) :
    (s.emitN n).maxData = s.maxData := rfl

@[simp] theorem sb_emitN_finOff (s : SendState) (n : Nat) :
    (s.emitN n).finOff = s.finOff := rfl

@[simp] theorem updateMaxData_maxData (s : SendState) (m : Nat) :
    (s.updateMaxData m).maxData = max s.maxData m := rfl

@[simp] theorem updateMaxData_off (s : SendState) (m : Nat) :
    (s.updateMaxData m).off = s.off := rfl

@[simp] theorem updateMaxData_emitOff (s : SendState) (m : Nat) :
    (s.updateMaxData m).emitOff = s.emitOff := rfl

@[simp] theorem updateMaxData_ackOff (s : SendState) (m : Nat) :
    (s.updateMaxData m).ackOff = s.ackOff := rfl

@[simp] theorem ackContiguous_ackOff (s : SendState) (len : Nat) :
    (s.ackContiguous len).ackOff = s.ackOff + len := rfl

@[simp] theorem ackContiguous_emitOff (s : SendState) (len : Nat) :
    (s.ackContiguous len).emitOff = s.emitOff := rfl

@[simp] theorem ackContiguous_off (s : SendState) (len : Nat) :
    (s.ackContiguous len).off = s.off := rfl

-- =============================================================================
-- §5  Monotonicity theorems
-- =============================================================================

/-- write is monotone: off never decreases. -/
theorem write_off_mono (s : SendState) (n : Nat) :
    (s.write n).off ≥ s.off := by
  show s.off + n ≥ s.off; omega

/-- updateMaxData is monotone: the flow-control limit never decreases. -/
theorem updateMaxData_mono (s : SendState) (m : Nat) :
    (s.updateMaxData m).maxData ≥ s.maxData := by
  show max s.maxData m ≥ s.maxData; omega

/-- updateMaxData raises the limit to at least m. -/
theorem updateMaxData_ge (s : SendState) (m : Nat) :
    (s.updateMaxData m).maxData ≥ m := by
  show max s.maxData m ≥ m; omega

/-- emitN is monotone: emitOff never decreases. -/
theorem emitN_emitOff_mono (s : SendState) (n : Nat) :
    (s.emitN n).emitOff ≥ s.emitOff := by
  simp only [emitN_emitOff]; omega

/-- ackContiguous is monotone: ackOff never decreases. -/
theorem ackContiguous_mono (s : SendState) (len : Nat) :
    (s.ackContiguous len).ackOff ≥ s.ackOff := by
  show s.ackOff + len ≥ s.ackOff; omega

-- =============================================================================
-- §6  Flow-control safety theorems
-- =============================================================================

/-- emitN never exceeds the flow-control limit.
    Key security invariant: prevents the sender from exceeding the peer's
    MAX_DATA credit (RFC 9000 §4.1).
    Requires invariant I3: emitOff ≤ maxData. -/
theorem emitN_le_maxData (s : SendState) (n : Nat) (hinv : s.Inv) :
    (s.emitN n).emitOff ≤ s.maxData := by
  obtain ⟨_, _, hem, _⟩ := hinv
  simp only [emitN_emitOff]; omega

/-- emitN cannot send bytes that have not been written.
    Requires invariant I2: emitOff ≤ off. -/
theorem emitN_le_off (s : SendState) (n : Nat) (hinv : s.Inv) :
    (s.emitN n).emitOff ≤ s.off := by
  obtain ⟨_, heo, _, _⟩ := hinv
  simp only [emitN_emitOff]; omega

/-- Capacity is 0 when the write cursor has reached the flow-control limit. -/
theorem cap_zero_of_blocked (s : SendState) (h : s.off ≥ s.maxData) :
    s.cap = 0 := by simp only [SendState.cap]; omega

/-- Writing at most cap bytes keeps off within the flow-control limit.
    Requires `hoff : s.off ≤ s.maxData` (ensured by the flow-control invariant
    at the call site — in Rust, off ≤ max_data is maintained by construction). -/
theorem write_off_le_maxData_of_cap
    (s : SendState) (n : Nat) (hn : n ≤ s.cap) (hoff : s.off ≤ s.maxData) :
    (s.write n).off ≤ s.maxData := by
  unfold SendState.cap at hn
  simp only [write_off]
  omega

-- =============================================================================
-- §7  Invariant preservation
-- =============================================================================

/-- write preserves Inv when n ≤ cap and FIN has not been set.
    The cap bound ensures we don't overshoot the peer's flow-control window.
    The finOff = none precondition reflects that Rust's write() refuses
    to write past the final offset. -/
theorem write_preserves_inv
    (s : SendState) (n : Nat)
    (hinv : s.Inv) (hcap : n ≤ s.cap) (hfin : s.finOff = none) :
    (s.write n).Inv := by
  obtain ⟨hae, heo, hem, _⟩ := hinv
  -- All fields except off are unchanged by write
  refine ⟨hae, ?_, hem, ?_⟩
  · -- I2: emitOff ≤ off + n
    show s.emitOff ≤ s.off + n; omega
  · -- I4: finOff unchanged, so finOff = none → ∀ vacuously true
    intro f hf
    simp only [write_finOff] at hf
    rw [hfin] at hf
    simp at hf

/-- emitN preserves Inv. -/
theorem sb_emitN_preserves_inv (s : SendState) (n : Nat) (hinv : s.Inv) :
    (s.emitN n).Inv := by
  obtain ⟨hae, heo, hem, hfi⟩ := hinv
  refine ⟨?_, ?_, ?_, ?_⟩
  · -- I1: ackOff ≤ new emitOff (emitOff increases, ackOff unchanged)
    have hmono := emitN_emitOff_mono s n
    simp only [emitN_ackOff]; omega
  · exact emitN_le_off s n ⟨hae, heo, hem, hfi⟩
  · exact emitN_le_maxData s n ⟨hae, heo, hem, hfi⟩
  · intro f hf; simp only [sb_emitN_finOff] at hf; exact hfi f hf

/-- updateMaxData preserves Inv: raising the limit is always safe. -/
theorem updateMaxData_preserves_inv (s : SendState) (m : Nat) (hinv : s.Inv) :
    (s.updateMaxData m).Inv := by
  obtain ⟨hae, heo, hem, hfi⟩ := hinv
  refine ⟨hae, heo, ?_, ?_⟩
  · show s.emitOff ≤ max s.maxData m; omega
  · intro f hf
    simp only [SendState.updateMaxData] at hf
    exact hfi f hf

/-- ackContiguous preserves Inv when the new ack doesn't overshoot emitOff.
    Precondition: you cannot acknowledge bytes that haven't been sent. -/
theorem ackContiguous_preserves_inv
    (s : SendState) (len : Nat)
    (hinv : s.Inv) (hle : s.ackOff + len ≤ s.emitOff) :
    (s.ackContiguous len).Inv := by
  obtain ⟨_, heo, hem, hfi⟩ := hinv
  refine ⟨?_, heo, hem, ?_⟩
  · show s.ackOff + len ≤ s.emitOff; exact hle
  · intro f hf
    simp only [SendState.ackContiguous] at hf
    exact hfi f hf

/-- setFin preserves Inv: recording the final size doesn't alter cursors. -/
theorem setFin_preserves_inv (s : SendState) (hinv : s.Inv) :
    s.setFin.Inv := by
  obtain ⟨hae, heo, hem, _⟩ := hinv
  refine ⟨hae, heo, hem, ?_⟩
  intro f hf
  simp only [SendState.setFin, Option.some.injEq] at hf
  exact hf.symm

-- =============================================================================
-- §8  FIN consistency theorems
-- =============================================================================

/-- After setFin, isFin is true. -/
theorem setFin_isFin (s : SendState) :
    s.setFin.isFin = true := by
  simp only [SendState.setFin, SendState.isFin, beq_self_eq_true]

/-- isFin = true iff finOff = some off. -/
theorem isFin_iff_finOff (s : SendState) :
    s.isFin = true ↔ s.finOff = some s.off := by
  constructor
  · intro h
    unfold SendState.isFin at h
    cases hf : s.finOff with
    | none   => simp [hf] at h
    | some f =>
      rw [hf] at h
      simp only [beq_iff_eq] at h
      subst h; rfl
  · intro h
    unfold SendState.isFin
    rw [h]
    simp

/-- After setFin, finOff = some off. -/
theorem setFin_finOff_eq_off (s : SendState) :
    s.setFin.finOff = some s.off := rfl

/-- Writing after setFin makes isFin false (off advances past finOff).
    In the Rust implementation, write() is guarded to refuse writes past FIN;
    this theorem shows why: off would no longer equal finOff. -/
theorem write_after_setFin_isFin_false
    (s : SendState) (n : Nat) (hn : n > 0) :
    (s.setFin.write n).isFin = false := by
  show (s.off == s.off + n) = false
  cases h : (s.off == s.off + n) with
  | false => rfl
  | true  => simp only [beq_iff_eq] at h; omega

-- =============================================================================
-- §9  Capacity and write bounds
-- =============================================================================

/-- cap decreases when bytes are written. -/
theorem cap_after_write (s : SendState) (n : Nat) :
    (s.write n).cap = s.cap - n := by
  show s.maxData - (s.off + n) = s.maxData - s.off - n
  omega

/-- Writing exactly cap bytes exhausts the capacity. -/
theorem cap_exhausted_after_write_cap (s : SendState) :
    (s.write s.cap).cap = 0 := by
  show s.maxData - (s.off + (s.maxData - s.off)) = 0
  omega

/-- Writing 0 bytes is the identity. -/
theorem write_zero (s : SendState) : s.write 0 = s := by
  simp [SendState.write]

/-- Two sequential writes accumulate: off advances by n₁ + n₂. -/
theorem write_compose (s : SendState) (n₁ n₂ : Nat) :
    ((s.write n₁).write n₂).off = s.off + n₁ + n₂ := by
  show s.off + n₁ + n₂ = s.off + n₁ + n₂; rfl

/-- emitN of 0 is the identity on emitOff. -/
theorem emitN_zero_emitOff (s : SendState) :
    (s.emitN 0).emitOff = s.emitOff := by
  simp only [emitN_emitOff]; omega

-- =============================================================================
-- §10  Composing updateMaxData with write
-- =============================================================================

/-- After updateMaxData, the capacity is computed against the new limit. -/
theorem cap_after_updateMaxData (s : SendState) (m : Nat) :
    (s.updateMaxData m).cap = max s.maxData m - s.off := rfl

/-- updateMaxData strictly increases capacity when the new limit exceeds maxData
    and the stream is currently at-or-under maxData. -/
theorem cap_grows_after_updateMaxData
    (s : SendState) (m : Nat) (hm : m > s.maxData) (hlt : s.off ≤ s.maxData) :
    (s.updateMaxData m).cap > s.cap := by
  show max s.maxData m - s.off > s.maxData - s.off
  omega

/-- After updateMaxData(m) where m ≥ off + n, there is capacity to write n bytes.
    Key "unblocking" lemma: a peer MAX_DATA frame with value m allows writing
    up to m − off additional bytes. -/
theorem write_possible_after_updateMaxData
    (s : SendState) (m n : Nat) (hm : m ≥ s.off + n) :
    (s.updateMaxData m).cap ≥ n := by
  show max s.maxData m - s.off ≥ n
  omega

-- =============================================================================
-- §11  Test vectors (native_decide ground-truth checks)
-- =============================================================================

private def tv_init : SendState :=
  { off := 0, emitOff := 0, ackOff := 0, maxData := 1000, finOff := none }

-- Write 400 bytes, emit 250, ack 200.
private def tv_state : SendState :=
  ((tv_init.write 400).emitN 250).ackContiguous 200

example : tv_state.off     = 400  := by native_decide
example : tv_state.emitOff = 250  := by native_decide
example : tv_state.ackOff  = 200  := by native_decide
example : tv_state.maxData = 1000 := by native_decide
example : tv_state.cap     = 600  := by native_decide

-- Fully blocked: off = maxData.
private def tv_blocked : SendState :=
  { off := 1000, emitOff := 800, ackOff := 600, maxData := 1000, finOff := none }

example : tv_blocked.cap = 0 := by native_decide

-- After MAX_DATA update to 1500, cap = 500.
example : (tv_blocked.updateMaxData 1500).cap = 500 := by native_decide

-- FIN consistency.
example : (tv_init.write 42).setFin.isFin = true       := by native_decide
example : (tv_init.write 42).setFin.finOff = some 42   := by native_decide
example : ((tv_init.write 42).setFin.write 1).isFin = false := by native_decide

-- emitN bounded by maxData (flow-control safety check, bounded by maxData not off).
private def tv_fc : SendState :=
  { off := 500, emitOff := 0, ackOff := 0, maxData := 300, finOff := none }
example : (tv_fc.emitN 1000).emitOff = 300 := by native_decide
