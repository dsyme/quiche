# FV State Snapshot

Last updated: 2026-04-18 (run 81, workflow 24601813049)

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

## Open Sorry Obligations (confirmed lake build run81)

| Theorem | File | Blocking gap |
|---------|------|-------------|
| putVarint_freeze_getVarint_8byte | VarIntRoundtrip.lean | putU32_bytes_unchanged in OctetsMut.lean |
| putVarint_first_byte_tag (8-byte) | VarIntRoundtrip.lean | Same |
| longHeader_roundtrip | PacketHeader.lean | Full buffer model needed |

## FV Targets

| Target | Description | Phase | File | Notes |
|--------|-------------|-------|------|-------|
| T1-T21 | (all complete) | 5 | various | Phase 5 done |
| T22 | RecvBuf flow-control bound | 0 | — | identified |
| T23 | put_varint→get_varint roundtrip | 5 | FVSquad/VarIntRoundtrip.lean | 2 sorry (8-byte) |
| T24 | encode→decode composition | 5 | FVSquad/PacketNumEncodeDecode.lean | DONE |
| T29 | QUIC packet-header first-byte | 4 | FVSquad/PacketHeader.lean | 14 thms, 1 sorry |
| T30 | Varint 2-bit tag consistency | 0 | — | HIGH/LOW-effort, next |
| T31 | H3 frame type codec round-trip | 0 | — | HIGH |
| T32 | BBR2 pacing rate bounds | 0 | — | MEDIUM |
| T33 | H3 Settings frame invariants | 0 | — | MEDIUM |

## Open PRs (lean-squad label)

- PR run81 (branch lean-squad-run81-24601813049-packet-header-report):
  Task 3 — PacketHeader.lean (T29) + Task 10 REPORT.md update

## Next Actions

1. Add putU32_bytes_unchanged to OctetsMut.lean → closes 2 sorry VarIntRoundtrip
2. T29: extend PacketHeader.lean with full byte-list encode/decode model
3. T30: write Lean spec for varint 2-bit tag consistency (LOW effort, HIGH value)
4. T31: write informal spec for H3 frame type codec
