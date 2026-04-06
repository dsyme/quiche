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
### 9. Packet number decode — Phase 5 COMPLETE (24 theorems) — PR #32
### 10. CUBIC congestion control — Phase 5 COMPLETE (26 theorems) — PR #36
### 11. RangeBuf offset arithmetic
- Phase 5 COMPLETE (19 theorems, 0 sorry)
- Lean file: FVSquad/RangeBuf.lean

### 12. Stream receive buffer (RecvBuf)
- Phase 4 — Implementation (32 theorems, 0 sorry)
- Lean file: FVSquad/RecvBuf.lean
- emitN: fully proved (§5-§7, 21 theorems)
- insertContiguous: fully proved (§9, 11 theorems, run 44)
- Next: model general write() with overlap handling (sorry-guarded)

### 13. SendBuf stream send buffer — Phase 5 COMPLETE (run 45)
- **43 theorems, 0 sorry** — FVSquad/SendBuf.lean
- Key invariants: I1 ackOff≤emitOff, I2 emitOff≤off, I3 emitOff≤maxData (security!), I4 FIN consistency
- Key theorems: emitN_le_maxData, write_preserves_inv, sb_emitN_preserves_inv
- updateMaxData_preserves_inv, write_after_setFin_isFin_false
- NAMING NOTE: emitN_finOff → sb_emitN_finOff, emitN_preserves_inv → sb_emitN_preserves_inv
  (renamed to avoid conflict with RecvBuf.lean names)

### 14. Connection ID sequence management — Phase 1 Research
- File: quiche/src/cid.rs
- Key: next_scid_seq strictly monotone, no duplicate seqs, bounded active set
- Priority: MEDIUM — seq monotonicity easy; disjointness harder

## Open PRs / Branches
- PR #38 `lean-squad-run43` — RangeBuf.lean + RecvBuf.lean spec (21 theorems)
- PR #39 `lean-squad-run44` — RecvBuf.lean +11 insertContiguous, RESEARCH.md
- PR `lean-squad-run45-24042482889-sendbuf-spec-proofs` — SendBuf.lean (43 theorems)

## Key Lean 4.29.0 Learnings
- `le_or_lt` NOT available — use `Nat.lt_or_ge`
- `split_ifs` NOT available — use `split` or `by_cases`
- `push_neg` NOT available — use `omega`
- `simp only [range_insert_go.eq_def]` LOOPS — use `unfold`
- `lemma` keyword NOT available — use `theorem`
- `bif`, `at` are RESERVED KEYWORDS
- `conv_rhs`, `set`, `ring`, `linarith`, `nlinarith` NOT available (no Mathlib)
- omega handles Nat.div and Nat.min/max
- `simp only [f]` for a @[simp] lemma `f : e = e'` rewrites AND closes goal with assumption
  → Do NOT put `exact h` or `omega` after simp when simp might already close the goal
  → Use `show explicit_form; omega` to avoid false "no goals" errors
- `show t` changes goal to definitionally equal `t` — use to expose concrete arithmetic
- `cases h : (a == b)` with `| false => rfl | true => simp only [beq_iff_eq] at h; omega`
  is the pattern for Bool beq equality
- `subst h` with `h : f = e` (f is local var) works to substitute
- After `cases hf : s.finOff with | some f => ...`, goal has `s.finOff` replaced by `some f`
- `simp only [beq_iff_eq] at h` converts `h : (a == b) = true` to `h : a = b`
- `beq_self_eq_true` closes goals of form `a == a = true`
- NAME CONFLICTS: global namespace — prefix with `sb_` for SendBuf-specific names
  that might conflict with RecvBuf (emitN_finOff, emitN_preserves_inv)
- `write_off_le_maxData_of_cap` needs `hoff : s.off ≤ s.maxData` (not in invariant)
- `emitN_le_maxData` / `emitN_le_off` need the Inv as hypothesis (nat sub issue)
- For Nat subtraction `a - b`, omega only handles it correctly when `b ≤ a` is known

## Status Issue: #4 (open), updated run 45

## Summary
- **309 total theorems, 0 sorry** across 13 files
- Varint:10 | RangeSet:16 | Minmax:15 | RttStats:23 | FlowControl:22
  NewReno:13 | DatagramQueue:26 | PRR:20 | PacketNumDecode:24 | Cubic:26
  RangeBuf:19 | RecvBuf:32 | SendBuf:43

## Notes
- Aeneas: NOT available (no sudo/opam in sandbox — recurring)
- FVSquad.lean imports all 13 modules

## Next Priorities
1. **RecvBuf general write** — model write() with BTreeMap overlap handling
   using sorry-guarded abstract axiom; prove highMark monotonicity
2. **CID sequence management** — Target 14: next_scid_seq strictly monotone
3. **Correspondence/Critique update** — add SendBuf to CORRESPONDENCE.md + CRITIQUE.md
