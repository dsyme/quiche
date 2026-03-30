# Lean Squad Memory — dsyme/quiche

## Run History
- **Run 1**: Task 1 (Research) — identified targets, created RESEARCH.md + TARGETS.md
- **Run 2**: Task 2 (Informal Spec) — wrote `formal-verification/specs/rangeset_informal.md`
- **Run 3**: Task 3+5 (Lean Spec + Proofs) — Varint.lean 10 theorems proved; PR #5 merged to master
- **Run 4**: Task 3 (RangeSet Lean spec) — RangeSet.lean created; PR #6 merged to master
- **Runs 5–14**: Various branches (not all merged — diverged history)
- **Run 15**: Tasks 5+9 — proved 3 remove_until theorems + lean-ci.yml on branch that was never merged
- **Run 16 (this)**: Tasks 5+6 — proved 3 remove_until theorems (again, since run15 not merged) + CORRESPONDENCE.md
  Branch: lean-squad-run16-proofs-correspondence-1743329999 (PR pending)

## IMPORTANT: Branch History Note
All lean-squad branches BEFORE run 15 are based on a DIFFERENT git history
(grafted, not reachable from current master e485077b). Only PRs #2, #5, #6
were successfully merged. Runs 15–16 are based on master with those PRs merged.
RttStats.lean and FlowControl.lean from older runs have NOT been recovered.
FVSquad.lean had a merge conflict (stale RttStats import) — fixed in run 16.

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
- **Status**: 🔄 In progress — Run 16 PR pending
- **Proved (run 16)**: remove_until_removes_small, remove_until_preserves_large,
  remove_until_preserves_invariant + 3 helper lemmas + 10 structural lemmas from before
- **Sorry remaining**: insert_preserves_invariant, insert_covers_union
- **Strategy for insert_***: Need generalised lemma for range_insert_go with
  accumulator invariant:
  - acc_rev.reverse is sorted_disjoint
  - All acc_rev elements end before the merge window start s
  - The whole result is sorted when acc_rev.reverse ++ processed_tail
  IMPORTANT: insert_covers_union does NOT hold unconditionally in Rust due to
  capacity eviction — will need `len < capacity` precondition!

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
- **lake build (run 16)**: PASSED, 0 errors, 2 sorry remaining

## Key Lean 4.29.0 API Notes (no Mathlib)
- `List.mem_cons_self` has ALL IMPLICIT args — use without `_ _`
- `split_ifs` NOT available without Mathlib — use `by_cases` + `rw [if_pos/if_neg h]`
- CRITICAL: `=` has HIGHER precedence than `||`, so
  `a || b = false` parses as `a || (b = false)`. Always add explicit parens:
  `(a || b) = false`
  For `have` statements: `have h : a = (b || c) := rfl` NOT `a = b || c`
- `show` uses definitional equality
- `Bool.or_false : b || false = b`, `Bool.false_or : false || b = b` — exist
- `Bool.true_or : true || b = true`, `Bool.or_true : b || true = true` — exist
- `simp [in_range]; omega` — works for Bool Nat comparisons
- `omega` handles linear arithmetic on Nat including ≤, <, ¬≤, ¬<
- `List.not_mem_nil s` gives `False` not `¬s ∈ []` — use `simp at hs` instead
  for `hs : s ∈ []`
- `simp only [sorted_disjoint]` may loop — prefer `sorted_disjoint_cons2_iff`
  helper or unfold manually with `rw`
- `induction rs generalizing head` — useful for helper lemmas that need to
  vary the head parameter through induction

## Correspondence
- **CORRESPONDENCE.md**: Created in run 16
- Varint.lean: approximation (OR → addition); exact for pure value mapping
- RangeSet.lean: abstraction (dual repr, no capacity limit); exact for invariants
- No mismatches found
- Key gap: insert_covers_union needs capacity precondition

## CI Status
- `lean-ci.yml`: NOT YET IN MASTER — was in run15 branch that wasn't merged
  Need to re-add in future run. Files exist under formal-verification/lean/**

## Status Issue
- **Issue #4** (open): `[Lean Squad] Formal Verification Status`
  Updated in run 16

## Current Run16 PR
- Branch: lean-squad-run16-proofs-correspondence-1743329999
- Contains: 3 proved remove_until theorems + helper lemmas + CORRESPONDENCE.md + FVSquad.lean fix

## Aeneas Status
- Task 8 (Aeneas): NOT attempted — opam not available in sandbox
  Documented as blocked for future runs. Try installing opam via apt-get if available.

## Open Tasks for Next Run
1. **Add lean-ci.yml** (Task 9 — HIGH PRIORITY: has_ci=false but Lean files exist)
   Create .github/workflows/lean-ci.yml to check proofs in CI
2. **Prove insert_preserves_invariant** (Task 5 — hard)
   Need generalised range_insert_go lemma with acc invariant
3. **Prove insert_covers_union** (Task 5 — hard, + needs capacity precondition)
4. **Write RttStats.lean spec** (Task 3) — Target 3, needs re-creation from scratch
5. **Write CRITIQUE.md** (Task 7)
