# Lean Squad Memory — dsyme/quiche

## Tool & Approach
- **FV tool**: Lean 4 (v4.29.0, no Mathlib)
- **Project**: `formal-verification/lean/` — `lake init FVSquad` (no Mathlib)
- **CI**: `.github/workflows/lean-ci.yml` (added in PR #15, merged)

## Targets

### 1. Varint encoding/decoding
- **File**: `quiche/src/octets.rs` (also `quiche/src/h3/mod.rs`)
- **Lean file**: `FVSquad/Varint.lean`
- **Phase**: 5 — COMPLETE (10 theorems, 0 sorry)
- **Key theorem**: `varint_round_trip` — decode(encode(v)) = v
- **PR**: #5 (merged)

### 2. RangeSet sorted-interval data structure
- **File**: `quiche/src/ranges.rs`
- **Lean file**: `FVSquad/RangeSet.lean`
- **Phase**: 5 — COMPLETE (16 theorems, 0 sorry)
- **PR**: #22 (merged)

### 3. WindowedMinimum running-minimum algorithm
- **File**: `quiche/src/minmax.rs`
- **Lean file**: `FVSquad/Minmax.lean`
- **Phase**: 5 — COMPLETE (15 theorems, 0 sorry)
- **PR**: #15 (merged)

### 4. RTT estimator
- **File**: `quiche/src/recovery/rtt.rs` — `RttStats::update_rtt`
- **Phase**: 5 — COMPLETE (23 theorems, 0 sorry)
- **Lean file**: `FVSquad/RttStats.lean`
- **Key theorems**:
  - `adjusted_rtt_ge_min_rtt`: KEY security property (ack-delay attack prevention)
  - `rtt_update_smoothed_upper_bound`: EWMA contraction theorem
  - `rtt_update_min_rtt_inv`: joint invariant min_rtt ≤ latest_rtt
- **PR**: #23 (merged)

### 5. Flow control window arithmetic
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 5 — COMPLETE (22 theorems, 0 sorry)
- **Lean file**: `FVSquad/FlowControl.lean`
- **Key theorems**:
  - `fc_no_update_needed_after_update`: should_update=false after update
  - `fc_max_data_next_gt_when_should_update`: limit strictly grows
  - `fc_update_idempotent`: double update is no-op
  - `fc_autotune_window_when_tuned`: window = min(window*2, max_window)
- **PR**: #26 (merged)

### 6. Congestion window (NewReno)
- **File**: `quiche/src/recovery/congestion/reno.rs`
- **Phase**: 5 — COMPLETE (13 theorems, 0 sorry) — added run 34
- **Lean file**: `FVSquad/NewReno.lean`
- **Informal spec**: `specs/congestion_informal.md`
- **Key theorems**:
  - `cwnd_floor_new_event`: cwnd ≥ mss*2 after fresh congestion event (RFC 6582)
  - `single_halving`: congestion_event no-op when in_recovery (epoch guard)
  - `acked_cwnd_monotone`: on_packet_acked never decreases cwnd
  - `acked_preserves_floor_inv`: FloorInv is inductive invariant under ACKs
- **PR**: run 34 PR (pending merge)
- **Correspondence**: documented in CORRESPONDENCE.md (run 34)

## Open PRs / Branches
- PR (run 34) `lean-squad-run34-23952827355` — NewReno.lean + CRITIQUE/TARGETS/CORRESPONDENCE update

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available without Mathlib/Std — use `Nat.lt_or_ge`
- `split_ifs` NOT available without Std — use `split` on if-expressions
- `push_neg` NOT available — use `Nat.le_of_not_gt` or `omega` instead
- `simp only [range_insert_go.eq_def]` LOOPS — use `unfold range_insert_go`
- `List.mem_cons_self` takes NO explicit args (zero explicit args)
- Bool `=` precedence trap: `||` has precedence 30, `=` has 50
- Bool AC tactic: generalize Bool atoms, `cases bA <;> ... <;> rfl`
- `lemma` keyword NOT available in Lean 4.29 without Mathlib — use `theorem`
- omega CANNOT handle two-variable floor division like `a*7/8 + b/8 ≤ a` (b ≤ a)
  SOLUTION: helper theorems `ewma_le_prev`, `ewma_le_next` using single-var omega
- omega CANNOT bridge Nat.max (function app `d`) and if-expression `c` even when
  definitionally equal. SOLUTION: use `Nat.le_trans` with `Nat.le_max_left/right`
- `simp [h]` on an if-expr where `h` resolves the condition: simp closes the goal
  entirely (including obvious arithmetic follow-ons). If `; omega` follows, it
  fails with "no goals". Don't add `omega` after `simp` if simp can close it.
- `simp [h]` does NOT use hypothesis values for arithmetic (e.g. `h : a ≥ b`)
  — to prove `b ≤ a + c` from `h`, use `omega` (not simp)
- `simp only [hg]` on a Bool in_recovery hypothesis: use `by_cases hg : expr`
  then `simp [hg]` — no need for `ite_false` simp lemma, Lean handles it
- `let` bindings inside function definitions cause proof complications — inline
  them to avoid issues with `split` and goal structure
- `FloorInv` defined as `r.FloorInv` refers to `r.mss`, not the outer `mss`.
  After `congestion_event`, `(r.congestion_event).FloorInv` needs
  `(r.congestion_event).mss = r.mss` — prove by unfolding, or prove directly

## TARGETS.md / CORRESPONDENCE.md / CRITIQUE.md
- TARGETS.md: 6 targets, all at Phase 5
- CORRESPONDENCE.md: updated run 34 (all 6 Lean files documented)
- CRITIQUE.md: updated run 34 (99 theorems assessed, NewReno section added)

## Status Issue: #4 (open), updated run 34

## Summary
- **99 total theorems, 0 sorry** across 6 files
- Varint.lean: 10 | RangeSet.lean: 16 | Minmax.lean: 15 | RttStats.lean: 23
  FlowControl.lean: 22 | NewReno.lean: 13

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox). Document failure each run.
- FVSquad.lean imports: Varint, RangeSet, Minmax, RttStats, FlowControl, NewReno

## Next Priorities
1. **Stream flow control** — per-stream window; reuse FlowControl.lean as model
2. **RangeSet semantic completeness** — prove flatten(insert(rs,r)) = set_union
3. **NewReno AIMD rate** — prove one-MSS-per-RTT-worth across multiple ACKs
   (currently only per-callback growth is verified)
4. **RTT lower bounds** — prove smoothed_rtt ≥ min_rtt after first sample
