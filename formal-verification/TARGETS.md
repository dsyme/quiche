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
| 12 | `RecvBuf` stream reassembly | `quiche/src/stream/recv_buf.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 59 theorems; emitN+insertContiguous+insertAny invariant preservation; `insertAny_inv` proves full out-of-order write correctness; `FVSquad/RecvBuf.lean`; informal spec in `specs/stream_recv_buf_informal.md` |
| 13 | `SendBuf` stream send buffer | `quiche/src/stream/send_buf.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 43 theorems; flow-control safety, invariant preservation, FIN consistency; `FVSquad/SendBuf.lean` |
| 14 | Connection ID sequence management | `quiche/src/cid.rs` | 5 — All Proofs | ✅ Done | 21 theorems, 0 sorry; specs/cid_mgmt_informal.md; FVSquad/CidMgmt.lean |
| 15 | Stream priority ordering (`StreamPriorityKey::cmp`) | `quiche/src/stream/mod.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 21 theorems + 7 examples; OQ-1 `Ord` antisymmetry violation proved; `FVSquad/StreamPriorityKey.lean` |
| 16 | `OctetsMut` byte-buffer read/write | `octets/src/lib.rs` | 5 — Proofs ✅ | ✅ Done (run 63) | Cursor-based byte buffer; round-trip, invariant preservation; `FVSquad/OctetsMut.lean` (27 public + 6 private theorems, 0 sorry). Fixed in run 63: Mathlib-only `split_ifs` replaced with `by_cases`; file added to FVSquad.lean manifest. |
| 17 | `Octets` (read-only) byte-buffer | `octets/src/lib.rs` | 5 — Proofs ✅ | ✅ Done (run 62) | Read-only cursor; invariant, getU8/16/32/64, skip/rewind, big-endian decode; `FVSquad/Octets.lean` (48 theorems + 9 examples, 0 sorry) |
| 18 | StreamId RFC 9000 §2.1 arithmetic | `quiche/src/stream/mod.rs` + `lib.rs` | 5 — Proofs | ✅ Done (run 64) | 35 theorems + 8 examples, 0 sorry; PR #51 merged |
| 19 | Octets↔OctetsMut cross-module round-trip | `octets/src/lib.rs` | 5 — Proofs | ✅ Done (run 65) | 20 theorems + 9 examples, 0 sorry; PR #52 merged |
| 20 | `pkt_num_len` / `encode_pkt_num` length selection | `quiche/src/packet.rs` | 5 — Proofs | ✅ Done (run 66) | 20 theorems + 10 examples, 0 sorry; `FVSquad/PacketNumLen.lean` |

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

1. **Target 20: `pkt_num_len` / `encode_pkt_num`** — ✅ Done in run 66.
   `FVSquad/PacketNumLen.lean` (20 theorems + 10 examples, 0 sorry):
   `pktNumLen_valid` (always 1–4 bytes), `pktNumLen_eq_{one,two,three,four}_iff`
   (characterisation), coverage theorems (numUnacked fits in half-window),
   `pktNumLen_mono` (monotone in gap size), and `pktNumLen_ge_{two,three,four}`
   (gap threshold bounds).
2. **Target 21: SendBuf retransmit model** — The `retransmit` function
   (`quiche/src/stream/send_buf.rs:366`) moves bytes back to the send queue.
   Properties: `retransmit(off, len)` increases `self.len` by the number of
   bytes in `[off, off+len)` that had been emitted; the `SendBuf` invariant
   is preserved; `len` never exceeds the buffer capacity.
3. **Target 22: RecvBuf flow-control bound** — Prove `highMark ≤ max_data`
   is maintained by `RecvBuf` operations (currently unmodelled).
4. **RangeSet semantic completeness** — prove `flatten(insert(rs,r))` equals
   `set_union`; see CRITIQUE.md
4. **NewReno AIMD rate theorem** — prove exact growth rate (one MSS per cwnd
   bytes ACKed) across multiple ACK callbacks; currently only per-callback
   growth is verified
5. **Stream flow control** — per-stream window using same model as FlowControl

## Archived / Completed Targets

| # | Target | Phase | PR | Notes |
|---|--------|-------|----|-------|
| 1 | QUIC varint codec | 5 — All Proofs | PR #5 (merged) | round_trip + 9 others; 0 sorry |
| 2 | RangeSet invariants | 5 — All Proofs | PR #22 (merged) | insert_preserves_invariant + 13 others; 0 sorry |
| 3 | Minmax filter | 5 — All Proofs | PR #15 (merged) | 15 theorems; 0 sorry |
| 7 | PRR (Proportional Rate Reduction) | 5 — All Proofs | pending | 20 theorems; 0 sorry |

| 18 | StreamId RFC 9000 §2.1 arithmetic | 5 — All Proofs | run 64 | 35 theorems; 0 sorry |
| 19 | Octets↔OctetsMut cross-module round-trip | 5 — All Proofs | run 65 | 20 theorems + 9 examples; 0 sorry |
