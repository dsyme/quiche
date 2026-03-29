# Lean Squad Memory — dsyme/quiche

## Run History
- **Run 1**: Task 1 (Research) — identified targets, created RESEARCH.md + TARGETS.md
- **Run 2**: Task 2 (Informal Spec) — wrote `formal-verification/specs/rangeset_informal.md`
- **Run 3**: Task 3+5 (Lean Spec + Proofs) — Varint.lean 10 theorems proved; PR #5 merged to master
- **Run 4**: Task 3 (RangeSet Lean spec) — RangeSet.lean created; branch diverged from master
- **Run 6**: Task 2+3 (RTT) — RttStats.lean 21 theorems 0 sorry; branch diverged from master
- **Run 10-13**: Tasks 3+5+6+9 — various proofs + CORRESPONDENCE.md; all branches diverged from master
- **Run 14 (this)**: Tasks 3+4/5+9 — FlowControl.lean (24 theorems, 0 sorry) + RttStats.lean recovered + lean-ci.yml
  Branch: lean-squad-run14-flowcontrol-spec-1774803000 (PR created)

## IMPORTANT: Branch History Note
All lean-squad branches BEFORE run 14 are based on a DIFFERENT git history
(grafted, not reachable from current master e485077b). They cannot be merged
with --allow-unrelated-histories without conflicts. Run 14 successfully:
1. Copied RttStats.lean from run6 branch via `git show`
2. Fixed merge conflict in FVSquad.lean (RttStats import)
3. Added FlowControl.lean fresh on master-based branch

## FV Targets

### Target 1: QUIC varint codec
- **File**: `octets/src/lib.rs`
- **Lean file**: `formal-verification/lean/FVSquad/Varint.lean`
- **Phase**: 5 — Complete
- **Status**: ✅ In master — 10 theorems proved, 0 sorry (PR #5 merged)
- **Theorems**: varint_round_trip, encode_decode, decode_1byte, decode_2byte, decode_4byte, decode_8byte, encode_len_*, etc.

### Target 2: RangeSet invariants
- **File**: `quiche/src/ranges.rs`
- **Informal spec**: `formal-verification/specs/rangeset_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/RangeSet.lean`
- **Phase**: 5 — Proofs
- **Status**: 🔄 In progress — 290-line file with 5 sorry remaining
- **Note**: RangeSet.lean IS in master branch (was in PR #5 merged or base)
- **Sorry remaining**: insert_preserves_invariant, insert_covers_union,
  remove_until_removes_small, remove_until_preserves_large,
  remove_until_preserves_invariant
  (run13 memory was WRONG — these are NOT proved in master)
- **Strategy for insert_***: Needs generalised lemma for range_insert_go with
  accumulator invariant: complex induction

### Target 3: RTT estimation
- **File**: `quiche/src/recovery/rtt.rs`
- **Informal spec**: `formal-verification/specs/rtt_informal.md` (in run6 branch, NOT master)
- **Lean file**: `formal-verification/lean/FVSquad/RttStats.lean`
- **Phase**: 5 — Complete
- **Status**: ✅ In run14 PR — 21 theorems proved, 0 sorry (from run6, recovered in run14)
- **Theorems**: init_smoothed_rtt, init_rttvar, first_sample_smoothed, first_sample_rttvar,
  update_sets_has_first, adjust_plausible, adjust_implausible, adjust_le_latest,
  ewma_smoothed, ewma_rttvar, min_rtt_nonincreasing, loss_delay_ge_granularity,
  abs_diff_nat_*, ewma_convergence, etc.

### Target 4: Flow control
- **File**: `quiche/src/flowcontrol.rs`
- **Informal spec**: `formal-verification/specs/flowcontrol_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/FlowControl.lean`
- **Phase**: 5 — Complete
- **Status**: ✅ In run14 PR — 24 theorems proved, 0 sorry
- **Theorems**: new_*, should_update_*, max_data_next_eq, update_*, set_window_*,
  ensure_lower_bound_*, invariant preservation
- **Approximations**: Nat not u64, no autotune_window, no time

### Target 5: Minmax filter
- **File**: `quiche/src/minmax.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started (run10 branch has Minmax.lean but in diverged history)

## Lean Toolchain
- **Version**: Lean 4.29.0
- **Installed at**: `~/.elan/bin/lean` (installed each run)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **lean-toolchain**: `leanprover/lean4:v4.29.0`
- **lake build (run14)**: PASSED, 0 errors

## Key Lean 4.29.0 API Notes (no Mathlib)
- `lemma` NOT valid — use `theorem`
- `Nat.le_min_of_le_left` does NOT exist — use `simp [Nat.min_def]; split; omega/exact`
- For `if_pos h` / `if_neg h` to unfold if-then-else in simp
- `simp [window_bounded, ...]` may leave a goal — use `exact h` afterwards
- `split` tactic splits on if-then-else and cases
- `decide` works for concrete Nat computations
- `omega` handles linear arithmetic on Nat

## CI Status
- `lean-ci.yml`: CREATED in run14 PR
  Triggers: PR + push to main/master for formal-verification/lean/**
  Caches: .lake keyed on lake-manifest.json hash

## Status Issue
- **Issue #4** (open): `[Lean Squad] Formal Verification Status`
  Updated in run14 with current state

## Current Run14 PR
- Branch: lean-squad-run14-flowcontrol-spec-1774803000
- Contains: FlowControl.lean, RttStats.lean, lean-ci.yml, flowcontrol_informal.md, FVSquad.lean fix

## Open Tasks for Next Run
1. **Prove remove_until theorems** (Task 5 — high priority, RangeSet.lean)
   sorry: remove_until_removes_small, remove_until_preserves_large, remove_until_preserves_invariant
   Strategy: induction on rs, case-split on the three branches of range_remove_until
2. **Prove insert_preserves_invariant** (Task 5 — hard, needs generalised induction)
   Strategy: generalise range_insert_go with accumulator invariant lemma
3. **Write Minmax.lean spec** (Task 3) — Target 5, Phase 1, not started
   Source: quiche/src/minmax.rs (windowed min-max filter, Kathleen Nichols algorithm)
4. **Merge run14 PR** into master to stabilise

## Aeneas Status
- Task 8 (Aeneas): NOT attempted — opam not available in sandbox
  Documented as blocked in memory for future runs
