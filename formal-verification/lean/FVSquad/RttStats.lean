-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of the RTT estimator
-- in `quiche/src/recovery/rtt.rs`.
--
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- RFC 9002 §5 defines the algorithm: smoothed RTT (EWMA with weight 7/8)
-- and RTT variance (EWMA of |smoothed − adjusted| with weight 3/4).
-- The min_rtt is a sliding-window minimum (modelled here as an abstract
-- non-decreasing lower bound for tractability).
--
-- Approximations / abstractions:
--   - `Duration` is modelled as `Nat` (nanoseconds, unbounded).
--     u64/u128 overflow edge cases are not captured.
--   - `Instant` is modelled as `Nat` (monotone counter); not needed for
--     the arithmetic properties targeted here.
--   - `Minmax<Duration>` (the sliding-window minimum filter) is abstracted
--     away: `min_rtt` is modelled as a plain `Nat` that satisfies the
--     postcondition `min_rtt ≤ latest_rtt` after every update.
--     The windowing and three-sample Kathleen Nichols mechanism are omitted.
--   - All arithmetic uses Lean 4 `Nat` (natural number) division (floor),
--     matching Rust's integer division.
--   - Mutation is replaced by pure functional update.

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §1  Model types
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- The RTT estimator state.
    Corresponds to `RttStats` in `quiche/src/recovery/rtt.rs`. -/
structure RttState where
  /-- Most recently measured RTT sample (nanoseconds). -/
  latest_rtt    : Nat
  /-- Smoothed RTT — EWMA with weight 7/8 on history. -/
  smoothed_rtt  : Nat
  /-- RTT variance — EWMA of |smoothed − adjusted| with weight 3/4. -/
  rttvar        : Nat
  /-- Window minimum of raw RTT samples (ack-delay excluded). -/
  min_rtt       : Nat
  /-- All-time maximum RTT. -/
  max_rtt       : Nat
  /-- Maximum ack delay from peer TRANSPORT_PARAMETERS. -/
  max_ack_delay : Nat
  /-- True once the first RTT sample has been recorded. -/
  has_first_rtt : Bool
  deriving Repr

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §2  Constructor
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Initial RTT state.
    Corresponds to `RttStats::new(initial_rtt, max_ack_delay)`. -/
def rtt_init (initial_rtt : Nat) (max_ack_delay : Nat) : RttState :=
  { latest_rtt    := 0
    smoothed_rtt  := initial_rtt
    rttvar        := initial_rtt / 2
    min_rtt       := initial_rtt
    max_rtt       := initial_rtt
    max_ack_delay := max_ack_delay
    has_first_rtt := false }

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §3  Adjusted RTT computation
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Compute the adjusted RTT by subtracting the ack delay when plausible.
    Corresponds to the `adjusted_rtt` local variable in `update_rtt`.

    The adjustment is only applied if:
      `latest_rtt ≥ min_rtt + ack_delay`
    This prevents negative RTT estimates when the ack delay is suspiciously
    large relative to the observed RTT. -/
def adjusted_rtt_of
    (latest_rtt min_rtt ack_delay : Nat) : Nat :=
  if latest_rtt ≥ min_rtt + ack_delay then
    latest_rtt - ack_delay
  else
    latest_rtt

/-- Absolute difference of two natural numbers.
    Models `u128::abs_diff` used in the rttvar EWMA. -/
def abs_diff (a b : Nat) : Nat :=
  if a ≥ b then a - b else b - a

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §4  Update step
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- One RTT update step.
    Corresponds to `RttStats::update_rtt(latest_rtt, ack_delay, now, hc)`.

    Note: the Minmax windowing in `min_rtt.running_min(...)` is abstracted away.
    We model `min_rtt` as `Nat.min prev.min_rtt latest_rtt` (a plain minimum,
    not a sliding window).  This is a safe abstraction because the true
    sliding-window min satisfies `min_rtt ≤ latest_rtt`, which is the only
    property required by the proofs in §5. -/
