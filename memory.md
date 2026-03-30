# Lean Squad Memory — dsyme/quiche

## Run History
- **Run 1**: Task 1 (Research) — identified targets, created RESEARCH.md + TARGETS.md
- **Run 2**: Task 2 (Informal Spec) — wrote `formal-verification/specs/rangeset_informal.md`
- **Run 3**: Task 3+5 (Lean Spec + Proofs) — Varint.lean 10 theorems proved; PR #5 merged to master
- **Run 4**: Task 3 (RangeSet Lean spec) — RangeSet.lean created; PR #6 merged to master
- **Run 15 (this)**: Tasks 5+9 — proved 3 remove_until theorems + lean-ci.yml
  Branch: lean-squad-run15-rangeset-proofs-1774842718 (PR pending)

## IMPORTANT: Branch History Note
All lean-squad branches BEFORE run 15 are based on a DIFFERENT git history
(grafted, not reachable from current master e485077b). Only PRs #2, #5, #6
were successfully merged. Run 15 is based on master with those PRs merged.
RttStats.lean and FlowControl.lean from older runs have NOT been recovered
(they were in branches with diverged history that were never merged).

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
- **Status**: 🔄 In progress — 2 sorry remaining (insert_*)
- **Proved (run 15)**: remove_until_removes_small, remove_until_preserves_large,
  remove_until_preserves_invariant (+ 10 structural lemmas from before)
- **Sorry remaining**: insert_preserves_invariant, insert_covers_union
- **Strategy for insert_***: Need generalised lemma for range_insert_go with
  accumulator invariant: complex induction, future run

### Target 3: RTT estimation
- **File**: `quiche/src/recovery/rtt.rs`
- **Phase**: 1 — Not in master
- **Status**: ⬜ Pending — was in run6/run14 branches but never merged

### Target 4: Flow control
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 1 — Not in master
- **Status**: ⬜ Pending — was in run14 branch but never merged

### Target 5: Minmax filter
- **File**: `quiche/src/minmax.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started

## Lean Toolchain
- **Version**: Lean 4.29.0
- **Installed at**: `~/.elan/bin/lean` (installed each run)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **lean-toolchain**: `leanprover/lean4:v4.29.0`
- **lake build (run 15)**: PASSED, 0 errors, 2 sorry remaining

## Key Lean 4.29.0 API Notes (no Mathlib)
- `List.mem_cons_self` has ALL IMPLICIT args — use without `_ _`
- `split_ifs` NOT available without Mathlib — use `by_cases` + `rw [if_pos/if_neg]`
- Operator precedence: `=` has higher precedence than `||`, so
  `a || b = false` parses as `a || (b = false)`. Always add explicit parens:
  `(a || b) = false`
- `show` uses definitional equality — works for unfolding covers/range_remove_until
- `unfold f` on `f concrete_arg = f free_arg` only unfolds the LHS (not RHS)
- For reducing `range_remove_until ((s,e)::tl) v`:
  Use `show (if e ≤ v+1 then ... else ...) = result` then `rw [if_pos/if_neg h]`
- `Bool.or_false : b || false = b`, `Bool.false_or : false || b = b` — exist
- `simp [in_range]; omega` — works for Bool Nat comparisons
- `omega` handles linear arithmetic on Nat including ≤, <, ¬≤, ¬<

## CI Status
- `lean-ci.yml`: CREATED in run15 PR
  Triggers: PR + push to master for formal-verification/lean/**
  Caches: .lake keyed on lake-manifest.json hash

## Status Issue
- **Issue #4** (open): `[Lean Squad] Formal Verification Status`
  To be updated this run

## Current Run15 PR
- Branch: lean-squad-run15-rangeset-proofs-1774842718
- Contains: 3 proved remove_until theorems + lean-ci.yml + FVSquad.lean fix

## Open Tasks for Next Run
1. **Prove insert_preserves_invariant** (Task 5 — hard)
   Strategy: Need generalised lemma for range_insert_go with acc_rev invariant:
   - acc_rev (reversed) is sorted_disjoint
   - All acc_rev elements end before s
   - The whole result is sorted when acc_rev.reverse ++ processed_tail
2. **Prove insert_covers_union** (Task 5 — hard, same strategy)
3. **Write RttStats.lean spec** (Task 3) — Target 3, needs re-creation from scratch
4. **Write FlowControl.lean spec** (Task 3) — Target 4, needs re-creation

## Aeneas Status
- Task 8 (Aeneas): NOT attempted — opam not available in sandbox
  Documented as blocked for future runs
