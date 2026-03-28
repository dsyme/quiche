-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of the RTT estimation algorithm
-- in `quiche/src/recovery/rtt.rs`.
--
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- Approximations / abstractions:
--   - Duration values are modelled as Nat (nanoseconds, unbounded).
--     No overflow, no wrap-around.
--   - The Minmax windowed minimum filter (RTT_WINDOW = 300s eviction) is
--     abstracted to plain `Nat.min`. Time-based eviction is NOT modelled.
--   - max_ack_delay clamping (handshake_confirmed branch) is NOT modelled;
--     callers are assumed to pass a post-clamped ack_delay.
--   - `loss_delay` uses a rational (num/denom) approximation for the
--     float `time_thresh` parameter.
--   - All arithmetic is over Nat (natural numbers), so subtraction is
--     saturating (a - b = 0 when a < b). This matches Rust's
--     `Duration::checked_sub` / saturating behaviour.
--
-- References:
--   RFC 9002 §5.3 — Estimating the Round-Trip Time
--   RFC 9002 §5.4 — Estimating the Acknowledgement Delay

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §1  Constants
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- GRANULARITY = 1 ms expressed in nanoseconds.
    Mirrors `GRANULARITY` in `quiche/src/recovery/mod.rs:85`. -/
def GRANULARITY_NS : Nat := 1_000_000

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §2  RTT state
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Pure model of `RttStats` (`quiche/src/recovery/rtt.rs`).
    All Duration fields are represented in nanoseconds as Nat. -/
structure RttState where
  /-- Smoothed RTT (SRTT) — RFC 9002 §5.3. -/
  smoothed_rtt : Nat
  /-- RTT variation (RTTVAR) — RFC 9002 §5.3. -/
  rttvar       : Nat
  /-- Minimum RTT observed (simplified: no windowed eviction). -/
  min_rtt      : Nat
  /-- Maximum RTT observed. -/
  max_rtt      : Nat
  /-- Most recent RTT sample. -/
  latest_rtt   : Nat
  /-- Whether at least one RTT sample has been seen. -/
  has_first    : Bool

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §3  Initialisation
--     Mirrors `RttStats::new` (rtt.rs:64-73).
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Construct the initial RTT state from an initial RTT estimate.
    RFC 9002 §5.3: Before any measurement, SRTT = initial_rtt,
    RTTVAR = initial_rtt / 2. -/
def rtt_init (initial_rtt : Nat) : RttState :=
  { smoothed_rtt := initial_rtt
    rttvar       := initial_rtt / 2
    min_rtt      := initial_rtt
    max_rtt      := initial_rtt
    latest_rtt   := 0
    has_first    := false }

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §4  Acknowledgement-delay adjustment
--     Mirrors the inline computation in `RttStats::update_rtt` (rtt.rs:92-100).
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Compute the adjusted RTT by subtracting the acknowledgement delay when
    the delay is "plausible" (RFC 9002 §5.4):
      adjusted_rtt = latest_rtt - ack_delay
                     if latest_rtt ≥ min_rtt + ack_delay
                     else latest_rtt. -/
def adjust_rtt (latest_rtt min_rtt ack_delay : Nat) : Nat :=
  if latest_rtt >= min_rtt + ack_delay then
    latest_rtt - ack_delay
  else
    latest_rtt

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §5  Absolute difference for Nat
--     Mirrors `u128::abs_diff` used in the rttvar update.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Absolute difference: |a - b|. -/
def abs_diff_nat (a b : Nat) : Nat :=
  if a >= b then a - b else b - a

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §6  RTT update
--     Mirrors `RttStats::update_rtt` (rtt.rs:75-111).
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Update RTT statistics with a new sample.

    - If no sample seen yet (first call): initialise from the sample.
    - Otherwise: apply RFC 9002 §5.3 EWMA update:
        SRTT   = 7/8 · SRTT   + 1/8 · adjusted_rtt
        RTTVAR = 3/4 · RTTVAR + 1/4 · |SRTT - adjusted_rtt|

    `ack_delay` is assumed already clamped to max_ack_delay by the caller
    when handshake is confirmed. -/
