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
- **Phase**: 5 — COMPLETE (23 theorems, 0 sorry as of run 30)
- **Lean file**: `FVSquad/RttStats.lean`
- **Informal spec**: `specs/rtt_informal.md`
- **Key theorems**:
  - `adjusted_rtt_ge_min_rtt`: KEY security property (ack-delay attack prevention)
  - `rtt_update_min_rtt_le_latest`: min_rtt ≤ latest_rtt invariant
  - `rtt_update_max_rtt_ge_prev`: max_rtt non-decreasing
  - `rtt_update_smoothed_pos`: smoothed_rtt > 0 preservation
  - `ewma_floor_sum` (run 30): a * 7/8 + a/8 ≤ a — EWMA partition lemma
  - `rtt_update_latest_rtt_eq` (run 30): update records new sample
  - `rtt_update_has_first_true` (run 30): has_first_rtt is sticky
  - `rtt_update_smoothed_upper_bound` (run 30): smoothed ≤ max(prev, latest)
  - `rtt_update_min_rtt_inv` (run 30): min_rtt ≤ latest_rtt joint invariant
- **PR**: lean-squad-run30-23927792642 (pending)
- **Next**: Write informal spec + Lean spec for flow control (Tasks 2+3)

### 5. Flow control window arithmetic
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 1 — Research identified
- **Priority**: HIGH (next main target)

## Open PRs / Branches
- `lean-squad-run30-23927792642` — run 30:
  5 new EWMA bounding theorems for RttStats + CORRESPONDENCE.md update

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
- `cases h : st.has_first_rtt <;> simp [rtt_update, h]` works for
  unconditional theorems about rtt_update (both branches)
- `omega` handles `a * 7 / 8 + a / 8 ≤ a` and similar floor-div arithmetic
  with constant denominators
- Bool struct field inheritance: `{ st with f := v }` inherits all fields
  not listed; `simp [rtt_update, h]` properly evaluates Bool conditions
  like `!st.has_first_rtt` when `h : st.has_first_rtt = true/false`

## TARGETS.md / CORRESPONDENCE.md / CRITIQUE.md
- All three in `formal-verification/`
- CORRESPONDENCE.md updated in run 30: header refresh, has_first_rtt note,
  5 new theorems documented, total count 62
- TARGETS.md: accurate as of run 29 (no update needed in run 30)
- CRITIQUE.md: not yet written (has_critique = false in phase_flags)

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox). Document failure each run.
- FVSquad.lean imports: Varint, RangeSet, Minmax, RttStats (as of run 29)
- Concrete example check: rtt_update with srtt=120ms gives (120, 45, 100, 130)
  — verified via #eval in RttStats.lean

## Next Priorities
1. Write informal spec for Flow control (Task 2): `quiche/src/flowcontrol.rs`
2. Write Lean spec for Flow control (Task 3)
3. Task 7 (Proof Utility Critique) — create CRITIQUE.md with assessment of
   all 62 theorems across 4 files
