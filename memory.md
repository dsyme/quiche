# Lean Squad Memory -- dsyme/quiche

Last updated: 2026-04-23 (run 95)
Lean toolchain: leanprover/lean4:v4.29.0 (lean-toolchain file); elan installs v4.30.0-rc2 (stable)
Lake project: formal-verification/lean/
FVSquad.lean: import manifest for all 26 modules

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
| 20 | pkt_num_len encoding length | quiche/src/packet.rs | 5 | Done; Route-B 18/18 PASS (run89) |
| 21 | SendBuf::retransmit model | quiche/src/stream/send_buf.rs | 5 | Done |
| 22 | RecvBuf flow-control bound | quiche/src/stream/recv_buf.rs | 0 | Identified |
| 23 | put_varint→get_varint roundtrip | octets/src/lib.rs | 5 | Done (8 thms, 2 sorry 8-byte) |
| 24 | encode_pkt_num→decode_pkt_num | quiche/src/packet.rs | 5 | Done (10 thms, 0 sorry) |
| 29 | QUIC packet-header first-byte | quiche/src/packet.rs | 4 | 14 thms, 1 sorry; CORR done run95 |
| 30 | Varint 2-bit tag consistency | octets/src/lib.rs | 5 | Done run85 (15 thms, 0 sorry); CORR done run95 |
| 31 | H3 frame type codec round-trip | quiche/src/h3/frame.rs | 2 | Informal spec done (run82) |
| 32 | BBR2 pacing rate bounds | quiche/src/recovery/gcongestion/bbr2.rs | 0 | MEDIUM |
| 33 | H3 Settings frame invariants | quiche/src/h3/frame.rs | 2 | Informal spec done (run86) |
| 34 | QPACK static table lookup | quiche/src/h3/qpack/ | 1 | ~30 lines, all decide; HIGH |
| 35 | H3 parse_settings_frame RFC | quiche/src/h3/frame.rs | 1 | H2-key rejection + size guard |
| 36 | Bandwidth arithmetic invariants | quiche/src/recovery/bandwidth.rs | 5 | Done run90 (22 thms, 0 sorry); Route-B 25/25 PASS; CORR done run95 |
| 37 | BytesInFlight counter invariant | quiche/src/recovery/bytes_in_flight.rs | 1 | ~50 lines, MEDIUM |
| 38 | PathState monotone progression | quiche/src/path.rs | 1 | RFC 9000 §8.2; ~45 lines; MEDIUM |
| 39 | QPACK lookup_static bounds | quiche/src/h3/qpack/ | 1 | all decide; ~20 lines; HIGH |
| 40 | QPACK decode_int prefix-mask | quiche/src/h3/qpack/decoder.rs | 1 | fuel model; ~50 lines; MEDIUM |
| 41 | Pacer pacing_rate cap | quiche/src/recovery/gcongestion/pacer.rs | 2 | Informal spec done run95; HIGH; ~25 lines |
| 42 | Frame ack_eliciting/probing | quiche/src/frame.rs | 1 | all decide; ~30 lines; HIGH |
| 43 | ACK frame acked-range bounds | quiche/src/frame.rs | 1 | induction; ~60 lines; HIGH |

## Lean File Registry (verified lake build Lean 4.30.0-rc2, run 90)

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
| FVSquad/PacketHeader.lean | 14 | 12 | 1 sorry (full RT deferred) |
| FVSquad/VarIntTag.lean | 15 | 22 | Done (run 85) |
| FVSquad/Bandwidth.lean | 22 | 9 | Done (run 90, 0 sorry) |
| **TOTAL** | **555** | **202** | **3 sorry** |

## Open Sorry Obligations

| Theorem | File | Blocking gap |
|---------|------|-------------|
| putVarint_freeze_getVarint_8byte | VarIntRoundtrip.lean | putU32_bytes_unchanged in OctetsMut.lean |
| putVarint_first_byte_tag (8-byte) | VarIntRoundtrip.lean | Same |
| longHeader_roundtrip | PacketHeader.lean | Full buffer model (byte-list encode/decode) |

## Route-B Correspondence Tests

| Target | Directory | Run | Cases | Result |
|--------|-----------|-----|-------|--------|
| T20 (PacketNumLen) | tests/pkt_num_len/ | 89 | 18 | 18/18 PASS |
| T36 (Bandwidth) | tests/bandwidth_arithmetic/ | 90 | 25 | 25/25 PASS |

## CORRESPONDENCE.md Coverage

All 26 Lean files now have CORRESPONDENCE.md entries (T29/T30/T36 added run95).

## CI Status

- lean-ci.yml: ✅ exists, working, path-triggered on formal-verification/lean/**

## Open PRs (lean-squad label)

- PR #77 (run92): REPORT.md + paper.tex — OPEN
- PR run95 (branch lean-squad-run95-24829414664-correspondence-informal):
  Task 2 — T41 informal spec (pacer_informal.md)
  Task 6 — CORRESPONDENCE.md entries for T29/T30/T36; TARGETS.md catch-up

## Status Issue

Issue #4 (open)

## Key Findings

- OQ-1 (run49): StreamPriorityKey antisymmetry violation (intentional by design)
- OQ-RT-1 (run68): zero-length retransmit with off > ackOff may not be no-op
- OQ-FC-1 (run70, not modelled): RESET_STREAM guard in RecvBuf not modelled
- decode_pktnum_correct spec refinement (run39): non-strict bound counterexample found

## Next Actions

1. T41: write FVSquad/Pacer.lean (Nat.min_le_left, ~25 lines, informal spec done run95)
2. T39: write FVSquad/QPACKStatic.lean (all decide, ~20 lines)
3. T42: write FVSquad/FrameClassification.lean (all decide, ~30 lines)
4. T43: write FVSquad/AckRanges.lean (induction on block list, ~60 lines)
5. T31: write FVSquad/H3Frame.lean (GoAway/MaxPushId/CancelPush round-trips)
6. Add putU32_bytes_unchanged to OctetsMut.lean → closes 2 sorry VarIntRoundtrip
