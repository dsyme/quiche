# FV State Snapshot

Last updated: 2026-04-17 (run 76, workflow 24546795657)

## Lean File Registry (verified by grep)

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
| FVSquad/VarIntRoundtrip.lean | ~18 | 15 | Phase 3 (2 sorry: 8-byte case) |
| FVSquad/PacketNumEncodeDecode.lean | 10 | 23 | Phase 5 (0 sorry, run 76) |
| **TOTAL** | **~514** | **~194** | **2 sorry (8-byte roundtrip in VarIntRoundtrip)** |

## FV Targets

| Target | Description | Phase | File | Notes |
|--------|-------------|-------|------|-------|
| T1-T21 | (all complete) | 5 | various | 486 theorems total, 0 sorry |
| T22 | RecvBuf flow-control bound | 0 | — | identified |
| T23 | put_varint→get_varint roundtrip | 3 | FVSquad/VarIntRoundtrip.lean | run75: 1/2/4-byte proved; 8-byte sorry (need putU32_bytes_unchanged); Correspondence entry added run76 |
| T24 | encode→decode composition | 5 | FVSquad/PacketNumEncodeDecode.lean | run76: 10 theorems 0 sorry; bridges T9(PacketNumDecode) + T20(PacketNumLen); Correspondence entry added |
| T25 | StreamId↔stream_do_send guard | 0 | — | identified |
| T26 | CUBIC Reno-friendly transition | 0 | — | MEDIUM |
| T27 | CidMgmt retire_if_needed | 0 | — | MEDIUM |
| T28 | NewReno AIMD convergence | 0 | — | MEDIUM |
| T29 | QUIC packet-header roundtrip | 2 | specs/packet_header_informal.md | run73 informal spec |
| T30 | Varint 2-bit tag consistency | 0 | — | HIGH/LOW-effort |

## Open PRs (lean-squad label)

- PR run76 (branch lean-squad-run76-24546795657-t24-pktnum-encode-decode-correspondence):
  Task 3 — T24 PacketNumEncodeDecode.lean (10 theorems, 0 sorry) + Task 6 — CORRESPONDENCE.md T22/T23 entries

## Next Actions

1. T23 phase 4→5: add `putU32_bytes_unchanged` to OctetsMut.lean, then prove 8-byte case
2. T22 phase 1-3: RecvBuf flow-control bound (identified only — needs informal spec and Lean file)
3. T29 phase 3: write Lean spec for QUIC packet header roundtrip (informal spec exists)
4. T30 phase 1-3: varint 2-bit tag consistency (LOW effort, uses existing Varint.lean)
