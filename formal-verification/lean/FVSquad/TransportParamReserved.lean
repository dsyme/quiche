-- Copyright (c) 2025, Lean Squad (automated FV).
-- SPDX-License-Identifier: BSD-2-Clause

/-!
# RFC 9000 §18.1 Reserved Transport Parameter IDs

Models and verifies `UnknownTransportParameter::is_reserved` from
`quiche/src/transport_params.rs`.

RFC 9000 §18.1 reserves transport parameter IDs of the form `31 * N + 27`
for N ≥ 0, i.e. the arithmetic progression {27, 58, 89, 120, ...}.

## Rust source

```rust
pub fn is_reserved(&self) -> bool {
    let n = (self.id - 27) / 31;
    self.id == 31 * n + 27
}
```

where `self.id : u64`.

## Lean model

We model `id` as a `Nat` (natural number), which saturates at zero rather
than wrapping like `u64`.  For all `id ≥ 27` the two semantics agree, so the
proved properties are valid in that region, which covers all legitimate QUIC
transport parameter IDs.

## Approximations / omissions

* Wrapping underflow for `id < 27` in u64 is NOT modelled; the Lean model
  uses saturating `Nat` subtraction, which correctly returns `false` for
  `id < 27`.
* `self.id` is modelled as a plain `Nat`; no struct wrapper.
-/

/-- RFC 9000 §18.1 reserved-ID predicate (direct translation of Rust logic). -/
def isReserved (id : Nat) : Bool :=
  let n := (id - 27) / 31   -- Nat subtraction saturates to 0 when id < 27
  id == 31 * n + 27

/-- Equivalent characterisation: id is a multiple of 31 shifted by 27. -/
def isReservedAlt (id : Nat) : Bool :=
  (id + 4) % 31 == 0         -- 27 % 31 = 27, and 27 + 4 = 31

-- ────────────────────────────────────────────────────────────────────────────
-- 1. Decidable spot-checks (proved by `decide`)
-- ────────────────────────────────────────────────────────────────────────────

theorem isReserved_27 : isReserved 27 = true := by decide
theorem isReserved_58 : isReserved 58 = true := by decide
theorem isReserved_89 : isReserved 89 = true := by decide
theorem isReserved_120 : isReserved 120 = true := by decide
theorem isReserved_0_false : isReserved 0 = false := by decide
theorem isReserved_1_false : isReserved 1 = false := by decide
theorem isReserved_26_false : isReserved 26 = false := by decide
theorem isReserved_31_false : isReserved 31 = false := by decide
theorem isReserved_57_false : isReserved 57 = false := by decide

-- ────────────────────────────────────────────────────────────────────────────
-- 2. Arithmetic core: isReserved ↔ mod-31 condition
-- ────────────────────────────────────────────────────────────────────────────

/-- The reserved-ID condition is equivalent to `id % 31 = 27` for `id ≥ 27`. -/
theorem isReserved_iff_mod (id : Nat) (h : 27 ≤ id) :
    isReserved id = true ↔ id % 31 = 27 := by
  simp only [isReserved, beq_iff_eq]
  constructor
  · intro heq
    have hge : 31 * ((id - 27) / 31) + 27 ≤ id := by omega
    have hmod : (id - 27) % 31 = 0 := by
      have : id - 27 = 31 * ((id - 27) / 31) := by omega
      omega
    omega
  · intro hmod
    have hsub : id - 27 = 31 * ((id - 27) / 31) := by
      have : (id - 27) % 31 = 0 := by omega
      omega
    omega

/-- Contrapositive: if `id % 31 ≠ 27` (and `id ≥ 27`) then not reserved. -/
theorem isReserved_false_iff_mod (id : Nat) (h : 27 ≤ id) :
    isReserved id = false ↔ id % 31 ≠ 27 := by
  constructor
  · intro hf hm
    have : isReserved id = true := (isReserved_iff_mod id h).mpr hm
    simp [this] at hf
  · intro hne
    cases hb : isReserved id
    · rfl
    · exact absurd ((isReserved_iff_mod id h).mp hb) hne

-- ────────────────────────────────────────────────────────────────────────────
-- 3. Every arithmetic-progression element `31 * k + 27` is reserved
-- ────────────────────────────────────────────────────────────────────────────

/-- All members of the reserved arithmetic progression are detected. -/
theorem isReserved_progression (k : Nat) : isReserved (31 * k + 27) = true := by
  have hge : 27 ≤ 31 * k + 27 := by omega
  rw [isReserved_iff_mod _ hge]
  omega

/-- No element between consecutive reserved values is reserved (gap lemma). -/
theorem isReserved_gap (k : Nat) (j : Nat) (hj : 0 < j) (hj2 : j < 31) :
    isReserved (31 * k + 27 + j) = false := by
  have hge : 27 ≤ 31 * k + 27 + j := by omega
  cases hb : isReserved (31 * k + 27 + j)
  · rfl
  · have := (isReserved_iff_mod _ hge).mp hb; omega

-- ────────────────────────────────────────────────────────────────────────────
-- 4. Equivalence with the alt formulation
-- ────────────────────────────────────────────────────────────────────────────

/-- The two formulations agree for `id ≥ 27`. -/
theorem isReserved_eq_alt (id : Nat) (h : 27 ≤ id) :
    isReserved id = isReservedAlt id := by
  simp only [isReservedAlt]
  by_cases hm : id % 31 = 27
  · have : isReserved id = true := (isReserved_iff_mod id h).mpr hm
    simp [this]
    omega
  · have : isReserved id = false := by
      cases hb : isReserved id
      · rfl
      · exact absurd ((isReserved_iff_mod id h).mp hb) hm
    simp [this]
    omega

-- ────────────────────────────────────────────────────────────────────────────
-- 5. Spacing invariant: reserved IDs are at least 31 apart
-- ────────────────────────────────────────────────────────────────────────────

/-- Two distinct reserved IDs differ by at least 31. -/
theorem isReserved_spacing (a b : Nat) (ha : 27 ≤ a) (hb : 27 ≤ b)
    (hres_a : isReserved a = true) (hres_b : isReserved b = true)
    (hne : a ≠ b) : 31 ≤ (max a b) - (min a b) := by
  rw [isReserved_iff_mod a ha] at hres_a
  rw [isReserved_iff_mod b hb] at hres_b
  simp [Nat.max_def, Nat.min_def]
  split <;> omega
