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
- **Phase**: 5 — 1 sorry remaining (insert_preserves_invariant)
- **Key theorems proved**: `insert_covers_union` (proved in run 27!),
  `remove_until_removes_small`, `remove_until_preserves_large`,
  `remove_until_preserves_invariant`
- **PR**: run-27 PR pending
- **Notable**: `insert_covers_union` proved using `range_insert_go_covers_gen`
  (generalised accumulator induction, no sorted_disjoint needed).
  New helpers: `covers_append`, `merge_in_range_prop`, `merge_in_range_bool`,
  `if_lt_eq_min`, `if_gt_eq_max`, `bool_eq_iff_iff`, `in_range_iff_prop`
- **Still open**: `insert_preserves_invariant` — needs accumulator invariant:
  acc_rev.reverse is sorted_disjoint and all elements end ≤ current s

### 3. WindowedMinimum running-minimum algorithm
- **File**: `quiche/src/minmax.rs`
- **Lean file**: `FVSquad/Minmax.lean`
- **Phase**: 5 — COMPLETE (15 public + 3 private theorems, 0 sorry)
- **PR**: #15 (merged)

### 4. RTT estimator
- **File**: `quiche/src/recovery/rtt.rs` — `RttStats::update_rtt`
- **Phase**: 2 — Informal spec written (run 27)
- **Informal spec**: `specs/rtt_informal.md`
- **Priority**: HIGH — security-sensitive, affects congestion control
- **Target properties**: min_rtt monotone, smoothed_rtt bounded, rttvar ≥ 0,
  adjusted_rtt ≥ min_rtt, max_rtt monotone non-decreasing
- **Key open question**: Is max_rtt field safety-critical or diagnostic only?

### 5. Flow control window arithmetic
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 1 — Research identified
- **Priority**: MEDIUM

## Open PRs / Branches
- `lean-squad-rtt-rangeset-run27-23894233778` — run 27:
  insert_covers_union proved, RTT informal spec

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available without Mathlib/Std — use `Nat.lt_or_ge`
- `split_ifs` NOT available without Std — use `by_cases`
- `push_neg` NOT available — use `Nat.not_lt.mp h`
- `simp only [covers, List.any]` unfolds acc_rev.reverse open terms, breaking
  `generalize`. Use `have` lemmas for specific list coverage computations,
  do NOT unfold `covers acc_rev.reverse n` or `covers rest n`.
- `simp only [range_insert_go.eq_def]` LOOPS — use `unfold range_insert_go`
- `List.mem_cons_self` takes NO explicit args
- Bool `=` precedence trap in Lean 4.29: `||` has precedence 30, `=` has 50
- Bool algebra goals: generalize each Bool atom, then `cases bX <;> ... <;> rfl`
- `if_pos/if_neg simp`: NEVER pass both in same simp call
- `in_range (s, e) n = (s ≤ n && n < e)` is `rfl` (definitional)
- `covers (r :: rs) n = (in_range r n || covers rs n)` is `rfl`
- `covers_append`: unfold covers; rw [List.any_append] works
- `Nat.min_eq_left h : min a b = a` when `h : a ≤ b`
- `Nat.min_eq_right h : min a b = b` when `h : b ≤ a`
- `Nat.max_eq_left h : max a b = a` when `h : b ≤ a`
- `Nat.max_eq_right h : max a b = b` when `h : a ≤ b`

## CRITIQUE.md / TARGETS.md / CORRESPONDENCE.md
- All three in `formal-verification/`; CRITIQUE.md added in run 24

## Next Priorities
1. Prove `insert_preserves_invariant` in RangeSet (Task 5)
   - Key insight: need lemma: if acc_rev satisfies sorted_disjoint and all
     elements end ≤ s, and (s,e) merges with (rs,re), then result preserves
     sorted_disjoint with correct bounds
2. Write Lean spec for RTT estimator (Task 3)
   - Pure arithmetic: Duration modelled as Nat (nanoseconds)
   - Key theorems: smoothed_rtt_pos, rttvar_nonneg, min_rtt_le_latest_rtt
3. Write informal spec for Flow control (Task 2)
