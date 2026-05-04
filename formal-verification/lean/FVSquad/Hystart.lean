-- Copyright (C) 2024, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/Hystart.lean
--
-- Formal verification of HyStart++ invariants.
-- Source: quiche/src/recovery/congestion/hystart.rs
-- RFC: draft-ietf-tcpm-hystartplusplus-04
--
-- Key invariants verified:
--   1. rtt_thresh is clamped to [MIN_RTT_THRESH, MAX_RTT_THRESH]
--   2. css_cwnd_inc = pkt_size / CSS_GROWTH_DIVISOR
--   3. css_cwnd_inc ≤ pkt_size (CSS reduces increment)
--   4. Constant sanity: MIN_RTT_THRESH ≤ MAX_RTT_THRESH, CSS_ROUNDS = 5
--   5. rtt_thresh is monotone in last_round_min_rtt
--   6. css_cwnd_inc is strictly less than pkt_size for pkt_size > 0

namespace Hystart

/-! ## Constants

Modelled as natural numbers (milliseconds).
Rust: Duration::from_millis(4)/Duration::from_millis(16) etc.
-/

/-- Minimum RTT threshold for SS→CSS transition (4 ms). -/
def MIN_RTT_THRESH : Nat := 4

/-- Maximum RTT threshold (16 ms). -/
def MAX_RTT_THRESH : Nat := 16

/-- Number of RTT samples required before checking threshold. -/
def N_RTT_SAMPLE : Nat := 8

/-- Divisor for cwnd increment during Conservative Slow Start. -/
def CSS_GROWTH_DIVISOR : Nat := 4

/-- Number of CSS rounds before exiting to Congestion Avoidance. -/
def CSS_ROUNDS : Nat := 5

/-! ## Pure model

`rtt_thresh last_ms` mirrors the Rust expression:
  cmp::min(cmp::max(last_round_min_rtt / 8, MIN_RTT_THRESH), MAX_RTT_THRESH)

All values in milliseconds; integer division matches Rust's Duration::div.
-/

/-- RTT threshold: clamp(last_ms / 8, MIN_RTT_THRESH, MAX_RTT_THRESH). -/
def rtt_thresh (last_ms : Nat) : Nat :=
  min (max (last_ms / 8) MIN_RTT_THRESH) MAX_RTT_THRESH

/-- CSS cwnd increment: pkt_size / CSS_GROWTH_DIVISOR. -/
def css_cwnd_inc (pkt_size : Nat) : Nat :=
  pkt_size / CSS_GROWTH_DIVISOR

/-! ## Theorem 1: Constant sanity -/

/-- MIN_RTT_THRESH ≤ MAX_RTT_THRESH. -/
theorem min_le_max_thresh : MIN_RTT_THRESH ≤ MAX_RTT_THRESH := by decide

/-- CSS_GROWTH_DIVISOR is positive. -/
theorem css_growth_divisor_pos : 0 < CSS_GROWTH_DIVISOR := by decide

/-- CSS_ROUNDS = 5 (matches RFC constant). -/
theorem css_rounds_five : CSS_ROUNDS = 5 := by decide

/-- N_RTT_SAMPLE = 8. -/
theorem n_rtt_sample_eight : N_RTT_SAMPLE = 8 := by decide

/-! ## Theorem 2: rtt_thresh clamping -/

/-- rtt_thresh is always at least MIN_RTT_THRESH. -/
theorem rtt_thresh_ge_min (last_ms : Nat) :
    MIN_RTT_THRESH ≤ rtt_thresh last_ms := by
  simp only [rtt_thresh, MIN_RTT_THRESH, MAX_RTT_THRESH]
  exact Nat.le_min.mpr ⟨Nat.le_max_right _ _, by decide⟩

/-- rtt_thresh is always at most MAX_RTT_THRESH. -/
theorem rtt_thresh_le_max (last_ms : Nat) :
    rtt_thresh last_ms ≤ MAX_RTT_THRESH := by
  simp only [rtt_thresh, MAX_RTT_THRESH]
  exact Nat.min_le_right _ _

