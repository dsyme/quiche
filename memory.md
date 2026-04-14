# Lean Squad Memory -- dsyme/quiche

Last updated: 2026-04-14 (run 68)
Lean toolchain: leanprover/lean4:v4.29.0 (via elan)
Lake project: formal-verification/lean/
FVSquad.lean: import manifest for all modules

## FV Targets

| # | Name | File | Phase | Status |
|---|------|------|-------|--------|
| 1 | Varint encoding | quiche/src/stream/mod.rs | 5 | ✅ Done |
| 2 | RangeSet interval algebra | quiche/src/ranges.rs | 5 | ✅ Done |
| 3 | RTT estimator (EWMA) | quiche/src/recovery/rtt.rs | 5 | ✅ Done |
| 4 | Flow control window | quiche/src/flowcontrol.rs | 5 | ✅ Done |
| 5 | NewReno congestion | quiche/src/recovery/congestion/... | 5 | ✅ Done |
| 6 | Datagram queue | quiche/src/dgram.rs | 5 | ✅ Done |
| 7 | PRR packet pacing | quiche/src/recovery/prr.rs | 5 | ✅ Done |
| 8 | Packet number decode | quiche/src/packet.rs | 5 | ✅ Done |
| 9 | Cubic CC | quiche/src/recovery/congestion/cubic.rs | 5 | ✅ Done |
| 10 | Min-max filter | quiche/src/minmax.rs | 5 | ✅ Done |
| 11 | RangeBuf offset arithmetic | quiche/src/range_buf.rs | 5 | ✅ Done |
| 12 | RecvBuf stream reassembly | quiche/src/stream/recv_buf.rs | 5 | ✅ Done (run61: insertAny_inv) |
| 13 | SendBuf stream send buffer | quiche/src/stream/send_buf.rs | 5 | ✅ Done |
| 14 | Connection ID management | quiche/src/cid.rs | 5 | ✅ Done |
| 15 | Stream priority key | quiche/src/stream/mod.rs | 5 | ✅ Done |
| 16 | OctetsMut byte serializer | octets/src/lib.rs | 5 | ✅ Done (run63: fixed split_ifs) |
| 17 | Octets read-only cursor | octets/src/lib.rs | 5 | ✅ Done (run62: 48 theorems + 9 examples) |
| 18 | StreamId RFC 9000 §2.1 | quiche/src/stream/mod.rs + lib.rs | 5 | ✅ Done (run64: 35 theorems) |
| 19 | Octets↔OctetsMut cross-module | octets/src/lib.rs | 5 | ✅ Done (run65: 20 theorems + 9 examples) |
| 20 | pkt_num_len encoding length | quiche/src/packet.rs ~L569 | 5 | ✅ Done (run66: 20 theorems + 10 examples) |
| 21 | SendBuf::retransmit model | quiche/src/stream/send_buf.rs:366 | 5 | ✅ Done (run68: 17 theorems + 10 examples) |
| 22 | RecvBuf flow-control bound | quiche/src/stream/recv_buf.rs:93 | 0 | ⬜ Identified |
| 23 | put_varint→get_varint roundtrip | octets/src/lib.rs | 0 | ⬜ Identified |
| 24 | encode_pkt_num→decode_pkt_num | quiche/src/packet.rs | 0 | ⬜ Identified |
| 25 | StreamId↔stream_do_send guard | quiche/src/lib.rs:5894 | 0 | ⬜ Identified |

## Theorem Totals

486 public theorems + 156 examples + ~53 private helpers, 0 sorry across 21 Lean files.
(Previous: 469 + 146 examples; added run68: 17 theorems + 10 examples)

## Open PRs (lean-squad label)

- PR #53 (run66): PacketNumLen.lean — open
- PR #54 (run67): CRITIQUE.md update (Targets 19-20) + CI audit — open
- PR run68: SendBufRetransmit.lean + RESEARCH Targets 21-25 — just created

## Status Issue: #4 (open)

## Key Open Questions for Next Run

- Next targets: **Target 22** (RecvBuf flow-control), **Target 23** (varint roundtrip),
  **Target 24** (encode→decode composition), **Target 25** (StreamId guard)
- OQ-1 (StreamPriorityKey antisymmetry): awaiting maintainer response
- OQ-RT-1 (zero-length retransmit edge case): awaiting maintainer response
- CORRESPONDENCE.md: needs updates for Targets 18-21

## Anti-Patterns (DO NOT USE without Mathlib)

- `split_ifs` — Mathlib-only tactic; use `by_cases hc : COND` instead
- `linarith` — Mathlib-only; use `omega` for all Nat arithmetic
- `native_decide` on struct equality — SendState lacks DecidableEq; use
  field-level `decide` instead (test .emitOff, .off, etc. individually)
- `|>` operator before `=` in examples — parenthesise: `(expr).field = val`
- `simp [h]; omega` — if simp already closes the goal, omega will see
  "No goals to be solved". Use simp only, or omit omega if simp closes it.

## Key Proof Patterns (no Mathlib)

- If-then-else in hypothesis: `by_cases hc : COND`
- min/max idempotence: `min (min a b) b = min a b` via `Nat.min_eq_left (Nat.min_le_right a b)`
- Struct equality when only one field differs: use `congr 1` then prove the field equality
- calc chains for transitivity: avoid simp after emitN (simp unfolds emitN_emitOff)
- Roundtrip existential: `refine ⟨witness, ?_⟩` then simp+omega
- Nat.sub with omega: need `b ≤ a` in context for `(a - b) + b = a`
- Nat.max with omega: omega does NOT know `max a b ≥ a`
  → Use `have := Nat.le_max_left a b` or `Nat.le_max_right a b` explicitly
- Cross-module: private theorems must be re-proved inline
- pktNumLen if-then-else: use simp [if_pos c]/simp [if_neg c] for reasoning

## Key Findings

- OQ-1 (run 49): StreamPriorityKey::cmp violates Ord antisymmetry (intentional)
- decode_pktnum_correct spec refinement (run 39): non-strict bound admitted
  counterexample; corrected to match RFC 9000 §A.3 strict invariant
- run 63: OctetsMut split_ifs fix — split_ifs is Mathlib-only; use by_cases
- run 64: streamType_add_mul4 — stream type preserved under all +4k increments
- run 66: pktNumLen_four_coverage requires QUIC validity hypothesis
  (numUnacked ≤ 2147483648) since model returns 4 for all large values
- run 68: OQ-RT-1 — zero-length retransmit with off > ackOff may not be a no-op
  (the Lean model sets emitOff to off even for len=0); needs maintainer clarification

## CI Status (Task 9 audit — run 67)

- lean-ci.yml: ✅ exists, correct triggers (PR + push master/main on formal-verification/lean/**)
- lake build: ✅ passes with 24 jobs (run68), 0 errors, 0 sorry
- All 21 FVSquad modules included in FVSquad.lean manifest
- lean-toolchain: leanprover/lean4:v4.29.0 (no update needed)

## Lake Project

No Mathlib dependency (`lake-manifest.json` is empty packages).
FVSquad.lean imports (in order): Octets, Varint, RangeSet, Minmax,
  RttStats, FlowControl, NewReno, DatagramQueue, PRR, PacketNumDecode,
  Cubic, RangeBuf, RecvBuf, SendBuf, CidMgmt, StreamPriorityKey,
  OctetsMut, OctetsRoundtrip, StreamId, PacketNumLen, SendBufRetransmit