def rtt_update
    (st             : RttState)
    (latest_rtt     : Nat)
    (ack_delay      : Nat)
    (handshake_confirmed : Bool)
    : RttState :=
  if !st.has_first_rtt then
    -- First sample: initialise everything from latest_rtt (ack_delay ignored)
    { st with
        latest_rtt    := latest_rtt
        smoothed_rtt  := latest_rtt
        rttvar        := latest_rtt / 2
        min_rtt       := latest_rtt
        max_rtt       := latest_rtt
        has_first_rtt := true }
  else
    -- Subsequent sample
    let min_rtt'  := Nat.min st.min_rtt latest_rtt
    let max_rtt'  := Nat.max st.max_rtt latest_rtt
    -- Clamp ack_delay by max_ack_delay after handshake confirmation
    let ack_del'  := if handshake_confirmed
                      then Nat.min ack_delay st.max_ack_delay
                      else ack_delay
    -- Plausibility-filtered adjusted RTT
    let adj_rtt   := adjusted_rtt_of latest_rtt min_rtt' ack_del'
    -- RTT variance: EWMA of |smoothed − adjusted|, weight 3/4 on history
    let rttvar'   := st.rttvar * 3 / 4 + abs_diff st.smoothed_rtt adj_rtt / 4
    -- Smoothed RTT: EWMA with weight 7/8 on history
    let srtt'     := st.smoothed_rtt * 7 / 8 + adj_rtt / 8
    { st with
        latest_rtt   := latest_rtt
        smoothed_rtt := srtt'
        rttvar       := rttvar'
        min_rtt      := min_rtt'
        max_rtt      := max_rtt' }

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §5  Key theorems
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- §5.1  Initialisation postconditions

/-- After construction, smoothed_rtt equals the initial estimate. -/
theorem rtt_init_smoothed_eq
    (r d : Nat) : (rtt_init r d).smoothed_rtt = r := by
  simp [rtt_init]

/-- After construction, rttvar equals half the initial estimate (integer div). -/
theorem rtt_init_rttvar_eq
    (r d : Nat) : (rtt_init r d).rttvar = r / 2 := by
  simp [rtt_init]

/-- After construction, has_first_rtt is false — no sample recorded yet. -/
theorem rtt_init_no_first_sample
    (r d : Nat) : (rtt_init r d).has_first_rtt = false := by
  simp [rtt_init]

/-- After construction with a positive initial_rtt, smoothed_rtt > 0. -/
theorem rtt_init_smoothed_pos
    (r d : Nat) (hr : 0 < r) : 0 < (rtt_init r d).smoothed_rtt := by
  simp [rtt_init, hr]

-- §5.2  First sample postconditions

/-- On the first update, smoothed_rtt is set to latest_rtt (ack_delay ignored). -/
theorem rtt_first_update_smoothed_eq
    (r d lr ad : Nat) (hc : Bool) :
    (rtt_update (rtt_init r d) lr ad hc).smoothed_rtt = lr := by
  simp [rtt_update, rtt_init]

/-- On the first update, rttvar = latest_rtt / 2. -/
theorem rtt_first_update_rttvar_eq
    (r d lr ad : Nat) (hc : Bool) :
    (rtt_update (rtt_init r d) lr ad hc).rttvar = lr / 2 := by
  simp [rtt_update, rtt_init]

/-- On the first update, min_rtt = latest_rtt. -/
theorem rtt_first_update_min_rtt_eq
    (r d lr ad : Nat) (hc : Bool) :
    (rtt_update (rtt_init r d) lr ad hc).min_rtt = lr := by
  simp [rtt_update, rtt_init]

/-- After the first update, has_first_rtt is true. -/
theorem rtt_first_update_has_first
    (r d lr ad : Nat) (hc : Bool) :
    (rtt_update (rtt_init r d) lr ad hc).has_first_rtt = true := by
  simp [rtt_update, rtt_init]

-- §5.3  Core arithmetic: adjusted_rtt_of

/-- **Key safety property**: adjusted_rtt ≥ min_rtt whenever min_rtt ≤ latest_rtt.
    This is the critical invariant that prevents negative EWMA inputs.
    In both branches of the plausibility check:
    - Branch 1 (latest ≥ min + delay): adjusted = latest − delay ≥ min  (arithmetic)
    - Branch 2 (latest < min + delay):  adjusted = latest ≥ min         (hypothesis) -/
theorem adjusted_rtt_ge_min_rtt
    (latest_rtt min_rtt ack_delay : Nat)
    (h : min_rtt ≤ latest_rtt) :
    min_rtt ≤ adjusted_rtt_of latest_rtt min_rtt ack_delay := by
  unfold adjusted_rtt_of
  split
  · -- Branch: latest_rtt ≥ min_rtt + ack_delay
    -- adjusted = latest_rtt − ack_delay; need min_rtt ≤ latest_rtt − ack_delay
    -- From hypothesis h1: latest_rtt ≥ min_rtt + ack_delay
    rename_i h1
    omega
  · -- Branch: latest_rtt < min_rtt + ack_delay
    -- adjusted = latest_rtt; need min_rtt ≤ latest_rtt — directly from h
    exact h

/-- adjusted_rtt never exceeds latest_rtt (the delay can only reduce it). -/
theorem adjusted_rtt_le_latest
    (latest_rtt min_rtt ack_delay : Nat) :
    adjusted_rtt_of latest_rtt min_rtt ack_delay ≤ latest_rtt := by
  unfold adjusted_rtt_of
  split
  · omega
  · -- adjusted = latest_rtt
    exact Nat.le_refl _

/-- adjusted_rtt_of with zero ack delay equals latest_rtt. -/
theorem adjusted_rtt_of_zero_delay
    (latest_rtt min_rtt : Nat) :
    adjusted_rtt_of latest_rtt min_rtt 0 = latest_rtt := by
  unfold adjusted_rtt_of
  split <;> omega

-- §5.4  abs_diff properties

/-- abs_diff is symmetric. -/
theorem abs_diff_comm (a b : Nat) :
    abs_diff a b = abs_diff b a := by
  unfold abs_diff
  split
  · split
    · omega
    · rfl
  · split
    · rfl
    · omega

/-- abs_diff a a = 0. -/
theorem abs_diff_self (a : Nat) : abs_diff a a = 0 := by
  unfold abs_diff
  simp

-- §5.5  Subsequent update: min_rtt and max_rtt monotonicity

/-- After a subsequent update, min_rtt is at most the new sample. -/
theorem rtt_update_min_rtt_le_latest
    (st : RttState) (lr ad : Nat) (hc : Bool)
    (h : st.has_first_rtt = true) :
    (rtt_update st lr ad hc).min_rtt ≤ lr := by
  simp [rtt_update, h]
  exact Nat.min_le_right _ _

/-- After a subsequent update, min_rtt is at most the previous min_rtt. -/
theorem rtt_update_min_rtt_le_prev
    (st : RttState) (lr ad : Nat) (hc : Bool)
    (h : st.has_first_rtt = true) :
    (rtt_update st lr ad hc).min_rtt ≤ st.min_rtt := by
  simp [rtt_update, h]
  exact Nat.min_le_left _ _

/-- After a subsequent update, max_rtt is at least the new sample. -/
theorem rtt_update_max_rtt_ge_latest
    (st : RttState) (lr ad : Nat) (hc : Bool)
    (h : st.has_first_rtt = true) :
    lr ≤ (rtt_update st lr ad hc).max_rtt := by
  simp [rtt_update, h]
  exact Nat.le_max_right _ _

/-- After a subsequent update, max_rtt is at least the previous max_rtt
    (max_rtt is non-decreasing). -/
theorem rtt_update_max_rtt_ge_prev
    (st : RttState) (lr ad : Nat) (hc : Bool)
    (h : st.has_first_rtt = true) :
    st.max_rtt ≤ (rtt_update st lr ad hc).max_rtt := by
  simp [rtt_update, h]
  exact Nat.le_max_left _ _

-- §5.6  smoothed_rtt positivity

/-- If the previous smoothed_rtt was positive and the new sample is positive,
    the updated smoothed_rtt remains positive.
    (Since Nat division floors toward 0, we need 7*prev ≥ 8 to avoid flooring
    to 0.  The guard `h_prev : 8 ≤ prev.smoothed_rtt` ensures this.) -/
theorem rtt_update_smoothed_pos
    (st : RttState) (lr ad : Nat) (hc : Bool)
    (h  : st.has_first_rtt = true)
    (h_prev : 8 ≤ st.smoothed_rtt) :
    0 < (rtt_update st lr ad hc).smoothed_rtt := by
  simp [rtt_update, h]
  -- smoothed = st.smoothed_rtt * 7 / 8 + adj_rtt / 8
  -- st.smoothed_rtt * 7 / 8 ≥ 7 since 8 ≤ st.smoothed_rtt
  -- So the sum is > 0.
  have h7 : 7 ≤ st.smoothed_rtt * 7 / 8 := by omega
  -- adj_rtt / 8 ≥ 0 trivially; sum ≥ 7 + 0 > 0
  omega

-- §5.7  EWMA floor arithmetic

/-- The weighted floor average of a number with itself is at most that number.
    Key arithmetic building block: `a * 7 / 8 + a / 8 ≤ a` for all `a : Nat`.
    This shows the EWMA coefficients 7/8 and 1/8 are a valid partition (sum ≤ 1
    under Nat floor division). -/
theorem ewma_floor_sum (a : Nat) : a * 7 / 8 + a / 8 ≤ a := by omega

-- §5.8  Per-update completeness

/-- Every call to `rtt_update` sets `latest_rtt` to the new sample.
    This holds unconditionally (both first-sample and subsequent-sample branches). -/
theorem rtt_update_latest_rtt_eq
    (st : RttState) (lr ad : Nat) (hc : Bool) :
    (rtt_update st lr ad hc).latest_rtt = lr := by
  cases h : st.has_first_rtt <;> simp [rtt_update, h]

/-- After any call to `rtt_update`, `has_first_rtt` is permanently `true`.
    Once a sample has been recorded the flag is never cleared. -/
theorem rtt_update_has_first_true
    (st : RttState) (lr ad : Nat) (hc : Bool) :
    (rtt_update st lr ad hc).has_first_rtt = true := by
  cases h : st.has_first_rtt <;> simp [rtt_update, h]

-- §5.9  EWMA upper bound

/-- The updated `smoothed_rtt` is bounded above by the maximum of the previous
    smoothed estimate and the new sample.

    Proof sketch (subsequent branch):
      `smoothed' = old * 7/8 + adj/8`
      where `adj ≤ latest_rtt` (plausibility filter can only reduce the sample).
      Since `a * 7/8 + b/8 ≤ max(a, b)` for any `a, b : Nat`,
      and `max(old, adj) ≤ max(old, latest_rtt)`, the bound follows. -/
theorem rtt_update_smoothed_upper_bound
    (st : RttState) (lr ad : Nat) (hc : Bool) :
    (rtt_update st lr ad hc).smoothed_rtt ≤ Nat.max st.smoothed_rtt lr := by
  cases h : st.has_first_rtt
  · -- First update: smoothed' = lr ≤ max(old, lr)
    simp [rtt_update, h]
    exact Nat.le_max_right _ _
  · -- Subsequent: smoothed' = old * 7/8 + adj/8 ≤ max(old, lr)
    simp [rtt_update, h]
    have h_adj_le : adjusted_rtt_of lr (Nat.min st.min_rtt lr)
                       (if hc then Nat.min ad st.max_ack_delay else ad) ≤ lr :=
      adjusted_rtt_le_latest _ _ _
    have h_sm : st.smoothed_rtt ≤ Nat.max st.smoothed_rtt lr :=
      Nat.le_max_left _ _
    have h_adj : adjusted_rtt_of lr (Nat.min st.min_rtt lr)
                     (if hc then Nat.min ad st.max_ack_delay else ad) ≤
                 Nat.max st.smoothed_rtt lr :=
      Nat.le_trans h_adj_le (Nat.le_max_right _ _)
    omega

-- §5.10  Combined invariant: min_rtt ≤ latest_rtt

/-- After any update, `min_rtt ≤ latest_rtt` holds as a joint property of the
    result state.  This invariant is the key safety property used by the
    plausibility filter in `adjusted_rtt_of`. -/
theorem rtt_update_min_rtt_inv
    (st : RttState) (lr ad : Nat) (hc : Bool) :
    (rtt_update st lr ad hc).min_rtt ≤
    (rtt_update st lr ad hc).latest_rtt := by
  rw [rtt_update_latest_rtt_eq]
  cases h : st.has_first_rtt
  · -- First update: min_rtt' = lr
    simp [rtt_update, h]
  · -- Subsequent: min_rtt' = Nat.min old lr ≤ lr
    exact rtt_update_min_rtt_le_latest st lr ad hc h

-- §5.11  Concrete example (sanity check via native_decide)

-- Verify Example 3 from the informal spec (nanosecond values):
-- State: smoothed_rtt=120ms, min_rtt=100ms, rttvar=60ms
-- update_rtt(130ms, 10ms, true)
-- Expected: ack_del'=10ms, adj_rtt=120ms, rttvar=45ms, srtt=120ms
private def ms := 1_000_000  -- nanoseconds per millisecond

#eval do
  let st : RttState := {
    latest_rtt    := 0
    smoothed_rtt  := 120 * ms
    rttvar        := 60 * ms
    min_rtt       := 100 * ms
    max_rtt       := 130 * ms
    max_ack_delay := 25 * ms
    has_first_rtt := true }
  let st' := rtt_update st (130 * ms) (10 * ms) true
  return (st'.smoothed_rtt / ms, st'.rttvar / ms,
          st'.min_rtt / ms, st'.max_rtt / ms)
-- Expected: (120, 45, 100, 130)

-- Verify: adjusted_rtt_ge_min_rtt for the plausibility check
example : adjusted_rtt_of (130 * ms) (100 * ms) (10 * ms) = 120 * ms := by
  native_decide

example : adjusted_rtt_of (105 * ms) (100 * ms) (20 * ms) = 105 * ms := by
  native_decide
