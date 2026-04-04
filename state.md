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
- **PR**: #30 (merged)

### 9. Packet number decode (RFC 9000 App. A.3)
- **File**: `quiche/src/packet.rs` — `decode_pkt_num`
- **Phase**: 5 — IN PROGRESS (22 theorems, 1 sorry)
- **Lean file**: `FVSquad/PacketNumDecode.lean`
- **Informal spec**: `specs/packet_num_decode_informal.md`
- **Key theorems**:
  - `decode_mod_win_exact`: RFC 9000 §17.1 congruence (FULLY PROVED)
  - `decode_branch1_overflow_guard`: 2^62 overflow guard
  - `decode_branch2_upper`: downward-adjustment proximity bound
  - 7 `native_decide` test vectors
  - `decode_pktnum_correct`: sorry (α=β case split)
- **PR**: branch `lean-squad-run38-23979686182-pktnum-decode` (run 38, pending)

## Open PRs / Branches
- Branch `lean-squad-run38-23979686182-pktnum-decode` — PacketNumDecode.lean (run 38, pending)

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available without Mathlib/Std — use `Nat.lt_or_ge`
- `split_ifs` NOT available without Std — use `split` or `by_cases`
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
- `nlinarith` tactic: NOT available without Mathlib
- omega CANNOT prove `(a + n) % n = a % n` for symbolic n → use `Nat.add_mod_right`
- omega CANNOT prove `(k*n + m) % n = m % n` for symbolic n → use `mul_add_mod` induction
- omega CANNOT prove nonlinear goals with two symbolic multiplied variables
- **Nat.pos_pow_of_pos DOES NOT EXIST** in Lean 4.29 — use `Nat.two_pow_pos` for powers of 2
- **`Nat.add_mod_right (a n) : (a + n) % n = a % n`** works ✓
- **alpha-trick for modular arithmetic**: intro α := (expected/win)*win as opaque Nat,
  then `α + exp%win = expected_pn` (from `Nat.div_add_mod` + `Nat.mul_comm`), omega sees linear
- **`Nat.div_add_mod (m n : Nat) : n * (m / n) + m % n = m`** (divisor first)
- **`Nat.mul_mod_right (m n : Nat) : m * n % m = 0`** (m first)
- **`mul_mod_zero k win : k * win % win = 0`** — custom helper using `Nat.mul_comm` + `Nat.mul_mod_right`
- **`mul_add_mod k win m h : (k * win + m) % win = m`** — needs `cases Nat.eq_zero_or_pos win` + `Nat.mod_eq_of_lt` TWICE
- **`sub_add_mod a win h : (a - win) % win = a % win`** — use `calc` with `Nat.add_mod_right`
- **`simp only [decodePktNum]`** (not `unfold decodePktNum`) to eliminate let-bindings; then `by_cases`
- **`by_cases h : cond`** works in Lean 4.29 (via Classical.em) — use instead of `split`
- **decode branch proofs**: after `simp only [decodePktNum]`, use `by_cases` 4 times then `simp only [cond, ite_true/ite_false]`
- **`ite_true` and `ite_false`** as simp lemmas to reduce `if True then a else b = a` etc.

## TARGETS.md / CORRESPONDENCE.md / CRITIQUE.md
- TARGETS.md: 9 targets (PacketNumDecode added run 38), target 9 at Phase 5 (in progress)
- CORRESPONDENCE.md: updated run 38 (all 9 Lean files documented)
- CRITIQUE.md: updated run 38 (187 theorems assessed, PacketNumDecode section added)

## Status Issue: #4 (open), updated for run 38

## Summary
- **187 total theorems, 1 sorry** across 9 files
- Varint: 10 | RangeSet: 16 | Minmax: 15 | RttStats: 23 | FlowControl: 22
  NewReno: 13 | DatagramQueue: 26 | PRR: 20 | PacketNumDecode: 22

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox). Document failure each run.
- FVSquad.lean imports all 9 modules

## Next Priorities
1. **decode_pktnum_correct sorry** — prove the α=β case split for `PacketNumDecode`
   - Need `pnWin_double : pnWin pn_len = 2 * pnHwin pn_len` (pnWin is even)
   - Need `candidate_arith_eq_bitwise` bridging arithmetic model to bitwise
   - Then three-way case split: β=α (branch 3), β=α+win (branch 1), β=α-win (branch 2)
2. **Packet number uniqueness** — prove decoded number is the *unique* candidate
   within pkt_hwin of expected_pn congruent to truncated_pn mod pkt_win
3. **NewReno AIMD growth rate** — multi-callback accumulation theorem
4. **RangeSet semantic completeness** — flatten(insert(rs,r)) = set_union
5. **Cubic congestion** — `cubic_k` and `w_cubic` (uses f64; model as rational?)
