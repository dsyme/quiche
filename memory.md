# Lean Squad Memory — dsyme/quiche

## Tool & Approach
- **FV tool**: Lean 4 (v4.29.0, no Mathlib)
- **Project**: `formal-verification/lean/` — `lake init FVSquad` (no Mathlib)
- **CI**: `.github/workflows/lean-ci.yml` (added run 15; improved run 42: sorry-in-source step + workflow path trigger)

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
- **PR**: #32 (merged)
- **FINDING**: Original hprox2 was non-strict (≤); corrected to strict (<) + hoverflow + hwin_le

### 10. CUBIC congestion control
- **File**: `quiche/src/recovery/congestion/cubic.rs`
- **Phase**: 5 — COMPLETE (26 theorems, 0 sorry)
- **Lean file**: `FVSquad/Cubic.lean`
- **PR**: #36 (merged)

### 11. RangeBuf offset arithmetic
- **File**: `quiche/src/range_buf.rs`
- **Phase**: 5 — COMPLETE (16 theorems, 0 sorry)
- **Lean file**: `FVSquad/RangeBuf.lean`
- **Key theorems**:
  - `max_off_eq`: max_off = off + len (definition consistency)
  - `consume_max_off`: consume preserves max_off (key reassembler property)
  - `split_adjacent`: left.max_off = right.off (perfect partition)
  - `split_max_off`: right half preserves original max_off
  - `consume_split_max_off`: compose consume+split preserves max_off
- **PR**: run 42 (pending)

### 12. Stream receive buffer (RecvBuf)
- **File**: `quiche/src/stream/recv_buf.rs`
- **Phase**: 2 — INFORMAL SPEC written
- **Lean file**: not yet written
- **Informal spec**: `specs/stream_recv_buf_informal.md`
- **Notes**: BTreeMap-based out-of-order reassembly. Complex. Key invariants:
  off ≤ len, non-overlapping chunks, FIN monotone, chunks ahead of off.
  Approach for Lean: model as abstract list of (off, len) chunks.

## Open PRs / Branches
- Branch `lean-squad-run42-24006276151-rangebuf-ci-a3f8e2b1c9d47f0e` (run 42, pending)
  Contains: RangeBuf.lean (16 theorems), stream_recv_buf_informal.md, TARGETS.md update,
  lean-ci.yml improvements (sorry-in-source step + workflow path trigger)

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available without Mathlib/Std — use `Nat.lt_or_ge`
- `split_ifs` NOT available without Std — use `split` or `by_cases`
- `push_neg` NOT available — use `Nat.le_of_not_gt` or `omega` instead
- `simp only [range_insert_go.eq_def]` LOOPS — use `unfold range_insert_go`
- `List.mem_cons_self` takes NO explicit args (zero explicit args)
- `lemma` keyword NOT available in Lean 4.29 without Mathlib — use `theorem`
- `bif` is a RESERVED KEYWORD in Lean 4 — do not use as variable name
- `at` is a RESERVED KEYWORD in Lean 4 — do not use as variable name
- `conv_rhs` tactic: NOT available without Mathlib — use explicit `have` + `rw`
- `set` tactic: NOT available without Std4/Mathlib — use explicit `have`
- `ring` tactic: NOT available without Mathlib
- `linarith` / `nlinarith`: NOT available without Mathlib
- `le_refl` NOT available without Mathlib — use `Nat.le_refl`
- omega handles Nat.div (e.g., `cwnd * 7 / 10 < cwnd` for cwnd > 0) ✅
- `Nat.pos_pow_of_pos DOES NOT EXIST` in Lean 4.29 — use `Nat.two_pow_pos` for powers of 2
- **Unused variable warnings**: use `_h` instead of `h` for proof-only bounds
- **grep -rh**: use `-h` flag to suppress filenames so `grep -v '^\s*--'` works

## TARGETS.md / CORRESPONDENCE.md / CRITIQUE.md
- TARGETS.md: 12 targets; #1-11 at Phase 5, #12 at Phase 2
- CORRESPONDENCE.md: last updated run 41 (10 files; RangeBuf not yet added)
- CRITIQUE.md: last updated run 41 (216 theorems assessed)

## Status Issue: #4 (open), updated run 42

## Summary
- **232 total theorems, 0 sorry** across 11 files (run 42: +16 from RangeBuf.lean)
- Varint: 10 | RangeSet: 16 | Minmax: 15 | RttStats: 23 | FlowControl: 22
  NewReno: 13 | DatagramQueue: 26 | PRR: 20 | PacketNumDecode: 24 | Cubic: 26
  RangeBuf: 16

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox). Document failure each run.
- FVSquad.lean imports all 11 modules

## Next Priorities
1. **RecvBuf Lean spec** — advance target #12 to Phase 3 using RangeBuf.lean
   as a foundation. Key: model buffer as list of non-overlapping (off, len)
   pairs; prove off_le_len invariant, write_monotone_len, is_fin_at_off
2. **CORRESPONDENCE.md update** — add RangeBuf entry (run 42 target)
3. **NewReno AIMD accumulation** — multi-step induction: sum of pkt_sizes = cwnd → cwnd += mds
4. **Packet number uniqueness** — uniqueness of decoded number within pkt_hwin
