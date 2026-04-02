# Lean Squad Memory — dsyme/quiche

## Tool & Approach
- **FV tool**: Lean 4 (v4.29.0, no Mathlib)
- **Project**: `formal-verification/lean/` — `lake init FVSquad` (no Mathlib)
- **CI**: `.github/workflows/lean-ci.yml` (added in PR #15, merged)

## Targets

### 1. Varint encoding/decoding
- **File**: `quiche/src/octets.rs` (also `quiche/src/h3/mod.rs`)
- **Lean file**: `FVSquad/Varint.lean`
- **Phase**: 5 — COMPLETE (10 theorems, 0 sorry)
- **Key theorem**: `varint_round_trip` — decode(encode(v)) = v
- **PR**: #5 (merged)

### 2. RangeSet sorted-interval data structure
- **File**: `quiche/src/ranges.rs`
- **Lean file**: `FVSquad/RangeSet.lean`
- **Phase**: 5 — COMPLETE (14 theorems, 0 sorry)
- **All proved**: insert_preserves_invariant, insert_covers_union,
  remove_until_removes_small, remove_until_preserves_large,
  remove_until_preserves_invariant, and all structural lemmas
- **PR**: #22 (merged)

### 3. WindowedMinimum running-minimum algorithm
- **File**: `quiche/src/minmax.rs`
- **Lean file**: `FVSquad/Minmax.lean`
- **Phase**: 5 — COMPLETE (15 theorems, 0 sorry)
- **PR**: #15 (merged)

### 4. RTT estimator
- **File**: `quiche/src/recovery/rtt.rs` — `RttStats::update_rtt`
- **Phase**: 3 — Lean spec written (run 29); 18 theorems, 0 sorry
- **Lean file**: `FVSquad/RttStats.lean`
- **Informal spec**: `specs/rtt_informal.md`
- **Key theorems**:
  - `adjusted_rtt_ge_min_rtt`: KEY security property (ack-delay attack prevention)
  - `rtt_update_min_rtt_le_latest`: min_rtt ≤ latest_rtt invariant
  - `rtt_update_max_rtt_ge_prev`: max_rtt non-decreasing
  - `rtt_update_smoothed_pos`: smoothed_rtt > 0 preservation
- **PR**: `lean-squad-rtt-run29-23919941340` (pending merge)
- **Next**: EWMA convergence proofs, per-update invariant preservation chain

### 5. Flow control window arithmetic
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 1 — Research identified
- **Priority**: MEDIUM

## Open PRs / Branches
- `lean-squad-rtt-run29-23919941340` — run 29:
  RTT informal spec + Lean spec (18 theorems, 0 sorry) + CORRESPONDENCE.md update

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available without Mathlib/Std — use `Nat.lt_or_ge`
- `split_ifs` NOT available without Std — use `by_cases`
- `push_neg` NOT available — use arithmetic directly or omega
- `simp only [range_insert_go.eq_def]` LOOPS — use `unfold range_insert_go`
  OR `simp only [range_insert_go]` (the latter works)
- `List.mem_cons_self` takes NO explicit args (zero explicit args)
- Bool `=` precedence trap: `||` has precedence 30, `=` has 50
- Bool AC tactic: generalize Bool atoms, `cases bA <;> ... <;> rfl`
- `covers_append`: unfold covers; rw [List.any_append] works
- `sorted_disjoint_cons2_iff` as `@[simp]` works; but `rw [...]` fails when
  variable `s` in scope shadows pattern variable — use `simp only [...]`
- `List.mem_reverse.mp`: converts `r ∈ l.reverse → r ∈ l`
- For if-then-else proofs: `split <;> omega` often works cleanly
- `simp [ite_self]` closes `if p then a else a = a` goals
- `Nat.min_le_left a b : min a b ≤ a`, `Nat.min_le_right a b : min a b ≤ b`
- `Nat.le_max_left a b : a ≤ max a b`, `Nat.le_max_right a b : b ≤ max a b`
- After `simp [f, h]` closes a goal, subsequent `have h7 := by omega` gives
  "No goals to be solved" — detect this by removing the extra tactics

## TARGETS.md / CORRESPONDENCE.md / CRITIQUE.md
- All three in `formal-verification/`
- CORRESPONDENCE.md updated in run 29 with Minmax + RttStats sections
- TARGETS.md updated in run 29 to reflect accurate phases

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox). Document failure each run.
- FVSquad.lean imports: Varint, RangeSet, Minmax, RttStats (as of run 29)
- Concrete example check: rtt_update with srtt=120ms gives (120, 45, 100, 130)
  — verified via #eval in RttStats.lean

## Next Priorities
1. Expand RTT proofs (Task 5): EWMA step invariant, invariant preservation chain
   after multiple updates, prove `smoothed_rtt_pos` without the 8ns guard
2. Write informal spec + Lean spec for Flow control (Tasks 2+3)
3. Task 7 (Proof Utility Critique) — update CRITIQUE.md with RttStats findings
