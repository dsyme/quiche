# Lean Squad Memory — dsyme/quiche

## Run History
- **Run 1**: Task 1 (Research) — identified targets, created RESEARCH.md + TARGETS.md; PR #2 merged
- **Run 2**: Task 2 (Informal Spec) — wrote `formal-verification/specs/rangeset_informal.md`
- **Run 3**: Task 3+5 (Lean Spec + Proofs) — Varint.lean 10 theorems proved; PR #5 merged
- **Run 4**: Task 3 (RangeSet Lean spec) — 5 sorry remaining; PR #6 (open issue)
- **Run 6**: Task 2+3 (RTT) — RttStats.lean 21 theorems 0 sorry; branch lean-squad-run6-rtt-spec
- **Run 10**: Tasks 3+9 — Minmax.lean spec + lean-ci.yml; PR (open issue)
- **Run 11**: Tasks 5+9 — 3 RangeSet remove_until theorems; PR created (superseded)
- **Run 12 (this)**: Tasks 5+9 — Proved 3 remove_until theorems; created lean-ci.yml; PR created
  Branch: lean-squad-run12-proofs-ci-1774756106

## FV Targets

### Target 1: QUIC varint codec
- **File**: `octets/src/lib.rs`
- **Lean file**: `formal-verification/lean/FVSquad/Varint.lean`
- **Phase**: 5 — Proofs
- **Status**: ✅ COMPLETE — 10 theorems proved, 0 sorry
- **PR**: #5 (merged to master)

### Target 2: RangeSet invariants
- **File**: `quiche/src/ranges.rs`
- **Informal spec**: `formal-verification/specs/rangeset_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/RangeSet.lean`
- **Phase**: 5 — Proofs
- **Status**: 🔄 In progress — 16 proved, 2 sorry remaining
- **PR**: lean-squad-run12-proofs-ci-1774756106 (current run)
- **Proved helpers (run 12)**: not_in_range_of_lt_start, covers_false_of_all_starts_gt, sd_tail_starts_ge
- **Proved main (run 12)**: remove_until_removes_small (I4a), remove_until_preserves_large (I4b), remove_until_preserves_invariant
- **Sorry remaining**: insert_preserves_invariant, insert_covers_union
  (require generalised induction on range_insert_go with accumulator invariant)

### Target 3: RTT estimation
- **File**: `quiche/src/recovery/rtt.rs`
- **Informal spec**: `formal-verification/specs/rtt_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/RttStats.lean`
- **Phase**: 5 — Proofs
- **Status**: ✅ COMPLETE — 21 theorems proved, 0 sorry
- **Note**: RttStats.lean is in lean-squad-run12 PR (not yet merged to master separately)

### Target 4: Flow control
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started

### Target 5: Minmax filter
- **File**: `quiche/src/minmax.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started (run 10 branch was not merged)

## Lean Toolchain
- **Version**: Lean 4.29.0 (installed at `~/.elan/bin/lean`)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **lake build**: PASSED (2 sorry: insert_preserves_invariant + insert_covers_union)

## Key Lean 4.29.0 API Notes (no Mathlib)
- `lemma` keyword NOT valid — use `theorem` or `private theorem`
- `List.mem_cons_self` takes NO explicit args; use `List.mem_cons.mpr (Or.inl rfl)`
- For Bool case split: `cases h : myBool with | true => ... | false => ...`
  NOT `by_cases h : myBool` or `rcases Bool.eq_true_or_eq_false ...`
- `Bool.eq_true_or_eq_false` DOES NOT EXIST — use `cases h : expr with | true | false`
- `List.not_mem_nil` — use `cases hr` on `hr : r ∈ []` (inductive type has no constructors)
  NOT `hr.elim` (List.Mem doesn't have .elim)
- `simp [h_hd]` on Bool hypothesis over-unfolds covers → use `simp only [h_hd, Bool.false_or]`
- `split_ifs` NOT available; use `by_cases h : cond; simp only [if_pos h / if_neg h]`
- `push_neg` NOT available; use Nat arithmetic via omega
- For `have : r.1 = s := by rw [heq]` — add `; rfl` after rw, or use `simp [heq]`
- `simp [covers, List.any, in_range]; omega` works for single-list coverage goals
- `simp [in_range] at h; omega` converts Bool in_range to Prop for arithmetic
- `Bool.false_or : false || b = b` — available in core

## CI Status
- `lean-ci.yml`: CREATED in run 12 PR — triggers on formal-verification/lean/**
  (Previous run 10/11 versions were in PRs that weren't merged)
- Status issue: #4 (open, updated each run)

## Open Tasks for Next Run
1. **Prove insert sorry theorems** (Task 5):
   - Strategy: define generalised lemma for range_insert_go with acc:
     `range_insert_go_inv : sorted_disjoint acc_rev.reverse → sorted_disjoint rest →
      (acc_rev ends before s) → sorted_disjoint (range_insert_go acc_rev rest s e)`
   - This is non-trivial; requires careful bound tracking
2. **Write FlowControl informal+Lean spec** (Tasks 2+3) — Phase 1, not started
3. **Write Correspondence.md** (Task 6) — link Lean models to Rust source
4. **Merge PRs** — lean-squad-run12 PR should be merged; RttStats.lean is only in that PR

## Aeneas Status
- **Task 8 (Aeneas)**: NOT attempted in runs 11 or 12
  Reason: `opam` not available (sandboxed environment, no sudo)
  Note: GitHub Actions runners HAVE opam, so Aeneas may work in CI context

## PR Status
- PR #5: merged (Varint.lean + RangeSet informal spec)
- lean-squad-run12-proofs-ci-1774756106: current run PR (RangeSet proofs + lean-ci.yml)
  Also contains RttStats.lean from run 6
