# Lean Squad Memory -- dsyme/quiche

## Tool & Approach
- FV tool: Lean 4 (v4.29.0, no Mathlib)
- Project: formal-verification/lean/ -- lake init FVSquad (no Mathlib)
- CI: .github/workflows/lean-ci.yml (added run 15; improved run 42)

## Targets

### 1-10: Phase 5 COMPLETE (see TARGETS.md)
### 11. RangeBuf offset arithmetic -- Phase 5 COMPLETE (19 theorems)
### 12. Stream receive buffer (RecvBuf) -- Phase 4 (32 theorems, 0 sorry)
- Lean file: FVSquad/RecvBuf.lean
- emitN + insertContiguous fully proved; insertAny general model is the gap
- Next: extend to overlapping chunks (hardest part)

### 13. SendBuf stream send buffer -- Phase 5 COMPLETE (43 theorems)
### 14. Connection ID sequence management -- Phase 5 COMPLETE (21 theorems)
### 15. StreamPriorityKey::cmp ordering -- Phase 5 COMPLETE (run 49)
- OQ-1 FORMALLY PROVED: cmpKey_incr_incr_not_antisymmetric (Ord violation)

### 16. OctetsMut byte-buffer read/write -- Phase 5 COMPLETE (run 59)
- Lean file: FVSquad/OctetsMut.lean (41 theorems, 0 sorry)
- FIXED in run59: was never imported; split_ifs→by_cases; if_pos fix
- Key theorems: putU8/U16/U32 round-trips, skip_rewind_inverse

### 17. Octets read-only byte buffer -- Phase 5 COMPLETE (run 59)
- Lean file: FVSquad/Octets.lean (~50 theorems + examples, 0 sorry)
- KEY FINDING: isEmpty checks buf.len()==0, NOT cap()==0 (counter-intuitive)
- Fully-consumed non-empty buffer returns isEmpty=false
- Key theorems: isEmpty_iff_buf_nil, isEmpty_false_of_nonempty_buf,
  skip_rewind_inverse_ro, getU8/U16/U32/U64 unpack+value+advance,
  getBytes_sub_len_eq_n, cap_after_getU*

## Open PRs
- run47 (PR#47): OctetsMut.lean (run53) -- STILL OPEN, not yet merged
- run46 (PR#46): CORRESPONDENCE + StreamPriorityKey (run52) -- STILL OPEN

## Pending Branch (NOT PUSHED)
- lean-squad-run59: committed locally, safeoutputs MCP blocked in run59
  Files: Octets.lean (new), OctetsMut.lean (fix), FVSquad.lean (imports)
  NEXT RUN: must push this branch and create PR before new work

## Suite Status (run 59 -- local only)
- 17 modules, ~460 theorems + examples, 0 sorry
- Lean 4.29.0, no Mathlib; lake build: PASSED

## Key Technical Notes
- No Mathlib: use omega, simp, decide, native_decide, rfl
- Big-endian get: use 256*b0+b1 NOT b0*256+b1 for omega
- split_ifs NOT available (Mathlib-only); use by_cases + rw [if_pos/if_neg]
- if-reduction: use if_pos hc in simp set (NOT bare hc which just rewrites to True)
- Unpack pattern for (val, state) results:
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨hv, hs'⟩ := h; subst hs'
- Unpack for plain state results (no pair):
    simp only [Option.some.injEq] at h; subst h
- For getBytes (returns (sub, s')) -- sub is a struct not a pair:
    obtain ⟨hsub, hs'⟩ := h; subst hs'; subst hsub
- FVSquad.lean imports all modules; new .lean files MUST be added there

## Next Targets (priority order)
1. FIRST: push lean-squad-run59 branch + create PR (if not already done)
2. OctetsMut putU64/getU64 (8-byte big-endian round-trip)
3. Cross-module Octets/OctetsMut round-trip (write then read)
4. RecvBuf overlapping chunks (phase 4→5)
5. RangeSet semantic completeness
