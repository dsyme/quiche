-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of Proportional Rate Reduction (PRR)
-- in `quiche/src/recovery/congestion/prr.rs`.
--
-- Based on RFC 6937: <https://datatracker.ietf.org/doc/html/rfc6937>
--
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- §1  Ceiling-division helper
-- §2  Model types
-- §3  Pure functional operations
-- §4  Theorems
--       congestion_event: 5 theorems (state reset + idempotence)
--       on_packet_sent:   2 theorems (prr_out increases, snd_cnt saturates)
--       on_packet_acked:  2 theorems (prr_delivered increases, prr_out unchanged)
--       PRR mode:         3 theorems (zero-recoverfs, formula, rate bound)
--       PRR-SSRB mode:    4 theorems (gap bound, limit bound, at-least-mss, formula)
--       Structural:       1 theorem  (congestion then sent: prr_out = sent_bytes)
--
-- Approximations / abstractions:
--   - `usize` → `Nat` (unbounded). No integer overflow.
--   - Lean `Nat` subtraction saturates at 0, faithfully modelling Rust's
--     `saturating_sub`.
--   - `usize::div_ceil(a, b)` → `divCeil a b` below (= 0 when b = 0, matching
--     Lean's `Nat.div` convention and the `recoverfs > 0` guard in the Rust).
--   - `cmp::max(snd_cnt, 0)` at the end of `on_packet_acked` is a no-op for
--     `Nat` (always ≥ 0) and is omitted.
--   - The protocol contract that callers only invoke `on_packet_sent` with
--     `sent_bytes ≤ snd_cnt` is NOT enforced by the model.

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  Ceiling-division helper
-- ─────────────────────────────────────────────────────────────────────────────

/-- Ceiling integer division: `divCeil a b = ⌈a / b⌉`.
    Returns 0 when `b = 0` (matching Lean's `Nat.div` convention, and the
    `recoverfs > 0` guard in the Rust source). -/
def divCeil (a b : Nat) : Nat :=
  if b = 0 then 0 else (a + b - 1) / b

/-- `divCeil 0 b = 0` for all `b`. -/
theorem divCeil_zero_left (b : Nat) : divCeil 0 b = 0 := by
  simp [divCeil]
  cases b <;> simp

/-- When `b > 0`, `divCeil a b` equals `(a + b - 1) / b`. -/
theorem divCeil_eq_of_pos {b : Nat} (hb : 0 < b) (a : Nat) :
    divCeil a b = (a + b - 1) / b := by
  have hne : b ≠ 0 := by omega
  simp [divCeil, hne]

/-- Ceiling division is at least floor division. -/
theorem divCeil_ge_div (a b : Nat) : a / b ≤ divCeil a b := by
  by_cases hb : b = 0
  · simp [hb, divCeil]
  · simp only [divCeil, hb, ite_false]
    apply Nat.div_le_div_right
    omega

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  Model types
-- ─────────────────────────────────────────────────────────────────────────────

/-- Functional model of the `PRR` struct in `prr.rs`.
    All fields are `Nat`, mirroring Rust's `usize` without an upper bound.
    Lean `Nat` subtraction saturates at 0, matching Rust's `saturating_sub`. -/
structure PRR where
  /-- Bytes delivered (ACKed) since the start of this recovery epoch. -/
  prr_delivered : Nat
  /-- Bytes in flight at the start of this recovery epoch (`recoverfs`). -/
  recoverfs     : Nat
  /-- Bytes sent since the start of this recovery epoch. -/
  prr_out       : Nat
  /-- How many additional bytes the sender is permitted to transmit now. -/
  snd_cnt       : Nat

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  Pure functional operations
-- ─────────────────────────────────────────────────────────────────────────────

/-- Reset PRR state at the start of a new congestion recovery epoch.
    Records `bytes_in_flight` as the flight size at epoch start. -/
def PRR.congestion_event (p : PRR) (bytes_in_flight : Nat) : PRR :=
  { prr_delivered := 0
    recoverfs     := bytes_in_flight
    prr_out       := 0
    snd_cnt       := 0 }

/-- Record that `sent_bytes` bytes were sent; decrease `snd_cnt` by the same
    amount (saturating at 0). -/
def PRR.on_packet_sent (p : PRR) (sent_bytes : Nat) : PRR :=
  { p with
    prr_out := p.prr_out + sent_bytes
    snd_cnt := p.snd_cnt - sent_bytes }

/-- Recompute `snd_cnt` after receiving ACKs for `delivered_data` bytes.
    - **PRR mode** (`pipe > ssthresh`): paces the sending rate proportionally
      to the fraction of `recoverfs` already delivered.
    - **PRR-SSRB mode** (`pipe ≤ ssthresh`): allows catching up to `ssthresh`
      at most one MSS above the per-round delivery limit.
    Implements RFC 6937 §3. -/
def PRR.on_packet_acked
    (p : PRR) (delivered_data pipe ssthresh mss : Nat) : PRR :=
  let new_del := p.prr_delivered + delivered_data
  { prr_delivered := new_del
    recoverfs     := p.recoverfs
    prr_out       := p.prr_out
    snd_cnt       :=
      if pipe > ssthresh then
        -- PRR: proportional rate reduction
        if p.recoverfs > 0 then
          divCeil (new_del * ssthresh) p.recoverfs - p.prr_out
        else
          0
      else
        -- PRR-SSRB: safe slow-start recovery band
        Nat.min (ssthresh - pipe)
          (Nat.max (new_del - p.prr_out) delivered_data + mss) }

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Theorems
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 4.1  congestion_event ────────────────────────────────────────────────────

/-- After `congestion_event`, `prr_delivered` is reset to 0. -/
theorem congestion_event_prr_delivered (p : PRR) (flight : Nat) :
    (p.congestion_event flight).prr_delivered = 0 := rfl

/-- After `congestion_event`, `recoverfs` records the in-flight bytes. -/
theorem congestion_event_recoverfs (p : PRR) (flight : Nat) :
    (p.congestion_event flight).recoverfs = flight := rfl

/-- After `congestion_event`, `prr_out` is reset to 0. -/
theorem congestion_event_prr_out (p : PRR) (flight : Nat) :
    (p.congestion_event flight).prr_out = 0 := rfl

/-- After `congestion_event`, `snd_cnt` is reset to 0. -/
theorem congestion_event_snd_cnt (p : PRR) (flight : Nat) :
    (p.congestion_event flight).snd_cnt = 0 := rfl

/-- Two consecutive congestion events are equivalent to the last one alone. -/
theorem congestion_event_twice (p : PRR) (f1 f2 : Nat) :
    (p.congestion_event f1).congestion_event f2 = p.congestion_event f2 := rfl

-- ── 4.2  on_packet_sent ──────────────────────────────────────────────────────

/-- `on_packet_sent` increases `prr_out` by exactly `sent_bytes`. -/
theorem sent_prr_out_increases (p : PRR) (b : Nat) :
    (p.on_packet_sent b).prr_out = p.prr_out + b := rfl

/-- `on_packet_sent` decrements `snd_cnt` by `sent_bytes`, saturating at 0. -/
theorem sent_snd_cnt_saturating (p : PRR) (b : Nat) :
    (p.on_packet_sent b).snd_cnt = p.snd_cnt - b := rfl

-- ── 4.3  on_packet_acked: field invariants ───────────────────────────────────

/-- `on_packet_acked` increases `prr_delivered` by exactly `delivered_data`. -/
theorem acked_prr_delivered_increases (p : PRR) (d pipe ss mss : Nat) :
    (p.on_packet_acked d pipe ss mss).prr_delivered = p.prr_delivered + d := rfl

/-- `on_packet_acked` leaves `prr_out` unchanged. -/
theorem acked_prr_out_unchanged (p : PRR) (d pipe ss mss : Nat) :
    (p.on_packet_acked d pipe ss mss).prr_out = p.prr_out := rfl

-- ── 4.4  PRR mode (pipe > ssthresh) ──────────────────────────────────────────

/-- When `recoverfs = 0` and we are in PRR mode, `snd_cnt = 0`.
    Avoids division by zero and correctly sends nothing. -/
theorem prr_mode_snd_cnt_zero_when_recoverfs_zero
    (p : PRR) (d pipe ss mss : Nat)
    (h_pipe : pipe > ss)
    (h_rfs  : p.recoverfs = 0) :
    (p.on_packet_acked d pipe ss mss).snd_cnt = 0 := by
  simp only [PRR.on_packet_acked]
  by_cases hpipe : pipe > ss
  · simp only [hpipe, ite_true]
    have hno : ¬ (p.recoverfs > 0) := by omega
    simp [hno]
  · exact absurd h_pipe hpipe

/-- In PRR mode with `recoverfs > 0`, `snd_cnt` equals the RFC 6937 formula:
    `⌈prr_delivered' · ssthresh / recoverfs⌉ − prr_out`. -/
theorem prr_mode_snd_cnt_formula
    (p : PRR) (d pipe ss mss : Nat)
    (h_pipe : pipe > ss)
    (h_rfs  : 0 < p.recoverfs) :
    (p.on_packet_acked d pipe ss mss).snd_cnt =
      divCeil ((p.prr_delivered + d) * ss) p.recoverfs - p.prr_out := by
  simp only [PRR.on_packet_acked]
  by_cases hpipe : pipe > ss
  · simp only [hpipe, ite_true]
    by_cases hrfs : p.recoverfs > 0
    · simp [hrfs]
    · exact absurd h_rfs hrfs
  · exact absurd h_pipe hpipe

/-- In PRR mode, `snd_cnt ≤ ⌈prr_delivered' · ssthresh / recoverfs⌉`.
    This is the central rate-control guarantee of PRR: the sender never
    transmits more than the proportional-rate target. -/
theorem prr_mode_snd_cnt_le_ratio
    (p : PRR) (d pipe ss mss : Nat)
    (h_pipe : pipe > ss)
    (h_rfs  : 0 < p.recoverfs) :
    (p.on_packet_acked d pipe ss mss).snd_cnt ≤
      divCeil ((p.prr_delivered + d) * ss) p.recoverfs := by
  rw [prr_mode_snd_cnt_formula p d pipe ss mss h_pipe h_rfs]
  omega

-- ── 4.5  PRR-SSRB mode (pipe ≤ ssthresh) ─────────────────────────────────────

/-- In SSRB mode, `snd_cnt ≤ ssthresh − pipe` (the gap to the target). -/
theorem ssrb_snd_cnt_le_gap
    (p : PRR) (d pipe ss mss : Nat)
    (h_pipe : ¬ pipe > ss) :
    (p.on_packet_acked d pipe ss mss).snd_cnt ≤ ss - pipe := by
  simp only [PRR.on_packet_acked]
  by_cases hpipe : pipe > ss
  · exact absurd hpipe h_pipe
  · simp only [hpipe, ite_false]
    exact Nat.min_le_left _ _

/-- In SSRB mode, `snd_cnt` is bounded by the per-round limit
    `max(prr_delivered' − prr_out, delivered_data) + mss`. -/
theorem ssrb_snd_cnt_le_limit
    (p : PRR) (d pipe ss mss : Nat)
    (h_pipe : ¬ pipe > ss) :
    (p.on_packet_acked d pipe ss mss).snd_cnt ≤
      Nat.max (p.prr_delivered + d - p.prr_out) d + mss := by
  simp only [PRR.on_packet_acked]
  by_cases hpipe : pipe > ss
  · exact absurd hpipe h_pipe
  · simp only [hpipe, ite_false]
    exact Nat.min_le_right _ _

/-- In SSRB mode, `snd_cnt ≥ min(ssthresh − pipe, mss)`.
    The per-round limit always includes at least `mss` (since `max(·,·) + mss ≥ mss`),
    so SSRB always permits at least one MSS worth of sends when room exists. -/
theorem ssrb_snd_cnt_ge_min_gap_mss
    (p : PRR) (d pipe ss mss : Nat)
    (h_pipe : ¬ pipe > ss) :
    Nat.min (ss - pipe) mss ≤ (p.on_packet_acked d pipe ss mss).snd_cnt := by
  simp only [PRR.on_packet_acked]
  by_cases hpipe : pipe > ss
  · exact absurd hpipe h_pipe
  · simp only [hpipe, ite_false]
    -- Goal: min (ss - pipe) mss ≤ min (ss - pipe) (max (...) d + mss)
    -- Since max (...) d + mss ≥ mss, and min is monotone in the right argument:
    apply (Nat.le_min).mpr
    constructor
    · exact Nat.min_le_left _ _
    · exact Nat.le_trans (Nat.min_le_right _ _) (by omega)

/-- In SSRB mode, the exact formula for `snd_cnt`. -/
theorem ssrb_snd_cnt_formula
    (p : PRR) (d pipe ss mss : Nat)
    (h_pipe : ¬ pipe > ss) :
    (p.on_packet_acked d pipe ss mss).snd_cnt =
      Nat.min (ss - pipe) (Nat.max (p.prr_delivered + d - p.prr_out) d + mss) := by
  simp only [PRR.on_packet_acked]
  by_cases hpipe : pipe > ss
  · exact absurd hpipe h_pipe
  · simp [hpipe]

-- ── 4.6  Structural: fresh epoch ─────────────────────────────────────────────

/-- After `congestion_event` followed by `on_packet_sent b`, `prr_out = b`.
    The epoch reset clears `prr_out` to 0, then `on_packet_sent` sets it to `b`. -/
theorem fresh_epoch_sent_prr_out (p : PRR) (flight b : Nat) :
    ((p.congestion_event flight).on_packet_sent b).prr_out = b := by
  simp [PRR.congestion_event, PRR.on_packet_sent]
