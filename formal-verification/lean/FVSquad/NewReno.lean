-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of the NewReno congestion controller
-- in `quiche/src/recovery/congestion/reno.rs`.
--
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- The module covers:
--   §1  Model types and invariant
--   §2  Pure functional operations (on_packet_acked, congestion_event)
--   §3  Key theorems:
--         - cwnd_floor_new_event: after a fresh congestion_event, cwnd ≥ mss*2
--         - single_halving: congestion_event is no-op when in_recovery
--         - congestion_event_sets_recovery: in_recovery = true after new event
--         - congestion_event_idempotent: two consecutive events = one
--         - slow_start_growth: slow start raises cwnd by exactly mss per ACK
--         - ca_ack_no_growth: CA counter below threshold → cwnd unchanged
--         - ca_ack_growth: CA counter reaching cwnd → cwnd += mss
--         - recovery_no_growth: in recovery → on_packet_acked is a no-op
--         - app_limited_no_growth: app_limited → on_packet_acked is a no-op
--         - acked_cwnd_monotone: on_packet_acked never decreases cwnd
--         - acked_preserves_floor_inv: FloorInv preserved by on_packet_acked
--         - congestion_event_cwnd_le_of_floor: under FloorInv, event ≤ cwnd
--
-- Approximations / abstractions:
--   - `usize` is modelled as `Nat` (unbounded); integer overflow not captured.
--   - `Instant` is abstracted to `Bool` (`in_recovery`): whether the current
--     epoch is a recovery epoch.  `in_congestion_recovery(sent_time)` is
--     replaced by the `in_recovery` field.
--   - `f64 * 0.5` (LOSS_REDUCTION_FACTOR) is modelled as Nat floor-division
--     by 2, matching the `as usize` cast in the Rust source.
--   - HyStart++ (CSS branch) is abstracted away; only the plain slow-start
--     branch (`cwnd += mss`) is modelled here.
--   - `app_limited` is kept as a `Bool` field (no window change when set).
--   - `ssthresh` is an ordinary `Nat` (no `Saturating` wrapper needed).
--   - `bytes_acked_sl` (slow-start ACK counter) is included but not the focus
--     of current theorems.
--   - The `let new_bytes := …` binding in the CA branch is inlined to avoid
--     proof complications with `let`-expressions in Lean 4 goal contexts.

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  Model types and invariant
-- ─────────────────────────────────────────────────────────────────────────────

/-- Functional model of the NewReno `Congestion` struct.
    `in_recovery` abstracts `congestion_recovery_start_time.is_some()` and the
    time comparison in `in_congestion_recovery`. -/
structure NewReno where
  cwnd           : Nat   -- congestion_window
  ssthresh       : Nat   -- slow-start threshold
  bytes_acked_ca : Nat   -- CA byte counter
  bytes_acked_sl : Nat   -- slow-start byte counter
  mss            : Nat   -- max_datagram_size
  in_recovery    : Bool  -- abstraction of congestion_recovery_start_time
  app_limited    : Bool

/-- The floor invariant: `cwnd ≥ mss * MINIMUM_WINDOW_PACKETS` (= mss * 2).
    This must hold after any congestion event. -/
def NewReno.FloorInv (r : NewReno) : Prop :=
  r.cwnd ≥ r.mss * 2

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  Pure functional operations
-- ─────────────────────────────────────────────────────────────────────────────

/-- `LOSS_REDUCTION_FACTOR = 0.5` modelled as Nat floor-division by 2.
    Matches `(x as f64 * 0.5) as usize` in Rust. -/
def halve (x : Nat) : Nat := x / 2

/-- `congestion_event`: reduce cwnd on loss.
    Only acts when not already in recovery (`!r.in_recovery`). -/
def NewReno.congestion_event (r : NewReno) : NewReno :=
  if r.in_recovery then
    r                    -- already in recovery — no action
  else
    let new_cwnd := Nat.max (halve r.cwnd) (r.mss * 2)
    { r with
      cwnd           := new_cwnd
      bytes_acked_ca := halve new_cwnd
      ssthresh       := new_cwnd
      in_recovery    := true }

/-- `on_packet_acked` (single ACK, slow-start or CA branch).
    HyStart++ CSS is abstracted away; only the plain branches are modelled.
    The CA `let new_bytes := …` binding is inlined to ease proofs. -/
