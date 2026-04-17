# FV State Snapshot

Last updated: 2026-04-17 (run 78, workflow 24578215430)

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
| FVSquad/VarIntRoundtrip.lean | 8 | 16 | Done (run 75-77, 0 sorry) |
| FVSquad/PacketNumEncodeDecode.lean | 10 | 23 | Done (run 76, 0 sorry) |
| **TOTAL** | **504** | **175** | **0 sorry** |

## FV Targets

| Target | Description | Phase | File | Notes |
|--------|-------------|-------|------|-------|
| T1-T21 | (all complete) | 5 | various | Phase 5 done |
| T22 | RecvBuf flow-control bound | 0 | — | identified |
| T23 | put_varint→get_varint roundtrip | 5 | FVSquad/VarIntRoundtrip.lean | DONE run77: 8 theorems 0 sorry |
| T24 | encode→decode composition | 5 | FVSquad/PacketNumEncodeDecode.lean | DONE run76: 10 theorems 0 sorry |
| T25 | StreamId↔stream_do_send guard | 0 | — | identified |
| T26 | CUBIC Reno-friendly transition | 0 | — | MEDIUM |
| T27 | CidMgmt retire_if_needed | 0 | — | MEDIUM |
| T28 | NewReno AIMD convergence | 0 | — | MEDIUM |
| T29 | QUIC packet-header first-byte encoding | 2 | — | informal spec exists; Phase 3 next |
| T30 | Varint 2-bit tag consistency | 0 | — | HIGH/LOW-effort |
| T31 | H3 frame type codec round-trip | 0 | — | NEW run78: quiche/src/h3/frame.rs |
| T32 | BBR2 pacing rate bounds | 0 | — | NEW run78: gcongestion/bbr2.rs |
| T33 | H3 Settings frame invariants | 0 | — | NEW run78: RFC 9114 §7.2.4 |

## Open PRs (lean-squad label)

- PR run78 (branch lean-squad-run78-24578215430-paper-research):
  Task 11 — Conference paper (paper.tex + paper.bib)
  Task 1 — T31/T32/T33 new targets + RESEARCH.md/TARGETS.md updates

## Conference Paper

Created: formal-verification/paper/paper.tex
  - ACM sigconf format, ~9 pages
  - Reports 504 theorems, 23 files, 0 sorry
  - Three findings: OQ-1, RFC 9000 §A.3 gap, OQ-RT-1
  - Tikz proof architecture diagram
  - PDF not compiled (LaTeX unavailable in CI container)
- formal-verification/paper/paper.bib (18 entries)

## Next Actions

1. T29 phase 3: write Lean spec for QUIC packet-header (PacketHeader.lean)
2. T30 phase 1-3: varint 2-bit tag consistency (LOW effort)
3. T22 phase 2-3: RecvBuf flow-control bound
4. T31 phase 2: informal spec for H3 frame round-trip
5. Compile paper.pdf once LaTeX is available
