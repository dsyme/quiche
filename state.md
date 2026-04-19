# Lean Squad Memory -- dsyme/quiche

Last updated: 2026-04-19 (run 83)
Lean toolchain: leanprover/lean4:v4.29.1 (via elan)
Lake project: formal-verification/lean/
FVSquad.lean: import manifest for all modules

## FV Targets

| # | Name | File | Phase | Status |
|---|------|------|-------|--------|
| 1 | Varint encoding | octets/src/lib.rs | 5 | Done |
| 2 | RangeSet interval algebra | quiche/src/ranges.rs | 5 | Done |
| 3 | Minmax filter | quiche/src/minmax.rs | 5 | Done |
| 4 | RTT estimator (EWMA) | quiche/src/recovery/rtt.rs | 5 | Done |
| 5 | Flow control window | quiche/src/flowcontrol.rs | 5 | Done |
| 6 | NewReno congestion | quiche/src/recovery/congestion/reno.rs | 5 | Done |
| 7 | DatagramQueue | quiche/src/dgram.rs | 5 | Done |
| 8 | PRR packet pacing | quiche/src/recovery/prr.rs | 5 | Done |
| 9 | Packet number decode | quiche/src/packet.rs | 5 | Done |
| 10 | Cubic CC | quiche/src/recovery/congestion/cubic.rs | 5 | Done |
| 11 | RangeBuf offset arithmetic | quiche/src/range_buf.rs | 5 | Done |
| 12 | RecvBuf stream reassembly | quiche/src/stream/recv_buf.rs | 5 | Done |
| 13 | SendBuf stream send buffer | quiche/src/stream/send_buf.rs | 5 | Done |
| 14 | CID management | quiche/src/cid.rs | 5 | Done |
| 15 | StreamPriorityKey ordering | quiche/src/stream/mod.rs | 5 | Done |
| 16 | OctetsMut byte serializer | octets/src/lib.rs | 5 | Done |
| 17 | Octets read-only cursor | octets/src/lib.rs | 5 | Done |
| 18 | StreamId RFC 9000 §2.1 | quiche/src/stream/mod.rs | 5 | Done |
| 19 | OctetsRoundtrip cross-module | octets/src/lib.rs | 5 | Done |
| 20 | pkt_num_len encoding length | quiche/src/packet.rs | 5 | Done |
| 21 | SendBuf::retransmit model | quiche/src/stream/send_buf.rs | 5 | Done |
| 22 | RecvBuf flow-control bound | quiche/src/stream/recv_buf.rs | 0 | Identified |
| 23 | put_varint→get_varint roundtrip | octets/src/lib.rs | 5 | Done (8 thms, 2 sorry 8-byte) |
| 24 | encode_pkt_num→decode_pkt_num | quiche/src/packet.rs | 5 | Done (10 thms, 0 sorry) |
| 25 | StreamId↔stream_do_send guard | quiche/src/lib.rs | 0 | Identified |
| 26 | CUBIC W_cubic vs W_est | quiche/src/recovery/congestion/cubic.rs | 0 | Identified (MEDIUM) |
| 27 | CidMgmt retire_if_needed | quiche/src/cid.rs | 0 | Identified (MEDIUM) |
| 28 | NewReno multi-cycle AIMD | quiche/src/recovery/congestion/reno.rs | 0 | Identified (MEDIUM) |
| 29 | QUIC packet-header first-byte | quiche/src/packet.rs | 4 | 14 thms, 1 sorry for full RT |
| 30 | Varint 2-bit tag consistency | octets/src/lib.rs | 2 | Informal spec done (run 83) |
| 31 | H3 frame type codec round-trip | quiche/src/h3/frame.rs | 2 | Informal spec done (run 82) |
| 32 | BBR2 pacing rate bounds | quiche/src/recovery/gcongestion/bbr2.rs | 0 | NEW run78 (MEDIUM) |
| 33 | H3 Settings frame invariants | quiche/src/h3/frame.rs | 0 | NEW run78 (MEDIUM) |

## Lean File Registry (verified lake build run81)

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

## Open Sorry Obligations

| Theorem | File | Blocking gap |
|---------|------|-------------|
| putVarint_freeze_getVarint_8byte | VarIntRoundtrip.lean | putU32_bytes_unchanged in OctetsMut.lean |
| putVarint_first_byte_tag (8-byte) | VarIntRoundtrip.lean | Same |
| longHeader_roundtrip | PacketHeader.lean | Full buffer model (byte-list encode/decode) |

## Open PRs (lean-squad label)

