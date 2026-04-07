# Lean Squad Memory — dsyme/quiche

## Tool & Approach
- **FV tool**: Lean 4 (v4.29.0, no Mathlib)
- **Project**: `formal-verification/lean/` — `lake init FVSquad` (no Mathlib)
- **CI**: `.github/workflows/lean-ci.yml` (added run 15; improved run 42)

## Targets

### 1. Varint encoding/decoding — Phase 5 COMPLETE (10 theorems) — PR #5
### 2. RangeSet sorted-interval — Phase 5 COMPLETE (16 theorems) — PR #22
### 3. Minmax filter — Phase 5 COMPLETE (15 theorems) — PR #15
### 4. RTT estimator — Phase 5 COMPLETE (23 theorems) — PR #23
### 5. Flow control — Phase 5 COMPLETE (22 theorems) — PR #26
### 6. Congestion window (NewReno) — Phase 5 COMPLETE (13 theorems) — PR #28
### 7. DatagramQueue — Phase 5 COMPLETE (26 theorems) — PR #29
### 8. PRR — Phase 5 COMPLETE (20 theorems) — PR #30
### 9. Packet number decode — Phase 5 COMPLETE (23 theorems) — PR #32
### 10. CUBIC congestion control — Phase 5 COMPLETE (26 theorems) — PR #36
### 11. RangeBuf offset arithmetic — Phase 5 COMPLETE (19 theorems)
### 12. Stream receive buffer (RecvBuf) — Phase 4 (29 theorems, 0 sorry)
- Lean file: FVSquad/RecvBuf.lean
- emitN: fully proved; insertContiguous: fully proved (in-order path only)
- Next: model general write() with overlap handling

### 13. SendBuf stream send buffer — Phase 5 COMPLETE (run 45)
- **26 theorems, 0 sorry** — FVSquad/SendBuf.lean
- Key: emitN_le_maxData (RFC 9000 §4.1 flow-control safety — security!)
- write_preserves_inv, sb_emitN_preserves_inv, write_possible_after_updateMaxData

### 14. Connection ID sequence management — Phase 5 COMPLETE (run 46)
- **21 theorems, 0 sorry** — FVSquad/CidMgmt.lean
- Informal spec: specs/cid_mgmt_informal.md
- CidInv: 5-part invariant (pos, distinct, bound, nonempty, size)
- Key: newScid_preserves_inv, retireScid_preserves_inv
- Security: newScid_seq_fresh (no CID reuse), retireScid_removes
- Monotonicity: applyNewScid_nextSeq_strict

## Open PRs / Branches
- PR #38 `lean-squad-run43` — RangeBuf.lean + RecvBuf.lean spec (content in master)
- PR #39 `lean-squad-run44` — RecvBuf.lean +11 insertContiguous (content in master)
- Branch `lean-squad-run46-24063078253-cid-critique-run46` — CidMgmt (run 46, pending)

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available — use `Nat.lt_or_ge`
- `split_ifs` NOT available — use `split` or `by_cases`
- `push_neg` NOT available — use `simp only [not_or]` or manual `intro` + cases
- `simp only [range_insert_go.eq_def]` LOOPS — use `unfold`
- `lemma` keyword NOT available — use `theorem`
- `bif`, `at` are RESERVED KEYWORDS
- `conv_rhs`, `set`, `ring`, `linarith`, `nlinarith` NOT available (no Mathlib)
- `tauto` NOT available — use manual case splits or `simp`
- `List.not_mem_nil` takes NO explicit args in Lean 4.29 (implicit `{a}`)
- `List.mem_cons_self` takes NO explicit args (type `a ∈ a :: l`)
- `List.mem_of_mem_filter` does NOT exist — use `(List.mem_filter.mp h).1`
- `simp only [List.mem_cons, not_or] at h` decomposes `x ∉ a :: t` into `x ≠ a ∧ x ∉ t`
- omega handles `2 * n - 1 ≥ 1` when `n ≥ 1` BUT needs `simp only [f] at *`
  on all occurrences (not just hypothesis) so goal is fully reduced
- `simp only [initState] at *` required to unfold struct in BOTH goal and hyps
- `allDistinct : List Nat → Prop` best defined as `| [] => True | x :: xs => x ∉ xs ∧ allDistinct xs`
- `List.filter (· ≠ seq)` works for filtering by inequality
- `by simp [hne]` closes `decide (n ≠ seq) = true` when `hne : n ≠ seq`

## Status Issue: #4 (open), updated run 45
## Theorem Count (run 46)
- 14 files, 289 named theorems, 0 sorry
- CidMgmt:21 | Cubic:26 | DatagramQueue:26 | FlowControl:22 | Minmax:15
  NewReno:13 | PRR:20 | PacketNumDecode:23 | RangeBuf:19 | RangeSet:16
  RecvBuf:29 | RttStats:23 | SendBuf:26 | Varint:10

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox — recurring)
- FVSquad.lean imports all 14 modules

## Next Priorities
1. **RecvBuf general write** — model write() with BTreeMap overlap handling
   using sorry-guarded abstract axiom; prove highMark monotonicity
2. **CRITIQUE/CORRESPONDENCE maintenance** — done in run 46; revisit after next batch
3. **Stream-level flow control** — per-stream window analogous to FlowControl.lean
4. **NewReno AIMD multi-callback rate** — exact growth rate over N ACK callbacks
