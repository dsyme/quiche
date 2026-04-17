# FV State Snapshot

Last updated: 2026-04-17 (run 77, workflow 24559290219)

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
| FVSquad/OctetsRoundtrip.lean | 21 | 9 | Done |
| FVSquad/StreamId.lean | 35 | 8 | Done |
| FVSquad/PacketNumLen.lean | 20 | 10 | Done |
| FVSquad/SendBufRetransmit.lean | 17 | 10 | Done |
| FVSquad/VarIntRoundtrip.lean | 20 | 15 | Phase 5 (0 sorry — run 77 eliminated 8-byte case) |
| FVSquad/PacketNumEncodeDecode.lean | 10 | 23 | Phase 5 (0 sorry, run 76) |
| FVSquad/PacketHeader.lean | 12 | 18 | Phase 3 (0 sorry — new in run 77) |
| **TOTAL** | **~526** | **~212** | **0 sorry** |

## FV Targets

| Target | Description | Phase | File | Notes |
|--------|-------------|-------|------|-------|
| T1-T21 | (all complete) | 5 | various | 486 theorems total, 0 sorry |
| T22 | RecvBuf flow-control bound | 0 | — | identified |
| T23 | put_varint→get_varint roundtrip | 5 | FVSquad/VarIntRoundtrip.lean | run77: all 4 widths proved, 0 sorry; putU32_bytes_below added to OctetsRoundtrip |
| T24 | encode→decode composition | 5 | FVSquad/PacketNumEncodeDecode.lean | run76: 10 theorems 0 sorry |
| T25 | StreamId↔stream_do_send guard | 0 | — | identified |
| T26 | CUBIC Reno-friendly transition | 0 | — | MEDIUM |
| T27 | CidMgmt retire_if_needed | 0 | — | MEDIUM |
| T28 | NewReno AIMD convergence | 0 | — | MEDIUM |
| T29 | QUIC packet-header first-byte encoding | 3 | FVSquad/PacketHeader.lean | run77: 12 theorems 18 examples 0 sorry; encode_decode_type_long roundtrip proved |
| T30 | Varint 2-bit tag consistency | 0 | — | HIGH/LOW-effort |

## Open PRs (lean-squad label)

- PR run77 (branch lean-squad-run77-24559290219-varint-8byte-packet-header):
  Task 5 — T23 VarInt 8-byte sorry elimination (0 sorry now across all roundtrip widths)
  Task 3 — T29 PacketHeader.lean (12 theorems, 18 examples, 0 sorry)
  CORRESPONDENCE.md: updated Last Updated + T29 section added

## Next Actions

1. T22 phase 1-3: RecvBuf flow-control bound (identified only — needs informal spec and Lean file)
2. T29 phase 3→4: implement Lean model of full first-byte parse from raw byte
3. T25 phase 1: StreamId↔stream_do_send guard — high-value safety property
4. T30 phase 1-3: varint 2-bit tag consistency (LOW effort, uses existing Varint.lean)
