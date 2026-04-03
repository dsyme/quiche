# FV Targets — quiche

> 🔬 *Maintained by Lean Squad automated formal verification.*

## Priority Order

| # | Target | Location | Phase | Status | Notes |
|---|--------|----------|-------|--------|-------|
| 1 | QUIC varint codec | `octets/src/lib.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 10 theorems; PR #5 merged |
| 2 | `RangeSet` invariants | `quiche/src/ranges.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 14 theorems incl. `insert_preserves_invariant`; PR #22 merged |
| 3 | Minmax filter | `quiche/src/minmax.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 15 theorems; PR #15 merged |
| 4 | RTT estimation | `quiche/src/recovery/rtt.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 24 theorems incl. `adjusted_rtt_ge_min_rtt`; `FVSquad/RttStats.lean` |
| 5 | Flow control | `quiche/src/flowcontrol.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 22 theorems; `FVSquad/FlowControl.lean`; informal spec in `specs/flowcontrol_informal.md` |
| 6 | Congestion window (NewReno) | `quiche/src/recovery/congestion/reno.rs` | 2 — Informal Spec | 🔄 In progress | Informal spec written (run 33): `specs/congestion_informal.md` |

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

1. **Congestion window** (Target 6) — informal spec written (run 33); next: write
   Lean spec (`FVSquad/NewReno.lean`) for window-floor and AIMD properties
2. **Stream flow control** — similar to flowcontrol.rs but per-stream; reuse FlowControl model
3. **RangeSet semantic completeness** — prove flatten(insert(rs,r)) = set_union; see CRITIQUE.md

## Archived / Completed Targets

| # | Target | Phase | PR | Notes |
|---|--------|-------|----|-------|
| 1 | QUIC varint codec | 5 — All Proofs | PR #5 (merged) | round_trip + 9 others; 0 sorry |
| 2 | RangeSet invariants | 5 — All Proofs | PR #22 (merged) | insert_preserves_invariant + 13 others; 0 sorry |
| 3 | Minmax filter | 5 — All Proofs | PR #15 (merged) | 15 theorems; 0 sorry |