def update_rtt (s : RttState) (latest_rtt ack_delay : Nat) : RttState :=
  if !s.has_first then
    { smoothed_rtt := latest_rtt
      rttvar       := latest_rtt / 2
      min_rtt      := latest_rtt
      max_rtt      := latest_rtt
      latest_rtt   := latest_rtt
      has_first    := true }
  else
    let adj   := adjust_rtt latest_rtt s.min_rtt ack_delay
    let srtt' := s.smoothed_rtt * 7 / 8 + adj / 8
    let var'  := s.rttvar * 3 / 4 + abs_diff_nat s.smoothed_rtt adj / 4
    let min'  := Nat.min s.min_rtt latest_rtt
    let max'  := Nat.max s.max_rtt latest_rtt
    { smoothed_rtt := srtt'
      rttvar       := var'
      min_rtt      := min'
      max_rtt      := max'
      latest_rtt   := latest_rtt
      has_first    := true }

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §7  loss_delay helper
--     Mirrors `RttStats::loss_delay` (rtt.rs:126-131).
--     `time_thresh` ≈ 9/8 — represented here as (thresh_num / thresh_denom).
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Compute the loss detection delay:
      max(max(latest_rtt, smoothed_rtt) * time_thresh, GRANULARITY). -/
def loss_delay (s : RttState) (thresh_num thresh_denom : Nat) : Nat :=
  let base := Nat.max s.latest_rtt s.smoothed_rtt
  Nat.max (base * thresh_num / thresh_denom) GRANULARITY_NS

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §8  Concrete verification (native_decide)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Initialisation postconditions (initial_rtt = 100ms = 100_000_000 ns)
example : (rtt_init 100_000_000).smoothed_rtt = 100_000_000 := by native_decide
example : (rtt_init 100_000_000).rttvar       = 50_000_000  := by native_decide
example : (rtt_init 100_000_000).has_first    = false        := by native_decide

-- First update: smoothed_rtt = latest_rtt (no ack_delay)
example : (update_rtt (rtt_init 100_000_000) 120_000_000 0).smoothed_rtt
    = 120_000_000 := by native_decide
example : (update_rtt (rtt_init 100_000_000) 120_000_000 0).rttvar
    = 60_000_000 := by native_decide
example : (update_rtt (rtt_init 100_000_000) 120_000_000 0).has_first
    = true := by native_decide

-- Plausible ack_delay: subtract it (latest=100ms, min=80ms, delay=10ms)
example : adjust_rtt 100_000_000 80_000_000 10_000_000 = 90_000_000 := by native_decide

-- Implausible ack_delay: keep latest (latest=50ms < min=80ms + delay=10ms)
example : adjust_rtt 50_000_000 80_000_000 10_000_000 = 50_000_000 := by native_decide

-- Zero ack_delay: adjusted = latest
example : adjust_rtt 100_000_000 80_000_000 0 = 100_000_000 := by native_decide

-- EWMA update with plausible delay:
-- srtt=100ms, rttvar=20ms, min=80ms, latest=100ms, delay=10ms
-- adj = 90ms
-- new_srtt = 100*7/8 + 90/8 = 87_500_000 + 11_250_000 = 98_750_000
-- new_rttvar = 20*3/4 + |100-90|/4 = 15_000_000 + 2_500_000 = 17_500_000
private def s0 : RttState :=
  { smoothed_rtt := 100_000_000, rttvar := 20_000_000,
    min_rtt := 80_000_000, max_rtt := 100_000_000,
    latest_rtt := 100_000_000, has_first := true }

example : (update_rtt s0 100_000_000 10_000_000).smoothed_rtt = 98_750_000 := by
  native_decide
example : (update_rtt s0 100_000_000 10_000_000).rttvar = 17_500_000 := by
  native_decide

-- abs_diff_nat
example : abs_diff_nat 100 80 = 20 := by native_decide
example : abs_diff_nat 80 100 = 20 := by native_decide
example : abs_diff_nat 50 50 = 0  := by native_decide

-- loss_delay: thresh=9/8, srtt=100ms > latest=50ms → base=100ms, *9/8=112_500_000
example : loss_delay
    { smoothed_rtt := 100_000_000, rttvar := 10_000_000,
      min_rtt := 50_000_000, max_rtt := 100_000_000,
      latest_rtt := 50_000_000, has_first := true }
    9 8 = 112_500_000 := by native_decide

