# Lean Squad Memory — dsyme/quiche

## Tool & Approach
- **FV tool**: Lean 4 (v4.29.0, no Mathlib)
- **Project**: `formal-verification/lean/` — `lake init FVSquad` (no Mathlib)
- **CI**: `.github/workflows/lean-ci.yml` (added run 15; improved run 42)

## Targets

### 1. Varint encoding/decoding — Phase 5 COMPLETE (10 theorems) — PR #5
### 2. RangeSet sorted-interval — Phase 5 COMPLETE (16 theorems) — PR #22
### 3. Minmax filter — Phase 5 COMPLETE (15 theorems) — PR #15
### 4. RTT estimator — Phase 5 COMPLETE (23 theorems) — PR #23
### 5. Flow control — Phase 5 COMPLETE (22 theorems) — PR #26
### 6. Congestion window (NewReno) — Phase 5 COMPLETE (13 theorems) — PR #28
### 7. DatagramQueue — Phase 5 COMPLETE (26 theorems) — PR #29
### 8. PRR — Phase 5 COMPLETE (20 theorems) — PR #30
### 9. Packet number decode — Phase 5 COMPLETE (24 theorems) — PR #32
### 10. CUBIC congestion control — Phase 5 COMPLETE (26 theorems) — PR #36
### 11. RangeBuf offset arithmetic
- Phase 5 COMPLETE (19 theorems, 0 sorry)
- Lean file: FVSquad/RangeBuf.lean
- Key: consume_maxOff, split_adjacent, split_maxOff

### 12. Stream receive buffer (RecvBuf)
- Phase 4 — Implementation (32 theorems, 0 sorry)
- Lean file: FVSquad/RecvBuf.lean
- Informal spec: specs/stream_recv_buf_informal.md
- emitN: fully proved (§5-§7, 21 theorems)
- insertContiguous: fully proved (§9, 11 new theorems, run 44)
  - insertContiguous_inv: all 5 invariants preserved
  - insertContiguous_two_highMark: sequential writes advance by c1.len+c2.len
- Next: model general write() with overlap handling (sorry-guarded)

### 13. SendBuf stream send buffer — Phase 1 Research
- File: quiche/src/stream/send_buf.rs
- Key invariants: ack_off ≤ emit_off ≤ off; emit_off ≤ max_data
- Priority: HIGH — linear arithmetic, all provable by omega
- Approach: SendState model (off, emit_off, ack_off, max_data, fin_off : Nat)

### 14. Connection ID sequence management — Phase 1 Research
- File: quiche/src/cid.rs
- Key: next_scid_seq strictly monotone, no duplicate seqs, bounded active set
- Priority: MEDIUM — seq monotonicity easy; disjointness harder

## Open PRs / Branches
- `lean-squad-run44-24027263298-recvbuf-impl-sendbuf-research` (run 44, pending)
  RecvBuf.lean +11 theorems, RESEARCH.md (targets 13-14), TARGETS.md, CORRESPONDENCE.md
- `lean-squad-run43-24017867324-rangebuf-recvbuf-spec-a1b2c3d4e5f6-58a179bdb3935c27`
  (run 43, pending — merged into run 44 branch)

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available — use `Nat.lt_or_ge`
- `split_ifs` NOT available — use `split` or `by_cases`
- `push_neg` NOT available — use `omega`
- `simp only [range_insert_go.eq_def]` LOOPS — use `unfold`
- `lemma` keyword NOT available — use `theorem`
- `bif`, `at` are RESERVED KEYWORDS
- `conv_rhs`, `set`, `ring`, `linarith`, `nlinarith` NOT available (no Mathlib)
- omega handles Nat.div; `simp only [...] at *; omega` for goals involving
  terms that simp can reduce to arithmetic in hypotheses too
- `cases hrest : e with | cons b bs => subst hrest` pattern for list case
  analysis (subst substitutes the variable)
- `chunksOrdered_snoc`: proved via `cases hrest : rest; subst hrest; show ...`
- `show` tactic changes goal to definitionally equal type (safe for def unfolding)
- `⟨ha, hb⟩` anonymous constructor works for And goals
- `Nat.two_pow_pos` for powers of 2 (not `Nat.pos_pow_of_pos`)
- `simp only [...] at *` to simplify hypotheses for omega

## Status Issue: #4 (open), updated run 44

## Summary
- **266 total theorems, 0 sorry** across 12 files
- Varint:10 | RangeSet:16 | Minmax:15 | RttStats:23 | FlowControl:22
  NewReno:13 | DatagramQueue:26 | PRR:20 | PacketNumDecode:24 | Cubic:26
  RangeBuf:19 | RecvBuf:32

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox — no new privileges flag)
- FVSquad.lean imports all 12 modules

## Next Priorities
1. **RecvBuf general write** — add abstract `writeChunk` with highMark
   monotonicity; use sorry for overlap resolution; prove write_inv via axiom
2. **SendBuf Lean spec** — target 13, Phase 2→3: define SendState model,
   prove write_mono (off non-decreasing), cap_inv (emit_off ≤ max_data),
   update_max_data_mono
3. **CORRESPONDENCE.md** — update critique for run 44 additions
