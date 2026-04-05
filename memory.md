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
- **PR**: #30 (merged)

### 9. Packet number decode (RFC 9000 App. A.3)
- **File**: `quiche/src/packet.rs` — `decode_pkt_num`
- **Phase**: 5 — COMPLETE (24 theorems, 0 sorry)
- **Lean file**: `FVSquad/PacketNumDecode.lean`
- **Key theorems**:
  - `decode_mod_win_exact`: RFC 9000 §17.1 congruence (FULLY PROVED)
  - `decode_pktnum_correct`: FULLY PROVED (run 39) — 3-way window-quotient case split
  - `mul_uniq_in_range`: helper for unique-multiple-in-interval argument
  - 7 concrete test vectors aligned with quiche test suite
- **PR**: #32 (merged)
- **FINDING**: Original hprox2 was non-strict (≤); corrected to strict (<) + hoverflow + hwin_le

### 10. CUBIC congestion control
- **File**: `quiche/src/recovery/congestion/cubic.rs`
- **Phase**: 5 — COMPLETE (26 theorems, 0 sorry)
- **Lean file**: `FVSquad/Cubic.lean`
- **Informal spec**: `specs/cubic_informal.md`
- **Key theorems**:
  - `alphaAimd_numerator_eq` / `alphaAimd_denominator_eq`: ALPHA_AIMD=9/17 verified
  - `ssthresh_lt_cwnd_pos`: strict window reduction on loss
  - `wCubic_epoch_anchor`: RFC 8312bis §5.1 epoch-anchor (C*K³=w_max-cwnd → epoch anchor)
  - `wCubicNat_monotone`: W_cubic non-decreasing for t ≥ K
  - `fastConv_wmax_lt_cwnd`: fast convergence strictly reduces w_max
  - `congestionEvent_reduces_cwnd`: cwnd > 0 → ssthresh < cwnd
- **PR**: branch lean-squad-run41-23998622683-cubic-proofs-2db1adfc4c3ec411 (#36, pending)

## Open PRs / Branches
- PR #33: run 39, PacketNumDecode proved (190→190 theorems)
- PR #34: run 39, duplicate of #33
- PR #35: run 40, CORRESPONDENCE.md + CRITIQUE.md updates
- PR #36: run 41, Cubic.lean (26 theorems) + docs

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available without Mathlib/Std — use `Nat.lt_or_ge`
- `split_ifs` NOT available without Std — use `split` or `by_cases`
- `push_neg` NOT available — use `Nat.le_of_not_gt` or `omega` instead
- `simp only [range_insert_go.eq_def]` LOOPS — use `unfold range_insert_go`
- `List.mem_cons_self` takes NO explicit args (zero explicit args)
- `lemma` keyword NOT available in Lean 4.29 without Mathlib — use `theorem`
- `bif` is a RESERVED KEYWORD in Lean 4 — do not use as variable name
- `conv_rhs` tactic: NOT available without Mathlib — use explicit `have` + `rw`
- `set` tactic: NOT available without Std4/Mathlib — use explicit `have`
- `ring` tactic: NOT available without Mathlib
- `linarith` / `nlinarith`: NOT available without Mathlib
- omega handles Nat.div (e.g., `cwnd * 7 / 10 < cwnd` for cwnd > 0) ✅
- `Nat.pow_le_pow_left hbase 3`: works for cubic monotonicity ✅
- `Nat.mul_le_mul_left c hpow`: works for scaling ✅
- `Nat.mul_le_mul_right k h`: also available ✅
- `simp` closes `c * (k - k)^3 + wMax = wMax` (sub_self, zero_pow, mul_zero, zero_add)
- omega treats `c * k3` (product of variables) as an atom — can use in linear hypotheses ✅
- CUBIC: all f64 constants can be modelled as Nat fractions; omega handles floor div proofs

## TARGETS.md / CORRESPONDENCE.md / CRITIQUE.md
- TARGETS.md: 10 targets, all at Phase 5 Complete (0 sorry)
- CORRESPONDENCE.md: updated run 41 (all 10 Lean files documented)
- CRITIQUE.md: updated run 41 (216 theorems, 0 sorry)

## Status Issue: #4 (open), updated run 41

## Summary
- **216 total theorems, 0 sorry** across 10 files
- Varint: 10 | RangeSet: 16 | Minmax: 15 | RttStats: 23 | FlowControl: 22
  NewReno: 13 | DatagramQueue: 26 | PRR: 20 | PacketNumDecode: 24 | Cubic: 26

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox). Document failure each run.
- FVSquad.lean imports all 10 modules

## Next Priorities (all 10 targets fully proved — new targets needed)
1. **RangeSet semantic completeness** — `flatten(insert(rs,r)) = set_union`
2. **CUBIC W_est / TCP-friendliness** — prove w_est tracks Reno growth correctly;
   the switch between CUBIC and Reno modes (w_cubic(t) < w_est) is not yet modelled
3. **Stream receive buffer** — `quiche/src/stream/recv_buf.rs`
   BTreeMap-based out-of-order reassembly; key: no data lost, no duplicates, off monotone
4. **NewReno AIMD growth rate** — multi-callback accumulation theorem
5. **Packet number uniqueness** — uniqueness of decoded number within pkt_hwin
