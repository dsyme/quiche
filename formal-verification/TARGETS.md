# FV Targets — quiche

> 🔬 *Maintained by Lean Squad automated formal verification.*

## Priority Order

| # | Target | Location | Phase | Status | Notes |
|---|--------|----------|-------|--------|-------|
| 1 | QUIC varint codec | `octets/src/lib.rs` | 1 — Research | ✅ Done | Highest priority; pure functions, round-trip property |
| 2 | `RangeSet` invariants | `quiche/src/ranges.rs` | 1 — Research | ✅ Done | Sorted/non-overlapping invariant |
| 3 | RTT estimation | `quiche/src/recovery/rtt.rs` | 1 — Research | ✅ Done | RFC 9002 §5 EWMA update |
| 4 | Flow control | `quiche/src/flowcontrol.rs` | 1 — Research | ✅ Done | Arithmetic invariants |
| 5 | Minmax filter | `quiche/src/minmax.rs` | 1 — Research | ✅ Done | Windowed min/max |

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

1. **Write informal spec** for Target 1 (varint codec) — `specs/varint_informal.md`
2. **Write Lean spec** for Target 1 — requires Lean 4 / lake setup
3. **Write informal spec** for Target 2 (RangeSet)

## Archived Targets

*(None yet — targets stay here until phase 5 is complete.)*
