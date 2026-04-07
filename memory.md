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

### 15. StreamPriorityKey::cmp ordering — Phase 2 (Informal Spec, run 48)
- Informal spec: specs/stream_priority_key_informal.md
- TARGETS.md: added as Target 15
- **Open Question OQ-1**: non-antisymmetry for incremental-incremental case
  (a.cmp(b) = Greater AND b.cmp(a) = Greater when both incremental,
  same urgency, different ID) — potential Ord contract violation in Rust
- Next: write FVSquad/StreamPriorityKey.lean; prove Ord laws; verify OQ-1

## Open PRs / Branches
- Branch `lean-squad-run48-24095505289-corr-research` — CORRESPONDENCE+CRITIQUE+Target15 (run 48, new)

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
- For `Ordering`: use `Ordering.lt`, `Ordering.eq`, `Ordering.gt` (or `.lt` etc. with dot notation)
- `Ordering.lt.cmp` etc. not available — use `compare` or `decide` on `Ordering` values

## Status Issue: #4 (open), updated run 46
## Theorem Count (run 48)
- 14 files, 289 named theorems + 12 examples, 0 sorry
- CidMgmt:21 | Cubic:26 | DatagramQueue:26 | FlowControl:22
  Minmax:15 | NewReno:13 | PRR:20 | PacketNumDecode:23 | RangeBuf:19
  RangeSet:16 | RecvBuf:29 | RttStats:23 | SendBuf:26 | Varint:10

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox — recurring)
- FVSquad.lean imports all 14 modules

## Next Priorities
1. **StreamPriorityKey Lean spec** — write FVSquad/StreamPriorityKey.lean;
   model the 7-case ordering; prove Ord laws; INVESTIGATE OQ-1 non-antisymmetry
2. **RecvBuf general write** — model write() with BTreeMap overlap handling
3. **RangeSet semantic completeness** — flatten(insert(rs,r)) = set_union
