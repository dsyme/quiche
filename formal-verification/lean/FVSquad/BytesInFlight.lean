-- Copyright (C) 2025, Cloudflare, Inc.
-- BSD-2-Clause licence (same as quiche)
--
-- Formal specification of `BytesInFlight` from
-- `quiche/src/recovery/bytes_in_flight.rs`.
--
-- Model: time is abstracted as `Nat` (monotone ticks).
--        Duration is also `Nat`.
--        `Instant` → `Nat`, `Duration` → `Nat`.
--
-- Omitted: system-clock specifics, `pub(crate)` visibility,
--          `Default` derive.

namespace BytesInFlight

-- ─── State ─────────────────────────────────────────────────────────────────

structure State where
  bytes       : Nat          -- current bytes in flight
  startTime   : Option Nat   -- interval start; None ↔ bytes = 0
  openDur     : Nat          -- duration of the current open interval
  closedDur   : Nat          -- sum of all closed interval durations

def State.initial : State := ⟨0, none, 0, 0⟩

-- ─── Operations ────────────────────────────────────────────────────────────

def updateDuration (s : State) (now : Nat) : State :=
  match s.startTime with
  | none => s
  | some t =>
    if s.bytes = 0 then
      { s with
        openDur   := 0
        closedDur := s.closedDur + (now - t)
        startTime := none }
    else
      { s with openDur := now - t }

