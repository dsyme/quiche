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
- **PR**: #30 (merged, run 36 → run 37 baseline)

### 9. Packet number decode (RFC 9000 App. A.3)
- **File**: `quiche/src/packet.rs` — `decode_pkt_num`
- **Phase**: 5 — COMPLETE (21 theorems, 0 sorry)
- **Lean file**: `FVSquad/PacketNumDecode.lean`
- **Informal spec**: `specs/packet_num_decode_informal.md`
- **Key theorems**:
  - `decode_mod_win_exact`: lower bits preserved (core RFC 9000 §17.1)
  - `decode_branch1/2_upper/lower`: proximity bounds (nearest-candidate guarantee)
  - 5 concrete test vectors aligned with quiche test suite
- **PR**: run37 branch `lean-squad-run37-23976038343-pktnum-decode` (pending merge)

## Open PRs / Branches
- Branch `lean-squad-run37-23976038343-pktnum-decode` — PacketNumDecode.lean (run 37, pending)

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available without Mathlib/Std — use `Nat.lt_or_ge`
- `split_ifs` NOT available without Std — use `split` on if-expressions
- `push_neg` NOT available — use `Nat.le_of_not_gt` or `omega` instead
- `simp only [range_insert_go.eq_def]` LOOPS — use `unfold range_insert_go`
- `List.mem_cons_self` takes NO explicit args (zero explicit args)
- `lemma` keyword NOT available in Lean 4.29 without Mathlib — use `theorem`
- `bif` is a RESERVED KEYWORD in Lean 4 — do not use as variable name
- `conv_rhs` tactic: NOT available without Mathlib — use explicit `have` + `rw`
- `set` tactic: NOT available without Std4/Mathlib — use explicit `have` to name subexpressions
- `positivity` tactic: NOT available without Mathlib
- `ring` tactic: NOT available without Mathlib
- `linarith` tactic: NOT available without Mathlib
- omega CANNOT prove `(a + n) % n = a % n` for symbolic n → use `Nat.add_mod_right`
- omega CANNOT prove `(k*n + m) % n = m % n` for symbolic n → use `mul_add_mod_left` induction
- omega CANNOT prove nonlinear goals with two symbolic multiplied variables
- **α-trick for proximity proofs**: introduce `α := (expected/win)*win` as explicit existential;
  omega sees only linear constraints and α cancels from both sides
- **hcsa bridge**: `have hcsa : cand - win + win = cand := by omega` (using h3 : cand ≥ win)
  allows omega to handle Nat subtraction when both sides appear in the goal
- `Nat.div_add_mod (m n : Nat) : n * (m / n) + m % n = m` (divisor first — note argument order)
- `Nat.mul_mod_right (m n : Nat) : m * n % m = 0` (m first, not n)

## TARGETS.md / CORRESPONDENCE.md / CRITIQUE.md
- TARGETS.md: 9 targets (PacketNumDecode added run 37), all at Phase 5
- CORRESPONDENCE.md: updated run 37 (all 9 Lean files documented)
- CRITIQUE.md: updated run 37 (166 theorems assessed, PRR + PacketNumDecode sections added)

## Status Issue: #4 (open), needs update for run 37

## Summary
- **166 total theorems, 0 sorry** across 9 files
- Varint: 10 | RangeSet: 16 | Minmax: 15 | RttStats: 23 | FlowControl: 22
  NewReno: 13 | DatagramQueue: 26 | PRR: 20 | PacketNumDecode: 21

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox). Document failure each run.
- FVSquad.lean imports all 9 modules

## Next Priorities
1. **Packet number uniqueness** — prove decoded number is the *unique* candidate
   within pkt_hwin of expected_pn congruent to truncated_pn mod pkt_win
2. **PacketNumDecode overflow guard** — model `candidate < (1<<62) - pkt_win`
3. **NewReno AIMD growth rate** — multi-callback accumulation theorem
4. **RangeSet semantic completeness** — flatten(insert(rs,r)) = set_union
5. **Cubic congestion** — `cubic_k` and `w_cubic` (uses f64; model as rational?)
