# Lean Squad Memory — dsyme/quiche

**Last updated**: 2026-03-28 12:30 UTC  
**Commit**: ab1754a1 (lean-squad-run7-flowcontrol-1774699596-431a07319e9c00eb)  
**Run**: https://github.com/dsyme/quiche/actions/runs/23684817578

## FV Targets

| # | Target | Location | Phase | Open PRs/Issues | Notes |
|---|--------|----------|-------|-----------------|-------|
| 1 | varint codec | `octets/src/lib.rs` | 5 — ALL PROVED (0 sorry) | PR #5 open | round_trip + first_byte_tag proved |
| 2 | RangeSet invariants | `quiche/src/ranges.rs` | 5 — ALL PROVED (0 sorry) | PR #6 open (5 sorrys — old) | All 5 theorems proved in run5 branch, not yet in PR #6 |
| 3 | RTT estimation | `quiche/src/recovery/rtt.rs` | 5 — ALL PROVED (0 sorry) | branch: run6 (no PR created) | 21 theorems, RFC 9002 §5 |
| 4 | Flow control | `quiche/src/flowcontrol.rs` | 5 — ALL PROVED (0 sorry) | PR (run 7, just created) | 35 theorems, RFC 9000 §4 |
| 5 | Minmax filter | `quiche/src/minmax.rs` | 1 — Research | — | Windowed min/max |

## Tool Choice

- **Lean 4.29.0** — no Mathlib (network firewall blocks download)
- Core tactics: `omega`, `simp`, `cases`, `native_decide`, `rw`, `induction`, `split`, `by_cases`

## Key Files

