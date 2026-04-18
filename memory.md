# Lean Squad Memory -- dsyme/quiche

Last updated: 2026-04-18 (run 79)
Lean toolchain: leanprover/lean4:v4.29.0 (via elan)
Lake project: formal-verification/lean/
FVSquad.lean: import manifest for all modules

## FV Targets

| # | Name | File | Phase | Status |
|---|------|------|-------|--------|
| 1 | Varint encoding | octets/src/lib.rs | 5 | Done |
| 2 | RangeSet interval algebra | quiche/src/ranges.rs | 5 | Done |
| 3 | Minmax filter | quiche/src/minmax.rs | 5 | Done |
| 4 | RTT estimator (EWMA) | quiche/src/recovery/rtt.rs | 5 | Done |
| 5 | Flow control window | quiche/src/flowcontrol.rs | 5 | Done |
| 6 | NewReno congestion | quiche/src/recovery/congestion/reno.rs | 5 | Done |
| 7 | DatagramQueue | quiche/src/dgram.rs | 5 | Done |
| 8 | PRR packet pacing | quiche/src/recovery/prr.rs | 5 | Done |
| 9 | Packet number decode | quiche/src/packet.rs | 5 | Done |
| 10 | Cubic CC | quiche/src/recovery/congestion/cubic.rs | 5 | Done |
| 11 | RangeBuf offset arithmetic | quiche/src/range_buf.rs | 5 | Done |
| 12 | RecvBuf stream reassembly | quiche/src/stream/recv_buf.rs | 5 | Done |
| 13 | SendBuf stream send buffer | quiche/src/stream/send_buf.rs | 5 | Done |
| 14 | CID management | quiche/src/cid.rs | 5 | Done |
| 15 | StreamPriorityKey ordering | quiche/src/stream/mod.rs | 5 | Done |
| 16 | OctetsMut byte serializer | octets/src/lib.rs | 5 | Done |
| 17 | Octets read-only cursor | octets/src/lib.rs | 5 | Done |
| 18 | StreamId RFC 9000 §2.1 | quiche/src/stream/mod.rs | 5 | Done |
| 19 | OctetsRoundtrip cross-module | octets/src/lib.rs | 5 | Done |
| 20 | pkt_num_len encoding length | quiche/src/packet.rs | 5 | Done |
| 21 | SendBuf::retransmit model | quiche/src/stream/send_buf.rs | 5 | Done |
| 22 | RecvBuf flow-control bound | quiche/src/stream/recv_buf.rs | 0 | Identified |
| 23 | put_varint→get_varint roundtrip | octets/src/lib.rs | 5 | Done (8 thms, 2 sorry for 8-byte) |
| 24 | encode_pkt_num→decode_pkt_num | quiche/src/packet.rs | 5 | Done (10 thms, 0 sorry) |
| 25 | StreamId↔stream_do_send guard | quiche/src/lib.rs | 0 | Identified |
| 26 | CUBIC W_cubic vs W_est | quiche/src/recovery/congestion/cubic.rs | 0 | Identified (MEDIUM) |
| 27 | CidMgmt retire_if_needed | quiche/src/cid.rs | 0 | Identified (MEDIUM) |
| 28 | NewReno multi-cycle AIMD | quiche/src/recovery/congestion/reno.rs | 0 | Identified (MEDIUM) |
| 29 | QUIC packet-header roundtrip | quiche/src/packet.rs | 2 | Informal Spec (run73) |
| 30 | Varint 2-bit tag consistency | octets/src/lib.rs | 0 | Identified (HIGH) |
| 31 | H3 frame type codec round-trip | quiche/src/h3/frame.rs | 0 | NEW run78 (HIGH) |
| 32 | BBR2 pacing rate bounds | quiche/src/recovery/gcongestion/bbr2.rs | 0 | NEW run78 (MEDIUM) |
| 33 | H3 Settings frame invariants | quiche/src/h3/frame.rs | 0 | NEW run78 (MEDIUM) |

## Lean File Registry (verified lake build run79)

| File | Theorems | Examples | Status |
|------|----------|----------|--------|
| FVSquad/Varint.lean | 10 | 25 | Done |
| FVSquad/RangeSet.lean | 16 | 15 | Done |
| FVSquad/Minmax.lean | 15 | 6 | Done |
| FVSquad/RttStats.lean | 23 | 2 | Done |
| FVSquad/FlowControl.lean | 22 | 1 | Done |
| FVSquad/NewReno.lean | 13 | 0 | Done |
| FVSquad/DatagramQueue.lean | 26 | 0 | Done |
| FVSquad/PRR.lean | 20 | 0 | Done |
| FVSquad/PacketNumDecode.lean | 23 | 0 | Done |
| FVSquad/Cubic.lean | 26 | 0 | Done |
| FVSquad/RangeBuf.lean | 19 | 5 | Done |
| FVSquad/RecvBuf.lean | 38 | 17 | Done |
| FVSquad/SendBuf.lean | 26 | 11 | Done |
| FVSquad/CidMgmt.lean | 21 | 13 | Done |
| FVSquad/StreamPriorityKey.lean | 21 | 8 | Done |
| FVSquad/OctetsMut.lean | 27 | 7 | Done |
| FVSquad/Octets.lean | 48 | 9 | Done |
| FVSquad/OctetsRoundtrip.lean | 20 | 9 | Done |
| FVSquad/StreamId.lean | 35 | 8 | Done |
| FVSquad/PacketNumLen.lean | 20 | 10 | Done |
| FVSquad/SendBufRetransmit.lean | 17 | 10 | Done |
| FVSquad/VarIntRoundtrip.lean | 8 | 16 | 2 sorry (8-byte varint) |
| FVSquad/PacketNumEncodeDecode.lean | 10 | 23 | Done |
| **TOTAL** | **504** | **175** | **2 sorry** |

