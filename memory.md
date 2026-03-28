# Lean Squad Memory — dsyme/quiche

**Last updated**: 2026-03-28 11:49 UTC  
**Commit**: 2f6287aa (lean-squad-run6-rtt-spec-1774698629)  
**Run**: https://github.com/dsyme/quiche/actions/runs/23684550503

## FV Targets

| # | Target | Location | Phase | Open PRs/Issues | Notes |
|---|--------|----------|-------|-----------------|-------|
| 1 | varint codec | `octets/src/lib.rs` | 5 — ALL PROVED (0 sorry) | PR #5 open | round_trip + first_byte_tag proved |
| 2 | RangeSet invariants | `quiche/src/ranges.rs` | 5 — ALL PROVED (0 sorry) | PR #6 open | All 5 theorems proved (run5 branch, not yet separate PR) |
| 3 | RTT estimation | `quiche/src/recovery/rtt.rs` | 5 — ALL PROVED (0 sorry) | PR #7 open (run6) | 21 theorems, RFC 9002 §5 |
| 4 | Flow control | `quiche/src/flowcontrol.rs` | 1 — Research | — | Arithmetic invariants |
| 5 | Minmax filter | `quiche/src/minmax.rs` | 1 — Research | — | Windowed min/max |

## Tool Choice

- **Lean 4.29.0** — no Mathlib (network firewall blocks download)
- Core tactics: `omega`, `simp`, `cases`, `native_decide`, `rw`, `induction`, `split`

## Key Files

- `formal-verification/RESEARCH.md` — target survey
- `formal-verification/TARGETS.md` — phase tracking
- `formal-verification/specs/varint_informal.md` — informal spec
- `formal-verification/specs/rangeset_informal.md` — informal spec
- `formal-verification/specs/rtt_informal.md` — informal spec (added run 6)
- `formal-verification/lean/FVSquad/Varint.lean` — Lean 4 spec+impl+proofs (10 theorems, 0 sorry)
- `formal-verification/lean/FVSquad/RangeSet.lean` — Lean 4 spec+impl+proofs (15+ theorems, 0 sorry in run5 branch)
- `formal-verification/lean/FVSquad/RttStats.lean` — Lean 4 spec+impl+proofs (21 theorems, 0 sorry)
- `formal-verification/lean/lakefile.toml` — Lake project (no Mathlib)
- `formal-verification/lean/lean-toolchain` — leanprover/lean4:v4.29.0
- `.github/workflows/lean-ci.yml` — CI workflow (included in PR #7, needs maintainer merge)

## Varint Codec (Target 1) — COMPLETE (Phase 5)

All 10 theorems proved. PR #5 open (pending merge).

## RangeSet (Target 2) — COMPLETE (Phase 5)

All 5 key theorems proved in run5 branch. PR #6 is open but has the old 5-sorry version.
The proved version was on a run5 branch that didn't get a separate PR (work included in run6 merge).

**WARNING**: PR #6 still shows 5 sorrys because the run5 proofs were not on a separate branch.
Next run should either: (a) add RangeSet proofs to existing PR #6, or (b) create new PR with proofs.

## RTT Estimation (Target 3) — COMPLETE (Phase 5)

### ALL 21 theorems proved (no sorry) in run 6

**Initialization:**
- `init_smoothed_rtt`, `init_rttvar`, `init_has_first_false`

**First-sample update:**
- `first_update_smoothed_rtt`, `first_update_rttvar`, `first_update_sets_has_first`

**Monotonicity:**
- `update_sets_has_first`

**Ack-delay adjustment:**
- `adjust_rtt_le_latest`, `adjust_rtt_when_plausible`, `adjust_rtt_when_implausible`

**EWMA formulas (RFC 9002 §5.3):**
- `srtt_update_formula` (I11), `rttvar_update_formula` (I12)

**Min RTT / loss delay:**
- `min_rtt_nonincreasing`, `loss_delay_ge_granularity`

**abs_diff_nat:**
- `abs_diff_nat_symm` (needed `split <;> (split <;> omega)` — NOT just omega)
- `abs_diff_nat_self`

**EWMA convergence:**
- `srtt_within_convex_hull`, `srtt_moves_toward_sample_up`, `srtt_moves_toward_sample_down`
- `rttvar_shrinks_when_stable`, `first_update_srtt_positive`

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

## CI Status

- `.github/workflows/lean-ci.yml` created and included in PR #7
- Previous runs were blocked by "workflows" permission
- This run used the `safeoutputs-create_pull_request` tool which CAN include workflow files
- CI will activate once PR #7 is merged by maintainer

## Next Run Priorities

1. **Task 5**: Add RangeSet proofs to PR #6 branch (or create new PR)
   - The run5 RangeSet proofs exist in memory but weren't pushed as a separate PR
   - Merge PR #6, then add proved theorems
2. **Task 2/3**: Informal spec + Lean spec for Target 4 (flow control, flowcontrol.rs)
3. **Task 6**: Correspondence review (CORRESPONDENCE.md)
4. **Task 7**: Proof utility critique (CRITIQUE.md)

## Run History

### 2026-03-28 — Run 23684550503
- Tasks: Task 2+3 (RTT estimation) + Task 9 (CI)
- RttStats.lean: 21 theorems proved, 0 sorry
- lean-ci.yml created and included in PR
- Key lesson: omega fails on nested if-then-else; use split first

### 2026-03-28 — Run 23681950678
- Tasks: Task 5 (RangeSet proofs) — COMPLETED
- All 5 RangeSet theorems proved: 0 sorry remain
- lake build PASSED with Lean 4.29.0
- Key lesson: bool_or4 needs parens around both sides of = due to precedence

### 2026-03-28 — Run 23676429830
- Tasks: 3 (Lean Spec — RangeSet), 9 (CI — blocked)
- RangeSet.lean: 10 structural lemmas proved, 5 sorry deferred
- PR created: lean-squad-run4-rangeset-spec branch (PR #6)

### 2026-03-28 — Run 23674446182
- ALL varint theorems proved (0 sorry), RangeSet informal spec written
- PR #5 pending

### 2026-03-27 — Run 23661997161 / 23661208608
- Research, varint informal spec (PR #2 merged), partial varint proofs