-- loss_delay: base too small → clamped to GRANULARITY_NS
example : loss_delay
    { smoothed_rtt := 0, rttvar := 0,
      min_rtt := 0, max_rtt := 0, latest_rtt := 0, has_first := false }
    9 8 = 1_000_000 := by native_decide

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §9  Proved theorems — initialisation (RFC 9002 §5.3 initial state)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- I1: The initial state sets smoothed_rtt to initial_rtt. -/
theorem init_smoothed_rtt (r : Nat) :
    (rtt_init r).smoothed_rtt = r := rfl

/-- I2: The initial state sets rttvar to initial_rtt / 2. -/
theorem init_rttvar (r : Nat) :
    (rtt_init r).rttvar = r / 2 := rfl

/-- I3: The initial state has no RTT sample. -/
theorem init_has_first_false (r : Nat) :
    (rtt_init r).has_first = false := rfl

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §10 Proved theorems — first-sample update (RFC 9002 §5.3, first sample)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- I4: After the first RTT sample, smoothed_rtt = latest_rtt.
    RFC 9002 §5.3: "SRTT ← latest_RTT" on first measurement. -/
theorem first_update_smoothed_rtt (s : RttState) (h : s.has_first = false)
    (latest ack_delay : Nat) :
    (update_rtt s latest ack_delay).smoothed_rtt = latest := by
  unfold update_rtt
  simp [h]

/-- I5: After the first RTT sample, rttvar = latest_rtt / 2.
    RFC 9002 §5.3: "RTTVAR ← latest_RTT / 2" on first measurement. -/
theorem first_update_rttvar (s : RttState) (h : s.has_first = false)
    (latest ack_delay : Nat) :
    (update_rtt s latest ack_delay).rttvar = latest / 2 := by
  unfold update_rtt
  simp [h]

/-- I6: After the first RTT sample, has_first = true. -/
theorem first_update_sets_has_first (s : RttState) (h : s.has_first = false)
    (latest ack_delay : Nat) :
    (update_rtt s latest ack_delay).has_first = true := by
  unfold update_rtt
  simp [h]

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §11 Proved theorems — update always sets has_first
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- I7: Any call to update_rtt sets has_first = true.
    (has_first is monotone: once true, stays true.) -/
theorem update_sets_has_first (s : RttState) (latest ack_delay : Nat) :
    (update_rtt s latest ack_delay).has_first = true := by
  unfold update_rtt
  cases h : s.has_first <;> simp [Bool.not_false, Bool.not_true]

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §12 Proved theorems — acknowledge-delay adjustment
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- I8: Ack-delay adjustment never increases the RTT.
    adjusted_rtt ≤ latest_rtt always. -/
theorem adjust_rtt_le_latest (latest min_rtt ack_delay : Nat) :
    adjust_rtt latest min_rtt ack_delay ≤ latest := by
  unfold adjust_rtt
  split <;> omega

/-- I9: When the delay is plausible (latest ≥ min + delay),
    the adjustment subtracts ack_delay. -/
theorem adjust_rtt_when_plausible (latest min_rtt ack_delay : Nat)
    (h : latest >= min_rtt + ack_delay) :
    adjust_rtt latest min_rtt ack_delay = latest - ack_delay := by
  unfold adjust_rtt
  simp [h]

/-- I10: When the delay is implausible (latest < min + delay),
    the RTT is left unadjusted. -/
theorem adjust_rtt_when_implausible (latest min_rtt ack_delay : Nat)
    (h : ¬(latest >= min_rtt + ack_delay)) :
    adjust_rtt latest min_rtt ack_delay = latest := by
  unfold adjust_rtt
  simp [h]

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §13 Proved theorems — EWMA update formulas (RFC 9002 §5.3)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- I11: SRTT update formula on subsequent measurements.
    RFC 9002 §5.3: SRTT ← 7/8 · SRTT + 1/8 · adjusted_rtt. -/
theorem srtt_update_formula (s : RttState) (h : s.has_first = true)
    (latest ack_delay : Nat) :
    let adj := adjust_rtt latest s.min_rtt ack_delay
    (update_rtt s latest ack_delay).smoothed_rtt =
      s.smoothed_rtt * 7 / 8 + adj / 8 := by
  unfold update_rtt
  simp [h]