## Open PRs (lean-squad label)

- PR run78 (branch lean-squad-run78-24578215430-paper-research-e187acd3c26faf23):
  Task 11 — Conference paper (paper.tex + paper.bib) + Task 1 T31/T32/T33
- PR run79 (branch lean-squad-run79-24596073436-correspondence-paper):
  Task 6 — CORRESPONDENCE.md (2 sorry found, Open Sorry Obligations section)
  Task 11 — paper.tex accuracy (0 sorry → 2 sorry)
  REPORT.md: status + file inventory updated

## Status Issue

Issue #4 (open)

## Key Findings

- OQ-1 (run49): StreamPriorityKey antisymmetry violation (intentional by design)
- OQ-RT-1 (run68): zero-length retransmit with off > ackOff may not be no-op
- OQ-FC-1 (run70, not modelled): RESET_STREAM guard in RecvBuf not modelled
- decode_pktnum_correct spec refinement (run39): non-strict bound counterexample found and corrected
- OQ-T29-1 (run73): Initial token=None encodes as varint 0, decodes as Some([]) — asymmetry
- OQ-T29-2 (run73): to_bytes does not validate CID lengths
- OQ-T29-3 (run73): pkt_num/key_phase not in to_bytes/from_bytes roundtrip
- OQ-T23-1 (run74): over-long encoding tag consistency (put_varint_with_len)
- OQ-T23-2 (run74): OctetsMut.get_varint ≡ Octets.get_varint equivalence
- **run79 CORRECTION**: VarIntRoundtrip.lean has 2 sorry (not 0 as previously recorded)
  Both in 8-byte varint case; need putU32_bytes_unchanged lemma to close.

## CORRESPONDENCE.md Coverage (run79)

All 23 Lean files covered. 2 sorry obligations documented in new section.
No mismatches identified.

## Next Priority Targets

1. Add putU32_bytes_unchanged to OctetsMut.lean → closes 2 sorry in VarIntRoundtrip.lean (Task 5)
2. T29 PacketHeader.lean — write Lean spec (Task 3)
3. T30 Varint 2-bit tag (LOW effort, HIGH value; ~40 Lean lines)
4. T31 H3 frame round-trip (Task 2 informal spec first)
5. T22 RecvBuf flow-control bound

## Anti-Patterns (DO NOT USE without Mathlib)

- `split_ifs` — Mathlib-only; use `by_cases hc : COND`
- `linarith` — Mathlib-only; use `omega`
- `native_decide` on struct equality — SendState lacks DecidableEq
- `|>` before `=` in examples — parenthesise: `(expr).field = val`
- `simp [h]; omega` — if simp closes goal, omega sees "No goals to be solved"

## Key Proof Patterns (no Mathlib)

- If-then-else in hypothesis: `by_cases hc : COND`
- min/max idempotence: `Nat.min_eq_left (Nat.min_le_right a b)`
- Struct equality one field differs: `congr 1` then prove field equality
- Roundtrip existential: `refine ⟨witness, ?_⟩` then simp+omega
- Nat.sub with omega: need `b ≤ a` in context
- Nat.max with omega: add `have := Nat.le_max_left a b` explicitly
- Cross-module: private theorems must be re-proved inline

## CI Status (run79)

- lean-ci.yml: exists, correct triggers (PR + push master/main on formal-verification/lean/**)
- lake build: passes with 26 jobs, 2 sorry warnings, 0 errors (run79)
- lean-toolchain: leanprover/lean4:v4.29.0

## Lake Project

No Mathlib dependency (lake-manifest.json is empty packages).
FVSquad.lean imports 23 modules (in order): Octets, Varint, RangeSet,
  Minmax, RttStats, FlowControl, NewReno, DatagramQueue, PRR, PacketNumDecode,
  Cubic, RangeBuf, RecvBuf, SendBuf, CidMgmt, StreamPriorityKey, OctetsMut,
  OctetsRoundtrip, StreamId, PacketNumLen, SendBufRetransmit,
  VarIntRoundtrip, PacketNumEncodeDecode
