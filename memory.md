# Lean Squad Memory — dsyme/quiche

## Run History
- **Run 1**: Task 1 (Research) — identified targets, created RESEARCH.md + TARGETS.md; PR #2 merged
- **Run 2**: Task 2 (Informal Spec) — wrote `formal-verification/specs/rangeset_informal.md`
- **Run 3**: Task 3+5 (Lean Spec + Proofs) — Varint.lean 10 theorems proved; PR #5 (open)
- **Run 4**: Task 3 (RangeSet Lean spec) — 5 sorry remaining; PR #6 (open)
- **Run 6**: Task 2+3 (RTT) — RttStats.lean 21 theorems 0 sorry; branch lean-squad-run6-rtt-spec
- **Run 10 (this)**: Tasks 3+9 — Minmax.lean spec + lean-ci.yml; PR created

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
- **Sorry theorems**: insert_preserves_invariant, insert_covers_union,
  remove_until_removes_small, remove_until_preserves_large, remove_until_preserves_invariant

### Target 3: RTT estimation
- **File**: `quiche/src/recovery/rtt.rs`
- **Informal spec**: `formal-verification/specs/rtt_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/RttStats.lean`
- **Phase**: 5 — Proofs
- **Status**: ✅ COMPLETE — 21 theorems proved, 0 sorry
- **Branch**: lean-squad-run6-rtt-spec-1774698629-be91e44fb7d49a1d (open PR needed)

### Target 4: Flow control
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started (prior run's branch not surfaced as PR)

### Target 5: Minmax filter
- **File**: `quiche/src/minmax.rs`
- **Informal spec**: `formal-verification/specs/minmax_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/Minmax.lean`
- **Phase**: 3 — Lean Spec
- **Status**: 🔄 In progress — 6 proved lemmas, 7 sorry theorems (deferred)
- **PR**: run 10 PR (just created)
- **Proved**: reset_all_equal, reset_all_same_time, reset_returns_value,
  reset_min_invariant, reset_max_invariant, reset_time_invariant,
  running_min_reset_case, running_max_reset_case
- **Sorry**: running_min_returns_estimate0, running_min/max_preserves_*_invariant,
  running_min_result_le_meas, running_min_no_expiry_le_current

## Lean Toolchain
- **Version**: Lean 4.29.0 (installed at `~/.elan/bin/lean`)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **lake build**: PASSED (7 jobs, 12 sorry total: 5 RangeSet + 7 Minmax)

## Key Lean 4.29.0 API Notes (no Mathlib)
- `List.mem_cons_self` takes NO explicit args; use `List.mem_cons.mpr (Or.inl rfl)`
- `split_ifs` NOT available; use `by_cases h : cond; simp only [if_pos h / if_neg h]`
- `push_neg` NOT available in base Lean; use `Nat.le_of_not_lt` or `omega`
- For Bool cases: `cases hhu : s.has_updated <;> cases hbu : b <;> simp_all`
- For `Nat.min` in proofs: case split on which branch is smaller first
- `decide_eq_false_iff_not` (no Bool. prefix) works in Lean 4.29
- For `Or` in if-conditions: `simp [if_pos (Or.inl h1)]` works
- For reset case proofs: `have h : ... := Or.inr h2; simp [if_pos h, mmReset]`

## CI Status
- `lean-ci.yml`: CREATED in run 10 PR — triggers on formal-verification/lean/**
- Status issue: #4 (open, updated each run)

## Open Tasks for Next Run
1. **Prove Minmax sorry theorems** (Task 5):
   - running_min_returns_estimate0: case split on 4 mmRunningMin branches
   - running_min_preserves_min_invariant: cases + subwin_update analysis
   - running_min_result_le_meas: follows from invariant + reset case
2. **Prove RangeSet sorry theorems** (Task 5) — 5 sorry in PR #6
3. **Write FlowControl informal+Lean spec** (Tasks 2+3) — Phase 1, not started
4. **Write Correspondence.md** (Task 6) — link Lean models to Rust source
