# Lean Squad Memory -- dsyme/quiche

Last updated: 2026-04-14 (run 66)
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

## Theorem Totals

469 public theorems + 146 examples + ~53 private helpers, 0 sorry across 20 Lean files.

## Open PRs (lean-squad label)

- PR run65: OctetsRoundtrip.lean (pending merge — PR #52)
- PR run66: PacketNumLen.lean (just created, pending merge)
## Status Issue: #4 (open)

## Key Open Questions for Next Run

- Next targets: **Target 21** (SendBuf retransmit model — retransmit preserves
  SendBuf invariant), **Target 22** (RecvBuf highMark ≤ max_data flow-control),
  RangeSet semantic completeness, NewReno AIMD rate theorem
- OQ-1 (StreamPriorityKey antisymmetry): awaiting maintainer response
- CORRESPONDENCE.md: needs updates for Targets 18-20 (StreamId, OctetsRoundtrip, PacketNumLen)
- CRITIQUE.md: may need Target 20 entry (PacketNumLen)

## Anti-Patterns (DO NOT USE without Mathlib)

- `split_ifs` — Mathlib-only tactic; use `by_cases hc : COND` instead
- `linarith` — Mathlib-only; use `omega` for all Nat arithmetic
- `native_decide` on `Prop`s that are not `Decidable`
  Use explicit case analysis instead
- `simp [...] ; omega` — if simp already closes the goal, omega will see
  "No goals to be solved". Use simp only, or omit omega if simp closes it.
- Private theorems from other modules are not accessible — inline their proofs
  (e.g., putU16_unpack, putU32_unpack in OctetsMut.lean are private)

## Key Proof Patterns (no Mathlib)

- If-then-else in hypothesis: `by_cases hc : COND`
- Roundtrip existential: `refine ⟨witness, ?_⟩` then simp+omega
- Nat.sub with omega: need `b ≤ a` in context for `(a - b) + b = a`
  → For struct fields: add `have hinv := s.inv` before omega
- Nat.max with omega: omega does NOT know `max a b ≥ a` or `max a b ≥ b`
  → Use `have := Nat.le_max_left a b` or `Nat.le_max_right a b` explicitly
- Bool predicates from Prop: `def f : Bool := (expr : Prop)` uses decide wrapper
  → To prove `f (a+k) = f a`, use `have h : expr_in_a+k = expr_in_a := by omega`
     then `simp only [f, h]`
- Cross-module: private theorems (e.g. putU16_unpack) must be re-proved inline
  using simp+by_cases+subst patterns
- listSet_length: used to show (listSet l i v).length = l.length
  → Needed when proving off < (listSet ...).length after a put

## Key Findings

- OQ-1 (run 49): StreamPriorityKey::cmp violates Ord antisymmetry (intentional)
- decode_pktnum_correct spec refinement (run 39): non-strict bound admitted
  counterexample; corrected to match RFC 9000 §A.3 strict invariant
- getU16_split (run 62): getU16 = two sequential getU8 (big-endian framing)
- run 63: OctetsMut split_ifs fix — split_ifs is Mathlib-only; use by_cases
- run 64: streamType_add_mul4 — stream type preserved under all +4k increments
- run 66: pktNumLen if-then-else: use simp [if_pos c]/simp [if_neg c] for reasoning;
  `let` bindings in defs prevent simp from unfolding — avoid them for provability;
  after rw [if_pos/neg] numeric goals need omega; pktNumLen_four_coverage requires
  QUIC validity hypothesis (numUnacked ≤ 2147483648) since model returns 4 for all
  large values while Rust errors for n > 2^31-1

## Lake Project

No Mathlib dependency (`lake-manifest.json` is empty packages).
FVSquad.lean imports (in order): Octets, Varint, RangeSet, Minmax,
  RttStats, FlowControl, NewReno, DatagramQueue, PRR, PacketNumDecode,
  Cubic, RangeBuf, RecvBuf, SendBuf, CidMgmt, StreamPriorityKey,
  OctetsMut, OctetsRoundtrip, StreamId, PacketNumLen
