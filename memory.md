# Lean Squad Memory — dsyme/quiche

## Last updated
Run 180 (workflow 26224153039, 2026-05-21)

## FV Toolchain
- Lean 4.29.1 (elan stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)
- Key tactic notes:
  - No `split_ifs`, `push_neg`, `rcases` without Mathlib
  - Use `by_cases h : cond <;> simp [h] <;> omega` for if-then-else goals
  - Use `cases Or.inl/inr` for Or goals instead of rcases
  - `Nat.lt_or_ge b a` gives `inl : b < a | inr : a ≤ b` (note direction!)

## Repository State (after run 180)
- Lean files: 72
- Total theorems: 1391 (1367 + 24)
- Total sorry: 0
- Route-B test targets: 30

## Open PRs (lean-squad label) — as of run 180
- PR #146: T73 BBR2CyclePhaseGain (stale conflict — content already in master)
- PR created this run: T79 VarIntLength (branch lean-squad-run180-26224153039-varint-len-t79)

## CI Status
- lean-ci.yml: exists, healthy, passing
- lean-toolchain: v4.29.0
- Triggers: PR + push on formal-verification/lean/**

## Targets

### T79: VarIntLength monotonicity (run 180, DONE)
- Phase: 5 (Done — 24 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/VarIntLength.lean
- Source: octets/src/lib.rs (varint_len L810-822)
- Key theorems: varint_len_monotone, varint_len_in_set, varint_len_inv_monotone
- Route-B: formal-verification/tests/varint_len/ — 25/25 PASS

### T78: BBR2ProbeBWCycle (run 179, research)
- Phase: 1 — Research
- Source: quiche/src/recovery/gcongestion/bbr2/probe_bw.rs (transitions)
- Key: Down→Cruise/Refill→Refill→Up→Down ordering; finite state machine
- Next: write FVSquad/BBR2ProbeBWCycle.lean

### T77: BBR2InflightHiSlope (run 179, DONE)
- Phase: 5 (Done — 19 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2InflightHiSlope.lean
- Source: probe_bw.rs L582-590 (raise_inflight_high_slope)

### T76: BBR2ModeState (run 177)
- Phase: 5 (Done — 19 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2ModeState.lean
- Route-B: formal-verification/tests/bbr2_mode_state/ — 91/91 PASS

### T75: BBR2DrainExit (run 176)
- Phase: 5 (Done — 17 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2DrainExit.lean
- Route-B: formal-verification/tests/bbr2_drain_exit/ — 23/23 PASS

### Earlier targets (T1-T74): All phase 5 (Done)

## Route-B Tests (30 targets total, 1709+ cases, all PASS)

## Next Run Priorities
1. T78: BBR2ProbeBWCycle abstract state machine (MEDIUM)
2. REPORT.md update to cover runs 167–180
3. CORRESPONDENCE.md update for T77, T79
4. Close PR #146 (stale, content already in master)
