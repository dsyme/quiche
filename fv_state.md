# FV State Snapshot

Last updated: 2026-04-18 (run 79, workflow 24596073436)

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
| FVSquad/VarIntRoundtrip.lean | 8 | 16 | 2 sorry (8-byte varint case) |
| FVSquad/PacketNumEncodeDecode.lean | 10 | 23 | Done (0 sorry) |
| **TOTAL** | **504** | **175** | **2 sorry** (VarIntRoundtrip.lean) |

## Open Sorry Obligations (confirmed by lake build run 79)

| Theorem | File | Lines | Blocking gap |
|---------|------|-------|-------------|
| putVarint_freeze_getVarint_8byte | VarIntRoundtrip.lean | 244–251 | putU32_bytes_unchanged in OctetsMut.lean |
| putVarint_first_byte_tag (8-byte branch) | VarIntRoundtrip.lean | 375–418 | Same |

Fix: add putU32_bytes_unchanged lemma to OctetsMut.lean (or OctetsRoundtrip.lean).
This is a non-interference lemma: "writing a u32 at buffer offset k+4 does not
modify bytes at positions k..k+3".

## FV Targets

| Target | Description | Phase | File | Notes |
|--------|-------------|-------|------|-------|
| T1-T21 | (all complete) | 5 | various | Phase 5 done |
| T22 | RecvBuf flow-control bound | 0 | — | identified |
| T23 | put_varint→get_varint roundtrip | 5 | FVSquad/VarIntRoundtrip.lean | 8 theorems, 2 sorry (8-byte) |
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

- PR run78 (branch lean-squad-run78-24578215430-paper-research-e187acd3c26faf23):
  Task 11 — Conference paper (paper.tex + paper.bib) + Task 1 T31/T32/T33
- PR run79 (branch lean-squad-run79-24596073436-correspondence-paper):
  Task 6 — CORRESPONDENCE.md update (2 sorry found + Open Sorry Obligations section)
  Task 11 — paper.tex accuracy (corrected 0 sorry → 2 sorry claims)
  REPORT.md: status header + file inventory updated to 504/175/2sorry/23 files

## Conference Paper

Created: formal-verification/paper/paper.tex (updated run79)
  - ACM sigconf format
  - Reports 504 theorems, 502 sorry-free (2 sorry for 8-byte varint case)
  - Three findings: OQ-1, RFC 9000 §A.3 gap, OQ-RT-1
  - PDF not compiled (LaTeX unavailable in CI container)
- formal-verification/paper/paper.bib (18 entries)

## Next Actions

1. Add putU32_bytes_unchanged to OctetsMut.lean → closes 2 sorry in VarIntRoundtrip.lean
2. T29 phase 3: write Lean spec for QUIC packet-header (PacketHeader.lean)
3. T30 phase 1-3: varint 2-bit tag consistency (LOW effort, HIGH value)
4. T22 phase 2-3: RecvBuf flow-control bound
5. T31 phase 2: informal spec for H3 frame round-trip
