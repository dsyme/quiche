# Lean Squad Memory — dsyme/quiche

## Tool & Approach
- **FV tool**: Lean 4 (v4.29.0, no Mathlib)
- **Project**: `formal-verification/lean/` — `lake init FVSquad` (no Mathlib)
- **CI**: `.github/workflows/lean-ci.yml` (working, triggers on lean/** changes)

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
- **Phase**: 5 — COMPLETE (13+ theorems, 0 sorry as of run 28)
- **All proved**: insert_preserves_invariant, insert_covers_union,
  remove_until_removes_small, remove_until_preserves_large,
  remove_until_preserves_invariant, and all structural lemmas
- **PR**: run-28 PR pending merge
- **Proof strategy**: generalised accumulator induction via
  range_insert_go_covers_gen and range_insert_go_preserves_inv
  (4 acc invariants: sorted_disjoint, bound, separation, validity)

### 3. WindowedMinimum running-minimum algorithm
- **File**: `quiche/src/minmax.rs`
- **Lean file**: `FVSquad/Minmax.lean`
- **Phase**: 5 — COMPLETE (15 public + 3 private theorems, 0 sorry)
- **PR**: #15 (merged)

### 4. RTT estimator
- **File**: `quiche/src/recovery/rtt.rs` — `RttStats::update_rtt`
- **Phase**: 2 — Informal spec in prior run memory, NOT committed to master
- **Priority**: HIGH — security-sensitive, affects congestion control
- **Target properties**: min_rtt monotone, smoothed_rtt bounded, rttvar ≥ 0,
  adjusted_rtt ≥ min_rtt, max_rtt monotone non-decreasing
- **Note**: RttStats.lean was referenced in FVSquad.lean import (stale, now removed)

### 5. Flow control window arithmetic
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 1 — Research identified
- **Priority**: MEDIUM

## Open PRs / Branches
- `lean-squad-rangeset-proofs-run28-23913360731` — run 28:
  insert_preserves_invariant + insert_covers_union proved (0 sorry total)
  Also fixes stale FVSquad.lean import

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available without Mathlib/Std — use `Nat.lt_or_ge`
- `split_ifs` NOT available without Std — use `by_cases`
- `push_neg` NOT available — use arithmetic directly or omega
- `simp only [range_insert_go.eq_def]` LOOPS — use `unfold range_insert_go`
  OR `simp only [range_insert_go]` (the latter works)
- `List.mem_cons_self` takes NO explicit args (zero explicit args)
- Bool `=` precedence trap: `||` has precedence 30, `=` has 50
- Bool AC tactic: use `generalize (...expr...) = bX` for each Bool atom,
  then `cases bA <;> ... <;> rfl` (not simp or omega)
- `covers_append`: unfold covers; rw [List.any_append] works
- sorted_disjoint_cons2_iff as `@[simp]` works for goal simplification;
  but `rw [sorted_disjoint_cons2_iff]` fails when variable name `s` in scope
  shadows the pattern variable — use `simp only [...]` instead
- `List.mem_reverse.mp`: converts `r ∈ l.reverse → r ∈ l` (use `.mp` not `.mpr`)
- For generalised accumulator invariant (insert_preserves_invariant):
  4 invariants: sorted_disjoint, acc_bound (≤ s), sep (acc ends before rest),
  rest_inv — all preserved through skip, overlap, and base cases
- `sorted_disjoint_snoc` uses `lo hi` (not `s e`) to avoid naming conflict
  with sorted_disjoint_cons2_iff @[simp] pattern variable
- `covers_singleton r n = in_range r n` via simp [covers, List.any, in_range]
- `in_range_merge_bool`: proved via bool_eq_of_iff + 4 by_cases (hs × he)
  + omega in each branch. Uses h1: ¬(e<rs), h2: ¬(s>re) as Prop hypotheses.

## TARGETS.md / CORRESPONDENCE.md / CRITIQUE.md
- All three in `formal-verification/`

## Next Priorities
1. Write RTT estimator Lean spec (Task 3) — pure arithmetic, Duration as Nat
   - Key theorems: smoothed_rtt_pos, rttvar_nonneg, min_rtt_le_latest_rtt
2. Write informal spec for Flow control (Task 2)
3. Task 7 (Proof Utility Critique) — update CRITIQUE.md now that RangeSet complete

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox). Document failure each run.
- FVSquad.lean had stale `import FVSquad.RttStats` — FIXED in run 28.
  Do NOT add RttStats import until the file is actually created.