- `formal-verification/RESEARCH.md` — target survey
- `formal-verification/TARGETS.md` — phase tracking
- `formal-verification/specs/varint_informal.md`
- `formal-verification/specs/rangeset_informal.md`
- `formal-verification/specs/rtt_informal.md`
- `formal-verification/specs/flowcontrol_informal.md` ← NEW run 7
- `formal-verification/lean/FVSquad/Varint.lean` — 10 theorems, 0 sorry
- `formal-verification/lean/FVSquad/RangeSet.lean` — 10 lemmas proved, 5 sorry (PR #6 version)
- `formal-verification/lean/FVSquad/RttStats.lean` — 21 theorems, 0 sorry
- `formal-verification/lean/FVSquad/FlowControl.lean` — 35 theorems, 0 sorry ← NEW run 7
- `formal-verification/lean/lakefile.toml`
- `formal-verification/lean/lean-toolchain` — leanprover/lean4:v4.29.0
- `.github/workflows/lean-ci.yml` — in RTT branch (pending maintainer merge)

## Varint Codec (Target 1) — COMPLETE (Phase 5)

All 10 theorems proved. PR #5 open (pending merge).

## RangeSet (Target 2) — COMPLETE (Phase 5)

All 5 key theorems proved in run5 branch. PR #6 shows old 5-sorry version.
Next run should add proofs to PR #6 or create a new PR with the proved version.

**WARNING**: The run5 proofs exist in memory (merged into run7 branch) but PR #6 still shows old code.
The run7 branch includes the proved RangeSet from run5.

## RTT Estimation (Target 3) — COMPLETE (Phase 5)

21 theorems proved in run6 branch. No PR was created for the RTT work (branch exists but no PR).
The run7 branch includes the RTT work (merged during run7 setup).

## Flow Control (Target 4) — COMPLETE (Phase 5) — NEW in run 7

35 theorems proved in run7 branch. PR created (FlowControl).

Key theorems:
- `new_window_valid` — I1: window ≤ max_window after construction
- `update_max_data_monotone` — max_data never decreases (precondition: maxData ≤ consumed + window)
- `autotune_window_nondecreasing` — window only increases (needs fcWindowValid hypothesis)
- `should_update_window_one_safe` — always false when window=1 (edge case)
- `ensure_window_lower_bound_nondecreasing` — window never decreases

## Lean Syntax Gotchas (v4.29.0 without Mathlib)

1. **Operator precedence**: `=` (prec 50) is TIGHTER than `||` (prec 30)!
   - ALWAYS wrap both sides of `=` in parens: `(A || B) = (A || ...)`
2. `private lemma` is NOT valid — use `private theorem`
3. `hr.elim` fails for `hr : r ∈ []` — use `cases hr` instead
4. No `push_neg`, `split_ifs`, `ring` (Mathlib tactics)
5. `by_cases h : bool_expr` gives `h : ¬(bool_expr)` in false branch
   - Use `cases h : bool_expr` for clean `h : bool_expr = false/true`
6. `omega` CANNOT prove goals involving nested `if-then-else` expressions
   - Use `split <;> (split <;> omega)` to split on the conditions first
7. For `if-then-else` in goal: use `split` (not `split_ifs` which is Mathlib)
8. `simp [h]` warns "unused simp arg h" if `h` was already substituted by `cases`
9. `Nat.min_le_left : ∀ m n, min m n ≤ m` is available in Lean 4 core
10. `Nat.le_max_right : ∀ a b, b ≤ max a b` is available in Lean 4 core
11. **`le_min` does NOT exist in Lean 4 core without Mathlib**
    - Use `simp only [Nat.min_def]; split <;> omega` for `c ≤ min a b` goals
    - OR prove both components and combine with `split <;> omega` after `simp [Nat.min_def]`
12. **Struct projection after `simp only [def]` may not reduce `.field`**
    - Use full `simp` (not `simp only`) OR use existing proved theorems to rewrite
    - E.g., rewrite with `autotune_window_true_doubles` instead of unfolding `fcAutotuneWindow`
13. **Forward declaration matters**: theorems can only reference earlier theorems
    - Reorder theorems if you need to use one before the other

## CI Status

- `.github/workflows/lean-ci.yml` created in RTT branch (not yet a PR)
- Needs maintainer merge to activate

## Next Run Priorities

1. **Task 5**: Fix PR #6 — add RangeSet proved theorems (the proofs are on run7 branch)
   - The proved version is in `formal-verification/lean/FVSquad/RangeSet.lean` on run7 branch
   - Create new PR or push to existing PR #6 branch
2. **Task 6**: Write CORRESPONDENCE.md linking all 4 Lean models to Rust source
3. **Task 7**: Write CRITIQUE.md assessing proof utility and coverage gaps
4. **Target 5 (Minmax)**: Task 2 (informal spec) for minmax.rs

## Run History

### 2026-03-28 — Run 23684817578
- Tasks: Task 2 (FlowControl informal spec) + Task 3+5 (FlowControl Lean proofs)
- FlowControl.lean: 35 theorems proved, 0 sorry
- lake build PASSED with Lean 4.29.0
- Key lesson: le_min not in Lean 4 core; use Nat.min_def + split <;> omega
- Key lesson: struct projections not reduced by simp only; use full simp or rewrite with lemmas

### 2026-03-28 — Run 23684550503
- Tasks: Task 2+3 (RTT estimation) + Task 9 (CI)
- RttStats.lean: 21 theorems proved, 0 sorry
- lean-ci.yml created and included in RTT branch

### 2026-03-28 — Run 23681950678
- Tasks: Task 5 (RangeSet proofs) — COMPLETED
- All 5 RangeSet theorems proved: 0 sorry remain
- lake build PASSED with Lean 4.29.0

### 2026-03-28 — Run 23676429830
- Tasks: 3 (Lean Spec — RangeSet), 9 (CI — blocked)
- RangeSet.lean: 10 structural lemmas proved, 5 sorry deferred
- PR created: lean-squad-run4-rangeset-spec branch (PR #6)

### 2026-03-28 — Run 23674446182
- ALL varint theorems proved (0 sorry), RangeSet informal spec written
- PR #5 pending

### 2026-03-27 — Run 23661997161 / 23661208608
- Research, varint informal spec (PR #2 merged), partial varint proofs
