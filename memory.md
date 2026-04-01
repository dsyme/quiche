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
- **Phase**: 5 — COMPLETE (14 public + 9 private theorems, 0 sorry)
- **Key theorems**: `insert_preserves_invariant`, `insert_covers_union`,
  `remove_until_removes_small`, `remove_until_preserves_large`,
  `remove_until_preserves_invariant`
- **PRs**: #7 (spec), #9 (impl), #11 (partial proofs), #15 (more proofs),
  run-24 PR (proves final 2 sorry — branch lean-squad-run24-insert-proofs-critique-1775069276)
- **Notable**: `insert_covers_union` holds without `sorted_disjoint` precondition
  (h_inv is unnecessary — pure structural equality)

### 3. WindowedMinimum running-minimum algorithm
- **File**: `quiche/src/minmax.rs`
- **Lean file**: `FVSquad/Minmax.lean`
- **Phase**: 5 — COMPLETE (15 public + 3 private theorems, 0 sorry)
- **PR**: #15 (merged)

### 4. RTT estimator
- **File**: `quiche/src/recovery/rtt.rs` — `RttStats::update_rtt`
- **Phase**: 1 — Research identified, no spec yet
- **Priority**: HIGH — security-sensitive, affects congestion control
- **Target properties**: min_rtt monotone, smoothed_rtt bounded, rttvar ≥ 0

### 5. Flow control window arithmetic
- **File**: `quiche/src/flowcontrol.rs`
- **Phase**: 1 — Research identified, no spec yet
- **Priority**: HIGH — buffer-limit violations, pure arithmetic
- **Target property**: max_data ≥ consumed invariant

## CRITIQUE.md
- Added in run 24 (branch lean-squad-run24-insert-proofs-critique-1775069276)
- Assesses all 51 theorems across 3 files
- Top gaps: RTT estimator, flow control, capacity eviction, state machine

## Open PRs / Branches
- `lean-squad-run24-insert-proofs-critique-1775069276` — run 24 work,
  safeoutputs MCP server was unavailable so PR could not be created via tool;
  branch exists locally with commit fdd0261

## Key Lean 4.29.0 Learnings
- `simp only [range_insert_go.eq_def]` LOOPS — use `unfold range_insert_go`
- `List.mem_cons_self` takes NO explicit args
- `covers (l1 ++ l2) n = (covers l1 n || covers l2 n)` needs parens — else
  parsed as `(covers ... = covers ...) || covers ... n` (Bool precedence)
- `List.any_append` directly proves `covers_append` after parens fix
- `unfold covers; rw [List.any_append]` works; `simp [covers, List.any_append]` fails
- For Bool rearrangements: `simp [Bool.or_comm, Bool.or_left_comm, Bool.or_assoc]`

## Invariants / No-Ops
- `sorted_disjoint_cons2_iff` is `@[simp]` — use `simp` or `.mp` to unfold
- `FVSquad.lean` imports all three modules; RttStats import removed (stale)
