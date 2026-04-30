# Lean Squad Memory -- dsyme/quiche

Last updated: 2026-04-30 (run 116)
Lean toolchain: leanprover/lean4:v4.29.0 (lean-toolchain file); elan installs v4.30.0-rc2 (stable)
Lake project: formal-verification/lean/
FVSquad.lean: import manifest for all 34 modules

## FV Targets

| # | Name | File | Phase | Status |
|---|------|------|-------|--------|
| 1-21 | (various done targets) | various | 5 | All Done (see prior runs) |
| 23 | put_varint→get_varint roundtrip | octets/src/lib.rs | 5 | Done (10 thms, 0 sorry) |
| 24 | encode_pkt_num→decode_pkt_num | quiche/src/packet.rs | 5 | Done (10 thms, 0 sorry) |
| 29 | QUIC packet-header first-byte + full roundtrip | quiche/src/packet.rs | 5 | Done run105 (14 thms, 0 sorry) |
| 30 | Varint 2-bit tag consistency | octets/src/lib.rs | 5 | Done run85 (15 thms, 0 sorry) |
| 31 | H3 frame type codec round-trip | quiche/src/h3/frame.rs | 5 | Done run99/100 (19 thms, 0 sorry); Route-B 25/25 PASS run103 |
| 32 | BBR2 Limits struct invariants | quiche/src/recovery/gcongestion/bbr2.rs | 5 | Done run113 (14 thms, 0 sorry) |
| 33 | H3 Settings frame invariants | quiche/src/h3/frame.rs | 5 | Done run114 (20 thms, 0 sorry) |
| 34 | QPACK static table lookup | quiche/src/h3/qpack/ | 1 | Researched (run87); ~30 lines, all decide |
| 35 | parse_settings_frame RFC compliance | quiche/src/h3/frame.rs | 5 | Done run116 (21 thms, 0 sorry) |
| 36 | Bandwidth arithmetic invariants | quiche/src/recovery/bandwidth.rs | 5 | Done run90 (22 thms, 0 sorry); Route-B 25/25 PASS |
| 37 | BytesInFlight counter invariant | quiche/src/recovery/bytes_in_flight.rs | 5 | Done run107 (17 thms, 0 sorry); Route-B 25/25 PASS run112 |
| 38 | PathState monotone progression | quiche/src/path.rs | 5 | Done run109 (24 thms, 0 sorry) |
| 39 | QPACK lookup_static bounds | quiche/src/h3/qpack/ | 1 | Researched run87; file not confirmed in repo |
| 40 | QPACK decode_int prefix-mask | quiche/src/h3/qpack/decoder.rs | 1 | Researched run111; file not confirmed in repo |
| 41 | Pacer pacing_rate cap | quiche/src/recovery/gcongestion/pacer.rs | 5 | Done run98 (16 thms, 0 sorry) |
| 42 | Frame ack_eliciting/probing | quiche/src/frame.rs | 5 | Done run97 (25 thms, 0 sorry) — file not confirmed |
| 43 | ACK frame acked-range bounds | quiche/src/frame.rs | 5 | Done run102 (13 thms, 0 sorry); Route-B 25/25 PASS |

## MILESTONE: 34 Lean files confirmed in repo, ~696 theorems, 0 sorry (run 116)

NOTE: T39/T40/T42 memory shows Done but Lean files NOT present in repo.
Future run should re-create these files.

## Lean File Registry (confirmed in repo as of run 116)

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
| FVSquad/PacketHeader.lean | 14 | Done run105 |
| FVSquad/VarIntTag.lean | 15 | Done run85 |
| FVSquad/Bandwidth.lean | 22 | Done run90 |
| FVSquad/Pacer.lean | 16 | Done run98 |
| FVSquad/H3Frame.lean | 19 | Done run99/100 |
| FVSquad/AckRanges.lean | 13 | Done run102 |
| FVSquad/BytesInFlight.lean | 17 | Done run107 |
| FVSquad/PathState.lean | 24 | Done run109 |
| FVSquad/BBR2Limits.lean | 14 | Done run113 |
| FVSquad/H3Settings.lean | 20 | Done run114 |
| FVSquad/H3ParseSettings.lean | 21 | Done run116 |
| **TOTAL** | **~696** | **0 sorry** 🎉 |

## Route-B Correspondence Tests

| Target | Directory | Run | Cases | Result |
|--------|-----------|-----|-------|--------|
| T20 (PacketNumLen) | tests/pkt_num_len/ | 89 | 18 | 18/18 PASS |
| T36 (Bandwidth) | tests/bandwidth_arithmetic/ | 90/94 | 25 | 25/25 PASS |
| T2 (RangeSet) | tests/rangeset_insert/ | 96 | 21 | 21/21 PASS |
| T43 (AckRanges) | tests/ack_ranges/ | 102 | 25 | 25/25 PASS |
| T31 (H3Frame) | tests/h3_frame/ | 103 | 25 | 25/25 PASS |
| T37 (BytesInFlight) | tests/bytes_in_flight/ | 112 | 25 | 25/25 PASS |

## CI Status

- lean-ci.yml: exists, healthy, path-triggered on formal-verification/lean/**

## Open PRs (lean-squad label)

- PR run115 (branch lean-squad-run115-25125450647-correspondence-informal):
  Task 6 — 17 missing correspondence entries added to CORRESPONDENCE.md
  Task 2 — T35 informal spec (parse_settings_frame RFC compliance)
- PR run116 (branch lean-squad-run116-25147228393-h3parsesettings):
  Task 3+5 — T35 H3ParseSettings.lean (21 thms, 0 sorry)

## Status Issue

Issue #4 (open) — updated run115, to update run116

## Key Findings

- OQ-1 (run49): StreamPriorityKey antisymmetry violation (intentional by design)
- OQ-RT-1 (run68): zero-length retransmit with off > ackOff may not be no-op
- OQ-FC-1 (run70): RESET_STREAM guard in RecvBuf not modelled
- decode_pktnum_correct spec refinement (run39): non-strict bound counterexample found
- OQ-T43-2 (run100): uncapped block_count in parse_ack_frame — potential DoS vector
- OQ-T37-1 (run103): clock-monotonicity not asserted in BytesInFlight.add/subtract
- OQ-T40-1 (run111): shift in decode_int not explicitly capped; relies on checked_shl

## Next Priority Targets

1. T34: write FVSquad/QPACKStaticTable.lean (~30 lines, all decide) — easiest
2. Recreate T39 (QPACKStaticTable bounds), T42 (FrameAckEliciting) — lost in unmerged PRs
3. Route-B tests for T38 (PathState) — state machine transition tests
4. RecvBuf flow-control bound: highMark ≤ max_data
