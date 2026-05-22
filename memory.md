# Lean Squad Memory — dsyme/quiche

## Last updated
Run 182 (workflow 26268953159, 2026-05-21)

## FV Toolchain
- Lean 4.29.1 (elan stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)
- Key tactic notes:
  - No `split_ifs`, `push_neg`, `rcases` without Mathlib
  - Use `by_cases h : cond <;> simp [h] <;> omega` for if-then-else goals
  - Use `cases Or.inl/inr` for Or goals instead of rcases
  - `Nat.lt_or_ge b a` gives `inl : b < a | inr : a ≤ b` (note direction!)
  - Each file needs its own namespace to avoid CyclePhase name clashes

## Repository State (after run 182)
- Lean files: 74
- Total theorems: 1443
- Total sorry: 0
- Route-B test targets: 23

## Open PRs (lean-squad label) — as of run 182
- PR #146: T73 BBR2CyclePhaseGain — STALE (content already in master as BBR2CyclePhaseGain.lean)
- PR created run 182: T80 BBR2BandwidthGrowth + REPORT update (branch lean-squad-run182-26268953159-bbr2-bandwidth-growth-t80)

## CI Status
- lean-ci.yml: exists, healthy, passing
- lean-toolchain: v4.29.0
- Triggers: PR + push on formal-verification/lean/**

## Targets

### T80: BBR2 has_bandwidth_growth (run 182, DONE)
- Phase: 5 (Done — 20 thms, 0 sorry)
- Source: quiche/src/recovery/gcongestion/bbr2/network_model.rs L630–686
- File: formal-verification/lean/FVSquad/BBR2BandwidthGrowth.lean
- Key: monotone baseline, counter monotonicity, app-limited guard, monotone full_bw_reached, is_valid guard
- Notes: T55 (BBR2StartupExit) already modeled hasBandwidthGrowth w/o is_valid guard; T80 complements with full model

### T79: VarIntLength monotonicity (run 180, DONE)
- Phase: 5 (Done — 24 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/VarIntLength.lean
- Source: octets/src/lib.rs (varint_len L810-822)
- Route-B: formal-verification/tests/varint_len/ — 25/25 PASS

### T78: BBR2ProbeBWCycle (run 181, DONE)
- Phase: 5 (Done — 32 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2ProbeBWCycle.lean
- Source: quiche/src/recovery/gcongestion/bbr2/probe_bw.rs (L60-445) + mode.rs (L48-56)
- Namespace: FVSquad.BBR2ProbeBWCycle (avoids CyclePhase collision with ProbeBWPhase)
- Key theorems: down/cruise/refill/up_successors, cycle_strongly_connected (4 steps), probing_successor_options

### T77: BBR2InflightHiSlope (run 179, DONE)
- Phase: 5 (Done — 19 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2InflightHiSlope.lean

### T76: BBR2ModeState (run 177, DONE)
- Phase: 5 (Done — 19 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2ModeState.lean
- Route-B: formal-verification/tests/bbr2_mode_state/ — 91/91 PASS

### T75: BBR2DrainExit (run 176, DONE)
- Phase: 5 (Done — 17 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2DrainExit.lean
- Route-B: formal-verification/tests/bbr2_drain_exit/ — 23/23 PASS

### Earlier targets (T1-T74): All phase 5 (Done)

## Route-B Tests (31 targets total, 1734+ cases, all PASS)
(includes varint_len 25/25, bbr2_mode_state 91/91, bbr2_drain_exit 23/23, etc.)

## Next Run Priorities
1. CORRESPONDENCE.md update for T77, T78, T79, T80
2. Close PR #146 (stale — content already in master)
3. Route-B tests for T78 BBR2ProbeBWCycle
4. Task 1: identify T81 — next BBR2/QUIC target
