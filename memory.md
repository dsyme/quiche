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
- emitN: fully proved; insertContiguous: fully proved (in-order path)
- insertAny: general out-of-order write model — run 50 ✅
  - noOverlapWith, insertChunkAt, RecvBuf.insertAny
  - insertAny_inv: full invariant preservation
- Next: extend to overlapping chunks (hardest part)

### 13. SendBuf stream send buffer — Phase 5 COMPLETE (run 45)
- **26 theorems, 0 sorry** — FVSquad/SendBuf.lean

### 14. Connection ID sequence management — Phase 5 COMPLETE (run 46)
- **21 theorems, 0 sorry** — FVSquad/CidMgmt.lean

### 15. StreamPriorityKey::cmp ordering — Phase 5 COMPLETE (run 49)
- **22 theorems + 7 examples, 0 sorry** — FVSquad/StreamPriorityKey.lean
- OQ-1 FORMALLY PROVED: cmpKey_incr_incr_not_antisymmetric
- TARGETS.md updated to phase 5 (run 50)

### 16. OctetsMut byte-buffer read/write — Phase 2 (Informal Spec)
- Informal spec: specs/octets_informal.md (run 50)
- Key properties: put-then-get round-trip, cursor arithmetic, big-endian
- Open questions: OQ-1 rewind safety, OQ-2 put_u24 truncation, OQ-3 unsafe
- Next: write FVSquad/OctetsMut.lean (phase 3)

## Open PRs / Branches
- `lean-squad-run50-24129104910-recvbuf-octets-2` — RecvBuf insertAny + OctetsMut (run 50, new)
- PRs #43 (run 48) and #44 (run 49) still open upstream

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available — use `Nat.lt_or_ge`
- `split_ifs` NOT available — use `split` or `by_cases`
- `push_neg` NOT available — use manual `intro` + cases
- `lemma` keyword NOT available — use `theorem`
- `bif`, `at` are RESERVED KEYWORDS
- `conv_rhs`, `set`, `ring`, `linarith`, `nlinarith` NOT available (no Mathlib)
- `tauto` NOT available — use manual case splits or `simp`
- `le_refl` → use `Nat.le_refl`
- `Nat.le_max_of_le_left` NOT available → use `Nat.le_trans hi (Nat.le_max_left _ _)`
- `Nat.rec` in theorems is tricky — define helper function instead
- `native_decide` works on Bool/concrete computations but NOT on Prop directly
- `List.mem_cons_self d rest` NOT available as function call in 4.29.0
  → use `List.Mem.head rest` for `d ∈ d :: rest`
  → use `List.Mem.tail d he` for `e ∈ d :: rest` where `he : e ∈ rest`
- For Ordering: use `Ordering.lt`, `Ordering.eq`, `Ordering.gt`

## Status Issue: #4 (open), updated run 50
## Theorem Count (run 50)
- 15 files, 317 named theorems + 24 examples, 0 sorry
- CidMgmt:21 | Cubic:26 | DatagramQueue:26 | FlowControl:22
  Minmax:15 | NewReno:13 | PRR:20 | PacketNumDecode:23 | RangeBuf:19
  RangeSet:16 | RecvBuf:35+17ex | RttStats:23 | SendBuf:26 | Varint:10
  StreamPriorityKey:22+7ex

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox — recurring)
- FVSquad.lean imports all 15 modules

## Next Priorities
1. **OctetsMut Lean spec** — write FVSquad/OctetsMut.lean with put_uN/get_uN
   model and round-trip theorem (put_uN; rewind; get_uN = identity)
2. **RecvBuf overlap handling** — extend insertAny to trim/split overlapping
   chunks (full Rust write() path)
3. **RangeSet semantic completeness** — flatten(insert(rs,r)) = set_union
