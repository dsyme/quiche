-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of the Minmax windowed filter
-- in `quiche/src/minmax.rs`.
--
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- Kathleen Nichols' algorithm for tracking the minimum (or maximum)
-- value of a data stream over some fixed time interval.  Maintains
-- three samples (best, 2nd best, 3rd best) to ensure coverage even
-- as old values age out of the window.
--
-- Approximations / abstractions:
--   - Time is modelled as `Nat` (monotonically increasing counter)
--     rather than `std::time::Instant`.  Duration comparisons are
--     replaced with Nat inequality.
--   - `subwin_update` quarter/half-window sampling logic is modelled
--     in full for the time-elapsed cases but not the fractional
--     arithmetic (div_f32).  See §5 notes.
--   - Values are generic `Nat` (min filter only).  The max filter is
--     dual and shares the same invariant structure.
--   - Mutation is replaced by functional update; the Rust `&mut self`
--     is modelled as returning the new state.

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §1  Model types
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- A single (time, value) sample.
    Corresponds to `MinmaxSample<T>` in `quiche/src/minmax.rs`. -/
structure Sample where
  time  : Nat
  value : Nat
  deriving Repr, DecidableEq

/-- The Minmax filter state: three samples [best, 2nd-best, 3rd-best].
    Corresponds to `Minmax<T>.estimate` in `quiche/src/minmax.rs`. -/
structure MinmaxState where
  s0 : Sample   -- best (current minimum)
  s1 : Sample   -- 2nd best
  s2 : Sample   -- 3rd best (oldest / weakest)
  deriving Repr

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §2  Invariants
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- The value ordering invariant: the best estimate has the smallest value.
    I.e., s0.value ≤ s1.value ≤ s2.value.
    This holds after every `reset` or `running_min` call. -/
def min_val_inv (st : MinmaxState) : Prop :=
  st.s0.value ≤ st.s1.value ∧ st.s1.value ≤ st.s2.value

/-- The time ordering invariant: measurement times are non-decreasing.
    s0.time ≤ s1.time ≤ s2.time.
    This holds after every update that monotonically advances time. -/
def time_ordered (st : MinmaxState) : Prop :=
  st.s0.time ≤ st.s1.time ∧ st.s1.time ≤ st.s2.time

/-- After `reset`, all three samples are identical.
    The Rust code sets `estimate[0] = estimate[1] = estimate[2] = val`. -/
def all_equal (st : MinmaxState) : Prop :=
  st.s0 = st.s1 ∧ st.s1 = st.s2

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §3  Operations
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Reset all estimates to the given sample.
    Returns the value of estimate[0] (which equals `meas`).
    Corresponds to `Minmax::reset` in `quiche/src/minmax.rs`. -/
def minmax_reset (time meas : Nat) : MinmaxState × Nat :=
  let s := Sample.mk time meas
  (MinmaxState.mk s s s, meas)

/-- Simplified `subwin_update`: model only the "full window elapsed" case.
    The quarter/half-window sampling (which requires fractional arithmetic)
    is approximated: we pass a Boolean flag `quarter_elapsed` and
    `half_elapsed` derived from the caller.
    Returns the new state and best estimate.
    Corresponds to `Minmax::subwin_update` in `quiche/src/minmax.rs`. -/
def minmax_subwin_update
    (st : MinmaxState)
    (time meas : Nat)
    (full_win_elapsed quarter_elapsed half_elapsed : Bool)
    : MinmaxState × Nat :=
  let newSample := Sample.mk time meas
  if full_win_elapsed then
    -- Entire window elapsed — rotate: 0←1, 1←2, 2←new
    let st1 := { st with s0 := st.s1, s1 := st.s2, s2 := newSample }
    -- May need to rotate again if new s0 is also stale
    let st2 :=
      if full_win_elapsed then
        { st1 with s0 := st1.s1, s1 := st1.s2, s2 := newSample }
      else
        st1
    (st2, st2.s0.value)
  else if quarter_elapsed then
    -- Passed a quarter window; take 2nd estimate from 2nd quarter
    let st1 := { st with s2 := newSample, s1 := newSample }
    (st1, st1.s0.value)
  else if half_elapsed then
    -- Passed half window; take 3rd estimate from last half
    let st1 := { st with s2 := newSample }
    (st1, st1.s0.value)
  else
    (st, st.s0.value)

/-- Running minimum filter update.
    Returns (new_state, best_min_estimate).
    Corresponds to `Minmax::running_min` in `quiche/src/minmax.rs`.

    The `win_elapsed` flag represents `delta_time > win` for estimate[2].
    The `full_win_elapsed`, `quarter_elapsed`, `half_elapsed` flags are for
    the subwin_update call. -/
