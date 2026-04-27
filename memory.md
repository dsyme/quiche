# Lean Squad Memory -- dsyme/quiche

Last updated: 2026-04-27 (run 109)
Lean toolchain: leanprover/lean4:v4.29.0 (lean-toolchain file); elan installs v4.30.0-rc2 (stable)
Lake project: formal-verification/lean/
FVSquad.lean: import manifest for all 31 modules

## FV Targets

| # | Name | File | Phase | Status |
|---|------|------|-------|--------|
| 1-21 | (various done targets) | various | 5 | All Done (see prior runs)
| 23 | put_varint→get_varint roundtrip | octets/src/lib.rs | 5 | Done (10 thms, 0 sorry) |
| 24 | encode_pkt_num→decode_pkt_num | quiche/src/packet.rs | 5 | Done (10 thms, 0 sorry) |
| 29 | QUIC packet-header first-byte + full roundtrip | quiche/src/packet.rs | 5 | Done run105 (16 thms, 0 sorry) |
| 30 | Varint 2-bit tag consistency | octets/src/lib.rs | 5 | Done run85 (15 thms, 0 sorry) |
| 31 | H3 frame type codec round-trip | quiche/src/h3/frame.rs | 5 | Done run99/100 (19 thms, 0 sorry); Route-B 25/25 PASS run103 |
| 32 | BBR2 pacing rate bounds | quiche/src/recovery/gcongestion/bbr2.rs | 0 | MEDIUM — next new target |
| 33 | H3 Settings frame invariants | quiche/src/h3/frame.rs | 5 | Done run108 (28 thms, 0 sorry) |
| 36 | Bandwidth arithmetic invariants | quiche/src/recovery/bandwidth.rs | 5 | Done run90 (22 thms, 0 sorry); Route-B 25/25 PASS |
| 37 | BytesInFlight counter invariant | quiche/src/recovery/bytes_in_flight.rs | 5 | Done run107 (17 thms, 0 sorry); open PR |
| 38 | PathState monotone progression | quiche/src/path.rs | 5 | Done run109 (24 thms, 0 sorry); open PR |
| 39 | QPACK lookup_static bounds | quiche/src/h3/qpack/ | 5 | Done run97 (12 thms, 0 sorry) |
| 40 | QPACK decode_int prefix-mask | quiche/src/h3/qpack/decoder.rs | 1 | fuel model; ~50 lines; MEDIUM |
| 41 | Pacer pacing_rate cap | quiche/src/recovery/gcongestion/pacer.rs | 5 | Done run98 (17 thms, 0 sorry) |
| 42 | Frame ack_eliciting/probing | quiche/src/frame.rs | 5 | Done run97 (25 thms, 0 sorry) |
| 43 | ACK frame acked-range bounds | quiche/src/frame.rs | 5 | Done run102 (29 thms, 0 sorry); Route-B 25/25 PASS |

## 🎉 MILESTONE: 0 SORRY (as of run 105, maintained run 109)

All ~673 theorems across 31 Lean files are fully proved with 0 sorry.

## Lean File Registry (verified lake build v4.30.0-rc2, run 109)

