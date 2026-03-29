# Lean Squad Memory — dsyme/quiche

## Run History
- **Run 1**: Task 1 (Research) — identified targets, created RESEARCH.md + TARGETS.md; PR #2 merged
- **Run 2**: Task 2 (Informal Spec) — wrote `formal-verification/specs/rangeset_informal.md`
- **Run 3**: Task 3+5 (Lean Spec + Proofs) — Varint.lean 10 theorems proved; PR #5 merged
- **Run 4**: Task 3 (RangeSet Lean spec) — 5 sorry remaining; PR #6 (open issue)
- **Run 6**: Task 2+3 (RTT) — RttStats.lean 21 theorems 0 sorry; branch lean-squad-run6-rtt-spec
- **Run 10**: Tasks 3+9 — Minmax.lean spec + lean-ci.yml; PR (open issue)
- **Run 11**: Tasks 5+9 — 3 RangeSet remove_until theorems; PR created (superseded)
- **Run 12**: Tasks 5+9 — Proved 3 remove_until theorems; created lean-ci.yml; PR created
  Branch: lean-squad-run12-proofs-ci-1774756106
- **Run 13 (this)**: Tasks 5+6+9 — Proved 3 remove_until theorems; CORRESPONDENCE.md; lean-ci.yml
  Branch: lean-squad-run13-proofs-correspondence-ci

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
- **Status**: 🔄 In progress — 19 proved, 2 sorry remaining
- **PR**: lean-squad-run13-proofs-correspondence-ci (current run, open PR)
- **Proved (runs 12+13)**: sd_hd_end_le_next_start, sd_tail_starts_ge_end,
  covers_false_of_all_starts_gt (helpers), remove_until_removes_small (I4a),
  remove_until_preserves_large (I4b), remove_until_preserves_invariant
- **Sorry remaining**: insert_preserves_invariant, insert_covers_union
  (require generalised induction on range_insert_go with accumulator invariant)

### Target 3: RTT estimation
- **File**: `quiche/src/recovery/rtt.rs`
- **Informal spec**: `formal-verification/specs/rtt_informal.md`
- **Lean file**: `formal-verification/lean/FVSquad/RttStats.lean`
- **Phase**: 5 — Proofs
- **Status**: ✅ COMPLETE — 21 theorems proved, 0 sorry
- **Note**: RttStats.lean is NOT in master yet (only in unmerged PR branches)

### Target 4: Flow control
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started

### Target 5: Minmax filter
- **File**: `quiche/src/minmax.rs`
- **Phase**: 1 — Research
- **Status**: ⬜ Not started

## CORRESPONDENCE.md
- **Created run 13**: `formal-verification/CORRESPONDENCE.md`
- Documents Varint.lean and RangeSet.lean correspondence to Rust source
- Correspondence level per function: exact/abstraction
- Known divergences: capacity eviction, u64 vs Nat, bitwise vs arithmetic

## Lean Toolchain
- **Version**: Lean 4.29.0 (installed at `~/.elan/bin/lean`)
- **Project**: `formal-verification/lean/` (lakefile.toml, no Mathlib)
- **lean-toolchain**: `leanprover/lean4:v4.29.0`
- **lake build**: PASSED (2 sorry: insert_preserves_invariant + insert_covers_union)

## Key Lean 4.29.0 API Notes (no Mathlib)
- `lemma` keyword NOT valid — use `theorem` or `private theorem`
- `List.mem_cons_self` takes NO explicit args; use `List.mem_cons.mpr (Or.inl rfl)`
- For Bool case split: `cases h : myBool with | true => ... | false => ...`
- `Bool.eq_false_or_eq_true` gives `b = false ∨ b = true`
  CAUTION: first case is `false`, second is `true`. Prefer `cases h : b with | true | false`
- `Bool.or_eq_true : ((a || b) = true) = (a = true ∨ b = true)` — EXISTS ✓
- `Bool.false_or : false || b = b` — available in core ✓
- `simp [in_range]; omega` works for goals involving `in_range r n = false/true` ✓
- `simp [in_range] at h; omega` extracts `r.1 ≤ n` and `n < r.2` from `h : in_range r n = true` ✓
- `split_ifs` NOT available; use `by_cases h : cond; rw [if_pos h / if_neg h]`
- `simp only [range_remove_until]` may not simplify `if` chains; use `rw [if_pos/if_neg]`
- For pattern matching on `List (Nat × Nat)` in induction:
  use `| cons r tail ih => obtain ⟨s, e⟩ := r` NOT `| cons ⟨s, e⟩ tail ih =>`
- Well-founded recursion on List: use pattern match style `fun ... | [], ... => ... | ⟨a, b⟩ :: rest, ... => ...`

## CI Status
- `lean-ci.yml`: CREATED in run 13 PR
  Triggers on: PR + push to main/master modifying formal-verification/lean/**
  Caches: .lake keyed on lake-manifest.json hash

## Status Issue
- Issue #4 (open): `[Lean Squad] Formal Verification Status`

## PR Status
- PR #5: merged (Varint.lean + RangeSet informal spec)
- lean-squad-run13-proofs-correspondence-ci: current run PR (RangeSet proofs + CORRESPONDENCE + lean-ci.yml)
  NOT yet merged (RttStats.lean from run 6 also not merged)

## Open Tasks for Next Run
1. **Prove insert sorry theorems** (Task 5 — high priority):
   Strategy: define generalised lemma for range_insert_go:
   `range_insert_go_preserves_inv : sorted_disjoint (acc_rev.reverse) →
    sorted_disjoint rest → (∀ r ∈ acc_rev, r.2 < s) →
    sorted_disjoint (range_insert_go acc_rev rest s e)`
   This is complex; requires tracking the invariant of the accumulator.
2. **Add RttStats.lean to a PR** (Task 4/5) — the RTT proofs exist locally but are not merged
3. **Write FlowControl informal+Lean spec** (Tasks 2+3) — Phase 1, not started
4. **Verify lean-ci.yml works** (Task 9) — check CI runs once PR is merged

## Aeneas Status
- **Task 8 (Aeneas)**: NOT attempted (opam not available in sandbox; GitHub Actions runners may have it)
