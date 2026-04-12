# Lean Squad Memory -- dsyme/quiche

Last updated: 2026-04-12 (run 62)
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
| 12 | RecvBuf stream reassembly | quiche/src/stream/recv_buf.rs | 5 | ✅ Done (run61: 56 theorems) |
| 13 | SendBuf stream send buffer | quiche/src/stream/send_buf.rs | 5 | ✅ Done |
| 14 | Connection ID management | quiche/src/cid.rs | 5 | ✅ Done |
| 15 | Stream priority key | quiche/src/stream/mod.rs | 5 | ✅ Done |
| 16 | OctetsMut byte serializer | octets/src/lib.rs | 5 | ✅ Done (40 theorems) |
| 17 | Octets read-only cursor | octets/src/lib.rs | 5 | ✅ Done (run62: 48 theorems + 9 examples) |

## Theorem Totals

398 named theorems + 16 examples, 0 sorry across 17 Lean files.

## Key Open Questions for Next Run

- OctetsMut.lean uses `split_ifs` throughout — broken, never in manifest
  - MUST rewrite using `by_cases` before adding to FVSquad.lean
  - Consider: rewrite OctetsMut.lean in a future run (Task 5 clean-up)
- No Mathlib dependency — keep it that way (smaller build, fewer failures)
- Next targets: `OctetsMut` cleanup, `StreamMap`, `PacketHeader`

## Anti-Patterns (DO NOT USE without Mathlib)

- `split_ifs` — Mathlib-only tactic; use `by_cases hc : COND` instead
- `linarith` — Mathlib-only; use `omega` for all Nat arithmetic
- `native_decide` on `Prop`s that are not `Decidable` (e.g. `s.Inv`)
  Use `withSlice_inv []` or manual `simp [Inv, ...]` instead

## Key Proof Patterns (no Mathlib)

- Invariant unpack: `simp only [Option.some.injEq, Prod.mk.injEq] at h`
  then `obtain ⟨_, hs'⟩ := h; subst hs'`
- Nat.sub with omega: need `b ≤ a` in context for `(a - b) + b = a`
- Structural goals after subst usually close with `rfl` or `omega`
- Test vectors: use `native_decide` only for decidable closed examples

## Key Findings

- OQ-1 (run 49): StreamPriorityKey::cmp violates Ord antisymmetry (intentional)
- decode_pktnum_correct spec refinement (run 39): non-strict bound admitted
  counterexample; corrected to match RFC 9000 §A.3 strict invariant
- getU16_split (run 62): getU16 = two sequential getU8 (big-endian framing)

## Lake Project

No Mathlib dependency (`lake-manifest.json` is empty packages).
FVSquad.lean imports (in order): Octets, Varint, RangeSet, Minmax,
  RttStats, FlowControl, NewReno, DatagramQueue, PRR, PacketNumDecode,
  Cubic, RangeBuf, RecvBuf, SendBuf, CidMgmt, StreamPriorityKey, OctetsMut*
(* OctetsMut currently excluded from manifest — needs rewrite)
