# Lean Squad Memory — dsyme/quiche

## Run History
- **Run 1**: Task 1 (Research) — identified targets, created RESEARCH.md + TARGETS.md
- **Run 2**: Task 2 (Informal Spec) — wrote `formal-verification/specs/rangeset_informal.md`
- **Run 3**: Task 3+5 (Lean Spec + Proofs) — Varint.lean 10 theorems proved; PR #5 merged to master
- **Run 4**: Task 3 (RangeSet Lean spec) — RangeSet.lean created; PR #6 merged to master
- **Runs 5–14**: Various branches (not all merged — diverged history)
- **Run 15**: Tasks 5+9 — proved 3 remove_until theorems + lean-ci.yml (never merged)
- **Run 16**: Tasks 5+6 — proved 3 remove_until theorems + CORRESPONDENCE.md; PR #15 open
- **Run 17**: Tasks 5+9 — proved insert_covers_union (not merged; branch gone)
- **Run 18**: Tasks 6+9 — no content changes persisted
- **Run 19**: Tasks 6+9 — CORRESPONDENCE.md + lean-ci.yml + RangeSet proofs (PR created, never merged)
- **Run 20**: Tasks 9+3 — lean-ci.yml + Minmax.lean spec (diverged history, not merged)
- **Run 21**: Tasks 5+6+9 — remove_until proofs + CORRESPONDENCE.md + lean-ci.yml (PR created)
- **Run 22**: Tasks 6+9+5 — same content, MCP server down, PR not created
- **Run 23 (this)**: Tasks 3+9+6 (Aeneas substituted by Task 3)
  - Branch: lean-squad-run23-minmax-ci-1775064920 (PR CREATED)
  - Applied PR #15 content (remove_until proofs, CORRESPONDENCE.md, FVSquad.lean fix)
  - New: Minmax.lean (15 proved theorems, 0 sorry)
  - New: .github/workflows/lean-ci.yml
  - lake build: PASSED, 2 sorry remain (RangeSet insert theorems)

## IMPORTANT: Branch History Note
All lean-squad branches BEFORE run 15 are based on a DIFFERENT git history
(grafted). Only PRs #2, #5, #6 were successfully merged to master.
PR #15 (run 16) has unrelated history — content applied manually in runs 21-23.

## Current master state (as of run 23 branch, pending PR merge)
- FVSquad/Varint.lean: 10 theorems proved (no sorry) — MERGED
- FVSquad/RangeSet.lean: 290→441 lines, 3 remove_until proofs + 3 auxiliary lemmas
  - Proved: remove_until_removes_small, remove_until_preserves_large,
    remove_until_preserves_invariant, covers_above_bound_false,
    sorted_disjoint_all_ge_head_end, sorted_disjoint_cons2_iff
  - Sorry remaining: insert_preserves_invariant, insert_covers_union (2)
- FVSquad/Minmax.lean: NEW 15 theorems proved (0 sorry)
- CORRESPONDENCE.md: NEW
- .github/workflows/lean-ci.yml: NEW

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
- **Phase**: 5 — Proofs (partial, pending PR merge)
- **Status**: 🔄 In progress — Run 23 branch pending PR merge
- **Proved**:
    §7 structural: empty_sorted_disjoint, singleton_sorted_disjoint,
      empty_covers_nothing, singleton_covers_iff, insert_empty,
      remove_until_empty, insert_empty_covers, singleton_not_covers_left,
      singleton_not_covers_right, sorted_disjoint_tail, sorted_disjoint_head_valid
    §8: sorted_disjoint_cons2_iff (@[simp])
    §9: covers_above_bound_false, sorted_disjoint_all_ge_head_end
    §10 (remove_until): remove_until_removes_small, remove_until_preserves_large,
      remove_until_preserves_invariant
