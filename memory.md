# Lean Squad Memory — dsyme/quiche

## Run History
- **Run 1**: Task 1 (Research) — identified targets, created RESEARCH.md + TARGETS.md
- **Run 2**: Task 2 (Informal Spec) — wrote `formal-verification/specs/rangeset_informal.md`; PR #4 (merged)
- **Run 3**: Task 3 (Lean Spec) — wrote `formal-verification/lean/FVSquad/RangeSet.lean` with 5 sorry; PR #6 (merged)
- **Run 4**: Task 5 (Proof Assistance — Varint) — proved all 10 Varint theorems; PR #5 (merged)
- **Run 5**: Task 5 (Proof Assistance — RangeSet partial)
- **Run 6**: Tasks 2+3 (RTT informal spec + Lean proofs) — 21 theorems, 0 sorry; merged into run7
- **Run 7**: Task 5 (RangeSet: 4 more proofs) + Task 2 (FlowControl informal spec); PR #7 pending

## FV Targets

### Target 1: QUIC varint codec
- **File**: `octets/src/lib.rs`
- **Lean file**: `formal-verification/lean/FVSquad/Varint.lean`
- **Phase**: 5 — Proofs
- **Status**: ✅ COMPLETE — 10 theorems proved, 0 sorry (PR #5 merged)

### Target 2: RangeSet invariants
- **File**: `quiche/src/ranges.rs`
- **Lean file**: `formal-verification/lean/FVSquad/RangeSet.lean`
- **Phase**: 5 — Proofs (nearly complete)
- **Status**: 🔄 4 of 5 sorry proved. `insert_preserves_invariant` deferred (complex structural)
- **Theorems proved**:
  - `insert_covers_union` (semantic set union via rigo_covers)
  - `remove_until_removes_small` (values ≤ largest removed)
  - `remove_until_preserves_large` (values > largest preserved)
  - `remove_until_preserves_invariant` (invariant maintained)
- **Remaining sorry**: `insert_preserves_invariant` — sorted_disjoint maintained by insert

### Target 3: RTT estimation
- **File**: `quiche/src/recovery/rtt.rs`
- **Lean file**: `formal-verification/lean/FVSquad/RttStats.lean`
- **Phase**: 5 — Proofs
- **Status**: ✅ COMPLETE — 21 theorems, 0 sorry (merged from run6 branch)

### Target 4: Flow control
- **File**: `quiche/src/flowcontrol.rs`
- **Informal spec**: `formal-verification/specs/flowcontrol_informal.md`
- **Phase**: 2 — Informal Spec
- **Status**: 🔄 Informal spec written in run 7
- **Key properties to verify** (for Task 3):
  - Constructor: `window(new) = min(w, max_window)`
  - `should_update_max_data`: `max_data - consumed < window / 2`
  - `max_data_next`: `consumed + window`
  - `update_max_data` effect: `max_data = consumed + window`
  - Monotonicity: `update_max_data` never decreases `max_data`
  - Window bounded: `window ≤ max_window` always
  - Autotune: doubles window when triggered, caps at max_window

### Target 5: Minmax filter
- **File**: `quiche/src/minmax.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started

## Lean Toolchain
- **Version**: Lean 4.29.0 (installed at `~/.elan/bin/lean`)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **build**: `lake build` — last run 7: PASSED (1 intentional sorry)

## Key Lean 4.29.0 API Notes (no Mathlib)
- **Bool precedence BUG**: `A = B || C` parses as `(A = B) || C`; write `A = (B || C)`
- `List.mem_cons_self` implicit args: use `List.mem_cons.mpr (Or.inl rfl)`
- `List.not_mem_nil _` unexpected type: use `simp at hr` instead
- `List.any_append` uses existential form; avoid, use induction instead
- `simp only [covers]` BEFORE induction ensures IH stays in `List.any` form
- `omega` can't handle `decide` atoms: use `cases h : decide(p)` + `simp_all` + `omega`
- `valid_range r` not unfolded by omega: use `have hv : s < e := ...` with annotation
- `in_range = false`: use `cases h : in_range ...` + `absurd` pattern
- `split_ifs` not available; use `by_cases h : cond; simp only [h, ite_true/ite_false]`
- `push_neg` not available; use `Nat.lt_of_not_ge`/`Nat.le_of_not_lt`
- `bool_eq_of_iff` helper useful: `{a b : Bool} → (a=true ↔ b=true) → a=b`
- `decide_eq_true_eq` and `decide_eq_false_iff_not` are @[simp] — use in simp_all
- `simp_all` (not `simp`) when hypotheses need simplification too

## Open PRs
- **PR #7** (run7, pending): RangeSet proofs (4 sorries removed) + FlowControl informal spec

## Open Tasks for Next Run
1. **Task 3**: Write Lean spec for FlowControl (`formal-verification/lean/FVSquad/FlowControl.lean`)
2. **Task 5**: Prove `insert_preserves_invariant` in RangeSet.lean (structural induction)
3. **Task 6**: Write CORRESPONDENCE.md linking Lean models to Rust source
4. **Task 7**: Write CRITIQUE.md assessing proof utility
