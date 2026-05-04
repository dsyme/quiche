# Lean Squad Memory -- dsyme/quiche

Last updated: 2026-05-04 (run 129)
Lean toolchain: leanprover/lean4:v4.29.0 (lean-toolchain file); elan installs v4.29.1 (stable)
Lake project: formal-verification/lean/
FVSquad.lean: import manifest for all 40 modules

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
| 33 | H3 Settings frame invariants | quiche/src/h3/frame.rs | 5 | Done run114 (16 thms, 0 sorry); Route-B 43/43 PASS run125 |
| 34 | QPACK static table lookup | quiche/src/h3/qpack/static_table.rs | 5 | Done run119 (12 thms, 0 sorry) |
| 35 | parse_settings_frame RFC compliance | quiche/src/h3/frame.rs | 5 | Done run116 (21 thms, 0 sorry) |
| 36 | Bandwidth arithmetic invariants | quiche/src/recovery/bandwidth.rs | 5 | Done run90 (22 thms, 0 sorry); Route-B 25/25 PASS |
| 37 | BytesInFlight counter invariant | quiche/src/recovery/bytes_in_flight.rs | 5 | Done run107 (17 thms, 0 sorry); Route-B 25/25 PASS run112 |
| 38 | PathState monotone progression | quiche/src/path.rs | 5 | Done run109 (24 thms, 0 sorry); Route-B 75/75 PASS run118 |
| 41 | Pacer pacing_rate cap | quiche/src/recovery/gcongestion/pacer.rs | 5 | Done run98 (16 thms, 0 sorry) |
| 42 | Frame ack_eliciting/probing | quiche/src/frame.rs | 5 | Done run118 (15 thms, 0 sorry); Route-B 33/33 PASS run124 |
| 43 | ACK frame acked-range bounds | quiche/src/frame.rs | 5 | Done run102 (13 thms, 0 sorry); Route-B 25/25 PASS |
| 44 | QUIC stream state machine | quiche/src/stream/mod.rs | 5 | Done run120 (15 thms, 0 sorry); Route-B 46/46 PASS run123 |
| 45 | QPACK integer encode/decode | quiche/src/h3/qpack/encoder.rs + decoder.rs | 5 | Done run121 (10 thms + examples, 0 sorry); Route-B 25/25 PASS run122 |
| 46 | idle_timeout() negotiation RFC 9000 S10.1.1 | quiche/src/lib.rs:8757 | 5 | Done run128 (12 thms, 0 sorry); informal spec done |
| 47 | PMTUD binary search probe_size invariant | quiche/src/pmtud.rs | 5 | Done run129 (12 thms, 0 sorry); probe_size in [MIN_PLPMTU, max_mtu], convergence |
| 48 | HyStart++ RTT threshold clamp + CSS divisor | quiche/src/recovery/congestion/hystart.rs | 2 | Informal spec done run129; ~10 thms, omega; clamp [4ms,16ms], css_cwnd_inc monotone |

## MILESTONE: 40 Lean files, ~793 theorems, 0 sorry; Route-B 11 targets, 404 PASS

## Lean File Registry

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
| FVSquad/H3Settings.lean | 16 | Done run114 |
| FVSquad/H3ParseSettings.lean | 21 | Done run116 |
| FVSquad/FrameAckEliciting.lean | 15 | Done run118 |
| FVSquad/QPACKStaticTable.lean | 12 | Done run119 |
| FVSquad/StreamStateMachine.lean | 15 | Done run120 |
| FVSquad/QPACKInteger.lean | 10 + 9 examples | Done run121 |
| FVSquad/IdleTimeout.lean | 12 | Done run128 |
| FVSquad/Pmtud.lean | 12 | Done run129 |
| **TOTAL** | **~793** | **0 sorry** |

## Route-B Correspondence Tests

| Target | Directory | Run | Cases | Result |
|--------|-----------|-----|-------|--------|
| T20 (PacketNumLen) | tests/pkt_num_len/ | 89 | 18 | 18/18 PASS |
| T36 (Bandwidth) | tests/bandwidth_arithmetic/ | 90/94 | 25 | 25/25 PASS |
| T2 (RangeSet) | tests/rangeset_insert/ | 96 | 21 | 21/21 PASS |
| T43 (AckRanges) | tests/ack_ranges/ | 102 | 25 | 25/25 PASS |
| T31 (H3Frame) | tests/h3_frame/ | 103 | 25 | 25/25 PASS |
| T37 (BytesInFlight) | tests/bytes_in_flight/ | 112 | 25 | 25/25 PASS |
| T38 (PathState) | tests/path_state/ | 118 | 75 | 75/75 PASS |
| T45 (QPACKInteger) | tests/qpack_integer/ | 122 | 25 | 25/25 PASS |
| T44 (StreamStateMachine) | tests/stream_state_machine/ | 123 | 46 | 46/46 PASS |
| T42 (FrameAckEliciting) | tests/frame_ack_eliciting/ | 124 | 33 | 33/33 PASS |
| T33 (H3Settings) | tests/h3_settings/ | 125 | 43 | 43/43 PASS |

## Open PRs (lean-squad label)

- PR #100 (run124): Task 7+8 — CRITIQUE.md + Route-B FrameAckEliciting (33/33)
- PR #101 (run125): Task 11+8 — paper update (769 thms) + Route-B H3Settings (43/43)
- PR #102 (run126): Task 1+11 — research T46/T47 + paper future work
- PR #103 (run127): Task 2+7 — T46 idle_timeout informal spec + CRITIQUE update
- PR #104 (run128): Task 3+5+6 — IdleTimeout.lean (12 thms, 0 sorry) + CORRESPONDENCE + informal spec
- PR run129: Task 4+1 — Pmtud.lean (12 thms, 0 sorry) + HyStart++ informal spec

## Next Actions

1. T48: write FVSquad/Hystart.lean (RTT threshold clamp, css_cwnd_inc, ~10 thms, omega)
2. T47: Route-B correspondence tests for PMTUD (~10-15 test cases)
3. T46: Route-B correspondence tests for idle_timeout (~10-15 test cases)
4. Update conference paper for 40 files, 793 theorems, T47 addition
