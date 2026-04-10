# Lean Squad Memory — dsyme/quiche

## Tool & Approach
- **FV tool**: Lean 4 (v4.29.0, no Mathlib)
- **Project**: `formal-verification/lean/` — `lake init FVSquad` (no Mathlib)
- **CI**: `.github/workflows/lean-ci.yml` (added run 15; improved run 42)

## Targets

### 1–10: Phase 5 COMPLETE (see archived targets in TARGETS.md)
### 11. RangeBuf offset arithmetic — Phase 5 COMPLETE (19 theorems)
### 12. Stream receive buffer (RecvBuf) — Phase 4 (29 theorems, 0 sorry)
- Lean file: FVSquad/RecvBuf.lean
- emitN + insertContiguous fully proved; insertAny general model added
- Next: extend to overlapping chunks (hardest part)

### 13. SendBuf stream send buffer — Phase 5 COMPLETE (run 45)
- **26 theorems, 0 sorry** — FVSquad/SendBuf.lean

### 14. Connection ID sequence management — Phase 5 COMPLETE (run 46)
- **21 theorems, 0 sorry** — FVSquad/CidMgmt.lean

### 15. StreamPriorityKey::cmp ordering — Phase 5 COMPLETE (run 49)
- **21 theorems + 7 examples, 0 sorry** — FVSquad/StreamPriorityKey.lean
- OQ-1 FORMALLY PROVED: cmpKey_incr_incr_not_antisymmetric (Ord violation)
- PR #44 merged; CORRESPONDENCE added in run 52

### 16. OctetsMut byte-buffer read/write — Phase 5 COMPLETE (run 56)
- Informal spec: specs/octets_informal.md
- Lean file: FVSquad/OctetsMut.lean (49 theorems, 0 sorry)
- Run 56: added put_u64/get_u64 (8-byte big-endian) round-trip + successive write theorems
- Run 56: fixed all run53 bugs: split_ifs→by_cases, hBlen simp [B,...], if_pos hc, Nat.div_add_mod
- CORRESPONDENCE.md: Target 16 section added

### 17. Octets read-only byte buffer — Phase 5 COMPLETE (run 55)
- Informal spec: specs/octets_ro_informal.md (added run 55)
- Lean file: FVSquad/Octets.lean (28 theorems + 8 examples, 0 sorry)
- Run 55 PR: lean-squad-run55-... (pending merge)
- Key theorems: cap_identity, skip/rewind unpack, getU8/peekU8, getU16, getU32,
  getBytes (sub-buffer and main-buffer properties), offset accumulation
- Key fixes applied: if_pos hc for if-reduction; Nat.div_add_mod for byte-sum;
  .2.2.2.2 / .2.2.2.1 accessor paths for 5-component conjunction

## Open PRs / Branches
- PR #46: lean-squad-run52 (open) — CORRESPONDENCE.md, specs/octets_informal.md
- PR #48: lean-squad-run54 (open) — CRITIQUE.md update
- PR run55 (pending): Octets.lean + octets_ro_informal.md
- PR run56 (pending): OctetsMut.lean (49 theorems) + CORRESPONDENCE.md Target 16 + TARGETS.md

## Suite Status (run 56)
- **17 modules, ~388 theorems + 19 examples, 0 sorry**
- Lean 4.29.0, no Mathlib

## Key Technical Notes
- No Mathlib: use omega, simp, decide, rfl; no ring/linarith/norm_num
- listGet/listSet: define recursively
- Big-endian get: use `256 * b0 + b1` NOT `b0 * 256 + b1` for omega compat
- u32 arithmetic: break into separate have steps for omega
- **split_ifs NOT available** without Mathlib! Use by_cases + if_pos/if_neg
- if-reduction in simp: use `if_pos hc` as simp lemma, NOT `hc` alone
  (simp only [hc] rewrites condition to True but does NOT reduce the if)
- let-binding in simp: `let B := expr` requires `simp [B, listSet_length]` not just `simp [listSet_length]`
- Nat.div_add_mod v k : k * (v/k) + v%k = v (use for byte-round-trip proofs)
- u32 byte-sum identity: requires 3 Nat.div_add_mod + omega for h4/h5/h6 equalities
- 5-component conjunction access: A∧B∧C∧D∧E (right-assoc): .1 .2.1 .2.2.1 .2.2.2.1 .2.2.2.2
- Unpack helpers: private theorem returning ∧-conjunction of cond + buf + off

## Next Targets
- RecvBuf overlapping chunks (hardest; phase 4 → 5)
- CID byte-content uniqueness (security-critical per RFC 9000 §5.1)
- OctetsMut put_u64/get_u64 (DONE in run 56)
- RangeSet semantic completeness (flatten after insert = set_union)
- NewReno AIMD rate theorem (rate across multiple ACK callbacks)
