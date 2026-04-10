# Lean Squad Memory -- dsyme/quiche

## Tool & Approach
- FV tool: Lean 4 (v4.29.0, no Mathlib)
- Project: formal-verification/lean/ -- lake init FVSquad (no Mathlib)
- CI: .github/workflows/lean-ci.yml (added run 15; improved run 42)

## Targets

### 1-10: Phase 5 COMPLETE (see archived targets in TARGETS.md)
### 11. RangeBuf offset arithmetic -- Phase 5 COMPLETE (19 theorems)
### 12. Stream receive buffer (RecvBuf) -- Phase 4 (32 theorems, 0 sorry)
- Lean file: FVSquad/RecvBuf.lean
- emitN + insertContiguous fully proved; insertAny general model is the gap
- Next: extend to overlapping chunks (hardest part)

### 13. SendBuf stream send buffer -- Phase 5 COMPLETE (43 theorems)
- FVSquad/SendBuf.lean

### 14. Connection ID sequence management -- Phase 5 COMPLETE (21 theorems)
- FVSquad/CidMgmt.lean

### 15. StreamPriorityKey::cmp ordering -- Phase 5 COMPLETE (run 49)
- 21 theorems + 7 examples, 0 sorry -- FVSquad/StreamPriorityKey.lean
- OQ-1 FORMALLY PROVED: cmpKey_incr_incr_not_antisymmetric (Ord violation)

### 16. OctetsMut byte-buffer read/write -- Phase 5 COMPLETE (run 53)
- Informal spec: specs/octets_informal.md (added run 52)
- Lean file: FVSquad/OctetsMut.lean (33 named theorems + 7 examples, 0 sorry)
- Merged into run 57 working branch; PR run57 open
- Key theorems: putU8/U16/U32 round-trips, cap_identity, skip_rewind_inverse

### 17. Octets read-only byte buffer -- Phase 2 (run 57)
- Informal spec: specs/octets_ro_informal.md (added run 57)
- Next: write FVSquad/Octets.lean (Phase 3)
- Open questions: OQ-T17-1 (slice_last ignores cursor), OQ-T17-2 (is_empty)

## Open PRs
- lean-squad-run57-24255597145: CRITIQUE OctetsMut + Target 17 informal spec

## Suite Status (run 57)
- 16 modules, ~373 named theorems + 14 examples, 0 sorry
- Lean 4.29.0, no Mathlib; lake build: PASSED

## Key Technical Notes
- No Mathlib: use omega, simp, decide, rfl
- Big-endian get: use 256*b0+b1 NOT b0*256+b1 for omega
- split_ifs NOT available; use by_cases + if_pos/if_neg
- if-reduction: use if_pos hc as simp lemma, NOT hc alone
- let-binding in simp: require explicit let var in simp call
- Nat.div_add_mod v k : k*(v/k) + v mod k = v

## Next Targets (priority order)
1. Octets.lean (Target 17, Phase 3): getU8/U16/U32/U64, skip, rewind, get_bytes
2. OctetsMut putU64/getU64 (8-byte big-endian round-trip)
3. RecvBuf overlapping chunks (hardest; phase 4->5)
4. RangeSet semantic completeness (flatten after insert = set_union)
5. NewReno AIMD rate theorem
