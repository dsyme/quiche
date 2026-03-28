# Lean Squad Memory — dsyme/quiche

## Run History
- **Run 1**: Task 1 (Research) — identified targets, created RESEARCH.md + TARGETS.md
- **Run 2**: Task 2 (Informal Spec) — wrote `formal-verification/specs/rangeset_informal.md`; PR #4 (merged)
- **Run 3**: Task 3 (Lean Spec) — wrote `formal-verification/lean/FVSquad/RangeSet.lean` with 5 sorry; PR #6 (merged)
- **Run 4**: Task 5 (Proof Assistance — Varint) — proved all 10 Varint theorems; PR #5 (merged)
- **Run 5**: Task 5 (Proof Assistance — RangeSet) — proved all 3 remove_until_* theorems, partially proved insert_*; PR abandoned (not created, merge conflicts resolved inline)
- **Run 6 (current)**: Task 5 (Proof Assistance — RangeSet complete) — proved all 5 RangeSet theorems, 0 sorry; PR created on branch `lean-squad/rangeset-proofs-run6`

## FV Targets

### Target 1: QUIC varint codec
- **File**: `octets/src/lib.rs`
- **Lean file**: `formal-verification/lean/FVSquad/Varint.lean`
- **Phase**: 5 — Proofs
- **Status**: ✅ COMPLETE — 10 theorems proved, 0 sorry
- **PR**: #5 (merged)

### Target 2: RangeSet invariants
- **File**: `quiche/src/ranges.rs`
- **Informal spec**: `formal-verification/specs/rangeset_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/RangeSet.lean`
- **Phase**: 5 — Proofs
- **Status**: ✅ COMPLETE — 5 theorems proved, 0 sorry (PR on branch lean-squad/rangeset-proofs-run6)
- **Theorems proved**:
  - `insert_preserves_invariant` (sorted_disjoint maintained)
  - `insert_covers_union` (semantic set union)
  - `remove_until_removes_small` (values ≤ largest removed)
  - `remove_until_preserves_large` (values > largest preserved)
  - `remove_until_preserves_invariant` (invariant maintained)

### Target 3: RTT estimation
- **File**: `quiche/src/recovery/rtt.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started
- **Notes**: 152 lines, `update_rtt()` is the key function; RFC 9002 §5 EWMA update

### Target 4: Flow control
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started

### Target 5: Minmax filter
- **File**: `quiche/src/minmax.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started

## Lean Toolchain
- **Version**: Lean 4.29.0 (installed at `~/.elan/bin/lean`)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **build**: `lake build` — last run: PASSED

## Key Lean 4.29.0 API Notes (no Mathlib)
- `List.mem_cons_self` takes NO explicit args; use `List.mem_cons.mpr (Or.inl rfl)`
- `in_range r n = decide (r.1 ≤ n) && decide (n < r.2)` — use `simp [show ¬... by omega]` to disprove
- `split_ifs` NOT available without Mathlib; use `by_cases h : cond; simp only [h, ite_true/ite_false]`
- `push_neg` NOT available; use `Nat.lt_of_not_ge`/`Nat.le_of_not_lt`
- `Bool.or_left_comm` may not exist; derive via `Bool.or_assoc` + `Bool.or_comm`
- After `simp` unfolds `covers tail n` → `tail.any ...`, can't case-split with `cases`; use `Bool.or_assoc`/`Bool.or_comm` instead

## Key Insights for Future Runs
- `range_insert_go_acc` decomposition lemma is the key to all insert proofs
- For `rigo_covers` merge case: `in_range (min s rs, max e re) n = in_range (rs,re) n || in_range (s,e) n` proved via `Bool.eq_iff_iff` + `by_cases` + `omega`
- Don't unfold `covers tail n` before needing to case-split on it; use Bool.or structural lemmas instead

## Open Tasks for Next Run
1. **Write CORRESPONDENCE.md** (Task 6) — review Lean model vs Rust source for Varint + RangeSet
2. **RTT informal spec** (Task 2) — `quiche/src/recovery/rtt.rs`
3. **RTT Lean spec** (Task 3) — model RttStats, update_rtt
4. **Proof Utility Critique** (Task 7) — assess coverage of existing proofs
