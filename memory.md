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
- PR #47 open (pending merge)
- CORRESPONDENCE.md: OctetsMut section added (run 53)
- Key properties: off+cap=len invariant, skip/rewind inverse, u8/u16/u32 round-trips

### 17. Octets read-only byte buffer — Phase 2 (Informal Spec)
- Informal spec: specs/octets_ro_informal.md (added run 54)
- Natural complement to OctetsMut; all incoming QUIC data parsed via Octets
- Key targets: cursor invariant, skip/rewind inverse, peek_u8_no_advance,
  get_u16_big_endian, cross-type OctetsMut↔Octets bridge (OQ-3)
- PR #48 open (run 54)

## Open PRs / Branches
- PR #46: lean-squad-run52-24171018643-corr-targets-octetsmut-... (open)
  - CORRESPONDENCE.md StreamPriorityKey section, specs/octets_informal.md, TARGETS Target 16
- PR #47: lean-squad-run53-24183986964-octets-mut-proofs-... (open)
  - OctetsMut.lean (40 theorems), CORRESPONDENCE OctetsMut section, TARGETS 16→Phase 5
- PR #48: lean-squad-run54-24204649302-octets-ro-spec-critique (open, run 54)
  - specs/octets_ro_informal.md, TARGETS Target 17, CRITIQUE update (Targets 15+16+Gaps)

## Suite Status (run 54)
- **16 modules, 350 theorems + 11 examples, 0 sorry**
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
- Octets.lean (Target 17, Phase 2→5): informal spec done; write Lean spec
  - List Nat buffer, Nat offset, Option return type (same as OctetsMut)
  - Key theorems: Inv, skip/rewind inverse, peek_u8_no_advance, get_u16_big_endian
  - Cross-type bridge with OctetsMut.lean (OQ-3)
- RecvBuf overlapping chunks (hardest; phase 4 → 5)
- CID byte-content uniqueness (security-critical per RFC 9000 §5.1)
- OctetsMut put_u64/get_u64 (analogous to u32, Phase 5 extension)
