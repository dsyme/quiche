-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — T53: NewReno AIMD multi-cycle theorems
--
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- This module builds on FVSquad.NewReno (single-step model) to prove
-- properties about multi-step AIMD interactions:
--
--   §1  Iterated ACK helper and field-preservation lemmas
--   §2  ssthresh/cwnd relationship after congestion_event
--   §3  CA byte counter behaviour
--   §4  Multi-loss floor: FloorInv preserved by sequences of events + ACKs
--   §5  Slow-start multi-ACK growth
--   §6  Concrete examples
--
-- Approximations (inherited from NewReno.lean):
--   - `usize` modelled as `Nat` (unbounded); overflow not captured.
--   - `in_recovery` is a `Bool` abstracting the recovery epoch.
--   - HyStart++ CSS branch and app_limited are abstracted away.

import FVSquad.NewReno

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  Iterated ACK helper and field-preservation
-- ─────────────────────────────────────────────────────────────────────────────

/-- Apply `on_packet_acked` n times with the same pkt_size. -/
def NewReno.ack_n (r : NewReno) (pkt_size : Nat) : Nat → NewReno
  | 0     => r
  | n + 1 => (r.ack_n pkt_size n).on_packet_acked pkt_size

/-- `on_packet_acked` never changes `in_recovery` or `app_limited`. -/
private theorem on_acked_preserves_flags (r : NewReno) (pkt_size : Nat) :
    (r.on_packet_acked pkt_size).in_recovery = r.in_recovery ∧
    (r.on_packet_acked pkt_size).app_limited = r.app_limited := by
  unfold NewReno.on_packet_acked
  by_cases hg : r.in_recovery || r.app_limited
  · simp [hg]
  · simp only [hg, ite_false]
    by_cases hss : r.cwnd < r.ssthresh
    · simp [hss]
    · simp only [hss, ite_false]
      by_cases hge : r.bytes_acked_ca + pkt_size ≥ r.cwnd
      · simp [hge]
      · simp [hge]

/-- `on_packet_acked` never changes `ssthresh` or `mss`. -/
private theorem on_acked_preserves_ssthresh_mss (r : NewReno) (pkt_size : Nat) :
    (r.on_packet_acked pkt_size).ssthresh = r.ssthresh ∧
    (r.on_packet_acked pkt_size).mss = r.mss := by
  unfold NewReno.on_packet_acked
  by_cases hg : r.in_recovery || r.app_limited
  · simp [hg]
  · simp only [hg, ite_false]
    by_cases hss : r.cwnd < r.ssthresh
    · simp [hss]
    · simp only [hss, ite_false]
      by_cases hge : r.bytes_acked_ca + pkt_size ≥ r.cwnd
      · simp [hge]
      · simp [hge]

-- Convenient wrappers:
private theorem on_acked_recovery (r : NewReno) (pkt_size : Nat) :
    (r.on_packet_acked pkt_size).in_recovery = r.in_recovery :=
  (on_acked_preserves_flags r pkt_size).1

private theorem on_acked_app_limited (r : NewReno) (pkt_size : Nat) :
    (r.on_packet_acked pkt_size).app_limited = r.app_limited :=
  (on_acked_preserves_flags r pkt_size).2

private theorem on_acked_ssthresh (r : NewReno) (pkt_size : Nat) :
    (r.on_packet_acked pkt_size).ssthresh = r.ssthresh :=
  (on_acked_preserves_ssthresh_mss r pkt_size).1

private theorem on_acked_mss (r : NewReno) (pkt_size : Nat) :
    (r.on_packet_acked pkt_size).mss = r.mss :=
  (on_acked_preserves_ssthresh_mss r pkt_size).2

-- ack_n field preservation (induction using the single-step lemmas):

/-- ack_n preserves in_recovery. -/
theorem ack_n_recovery (r : NewReno) (pkt_size n : Nat) :
    (r.ack_n pkt_size n).in_recovery = r.in_recovery := by
  induction n with
  | zero => simp [NewReno.ack_n]
  | succ k ih => simp only [NewReno.ack_n, on_acked_recovery, ih]

