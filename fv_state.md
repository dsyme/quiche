# FV State Snapshot

Last updated: 2026-04-19 (run 84, workflow 24625876108)

## Lean File Registry (verified by lake build Lean 4.29.1)

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
| **TOTAL** | **518** | **187** | **3 sorry** |

## FV Targets

| Target | Description | Phase | File | Notes |
|--------|-------------|-------|------|-------|
| T1-T21 | (all complete) | 5 | various | Phase 5 done |
| T22 | RecvBuf flow-control bound | 0 | — | identified |
| T23 | put_varint→get_varint roundtrip | 5 | FVSquad/VarIntRoundtrip.lean | 2 sorry (8-byte) |
| T24 | encode→decode composition | 5 | FVSquad/PacketNumEncodeDecode.lean | DONE |
| T29 | QUIC packet-header first-byte | 4 | FVSquad/PacketHeader.lean | 14 thms, 1 sorry |
| T30 | Varint 2-bit tag consistency | 2 | specs/varint_tag_informal.md | Informal spec (run83); critique (run84) |
| T31 | H3 frame type codec round-trip | 2 | specs/h3_frame_informal.md | Informal spec (run82); critique (run84) |
| T32 | BBR2 pacing rate bounds | 0 | — | MEDIUM |
| T33 | H3 Settings frame invariants | 0 | — | MEDIUM |

## Open PRs (lean-squad label)

- PR run84 (branch lean-squad-run84-24625876108-critique-report):
  Task 7 — CRITIQUE.md T30/T31 assessment + Paper Review
  Task 10 — REPORT.md update (run 84)

## Next Actions

1. T30: write FVSquad/VarIntTag.lean (~120 lines, all omega proofs) — Task 3
2. T31: write FVSquad/H3Frame.lean (GoAway/MaxPushId/CancelPush round-trips) — Task 3
3. Add putU32_bytes_unchanged to OctetsMut.lean → closes 2 sorry VarIntRoundtrip
4. T29: extend PacketHeader.lean with full byte-list encode/decode model
5. Update paper.tex: fix stale counts, add PacketHeader row, add encode_decode_pktnum finding
