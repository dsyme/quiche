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
- CORRESPONDENCE.md updated: run 48
- CRITIQUE.md updated: run 48

### 15. StreamPriorityKey::cmp ordering — Phase 5 COMPLETE (run 49)
- **22 theorems + 7 examples, 0 sorry** — FVSquad/StreamPriorityKey.lean
- lake build PASSED (Lean 4.29.0)
- **OQ-1 FORMALLY PROVED**: cmpKey_incr_incr_not_antisymmetric
  Both-incremental same-urgency case: a.cmpKey(b) = .gt AND b.cmpKey(a) = .gt
  simultaneously. Ord antisymmetry violated. Intentional round-robin design
  but formally a contract deviation.
- CRITIQUE.md updated: run 49 (StreamPriorityKey section + OQ-1 finding)

## Open PRs / Branches
- `lean-squad-run49-24116453994-streampriority-critique` — StreamPriorityKey + CRITIQUE (run 49, new)

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
- `native_decide` works on `Bool`/concrete computations but NOT on `Prop` directly
- For `Ordering`: use `Ordering.lt`, `Ordering.eq`, `Ordering.gt` (dot notation: `.lt` etc.)
- `compare m n = .lt ↔ m < n`: prove by `simp [compare, compareOfLessAndEq, h]`
  — DO NOT write helper lemmas for this; inline the proof using simp
- For `if a.id == b.id` (beq) with `hid : a.id ≠ b.id`: use `simp [cmpKey, hid]`
  — simp connects `==` (BEq) with `≠` (Ne) via `beq_iff_eq`

## Status Issue: #4 (open), updated run 49
## Theorem Count (run 49)
- 15 files, 311 named theorems + 19 examples, 0 sorry
- CidMgmt:21 | Cubic:26 | DatagramQueue:26 | FlowControl:22
  Minmax:15 | NewReno:13 | PRR:20 | PacketNumDecode:23 | RangeBuf:19
  RangeSet:16 | RecvBuf:29 | RttStats:23 | SendBuf:26 | Varint:10
  StreamPriorityKey:22+7ex

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox — recurring)
- FVSquad.lean imports all 15 modules

## Next Priorities
1. **RecvBuf general write** — model write() with BTreeMap overlap handling
2. **OQ-1 maintainer response** — wait for maintainer input on intrusive-collections
   RBTree safety under non-antisymmetric comparator
3. **RangeSet semantic completeness** — flatten(insert(rs,r)) = set_union
