# FV State Snapshot

Last updated: 2026-04-20 (run 88, workflow 24681187441)

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
| T34 | QPACK static table lookup | 0 | — | run87 — ~30 lines, fully decidable |
| T35 | H3 parse_settings_frame RFC | 0 | — | run87 — H2-key rejection + size guard |
| T36 | Bandwidth arithmetic invariants | 0 | — | NEW run88 — gcongestion/bandwidth.rs, ~40 lines, all omega |
| T37 | BytesInFlight counter invariant | 0 | — | NEW run88 — recovery/bytes_in_flight.rs, ~50 lines |

## Open PRs (lean-squad label)

- PR #71 (run86): T33 informal spec + REPORT update — MERGED this run
- PR #72 (run87): T34/T35 research + paper.tex update — still open
- PR run88 (branch lean-squad-run88-24681187441-ci-research):
  Task 9 — CI completeness check step in lean-ci.yml
  Task 1 — Research T36/T37 new gcongestion targets + TARGETS.md T31-T37 table rows

## Next Actions

1. T31: write FVSquad/H3Frame.lean (GoAway/MaxPushId/CancelPush round-trips) — Task 3
2. T33: write FVSquad/H3Settings.lean (Settings invariants) — Task 3
3. T36: write FVSquad/Bandwidth.lean (all omega, ~40 lines) — Task 3 (very easy)
4. T34: write FVSquad/QPACKStaticTable.lean (~30 lines, all decide) — Task 3
5. Add putU32_bytes_unchanged to OctetsMut.lean → closes 2 sorry VarIntRoundtrip
6. T29: extend PacketHeader.lean with full byte-list model → closes 1 sorry
7. paper/paper.pdf: compile when LaTeX available; update REPORT.md to 37 targets
8. Task 8 (Aeneas): needs opam (sudo apt-get); retry on non-sandboxed runner
