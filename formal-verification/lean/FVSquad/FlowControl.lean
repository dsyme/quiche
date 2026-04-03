-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of the QUIC flow-control window
-- in `quiche/src/flowcontrol.rs`.
--
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- The module covers:
--   §1  Model types and invariant
--   §2  Constructor
--   §3  Core operations (pure functional model)
--   §4  Window management helpers
--   §5  Key theorems — invariant preservation and arithmetic properties
--
-- Approximations / abstractions:
--   - `u64` is modelled as `Nat` (unbounded); overflow is not captured.
--     In practice QUIC limits all byte offsets to 2^62-1, so overflow is
--     unreachable on compliant connections.
--   - `Instant` and `Duration` arithmetic (used by `autotune_window`) are
--     replaced by an abstract boolean parameter `should_tune : Bool` that
--     represents whether `now − last_update < rtt * 2`.
--   - `last_update : Option Instant` is abstracted to `tuned : Bool`
--     (whether `last_update.is_some()`).
--   - Mutation is replaced by pure functional update (new record values).
--   - `add_consumed` does not bounds-check against `max_data`; the caller
--     is responsible (QUIC protocol guarantee).

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §1  Model types and invariant
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- The flow-control window state.
    Corresponds to `FlowControl` in `quiche/src/flowcontrol.rs`. -/
structure FcState where
  /-- Bytes consumed (received) so far. -/
  consumed   : Nat
  /-- Current flow-control limit advertised to the peer. -/
  max_data   : Nat
  /-- Receive-window size used for computing `max_data` updates. -/
  window     : Nat
  /-- Maximum window size; `window ≤ max_window` always. -/
  max_window : Nat
  /-- Whether `last_update` has been set (i.e., `update_max_data` was
      ever called).  Abstracts `Option<Instant>`. -/
  tuned      : Bool
  deriving Repr

/-- The fundamental window invariant: window is capped by max_window. -/
def fc_inv (s : FcState) : Prop :=
  s.window ≤ s.max_window

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §2  Constructor
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Corresponds to `FlowControl::new(max_data, window, max_window)`.
    Note: `window` is clamped to `max_window`. -/
def fc_new (max_data window max_window : Nat) : FcState :=
  { consumed   := 0
    max_data   := max_data
    window     := Nat.min window max_window
    max_window := max_window
    tuned      := false }

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §3  Core operations
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Increase consumed bytes.
    Corresponds to `add_consumed`. -/
def fc_add_consumed (s : FcState) (delta : Nat) : FcState :=
  { s with consumed := s.consumed + delta }

/-- Returns `true` when a window update should be sent.
    Corresponds to `should_update_max_data`. -/
def fc_should_update (s : FcState) : Bool :=
  (s.max_data - s.consumed) < (s.window / 2)

/-- The proposed new `max_data` limit.
    Corresponds to `max_data_next`. -/
def fc_max_data_next (s : FcState) : Nat :=
  s.consumed + s.window

/-- Commit the new `max_data` limit.
    Corresponds to `update_max_data`. -/
def fc_update_max_data (s : FcState) : FcState :=
  { s with
    max_data := fc_max_data_next s
    tuned    := true }

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §4  Window management helpers
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Internal: set window, clamping to max_window.
    Corresponds to `set_window`. -/
def fc_set_window (s : FcState) (w : Nat) : FcState :=
  { s with window := Nat.min w s.max_window }

/-- Double the window (clamped) if `should_tune` is true.
    Corresponds to `autotune_window` with the timing condition abstracted. -/
def fc_autotune_window (s : FcState) (should_tune : Bool) : FcState :=
  if should_tune && s.tuned then
    fc_set_window s (s.window * 2)
  else
    s

/-- Set window only if not yet tuned.
    Corresponds to `set_window_if_not_tuned_yet`. -/
def fc_set_window_if_not_tuned (s : FcState) (w : Nat) : FcState :=
  if !s.tuned then
    fc_set_window s w
  else
    s

/-- Raise the window lower bound.
    Corresponds to `ensure_window_lower_bound`. -/
def fc_ensure_window_lower_bound (s : FcState) (min_window : Nat) : FcState :=
  if min_window > s.window then
    fc_set_window s min_window
  else
    s

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §5  Key theorems
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- ── §5.1  Constructor correctness ──────────────────────────────────────

/-- The constructor establishes the window invariant. -/
theorem fc_new_inv (max_data window max_window : Nat) :
    fc_inv (fc_new max_data window max_window) := by
  unfold fc_inv fc_new
  simp [Nat.min_le_right]

