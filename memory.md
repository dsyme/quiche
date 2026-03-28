# Lean Squad Memory — dsyme/quiche

## Run History
- **Run 1**: Task 1 (Research) — identified targets, created RESEARCH.md + TARGETS.md
- **Run 2**: Task 2 (Informal Spec) — wrote `formal-verification/specs/rangeset_informal.md`; PR #4 (merged)
- **Run 3**: Task 3 (Lean Spec) — wrote `formal-verification/lean/FVSquad/RangeSet.lean` with 5 sorry; PR #6 (open)
- **Run 4**: Task 5 (Proof Assistance — Varint) — proved all 10 Varint theorems; PR #5 (open)
- **Run 5**: Task 5 (Proof Assistance — RangeSet) — proved all 5 RangeSet theorems but PR abandoned
- **Run 6**: Task 2+3 RTT estimation — 21 theorems, 0 sorry; branch lean-squad-run6-rtt-spec merged into run 9
- **Run 7**: Tasks 2+3 FlowControl — no PR found
- **Run 8**: Tasks 2+3 Minmax + Task 9 CI — no PR found
- **Run 9 (current)**: Tasks 3+9 FlowControl Lean spec + CI — PR #8 created; merged runs 5,6 branches

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
- **PR**: included in run 9 PR #8

### Target 4: Flow control
- **File**: `quiche/src/flowcontrol.rs`
- **Informal spec**: `formal-verification/specs/flowcontrol_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/FlowControl.lean`
- **Phase**: 3 — Lean Spec
- **Status**: 🔄 In progress — 18 proved, 1 sorry
- **PR**: run 9 PR (open)
- **Sorry**: fc_update_monotone — needs precondition `fc_should_update s = true`

### Target 5: Minmax filter
- **File**: `quiche/src/minmax.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started

## Lean Toolchain
- **Version**: Lean 4.29.0 (installed at `~/.elan/bin/lean`)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **build**: `lake build` — last run: PASSED (7 jobs, all targets)

## Key Lean 4.29.0 API Notes (no Mathlib)
- `List.mem_cons_self` takes NO explicit args; use `List.mem_cons.mpr (Or.inl rfl)`
- `split_ifs` NOT available; use `by_cases h : cond; simp only [if_pos h / if_neg h]`
- `push_neg` NOT available in base Lean; use `Nat.le_of_not_lt` or `omega`
- `Bool.decide_eq_false_iff_not` NOT available; use `decide_eq_false_iff_not`
- For Bool cases: `cases hhu : s.has_updated <;> cases hbu : b <;> simp_all`
- For `Nat.min` in proofs: case split on which branch is smaller first
- `decide_eq_false_iff_not` (no Bool. prefix) works in Lean 4.29

## CI Status
- `lean-ci.yml` submitted in run 9 PR — may need maintainer merge for workflow perms
- Status issue: #4 (open, updated each run)

## Open Tasks for Next Run
1. **Prove FlowControl fc_update_monotone** (Task 5):
   - Needs precondition: `fc_should_update s = true` implies `max_data < consumed + window`
   - Then fc_update_max_data makes max_data = consumed + window ≥ old max_data
2. **Prove RangeSet sorry theorems** (Task 5) — still 5 sorry
3. **Write Minmax Lean spec** (Task 3) for Target 5
4. **CI (Task 9)**: lean-ci.yml needs maintainer merge
