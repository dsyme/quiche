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
- emitN: fully proved; insertContiguous: fully proved (in-order path only)
- Next: model general write() with overlap handling

### 13. SendBuf stream send buffer — Phase 5 COMPLETE (run 45)
- **26 theorems, 0 sorry** — FVSquad/SendBuf.lean

### 14. Connection ID sequence management — Phase 5 COMPLETE (run 46)
- **21 theorems, 0 sorry** — FVSquad/CidMgmt.lean

### 15. QUIC MAX_STREAMS limit tracking — Phase 5 COMPLETE (run 47)
- **24 theorems + 11 examples, 0 sorry** — FVSquad/StreamLimits.lean
- Informal spec: specs/stream_limits_informal.md
- StreamLimitsInv: 4-part invariant (localMax≤localNext, peerOpened≤localMax,
  localOpened≤peerMax, initial≤localNext)
- Key: acceptStream_safety, createStream_safety (RFC 9000 §4.6)
- shouldUpdate: 3 theorems specifying when MAX_STREAMS frame is needed
- collect_accumulates: k collects → localNext += k
- stream ID encoding helpers: isBidiStream, isLocalStream, streamSeq

## Open PRs / Branches
- PR #38 `lean-squad-run43` — RangeBuf.lean + RecvBuf.lean spec
- PR #39 `lean-squad-run44` — RecvBuf.lean insertContiguous (content in master)
- PR #41 `lean-squad-run46` — CidMgmt (pending)
- Branch `lean-squad-run47-24075167284-stream-limits` — StreamLimits (run 47, new)

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
- `split` on `Nat.max_def`: case 1 is `a ≤ b` → max = b; case 2 is `¬(a ≤ b)` → max = a
  (ORDER MATTERS: case 1 is the `≤` branch, NOT the else branch)
- `native_decide` works on `Bool`/concrete computations but NOT on `Prop` directly
  — for invariant test vectors use `simp [InvDef, initDef]` or `decide`

## Status Issue: #4 (open), updated run 46
## Theorem Count (run 47)
- 15 files, 313 named theorems + 11 examples, 0 sorry
- StreamLimits:24 | CidMgmt:21 | Cubic:26 | DatagramQueue:26 | FlowControl:22
  Minmax:15 | NewReno:13 | PRR:20 | PacketNumDecode:23 | RangeBuf:19
  RangeSet:16 | RecvBuf:29 | RttStats:23 | SendBuf:26 | Varint:10

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox — recurring)
- FVSquad.lean imports all 15 modules

## Next Priorities
1. **RecvBuf general write** — model write() with BTreeMap overlap handling
2. **Stream priority ordering** — StreamPriorityKey::cmp (urgency/incremental)
3. **CORRESPONDENCE.md** — add StreamLimits (target 15) entry
4. **CRITIQUE.md** — add assessment for StreamLimits