/-- The constructor sets consumed to zero. -/
theorem fc_new_consumed_zero (max_data window max_window : Nat) :
    (fc_new max_data window max_window).consumed = 0 := by
  unfold fc_new; rfl

/-- The constructor clamps window to max_window. -/
theorem fc_new_window_le_max (max_data window max_window : Nat) :
    (fc_new max_data window max_window).window ≤ max_window := by
  unfold fc_new; simp [Nat.min_le_right]

-- ── §5.2  `set_window` preserves invariant ─────────────────────────────

/-- `set_window` always re-establishes the invariant. -/
theorem fc_set_window_inv (s : FcState) (w : Nat) :
    fc_inv (fc_set_window s w) := by
  unfold fc_inv fc_set_window
  simp [Nat.min_le_right]

-- ── §5.3  `add_consumed` preserves invariant ──────────────────────────

/-- `add_consumed` does not change window or max_window, so it preserves
    the invariant. -/
theorem fc_add_consumed_preserves_inv
    (s : FcState) (delta : Nat) (h : fc_inv s) :
    fc_inv (fc_add_consumed s delta) := by
  unfold fc_inv fc_add_consumed at *
  exact h

-- ── §5.4  `update_max_data` preserves invariant ────────────────────────

/-- `update_max_data` preserves the window invariant. -/
theorem fc_update_preserves_inv (s : FcState) (h : fc_inv s) :
    fc_inv (fc_update_max_data s) := by
  unfold fc_inv fc_update_max_data at *
  exact h

-- ── §5.5  `autotune_window` preserves invariant ────────────────────────

/-- Autotuning preserves the window invariant. -/
theorem fc_autotune_preserves_inv
    (s : FcState) (should_tune : Bool) (h : fc_inv s) :
    fc_inv (fc_autotune_window s should_tune) := by
  unfold fc_autotune_window
  split
  · exact fc_set_window_inv s (s.window * 2)
  · exact h

-- ── §5.6  `should_update` after `update_max_data` ─────────────────────

/-- After `update_max_data`, `should_update` returns `false`.

    Proof: the new available window is `window`, and `window < window / 2`
    is false (since `window ≥ window / 2` for all `Nat`). -/
theorem fc_no_update_needed_after_update (s : FcState) :
    fc_should_update (fc_update_max_data s) = false := by
  unfold fc_should_update fc_update_max_data fc_max_data_next
  simp
  omega

-- ── §5.7  `max_data_next` is at least consumed ─────────────────────────

/-- The new limit is always at least as large as the consumed count. -/
theorem fc_max_data_next_ge_consumed (s : FcState) :
    fc_max_data_next s ≥ s.consumed := by
  unfold fc_max_data_next
  omega

-- ── §5.8  `should_update` — trigger condition is tight ────────────────

/-- `should_update` is `true` exactly when `available < window / 2`.
    This theorem unfolds the definition for clarity. -/
theorem fc_should_update_iff (s : FcState) :
    fc_should_update s = true ↔ (s.max_data - s.consumed) < (s.window / 2) := by
  unfold fc_should_update
  simp [decide_eq_true_eq]

-- ── §5.9  `ensure_window_lower_bound` correctness ────────────────────

/-- After `ensure_window_lower_bound`, the window is at least
    `min(min_window, max_window)`. -/
theorem fc_ensure_lb_ge (s : FcState) (min_window : Nat) (_ : fc_inv s) :
    (fc_ensure_window_lower_bound s min_window).window ≥
      Nat.min min_window s.max_window := by
  unfold fc_ensure_window_lower_bound fc_set_window
  by_cases hlt : min_window > s.window
  · simp [hlt]
  · simp [hlt]
    have hle : min_window ≤ s.window := Nat.le_of_not_gt hlt
    exact Nat.le_trans (Nat.min_le_left _ _) hle

/-- `ensure_window_lower_bound` preserves the invariant. -/
theorem fc_ensure_lb_preserves_inv
    (s : FcState) (min_window : Nat) (h : fc_inv s) :
    fc_inv (fc_ensure_window_lower_bound s min_window) := by
  unfold fc_ensure_window_lower_bound
  by_cases hlt : min_window > s.window
  · simp [hlt]; exact fc_set_window_inv s min_window
  · simp [hlt]; exact h

-- ── §5.10  `set_window_if_not_tuned` preserves invariant ──────────────

