# FV State Snapshot

Last updated: 2026-04-16 (run 73, workflow 24491238828)

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
| T26 | CUBIC Reno-friendly transition | 0 | — | MEDIUM |
| T27 | CidMgmt retire_if_needed | 0 | — | MEDIUM |
| T28 | NewReno AIMD convergence | 0 | — | MEDIUM |
| T29 | QUIC packet-header roundtrip | 2 | specs/packet_header_informal.md | run73 informal spec |
| T30 | Varint 2-bit tag consistency | 0 | — | HIGH/LOW-effort |

## Open PRs (lean-squad label)

- PR run73 (branch lean-squad-run73-24491238828-informal-spec-ci-audit):
  Task 2+9 — PacketHeader informal spec (T29) + CI audit — just created

## Key Findings

- OQ-1: StreamPriorityKey antisymmetry violation (intentional by design)
- OQ-RT-1: zero-length retransmit with off > ackOff may not be a no-op
- OQ-T29-1/2/3: Token None asymmetry, CID validation asymmetry, pkt_num partial roundtrip

## CORRESPONDENCE.md Status (run73)

All 21 Lean files covered. No mismatches identified.
