-- Copyright (C) 2024, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/IdleTimeout.lean
--
-- Formal verification of idle_timeout() negotiation
-- Source: quiche/src/lib.rs:8757
--
-- The idle_timeout() function computes the negotiated idle timeout from
-- two transport parameters and the current PTO estimate:
--   - If both are 0, timeout is disabled (None).
--   - If one is 0, use the other.
--   - If both nonzero, use the minimum (RFC 9000 §10.1.1).
--   - Clamp up to max(base, 3 × pto) for PTO safety.

namespace IdleTimeout

/-! ## Model -/

/-- Pure model of `idle_timeout()`.
    `loc` and `peer` are `max_idle_timeout` transport parameters in ms (0 = disabled).
    `pto` is the current probe timeout in ms.
    Returns `none` iff both peers disabled idle timeout. -/
def idleTimeout (loc peer pto : Nat) : Option Nat :=
  if loc == 0 && peer == 0 then none
  else
    let base :=
      if loc == 0 then peer
      else if peer == 0 then loc
      else min loc peer
    some (max base (3 * pto))

/-! ## Basic structure -/

/-- Returns None iff both parameters are zero. -/
theorem idleTimeout_none_iff (loc peer pto : Nat) :
    idleTimeout loc peer pto = none ↔ loc = 0 ∧ peer = 0 := by
  unfold idleTimeout
  simp only [Bool.and_eq_true, beq_iff_eq]
  constructor
  · intro h
    by_cases h1 : loc = 0 <;> by_cases h2 : peer = 0 <;> simp_all
  · intro ⟨h1, h2⟩
    simp [h1, h2]

/-- When both are nonzero, result is Some. -/
theorem idleTimeout_some_of_nonzero (loc peer pto : Nat)
    (hl : loc ≠ 0) (hp : peer ≠ 0) :
    (idleTimeout loc peer pto).isSome = true := by
  simp [idleTimeout, hl, hp, Nat.ne_of_gt, beq_iff_eq]

/-- When loc is zero but peer nonzero, result is Some peer (clamped). -/
theorem idleTimeout_local_zero (peer pto : Nat) (hp : peer ≠ 0) :
    idleTimeout 0 peer pto = some (max peer (3 * pto)) := by
  simp [idleTimeout, hp]

/-- When peer is zero but loc nonzero, result is Some loc (clamped). -/
theorem idleTimeout_peer_zero (loc pto : Nat) (hl : loc ≠ 0) :
    idleTimeout loc 0 pto = some (max loc (3 * pto)) := by
  simp [idleTimeout, hl]

/-- When both nonzero, result is min of the two (clamped). -/
theorem idleTimeout_both_nonzero (loc peer pto : Nat)
    (hl : loc ≠ 0) (hp : peer ≠ 0) :
    idleTimeout loc peer pto = some (max (min loc peer) (3 * pto)) := by
  simp [idleTimeout, hl, hp]

/-! ## RFC 9000 §10.1.1 compliance -/

/-- The result is always ≥ 3 × PTO (when timeout is enabled). -/
theorem idleTimeout_ge_3pto (loc peer pto : Nat)
    {t : Nat} (h : idleTimeout loc peer pto = some t) :
    3 * pto ≤ t := by
  unfold idleTimeout at h
  by_cases h1 : loc = 0 <;> by_cases h2 : peer = 0 <;> simp_all <;> omega

/-- The result is ≤ max of the two parameters when pto = 0. -/
theorem idleTimeout_le_max_params (loc peer : Nat)
    {t : Nat} (ht : idleTimeout loc peer 0 = some t) :
    t ≤ max loc peer := by
  unfold idleTimeout at ht
  by_cases h1 : loc = 0 <;> by_cases h2 : peer = 0 <;> simp_all <;> omega

/-- When enabled, result is ≥ min of the two nonzero parameters. -/
theorem idleTimeout_ge_min_nonzero (loc peer pto : Nat)
    (hl : loc ≠ 0) (hp : peer ≠ 0) {t : Nat}
    (ht : idleTimeout loc peer pto = some t) :
    min loc peer ≤ t := by
  simp [idleTimeout, hl, hp] at ht
  rw [← ht]
  omega

/-- Result equals loc when peer = 0 and pto = 0. -/
theorem idleTimeout_at_most_local (loc : Nat) (hl : loc ≠ 0) :
    idleTimeout loc 0 0 = some loc := by
  simp [idleTimeout, hl]

/-- Result equals peer when loc = 0 and pto = 0. -/
theorem idleTimeout_at_most_peer (peer : Nat) (hp : peer ≠ 0) :
    idleTimeout 0 peer 0 = some peer := by
  simp [idleTimeout, hp]

/-! ## Commutativity -/

/-- Negotiation is symmetric: swapping loc/peer gives the same result. -/
theorem idleTimeout_comm (loc peer pto : Nat) :
    idleTimeout loc peer pto = idleTimeout peer loc pto := by
  unfold idleTimeout
  by_cases h1 : loc = 0 <;> by_cases h2 : peer = 0 <;> simp_all [Nat.min_comm]

/-! ## Monotonicity -/

/-- Increasing PTO can only increase (or maintain) the result. -/
theorem idleTimeout_mono_pto (loc peer pto₁ pto₂ : Nat)
    (h : pto₁ ≤ pto₂) {t₁ t₂ : Nat}
    (h1 : idleTimeout loc peer pto₁ = some t₁)
    (h2 : idleTimeout loc peer pto₂ = some t₂) :
    t₁ ≤ t₂ := by
  unfold idleTimeout at h1 h2
  by_cases ha : loc = 0 <;> by_cases hb : peer = 0 <;> simp_all <;> omega

/-! ## Concrete examples -/

#eval idleTimeout 0 0 100    -- none
#eval idleTimeout 5000 0 100 -- some 5000
#eval idleTimeout 0 3000 100 -- some 3000
#eval idleTimeout 5000 3000 100 -- some 3000
#eval idleTimeout 1000 2000 500 -- some 1500 (3*500=1500 > min=1000)

end IdleTimeout
