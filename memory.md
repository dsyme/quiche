# Lean Squad Memory — dsyme/quiche

## Run History
- **Run 1**: Task 1 (Research) — identified targets, created RESEARCH.md + TARGETS.md
- **Run 2**: Task 2 (Informal Spec) — wrote `formal-verification/specs/rangeset_informal.md`; PR #4 (merged)
- **Run 3**: Task 3 (Lean Spec) — wrote `formal-verification/lean/FVSquad/RangeSet.lean` with 5 sorry; PR #6 (merged)
- **Run 4**: Task 5 (Proof Assistance — Varint) — proved all 10 Varint theorems; PR #5 (merged)
- **Run 5**: Task 5 (Proof Assistance — RangeSet) — proved all 5 RangeSet theorems but PR abandoned
- **Run 6**: Task 2+3 RTT estimation — 21 theorems, 0 sorry; blocked as issue #8 (workflow perms)
- **Run 7 (current)**: Tasks 2+3+5 FlowControl — 23 theorems, 0 sorry; merged RTT+Varint+RangeSet branches; PR submitted

## FV Targets

### Target 1: QUIC varint codec
- **File**: `octets/src/lib.rs`
- **Lean file**: `formal-verification/lean/FVSquad/Varint.lean`
- **Phase**: 5 — Proofs
- **Status**: ✅ COMPLETE — 10 theorems proved, 0 sorry
- **PR**: #5 (open, in this run's branch)

### Target 2: RangeSet invariants
- **File**: `quiche/src/ranges.rs`
- **Informal spec**: `formal-verification/specs/rangeset_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/RangeSet.lean`
- **Phase**: 3 — Lean Spec
- **Status**: 🔄 In progress — 5 sorry remaining (deferred proofs)
- **PR**: #6 (open, in this run's branch)
- **Theorems with sorry**: insert_preserves_invariant, insert_covers_union, remove_until_removes_small, remove_until_preserves_large, remove_until_preserves_invariant

### Target 3: RTT estimation
- **File**: `quiche/src/recovery/rtt.rs`
- **Informal spec**: `formal-verification/specs/rtt_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/RttStats.lean`
- **Phase**: 5 — Proofs
- **Status**: ✅ COMPLETE — 21 theorems proved, 0 sorry
- **PR**: included in run 7 branch (was blocked as issue #8 in run 6)

### Target 4: Flow control
- **File**: `quiche/src/flowcontrol.rs`
- **Informal spec**: `formal-verification/specs/flowcontrol_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/FlowControl.lean`
- **Phase**: 5 — Proofs
- **Status**: ✅ COMPLETE — 23 theorems proved, 0 sorry
- **PR**: Run 7 branch `lean-squad-run7-rtt-spec`
- **Key theorems**: window_inv preserved by all ops, should_update_iff, max_data_next_ge_max_data (with precondition), ensure_lower_bound_ge_prev

### Target 5: Minmax filter
- **File**: `quiche/src/minmax.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started

## Lean Toolchain
- **Version**: Lean 4.29.0 (installed at `~/.elan/bin/lean`)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **build**: `lake build` — last run: PASSED (7 jobs)

## Key Lean 4.29.0 API Notes (no Mathlib)
- `List.mem_cons_self` takes NO explicit args; use `List.mem_cons.mpr (Or.inl rfl)`
- `split_ifs` NOT available; use `by_cases h : cond; simp only [if_pos h / if_neg h]`
- `push_neg` NOT available; use `Nat.le_of_not_lt` or `omega`
- `Nat.le_or_lt` NOT available; use `by_cases` or `omega`
- `Bool.decide_eq_true_eq` NOT available (as Bool prefix); use `simp [fc_fn]` directly
- `Bool.decide_eq_false_iff_not` NOT available; use `simp [fc_fn]`
- `decide_eq_true_eq` works for `decide x = true ↔ x` via `simp`
- For min proofs: use `by_cases hmw : a ≤ b; simp only [if_pos hmw / if_neg hmw]; omega`

## Open Tasks for Next Run
1. **Prove RangeSet sorry theorems** (Task 5) — 5 sorry in RangeSet.lean
   - `insert_preserves_invariant`: structural induction on `rs`
   - `insert_covers_union`: key I3 set-union property
   - `remove_until_*`: three theorems
   - Memory from run 5: all were proved there, approach is in comments in the .lean file
2. **Write Minmax informal + Lean spec** (Tasks 2+3) — `quiche/src/minmax.rs`
3. **CORRESPONDENCE.md** (Task 6) — review all 4 Lean models vs Rust
4. **CI (Task 9)**: lean-ci.yml requires maintainer merge (documented in issue #3)

## Note on PR Strategy
- lean-ci.yml CANNOT be submitted by automated runs (workflow permissions blocked)
- Don't include it in PRs; document in issues/PR descriptions
- All prior lean-squad PRs are open but not merged into master (PRs #5, #6)
- The run 7 branch includes all prior work merged: varint+rangeset+RTT+flowcontrol