- run83 PR (branch lean-squad-run83-24620481200-t30spec-report):
  Task 2 — Varint 2-bit tag informal spec T30 (Phase 0→2)
  Task 10 — REPORT.md update (run 83)

## Status Issue

Issue #4 (open)

## Key Findings

- OQ-1 (run49): StreamPriorityKey antisymmetry violation (intentional by design)
- OQ-RT-1 (run68): zero-length retransmit with off > ackOff may not be no-op
- OQ-FC-1 (run70, not modelled): RESET_STREAM guard in RecvBuf not modelled
- decode_pktnum_correct spec refinement (run39): non-strict bound counterexample found
- OQ-T29-1 (run73): Initial token=None encodes as varint 0, decodes as Some([])
- OQ-T29-2 (run73): to_bytes does not validate CID lengths
- OQ-T29-3 (run73): pkt_num/key_phase not in to_bytes/from_bytes roundtrip
- OQ-T23-1 (run74): over-long encoding tag consistency (put_varint_with_len)
- OQ-T23-2 (run74): OctetsMut.get_varint ≡ Octets.get_varint equivalence
- OQ-T31-1 (run82): from_bytes behavior with payload_length > bytes.len()
- OQ-T31-2 (run82): 0-length frame handling incomplete (TODO in code)
- OQ-T31-3 (run82): Settings GREASE round-trip reconstruction
- OQ-T31-4 (run82): payload_length vs bytes.len() precondition not enforced
- OQ-T30-1 (run83): varint_parse_len_nat(first>255) behavior (open-ended bound)
- OQ-T30-2 (run83): omega on very large 8-byte constants may timeout
- OQ-T30-3 (run83): partition theorem vs 4 separate iffs — design choice

## Next Priority Targets

1. T30: write FVSquad/VarIntTag.lean (~120 lines, all omega proofs)
   - varint_parse_len_N_iff biconditionals (§1 of spec)
   - varint_tag_nooverlap lemmas (§3 of spec)
   - varint_tag_consistency universal form (§4 of spec)
2. T31: write FVSquad/H3Frame.lean for GoAway/MaxPushId/CancelPush round-trips
3. Add putU32_bytes_unchanged to OctetsMut.lean → closes 2 sorry VarIntRoundtrip
4. T29: extend PacketHeader.lean with full byte-list model → closes 1 sorry

## CRITIQUE.md Status (run 82)

Last updated: 2026-04-18 17:20 UTC (commit d951c7e1)
Covers: Targets 1-29, 518 theorems, 3 sorry

## Anti-Patterns (DO NOT USE without Mathlib)

- `split_ifs` — Mathlib-only; use `by_cases hc : COND`
- `linarith` — Mathlib-only; use `omega`
- `native_decide` on struct equality — SendState lacks DecidableEq
- `|>` before `=` in examples — parenthesise: `(expr).field = val`
- `simp [h]; omega` — if simp closes goal, omega sees "No goals to be solved"
- `decide` on goals with free `Nat` variables — not decidable; use cases+simp+omega

## Key Proof Patterns (no Mathlib)

- If-then-else in hypothesis: `by_cases hc : COND`
- min/max idempotence: `Nat.min_eq_left (Nat.min_le_right a b)`
- Struct equality one field differs: `congr 1` then prove field equality
- Roundtrip existential: `refine ⟨witness, ?_⟩` then simp+omega
- Nat.sub with omega: need `b ≤ a` in context
- Nat.max with omega: add `have := Nat.le_max_left a b` explicitly
- Cross-module: private theorems must be re-proved inline
- PacketType case analysis: `cases ty <;> simp [...] at * <;> omega`
- typeCode/longFirstByte proofs: `cases ty` + simp + omega (not decide)

## CI Status (run82)

- lean-ci.yml: exists, correct triggers (PR + push master/main on formal-verification/lean/**)
- lake build: passes with 27 jobs, 3 sorry warnings, 0 errors (run81)
- lean-toolchain: leanprover/lean4:v4.29.0 (note: elan installed v4.29.1)

## Lake Project

No Mathlib dependency (lake-manifest.json is empty packages).
FVSquad.lean imports 24 modules (in order): Octets, Varint, RangeSet,
  Minmax, RttStats, FlowControl, NewReno, DatagramQueue, PRR, PacketNumDecode,
  Cubic, RangeBuf, RecvBuf, SendBuf, CidMgmt, StreamPriorityKey, OctetsMut,
  OctetsRoundtrip, StreamId, PacketNumLen, SendBufRetransmit,
  VarIntRoundtrip, PacketNumEncodeDecode, PacketHeader
