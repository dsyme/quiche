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
- **Phase**: 5 — COMPLETE (24 theorems, 0 sorry)
- **Lean file**: `FVSquad/RttStats.lean`
- **Informal spec**: `specs/rtt_informal.md`
- **Key theorems**:
  - `adjusted_rtt_ge_min_rtt`: KEY security property (ack-delay attack prevention)
  - `rtt_update_smoothed_upper_bound`: EWMA contraction theorem
  - `rtt_update_min_rtt_inv`: joint invariant min_rtt ≤ latest_rtt
- **PR**: #23 (merged)

### 5. Flow control window arithmetic
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 5 — COMPLETE (22 theorems, 0 sorry) — added run 32
- **Lean file**: `FVSquad/FlowControl.lean`
- **Informal spec**: `specs/flowcontrol_informal.md`
- **Key theorems**:
  - `fc_no_update_needed_after_update`: should_update=false after update
  - `fc_max_data_next_gt_when_should_update`: limit strictly grows
  - `fc_update_idempotent`: double update is no-op
  - `fc_autotune_window_when_tuned`: window = min(window*2, max_window)
- **PR**: `lean-squad-flowcontrol-critique-run32-23932599559` (pending)

### 6. Congestion window
- **File**: `quiche/src/recovery/congestion/`
- **Phase**: 1 — IDENTIFIED
- **Target properties**: window grows on ACK, halves on loss, ≥ min_cwnd
- **Notes**: Start with CUBIC or NewReno (simpler); see CRITIQUE.md

## Open PRs / Branches
- `lean-squad-flowcontrol-critique-run32-23932599559` — run 32:
  FlowControl (22 theorems) + flowcontrol_informal.md + CRITIQUE.md

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available without Mathlib/Std — use `Nat.lt_or_ge`
- `split_ifs` NOT available without Std — use `split` on if-expressions
- `push_neg` NOT available — use `Nat.le_of_not_gt` or `omega` instead
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
- `simp [ht]` on Bool if-then-else: when `ht : cond = true`, simp closes the
  whole goal if nothing remains (don't add `exact ...` after)
- `by_cases ht : Bool_expr = true` + `simp [ht]` works for if-then-else dispatch
- Record field access after `unfold` may not reduce for omega;
  use `simp [def_name]` first to project fields
- `split` tactic works on if-then-else in the goal (better than by_cases for
  preserving goal structure)
- `decide_eq_true_eq` is the right simp lemma for `decide P = true ↔ P`
  (NOT `Bool.decide_eq_true`)

## TARGETS.md / CORRESPONDENCE.md / CRITIQUE.md
- TARGETS.md: 5 targets at Phase 5, Target 6 identified
- CORRESPONDENCE.md: updated run 30 (all 5 targets documented)
- CRITIQUE.md: WRITTEN — run 32 (105 theorems assessed)

## Status Issue: #4 (open), updated run 32

## Summary
- **85 total theorems, 0 sorry** across 5 files
- Varint.lean: 10 | RangeSet.lean: 14 | Minmax.lean: 15 | RttStats.lean: 24 | FlowControl.lean: 22
- Note: RttStats theorem count in source shows 24 (not 26 from memory stale state)

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox). Document failure each run.
- FVSquad.lean imports: Varint, RangeSet, Minmax, RttStats, FlowControl

## Next Priorities
1. Target 6: congestion window — write informal spec for `recovery/congestion/`
2. FlowControl: u64 overflow guard (add bounded model, prove no overflow under 2^62 limit)
3. RangeSet semantic completeness — prove flatten(insert(rs,r)) = set_union
4. RTT lower bounds — prove smoothed_rtt ≥ min_rtt after first sample