/-- ack_n preserves app_limited. -/
theorem ack_n_app_limited (r : NewReno) (pkt_size n : Nat) :
    (r.ack_n pkt_size n).app_limited = r.app_limited := by
  induction n with
  | zero => simp [NewReno.ack_n]
  | succ k ih => simp only [NewReno.ack_n, on_acked_app_limited, ih]

/-- ack_n preserves ssthresh. -/
theorem ack_n_ssthresh (r : NewReno) (pkt_size n : Nat) :
    (r.ack_n pkt_size n).ssthresh = r.ssthresh := by
  induction n with
  | zero => simp [NewReno.ack_n]
  | succ k ih => simp only [NewReno.ack_n, on_acked_ssthresh, ih]

/-- ack_n preserves mss. -/
theorem ack_n_mss (r : NewReno) (pkt_size n : Nat) :
    (r.ack_n pkt_size n).mss = r.mss := by
  induction n with
  | zero => simp [NewReno.ack_n]
  | succ k ih => simp only [NewReno.ack_n, on_acked_mss, ih]

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  ssthresh/cwnd after congestion_event
-- ─────────────────────────────────────────────────────────────────────────────

/-- After a fresh congestion event, ssthresh = max(cwnd/2, mss*2). -/
theorem ssthresh_after_event (r : NewReno) (h : r.in_recovery = false) :
    (r.congestion_event).ssthresh = Nat.max (r.cwnd / 2) (r.mss * 2) := by
  unfold NewReno.congestion_event; simp [h, halve]

/-- After a fresh congestion event, cwnd = ssthresh. -/
theorem cwnd_eq_ssthresh_after_event (r : NewReno) (h : r.in_recovery = false) :
    (r.congestion_event).cwnd = (r.congestion_event).ssthresh := by
  unfold NewReno.congestion_event; simp [h, halve]

/-- After a fresh event (given FloorInv), new ssthresh ≤ original cwnd. -/
theorem ssthresh_le_cwnd_after_event (r : NewReno)
    (h : r.in_recovery = false) (hfloor : r.FloorInv) :
    (r.congestion_event).ssthresh ≤ r.cwnd := by
  unfold NewReno.FloorInv at hfloor
  rw [ssthresh_after_event r h]
  exact Nat.max_le.mpr ⟨Nat.div_le_self _ _, hfloor⟩

/-- bytes_acked_ca = cwnd/2 right after a fresh congestion event. -/
theorem bytes_acked_ca_after_event (r : NewReno) (h : r.in_recovery = false) :
    (r.congestion_event).bytes_acked_ca = (r.congestion_event).cwnd / 2 := by
  unfold NewReno.congestion_event; simp [h, halve]

/-- After a fresh event with mss ≥ 1, bytes_acked_ca < cwnd. -/
theorem bytes_acked_ca_lt_cwnd_after_event (r : NewReno)
    (h : r.in_recovery = false) (hm : r.mss ≥ 1) :
    (r.congestion_event).bytes_acked_ca < (r.congestion_event).cwnd := by
  unfold NewReno.congestion_event
  simp only [h, halve]
  -- Goal: max(cwnd/2, mss*2)/2 < max(cwnd/2, mss*2)
  have hx : Nat.max (r.cwnd / 2) (r.mss * 2) ≥ r.mss * 2 := Nat.le_max_right _ _
  have hpos : 0 < Nat.max (r.cwnd / 2) (r.mss * 2) := by omega
  exact Nat.div_lt_self hpos (by omega)

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  CA byte counter: single-ACK properties
-- ─────────────────────────────────────────────────────────────────────────────

/-- In CA (not recovery, not app_limited, not slow-start), if the byte counter
    doesn't yet reach cwnd, bytes_acked_ca grows by exactly pkt_size. -/
theorem ca_accumulates (r : NewReno) (pkt_size : Nat)
    (hca  : ¬ r.cwnd < r.ssthresh)
    (hrec : r.in_recovery = false)
    (happ : r.app_limited = false)
    (hlt  : ¬ r.bytes_acked_ca + pkt_size ≥ r.cwnd) :
    (r.on_packet_acked pkt_size).bytes_acked_ca =
      r.bytes_acked_ca + pkt_size := by
  unfold NewReno.on_packet_acked; simp [hrec, happ, hca, hlt]

