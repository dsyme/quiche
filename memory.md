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

### 16. OctetsMut byte-buffer read/write — Phase 2 (Informal Spec)
- Informal spec: specs/octets_informal.md (added run 52)
- Source: octets/src/lib.rs (OctetsMut struct, lines 391–800)
- Key properties: off+cap=len invariant, put/get round-trips, skip/rewind inverses
- Lean file: not yet created
- Next: write FVSquad/OctetsMut.lean (Tasks 3–5)

## Open PRs / Branches
- `lean-squad-run52-24171018643-corr-targets-octetsmut` — in progress (run 52)
  - CORRESPONDENCE.md: Target 15 section added
  - TARGETS.md: Target 15→Phase 5, Target 16 added
  - specs/octets_informal.md: new

## Suite Status (run 52)
- **15 modules, 310 theorems, 0 sorry** (current master)
- Target 15 done; Target 16 at phase 2
- Lean 4.29.0, no Mathlib

## Key Technical Notes
- No Mathlib: use omega, simp, decide, rfl; no ring/linarith/norm_num
- listGet/listSet: define recursively (no List.get?)
- Big-endian get: use `256 * b0 + b1` NOT `b0 * 256 + b1` for omega compat
- u32 arithmetic: break 256*(65536*x+...) via intermediate have steps
- simp [Nat.div_add_mod] closes match + arithmetic in one shot
- Match reduction: simp (not congr) evaluates match on some X, some Y

## Next Targets
- OctetsMut: write FVSquad/OctetsMut.lean with round-trip + invariant theorems
- RecvBuf overlapping chunks (hardest; phase 4 → 5)
- CID byte-content uniqueness (security-critical per RFC 9000 §5.1)