def NewReno.on_packet_acked (r : NewReno) (pkt_size : Nat) : NewReno :=
  if r.in_recovery || r.app_limited then
    r                    -- guarded — no window change
  else if r.cwnd < r.ssthresh then
    -- Slow start: grow cwnd by one MSS per ACKed packet
    { r with
      bytes_acked_sl := r.bytes_acked_sl + pkt_size
      cwnd           := r.cwnd + r.mss }
  else if r.bytes_acked_ca + pkt_size ≥ r.cwnd then
    -- CA: threshold reached — grow by one MSS
    { r with
      bytes_acked_ca := r.bytes_acked_ca + pkt_size - r.cwnd
      cwnd           := r.cwnd + r.mss }
  else
    -- CA: still accumulating
    { r with bytes_acked_ca := r.bytes_acked_ca + pkt_size }

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  Key theorems
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 3.1  Window floor after a fresh congestion event ─────────────────────────

/-- After a **fresh** (non-recovery) congestion event, cwnd ≥ mss * 2.
    This is the MINIMUM_WINDOW_PACKETS safety floor. -/
theorem cwnd_floor_new_event (r : NewReno) (h : r.in_recovery = false) :
    (r.congestion_event).cwnd ≥ r.mss * 2 := by
  unfold NewReno.congestion_event
  simp [h, Nat.le_max_right]

-- ── 3.2  Single halving per epoch ────────────────────────────────────────────

/-- When already in recovery, `congestion_event` is a no-op. -/
theorem single_halving (r : NewReno) (h : r.in_recovery = true) :
    r.congestion_event = r := by
  unfold NewReno.congestion_event
  simp [h]

-- ── 3.3  Recovery flag is set after a new congestion event ───────────────────

/-- After a fresh congestion event, `in_recovery` is true. -/
theorem congestion_event_sets_recovery (r : NewReno)
    (h : r.in_recovery = false) :
    (r.congestion_event).in_recovery = true := by
  unfold NewReno.congestion_event
  simp [h]

-- ── 3.4  Idempotence: two consecutive congestion events (same epoch) ──────────

/-- Two consecutive calls to `congestion_event` are equivalent to one.
    The second call sees `in_recovery = true` and is a no-op. -/
theorem congestion_event_idempotent (r : NewReno) :
    r.congestion_event.congestion_event = r.congestion_event := by
  unfold NewReno.congestion_event
  by_cases h : r.in_recovery
  · simp [h]
  · simp [h]

-- ── 3.5  Slow-start growth (not guarded) ─────────────────────────────────────

/-- In slow start, not in recovery, not app_limited: cwnd grows by exactly mss. -/
theorem slow_start_growth (r : NewReno) (pkt_size : Nat)
    (hss  : r.cwnd < r.ssthresh)
    (hrec : r.in_recovery = false)
    (happ : r.app_limited = false) :
    (r.on_packet_acked pkt_size).cwnd = r.cwnd + r.mss := by
  unfold NewReno.on_packet_acked
  simp [hrec, happ, hss]

-- ── 3.6  Congestion avoidance: no growth below threshold ─────────────────────

/-- In CA, ACK bytes below threshold → cwnd unchanged. -/
theorem ca_ack_no_growth (r : NewReno) (pkt_size : Nat)
    (hca  : ¬ r.cwnd < r.ssthresh)
    (hrec : r.in_recovery = false)
    (happ : r.app_limited = false)
    (hlt  : ¬ r.bytes_acked_ca + pkt_size ≥ r.cwnd) :
    (r.on_packet_acked pkt_size).cwnd = r.cwnd := by
  unfold NewReno.on_packet_acked
  simp [hrec, happ, hca, hlt]

-- ── 3.7  Congestion avoidance: growth when threshold reached ─────────────────

/-- In CA, when bytes_acked_ca + pkt_size ≥ cwnd, the window grows by mss. -/
theorem ca_ack_growth (r : NewReno) (pkt_size : Nat)
    (hca  : ¬ r.cwnd < r.ssthresh)
    (hrec : r.in_recovery = false)
    (happ : r.app_limited = false)
    (hge  : r.bytes_acked_ca + pkt_size ≥ r.cwnd) :
    (r.on_packet_acked pkt_size).cwnd = r.cwnd + r.mss := by
  unfold NewReno.on_packet_acked
  simp [hrec, happ, hca, hge]

-- ── 3.8  No change when in recovery ──────────────────────────────────────────

/-- When in recovery, `on_packet_acked` does not change cwnd. -/
theorem recovery_no_growth (r : NewReno) (pkt_size : Nat)
    (hrec : r.in_recovery = true) :
    (r.on_packet_acked pkt_size).cwnd = r.cwnd := by
  unfold NewReno.on_packet_acked
  simp [hrec]

-- ── 3.9  No change when app-limited ──────────────────────────────────────────

