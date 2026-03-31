# Lean Squad Memory — dsyme/quiche

## Run History
- **Run 1**: Task 1 (Research) — identified targets, created RESEARCH.md + TARGETS.md
- **Run 2**: Task 2 (Informal Spec) — wrote `formal-verification/specs/rangeset_informal.md`
- **Run 3**: Task 3+5 (Lean Spec + Proofs) — Varint.lean 10 theorems proved; PR #5 merged to master
- **Run 4**: Task 3 (RangeSet Lean spec) — RangeSet.lean created; PR #6 merged to master
- **Runs 5–14**: Various branches (not all merged — diverged history)
- **Run 15**: Tasks 5+9 — proved 3 remove_until theorems + lean-ci.yml on branch that was never merged
- **Run 16**: Tasks 5+6 — proved 3 remove_until theorems (again) + CORRESPONDENCE.md; PR #15 open
- **Run 17**: Tasks 5+9 — proved insert_covers_union (not merged; branch gone)
- **Run 18**: Tasks 6+9 — branch was same SHA as master; no content changes persisted
- **Run 19 (this)**: Tasks 6+9 — CORRESPONDENCE.md + lean-ci.yml + RangeSet proofs applied
  Branch: lean-squad-run19-correspondence-ci-1774950365 (PR created)

## IMPORTANT: Branch History Note
All lean-squad branches BEFORE run 15 are based on a DIFFERENT git history
(grafted). Only PRs #2, #5, #6 were successfully merged to master.
Run 16 PR (#15) has unrelated history — must cherry-apply content.
Run 19 branch created fresh from master, applied PR #15 content manually.

## FV Targets

### Target 1: QUIC varint codec
- **File**: `octets/src/lib.rs`
- **Lean file**: `formal-verification/lean/FVSquad/Varint.lean`
- **Phase**: 5 — Complete
- **Status**: ✅ In master — 10 theorems proved, 0 sorry (PR #5 merged)

### Target 2: RangeSet invariants
- **File**: `quiche/src/ranges.rs`
- **Informal spec**: `formal-verification/specs/rangeset_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/RangeSet.lean`
- **Phase**: 5 — Proofs (partial)
- **Status**: 🔄 In progress — Run 19 PR pending
- **Proved (cumulative, in run 19 branch)**:
    §7 structural: empty_sorted_disjoint, singleton_sorted_disjoint,
      empty_covers_nothing, singleton_covers_iff, insert_empty,
      remove_until_empty, insert_empty_covers, singleton_not_covers_left,
      singleton_not_covers_right, sorted_disjoint_tail, sorted_disjoint_head_valid
    §8: sorted_disjoint_cons2_iff
    §9: covers_above_bound_false, sorted_disjoint_all_ge_head_end
    §5 (remove_until): remove_until_removes_small, remove_until_preserves_large,
      remove_until_preserves_invariant
- **Sorry remaining**: insert_preserves_invariant, insert_covers_union (2)
- **Strategy for insert_preserves_invariant / insert_covers_union**:
    Both need generalised induction over range_insert_go with accumulator invariant:
    `range_insert_go_inv acc_rev rest s e`:
    - acc_rev.reverse is sorted_disjoint
    - All acc_rev elements end ≤ s (current window start)
    - rest is sorted_disjoint
    - Result (range_insert_go acc_rev rest s e) is sorted_disjoint
    Key: prove this generalised lemma by strong induction on rest.length.

### Target 3: RTT estimation
- **File**: `quiche/src/recovery/rtt.rs`
- **Phase**: 1 — Not in master
- **Status**: ⬜ Pending — needs fresh Lean file from scratch

### Target 4: Flow control
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 1 — Not in master
- **Status**: ⬜ Pending — needs fresh Lean file from scratch

### Target 5: Minmax filter
- **File**: `quiche/src/minmax.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started

## Lean Toolchain
- **Version**: Lean 4.29.0
- **Installed at**: `~/.elan/bin/lean` (installed each run via elan)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **lean-toolchain**: `leanprover/lean4:v4.29.0`
- **lake build (run 19)**: PASSED, 0 errors, 2 sorry remaining

## Key Lean 4.29.0 API Notes (no Mathlib)
- `lemma` keyword NOT supported — use `theorem` instead!
  `private lemma` causes "unexpected identifier" error
- `split_ifs` NOT available without Mathlib — use `by_cases hs : cond`
  then `simp only [if_pos hs]` or `simp only [if_neg hs]` separately
- `List.reverse_cons : (a :: l).reverse = l.reverse ++ [a]` — theorem only,
  NOT a function; use `rw [List.reverse_cons]` not `List.reverse_cons _ _`
- `List.any_append` IS available as simp lemma
- `Bool.and_eq_true`, `Bool.or_eq_true`, `decide_eq_true_eq` — convert
  Bool to Prop; works in simp after `apply bool_eq_of_prop_iff`
- simp lemmas must be applied before `covers` is unfolded (else covers_append
  won't match since covers unfolds to List.any)
- `omega` handles Nat linear arithmetic including ∧/¬ but NOT ∨ in goals
  Use `left`/`right` before omega for disjunctive goals

## Correspondence
- **CORRESPONDENCE.md**: Added to run 19 PR (PENDING)
- Varint.lean: approximation (OR → addition); exact for pure value mapping
- RangeSet.lean: abstraction (dual repr, no capacity limit); exact for invariants
- No mismatches found
- Key gap: insert_covers_union does NOT hold unconditionally in Rust when
  capacity eviction fires — needs `len < capacity` precondition

## CI Status
- `lean-ci.yml`: ADDED in run 19 PR (PENDING)
  Triggers on PR/push to formal-verification/lean/**
  Caches .lake artefacts on lake-manifest.json hash
  NOT yet merged to master

## Status Issue
- **Issue #4** (open): `[Lean Squad] Formal Verification Status`
  Updated in run 19

## Open PRs
- **PR #15** (run 16): RangeSet remove_until proofs + CORRESPONDENCE.md
  Content has been applied to run 19 branch; superseded by run 19 PR
- **Run 19 PR** (lean-squad-run19-correspondence-ci-1774950365): PENDING

## Open Tasks for Next Run
1. **Prove insert_preserves_invariant** (Task 5 — hard)
   Need `range_insert_go_inv` generalised lemma:
   `sorted_disjoint_insert_go_inv acc_rev rest s e` ≡
   - sorted_disjoint acc_rev.reverse ∧ sorted_disjoint rest
   - ∀ r ∈ acc_rev, r.2 ≤ s  (acc ends before window)
   - s < e (valid window)
   - result is sorted_disjoint
2. **Prove insert_covers_union** (Task 5 — hard, same technique)
3. **Write RttStats.lean spec** (Task 3 — medium)
4. **Write CRITIQUE.md** (Task 7)
5. **Aeneas Task 8** — blocked by opam availability

## Aeneas Status
- Task 8 (Aeneas): NOT attempted — opam not available in sandbox
