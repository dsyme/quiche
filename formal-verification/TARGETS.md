# FV Targets — quiche

> 🔬 *Maintained by Lean Squad automated formal verification.*

## Priority Order

| # | Target | Location | Phase | Status | Notes |
|---|--------|----------|-------|--------|-------|
| 1 | QUIC varint codec | `octets/src/lib.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 10 theorems proved; PR #5 merged |
| 2 | `RangeSet` invariants | `quiche/src/ranges.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 14 theorems proved incl. `insert_preserves_invariant`; PR #22 merged |
| 3 | Minmax filter | `quiche/src/minmax.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 15 theorems proved; PR #15 merged |
| 4 | RTT estimation | `quiche/src/recovery/rtt.rs` | 3 — Lean Spec | 🔄 In progress | `FVSquad/RttStats.lean` written; 18 theorems proved (0 sorry); informal spec in `specs/rtt_informal.md` |
| 5 | Flow control | `quiche/src/flowcontrol.rs` | 1 — Research | ⬜ Not started | Arithmetic window invariants |

## Phase Definitions

| Phase | Name | Description |
|-------|------|-------------|
| 0 | Identified | Added to this list |
| 1 | Research | Surveyed; benefit, tractability, approach documented in RESEARCH.md |
| 2 | Informal Spec | `specs/<name>_informal.md` written |
| 3 | Lean Spec | Lean 4 file with type definitions, theorem statements, and implementation model |
| 4 | Implementation | Lean functional model with implementation details extracted |
| 5 | Proofs | Key theorems proved (or counterexamples found) — 0 sorry |

## Next Actions

1. **Advance RTT estimation** to phase 4/5 — implementation model already in `RttStats.lean`;
   expand proofs of EWMA convergence and per-update invariant preservation
2. **Write informal spec** for Flow control (Target 5) — Task 2
3. **Write Lean spec** for Flow control (Target 5) — Task 3

## Archived / Completed Targets

| # | Target | Phase | PR | Notes |
|---|--------|-------|----|-------|
| 1 | QUIC varint codec | 5 — All Proofs | PR #5 (merged) | round_trip + 9 others; 0 sorry |
| 2 | RangeSet invariants | 5 — All Proofs | PR #22 (merged) | insert_preserves_invariant + 13 others; 0 sorry |
| 3 | Minmax filter | 5 — All Proofs | PR #15 (merged) | 15 theorems; 0 sorry |