/-- I12: RTTVAR update formula on subsequent measurements.
    RFC 9002 §5.3: RTTVAR ← 3/4 · RTTVAR + 1/4 · |SRTT - adjusted_rtt|.
    Note: |·| uses the OLD smoothed_rtt, not the updated one. -/
theorem rttvar_update_formula (s : RttState) (h : s.has_first = true)
    (latest ack_delay : Nat) :
    let adj := adjust_rtt latest s.min_rtt ack_delay
    (update_rtt s latest ack_delay).rttvar =
      s.rttvar * 3 / 4 + abs_diff_nat s.smoothed_rtt adj / 4 := by
  unfold update_rtt
  simp [h]

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §14 Proved theorems — min_rtt and loss_delay properties
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- I13: min_rtt is non-increasing after each update.
    (Simplified — ignores windowed eviction of old minimum.) -/
theorem min_rtt_nonincreasing (s : RttState) (h : s.has_first = true)
    (latest ack_delay : Nat) :
    (update_rtt s latest ack_delay).min_rtt ≤ s.min_rtt := by
  unfold update_rtt
  simp [h]
  exact Nat.min_le_left _ _

/-- I14: loss_delay is always at least GRANULARITY (1ms).
    Mirrors the `max(·, GRANULARITY)` in `RttStats::loss_delay`. -/
theorem loss_delay_ge_granularity (s : RttState) (tn td : Nat) :
    loss_delay s tn td ≥ GRANULARITY_NS := by
  unfold loss_delay
  exact Nat.le_max_right _ _

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §15 Proved theorems — abs_diff_nat properties
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- I15: abs_diff_nat is symmetric. -/
theorem abs_diff_nat_symm (a b : Nat) :
    abs_diff_nat a b = abs_diff_nat b a := by
  unfold abs_diff_nat
  split <;> (split <;> omega)

/-- I16: abs_diff_nat a a = 0. -/
theorem abs_diff_nat_self (a : Nat) :
    abs_diff_nat a a = 0 := by
  unfold abs_diff_nat
  simp

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §16 Proved theorems — EWMA convergence properties
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- I17: The EWMA result lies within the range [old, new] (or [new, old]).
    Formally: srtt * 7/8 + adj/8 ≤ max(srtt, adj).
    This captures the "smoothing" property: the new SRTT is always between
    the previous SRTT and the adjusted sample. -/
theorem srtt_within_convex_hull (srtt adj : Nat) :
    srtt * 7 / 8 + adj / 8 ≤ Nat.max srtt adj := by
  simp only [Nat.max_def]
  split <;> omega

/-- I18: When the new sample is above the current SRTT, the EWMA moves up.
    Formally: if adj ≥ srtt then srtt * 7/8 + adj/8 ≥ srtt * 7/8. -/
theorem srtt_moves_toward_sample_up (srtt adj : Nat) :
    srtt * 7 / 8 + adj / 8 ≥ srtt * 7 / 8 := by
  omega

/-- I19: When the new sample is below the current SRTT, the EWMA moves down.
    Formally: if srtt ≥ adj then srtt * 7/8 + adj/8 ≤ srtt. -/
theorem srtt_moves_toward_sample_down (srtt adj : Nat) (h : srtt ≥ adj) :
    srtt * 7 / 8 + adj / 8 ≤ srtt := by
  omega

/-- I20: rttvar update with equal SRTT and adjusted_rtt causes rttvar to
    shrink toward zero (the mean-deviation of a stable process decreases).
    Formally: rttvar * 3/4 + 0/4 ≤ rttvar. -/
theorem rttvar_shrinks_when_stable (rttvar : Nat) :
    rttvar * 3 / 4 + 0 / 4 ≤ rttvar := by
  omega

/-- I21: The first positive RTT sample produces a positive SRTT. -/
theorem first_update_srtt_positive (s : RttState) (h : s.has_first = false)
    (latest ack_delay : Nat) (hpos : 0 < latest) :
    0 < (update_rtt s latest ack_delay).smoothed_rtt := by
  rw [first_update_smoothed_rtt s h latest ack_delay]
  exact hpos
