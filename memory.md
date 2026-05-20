# Lean Squad Memory — dsyme/quiche

## Last updated
Run 177 (workflow 26159754284, 2026-05-20)

## FV Toolchain
- Lean 4.29.0 (lake project pinned, lean-toolchain: v4.29.0)
- Lean 4.29.1 (installed by elan stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 177)
- Lean files: 70
- Total theorems: 1348
- Total sorry: 0
- Route-B test targets: 27
- Status issue: #4 (open)

## Open PRs (lean-squad label) — as of run 177
- PR #149: T74 PacketTypeEpoch Route-B 42/42 + paper update (open, stale — content merged)
- PR #146: T73 BBR2CyclePhaseGain (open, stale — content merged)
- PR created this run: T76 BBR2ModeState (19 thms) + CRITIQUE.md (branch lean-squad-run177-26159754284-bbr2-mode-state-machine)

## CI Status
- lean-ci.yml: exists, healthy, passing
- lean-toolchain: v4.29.0
- Triggers: PR + push on formal-verification/lean/**
- lake build: 0 sorry

## Targets

### T76: BBR2ModeState (run 177)
- Phase: 5 (Done — 19 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2ModeState.lean
- Source: quiche/src/recovery/gcongestion/bbr2/mode.rs, startup.rs, drain.rs
- Key theorems: startup_only_transitions_to_drain, startup_cannot_skip_drain,
  drain_only_transitions_to_probebw, probertt_only_transitions_to_probebw,
  step_idempotent_{startup,drain,probebw}_stable

### T75: BBR2DrainExit (run 176)
- Phase: 5 (Done — 17 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2DrainExit.lean
- Source: quiche/src/recovery/gcongestion/bbr2/drain.rs + network_model.rs
- Route-B: not yet done (next priority)

### T74: QUIC PacketType ↔ Epoch Round-Trip (run 173)
- Phase: 5 (Done — 14 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/PacketTypeEpoch.lean
- Route-B: 42/42 PASS (run 175)

### T73: BBR2 CyclePhase Gain Assignment (run 172, in PR #146)
- Phase: 5 (Done — 23 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2CyclePhaseGain.lean
- Route-B: 25/25 PASS (run 173)

### T72: BBR2 PROBE_RTT Phase Constants (run 171)
- Phase: 5 (Done — 25 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2ProbeRTTPhase.lean

### T71: BBR2 Startup Phase Constants (run 170)
- Phase: 5 (Done — 26 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2Startup.lean

### T70: BBR2 Drain Phase Constants (run 169)
- Phase: 5 (Done — 21 thms)
- File: formal-verification/lean/FVSquad/BBR2DrainPhase.lean

### Earlier targets (T1-T69): All phase 5 (Done)

## Route-B Tests (27 targets total, 2864+ cases, all PASS)
See prior memory entries for full table.

## Key Technical Notes
- `bif` is a Lean 4 keyword (boolean if-then-else) — use `byif` or `n` instead
- `split_ifs` NOT available without Mathlib
- `omega` CANNOT handle if-then-else — use `by_cases` + `simp` first
- Best pattern: `by_cases h : cond <;> simp [h] <;> omega`
- `ring` tactic NOT available without Mathlib — use `omega` for linear identities
- `Nat.mul_div_cancel bw hd` requires explicit `hd : den > 0`
- UInt8 bit-ops work cleanly with `decide` for small types
- `nlinarith`, `push_neg`, `norm_num` NOT available without Mathlib
- Use `namespace FVSquad.ModuleName` to avoid name collisions
- `theorem mode_eq_decidable (m1 m2 : T) : Decidable (m1 = m2)` is NOT a proposition
  — use `example` or `#check` instead

## Next Run Priorities
1. Route-B for T75 (BBR2DrainExit): drain exit decision vs Rust fixture
2. Route-B for T76 (BBR2ModeState): abstract mode step vs Rust fixture
3. REPORT.md update to cover runs 167–177
4. Paper PDF compilation (needs LaTeX environment)
5. Merge stale PRs #149 and #146
