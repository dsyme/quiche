# Lean Squad Memory — dsyme/quiche

## Last updated
Run 179 (workflow 26206385584, 2026-05-21)

## FV Toolchain
- Lean 4.29.1 (elan stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)
- Key tactic notes:
  - `Nat.min_eq_left h` needs `h : a ≤ b` → `min a b = a`
  - `Nat.min_eq_right h` needs `h : b ≤ a` → `min a b = b`
  - For goals about `(n+1).min k`, use `change min (n+1) k ≥ n` then `Nat.le_min.mpr`
  - `Nat.pow_succ : n ^ m.succ = n ^ m * n` (use `rw [Nat.pow_succ]; omega`)
  - No `ring`, `split_ifs`, `push_neg` without Mathlib

## Repository State (after run 179)
- Lean files: 71
- Total theorems: 1367 (1348 + 19)
- Total sorry: 0
- Route-B test targets: 29

## Open PRs (lean-squad label) — as of run 179
- PR #146: T73 BBR2CyclePhaseGain (stale conflict — content already in master)
- PR created this run: T77 BBR2InflightHiSlope (branch lean-squad-run179-26206385584-bbr2-inflight-hi-slope-t77)

## CI Status
- lean-ci.yml: exists, healthy, passing
- lean-toolchain: v4.29.0
- Triggers: PR + push on formal-verification/lean/**

## Targets

### T79: VarIntLength monotonicity (run 179, research)
- Phase: 1 — Research
- Source: octets/src/lib.rs (varint_len L810-822)
- Key: varint_len is monotone non-decreasing; values only in {1,2,4,8}
- Note: VarIntTag.lean already has consistency proofs; add monotonicity
- Next: write FVSquad/VarIntLength.lean (~15 thms, all decide/omega)

### T78: BBR2ProbeBWCycle (run 179, research)
- Phase: 1 — Research
- Source: quiche/src/recovery/gcongestion/bbr2/probe_bw.rs (transitions)
- Key: Down→Cruise/Refill→Refill→Up→Down ordering; finite state machine
- Next: write FVSquad/BBR2ProbeBWCycle.lean

### T77: BBR2InflightHiSlope (run 179, DONE)
- Phase: 5 (Done — 19 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2InflightHiSlope.lean
- Source: probe_bw.rs L582-590 (raise_inflight_high_slope)
- Key theorems: newRounds_le_cap, probeUpBytes_ge_mss, growthThisRound_pos
- CORRESPONDENCE.md: not yet updated

### T76: BBR2ModeState (run 177)
- Phase: 5 (Done — 19 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2ModeState.lean
- Route-B: formal-verification/tests/bbr2_mode_state/ — 91/91 PASS

### T75: BBR2DrainExit (run 176)
- Phase: 5 (Done — 17 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2DrainExit.lean
- Route-B: formal-verification/tests/bbr2_drain_exit/ — 23/23 PASS

### Earlier targets (T1-T74): All phase 5 (Done)

## Route-B Tests (29 targets total, 1684+ cases, all PASS)

## Next Run Priorities
1. T79: VarIntLength monotonicity (LOW difficulty, all omega/decide)
2. T78: BBR2ProbeBWCycle abstract state machine (MEDIUM)
3. REPORT.md update to cover runs 167–179
4. CORRESPONDENCE.md update for T77, T75, T76
5. Close PR #146 (stale, content already in master)
