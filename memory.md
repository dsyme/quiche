# Lean Squad Memory — dsyme/quiche

**Last updated**: 2026-03-28 09:56 UTC  
**Commit**: 2c51d0cc (lean-squad-run5-rangeset-proofs-1774689002)  
**Run**: https://github.com/dsyme/quiche/actions/runs/23681950678

## FV Targets

| # | Target | Location | Phase | Open PRs/Issues | Notes |
|---|--------|----------|-------|-----------------|-------|
| 1 | varint codec | `octets/src/lib.rs` | 5 — ALL PROVED (0 sorry) | PR #5 open | round_trip + first_byte_tag proved |
| 2 | RangeSet invariants | `quiche/src/ranges.rs` | 5 — ALL PROVED (0 sorry) | PR (run5 branch) | All 5 theorems proved this run |
| 3 | RTT estimation | `quiche/src/recovery/rtt.rs` | 1 — Research | — | RFC 9002 §5 EWMA |
| 4 | Flow control | `quiche/src/flowcontrol.rs` | 1 — Research | — | Arithmetic invariants |
| 5 | Minmax filter | `quiche/src/minmax.rs` | 1 — Research | — | Windowed min/max |

## Tool Choice

- **Lean 4.29.0** — no Mathlib (network firewall blocks download)
- Core tactics: `omega`, `simp`, `cases`, `native_decide`, `rw`, `induction`

## Key Files

- `formal-verification/RESEARCH.md` — target survey
- `formal-verification/TARGETS.md` — phase tracking (updated this run)
- `formal-verification/specs/varint_informal.md` — informal spec
- `formal-verification/specs/rangeset_informal.md` — informal spec
- `formal-verification/lean/FVSquad/Varint.lean` — Lean 4 spec+impl+proofs (10 theorems, 0 sorry)
- `formal-verification/lean/FVSquad/RangeSet.lean` — Lean 4 spec+impl+proofs (15+ theorems, 0 sorry)
- `formal-verification/lean/lakefile.toml` — Lake project (no Mathlib)
- `formal-verification/lean/lean-toolchain` — leanprover/lean4:v4.29.0

## Varint Codec (Target 1) — COMPLETE (Phase 5)

All 10 theorems proved. PR #5 open.

## RangeSet (Target 2) — COMPLETE (Phase 5)

### ALL theorems proved (no sorry) this run

**Helper lemmas (private):**
- `covers_false_of_all_above`: if all range starts > n, covers = false
- `sorted_disjoint_rest_ge`: tail elements start ≥ head.end
- `covers_append`: covers distributes over ++
- `bool_or4`: (A||B||(C||D)) = (A||(C||B)||D) for Bool
- `range_insert_go_covers`: generalised coverage via accumulator induction
- `sorted_disjoint_append_singleton`, `sorted_disjoint_concat`
- `range_insert_go_sorted`: generalised invariant via accumulator induction

**Main theorems (public):**
- `insert_preserves_invariant (I1+I2)` — insert keeps sorted_disjoint
- `insert_covers_union (I3)` — insert = union with [s,e)
- `remove_until_removes_small (I4a)` — no value ≤ v remains
- `remove_until_preserves_large (I4b)` — values > v preserved
- `remove_until_preserves_invariant` — invariant preserved

### Key implementation notes
- `range_insert_go` accumulator is in REVERSE order; reversed at end
- Adjacent ranges ARE merged
- Capacity eviction NOT modelled

## Lean Syntax Gotchas (v4.29.0 without Mathlib)

1. **Operator precedence**: `=` (prec 50) is TIGHTER than `||` (prec 30)!
   - `A || B || (C || D) = A || ...` is parsed as `A || B || (((C || D) = A) || ...) `
   - ALWAYS wrap both sides of `=` in parens: `(A || B || (C || D)) = (A || ...)`
2. `private lemma` is NOT valid — use `private theorem`
3. `hr.elim` fails for `hr : r ∈ []` — use `cases hr` instead
4. No `push_neg`, `split_ifs`, `ring` (Mathlib tactics)
5. `by_cases h : bool_expr` gives `h : ¬(bool_expr)` in false branch (not `h : bool_expr = false`)
   - Use `cases h : bool_expr` instead for clean `h : bool_expr = false/true`
6. `simp [h]` uses default simp set which includes `List.any_eq_true` (converts `any ... = true` to existential)
   - Prefer `simp only [h, Bool.false_or]` for targeted simplification
7. Bool induction: `cases (b : Bool)` gives two goals `b = false` and `b = true`

## CI Status

- lean-ci.yml could not be committed (protected workflow files)
- Manual maintainer action needed to enable CI

## Next Run Priorities

1. **Task 2**: Write informal spec for Target 3 (RTT estimation, rtt.rs)
2. **Task 3**: Write Lean spec for Target 3 (RTT estimation)
3. **Task 6**: Correspondence review (document Lean model vs Rust source)
4. **Task 7**: Proof utility critique

## Run History

### 2026-03-28 — Run 23681950678
- Tasks: Task 5 (RangeSet proofs) — COMPLETED
- All 5 RangeSet theorems proved: 0 sorry remain
- lake build PASSED with Lean 4.29.0
- Key lesson: bool_or4 needs parens around both sides of = due to precedence
- PR created this run for RangeSet proofs

### 2026-03-28 — Run 23676429830
- Tasks: 3 (Lean Spec — RangeSet), 9 (CI — blocked)
- RangeSet.lean: 10 structural lemmas proved, 5 sorry deferred
- PR created: lean-squad-run4-rangeset-spec branch

### 2026-03-28 — Run 23674446182
- ALL varint theorems proved (0 sorry), RangeSet informal spec written
- PR #5 pending

### 2026-03-27 — Run 23661997161 / 23661208608
- Research, varint informal spec (PR #2 merged), partial varint proofs
