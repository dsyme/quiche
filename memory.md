# Lean Squad Memory — dsyme/quiche

## Last updated
Run 178 (workflow 26183850071, 2026-05-20)

## FV Toolchain
- Lean 4.29.0 (lake project pinned, lean-toolchain: v4.29.0)
- Lean 4.29.1 (installed by elan stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 178)
- Lean files: 70
- Total theorems: 1348
- Total sorry: 0
- Route-B test targets: 29 (added T75 + T76 this run)
- Status issue: #4 (open)

## Open PRs (lean-squad label) — as of run 178
- PR #146: T73 BBR2CyclePhaseGain (open, stale — content merged)
- PR #149: T74 PacketTypeEpoch Route-B 42/42 + paper update (open, stale)
- PR created this run: T75+T76 Route-B + Research (branch lean-squad-run178-26183850071-route-b-t75-t76)

## CI Status
- lean-ci.yml: exists, healthy, passing
- lean-toolchain: v4.29.0
- Triggers: PR + push on formal-verification/lean/**
- lake build: 0 sorry

## Targets

### T79: VarIntLength (run 178, new research)
- Phase: 1 — Research
- Source: octets/src/lib.rs (lines 810–834)
- Key: varint_len ↔ varint_parse_len consistency; decidable; HIGH priority
- Next: write FVSquad/VarIntLength.lean

### T78: BBR2ProbeBWCycle (run 178, new research)
- Phase: 1 — Research
- Source: quiche/src/recovery/gcongestion/bbr2/probe_bw.rs (lines 201–380)
- Key: Down→Cruise/Refill→Refill→Up→Down ordering; abstract state machine
- Next: write FVSquad/BBR2ProbeBWCycle.lean

### T77: BBR2InflightHiSlope (run 178, new research)
- Phase: 1 — Research
- Source: quiche/src/recovery/gcongestion/bbr2/probe_bw.rs (lines 582–590)
- Key: probe_up_rounds cap at 30; probe_up_bytes ≥ DEFAULT_MSS; HIGH priority
- Next: write FVSquad/BBR2InflightHiSlope.lean

### T76: BBR2ModeState (run 177)
- Phase: 5 (Done — 19 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2ModeState.lean
- Source: mode.rs, startup.rs, drain.rs, probe_rtt.rs
- Route-B: formal-verification/tests/bbr2_mode_state/ — 91/91 PASS (run 178)
- CORRESPONDENCE.md: updated (run 178)

### T75: BBR2DrainExit (run 176)
- Phase: 5 (Done — 17 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2DrainExit.lean
- Source: quiche/src/recovery/gcongestion/bbr2/drain.rs, network_model.rs
- Route-B: formal-verification/tests/bbr2_drain_exit/ — 23/23 PASS (run 178)
- CORRESPONDENCE.md: updated (run 178)
- Note: Lean comment says bw_bps is "bits/s" but formula matches Rust with bytes/s

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

## Route-B Tests (29 targets total, 1684+ cases, all PASS)
| Target | Dir | Cases | Run |
|--------|-----|-------|-----|
| T75 BBR2DrainExit | bbr2_drain_exit | 23 | 178 |
| T76 BBR2ModeState | bbr2_mode_state | 91 | 178 |
| T74 PacketTypeEpoch | packet_type_epoch | 42 | 175 |
| T73 BBR2CyclePhaseGain | bbr2_cycle_phase_gain | 25 | 173 |
(+ 25 earlier targets for 1503+ more cases)

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
1. T77: BBR2InflightHiSlope (new research, HIGH — small pure arithmetic)
2. T79: VarIntLength consistency (new research, HIGH — decidable)
3. T78: BBR2ProbeBWCycle abstract state machine (MEDIUM)
4. REPORT.md update to cover runs 167–178
5. Paper PDF compilation (needs LaTeX environment)
6. Merge stale PRs #149 and #146
