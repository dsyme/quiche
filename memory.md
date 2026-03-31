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
- **Run 19**: Tasks 6+9 — CORRESPONDENCE.md + lean-ci.yml + RangeSet proofs applied (PR created, never merged)
- **Run 20 (this)**: Tasks 9+3 — lean-ci.yml + Minmax.lean spec + backport PR #15 changes
  Branch: lean-squad-run20-ci-minmax-1774950366 (PR created)

## IMPORTANT: Branch History Note
All lean-squad branches BEFORE run 15 are based on a DIFFERENT git history
(grafted). Only PRs #2, #5, #6 were successfully merged to master.
PR #15 (run 16) has unrelated history — must cherry-apply content each run.
Run 20 applied PR #15 content manually and created a new PR.

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
- **Status**: 🔄 In progress — Run 20 PR pending
- **Proved (cumulative, in run 20 branch)**:
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
- **Lean file**: `formal-verification/lean/FVSquad/Minmax.lean`
- **Phase**: 3 — Formal Spec (partial proofs)
- **Status**: 🔄 In progress — Run 20 PR pending
- **Proved**:
    §4 (reset): reset_uniform, reset_e0_value, reset_e1_value, reset_e2_value,
      reset_e0_time, reset_e1_time, reset_e2_time,
      reset_satisfies_min_val_inv, reset_satisfies_time_ordered (all by rfl/omega)
    §5 (running_min reset branches): running_min_new_min, running_min_window_expired,
      running_min_new_min_uniform, running_min_window_expired_uniform
    §7 (concrete examples): 4 #eval/example checks pass
- **Sorry remaining**: min_val_inv_preserved, time_ordered_preserved (2)
- **Approximations**: Instant/Duration → Nat; div_f32(4.0) → 4*delta > win;
    pure functional model (no mutation)

## Lean Toolchain
- **Version**: Lean 4.29.0
- **Installed at**: `~/.elan/bin/lean` (installed each run via elan)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **lean-toolchain**: `leanprover/lean4:v4.29.0`
- **lake build (run 20)**: PASSED, 0 errors, 4 sorry remaining

## Key Lean 4.29.0 API Notes (no Mathlib)
- `lemma` keyword NOT supported — use `theorem` instead!
  `private lemma` causes "unexpected identifier" error
- `split_ifs` NOT available without Mathlib — use `by_cases hs : cond`
  then `simp only [if_pos hs]` or `simp only [if_neg hs]` separately
- `List.reverse_cons : (a :: l).reverse = l.reverse ++ [a]` — theorem only,
  NOT a function; use `rw [List.reverse_cons]` not `List.reverse_cons _ _`
- `decide` on Prop: works for Nat equality/order, but NOT for opaque `def`
  predicates — use `simp [pred_name]; decide` or `native_decide`
- `native_decide` works for decidable small-Nat computations
- `omega` handles Nat linear arithmetic including ∧/¬ but NOT ∨ in goals
  Use `left`/`right` before omega for disjunctive goals

## Correspondence
- **CORRESPONDENCE.md**: Added in run 20 PR
- Varint.lean: approximation (OR → addition); exact for pure value mapping
- RangeSet.lean: abstraction (dual repr, no capacity limit); exact for invariants
- Minmax.lean: abstraction (Instant→Nat, div_f32→integer, pure functional)
- No mismatches found
- Key gap: insert_covers_union does NOT hold unconditionally in Rust when
  capacity eviction fires — needs `len < capacity` precondition

## CI Status
- `lean-ci.yml`: ADDED in run 20 PR (PENDING)
  Triggers on PR/push to formal-verification/lean/**
  Caches .lake artefacts on lake-manifest.json hash
  NOT yet merged to master

## Status Issue
- **Issue #4** (open): `[Lean Squad] Formal Verification Status`
  Updated in run 20

## Open PRs
- **PR #15** (run 16): RangeSet remove_until proofs + CORRESPONDENCE.md
  Content has been applied to run 20 branch; superseded by run 20 PR
- **Run 20 PR** (lean-squad-run20-ci-minmax-1774950366): PENDING

## Open Tasks for Next Run
1. **Prove insert_preserves_invariant** (Task 5 — hard)
   Need `range_insert_go_inv` generalised lemma — see strategy above
2. **Prove insert_covers_union** (Task 5 — hard, same technique)
3. **Prove min_val_inv_preserved** (Task 5 — medium)
   Case split on running_min + subwin_update branches; straightforward but verbose
4. **Prove time_ordered_preserved** (Task 5 — medium, similar)
5. **Write informal spec for Minmax** (Task 2 — quick)
6. **Write CRITIQUE.md** (Task 7)
7. **Aeneas Task 8** — blocked by opam availability

## Aeneas Status
- Task 8 (Aeneas): NOT attempted — opam not available in sandbox
