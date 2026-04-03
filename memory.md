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
- **PR**: #23 (merged)

### 5. Flow control window arithmetic
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 5 — COMPLETE (22 theorems, 0 sorry)
- **Lean file**: `FVSquad/FlowControl.lean`
- **PR**: #26 (merged)

### 6. Congestion window (NewReno)
- **File**: `quiche/src/recovery/congestion/reno.rs`
- **Phase**: 5 — COMPLETE (13 theorems, 0 sorry)
- **Lean file**: `FVSquad/NewReno.lean`
- **PR**: #28 (open, run 34)

### 7. DatagramQueue bounded FIFO
- **File**: `quiche/src/dgram.rs`
- **Phase**: 5 — COMPLETE (26 theorems, 0 sorry)
- **Lean file**: `FVSquad/DatagramQueue.lean`
- **Informal spec**: `specs/datagram_queue_informal.md`
- **Key theorems**:
  - `push_preserves_cap_inv`: capacity invariant
  - `push_byteSize_inc` / `pop_byteSize_dec`: byte-size tracking
  - `push_then_pop_front_unchanged`: FIFO ordering
  - `purge_removes_matching` / `purge_keeps_non_matching`: purge correctness
- **PR**: run 35 PR (pending merge)
- **Correspondence**: documented in CORRESPONDENCE.md (run 35)

## Open PRs / Branches
- PR #28 (run 34) `lean-squad-run34-23952827355-f23aa593047d15a5` — NewReno.lean
- PR (run 35) `lean-squad-run35-23954713919-datagram-queue` — DatagramQueue.lean

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
- After `simp [DgramQueue.push, DgramQueue.isFull] at h` with `push` as an if-expr,
  `h` becomes a conjunction `⟨hne, rfl⟩`. Use `obtain ⟨hne, rfl⟩ := h` NOT `split`.
- `List.foldl (· + ·) acc xs = acc + List.foldl (· + ·) 0 xs` — needs helper
  theorem `foldl_add_acc` using `simp only [List.foldl, Nat.zero_add]` + `rw [ih ...]` + `omega`
- `List.filter (fun _ => true) xs = xs` — needs helper `filter_true_eq_id` by induction
- `List.length_singleton` needed to reduce `[d].length` to `1` in omega goals
- When a `simp` closes the entire goal, adding `omega` after it yields "No goals to be solved"
  — use `refine ⟨?_, ?_⟩` with separate bullets instead of `constructor` if `simp` may close all

## TARGETS.md / CORRESPONDENCE.md / CRITIQUE.md
- TARGETS.md: 7 targets, all at Phase 5
- CORRESPONDENCE.md: updated run 35 (all 7 Lean files documented)
- CRITIQUE.md: updated run 35 (125 theorems assessed, DatagramQueue section added)

## Status Issue: #4 (open), updated run 35

## Summary
- **125 total theorems, 0 sorry** across 7 files
- Varint.lean: 10 | RangeSet.lean: 16 | Minmax.lean: 15 | RttStats.lean: 23
  FlowControl.lean: 22 | NewReno.lean: 13 | DatagramQueue.lean: 26

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox). Document failure each run.
- FVSquad.lean imports: Varint, RangeSet, Minmax, RttStats, FlowControl, NewReno, DatagramQueue

## Next Priorities
1. **RangeSet semantic completeness** — prove flatten(insert(rs,r)) = set_union
2. **NewReno AIMD rate** — prove one-MSS-per-RTT-worth across multiple ACKs
3. **Stream flow control** — per-stream window; reuse FlowControl.lean as model
4. **RTT lower bounds** — prove smoothed_rtt ≥ min_rtt after first sample
