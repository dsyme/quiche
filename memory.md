# Lean Squad Memory — dsyme/quiche

**Last updated**: 2026-03-27 18:26 UTC  
**Commit**: 2460849b432802416238f29661f35d6630557e87  
**Run**: https://github.com/dsyme/quiche/actions/runs/23661208608

## FV Targets

| # | Target | Location | Phase | Open PRs/Issues | Notes |
|---|--------|----------|-------|-----------------|-------|
| 1 | varint codec | `octets/src/lib.rs` | 2 — Informal Spec | PR (lean-squad-research-run1) | Highest priority; pure functions |
| 2 | RangeSet invariants | `quiche/src/ranges.rs` | 1 — Research | — | Sorted/non-overlapping |
| 3 | RTT estimation | `quiche/src/recovery/rtt.rs` | 1 — Research | — | RFC 9002 §5 EWMA |
| 4 | Flow control | `quiche/src/flowcontrol.rs` | 1 — Research | — | Arithmetic invariants |
| 5 | Minmax filter | `quiche/src/minmax.rs` | 1 — Research | — | Windowed min/max |

## Tool Choice

- **Lean 4** with Mathlib
- Aeneas extraction: worth attempting for varint and flowcontrol once hand-written specs exist

## Key Files

- `formal-verification/RESEARCH.md` — target survey
- `formal-verification/TARGETS.md` — phase tracking
- `formal-verification/specs/varint_informal.md` — informal spec for varint

## Varint Codec (Target 1) — Notes

- `varint_len(v: u64) -> usize`: pure, 4-branch, decidable
- `varint_parse_len(first: u8) -> usize`: pure, 4-case on `first >> 6`, decidable
- Round-trip: `decode(encode(v)) = v` for all `v ≤ MAX_VAR_INT`
- Key property: `varint_parse_len(first_byte_of_encode(v)) = varint_len(v)`
- `MAX_VAR_INT = 4_611_686_018_427_387_903 = 2^62 - 1`
- Open Q: non-minimal encodings accepted silently — is this intentional?
- Open Q: no checked variant for `v > MAX_VAR_INT` (panics)

## Run History

### 2026-03-27 — Run 23661208608
- Tasks executed: Task 1 (Research), Task 2 (Informal Spec — varint)
- Tasks selected by weighting: 9, 4 (substituted → 1, 2 since no Lean work exists)
- PR created: lean-squad-research-run1 (draft)
- Lean not yet installed (Tasks 3+ deferred)
- No bugs found yet

## CI Status

- `lean-ci.yml`: not yet created (no Lean files exist yet — Task 9 deferred)
- Lean toolchain: not yet installed

## Next Run Priorities

1. Install Lean 4, write Lean spec (Task 3) for varint codec
2. Implement Lean functional model (Task 4) for varint codec
3. Attempt proofs (Task 5): round-trip property, `varint_len` correctness