/-- In CA, when the byte counter reaches cwnd, it resets to the overshoot. -/
theorem ca_reset_on_growth (r : NewReno) (pkt_size : Nat)
    (hca  : ¬ r.cwnd < r.ssthresh)
    (hrec : r.in_recovery = false)
    (happ : r.app_limited = false)
    (hge  : r.bytes_acked_ca + pkt_size ≥ r.cwnd) :
    (r.on_packet_acked pkt_size).bytes_acked_ca =
      r.bytes_acked_ca + pkt_size - r.cwnd := by
  unfold NewReno.on_packet_acked; simp [hrec, happ, hca, hge]

/-- After CA growth, bytes_acked_ca < new cwnd
    (given initial counter was < cwnd). -/
theorem ca_counter_lt_new_cwnd (r : NewReno) (pkt_size : Nat)
    (hca  : ¬ r.cwnd < r.ssthresh)
    (hrec : r.in_recovery = false)
    (happ : r.app_limited = false)
    (hge  : r.bytes_acked_ca + pkt_size ≥ r.cwnd)
    (hpre : r.bytes_acked_ca < r.cwnd)
    (hps  : pkt_size ≤ r.cwnd) :
    (r.on_packet_acked pkt_size).bytes_acked_ca <
      (r.on_packet_acked pkt_size).cwnd := by
  unfold NewReno.on_packet_acked
  simp [hrec, happ, hca, hge]
  -- goal: r.bytes_acked_ca + pkt_size - r.cwnd < r.cwnd + r.mss
  -- from hpre: bytes_acked_ca < cwnd, hps: pkt_size ≤ cwnd
  -- bytes_acked_ca + pkt_size - cwnd < pkt_size ≤ cwnd ≤ cwnd + mss
  omega

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Multi-loss floor: FloorInv preserved across sequences
-- ─────────────────────────────────────────────────────────────────────────────

/-- ack_n preserves FloorInv (induction on n). -/
theorem ack_n_preserves_floor (r : NewReno) (pkt_size n : Nat)
    (h : r.FloorInv) :
    (r.ack_n pkt_size n).FloorInv := by
  induction n with
  | zero => simpa [NewReno.ack_n]
  | succ k ih =>
    simp only [NewReno.ack_n]
    exact acked_preserves_floor_inv _ pkt_size ih

/-- ack_n never decreases cwnd. -/
theorem ack_n_cwnd_monotone (r : NewReno) (pkt_size n : Nat) :
    (r.ack_n pkt_size n).cwnd ≥ r.cwnd := by
  induction n with
  | zero => simp [NewReno.ack_n]
  | succ k ih =>
    simp only [NewReno.ack_n]
    exact Nat.le_trans ih (acked_cwnd_monotone _ _)

/-- Starting from FloorInv: event + n ACKs preserves FloorInv. -/
theorem event_then_acks_floor (r : NewReno) (pkt_size n : Nat)
    (hfloor : r.FloorInv) :
    (r.congestion_event.ack_n pkt_size n).FloorInv := by
  apply ack_n_preserves_floor
  by_cases hrec : r.in_recovery
  · simp [NewReno.congestion_event, hrec]; exact hfloor
  · exact congestion_event_establishes_floor r (by simpa using hrec)

/-- Starting from out-of-recovery: event + n ACKs establishes FloorInv. -/
theorem event_then_acks_floor' (r : NewReno) (pkt_size n : Nat)
    (h : r.in_recovery = false) :
    (r.congestion_event.ack_n pkt_size n).FloorInv :=
  ack_n_preserves_floor _ pkt_size n (congestion_event_establishes_floor r h)

-- ─────────────────────────────────────────────────────────────────────────────
-- §5  Slow-start multi-ACK growth
-- ─────────────────────────────────────────────────────────────────────────────

