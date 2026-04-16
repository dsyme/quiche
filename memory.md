# Lean Squad Memory -- dsyme/quiche

Last updated: 2026-04-16 (run 73)
Lean toolchain: leanprover/lean4:v4.29.0 (via elan)
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
| 23 | put_varint→get_varint roundtrip | octets/src/lib.rs | 0 | Identified (HIGH) |
| 24 | encode_pkt_num→decode_pkt_num | quiche/src/packet.rs | 0 | Identified |
| 25 | StreamId↔stream_do_send guard | quiche/src/lib.rs | 0 | Identified |
| 26 | CUBIC W_cubic vs W_est | quiche/src/recovery/congestion/cubic.rs | 0 | Identified (MEDIUM) |
| 27 | CidMgmt retire_if_needed | quiche/src/cid.rs | 0 | Identified (MEDIUM) |
| 28 | NewReno multi-cycle AIMD | quiche/src/recovery/congestion/reno.rs | 0 | Identified (MEDIUM) |
| 29 | QUIC packet-header roundtrip | quiche/src/packet.rs | 2 | Informal Spec (run73) |
| 30 | Varint 2-bit tag consistency | octets/src/lib.rs | 0 | Identified (HIGH) |

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

## Open PRs

- PR run73 (branch lean-squad-run73-24491238828-informal-spec-ci-audit):
  Task 2+9: PacketHeader informal spec (T29) + CI audit -- just created
- PR #58 run72 (branch lean-squad-run72-...): MERGED into run73 branch

## Status Issue

Issue #4 (open)

## Key Findings

- OQ-1 (run49): StreamPriorityKey antisymmetry violation (intentional by design)
- OQ-RT-1 (run68): zero-length retransmit with off > ackOff may not be no-op
- OQ-FC-1 (run70, not modelled): RESET_STREAM guard in RecvBuf not modelled
- decode_pktnum_correct spec refinement (run39): non-strict bound counterexample found and corrected
- OQ-T29-1 (run73): Initial token=None encodes as varint 0, decodes as Some([]) — asymmetry
- OQ-T29-2 (run73): to_bytes does not validate CID lengths (only from_bytes does for QUIC v1)
- OQ-T29-3 (run73): pkt_num/key_phase not in to_bytes/from_bytes roundtrip (handled by encrypt_hdr/decrypt_hdr)

## CORRESPONDENCE.md Coverage (run72)

All 21 Lean files now covered in CORRESPONDENCE.md. No mismatches identified.

## Next Priority Targets

1. T29 PacketHeader.lean — write Lean spec (Task 3): RT-1..RT-5 theorems
   - informal spec at specs/packet_header_informal.md
   - Key challenge: Retry AEAD tag (16 bytes) excluded from token on decode
2. T30 Varint 2-bit tag (LOW effort, HIGH value; ~40 Lean lines)
3. T23 put_varint→get_varint cross-module roundtrip
4. T24 encode_pkt_num→decode_pkt_num composition
5. T25 StreamId↔stream_do_send guard

## T29 PacketHeader — Key Modelling Notes (for Task 3)

- Buffer: List Nat (byte list), offset as return value
- Long header types: Initial=0x00, ZeroRTT=0x01, Handshake=0x02, Retry=0x03
- Wire constants: FORM_BIT=0x80, FIXED_BIT=0x40, TYPE_MASK=0x30
- pkt_num/key_phase NOT in to_bytes/from_bytes — always 0 in decode output
- Initial token=None in to_bytes writes varint 0; from_bytes returns Some([])
- Short header: no scid/version; dcid_len must be supplied by caller
- Retry AEAD tag (16 bytes) excluded from model
- VersionNegotiation: only decodeable, not encodeable

## Anti-Patterns (DO NOT USE without Mathlib)

- `split_ifs` — Mathlib-only; use `by_cases hc : COND`
- `linarith` — Mathlib-only; use `omega`
- `native_decide` on struct equality — SendState lacks DecidableEq
- `|>` before `=` in examples — parenthesise: `(expr).field = val`
- `simp [h]; omega` — if simp closes goal, omega sees "No goals to be solved"

## Key Proof Patterns (no Mathlib)

- If-then-else in hypothesis: `by_cases hc : COND`
- min/max idempotence: `Nat.min_eq_left (Nat.min_le_right a b)`
- Struct equality one field differs: `congr 1` then prove field equality
- Roundtrip existential: `refine ⟨witness, ?_⟩` then simp+omega
- Nat.sub with omega: need `b ≤ a` in context
- Nat.max with omega: add `have := Nat.le_max_left a b` explicitly
- Cross-module: private theorems must be re-proved inline

## CI Status (run73 audit)

- lean-ci.yml: exists, correct triggers (PR + push master/main on formal-verification/lean/**)
- lake build: passes with 24 jobs, 0 errors, 0 sorry (last known good: run67-72)
- lean-toolchain: leanprover/lean4:v4.29.0
- No issues found in run73 audit

## Lake Project

No Mathlib dependency (lake-manifest.json is empty packages).
FVSquad.lean imports 21 modules (in order): Octets, Varint, RangeSet,
  Minmax, RttStats, FlowControl, NewReno, DatagramQueue, PRR, PacketNumDecode,
  Cubic, RangeBuf, RecvBuf, SendBuf, CidMgmt, StreamPriorityKey, OctetsMut,
  OctetsRoundtrip, StreamId, PacketNumLen, SendBufRetransmit
