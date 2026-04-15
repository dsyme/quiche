# FV State Snapshot

Last updated: 2026-04-15 (run 72, workflow 24469336185)

## Lean File Registry

| File | Theorems | Examples | Status |
|------|----------|----------|--------|
| FVSquad/Varint.lean | 10 | 25 | Done |
| FVSquad/RangeSet.lean | 28 | 15 | Done |
| FVSquad/Minmax.lean | 16 | 6 | Done |
| FVSquad/RttStats.lean | 23 | 2 | Done |
| FVSquad/FlowControl.lean | 22 | 1 | Done |
| FVSquad/NewReno.lean | 13 | 0 | Done |
| FVSquad/DatagramQueue.lean | 28 | 0 | Done |
| FVSquad/PRR.lean | 20 | 0 | Done |
| FVSquad/PacketNumDecode.lean | 23 | 0 | Done |
| FVSquad/Cubic.lean | 26 | 0 | Done |
| FVSquad/RangeBuf.lean | 20 | 5 | Done |
| FVSquad/RecvBuf.lean | 59 | 17 | Done |
| FVSquad/SendBuf.lean | 26 | 11 | Done |
| FVSquad/CidMgmt.lean | 21 | 13 | Done |
| FVSquad/StreamPriorityKey.lean | 21 | 8 | Done |
| FVSquad/OctetsMut.lean | 33 | 7 | Done |
| FVSquad/Octets.lean | 54 | 9 | Done |
| FVSquad/StreamId.lean | 37 | 8 | Done |
| FVSquad/OctetsRoundtrip.lean | 22 | 9 | Done |
| FVSquad/PacketNumLen.lean | 21 | 10 | Done |
| FVSquad/SendBufRetransmit.lean | 17 | 10 | Done |
| **TOTAL** | **521** | **156** | **0 sorry** |

## FV Targets

| Target | Description | Phase | File | Notes |
|--------|-------------|-------|------|-------|
| T1-T21 | (all complete) | 5 | various | 521 theorems total, 0 sorry |
| T22 | RecvBuf flow-control bound | 0 | — | identified |
| T23 | put_varint→get_varint roundtrip | 0 | — | HIGH priority |
| T24 | encode→decode composition | 0 | — | identified |
| T25 | StreamId↔stream_do_send guard | 0 | — | identified |
| T26 | CUBIC Reno-friendly transition | 0 | — | run72 MEDIUM |
| T27 | CidMgmt retire_if_needed | 0 | — | run72 MEDIUM |
| T28 | NewReno AIMD convergence | 0 | — | run72 MEDIUM |
| T29 | QUIC packet-header roundtrip | 0 | — | run72 HIGHEST |
| T30 | Varint 2-bit tag consistency | 0 | — | run72 HIGH/LOW-effort |

## Open PRs (lean-squad label)

- PR run72 (branch lean-squad-run72-24469336185-research-correspondence): Research T26-30 + Correspondence T16,T18-T21 — just created

## Key Findings

- OQ-1: StreamPriorityKey antisymmetry violation (intentional by design)
- OQ-RT-1: zero-length retransmit with off > ackOff may not be a no-op

## CORRESPONDENCE.md Status (run72)

All 21 Lean files now covered.
Added in run72: T16, T18, T19, T20, T21.
No mismatches identified.