def minmax_running_min
    (st : MinmaxState)
    (time meas : Nat)
    (win_elapsed full_win_elapsed quarter_elapsed half_elapsed : Bool)
    : MinmaxState × Nat :=
  let newSample := Sample.mk time meas
  -- Reset if: new min OR entire old window expired
  if meas ≤ st.s0.value || win_elapsed then
    minmax_reset time meas
  else
    -- Update 2nd and/or 3rd estimates
    let st1 :=
      if meas ≤ st.s1.value then
        { st with s2 := newSample, s1 := newSample }
      else if meas ≤ st.s2.value then
        { st with s2 := newSample }
      else
        st
    minmax_subwin_update st1 time meas full_win_elapsed quarter_elapsed half_elapsed

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §4  Concrete verification with native_decide
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Based on `reset_filter_rtt` / `reset_filter_bandwidth` test cases.
-- (Time values are `Nat`; durations in ms are represented as raw Nat.)

-- After reset, all three estimates equal the initial value.
example : (minmax_reset 0 50).1.s0 = ⟨0, 50⟩ := by native_decide
example : (minmax_reset 0 50).1.s1 = ⟨0, 50⟩ := by native_decide
example : (minmax_reset 0 50).1.s2 = ⟨0, 50⟩ := by native_decide
-- Return value equals meas.
example : (minmax_reset 0 50).2 = 50 := by native_decide

-- running_min: new smaller value causes reset.
-- Analogous to `get_windowed_min_rtt`: reset at 25ms, then new min 24ms.
example :
    let st0 := (minmax_reset 0 25).1
    let (st1, ret) := minmax_running_min st0 250 24 false false false false
    ret = 24 ∧ st1.s0.value = 24 ∧ st1.s1.value = 24 ∧ st1.s2.value = 24 :=
  by native_decide

-- running_min: larger value doesn't beat best; does update 2nd/3rd.
-- Analogous to `get_windowed_min_estimates_rtt`: init 23, then 24 (larger).
example :
    let st0 := (minmax_reset 0 23).1
    -- 24 > 23, so best stays 23; 24 ≤ s1.value=23 is false;
    -- 24 ≤ s2.value=23 is false; no estimate updated pre-subwin.
    -- win_elapsed=false so no reset; let all subwin flags false.
    let (st1, ret) := minmax_running_min st0 300 24 false false false false
    ret = 23 ∧ st1.s0.value = 23 := by native_decide

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §5  Key theorems
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- ---------------------------------------------------------------------------
-- Reset theorems (all proved)
-- ---------------------------------------------------------------------------

/-- R1: `reset` returns the measurement value. -/
theorem reset_returns_meas (time meas : Nat) :
    (minmax_reset time meas).2 = meas := by
  simp [minmax_reset]

/-- R2: `reset` makes all three estimates equal the new sample. -/
theorem reset_all_equal (time meas : Nat) :
    all_equal (minmax_reset time meas).1 := by
  simp [minmax_reset, all_equal]

/-- R3: `reset` establishes the value ordering invariant (trivially — all equal). -/
theorem reset_min_val_inv (time meas : Nat) :
    min_val_inv (minmax_reset time meas).1 := by
  simp [minmax_reset, min_val_inv]

/-- R4: `reset` establishes the time ordering invariant. -/
theorem reset_time_ordered (time meas : Nat) :
    time_ordered (minmax_reset time meas).1 := by
  simp [minmax_reset, time_ordered]

/-- R5: After `reset`, estimate[0].value = meas. -/
theorem reset_s0_value (time meas : Nat) :
    (minmax_reset time meas).1.s0.value = meas := by
  simp [minmax_reset]

/-- R6: After `reset`, all estimates have the same timestamp. -/
theorem reset_s0_time (time meas : Nat) :
    (minmax_reset time meas).1.s0.time = time := by
  simp [minmax_reset]

-- ---------------------------------------------------------------------------
-- Running-min theorems — reset branch (proved)
-- ---------------------------------------------------------------------------

/-- M1: If `meas ≤ current_best`, `running_min` returns `meas` (via reset). -/
theorem running_min_new_min_returns_meas
    (st : MinmaxState) (time meas : Nat)
    (h : meas ≤ st.s0.value)
    (full_win quarter half : Bool) :
    (minmax_running_min st time meas false full_win quarter half).2 = meas := by
  simp [minmax_running_min, h, minmax_reset]

/-- M2: If `meas ≤ current_best`, `running_min` resets all estimates to `meas`. -/
theorem running_min_new_min_all_equal
    (st : MinmaxState) (time meas : Nat)
    (h : meas ≤ st.s0.value)
    (full_win quarter half : Bool) :
    all_equal (minmax_running_min st time meas false full_win quarter half).1 := by
  simp [minmax_running_min, h, minmax_reset, all_equal]

