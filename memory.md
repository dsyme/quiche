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
- **PR**: #28 (merged)

### 7. DatagramQueue bounded FIFO
- **File**: `quiche/src/dgram.rs`
- **Phase**: 5 — COMPLETE (26 theorems, 0 sorry)
- **Lean file**: `FVSquad/DatagramQueue.lean`
- **PR**: #29 (merged)

### 8. PRR (Proportional Rate Reduction)
- **File**: `quiche/src/recovery/congestion/prr.rs`
- **Phase**: 5 — COMPLETE (20 theorems, 0 sorry)
- **Lean file**: `FVSquad/PRR.lean`
- **Informal spec**: `specs/prr_informal.md`
- **Key theorems**:
  - `prr_mode_snd_cnt_formula`: exact RFC 6937 PRR formula
  - `prr_mode_snd_cnt_le_ratio`: rate-control bound
  - `ssrb_snd_cnt_le_gap`: SSRB bounded by ssthresh gap
  - `ssrb_snd_cnt_ge_min_gap_mss`: SSRB permits at least one MSS
- **PR**: run36 branch `lean-squad-run36-23970296538-prr` (pending merge)

## Open PRs / Branches
- Branch `lean-squad-run36-23970296538-prr` — PRR.lean (run 36, pending)

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available without Mathlib/Std — use `Nat.lt_or_ge`
- `split_ifs` NOT available without Std — use `split` on if-expressions
- `push_neg` NOT available — use `Nat.le_of_not_gt` or `omega` instead
- `simp only [range_insert_go.eq_def]` LOOPS — use `unfold range_insert_go`
- `List.mem_cons_self` takes NO explicit args (zero explicit args)
- Bool `=` precedence trap: `||` has precedence 30, `=` has 50
- `lemma` keyword NOT available in Lean 4.29 without Mathlib — use `theorem`
- `bif` is a RESERVED KEYWORD in Lean 4 — do not use as a variable name
- `Nat.not_eq_zero_of_lt` DOES NOT EXIST — use `have : b ≠ 0 := by omega`
- `Nat.le_min` is an IFF (not an arrow) — use `(Nat.le_min).mpr` or provide both parts
- omega CANNOT handle two-variable floor division like `a*7/8 + b/8 ≤ a`
  SOLUTION: helper theorems using single-var omega
- omega CANNOT bridge Nat.max (function app) and if-expression even when definitionally equal
- `simp [h]` on an if-expr where `h` resolves the condition: simp closes the goal entirely
- `simp [h]` does NOT use hypothesis values for arithmetic — use `omega` for inequalities
- After `simp` closes goal entirely, adding `;omega` yields "no goals"
- Use `by_cases h : condition` + `simp [h]` or `simp only [h, ite_true/ite_false]`
  for if-expression case analysis
- `Nat.div_le_div_right : m ≤ n → m / k ≤ n / k` — available and works
- `divCeil a b = (a + b - 1) / b` (ceiling division) needs `b ≠ 0` guard for Lean convention

## TARGETS.md / CORRESPONDENCE.md / CRITIQUE.md
- TARGETS.md: 8 targets (PRR added run 36), all at Phase 5
- CORRESPONDENCE.md: updated run 36 (all 8 Lean files documented)
- CRITIQUE.md: updated run 35 (125 theorems assessed); needs PRR section next run

## Status Issue: #4 (open), updated run 36

## Summary
- **145 total theorems, 0 sorry** across 8 files
- Varint.lean: 10 | RangeSet.lean: 16 | Minmax.lean: 15 | RttStats.lean: 23
  FlowControl.lean: 22 | NewReno.lean: 13 | DatagramQueue.lean: 26 | PRR.lean: 20

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox). Document failure each run.
- FVSquad.lean imports: Varint, RangeSet, Minmax, RttStats, FlowControl, NewReno, DatagramQueue, PRR

## Next Priorities
1. **CRITIQUE.md update** — add PRR section (Task 7)
2. **PRR rate-maintenance invariant** — prove that after `congestion_event` + alternating
   `on_packet_acked`/`on_packet_sent` calls with b ≤ snd_cnt, prr_out ≤ div_ceil ratio target
3. **Cubic congestion** — `cubic_k` and `w_cubic` are pure math (but use f64; model as rational?)
4. **QUIC packet number space** — encode/decode of variable-length packet number
5. **RangeSet semantic completeness** — prove flatten(insert(rs,r)) = set_union