/-- Setting the window only when not yet tuned preserves the invariant. -/
theorem fc_set_window_if_not_tuned_inv
    (s : FcState) (w : Nat) (h : fc_inv s) :
    fc_inv (fc_set_window_if_not_tuned s w) := by
  unfold fc_set_window_if_not_tuned
  by_cases ht : !s.tuned
  · simp [ht]; exact fc_set_window_inv s w
  · simp [ht]; exact h

-- ── §5.11  Monotone consumed under add_consumed ───────────────────────

/-- `add_consumed` is monotone: consumed only increases. -/
theorem fc_consumed_monotone (s : FcState) (delta : Nat) :
    (fc_add_consumed s delta).consumed ≥ s.consumed := by
  simp [fc_add_consumed]

-- ── §5.12  Window does not change on `add_consumed` ──────────────────

/-- `add_consumed` does not change the window. -/
theorem fc_add_consumed_window_unchanged (s : FcState) (delta : Nat) :
    (fc_add_consumed s delta).window = s.window := by
  unfold fc_add_consumed; rfl

-- ── §5.13  `max_data` after `update_max_data` ────────────────────────

/-- After `update_max_data`, `max_data = consumed + window`. -/
theorem fc_update_max_data_eq (s : FcState) :
    (fc_update_max_data s).max_data = s.consumed + s.window := by
  unfold fc_update_max_data fc_max_data_next; rfl

-- ── §5.14  `max_data_next` strictly exceeds `max_data` when updating ──

/-- When `should_update` is true, the new limit strictly exceeds the
    current one.

    Proof: `should_update` ↔ `max_data − consumed < window / 2`,
    which implies `max_data < consumed + window / 2 ≤ consumed + window`. -/
theorem fc_max_data_next_gt_when_should_update
    (s : FcState) (h : fc_should_update s = true) :
    fc_max_data_next s > s.max_data := by
  unfold fc_should_update at h
  simp at h
  unfold fc_max_data_next
  omega

-- ── §5.15  Idempotence of `update_max_data` ──────────────────────────

/-- Calling `update_max_data` twice in a row (without changing `consumed`)
    is idempotent: the second call produces the same state as the first.

    This holds because after the first update `max_data = consumed + window`,
    so `max_data_next` on the result equals the existing `max_data`. -/
theorem fc_update_idempotent (s : FcState) :
    fc_update_max_data (fc_update_max_data s) =
      fc_update_max_data s := by
  unfold fc_update_max_data fc_max_data_next
  simp

-- ── §5.16  Autotune does not change consumed or max_data ─────────────

/-- Autotuning only changes `window`; it does not touch `consumed` or
    `max_data`. -/
theorem fc_autotune_consumed_unchanged
    (s : FcState) (should_tune : Bool) :
    (fc_autotune_window s should_tune).consumed = s.consumed := by
  unfold fc_autotune_window fc_set_window
  by_cases ht : (should_tune && s.tuned) = true <;> simp [ht]

theorem fc_autotune_max_data_unchanged
    (s : FcState) (should_tune : Bool) :
    (fc_autotune_window s should_tune).max_data = s.max_data := by
  unfold fc_autotune_window fc_set_window
  by_cases ht : (should_tune && s.tuned) = true <;> simp [ht]

-- ── §5.17  Window after autotune ─────────────────────────────────────

/-- When the state is already tuned and `should_tune` fires, the window
    is set to the doubled value clamped by `max_window`. -/
theorem fc_autotune_window_when_tuned
    (s : FcState) (ht : s.tuned = true) :
    (fc_autotune_window s true).window = Nat.min (s.window * 2) s.max_window := by
  unfold fc_autotune_window fc_set_window
  simp [ht]

/-- When `should_tune` is false or the state is not yet tuned, the
    window is unchanged by autotuning. -/
theorem fc_autotune_window_unchanged
    (s : FcState) (should_tune : Bool)
    (h : should_tune = false ∨ s.tuned = false) :
    (fc_autotune_window s should_tune).window = s.window := by
  unfold fc_autotune_window
  rcases h with hs | ht
  · simp [hs]
  · simp [ht, Bool.and_false]

-- ── §5.18  Example: construction then update ─────────────────────────

/-- Concrete example matching the Rust test `update_max_data`. -/
example :
    let fc := fc_new 100 20 100
    let fc1 := fc_add_consumed fc 95
    let fc2 := fc_update_max_data fc1
    fc2.max_data = 115 := by
  native_decide
