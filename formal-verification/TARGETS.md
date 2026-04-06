# FV Targets — quiche

> 🔬 *Maintained by Lean Squad automated formal verification.*

## Priority Order

| # | Target | Location | Phase | Status | Notes |
|---|--------|----------|-------|--------|-------|
| 1 | QUIC varint codec | `octets/src/lib.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 10 theorems; PR #5 merged |
| 2 | `RangeSet` invariants | `quiche/src/ranges.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 14 theorems incl. `insert_preserves_invariant`; PR #22 merged |
| 3 | Minmax filter | `quiche/src/minmax.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 15 theorems; PR #15 merged |
| 4 | RTT estimation | `quiche/src/recovery/rtt.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 24 theorems incl. `adjusted_rtt_ge_min_rtt`; `FVSquad/RttStats.lean` |
| 5 | Flow control | `quiche/src/flowcontrol.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 22 theorems; `FVSquad/FlowControl.lean`; informal spec in `specs/flowcontrol_informal.md` |
| 6 | Congestion window (NewReno) | `quiche/src/recovery/congestion/reno.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 13 theorems incl. `cwnd_floor_new_event`, `single_halving`; `FVSquad/NewReno.lean` |
| 7 | DatagramQueue | `quiche/src/dgram.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 26 theorems; capacity invariant, byte-size tracking, FIFO ordering; `FVSquad/DatagramQueue.lean` |
| 8 | PRR (Proportional Rate Reduction) | `quiche/src/recovery/congestion/prr.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 20 theorems; RFC 6937 rate bound, SSRB bounds; `FVSquad/PRR.lean` |
| 9 | Packet number decode (RFC 9000 §A.3) | `quiche/src/packet.rs` | 5 — Proofs | ✅ Complete | **0 sorry** — 24 theorems; `decode_pktnum_correct` fully proved (run 39); `FVSquad/PacketNumDecode.lean` |
| 10 | CUBIC congestion control | `quiche/src/recovery/congestion/cubic.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 26 theorems; RFC 8312bis constants, ssthresh reduction, W_cubic algebraic properties, fast convergence; `FVSquad/Cubic.lean` |
| 11 | `RangeBuf` offset arithmetic | `quiche/src/range_buf.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 19 theorems; maxOff invariance under consume, split adjacency, partition; `FVSquad/RangeBuf.lean` |
| 12 | `RecvBuf` stream reassembly | `quiche/src/stream/recv_buf.rs` | 3 — Lean Spec | 🔄 In progress | **0 sorry** — 21 theorems; emitN invariant preservation, readOff monotone; `FVSquad/RecvBuf.lean`; informal spec in `specs/stream_recv_buf_informal.md` |

## Phase Definitions

| Phase | Name | Description |
|-------|------|-------------|
| 0 | Identified | Added to this list |
| 1 | Research | Surveyed; benefit, tractability, approach documented in RESEARCH.md |
| 2 | Informal Spec | `specs/<name>_informal.md` written |
| 3 | Lean Spec | Lean 4 file with type definitions, theorem statements, and implementation model |
| 4 | Implementation | Lean functional model with implementation details extracted |
| 5 | Proofs | Key theorems proved (or counterexamples found) — 0 sorry |

## Next Actions

1. **RangeSet semantic completeness** — prove `flatten(insert(rs,r))` equals
   `set_union`; see CRITIQUE.md
2. **NewReno AIMD rate theorem** — prove exact growth rate (one MSS per cwnd
   bytes ACKed) across multiple ACK callbacks; currently only per-callback
   growth is verified
3. **Stream flow control** — per-stream window using same model as FlowControl

## Archived / Completed Targets

| # | Target | Phase | PR | Notes |
|---|--------|-------|----|-------|
| 1 | QUIC varint codec | 5 — All Proofs | PR #5 (merged) | round_trip + 9 others; 0 sorry |
| 2 | RangeSet invariants | 5 — All Proofs | PR #22 (merged) | insert_preserves_invariant + 13 others; 0 sorry |
| 3 | Minmax filter | 5 — All Proofs | PR #15 (merged) | 15 theorems; 0 sorry |
| 7 | PRR (Proportional Rate Reduction) | 5 — All Proofs | pending | 20 theorems; 0 sorry |