- **Sorry remaining**: insert_preserves_invariant, insert_covers_union (2)
- **Strategy for insert proofs (hard — deferred)**:
    Need generalised induction over range_insert_go with accumulator invariant.
    Required invariants at each call to range_insert_go acc_rev rest s e:
      (I1) s < e
      (I2) sorted_disjoint acc_rev.reverse
      (I3) ∀ a ∈ acc_rev, a.2 ≤ s  (acc elements end before new range starts)
      (I4) sorted_disjoint rest
      (I5) ∀ a ∈ acc_rev, ∀ r ∈ rest, a.2 ≤ r.1  (acc precedes rest)
    Need helper lemma: sorted_disjoint_append_singleton
      (l : RangeSetModel) (s e) h_sd h_upper h_range → sorted_disjoint (l ++ [(s,e)])
    The "skip" branch maintains I2 using sorted_disjoint_append_singleton with
    h_upper_rs: ∀ a ∈ acc_rev, a.2 ≤ rs (from I5 with r = (rs,re))

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
- **Phase**: 3+5 — Spec + Proofs (partial — pending PR merge)
- **Status**: 🔄 Run 23 branch pending PR
- **Proved (15 theorems, 0 sorry)**:
    Reset: reset_returns_meas, reset_all_equal, reset_min_val_inv,
      reset_time_ordered, reset_s0_value, reset_s0_time
    running_min (reset branches): running_min_new_min_returns_meas,
      running_min_new_min_all_equal, running_min_win_elapsed_all_equal,
      running_min_win_elapsed_returns_meas
    running_min (non-reset): running_min_best_unchanged, running_min_returns_s0
    Invariant: reset_establishes_inv, running_min_reset_preserves_inv,
      running_min_update_s1_s2_preserves_inv
- **What to do next**: Prove min_val_inv preserved for the non-reset no-subwin
    cases (h_no_reset, ¬h_s1, h_s2) and subwin cases

## Lean Toolchain
- **Version**: Lean 4.29.0
- **Installed at**: `~/.elan/bin/lean` (installed each run via elan)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **lean-toolchain**: `leanprover/lean4:v4.29.0`
- **lake build (run 23)**: PASSED, 0 errors, 2 sorry remaining (RangeSet)

## Key Lean 4.29.0 API Notes (no Mathlib)
- `lemma` keyword NOT supported — use `theorem` instead!
- `split_ifs` NOT available without Mathlib — use `by_cases h : cond`
  then `simp only [if_pos h]` or `simp only [if_neg h]` separately
- `simp [cond]` where cond is a Bool hypothesis: use `simp only [h, ite_true]`
  or `simp only [h, ite_false]` for if-then-else on Bool
- After `by_cases h : P` + `simp [h]`, simp may close the goal — don't add more tactics
  Use `by_cases; <tac>` pattern and check each branch independently
- `unfold` on a def is safe; `simp [defname]` may get confused with nested defs
- `exact sublemma_name _ _ _ _ _ _` works for applying helper lemmas
- `native_decide` works for decidable small-Nat computations on concrete values
- `omega` handles Nat linear arithmetic; use after simp to discharge goals
- For structure fields: `{ st with s2 := newSample }` creates updated struct
- `Prod.fst`/`Prod.snd` or `.1`/`.2` for pair projections

## Correspondence
- **CORRESPONDENCE.md**: Added in run 23 branch (pending PR merge)
- Varint.lean: approximation (OR → addition); exact for pure value mapping
- RangeSet.lean: abstraction (dual repr, no capacity limit)
- Minmax.lean: abstraction (Nat time, Bool flags for Duration)
- No mismatches found
- Key gap: insert_covers_union needs `len < capacity` precondition in Rust

## CI Status
- `lean-ci.yml`: ADDED in run 23 branch (pending PR merge)
  Triggers on PR/push to formal-verification/lean/**
  Caches .lake artefacts on lake-manifest.json hash

## Status Issue
- **Issue #4** (open): `[Lean Squad] Formal Verification Status`
  Last updated run 23 ✅

## Open PRs (as of run 23)
- **PR #15** (run 16): Content SUPERSEDED by run 23 branch
- **Run 23 branch** (lean-squad-run23-minmax-ci-1775064920): PR CREATED ✅

## Aeneas Status
- Task 8 (Aeneas): NOT possible — opam requires sudo (no new privileges flag in container)
  Tried runs 16, 21, 22, 23 — all fail. Skip task 8 in future runs.

## Open Tasks for Next Run
1. **Prove insert_preserves_invariant** (Task 5 — hard)
   Need sorted_disjoint_append_singleton helper + range_insert_go_sd generalized induction
2. **Prove insert_covers_union** (Task 5 — hard, same technique)
3. **Write CRITIQUE.md** (Task 7)
4. **RTT estimation Lean spec** (Task 3) — rtt.rs has pure-functional properties
5. **Minmax: more invariant theorems** (Task 5) — non-reset cases