/-- In slow start (all n ACKs remain in slow start), cwnd grows by n*mss.
    Requires: not in recovery, not app_limited, mss > 0, and start + n*mss < ssthresh. -/
theorem ack_n_ss_cwnd (r : NewReno) (pkt_size n : Nat)
    (hrec : r.in_recovery = false)
    (happ : r.app_limited = false)
    (hmss : r.mss > 0)
    (hss  : r.cwnd + n * r.mss < r.ssthresh) :
    (r.ack_n pkt_size n).cwnd = r.cwnd + n * r.mss := by
  induction n with
  | zero => simp [NewReno.ack_n]
  | succ k ih =>
    -- hss : r.cwnd + (k+1) * r.mss < r.ssthresh
    have hmul : (k + 1) * r.mss = k * r.mss + r.mss := Nat.succ_mul k r.mss
    have hss_k : r.cwnd + k * r.mss < r.ssthresh := by omega
    simp only [NewReno.ack_n]
    have ihR : (r.ack_n pkt_size k).in_recovery = false := by
      rw [ack_n_recovery]; exact hrec
    have ihA : (r.ack_n pkt_size k).app_limited = false := by
      rw [ack_n_app_limited]; exact happ
    have ihSS : (r.ack_n pkt_size k).ssthresh = r.ssthresh := ack_n_ssthresh r pkt_size k
    have ihM : (r.ack_n pkt_size k).mss = r.mss := ack_n_mss r pkt_size k
    have ihV := ih hss_k
    have hss2 : (r.ack_n pkt_size k).cwnd < (r.ack_n pkt_size k).ssthresh := by
      rw [ihV, ihSS]; omega
    have key : ((r.ack_n pkt_size k).on_packet_acked pkt_size).cwnd =
        (r.ack_n pkt_size k).cwnd + (r.ack_n pkt_size k).mss :=
      slow_start_growth (r.ack_n pkt_size k) pkt_size hss2 ihR ihA
    rw [key, ihV, ihM]
    have hmul' : (k + 1) * r.mss = k * r.mss + r.mss := Nat.succ_mul k r.mss
    omega

-- ─────────────────────────────────────────────────────────────────────────────
-- §6  Concrete examples
-- ─────────────────────────────────────────────────────────────────────────────

private def r0 : NewReno :=
  { cwnd := 20, ssthresh := 100, bytes_acked_ca := 0,
    bytes_acked_sl := 0, mss := 1, in_recovery := false, app_limited := false }

-- ssthresh/cwnd after event: max(10,2)=10
example : (r0.congestion_event).cwnd = 10 := by native_decide
example : (r0.congestion_event).ssthresh = 10 := by native_decide
-- bytes_acked_ca = 5 = cwnd/2 after event
example : (r0.congestion_event).bytes_acked_ca = 5 := by native_decide
-- in_recovery set after event
example : (r0.congestion_event).in_recovery = true := by native_decide
-- ack_n 0 = identity
example : (r0.ack_n 1 0).cwnd = 20 := by native_decide
-- 5 SS ACKs: cwnd grows to 25
example : (r0.ack_n 1 5).cwnd = 25 := by native_decide
-- 79 SS ACKs: cwnd = 99 < ssthresh = 100
example : (r0.ack_n 1 79).cwnd = 99 := by native_decide
-- mss preserved
example : (r0.ack_n 1 50).mss = 1 := by native_decide
-- ssthresh preserved
example : (r0.ack_n 1 50).ssthresh = 100 := by native_decide
-- CA scenario
private def rCA : NewReno :=
  { cwnd := 10, ssthresh := 10, bytes_acked_ca := 5,
    bytes_acked_sl := 0, mss := 1, in_recovery := false, app_limited := false }
-- 5 ACKs trigger CA growth: cwnd goes to 11
example : (rCA.ack_n 1 5).cwnd = 11 := by native_decide
-- ssthresh unchanged
example : (rCA.ack_n 1 5).ssthresh = 10 := by native_decide
-- 11 more ACKs → grows to 12
example : (rCA.ack_n 1 16).cwnd = 12 := by native_decide
