# Lean Squad Memory -- dsyme/quiche

Last updated: 2026-04-25 (run 101)
Lean toolchain: leanprover/lean4:v4.29.0 (lean-toolchain file); elan installs v4.30.0-rc2 (stable)
Lake project: formal-verification/lean/
FVSquad.lean: import manifest for all 29 modules

## FV Targets

| # | Name | File | Phase | Status |
|---|------|------|-------|--------|
| 1-21 | (various done targets) | various | 5 | All Done (see prior runs)
| 23 | put_varint→get_varint roundtrip | octets/src/lib.rs | 5 | Done (10 thms, 0 sorry) |
| 24 | encode_pkt_num→decode_pkt_num | quiche/src/packet.rs | 5 | Done (10 thms, 0 sorry) |
| 29 | QUIC packet-header first-byte | quiche/src/packet.rs | 4 | 14 thms, 1 sorry |
| 30 | Varint 2-bit tag consistency | octets/src/lib.rs | 5 | Done run85 (15 thms, 0 sorry) |
| 31 | H3 frame type codec round-trip | quiche/src/h3/frame.rs | 5 | Done run99 (19 thms, 0 sorry) |
| 32 | BBR2 pacing rate bounds | quiche/src/recovery/gcongestion/bbr2.rs | 0 | MEDIUM |
| 33 | H3 Settings frame invariants | quiche/src/h3/frame.rs | 2 | Informal spec done (run86) |
| 36 | Bandwidth arithmetic invariants | quiche/src/recovery/bandwidth.rs | 5 | Done run90 (22 thms, 0 sorry); Route-B 25/25 PASS |
| 37 | BytesInFlight counter invariant | quiche/src/recovery/bytes_in_flight.rs | 1 | ~50 lines, MEDIUM |
| 38 | PathState monotone progression | quiche/src/path.rs | 1 | RFC 9000 §8.2; ~45 lines; MEDIUM |
| 39 | QPACK lookup_static bounds | quiche/src/h3/qpack/ | 5 | Done run97 (12 thms, 0 sorry) |
| 40 | QPACK decode_int prefix-mask | quiche/src/h3/qpack/decoder.rs | 1 | fuel model; ~50 lines; MEDIUM |
| 41 | Pacer pacing_rate cap | quiche/src/recovery/gcongestion/pacer.rs | 5 | Done run98 (17 thms, 0 sorry) |
| 42 | Frame ack_eliciting/probing | quiche/src/frame.rs | 5 | Done run97 (25 thms, 0 sorry) |
| 43 | ACK frame acked-range bounds | quiche/src/frame.rs | 3 | run101 (29 items, 3 sorry) — in open PR run101 |

## Lean File Registry (verified lake build v4.30.0-rc2, run 101)

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
| FVSquad/OctetsRoundtrip.lean | 20 | Done |
| FVSquad/StreamId.lean | 35 | Done |
| FVSquad/PacketNumLen.lean | 20 | Done |
| FVSquad/SendBufRetransmit.lean | 17 | Done |
| FVSquad/VarIntRoundtrip.lean | 8 | Done (0 sorry) |
| FVSquad/PacketNumEncodeDecode.lean | 10 | Done |
| FVSquad/PacketHeader.lean | 14 | 1 sorry (full RT deferred) |
| FVSquad/VarIntTag.lean | 15 | Done (run 85) |
| FVSquad/Bandwidth.lean | 22 | Done (run 90) |
| FVSquad/Pacer.lean | 17 | Done (run 98) |
| FVSquad/H3Frame.lean | 19 | Done (run 99) |
| FVSquad/AckRanges.lean | 29 | 3 sorry (loop invariant proofs) run101 |
| **TOTAL** | **620** | **4 sorry** |

## Open Sorry Obligations

| Theorem | File | Blocking gap |
|---------|------|-------------|
| longHeader_roundtrip | PacketHeader.lean | Full buffer model (byte-list encode/decode) |
| decodeAckBlocks_first_valid | AckRanges.lean | Head-of-reversed-list identity after loop |
| decodeAckBlocks_all_valid | AckRanges.lean | Loop invariant: acc entries have sm ≤ lg |
| decodeAckBlocks_bounded | AckRanges.lean | Loop invariant: acc entries have lg ≤ la |

## Route-B Correspondence Tests

| Target | Directory | Run | Cases | Result |
|--------|-----------|-----|-------|--------|
| T20 (PacketNumLen) | tests/pkt_num_len/ | 89 | 18 | 18/18 PASS |
| T36 (Bandwidth) | tests/bandwidth_arithmetic/ | 90/94 | 25 | 25/25 PASS |
| T2 (RangeSet) | tests/rangeset_insert/ | 96 | 21 | 21/21 PASS |

## CI Status

- lean-ci.yml: exists, working, path-triggered on formal-verification/lean/**

## Open PRs (lean-squad label)

- PR run101 (branch lean-squad-run101-24921786154-ack-ranges-correspondence):
  Task 5 — T43 AckRanges.lean (29 items, 3 sorry)
  Task 6 — CORRESPONDENCE.md updated with T43 section

## Status Issue

Issue #4 (open)

## Key Findings

- OQ-1 (run49): StreamPriorityKey antisymmetry violation (intentional by design)
- OQ-RT-1 (run68): zero-length retransmit with off > ackOff may not be no-op
- OQ-FC-1 (run70): RESET_STREAM guard in RecvBuf not modelled
- decode_pktnum_correct spec refinement (run39): non-strict bound counterexample found
- OQ-T43-2 (run100): uncapped block_count in parse_ack_frame — potential DoS vector

## Next Actions

1. T43: close 3 remaining sorry (loop invariant for all_valid, bounded, first_valid)
2. T33: write FVSquad/H3Settings.lean (Settings invariants)
3. T29: extend PacketHeader.lean with full byte-list model → closes 1 sorry
4. Route-B: add T43 correspondence tests
