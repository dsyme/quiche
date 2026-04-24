# Lean Squad Memory -- dsyme/quiche

Last updated: 2026-04-24 (run 98)
Lean toolchain: leanprover/lean4:v4.29.0 (lean-toolchain file); elan installs v4.30.0-rc2 (stable)
Lake project: formal-verification/lean/
FVSquad.lean: import manifest for all 30 modules

## FV Targets

| # | Name | File | Phase | Status |
|---|------|------|-------|--------|
| 1-21 | (various done targets) | various | 5 | All Done (see prior runs)
| 22 | RecvBuf flow-control bound | quiche/src/stream/recv_buf.rs | 0 | Identified |
| 23 | put_varint→get_varint roundtrip | octets/src/lib.rs | 5 | Done (10 thms, 0 sorry) |
| 24 | encode_pkt_num→decode_pkt_num | quiche/src/packet.rs | 5 | Done (10 thms, 0 sorry) |
| 29 | QUIC packet-header first-byte | quiche/src/packet.rs | 4 | 14 thms, 1 sorry |
| 30 | Varint 2-bit tag consistency | octets/src/lib.rs | 5 | Done run85 (15 thms, 0 sorry) |
| 31 | H3 frame type codec round-trip | quiche/src/h3/frame.rs | 2 | Informal spec done (run82) |
| 32 | BBR2 pacing rate bounds | quiche/src/recovery/gcongestion/bbr2.rs | 0 | MEDIUM |
| 33 | H3 Settings frame invariants | quiche/src/h3/frame.rs | 2 | Informal spec done (run86) |
| 34 | QPACK static table lookup | quiche/src/h3/qpack/ | 1 | Researched run87 |
| 35 | H3 parse_settings_frame RFC | quiche/src/h3/frame.rs | 1 | Researched run87 |
| 36 | Bandwidth arithmetic invariants | quiche/src/recovery/bandwidth.rs | 5 | Done run90 (22 thms, 0 sorry); Route-B 25/25 PASS |
| 37 | BytesInFlight counter invariant | quiche/src/recovery/bytes_in_flight.rs | 1 | ~50 lines, MEDIUM |
| 38 | PathState monotone progression | quiche/src/path.rs | 1 | RFC 9000 §8.2; ~45 lines; MEDIUM |
| 39 | QPACK lookup_static bounds | quiche/src/h3/qpack/ | 5 | Done run97 (12 thms, 0 sorry) |
| 40 | QPACK decode_int prefix-mask | quiche/src/h3/qpack/decoder.rs | 1 | fuel model; ~50 lines; MEDIUM |
| 41 | Pacer pacing_rate cap | quiche/src/recovery/gcongestion/pacer.rs | 5 | Done run98 (17 thms, 0 sorry) |
| 42 | Frame ack_eliciting/probing | quiche/src/frame.rs | 5 | Done run97 (25 thms, 0 sorry) |
| 43 | ACK frame acked-range bounds | quiche/src/frame.rs | 1 | induction; ~60 lines; HIGH |

## Lean File Registry (verified lake build v4.29.0, run 98)

| File | Theorems | Examples | Status |
| **TOTAL** | **620** | **257** | **3 sorry** |

## Open Sorry Obligations

| Theorem | File | Blocking gap |
|---------|------|-------------|
| putVarint_freeze_getVarint_8byte | VarIntRoundtrip.lean | putU32_bytes_before in OctetsRoundtrip.lean |
| putVarint_first_byte_tag (8-byte) | VarIntRoundtrip.lean | Same |
| longHeader_roundtrip | PacketHeader.lean | Full buffer model (byte-list encode/decode) |

## Route-B Correspondence Tests

| Target | Directory | Run | Cases | Result |
|--------|-----------|-----|-------|--------|
| T20 (PacketNumLen) | tests/pkt_num_len/ | 89 | 18 | 18/18 PASS |
| T36 (Bandwidth) | tests/bandwidth_arithmetic/ | 90/94 | 25 | 25/25 PASS |
| T2 (RangeSet) | tests/rangeset_insert/ | 96 | 21 | 21/21 PASS |

## CI Status

- lean-ci.yml: exists, working, path-triggered on formal-verification/lean/**

## Open PRs (lean-squad label)

- PR run97 (branch lean-squad-run97-24871494942-frame-classification-qpack):
  Task 3/4 — T42 FrameClassification.lean (25 thms, 0 sorry)
  Task 5 — T39 QPACKStatic.lean (12 thms, 0 sorry)
  + informal spec: frame_classification_informal.md

## Status Issue

Issue #4 (open)

## Key Findings

- OQ-1 (run49): StreamPriorityKey antisymmetry violation (intentional by design)
- OQ-RT-1 (run68): zero-length retransmit with off > ackOff may not be no-op
- OQ-FC-1 (run70): RESET_STREAM guard in RecvBuf not modelled
- decode_pktnum_correct spec refinement (run39): non-strict bound counterexample found
- RangeSet accumulator-cons-order (run96): corrected and 21/21 tests pass

## Next Actions

1. T41: write FVSquad/Pacer.lean (Nat.min_le_left, ~25 lines) — HIGH
2. T43: write FVSquad/AckRanges.lean (induction on block list, ~60 lines) — HIGH
3. T31: write FVSquad/H3Frame.lean (GoAway/MaxPushId/CancelPush round-trips)
4. Add putU32_bytes_before to OctetsRoundtrip.lean → closes 2 sorry VarIntRoundtrip
5. T29: extend PacketHeader.lean with full byte-list model → closes 1 sorry
6. Route-B: add more targets (e.g., OctetsRoundtrip, Varint)
