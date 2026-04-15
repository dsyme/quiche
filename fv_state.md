# FV State Snapshot

Last updated: 2026-04-15 (run 71, workflow 24448360185)

## Lean File Registry

| File | Theorems | Examples | Status |
|------|----------|----------|--------|
| FVSquad/Varint.lean | 10 | 25 | ✅ |
| FVSquad/RangeSet.lean | 28 | 15 | ✅ |
| FVSquad/Minmax.lean | 16 | 6 | ✅ |
| FVSquad/RttStats.lean | 23 | 2 | ✅ |
| FVSquad/FlowControl.lean | 22 | 1 | ✅ |
| FVSquad/NewReno.lean | 13 | 0 | ✅ |
| FVSquad/DatagramQueue.lean | 28 | 0 | ✅ |
| FVSquad/PRR.lean | 20 | 0 | ✅ |
| FVSquad/PacketNumDecode.lean | 23 | 0 | ✅ |
| FVSquad/Cubic.lean | 26 | 0 | ✅ |
| FVSquad/RangeBuf.lean | 20 | 5 | ✅ |
| FVSquad/RecvBuf.lean | 59 | 17 | ✅ (run61 insertAny) |
| FVSquad/SendBuf.lean | 26 | 11 | ✅ |
| FVSquad/CidMgmt.lean | 21 | 13 | ✅ |
| FVSquad/StreamPriorityKey.lean | 21 | 8 | ✅ |
| FVSquad/OctetsMut.lean | 33 | 7 | ✅ |
| FVSquad/Octets.lean | 54 | 9 | ✅ |
| FVSquad/StreamId.lean | 37 | 8 | ✅ run64 |
| FVSquad/OctetsRoundtrip.lean | 22 | 9 | ✅ run65 |
| FVSquad/PacketNumLen.lean | 21 | 10 | ✅ run66 |
| FVSquad/SendBufRetransmit.lean | 17 | 10 | ✅ run68 (from PR #55 extract) |
| FVSquad/VarIntRoundtrip.lean | 15 | 11 | ✅ run71 (Target 23) |
| **TOTAL** | **555** | **171** | **✅ 0 sorry** |

## FV Targets

| Target | Description | Phase | File | Notes |
|--------|-------------|-------|------|-------|
| T1 | Varint encode/decode | 5 | Varint.lean | |
| T2 | RangeSet operations | 5 | RangeSet.lean | |
| T3 | Minmax invariants | 5 | Minmax.lean | |
| T4 | RTT stats | 5 | RttStats.lean | |
| T5 | Flow control | 5 | FlowControl.lean | |
| T6 | NewReno | 5 | NewReno.lean | |
| T7 | DatagramQueue | 5 | DatagramQueue.lean | |
| T8 | PRR | 5 | PRR.lean | |
| T9 | PacketNumDecode | 5 | PacketNumDecode.lean | |
| T10 | Cubic | 5 | Cubic.lean | |
| T11 | RangeBuf | 5 | RangeBuf.lean | |
| T12 | RecvBuf | 5 | RecvBuf.lean | OQ-1 finding |
| T13 | SendBuf | 5 | SendBuf.lean | |
| T14 | CidMgmt | 5 | CidMgmt.lean | |
| T15 | StreamPriorityKey | 5 | StreamPriorityKey.lean | |
| T16 | OctetsMut | 5 | OctetsMut.lean | |
| T17 | Octets | 5 | Octets.lean | |
| T18 | StreamId | 5 | StreamId.lean | |
| T19 | OctetsRoundtrip | 5 | OctetsRoundtrip.lean | |
| T20 | PacketNumLen | 5 | PacketNumLen.lean | |
| T21 | SendBufRetransmit | 5 | SendBufRetransmit.lean | |
| T23 | VarIntRoundtrip | 5 | VarIntRoundtrip.lean | put_varint→get_varint |

## Open PRs (lean-squad label)

- PR run71 (branch lean-squad-run71-24448360185-varint-roundtrip-critique): VarIntRoundtrip.lean + SendBufRetransmit.lean + CRITIQUE update — just created
- Note: PR #55 (run68 SendBufRetransmit) had conflicts; content extracted manually to run71 PR
- Note: PR #53 (run66 PacketNumLen) merged cleanly into run71 branch
- Note: PR #54 (run67 CRITIQUE) merged cleanly into run71 branch

## Key Findings

- OQ-1: StreamPriorityKey antisymmetry violation (intentional by design)

## Next Priority Targets

1. encode_pkt_num → decode_pkt_num composition (closes packet-number lifecycle)
2. RecvBuf flow-control enforcement (highMark ≤ max_data)
3. Multi-field frame encoding (two varints back-to-back)
4. SendBuf retransmit-then-ACK composition
