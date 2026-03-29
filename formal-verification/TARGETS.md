# FV Targets — quiche

> 🔬 *Maintained by Lean Squad automated formal verification.*

## Priority Order

| # | Target | Location | Phase | Status | Notes |
|---|--------|----------|-------|--------|-------|
<<<<<<< HEAD
| 1 | QUIC varint codec | `octets/src/lib.rs` | 5 — Proofs | ✅ Done | **0 sorry** — all 10 theorems proved (round_trip, first_byte_tag, etc.) |
| 2 | `RangeSet` invariants | `quiche/src/ranges.rs` | 3 — Lean Spec | 🔄 In progress | `FVSquad/RangeSet.lean` written; 5 sorry (deferred proofs) |
| 3 | RTT estimation | `quiche/src/recovery/rtt.rs` | 1 — Research | ⬜ Not started | RFC 9002 §5 EWMA update |
=======
| 1 | QUIC varint codec | `octets/src/lib.rs` | 5 — Proofs | ✅ Done (PR #5) | 10 theorems, 0 sorry |
| 2 | `RangeSet` invariants | `quiche/src/ranges.rs` | 3 — Lean Spec | 🔄 In progress (PR #6) | Spec done; 5 sorry pending Task 5 |
| 3 | RTT estimation | `quiche/src/recovery/rtt.rs` | 5 — Proofs | ✅ Done (run 6) | 21 theorems, 0 sorry — RFC 9002 §5 |
>>>>>>> 4185f66e93c55c1c38324b2b768d8ade86d74428
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

<<<<<<< HEAD
1. **Prove** deferred RangeSet theorems (Target 2) — Task 5
   - `insert_preserves_invariant`: structural induction on the list
   - `insert_covers_union`: the key I3 union property
   - `remove_until_*`: three theorems about the prefix-removal operation
2. **Write Lean spec** for Target 3 (RTT estimation) — Task 3
3. **Write informal spec** for Target 3 (RTT estimation) — Task 2
=======
1. **Task 5**: Prove the 5 remaining RangeSet theorems (PR #6 branch)
2. **Task 2/3**: Write informal spec + Lean spec for Target 4 (flow control)
3. **Task 6**: Write CORRESPONDENCE.md linking all Lean models to Rust source
4. **Task 7**: Write CRITIQUE.md assessing proof utility
>>>>>>> 4185f66e93c55c1c38324b2b768d8ade86d74428

## Archived Targets

*(None yet — targets move here when phase 5 is complete and PR is merged.)*

## Completed Targets (awaiting PR merge)

| # | Target | Phase | PR | Notes |
|---|--------|-------|----|-------|
| 1 | QUIC varint codec | 5 — All Proofs | PR #5 (open) | round_trip + first_byte_tag proved; 0 sorry |
