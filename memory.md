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
- **Note**: CRITIQUE.md had phantom theorem names (run 40 fixed them)

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
- **Note**: CRITIQUE.md had incorrect theorem names (run 40 fixed them)

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
- **Informal spec**: `specs/packet_num_decode_informal.md`
- **Key theorems**:
  - `decode_mod_win_exact`: RFC 9000 §17.1 congruence (FULLY PROVED)
  - `decode_pktnum_correct`: FULLY PROVED (run 39) — 3-way window-quotient case split
  - `mul_uniq_in_range`: helper for unique-multiple-in-interval argument
  - 7 concrete test vectors aligned with quiche test suite
- **PR**: branch lean-squad-run39-23983513602-pktnum-prove-53fdae0a25e124ea (#33, pending)
- **FINDING**: Original hprox2 was non-strict (≤); corrected to strict (<) + hoverflow + hwin_le

## Open PRs / Branches
- PR #33: branch lean-squad-run39-23983513602-pktnum-prove-53fdae0a25e124ea (run 39, pending)
- PR #34: branch lean-squad-run39-23983513602-pktnum-prove-115496a2624eb7b8 (run 39, duplicate, pending)
- PR #35: lean-squad-run40-23993631568-correspondence-critique (run 40, correspondence+critique docs)

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
- `positivity` / `ring` / `linarith` / `nlinarith` NOT available without Mathlib
- omega CANNOT prove `(a + n) % n = a % n` → use `Nat.add_mod_right`
- omega CANNOT prove nonlinear goals with two symbolic multiplied variables
- **Nat.pos_pow_of_pos DOES NOT EXIST** — use `Nat.two_pow_pos` for powers of 2
- **`Nat.dvd_sub'` DOES NOT EXIST** in Lean 4.29 core — use `obtain ⟨k,h⟩` + `Nat.mul_sub`
- **`Nat.mul_sub (n m k : Nat) : n * (m - k) = n * m - n * k`** — available ✓
- **`Nat.succ_mul : Nat.succ n * m = n * m + m`** — use for `(k+1)*n = k*n+n` rewrites
- **`Nat.le_of_mul_le_mul_left : c * a ≤ c * b → 0 < c → a ≤ b`** (note arg order: c*a, c*b)
- **`Nat.lt_of_mul_lt_mul_left : k * a < k * b → a < b`** (no pos hypothesis needed)
- **`Nat.add_div_right (x : Nat) {z : Nat} (h : 0 < z) : (x + z) / z = x / z + 1`**
- **`mul_uniq_in_range` proof pattern**: establish `n * (a/n) = a` via `Nat.div_add_mod + simpa`;
  then `hq_lo` via `Nat.mul_add + Nat.mul_one + omega + Nat.le_of_mul_le_mul_left`;
  then `hq_hi` via `Nat.mul_add + omega + Nat.lt_succ_iff.mp + Nat.lt_of_mul_lt_mul_left`;
  conclude `rw [← hqa, hq_eq, Nat.mul_add, Nat.mul_one, hqb]`
- **`decode_pktnum_correct` proof pattern**: provide `hα_sum` (via `Nat.div_add_mod`),
  `hβ_sum` (via `Nat.div_add_mod + hmod`), `h2hwin : 2 * hwin ≤ win` (omega from unfold pnHwin);
  3-way `rcases Nat.lt_or_ge` case split on quotients;
  use `mul_uniq_in_range` + `rw [Nat.succ_mul] at hle` for upper bound;
  use `by_cases + exfalso + omega` for impossible branches

## TARGETS.md / CORRESPONDENCE.md / CRITIQUE.md
- TARGETS.md: 9 targets, all at Phase 5 Complete (0 sorry)
- CORRESPONDENCE.md: updated run 40 (all 9 Lean files documented, Summary fixed)
- CRITIQUE.md: updated run 40 (190 theorems, 0 sorry; phantom names fixed; CUBIC as next target)

## Status Issue: #4 (open), updated run 40

## Summary
- **190 total theorems, 0 sorry** across 9 files
- Varint: 10 | RangeSet: 16 | Minmax: 15 | RttStats: 23 | FlowControl: 22
  NewReno: 13 | DatagramQueue: 26 | PRR: 20 | PacketNumDecode: 24

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox). Document failure each run.
- FVSquad.lean imports all 9 modules

## Next Priorities (all 9 targets fully proved — new targets needed)
1. **CUBIC congestion** — `cubic.rs` key functions: `cubic_k`, `w_cubic`
   - Model cube-root as rational; verify w_cubic(0) = β·W_max, congestion halving
   - `congestion_event` halves window by BETA_CUBIC (0.7) exactly
2. **RangeSet semantic completeness** — capacity-bounded version of `insert_covers_union`
3. **Stream receive buffer** — `quiche/src/stream/recv_buf.rs`
   - BTreeMap-based out-of-order reassembly; key: no data lost, no duplicates, off monotone
4. **NewReno AIMD growth rate** — multi-callback accumulation theorem
5. **Packet number uniqueness** — uniqueness of decoded number within pkt_hwin
