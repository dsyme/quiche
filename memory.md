# Lean Squad Memory — dsyme/quiche

## Run History
- **Run 1**: Task 1 (Research) — identified targets, created RESEARCH.md + TARGETS.md; PR #2 merged
- **Run 2**: Task 2 (Informal Spec) — wrote `formal-verification/specs/rangeset_informal.md`
- **Run 3**: Task 3+5 (Lean Spec + Proofs) — Varint.lean 10 theorems proved; PR #5 (open)
- **Run 4**: Task 3 (RangeSet Lean spec) — 5 sorry remaining; PR #6 (open)
- **Run 6**: Task 2+3 (RTT) — RttStats.lean 21 theorems 0 sorry; branch lean-squad-run6-rtt-spec
- **Run 10**: Tasks 3+9 — Minmax.lean spec + lean-ci.yml; PR created (appears unused/broken branch)
- **Run 11 (this)**: Tasks 5+9 — Proved 3 RangeSet remove_until theorems; added lean-ci.yml; PR created

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
- **Phase**: 5 — Proofs
- **Status**: 🔄 In progress — 13 proved, 2 sorry remaining
- **PR**: run 11 PR (new)
- **Proved this run**: remove_until_removes_small, remove_until_preserves_large,
  remove_until_preserves_invariant (plus 3 helpers)
- **Sorry**: insert_preserves_invariant, insert_covers_union
  (require generalised induction on range_insert_go with accumulator invariant)

### Target 3: RTT estimation
- **File**: `quiche/src/recovery/rtt.rs`
- **Informal spec**: `formal-verification/specs/rtt_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/RttStats.lean`
- **Phase**: 5 — Proofs
- **Status**: ✅ COMPLETE — 21 theorems proved, 0 sorry
- **Branch**: lean-squad-run6-rtt-spec-1774698629-be91e44fb7d49a1d (included in run 11 PR)

### Target 4: Flow control
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started

### Target 5: Minmax filter
- **File**: `quiche/src/minmax.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started (run 10 branch was corrupt/broken)

## Lean Toolchain
- **Version**: Lean 4.29.0 (installed at `~/.elan/bin/lean`)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **lake build**: PASSED (6 jobs, 2 sorry: insert_preserves_invariant + insert_covers_union)

## Key Lean 4.29.0 API Notes (no Mathlib)
- `lemma` keyword NOT valid — use `theorem` or `private theorem`
- `List.mem_cons_self` takes NO explicit args; use `List.mem_cons.mpr (Or.inl rfl)`
- For Bool case split: `cases h : myBool with | true => ... | false => ...`
  NOT `by_cases h : myBool` (gives `h : False` in false branch, not `h : myBool = false`)
- `split_ifs` NOT available; use `by_cases h : cond; simp only [if_pos h / if_neg h]`
- `push_neg` NOT available; use `Nat.lt_of_not_le` instead
- `simp [covers, List.any_cons]` leaves `tl.any (fun r => in_range r n)`, not `covers tl n`
  Fix: `rw [show tl.any (fun r => in_range r n) = covers tl n from rfl]`
- `sorted_disjoint []` = `True`; need `trivial` (not just `simp [range_remove_until]`)
- For `simp [sorted_disjoint]` on cons-cons: gives `And (valid_range hd) (And (e ≤ next.1) tail_inv)`

## CI Status
- `lean-ci.yml`: CREATED in run 11 PR — triggers on formal-verification/lean/**
  (Previous run 10 branch was corrupt and not useful)
- Status issue: #4 (open, updated each run)

## Open Tasks for Next Run
1. **Prove insert sorry theorems** (Task 5):
   - Strategy: define generalised lemma for range_insert_go with acc:
     `range_insert_go_inv : sorted_disjoint acc_rev.reverse → sorted_disjoint rest →
      (acc_rev last range s e) → sorted_disjoint (range_insert_go acc_rev rest s e)`
   - This is non-trivial; requires careful bound tracking
2. **Write FlowControl informal+Lean spec** (Tasks 2+3) — Phase 1, not started
3. **Write Correspondence.md** (Task 6) — link Lean models to Rust source
4. **Merge PRs** — PRs #5, #6, run11 PR should be merged to enable subsequent runs
   to see higher phase counts in task_selection.json

## PR Status
- PR #5: lean-squad-run3-varint-proofs (Varint complete + rangeset informal)
- PR #6: lean-squad-run4-rangeset-spec (RangeSet Lean spec, 5 sorry — superseded by run11)
- Run 11 PR: lean-squad-run11-proofs-acf363d0 — consolidates all work:
  Varint + RangeSet + RttStats + lean-ci.yml; 2 sorry remain
