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
| 21 | `SendBuf::retransmit` — retransmit model | `quiche/src/stream/send_buf.rs` | 5 — Proofs | ✅ Done (run 68) | 17 theorems + 10 examples, 0 sorry; `FVSquad/SendBufRetransmit.lean` |
| 22 | `RecvBuf` flow-control bound (`highMark ≤ max_data`) | `quiche/src/stream/recv_buf.rs` | 0 | ⬜ Identified | Gap #2 from CRITIQUE.md; see specs/recv_buf_flowcontrol_informal.md (planned) |
| 23 | `put_varint` → `get_varint` cross-module round-trip | `octets/src/lib.rs` | 0 | ⬜ Identified | Gap #3 from CRITIQUE.md; closes the varint codec verification |
| 24 | `encode_pkt_num` → `decode_pkt_num` composition | `quiche/src/packet.rs` | 0 | ⬜ Identified | Gap #4 from CRITIQUE.md; closes the QUIC pkt-num lifecycle |
| 25 | `StreamId`↔`stream_do_send` guard correctness | `quiche/src/lib.rs` | 0 | ⬜ Identified | Gap #6 from CRITIQUE.md; RFC 9000 §2.1 stream-direction guard |

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

1. **Target 21: `SendBuf::retransmit` model** — ✅ Done in run 68.
   `FVSquad/SendBufRetransmit.lean` (17 theorems + 10 examples, 0 sorry):
   `retransmit_inv` (invariant preserved), `retransmit_emitOff_le` (anti-monotone),
   `retransmit_idempotent`, `retransmit_send_backlog_le` (backlog grows),
   and `retransmit_emitN_inv` (invariant preserved through emitN).
2. **Target 22: RecvBuf flow-control bound** — Prove the `RecvBuf` write
   operation enforces `buf.max_off() ≤ max_data()` (recv_buf.rs:93), and that
   `highMark = max offset seen` never exceeds the advertised window.
   `highMark ≤ max_data` is the memory-safety invariant for the receive buffer.
3. **Target 23: put_varint → get_varint cross-module round-trip** — Model
   `put_varint` (OctetsMut) followed by `freeze` + `get_varint` (Octets) and
   prove the original value is recovered for all QUIC-valid varint values.
   This closes the last gap in the codec verification.
4. **Target 24: encode_pkt_num → decode_pkt_num composition** — Prove that
   encoding then decoding a valid packet number recovers the original.
   `PacketNumLen.lean` + `PacketNumDecode.lean` prove the parts independently;
   this proves the composition.
5. **Target 25: StreamId↔stream_do_send guard correctness** — Prove that the
   `is_bidi && is_local` guard in `stream_do_send` correctly selects exactly
   the stream IDs that RFC 9000 §2.1 permits for sending.

## Archived / Completed Targets

| # | Target | Phase | PR | Notes |
|---|--------|-------|----|-------|
| 1 | QUIC varint codec | 5 — All Proofs | PR #5 (merged) | round_trip + 9 others; 0 sorry |
| 2 | RangeSet invariants | 5 — All Proofs | PR #22 (merged) | insert_preserves_invariant + 13 others; 0 sorry |
| 3 | Minmax filter | 5 — All Proofs | PR #15 (merged) | 15 theorems; 0 sorry |
| 7 | PRR (Proportional Rate Reduction) | 5 — All Proofs | pending | 20 theorems; 0 sorry |

| 18 | StreamId RFC 9000 §2.1 arithmetic | 5 — All Proofs | run 64 | 35 theorems; 0 sorry |
| 19 | Octets↔OctetsMut cross-module round-trip | 5 — All Proofs | run 65 | 20 theorems + 9 examples; 0 sorry |
