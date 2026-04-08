# Lean Squad Memory — dsyme/quiche

## Tool & Approach
- **FV tool**: Lean 4 (v4.29.0, no Mathlib)
- **Project**: `formal-verification/lean/` — `lake init FVSquad` (no Mathlib)
- **CI**: `.github/workflows/lean-ci.yml` (added run 15; improved run 42)

## Targets

### 1–10: Phase 5 COMPLETE (see archived targets in TARGETS.md)
### 11. RangeBuf offset arithmetic — Phase 5 COMPLETE (19 theorems)
### 12. Stream receive buffer (RecvBuf) — Phase 4 (35 theorems, 0 sorry)
- Lean file: FVSquad/RecvBuf.lean
- emitN + insertContiguous fully proved; insertAny general model added
- Next: extend to overlapping chunks (hardest part)

### 13. SendBuf stream send buffer — Phase 5 COMPLETE (run 45)
- **43 theorems, 0 sorry** — FVSquad/SendBuf.lean

### 14. Connection ID sequence management — Phase 5 COMPLETE (run 46)
- **21 theorems, 0 sorry** — FVSquad/CidMgmt.lean

### 15. StreamPriorityKey::cmp ordering — Phase 5 COMPLETE (run 49)
- **22 theorems + 7 examples, 0 sorry** — FVSquad/StreamPriorityKey.lean
- OQ-1 FORMALLY PROVED: cmpKey_incr_incr_not_antisymmetric (Ord violation)
- PR #44 merged

### 16. OctetsMut byte-buffer read/write — Phase 5 COMPLETE (run 51)
- **18 theorems, 0 sorry** — FVSquad/OctetsMut.lean
- Round-trip: putU8/U16/U32 write→rewind→read recovers original value
- Cursor inverses: skip_rewind_inverse, rewind_skip_inverse
- Invariant: putU8_preserves_inv, cap_plus_off_eq_len
- Informal spec: specs/octets_informal.md
- PR: lean-squad-run51-24149866820-octetsmut (pending push — safeoutputs MCP failed)

## Open PRs / Branches
- PR #43 (run 48): merged into master (fast-forward, CRITIQUE.md only)
- PR #44 (run 49): merged — StreamPriorityKey
- `lean-squad-run51-24149866820-octetsmut` — OctetsMut (committed, PR creation failed)

## Suite Status (run 51)
- **16 modules, 351 theorems, 25 examples, 0 sorry**
- Lean 4.29.0, no Mathlib

## Key Technical Notes
- No Mathlib: use omega, simp, decide, rfl; no ring/linarith/norm_num
- listGet/listSet: define recursively (no List.get?)
- Big-endian get: use `256 * b0 + b1` NOT `b0 * 256 + b1` for omega compat
- u32 arithmetic: break 256*(65536*x+...) via intermediate have steps
- simp [Nat.div_add_mod] closes match + arithmetic in one shot
- Match reduction: simp (not congr) evaluates match on some X, some Y

## Next Targets
- RecvBuf overlapping chunks (hardest; phase 4 → 5)
- OctetsMut: add put_u64 model, add range preconditions (OQ-1)
- CID byte-content uniqueness (security-critical per RFC 9000 §5.1)
