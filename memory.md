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

### 16. OctetsMut byte-buffer read/write -- Phase 5 COMPLETE (run 58)
- Informal spec: specs/octets_informal.md (added run 52)
- Lean file: FVSquad/OctetsMut.lean (41 theorems, 0 sorry)
- FIXED in run58: was never imported in FVSquad.lean; split_ifs→by_cases
- Key theorems: putU8/U16/U32 round-trips, bytes4_val helper, skip_rewind_inverse
- OctetsMut was missing from lake build before run 58 (import omission)

### 17. Octets read-only byte buffer -- Phase 5 COMPLETE (run 58)
- Lean file: FVSquad/Octets.lean (43 theorems + 7 examples, 0 sorry)
- Key result: is_empty_buf_based (isEmpty tests buf.len(), not cap())
- skip_rewind_inverse_ro, getU8/U16/U32/U64, getBytes, slice, sliceLast

## Open PRs
- run58 (lean-squad-run58-24273633585-octets-ro-corr-critique): Octets.lean + OctetsMut fix

## Suite Status (run 58)
- 17 modules, ~420 theorems + 26 examples, 0 sorry
- Lean 4.29.0, no Mathlib; lake build: PASSED

## Key Technical Notes
- No Mathlib: use omega, simp, decide, native_decide, rfl
- Big-endian get: use 256*b0+b1 NOT b0*256+b1 for omega
- split_ifs NOT available; use by_cases + rw [if_pos/if_neg]
- if-reduction: use if_pos hc in simp set, or rw [if_pos hc]
- Unpack pattern: simp [Option.some.injEq, Prod.mk.injEq]; obtain ⟨hv,hs'⟩:=h; subst hs'
- Nat.div_add_mod v k : k*(v/k) + v mod k = v
- Nat.div_div_eq_div_mul v a b : v/a/b = v/(a*b)
- bytes4_val: use Nat.div_div_eq_div_mul (not .symm)
- FVSquad.lean imports all modules; new .lean files MUST be added there

## Next Targets (priority order)
1. OctetsMut putU64/getU64 (8-byte big-endian round-trip, analogous to putU32)
2. RecvBuf overlapping chunks (hardest; phase 4->5)
3. RangeSet semantic completeness (flatten after insert = set_union)
4. NewReno AIMD rate theorem
5. Cross-module Octets/OctetsMut round-trip (write then read)
