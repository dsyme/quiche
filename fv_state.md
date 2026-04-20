# FV State Snapshot

Last updated: 2026-04-20 (run 86, workflow 24647797791)

## Lean File Registry (verified by lake build Lean 4.29.0)

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
| FVSquad/VarIntTag.lean | 15 | 11 | Done (run 85) |
| **TOTAL** | **533** | **198** | **3 sorry** |

## FV Targets

| Target | Description | Phase | File | Notes |
|--------|-------------|-------|------|-------|
| T1-T24 | (all complete) | 5 | various | Phase 5 done |
| T29 | QUIC packet-header first-byte | 4 | FVSquad/PacketHeader.lean | 14 thms, 1 sorry |
| T30 | Varint 2-bit tag consistency | 5 | FVSquad/VarIntTag.lean | DONE run 85, 15 thms, 0 sorry |
| T31 | H3 frame type codec round-trip | 2 | specs/h3_frame_informal.md | Informal spec (run82) |
| T32 | BBR2 pacing rate bounds | 0 | — | MEDIUM |
| T33 | H3 Settings frame invariants | 2 | specs/h3_settings_informal.md | Informal spec (run86), 4 OQs |

## Open PRs (lean-squad label)

- run86 PR (branch lean-squad-run86-24647797791-report-h3settings):
  Task 2 — H3Settings informal spec T33 (phase 2)
  Task 10 — REPORT update (533 theorems, 25 files)

## Next Actions

1. T31: write FVSquad/H3Frame.lean (GoAway/MaxPushId/CancelPush round-trips) — Task 3
2. T33: write FVSquad/H3Settings.lean (Settings invariants) — Task 3
3. Add putU32_bytes_unchanged to OctetsMut.lean → closes 2 sorry VarIntRoundtrip
4. T29: extend PacketHeader.lean with full byte-list model → closes 1 sorry
5. paper/paper.tex: update theorem count 518→533, add VarIntTag.lean row, add T33 row
6. Task 8 (Aeneas): needs opam (sudo apt-get); retry on non-sandboxed runner