def add (s : State) (delta : Nat) (now : Nat) : State :=
  if delta = 0 then s
  else
    let s' := { s with bytes := s.bytes + delta }
    if s.startTime.isSome then
      updateDuration s' now
    else
      { s' with startTime := some now }

def saturating_subtract (s : State) (delta : Nat) (now : Nat) : State :=
  let s' := { s with bytes := s.bytes - (min delta s.bytes) }
  updateDuration s' now

-- ─── Accessors ─────────────────────────────────────────────────────────────

def get (s : State) : Nat := s.bytes

def is_zero (s : State) : Bool := s.bytes == 0

def get_duration (s : State) : Nat := s.closedDur + s.openDur

-- ─── Invariant ─────────────────────────────────────────────────────────────

def wf (s : State) : Prop :=
  (s.bytes = 0 ↔ s.startTime = none)

-- ─── Theorems ──────────────────────────────────────────────────────────────

-- 1. Initial state is well-formed and zero
theorem initial_wf : wf State.initial := by
  simp [wf, State.initial]

theorem initial_bytes_zero : State.initial.bytes = 0 := rfl

-- 2. `get` returns `bytes`
theorem get_eq (s : State) : get s = s.bytes := rfl

-- 3. `is_zero` iff `bytes = 0`
theorem is_zero_iff (s : State) : is_zero s = true ↔ s.bytes = 0 := by
  simp [is_zero]

-- 4. `get_duration` = closedDur + openDur
theorem get_duration_eq (s : State) :
    get_duration s = s.closedDur + s.openDur := rfl

-- 5. `add` with delta = 0 is a no-op
theorem add_zero_noop (s : State) (now : Nat) : add s 0 now = s := by
  simp [add]

-- 6. `add` with delta > 0 increases bytes
theorem add_increases_bytes (s : State) (delta : Nat) (now : Nat)
    (h : delta > 0) :
    (add s delta now).bytes = s.bytes + delta := by
  unfold add updateDuration
  rw [if_neg (Nat.pos_iff_ne_zero.mp h)]
  rcases s.startTime with _ | t
  · simp [Option.isSome]
  · simp [Option.isSome]
    rw [if_neg (by omega : ¬(s.bytes = 0 ∧ delta = 0))]

-- 7. `add` opens interval when previously idle
theorem add_opens_interval (s : State) (delta : Nat) (now : Nat)
    (hd : delta > 0) (hidle : s.startTime = none) :
    (add s delta now).startTime = some now := by
  unfold add
  rw [if_neg (Nat.pos_iff_ne_zero.mp hd)]
  simp [hidle, Option.isSome]

-- 8. `add` keeps existing start time when already active
theorem add_keeps_start (s : State) (delta : Nat) (now : Nat) (t : Nat)
    (hd : delta > 0) (hactive : s.startTime = some t) :
    (add s delta now).startTime = some t := by
  unfold add updateDuration
  rw [if_neg (Nat.pos_iff_ne_zero.mp hd)]
  simp [hactive, Option.isSome]
  rw [if_neg (by omega : ¬(s.bytes = 0 ∧ delta = 0))]

-- 9. `saturating_subtract` never goes below zero
theorem sub_nonneg (s : State) (delta : Nat) (now : Nat) :
    (saturating_subtract s delta now).bytes ≤ s.bytes := by
  unfold saturating_subtract updateDuration
  rcases s.startTime with _ | t
  · dsimp; omega
  · dsimp
    by_cases h : s.bytes - min delta s.bytes = 0
    · rw [if_pos h]; dsimp; omega
    · rw [if_neg h]; dsimp; omega

-- 10. `saturating_subtract` with delta ≥ bytes sets bytes to 0
theorem sub_to_zero (s : State) (delta : Nat) (now : Nat)
    (h : s.bytes ≤ delta) :
    (saturating_subtract s delta now).bytes = 0 := by
  unfold saturating_subtract updateDuration
  rcases s.startTime with _ | t
  · dsimp; omega
  · dsimp
    have h0 : s.bytes - min delta s.bytes = 0 := by omega
    rw [if_pos h0]; dsimp; omega

-- 11. `is_zero` reflects `get = 0`
theorem is_zero_iff_get (s : State) : is_zero s = true ↔ get s = 0 := by
  simp [is_zero, get]

-- 12. Well-formedness is preserved by `add` (idle → active case)
theorem add_wf_idle (s : State) (delta : Nat) (now : Nat)
    (hidle : s.startTime = none) (hd : delta > 0) :
    wf (add s delta now) := by
  unfold wf add
  rw [if_neg (Nat.pos_iff_ne_zero.mp hd)]
  simp [hidle, Option.isSome]
  intro; omega

-- 13. Well-formedness is preserved by `add` (active → active case)
theorem add_wf_active (s : State) (delta : Nat) (now : Nat) (t : Nat)
    (hw : wf s) (hactive : s.startTime = some t) :
    wf (add s delta now) := by
  unfold wf add
  by_cases hd : delta = 0
  · rw [if_pos hd]; exact hw
  · rw [if_neg hd]
    simp [hactive, Option.isSome]
    unfold updateDuration; simp [hactive]
    rw [if_neg (by omega : ¬(s.bytes = 0 ∧ delta = 0))]
    simp; omega

-- 14. `get_duration` unchanged when adding to idle state
theorem add_duration_idle (s : State) (delta : Nat) (now : Nat)
    (h : s.startTime = none) (hd : delta > 0) :
    get_duration (add s delta now) = get_duration s := by
  unfold get_duration add
  rw [if_neg (Nat.pos_iff_ne_zero.mp hd)]
  simp [h, Option.isSome]

-- 15. `saturating_subtract` to zero records the open interval duration
theorem sub_to_zero_records_duration (s : State) (now : Nat) (t : Nat)
    (hactive : s.startTime = some t) :
    (saturating_subtract s s.bytes now).closedDur =
      s.closedDur + (now - t) := by
  unfold saturating_subtract updateDuration
  simp [hactive]

-- 16. `add` followed by `saturating_subtract` of same amount: bytes unchanged
theorem add_sub_cancel (s : State) (delta : Nat) (now1 now2 : Nat)
    (hidle : s.startTime = none) (hd : delta > 0) :
    (saturating_subtract (add s delta now1) delta now2).bytes = s.bytes := by
  have hbytes : (add s delta now1).bytes = s.bytes + delta :=
    add_increases_bytes s delta now1 hd
  have hstart : (add s delta now1).startTime = some now1 :=
    add_opens_interval s delta now1 hd hidle
  unfold saturating_subtract updateDuration
  rw [hstart, hbytes]
  simp
  by_cases h : s.bytes = 0
  · rw [if_pos h]
  · rw [if_neg h]

-- ─── Examples (smoke tests) ────────────────────────────────────────────────

#eval
  let s0 := State.initial
  let s1 := add s0 10 0
  let s2 := add s1 5  5
  let s3 := saturating_subtract s2 8 7
  let s4 := saturating_subtract s3 7 10
  -- after subtracting all bytes, closedDur should be 10 (0..10)
  (get s4, get_duration s4)
-- expected: (0, 10)

#eval
  let s0 := State.initial
  let s1 := add s0 1 0
  let s2 := saturating_subtract s1 1 7
  -- open second interval
  let s3 := add s2 10 30
  let s4 := saturating_subtract s3 10 35
  -- closed dur = 7 + 5 = 12
  (get s4, get_duration s4)
-- expected: (0, 12)

end BytesInFlight