/-- When last_ms / 8 is below MIN, rtt_thresh equals MIN_RTT_THRESH. -/
theorem rtt_thresh_clamp_low (last_ms : Nat)
    (h : last_ms / 8 ≤ MIN_RTT_THRESH) :
    rtt_thresh last_ms = MIN_RTT_THRESH := by
  simp only [rtt_thresh, MIN_RTT_THRESH, MAX_RTT_THRESH] at *
  rw [Nat.max_eq_right h, Nat.min_eq_left (by decide)]

/-- When last_ms / 8 is above MAX, rtt_thresh equals MAX_RTT_THRESH. -/
theorem rtt_thresh_clamp_high (last_ms : Nat)
    (h : MAX_RTT_THRESH ≤ last_ms / 8) :
    rtt_thresh last_ms = MAX_RTT_THRESH := by
  simp only [rtt_thresh, MIN_RTT_THRESH, MAX_RTT_THRESH] at *
  rw [Nat.max_eq_left (by omega), Nat.min_eq_right h]

/-- When last_ms / 8 is in [MIN, MAX], rtt_thresh equals last_ms / 8. -/
theorem rtt_thresh_clamp_mid (last_ms : Nat)
    (hlo : MIN_RTT_THRESH ≤ last_ms / 8)
    (hhi : last_ms / 8 ≤ MAX_RTT_THRESH) :
    rtt_thresh last_ms = last_ms / 8 := by
  simp only [rtt_thresh, MIN_RTT_THRESH, MAX_RTT_THRESH] at *
  rw [Nat.max_eq_left hlo, Nat.min_eq_left hhi]

/-- rtt_thresh is monotone: larger last_ms gives larger (or equal) threshold.
    This follows because integer division is monotone and clamp is monotone. -/
theorem rtt_thresh_monotone (a b : Nat) (h : a ≤ b) :
    rtt_thresh a ≤ rtt_thresh b := by
  simp only [rtt_thresh, MIN_RTT_THRESH, MAX_RTT_THRESH]
  have hdiv : a / 8 ≤ b / 8 := Nat.div_le_div_right h
  have h_max : Nat.max (a / 8) 4 ≤ Nat.max (b / 8) 4 :=
    Nat.max_le.mpr ⟨Nat.le_trans hdiv (Nat.le_max_left (b / 8) 4),
                    Nat.le_max_right (b / 8) 4⟩
  exact Nat.le_min.mpr
    ⟨Nat.le_trans (Nat.min_le_left _ _) h_max, Nat.min_le_right _ _⟩

/-! ## Theorem 3: css_cwnd_inc invariants -/

/-- css_cwnd_inc matches Rust: pkt_size / CSS_GROWTH_DIVISOR. -/
theorem css_cwnd_inc_eq (pkt_size : Nat) :
    css_cwnd_inc pkt_size = pkt_size / CSS_GROWTH_DIVISOR := by
  rfl

/-- css_cwnd_inc ≤ pkt_size (CSS reduces the increment, divisor ≥ 1). -/
theorem css_cwnd_inc_le_pkt (pkt_size : Nat) :
    css_cwnd_inc pkt_size ≤ pkt_size := by
  simp [css_cwnd_inc, CSS_GROWTH_DIVISOR]
  omega

/-- css_cwnd_inc < pkt_size when pkt_size > 0 (strict reduction for CSS). -/
theorem css_cwnd_inc_lt_pkt (pkt_size : Nat) (h : 0 < pkt_size) :
    css_cwnd_inc pkt_size < pkt_size := by
  simp [css_cwnd_inc, CSS_GROWTH_DIVISOR]
  omega

/-- css_cwnd_inc is monotone in pkt_size. -/
theorem css_cwnd_inc_monotone (a b : Nat) (h : a ≤ b) :
    css_cwnd_inc a ≤ css_cwnd_inc b := by
  simp [css_cwnd_inc, CSS_GROWTH_DIVISOR]
  exact Nat.div_le_div_right h

/-- css_cwnd_inc is at most one quarter of pkt_size (exact since divisor = 4). -/
theorem css_cwnd_inc_quarter (pkt_size : Nat) :
    css_cwnd_inc pkt_size = pkt_size / 4 := by
  simp [css_cwnd_inc, CSS_GROWTH_DIVISOR]

end Hystart
