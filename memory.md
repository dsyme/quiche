# Lean Squad Memory -- dsyme/quiche

Last updated: 2026-05-22 (run 61)
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
| 12 | RecvBuf stream reassembly | quiche/src/stream/recv_buf.rs | 5 | ✅ Done (run61) |
| 13 | SendBuf stream send buffer | quiche/src/stream/send_buf.rs | 5 | ✅ Done |
| 14 | Connection ID management | quiche/src/cid.rs | 5 | ✅ Done |
| 15 | Stream priority key | quiche/src/stream/mod.rs | 5 | ✅ Done |
| 16 | OctetsMut byte serializer | octets/src/lib.rs | 5 | ✅ Done |
| 17 | Octets (read-only) | octets/src/lib.rs | 1 | Research only |

NOTE: Target 17 (Octets.lean) was claimed done in run60 memory but the
branch was never pushed and the PR was never created. Memory was stale.
Target 17 remains at Phase 1.

## Open Issues / PRs
- Status issue: #4 (open, maintained by Lean Squad)
- run61 PR: open (recvbuf insertAny)

## Theorem counts (per module, after run 61)
Varint:16→10, RangeSet:16, Minmax:15, RttStats:23, FlowControl:22,
NewReno:13, DatagramQueue:26, PRR:20, PacketNumDecode:23, Cubic:26,
RangeBuf:19, RecvBuf:59, SendBuf:43, CidMgmt:21, StreamPriorityKey:28,
OctetsMut:40
Total: ~424 named theorems, 0 sorry

## Lean 4 Anti-patterns (CRITICAL)
1. push_neg → NOT available; use plain ¬ with omega
2. split_ifs → NOT available; use by_cases + rw [if_pos/if_neg]
3. conv_lhs → NOT available; use rw [show ...]
4. Nat.not_eq_zero_of_lt → doesn't exist; use Nat.ne_of_gt
5. simp [Chunk.maxOff] does NOT unfold hypotheses; use simp [...] at * or omega
6. omega CANNOT case-split on if-then-else; must by_cases first
7. Nat.min in omega: add Nat.min_le_left/right explicitly before omega
8. struct {off:=x,len:=y}.len not reduced by omega; use show pattern
9. chunksOrdered/Above/Within NOT @[simp]; use constructor/exact/trivial
10. simpa [h] on goal=True fails; just use trivial
