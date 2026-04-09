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

### 16. OctetsMut byte-buffer read/write — Phase 5 COMPLETE (run 53)
- Informal spec: specs/octets_informal.md (added run 52)
- Lean file: FVSquad/OctetsMut.lean (40 theorems, 0 sorry)
- PR: lean-squad-run53-24183986964-octets-mut-proofs (open)
- CORRESPONDENCE.md: OctetsMut section added (run 53)
- Key properties: off+cap=len invariant, skip/rewind inverse, u8/u16/u32 round-trips

## Open PRs / Branches
- `lean-squad-run53-24183986964-octets-mut-proofs` — open (run 53)
  - OctetsMut.lean (40 theorems), CORRESPONDENCE OctetsMut section, TARGETS 16→Phase 5

## Suite Status (run 53)
- **16 modules, 350 theorems + 11 examples, 0 sorry** (this PR)
- Lean 4.29.0, no Mathlib

## Key Technical Notes
- No Mathlib: use omega, simp, decide, rfl; no ring/linarith/norm_num
- listGet/listSet: define recursively
- Big-endian get: use `256 * b0 + b1` NOT `b0 * 256 + b1` for omega compat
- u32 arithmetic: break into separate have steps for omega
- simp [Nat.div_add_mod] closes match + arithmetic in one shot
- split_ifs at h → simp only [Option.some.injEq] at h; subst h
- Unpack helpers: private theorem returning ∧-conjunction of cond + buf + off

## Next Targets
- RecvBuf overlapping chunks (hardest; phase 4 → 5)
- CID byte-content uniqueness (security-critical per RFC 9000 §5.1)
- OctetsMut put_u64/get_u64 (analogous to u32, Phase 5 extension)
