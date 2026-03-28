# Lean Squad Memory — dsyme/quiche

**Last updated**: 2026-03-28 03:26 UTC  
**Commit**: b2ac0f55 (lean-squad-run4-rangeset-spec-a8f93c12)  
**Run**: https://github.com/dsyme/quiche/actions/runs/23676429830

## FV Targets

| # | Target | Location | Phase | Open PRs/Issues | Notes |
|---|--------|----------|-------|-----------------|-------|
| 1 | varint codec | `octets/src/lib.rs` | 5 — ALL PROVED (0 sorry) | PR #5 open | round_trip + first_byte_tag proved |
| 2 | RangeSet invariants | `quiche/src/ranges.rs` | 3 — Lean Spec | PR (run4 branch) | RangeSet.lean written, 5 sorry remain |
| 3 | RTT estimation | `quiche/src/recovery/rtt.rs` | 1 — Research | — | RFC 9002 §5 EWMA |
| 4 | Flow control | `quiche/src/flowcontrol.rs` | 1 — Research | — | Arithmetic invariants |
| 5 | Minmax filter | `quiche/src/minmax.rs` | 1 — Research | — | Windowed min/max |

## Tool Choice

- **Lean 4.29.0** — no Mathlib (network firewall blocks download)
- Core tactics: `omega`, `simp`+`if_pos`/`if_neg`, `by_cases`, `native_decide`, `rw`, `trivial`

## Key Files

- `formal-verification/RESEARCH.md` — target survey
- `formal-verification/TARGETS.md` — phase tracking (updated this run)
- `formal-verification/specs/varint_informal.md` — informal spec (merged in PR #2)
- `formal-verification/specs/rangeset_informal.md` — informal spec (in PR #5)
- `formal-verification/lean/FVSquad/Varint.lean` — Lean 4 spec+impl+proofs (10 theorems, 0 sorry)
- `formal-verification/lean/FVSquad/RangeSet.lean` — Lean 4 spec (this run)
- `formal-verification/lean/lakefile.toml` — Lake project (no Mathlib)
- `formal-verification/lean/lean-toolchain` — leanprover/lean4:v4.29.0

## Varint Codec (Target 1) — COMPLETE (Phase 5)

### ALL theorems proved (no sorry)
- `varint_len_nat_1/2/4/8` : branch postconditions
- `varint_len_nat_valid` : result ∈ {1, 2, 4, 8} for valid inputs
- `varint_parse_len_nat_valid` : result ∈ {1, 2, 4, 8} for all bytes
- `varint_len_nat_mono` : a ≤ b → varint_len_nat a ≤ varint_len_nat b
- `varint_encode_length` : encode produces exactly varint_len_nat v bytes
- **`varint_round_trip`** : decode(encode(v)) = v for ALL valid v
- **`varint_first_byte_tag`** : first byte's top-2-bits = length class

## RangeSet (Target 2) — Phase 3

### Lean file: FVSquad/RangeSet.lean
- `RangeSetModel = List (Nat × Nat)` — sorted list of (start, end) pairs
- `sorted_disjoint` predicate (I1+I2)
- `covers`, `in_range` membership predicates
- `range_insert` — functional insert with overlap merging (range_insert_go worker)
- `range_remove_until` — prefix removal with trimming
- 14 `native_decide` examples from test cases (all passing)

### Proved structural lemmas (no sorry)
- `empty_sorted_disjoint`, `singleton_sorted_disjoint`
- `empty_covers_nothing`, `singleton_covers_iff`
- `insert_empty`, `remove_until_empty`, `insert_empty_covers`
- `singleton_not_covers_left`, `singleton_not_covers_right`
- `sorted_disjoint_tail`, `sorted_disjoint_head_valid`

### Deferred theorems (5 sorry — Task 5 next)
- `insert_preserves_invariant (I1+I2)` — structural induction on rs, 3-way case split
- `insert_covers_union (I3)` — key union property
- `remove_until_removes_small (I4a)` — no value ≤ v remains
- `remove_until_preserves_large (I4b)` — values > v preserved
- `remove_until_preserves_invariant` — invariant preserved

### Proof strategy hints for Task 5
- For insert_preserves_invariant: induction on rs, case split on range_insert_go branches
  - "skip" branch: head unchanged, tail shrinks, IH applies
  - "insert before" branch: new range < head, trivially sorted
  - "merge" branch: merged range min(s,rs)..max(e,re) needs validity + position proof
- For insert_covers_union: induction on rs with careful case analysis
- For remove_until: simpler structure — the function is primitive recursive on the list

### Key implementation notes
- `range_insert_go` uses accumulator in REVERSE order; reverses at the end
- Adjacent ranges (end == start) ARE merged by the implementation
- Capacity eviction NOT modelled; theorems are unconditional in functional model

## CI Status

- **NOTE**: lean-ci.yml could not be committed (protected workflow files).
  Manual maintainer action needed to enable CI.
- Lean toolchain: v4.29.0 (stable)
- Mathlib: unavailable (network firewall); proofs use core Lean 4 only

## Proof Techniques (learned)

1. For if-then-else goals without Mathlib:
   - Use `simp [ha, hb, ...]` with boolean hypotheses
   - Use `by_cases` for all conditions, then `simp [h1, h2] <;> omega`

2. For existence theorems: `exact ⟨witness, proof1, proof2⟩`

3. omega limitations in Lean 4.29.0:
   - CANNOT unfold opaque `def` — use `have : x = n := ...` first
   - DOES handle nested div/mod for constant divisors

4. For sorted_disjoint proofs:
   - `simp [sorted_disjoint]` unfolds nicely
   - Pattern match with `cases rs with | nil | cons s rest`

5. Key: `trivial` closes `True` goals (for empty/nil base cases)

## Open Questions

1. Can Mathlib be installed in future runs? (Try: `lake update` with network access)
2. For RangeSet insert_covers_union: need to track what the accumulator covers
3. Is there a cleaner way to prove insert_preserves_invariant without acc reversal?

## Run History

### 2026-03-28 — Run 23676429830
- Tasks: 3 (Lean Spec — RangeSet), 9 (CI — blocked)
- Lean 4.29.0 working
- RangeSet.lean written: 10 structural lemmas proved, 5 sorry deferred
- 14 native_decide examples all passing
- PR created: lean-squad-run4-rangeset-spec-a8f93c12

### 2026-03-28 — Run 23674446182
- Tasks: 5 (varint proofs — complete), 2 (RangeSet informal spec)
- ALL varint theorems proved: varint_round_trip + varint_first_byte_tag (0 sorry)
- RangeSet informal spec written: specs/rangeset_informal.md
- PR #5 pending

### 2026-03-27 — Run 23661997161
- Tasks: 3 (Formal Spec), 4 (Implementation), 9 (CI)
- 5 structural theorems proved, 2 sorry remained
- CI setup blocked by GitHub Actions permission model

### 2026-03-27 — Run 23661208608
- Tasks: 1 (Research), 2 (Informal Spec — varint)
- PR #2 merged: RESEARCH.md, TARGETS.md, varint_informal.md

## Next Run Priorities

1. Task 5: Prove RangeSet deferred theorems
   - Start with `remove_until_removes_small` (simpler induction)
   - Then `insert_preserves_invariant` (harder, needs 3-way case split)
   - Then `insert_covers_union` (the key I3 property)
2. Task 6: Correspondence review — document Lean model vs Rust source
3. Task 9: CI — needs maintainer action to add lean-ci.yml
