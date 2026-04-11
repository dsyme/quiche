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

### 16. OctetsMut byte-buffer read/write -- Phase 5 COMPLETE (run 60)
- Lean file: FVSquad/OctetsMut.lean (40 theorems, 0 sorry)
- FIXED in run60: replaced split_ifs (Mathlib-only) with by_cases+if_pos/if_neg
- FIXED: round-trip proofs: rw [show N=v from by omega]; exact ⟨_, rfl⟩
- NOW compiles from source (no cached olean dependency)
- Key theorems: putU8/U16/U32 round-trips, skip_rewind_inverse, cap_identity

### 17. Octets read-only byte buffer -- Phase 5 COMPLETE (run 60)
- Lean file: FVSquad/Octets.lean (46 theorems + 9 examples, 0 sorry)
- KEY FINDING: isEmpty checks buf.len()==0, NOT cap()==0
  - cap_zero_ne_isEmpty: cap=0 + buf≠[] → isEmpty=false
  - Callers should use cap()==0, not is_empty()
- Key theorems: skip_rewind_inverse_ro, getU8/U16/U32/U64 value+range+advance
  getBytes_length_ro, cap_decreases_after_getU8_ro, isEmpty_iff_buf_nil

## Open PRs (run 60)
- run60 (lean-squad-run60-octets-ro-implementation-proofs): Octets.lean + OctetsMut fix
  Files: Octets.lean (new), OctetsMut.lean (fix), FVSquad.lean, TARGETS.md,
         CORRESPONDENCE.md, specs/octets_ro_informal.md

## Suite Status (run 60)
- 17 modules, ~396 named theorems + 20 examples, 0 sorry
- Lean 4.29.0, no Mathlib; lake build: PASSED (20 jobs)

## Key Technical Notes (CRITICAL for future Lean files)
- No Mathlib: use omega, simp, decide, native_decide, rfl
- Big-endian get: use 256*b0+b1 NOT b0*256+b1 for omega
- split_ifs NOT available (Mathlib-only); ALWAYS use by_cases + rw [if_pos/if_neg]
- conv_lhs NOT available (Mathlib-only); use plain rw [show ...]
- if-reduction: use if_pos hc in simp set (NOT bare hc which just rewrites to True)
- round-trip existential: rw [show N=v from by omega]; exact ⟨_, rfl⟩
- Unpack for (val, state) Option results:
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨hv, hs'⟩ := h; subst hs'
- Unpack for plain state Option results:
    simp only [Option.some.injEq] at h; subst h
- FVSquad.lean imports all modules; new .lean files MUST be added there

## Next Targets (priority order)
1. RecvBuf overlapping chunks (phase 4→5)
2. RangeSet semantic completeness (flatten(insert) = set_union)
3. OctetsMut putU64/getU64 (8-byte big-endian round-trip)
4. NewReno AIMD exact rate theorem (multi-callback)