| File | Theorems | Status |
|------|----------|--------|
| FVSquad/Varint.lean | 10 | Done |
| FVSquad/RangeSet.lean | 16 | Done |
| FVSquad/Minmax.lean | 15 | Done |
| FVSquad/RttStats.lean | 23 | Done |
| FVSquad/FlowControl.lean | 22 | Done |
| FVSquad/NewReno.lean | 13 | Done |
| FVSquad/DatagramQueue.lean | 26 | Done |
| FVSquad/PRR.lean | 20 | Done |
| FVSquad/PacketNumDecode.lean | 23 | Done |
| FVSquad/Cubic.lean | 26 | Done |
| FVSquad/RangeBuf.lean | 19 | Done |
| FVSquad/RecvBuf.lean | 38 | Done |
| FVSquad/SendBuf.lean | 26 | Done |
| FVSquad/CidMgmt.lean | 21 | Done |
| FVSquad/StreamPriorityKey.lean | 21 | Done |
| FVSquad/OctetsMut.lean | 27 | Done |
| FVSquad/Octets.lean | 48 | Done |
| FVSquad/OctetsRoundtrip.lean | 21 | Done |
| FVSquad/StreamId.lean | 35 | Done |
| FVSquad/PacketNumLen.lean | 20 | Done |
| FVSquad/SendBufRetransmit.lean | 17 | Done |
| FVSquad/VarIntRoundtrip.lean | 8 | Done |
| FVSquad/PacketNumEncodeDecode.lean | 10 | Done |
| FVSquad/PacketHeader.lean | 16 | Done run105 (0 sorry) |
| FVSquad/VarIntTag.lean | 15 | Done run85 |
| FVSquad/Bandwidth.lean | 22 | Done run90 |
| FVSquad/Pacer.lean | 17 | Done run98 |
| FVSquad/H3Frame.lean | 19 | Done run99/100 |
| FVSquad/AckRanges.lean | 29 | Done run102 |
| FVSquad/BytesInFlight.lean | 17 | Done run107 |
| FVSquad/PathState.lean | 24 | Done run109 |
| **TOTAL** | **~673** | **0 sorry** 🎉 |

## Route-B Correspondence Tests

| Target | Directory | Run | Cases | Result |
|--------|-----------|-----|-------|--------|
| T20 (PacketNumLen) | tests/pkt_num_len/ | 89 | 18 | 18/18 PASS |
| T36 (Bandwidth) | tests/bandwidth_arithmetic/ | 90/94 | 25 | 25/25 PASS |
| T2 (RangeSet) | tests/rangeset_insert/ | 96 | 21 | 21/21 PASS |
| T43 (AckRanges) | tests/ack_ranges/ | 102 | 25 | 25/25 PASS |
| T31 (H3Frame) | tests/h3_frame/ | 103 | 25 | 25/25 PASS |

## CI Status

- lean-ci.yml: exists, working, path-triggered on formal-verification/lean/**

## Open PRs (lean-squad label)

- PR run107 (branch lean-squad-run107-24976389936-bytes-in-flight): T37 BytesInFlight.lean (17 thms, 0 sorry)
- PR run109 (branch lean-squad-run109-25010820444-pathstate-correspondence): T38 PathState.lean (24 thms, 0 sorry) + CORRESPONDENCE update

## Status Issue

Issue #4 (open) — updated run109

## Key Findings

- OQ-1 (run49): StreamPriorityKey antisymmetry violation (intentional by design)
- OQ-RT-1 (run68): zero-length retransmit with off > ackOff may not be no-op
- OQ-FC-1 (run70): RESET_STREAM guard in RecvBuf not modelled
- decode_pktnum_correct spec refinement (run39): non-strict bound counterexample found
- OQ-T43-2 (run100): uncapped block_count in parse_ack_frame — potential DoS vector
- OQ-T37-1 (run103): clock-monotonicity not asserted in BytesInFlight.add/subtract
- OQ-T37-2 (run103): open_interval_duration reset on close (confirmed correct)
- T33 note (run108): SETTINGS_FRAME_TYPE_ID (0x4) is in the reserved set
- T38 note (run109): PathState proves no typeclass LE/LT (causes simp loops in pure Lean 4 without Mathlib); use State.rank directly

## Next Priority Targets

1. T32 (BBR2 pacing rate bounds) — gcongestion, medium difficulty
2. Route-B tests for T37 (BytesInFlight) — correspondence evidence
3. Route-B tests for T38 (PathState) — state machine transition tests
4. Route-B tests for T33 (H3Settings) — validate against Rust parse_settings_frame
5. T40 (QPACK decode_int prefix-mask) — fuel model, ~50 lines