/-- When app-limited, `on_packet_acked` does not change cwnd. -/
theorem app_limited_no_growth (r : NewReno) (pkt_size : Nat)
    (hrec : r.in_recovery = false)
    (happ : r.app_limited = true) :
    (r.on_packet_acked pkt_size).cwnd = r.cwnd := by
  unfold NewReno.on_packet_acked
  simp [hrec, happ]

-- ── 3.10  cwnd is non-decreasing under on_packet_acked ───────────────────────

/-- `on_packet_acked` never decreases cwnd. -/
theorem acked_cwnd_monotone (r : NewReno) (pkt_size : Nat) :
    (r.on_packet_acked pkt_size).cwnd ≥ r.cwnd := by
  unfold NewReno.on_packet_acked
  by_cases hg : r.in_recovery || r.app_limited
  · simp [hg]
  · simp only [hg]
    by_cases hss : r.cwnd < r.ssthresh
    · simp [hss]
    · simp only [hss]
      by_cases hge : r.bytes_acked_ca + pkt_size ≥ r.cwnd
      · simp [hge]
      · simp [hge]

-- ── 3.11  FloorInv preserved through on_packet_acked ─────────────────────────

/-- If FloorInv holds, it is preserved by `on_packet_acked`. -/
theorem acked_preserves_floor_inv (r : NewReno) (pkt_size : Nat)
    (h : r.FloorInv) :
    (r.on_packet_acked pkt_size).FloorInv := by
  unfold NewReno.FloorInv at *
  unfold NewReno.on_packet_acked
  by_cases hg : r.in_recovery || r.app_limited
  · simp [hg]; exact h
  · simp only [hg]
    by_cases hss : r.cwnd < r.ssthresh
    · simp [hss]; omega
    · simp only [hss]
      by_cases hge : r.bytes_acked_ca + pkt_size ≥ r.cwnd
      · simp [hge]; omega
      · simp [hge]; exact h

-- ── 3.12  congestion_event does not increase cwnd (under FloorInv) ───────────

/-- Under FloorInv, `congestion_event` does not raise cwnd. -/
theorem congestion_event_cwnd_le_of_floor (r : NewReno) (h : r.FloorInv) :
    (r.congestion_event).cwnd ≤ r.cwnd := by
  unfold NewReno.congestion_event
  by_cases hrec : r.in_recovery
  · simp [hrec]
  · simp only [hrec]
    unfold NewReno.FloorInv at h
    apply Nat.max_le.mpr
    constructor
    · exact Nat.div_le_self _ _
    · exact h

-- ── 3.13  FloorInv is established by congestion_event ────────────────────────

/-- Any fresh congestion event establishes FloorInv. -/
theorem congestion_event_establishes_floor (r : NewReno)
    (h : r.in_recovery = false) :
    (r.congestion_event).FloorInv := by
  unfold NewReno.FloorInv
  unfold NewReno.congestion_event
  simp [h]
  exact Nat.le_max_right _ _

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Concrete examples
-- ─────────────────────────────────────────────────────────────────────────────

-- Example 1: slow-start growth (+1 mss per packet)
#eval
  let r : NewReno := { cwnd := 10, ssthresh := 100, bytes_acked_ca := 0,
                       bytes_acked_sl := 0, mss := 1, in_recovery := false,
                       app_limited := false }
  (r.on_packet_acked 1).cwnd  -- expected 11

-- Example 2: congestion event halves cwnd
#eval
  let r : NewReno := { cwnd := 20, ssthresh := 100, bytes_acked_ca := 0,
                       bytes_acked_sl := 0, mss := 1, in_recovery := false,
                       app_limited := false }
  (r.congestion_event).cwnd  -- expected max(10, 2) = 10

-- Example 3: congestion event floor (small cwnd is clamped to mss*2)
#eval
  let r : NewReno := { cwnd := 2, ssthresh := 100, bytes_acked_ca := 0,
                       bytes_acked_sl := 0, mss := 2, in_recovery := false,
                       app_limited := false }
  (r.congestion_event).cwnd  -- expected max(1, 4) = 4

-- Example 4: CA growth after one full window ACKed
#eval
  let r : NewReno := { cwnd := 10, ssthresh := 10, bytes_acked_ca := 9,
                       bytes_acked_sl := 0, mss := 1, in_recovery := false,
                       app_limited := false }
  (r.on_packet_acked 1).cwnd  -- expected 11 (9+1 ≥ cwnd=10, so grows)

-- Example 5: CA no growth (accumulating)
#eval
  let r : NewReno := { cwnd := 10, ssthresh := 10, bytes_acked_ca := 5,
                       bytes_acked_sl := 0, mss := 1, in_recovery := false,
                       app_limited := false }
  (r.on_packet_acked 3).cwnd  -- expected 10 (5+3 < cwnd=10, no growth)
