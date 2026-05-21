# Lean Squad Memory — dsyme/quiche

## Last updated
Run 181 (workflow 26245098026, 2026-05-21)

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

## Repository State (after run 181)
- Lean files: 73
- Total theorems: ~1423 (1391 + 32)
- Total sorry: 0
- Route-B test targets: 31

## Open PRs (lean-squad label) — as of run 181
- PR #146: T73 BBR2CyclePhaseGain — STALE (content already in master as BBR2CyclePhaseGain.lean)
- PR #153: T77 BBR2InflightHiSlope — content merged into run181 branch
- PR #154: T79 VarIntLength — content merged into run181 branch
- PR created this run: T78 BBR2ProbeBWCycle + T80 informal spec (branch lean-squad-run181-26245098026-bbr2-probe-bw-cycle-t78)

## CI Status
- lean-ci.yml: exists, healthy, passing
- lean-toolchain: v4.29.0
- Triggers: PR + push on formal-verification/lean/**

## Targets

### T80: BBR2 has_bandwidth_growth (run 181, informal spec)
- Phase: 2 — Informal Spec
- Source: quiche/src/recovery/gcongestion/bbr2/network_model.rs L630–686
- File: formal-verification/specs/bbr2_bandwidth_growth_informal.md
- Key: monotone baseline, counter monotonicity, app-limited guard, monotone full_bw_reached
- OQs: T80-1 (invalid send state semantics), T80-2 (u64 overflow), T80-3 (interaction with check_persistent_queue)
- Next: write FVSquad/BBR2BandwidthGrowth.lean

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
1. T80: Write FVSquad/BBR2BandwidthGrowth.lean (~20-25 thms, omega)
2. CORRESPONDENCE.md update for T77, T78, T79
3. Close PR #146 (stale — content already in master)
4. Route-B tests for T78 BBR2ProbeBWCycle
