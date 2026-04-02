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
- **Key theorems proved**: `insert_covers_union` (proved in run 26!),
  `remove_until_removes_small`, `remove_until_preserves_large`,
  `remove_until_preserves_invariant`
- **PRs**: #7 (spec), #9 (impl), #11 (partial proofs), #15 (more proofs),
  run-26 PR pending (proves insert_covers_union, adds FlowControl)
- **Notable**: `insert_covers_union` proved without `sorted_disjoint` precondition;
  `insert_preserves_invariant` still sorry — requires generalised accumulator invariant
- **New helpers added**: `merge_covers_union`, `insert_go_covers_gen`,
  `covers_append`, `bool_eq_iff`

### 3. WindowedMinimum running-minimum algorithm
- **File**: `quiche/src/minmax.rs`
- **Lean file**: `FVSquad/Minmax.lean`
- **Phase**: 5 — COMPLETE (15 public + 3 private theorems, 0 sorry)
- **PR**: #15 (merged)

### 4. RTT estimator
- **File**: `quiche/src/recovery/rtt.rs` — `RttStats::update_rtt`
- **Phase**: 1 — Research identified, no spec yet
- **Priority**: HIGH — security-sensitive, affects congestion control
- **Target properties**: min_rtt monotone, smoothed_rtt bounded, rttvar ≥ 0

### 5. Flow control window arithmetic
- **File**: `quiche/src/flowcontrol.rs`
- **Lean file**: `FVSquad/FlowControl.lean`
- **Phase**: 5 — COMPLETE (7 theorems, 0 sorry)
- **PR**: run-26 PR pending
- **Theorems**: C1a-C1e (invariant preservation), C2 (update_sets_max_data),
  C3 (max_data_next_correct), C4 (should_update_iff), C5 (monotone_consumed),
  C6 (ensure_lower_bound_ge), C7 (set_window_clamp)
- **Informal spec**: `specs/flowcontrol_informal.md`

## Open PRs / Branches
- `lean-squad/flowcontrol-rangeset-proofs-run26` — run 26 work:
  FlowControl complete spec + proof, insert_covers_union proved in RangeSet

## Key Lean 4.29.0 Learnings
- `simp only [range_insert_go.eq_def]` LOOPS — use `unfold range_insert_go`
- `List.mem_cons_self` takes NO explicit args
- `covers (l1 ++ l2) n = (covers l1 n || covers l2 n)` needs parens — else
  parsed as `(covers ... = covers ...) || covers ... n` (Bool precedence)
- `List.any_append` directly proves `covers_append` after parens fix
- `unfold covers; rw [List.any_append]` works; `simp [covers, List.any_append]` fails
- **Bool `=` precedence trap**: `(a || b) || c = a || (b || c)` is WRONG in Lean 4.29!
  `||` has precedence 30, `=` has precedence 50, so `||c = a||` parses as `||(c=a)||`
  making `(a || b) || c = a || (b || c)` parse as `((a||b)||(decide(c=a))||(b||c)) = true`!
  Always write `((a || b) || c) = (a || (b || c))` with explicit outer parens.
- **Bool AC tactic**: `simp [Bool.or_comm, Bool.or_left_comm]` loops/fails for complex goals.
  Use `generalize (...expr...) = bX` for each Bool atom, then `cases bA <;> ... <;> rfl`
- **generalize expression matching**: uses syntactic matching — must use exact term form.
  `List.any acc_rev f` ≠ `(List.reverse acc_rev).any f`; inspect post-simp goal form.
- **h2 simp set**: must include `List.any_append` to fully split `(l1 ++ l2).any f`
  Otherwise simp unfolds `covers` first, producing `(l1++l2).any f` which blocks splitting
- `if_pos/if_neg simp`: NEVER pass `if_pos hs` and `if_neg hs` in same simp call —
  use `by_cases hs <;> simp only [if_pos hs]` / `simp only [if_neg hs]` in separate branches
- `fc_should_update` must use `decide (...)` wrapper for clean Bool/Prop conversion
- For `fc_ensure_lower_bound`: use `by_cases h : m > fc.window` then handle each case

## CRITIQUE.md / TARGETS.md / CORRESPONDENCE.md
- All three in `formal-verification/`; CRITIQUE.md added in run 24

## Next Priorities
1. Prove `insert_preserves_invariant` in RangeSet — needs generalised accumulator
   invariant: acc_rev.reverse is sorted_disjoint and all elements end ≤ current s
2. Write RTT estimator spec (phase 2→5)
3. Start ConnectionState machine as new target
