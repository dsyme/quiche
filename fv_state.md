# FV State Snapshot

Last updated: 2026-04-21 (run 89, workflow 24703159938)

## Lean File Registry (verified by lake build Lean 4.30.0-rc2)

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

## Route-B Correspondence Tests (NEW run 89)

| Target | Directory | Cases | Result | Notes |
|--------|-----------|-------|--------|-------|
| T20 (PacketNumLen) | tests/pkt_num_len/ | 18 | 18/18 PASS | Rust bit-counting vs Lean threshold model |

Divergence documented: numUnacked=2^31 → Rust=5, Lean=4 (expected, out-of-range)

## FV Targets

| Target | Description | Phase | File | Notes |
|--------|-------------|-------|------|-------|
| T1-T24 | (all complete) | 5 | various | Phase 5 done |
| T29 | QUIC packet-header first-byte | 4 | FVSquad/PacketHeader.lean | 14 thms, 1 sorry |
| T30 | Varint 2-bit tag consistency | 5 | FVSquad/VarIntTag.lean | DONE run 85, 15 thms, 0 sorry |
| T31 | H3 frame type codec round-trip | 2 | specs/h3_frame_informal.md | Informal spec (run82) |
| T32 | BBR2 pacing rate bounds | 0 | — | MEDIUM |
| T33 | H3 Settings frame invariants | 2 | specs/h3_settings_informal.md | Informal spec (run86), 4 OQs |
| T34 | QPACK static table lookup | 1 | — | Researched (run87) ~30 lines, fully decidable |
| T35 | H3 parse_settings_frame RFC | 1 | — | Researched (run87) H2-key rejection + size guard |
| T36 | Bandwidth arithmetic invariants | 1 | — | Researched (run88/89) gcongestion/bandwidth.rs, ~40 lines, all omega |
| T37 | BytesInFlight counter invariant | 1 | — | Researched (run88/89) recovery/bytes_in_flight.rs, ~50 lines |

## Open PRs (lean-squad label)

- Issue #73 (run88): T36/T37 research + CI completeness check (FAILED to push lean-ci.yml — protected file; info preserved in issue; changes apply to RESEARCH.md/TARGETS.md from run89)
- PR run89 (branch lean-squad-run89-24703159938-route-b-tests-research):
  Task 8 — Route-B tests for T20 (18/18 PASS)
  Task 1 — Research T36/T37 + TARGETS.md fix

## Next Actions

1. T36: write FVSquad/Bandwidth.lean (all omega, ~40 lines) — EASIEST next Lean file
2. T31: write FVSquad/H3Frame.lean (GoAway/MaxPushId/CancelPush round-trips)
3. T33: write FVSquad/H3Settings.lean (Settings invariants)
4. T34: write FVSquad/QPACKStaticTable.lean (~30 lines, all decide)
5. Add putU32_bytes_unchanged to OctetsMut.lean → closes 2 sorry VarIntRoundtrip
6. T29: extend PacketHeader.lean with full byte-list model → closes 1 sorry
7. Route-B tests: add more targets (e.g., RangeSet, Varint) following tests/pkt_num_len/ pattern
