# FV State Summary — dsyme/quiche

Last updated: 2026-05 (run 80 — Everest security pivot)

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
- RecvBuf.lean: 29 theorems, 0 sorry ✅
- SendBuf.lean: 26 theorems, 0 sorry ✅
- CidMgmt.lean: 21 theorems, 0 sorry ✅
- **QuicNonce.lean: 8 theorems, 0 sorry ✅ (NEW run 80)**
- **PktNumWindow.lean: 7 theorems, 0 sorry ✅ (NEW run 80)**
- **QuicHeaderProtection.lean: 9 theorems, 0 sorry ✅ (NEW run 80)**
- (many others — see memory.md for full list)
- **Total run 80: ~504 + 24 new theorems = ~528 named theorems, 2 sorry (pre-existing VarIntRoundtrip)**

## Security Targets (Everest-style, added run 80)
- T34: QUIC nonce injectivity — FVSquad/QuicNonce.lean — DONE (0 sorry)
- T35: Anti-replay window soundness — FVSquad/PktNumWindow.lean — DONE (0 sorry)
- T36: Header protection round-trip — FVSquad/QuicHeaderProtection.lean — DONE (0 sorry)
- T37: Anti-amplification rate bound — IDENTIFIED (future work)

## Status Issue: #4 (open)
## Open PRs
- run 80 PR pending (branch: lean-squad-run80-24599671257-everest-security)
