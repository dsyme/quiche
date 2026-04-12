# FV State Snapshot

Last updated: 2026-04-12 (run 63, workflow 24311908193)

## Lean File Registry

| File | Theorems | Examples | Status |
|------|----------|----------|--------|
| FVSquad/Varint.lean | 10 | 25 | ✅ |
| FVSquad/RangeSet.lean | 16 | 15 | ✅ |
| FVSquad/Minmax.lean | 15 | 6 | ✅ |
| FVSquad/RttStats.lean | 23 | 2 | ✅ |
| FVSquad/FlowControl.lean | 22 | 1 | ✅ |
| FVSquad/NewReno.lean | 13 | 0 | ✅ |
| FVSquad/DatagramQueue.lean | 26 | 0 | ✅ |
| FVSquad/PRR.lean | 20 | 0 | ✅ |
| FVSquad/PacketNumDecode.lean | 23 | 0 | ✅ |
| FVSquad/Cubic.lean | 26 | 0 | ✅ |
| FVSquad/RangeBuf.lean | 19 | 5 | ✅ |
| FVSquad/RecvBuf.lean | 38 | 17 | ✅ (run61+62 insertAny) |
| FVSquad/SendBuf.lean | 26 | 11 | ✅ |
| FVSquad/CidMgmt.lean | 21 | 13 | ✅ |
| FVSquad/StreamPriorityKey.lean | 21 | 8 | ✅ |
| FVSquad/OctetsMut.lean | 27 | 7 | ✅ (run63: fixed split_ifs) |
| FVSquad/Octets.lean | 48 | 9 | ✅ run62 |
| **TOTAL** | **394** | **119** | **✅ 0 sorry** |

Note: private/helper theorems add ~49 more checked declarations.

## Open PRs (lean-squad label)

- PR #48: RecvBuf insertAny (run61, open)
- PR #49: Octets read-only (run62, open)
- PR run63: OctetsMut fix + REPORT.md (just created)

## Branch

Current work: lean-squad-run63-24311908193-octets-mut-fix-report
