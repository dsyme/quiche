# FV State Summary — dsyme/quiche

Last updated: 2026-04-08 (run 50)

## Theorem Count
- Varint.lean: 10 theorems, 0 sorry ✅
- RangeSet.lean: 16 theorems, 0 sorry ✅
- Minmax.lean: 15 theorems, 0 sorry ✅
- RttStats.lean: 23 theorems, 0 sorry ✅
- FlowControl.lean: 22 theorems, 0 sorry ✅
- NewReno.lean: 13 theorems, 0 sorry ✅
- DatagramQueue.lean: 26 theorems, 0 sorry ✅
- PRR.lean: 20 theorems, 0 sorry ✅
- PacketNumDecode.lean: 23 theorems, 0 sorry ✅
- Cubic.lean: 26 theorems, 0 sorry ✅
- RangeBuf.lean: 19 theorems, 0 sorry ✅
- RecvBuf.lean: 35 theorems + 17 examples, 0 sorry ✅
- SendBuf.lean: 26 theorems, 0 sorry ✅
- CidMgmt.lean: 21 theorems, 0 sorry ✅
- StreamPriorityKey.lean: 22 theorems + 7 examples, 0 sorry ✅
- **Total: 317 named theorems + 24 examples, 0 sorry**

## New This Run (50)
- FVSquad/RecvBuf.lean: §11 insertAny added
  - noOverlapWith predicate, insertChunkAt (sorted), RecvBuf.insertAny
  - 6 new public theorems (insertAny_readOff/finOff/highMark/highMark_ge/
    highMark_covers_chunk/inv) + 7 test vectors
  - Total: 35 theorems + 17 examples (was 29+10)
- formal-verification/specs/octets_informal.md: OctetsMut informal spec (Target 16)
- TARGETS.md: Target 15 → phase 5; Target 16 added (OctetsMut, phase 2)
- PR: lean-squad-run50-24129104910-recvbuf-octets-2 (open)

## Status Issue: #4 (open)
## Open PRs
- Branch lean-squad-run50-24129104910-recvbuf-octets-2 (pending PR, run 50)
- PRs #43 and #44 (run 48/49) merged into local master (not yet merged upstream)
