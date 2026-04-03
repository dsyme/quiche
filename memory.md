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
- **PR**: #22 (merged)

### 3. WindowedMinimum running-minimum algorithm
- **File**: `quiche/src/minmax.rs`
- **Lean file**: `FVSquad/Minmax.lean`
- **Phase**: 5 — COMPLETE (15 theorems, 0 sorry)
- **PR**: #15 (merged)

### 4. RTT estimator
- **File**: `quiche/src/recovery/rtt.rs` — `RttStats::update_rtt`
- **Phase**: 5 — COMPLETE (26 theorems, 0 sorry)
- **Lean file**: `FVSquad/RttStats.lean`
- **Informal spec**: `specs/rtt_informal.md`
- **Key theorems**:
  - `adjusted_rtt_ge_min_rtt`: KEY security property (ack-delay attack prevention)
  - `rtt_update_smoothed_le_max_prev_adj`: EWMA contraction theorem
  - `rtt_update_rttvar_upper_bound`: rttvar growth bound
- **PR**: #23 (merged) + run 31 PR pending

### 5. Flow control window arithmetic
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 5 — COMPLETE (18 theorems, 0 sorry) — added run 31
- **Lean file**: `FVSquad/FlowControl.lean`
- **Informal spec**: `specs/flowcontrol_informal.md`
- **Key theorems**:
  - `fc_no_update_needed_after_update`: should_update = false after update
  - `fc_max_data_next_ge_consumed`: limit ≥ consumed always
  - `fc_new_inv`, `fc_update_preserves_inv`: window ≤ max_window invariant
- **PR**: `lean-squad-flowcontrol-rtt-run30-23927792618` (pending)

## Open PRs / Branches
- `lean-squad-flowcontrol-rtt-run30-23927792618` — run 31:
  FlowControl (18 theorems) + RttStats §6 EWMA proofs (8 new, 26 total)

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available without Mathlib/Std — use `Nat.lt_or_ge`
- `split_ifs` NOT available without Std — use `by_cases`
- `push_neg` NOT available — use `by omega` instead
- `simp only [range_insert_go.eq_def]` LOOPS — use `unfold range_insert_go`
- `List.mem_cons_self` takes NO explicit args (zero explicit args)
- Bool `=` precedence trap: `||` has precedence 30, `=` has 50
- Bool AC tactic: generalize Bool atoms, `cases bA <;> ... <;> rfl`
- `lemma` keyword NOT available in Lean 4.29 without Mathlib — use `theorem`
- omega CANNOT handle two-variable floor division like `a*7/8 + b/8 ≤ a` (b ≤ a)
  SOLUTION: helper theorems `ewma_le_prev`, `ewma_le_next` using single-var omega
- omega CANNOT bridge Nat.max (function app `d`) and if-expression `c` even when
  definitionally equal. SOLUTION: use `Nat.le_trans` with `Nat.le_max_left/right`
- `Nat.sub_le : n - k ≤ n` — available in Lean 4 core
- `abs_diff a b ≤ Nat.max a b` — use Nat.le_trans with Nat.sub_le and Nat.le_max_*
- `Nat.div_le_div_right` does NOT take a Nat argument as first arg in Lean 4.29
  — use omega with the bound hypothesis instead

## TARGETS.md / CORRESPONDENCE.md
- TARGETS.md: all 5 targets at Phase 5
- CORRESPONDENCE.md: updated run 31 (all 5 targets documented)
- CRITIQUE.md: NOT YET WRITTEN — priority for next run (Task 7)

## Status Issue: #4 (open), updated run 31

## Summary
- **83 total theorems, 0 sorry** across 5 files
- Varint.lean: 10 | RangeSet.lean: 14 | Minmax.lean: 15 | RttStats.lean: 26 | FlowControl.lean: 18

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox). Document failure each run.
- FVSquad.lean imports: Varint, RangeSet, Minmax, RttStats, FlowControl

## Next Priorities
1. Task 7 (Proof Utility Critique) — write CRITIQUE.md
2. Identify next FV target (e.g., congestion window in recovery/, or stream-level flow control)
3. FlowControl: add autotune_window model (time-as-parameter abstraction)