/-- M3: If `win_elapsed = true`, `running_min` resets all estimates. -/
theorem running_min_win_elapsed_all_equal
    (st : MinmaxState) (time meas : Nat)
    (full_win quarter half : Bool) :
    all_equal (minmax_running_min st time meas true full_win quarter half).1 := by
  simp [minmax_running_min, minmax_reset, all_equal]

/-- M4: If `win_elapsed = true`, `running_min` returns `meas`. -/
theorem running_min_win_elapsed_returns_meas
    (st : MinmaxState) (time meas : Nat)
    (full_win quarter half : Bool) :
    (minmax_running_min st time meas true full_win quarter half).2 = meas := by
  simp [minmax_running_min, minmax_reset]

-- ---------------------------------------------------------------------------
-- Running-min theorems — non-reset, no-subwin branch
-- ---------------------------------------------------------------------------

/-- M5: If `meas > s0.value` (no reset) and all subwin flags false,
    the best estimate is unchanged. -/
theorem running_min_best_unchanged
    (st : MinmaxState) (time meas : Nat)
    (h_no_reset : ¬(meas ≤ st.s0.value)) :
    (minmax_running_min st time meas false false false false).1.s0 = st.s0 := by
  simp [minmax_running_min, minmax_subwin_update, h_no_reset]
  by_cases h1 : meas ≤ st.s1.value
  · simp [h1]
  · simp [h1]
    by_cases h2 : meas ≤ st.s2.value
    · simp [h2]
    · simp [h2]

-- Helper for M6: subwin_update's return value equals the s0 of the new state.
private theorem subwin_snd_eq_fst_s0
    (st : MinmaxState) (time meas : Nat) (fw q h : Bool) :
    (minmax_subwin_update st time meas fw q h).2 =
    (minmax_subwin_update st time meas fw q h).1.s0.value := by
  unfold minmax_subwin_update
  by_cases hfw : fw
  · simp [hfw]
  · simp [hfw]
    by_cases hq : q
    · simp [hq]
    · simp [hq]
      by_cases hh : h
      · simp [hh]
      · simp [hh]

/-- M6: `running_min` always returns the s0 value of the resulting state. -/
theorem running_min_returns_s0
    (st : MinmaxState) (time meas : Nat)
    (win full_win quarter half : Bool) :
    (minmax_running_min st time meas win full_win quarter half).2 =
    (minmax_running_min st time meas win full_win quarter half).1.s0.value := by
  unfold minmax_running_min
  by_cases h_reset : meas ≤ st.s0.value
  · simp [h_reset, minmax_reset]
  · simp [h_reset]
    by_cases hw : win
    · simp [hw, minmax_reset]
    · simp [hw]
      by_cases h1 : meas ≤ st.s1.value
      · simp only [h1, ite_true]
        exact subwin_snd_eq_fst_s0 _ _ _ _ _ _
      · simp only [h1, ite_false]
        by_cases h2 : meas ≤ st.s2.value
        · simp only [h2, ite_true]
          exact subwin_snd_eq_fst_s0 _ _ _ _ _ _
        · simp only [h2, ite_false]
          exact subwin_snd_eq_fst_s0 _ _ _ _ _ _

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §6  Invariant preservation
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- P1: `reset` establishes min_val_inv (already proved as R3, repeated for
    completeness in this section). -/
theorem reset_establishes_inv (time meas : Nat) :
    min_val_inv (minmax_reset time meas).1 :=
  reset_min_val_inv time meas

/-- P2: If `running_min` takes the reset branch (new min or window expired),
    `min_val_inv` holds after the update. -/
theorem running_min_reset_preserves_inv
    (st : MinmaxState) (time meas : Nat)
    (win full_win quarter half : Bool)
    (h_reset : meas ≤ st.s0.value ∨ win = true) :
    min_val_inv (minmax_running_min st time meas win full_win quarter half).1 := by
  cases h_reset with
  | inl h =>
      simp [minmax_running_min, h, minmax_reset, min_val_inv]
  | inr h =>
      simp [minmax_running_min, minmax_reset, min_val_inv, h]

/-- P3: The min_val_inv is preserved when `meas > s0.value`, `meas ≤ s1.value`
    (2nd and 3rd estimates updated to meas), and no subwin flags are set.
    In this case: s0 unchanged, s1 = s2 = new sample with value `meas`.
    Invariant: s0.value ≤ meas (from ¬(meas ≤ s0.value)) ∧ meas ≤ meas ✓ -/
theorem running_min_update_s1_s2_preserves_inv
    (st : MinmaxState) (time meas : Nat)
    (h_inv : min_val_inv st)
    (h_no_reset : ¬(meas ≤ st.s0.value))
    (h_s1 : meas ≤ st.s1.value) :
    min_val_inv
      (minmax_running_min st time meas false false false false).1 := by
  simp [minmax_running_min, minmax_subwin_update, min_val_inv]
  simp [h_no_reset, h_s1]
  omega

