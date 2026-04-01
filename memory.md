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
- **Run 20**: Tasks 9+3 — lean-ci.yml + Minmax.lean spec + backport PR #15 changes (diverged history)
- **Run 21**: Tasks 5+6+9 — proved remove_until theorems + CORRESPONDENCE.md + lean-ci.yml
  Branch: lean-squad-run21-proofs-ci-1775015975 (PR created)
- **Run 22 (this)**: Tasks 6+9+5 — CORRESPONDENCE.md + lean-ci.yml + 3 remove_until proofs + 3 auxiliary lemmas
  Branch: lean-squad-run22-correspondence-ci-1775038123
  NOTE: MCP server unavailable at PR creation time — branch committed, PR not created via safeoutputs.
  PR should be created manually or will be retried next run.

## IMPORTANT: Branch History Note
All lean-squad branches BEFORE run 15 are based on a DIFFERENT git history
(grafted). Only PRs #2, #5, #6 were successfully merged to master.
PR #15 (run 16) has unrelated history — content applied manually in run 21/22.
Run 20 had diverged history — not merged; its Minmax.lean needs fresh creation.

## Current master state (after run 22 commit)
- FVSquad/Varint.lean: 10 theorems proved (no sorry) — MERGED
- FVSquad/RangeSet.lean: includes all proofs from run 22 (sorry: 2 remain)
  - Fixed merge conflict (stale import FVSquad.RttStats)
  - Added: sorted_disjoint_cons2_iff (@[simp]), sorted_disjoint_head_le_rest, covers_lt_start
  - Proved: remove_until_removes_small, remove_until_preserves_large, remove_until_preserves_invariant
- CORRESPONDENCE.md: NEW (run 22 branch)
- .github/workflows/lean-ci.yml: NEW (run 22 branch)

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
- **Phase**: 5 — Proofs (partial, pending merge)
- **Status**: 🔄 In progress — Run 22 branch pending PR
- **Proved (in run 22 branch)**:
    §7 structural: empty_sorted_disjoint, singleton_sorted_disjoint,
      empty_covers_nothing, singleton_covers_iff, insert_empty,
      remove_until_empty, insert_empty_covers, singleton_not_covers_left,
      singleton_not_covers_right, sorted_disjoint_tail, sorted_disjoint_head_valid
    §8: sorted_disjoint_cons2_iff (@[simp]), sorted_disjoint_head_le_rest
    §9: covers_lt_start
    §10 (remove_until): remove_until_removes_small, remove_until_preserves_large,
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
- **Phase**: 3 — Formal Spec (partial proofs) — NOT in master yet
- **Status**: ⬜ Run 20 PR has diverged history; needs fresh creation from scratch
- **What to do next run**: Create Minmax.lean fresh (it was in run 20 PR which had diverged history)
  Key proofs to tackle:
    - reset theorems (all by rfl/omega — easy)
    - running_min correctness theorems
    - min_val_inv_preserved (medium)
    - time_ordered_preserved (medium)

## Lean Toolchain
- **Version**: Lean 4.29.0
- **Installed at**: `~/.elan/bin/lean` (installed each run via elan)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **lean-toolchain**: `leanprover/lean4:v4.29.0`
- **lake build (run 22)**: PASSED, 0 errors, 2 sorry remaining

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
- `obtain ⟨hs, he⟩ := hd` works for `hd : Nat × Nat` to destructure
- `List.mem_cons_self` does NOT work in some contexts — use
  `List.mem_cons.mpr (Or.inl rfl)` instead
- For `heq : (ts, te) = (a, b)`, to get `ts = a`: 
  `have hts : ts = a := by have := congrArg Prod.fst heq; exact this`
- `sorted_disjoint_cons2_iff.mp` is NOT valid dot notation in this context —
  use `rw [sorted_disjoint_cons2_iff] at h` then destructure with `obtain`
- `simp [valid_range] at hv_s` is needed to unfold `valid_range s` into `s.1 < s.2`
  for omega to use it
- `Prod.fst` projections need `simp only [Prod.fst]` or destructuring for omega

## Correspondence
- **CORRESPONDENCE.md**: Added in run 22 branch (pending PR)
- Varint.lean: approximation (OR → addition); exact for pure value mapping
- RangeSet.lean: abstraction (dual repr, no capacity limit); exact for invariants
- No mismatches found
- Key gap: insert_covers_union does NOT hold unconditionally in Rust when
  capacity eviction fires — needs `len < capacity` precondition

## CI Status
- `lean-ci.yml`: ADDED in run 22 branch (PENDING PR/MERGE)
  Triggers on PR/push to formal-verification/lean/**
  Caches .lake artefacts on lean-toolchain hash
  NOT yet merged to master

## Status Issue
- **Issue #4** (open): `[Lean Squad] Formal Verification Status`
  Last updated in run 21 (needs run 22 update next run)

## Open PRs (as of run 22)
- **PR #15** (run 16): RangeSet remove_until proofs + CORRESPONDENCE.md
  Content superseded by run 22 branch
- **Run 22 branch** (lean-squad-run22-correspondence-ci-1775038123):
  COMMITTED, PR NOT CREATED (MCP server unavailable)
  Must create PR at start of next run

## Open Tasks for Next Run
1. **Create PR for run 22 branch** — MCP server was down, branch is committed
2. **Update Status Issue #4** — run 22 results not yet posted
3. **Create Minmax.lean** (Task 3) — fresh creation needed
4. **Prove insert_preserves_invariant** (Task 5 — hard)
   Need `range_insert_go_inv` generalised lemma — see strategy above
5. **Prove insert_covers_union** (Task 5 — hard, same technique)
6. **Write CRITIQUE.md** (Task 7)

## Aeneas Status
- Task 8 (Aeneas): NOT attempted — opam not available in sandbox
