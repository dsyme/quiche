# FV Targets — quiche

> 🔬 *Maintained by Lean Squad automated formal verification.*

## Priority Order

| # | Target | Location | Phase | Status | Notes |
|---|--------|----------|-------|--------|-------|
| 1 | QUIC varint codec | `octets/src/lib.rs` | 5 — Proofs | ✅ Done (PR #5) | 10 theorems, 0 sorry |
| 2 | `RangeSet` invariants | `quiche/src/ranges.rs` | 5 — Proofs | 🔄 In progress (run 11) | 3 new theorems proved; 2 sorry (insert_* require accumulator induction) |
| 3 | RTT estimation | `quiche/src/recovery/rtt.rs` | 5 — Proofs | ✅ Done (run 6) | 21 theorems, 0 sorry — RFC 9002 §5 |
| 4 | Flow control | `quiche/src/flowcontrol.rs` | 1 — Research | ⬜ Not started | Arithmetic invariants |
| 5 | Minmax filter | `quiche/src/minmax.rs` | 1 — Research | ⬜ Not started | Windowed min/max |

## Phase Definitions

| Phase | Name | Description |
|-------|------|-------------|
| 0 | Identified | Added to this list |
| 1 | Research | Surveyed; benefit, tractability, approach documented in RESEARCH.md |
| 2 | Informal Spec | `specs/<name>_informal.md` written |
| 3 | Lean Spec | Lean 4 file with type definitions and theorem statements (sorry proofs) |
| 4 | Implementation | Lean functional model of the Rust code |
| 5 | Proofs | Key theorems proved (or counterexamples found) |

## Next Actions

1. **Task 5**: Prove `insert_preserves_invariant` and `insert_covers_union` (require accumulator induction on `range_insert_go`)
2. **Task 2/3**: Write informal spec + Lean spec for Target 4 (flow control)
3. **Task 6**: Write CORRESPONDENCE.md linking all Lean models to Rust source
4. **Task 7**: Write CRITIQUE.md assessing proof utility

## Archived Targets

*(None yet — targets stay here until phase 5 is complete.)*
