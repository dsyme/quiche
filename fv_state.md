# FV State Summary -- dsyme/quiche

Last updated: 2026-05-22 (run 61)

## Theorem Count (after run 61)
- Varint.lean: 10 theorems, 0 sorry
- RangeSet.lean: 16 theorems, 0 sorry
- Minmax.lean: 15 theorems, 0 sorry
- RttStats.lean: 23 theorems, 0 sorry
- FlowControl.lean: 22 theorems, 0 sorry
- NewReno.lean: 13 theorems, 0 sorry
- DatagramQueue.lean: 26 theorems, 0 sorry
- PRR.lean: 20 theorems, 0 sorry
- PacketNumDecode.lean: 23 theorems, 0 sorry
- Cubic.lean: 26 theorems, 0 sorry
- RangeBuf.lean: 19 theorems, 0 sorry
- RecvBuf.lean: 59 theorems, 0 sorry  (UPDATED run61: +27 new)
- SendBuf.lean: 43 theorems, 0 sorry
- CidMgmt.lean: 21 theorems, 0 sorry
- StreamPriorityKey.lean: 21 theorems + 7 examples, 0 sorry
- OctetsMut.lean: 40 theorems, 0 sorry
- Total: 16 modules, ~397 named theorems + ~7 examples, 0 sorry
  NOTE: Octets.lean (run60 claim) was NEVER committed -- branch does not exist
  on remote. Run60 memory is STALE on this point.

## New This Run (61)
- Task 4+6: FVSquad/RecvBuf.lean extended (527→982 lines)
  - insertChunkInto: 6-case overlap-safe insertion algorithm
  - trimChunk: trims bytes below readOff cursor
  - RecvBuf.insertAny: full write() model (trim + insert + highMark update)
  - 27 new theorems (all 0 sorry): invariant preservation for general write
    KEY RESULT: insertAny_inv proves ALL 5 RecvBuf invariants preserved
  - 8 native_decide test vectors
- Task 6: CORRESPONDENCE.md updated (Target 12 V1 divergence partially resolved)
- TARGETS.md: Target 12 Phase 4→5 (Done), 32→59 theorems
- PR: lean-squad-run61-24298133625-recvbuf-insertany-correspondence (open)

## Status Issue: #4 (open)
## Open PRs (lean-squad label)
- run61: lean-squad-run61-24298133625-recvbuf-insertany-correspondence (open, not merged)

## Key Technical Notes
- NEVER use push_neg (Mathlib-only): use plain ¬(...)  with omega
- NEVER use split_ifs (Mathlib-only): use by_cases + rw [if_pos/if_neg]
- NEVER use conv_lhs (Mathlib-only): use rw [show ...]
- simp [Chunk.maxOff] does NOT unfold in hypotheses -- use simp [... ] at * or omega
- omega CANNOT case-split on if-then-else: must by_cases first then simp [if_pos/neg]
- Nat.min_le_left/right needed before omega for goals involving Nat.min
- struct literal field access {off:=x, len:=y}.len is NOT auto-reduced by omega
  -- use "show c.maxOff - e.maxOff > 0 from by omega" pattern
- chunksOrdered/chunksAbove/chunksWithin are defs not @[simp]: can't auto-close
  -- use constructor/exact/trivial after by_cases
