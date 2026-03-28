# Lean Squad Memory — dsyme/quiche

## Run History
- **Run 1**: Task 1 (Research) — identified targets, created RESEARCH.md + TARGETS.md
- **Run 2**: Task 2 (Informal Spec) — wrote `formal-verification/specs/rangeset_informal.md`; PR #4 (merged)
- **Run 3**: Task 3 (Lean Spec) — wrote `formal-verification/lean/FVSquad/RangeSet.lean` with 5 sorry; PR #6 (merged)
- **Run 4**: Task 5 (Proof Assistance — Varint) — proved all 10 Varint theorems; PR #5 (merged)
- **Run 5**: Task 5 (Proof Assistance — RangeSet) — proved all 5 RangeSet theorems but PR abandoned
- **Run 6**: Task 2+3 RTT estimation — 21 theorems, 0 sorry; blocked as issue #8 (workflow perms)
- **Run 7**: Tasks 2+3+5 FlowControl — 23 theorems, 0 sorry; merged RTT+Varint+RangeSet branches
- **Run 8 (current)**: Tasks 2+3 Minmax + Task 9 CI — 11 theorems, 2 sorry; lean-ci.yml submitted

## FV Targets

### Target 1: QUIC varint codec
- **File**: `octets/src/lib.rs`
- **Lean file**: `formal-verification/lean/FVSquad/Varint.lean`
- **Phase**: 5 — Proofs
- **Status**: ✅ COMPLETE — 10 theorems proved, 0 sorry
- **PR**: #5 (open, not yet merged to master)

### Target 2: RangeSet invariants
- **File**: `quiche/src/ranges.rs`
- **Informal spec**: `formal-verification/specs/rangeset_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/RangeSet.lean`
- **Phase**: 3 — Lean Spec
- **Status**: 🔄 In progress — 10 proved, 5 sorry remaining
- **PR**: #6 (open)
- **Theorems with sorry**: insert_preserves_invariant, insert_covers_union, remove_until_removes_small, remove_until_preserves_large, remove_until_preserves_invariant

### Target 3: RTT estimation
- **File**: `quiche/src/recovery/rtt.rs`
- **Informal spec**: `formal-verification/specs/rtt_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/RttStats.lean`
- **Phase**: 5 — Proofs
- **Status**: ✅ COMPLETE — 21 theorems proved, 0 sorry
- **PR**: run 6 branch (open, not yet merged to master)

### Target 4: Flow control
- **File**: `quiche/src/flowcontrol.rs`
- **Lean file**: `formal-verification/lean/FVSquad/FlowControl.lean`
- **Phase**: 5 — Proofs (estimated from memory)
- **Status**: ✅ COMPLETE — 23 theorems proved, 0 sorry (from run 7)
- **Note**: Run 7 branch was submitted but not found as a PR in the current open list

### Target 5: Minmax filter
- **File**: `quiche/src/minmax.rs`
- **Informal spec**: `formal-verification/specs/minmax_informal.md` (written run 8)
- **Lean file**: `formal-verification/lean/FVSquad/Minmax.lean` (written run 8)
- **Phase**: 3 — Lean Spec
- **Status**: 🔄 In progress — 11 proved, 2 sorry remaining
- **Sorry**: subwin_update_preserves_value_ordering, running_min_preserves_value_ordering
- **PR**: run 8 branch `lean-squad-run8-minmax-spec-a1b2c3d4`

## Lean Toolchain
- **Version**: Lean 4.29.0 (installed at `~/.elan/bin/lean`)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **build**: `lake build` — last run: PASSED (7 jobs, all 4 targets)

## Key Lean 4.29.0 API Notes (no Mathlib)
- `List.mem_cons_self` takes NO explicit args; use `List.mem_cons.mpr (Or.inl rfl)`
- `split_ifs` NOT available; use `by_cases h : cond; simp only [if_pos h / if_neg h]`
- `push_neg` NOT available; use `Nat.le_of_not_lt` or `omega`
- `Nat.le_or_lt` NOT available; use `by_cases` or `omega`
- `Bool.decide_eq_true_eq` NOT available (as Bool prefix); use `simp [fc_fn]` directly
- For min proofs: use `by_cases hmw : a ≤ b; simp only [if_pos hmw / if_neg hmw]; omega`
- For `¬(A ∨ B)` → simp: use `fun h => h.elim hnotA hnotB`
- `subwin_result_le_bound` pattern works for bounded result proofs in Minmax

## CI Status
- `lean-ci.yml` submitted in run 8 PR — may be blocked by workflow permissions
- Issue #3 documents lean-ci.yml content for manual maintainer creation
- No CI currently running for Lean proofs

## Open Tasks for Next Run
1. **Prove Minmax sorry theorems** (Task 5):
   - `subwin_update_preserves_value_ordering`: value ordering after subwin_update
     - Quarter window case: straightforward (e0 unchanged, e1=e2=val ≥ e0 by precond)
     - Half window case: e0,e1 unchanged, e2=val. Need val ≥ e1.value? Not guaranteed without more context.
     - Double-shift case: new e0 = old e2, which ≥ old e1 ≥ old e0 by inv. But new e1 = val, new e2 = val. Need val ≥ old e2. NOT guaranteed in isolation!
     - KEY INSIGHT: subwin_update_preserves_value_ordering alone may NOT be provable with just min_value_ordered + s.e0.value ≤ v. The correct theorem should be called from running_min where we have context about the s1 structure.
   - ALTERNATIVE: Prove `running_min_preserves_value_ordering` directly by full case analysis (not via subwin_update lemma)
2. **Write FlowControl Lean spec** if run 7 branch is missing (check)
3. **CORRESPONDENCE.md** (Task 6) — review all Lean models vs Rust
4. **CI (Task 9)**: lean-ci.yml may need maintainer merge
