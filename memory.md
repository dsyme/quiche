# Lean Squad Memory — dsyme/quiche

## Last updated
Run 172 (workflow 26052196972, 2026-05-18)

## FV Toolchain
- Lean 4.29.0 (lake project pinned, lean-toolchain: v4.29.0)
- Lean 4.29.1 (installed by elan stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 172)
- Lean files: 67 (BBR2CyclePhaseGain.lean added)
- Total theorems: ~1520 (+23 from T73)
- Total sorry: 0
- Route-B test targets: 25 (unchanged)
- Status issue: #4 (open)
- Open PRs: (new PR from run 172)

## Open PRs (lean-squad label) — as of run 172
- PR run172 (branch lean-squad-run172-26052196972-cycle-phase-gain-t73):
  Task 3 — T73 BBR2CyclePhaseGain.lean (23 thms, 0 sorry)
  + informal spec bbr2_cycle_phase_gain_informal.md

## Targets

### T73: BBR2 CyclePhase Gain Assignment (NEW run 172)
- Phase: 5 (Done — run 172, 23 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2CyclePhaseGain.lean
- Source: quiche/src/recovery/gcongestion/bbr2/mode.rs
- Key theorems: upPacingGain_superUnity, downPacingGain_subUnity,
  defaultPacingGain_unity, pacingGain_ordering, up_is_only_elevated_pacing,
  up_is_only_elevated_cwnd, up_uses_both_elevated_gains,
  nonUp_cwnd_gain_uniform, upPacingGain_ge_unity_applied
- Namespace: FVSquad.BBR2CyclePhaseGain
- 5 CyclePhases: NotStarted, Up, Down, Cruise, Refill
- Gains modelled as rational fractions (num/den)

### T72: BBR2 PROBE_RTT Phase Constants (run 171)
- Phase: 5 (Done — run 171, 25 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2ProbeRTTPhase.lean

### T71: BBR2 Startup Phase Constants (run 170)
- Phase: 5 (Done — run 170, 20 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2Startup.lean

### T70: BBR2 Drain Phase Constants (run 169)
- Phase: 5 (Done)
- File: formal-verification/lean/FVSquad/BBR2DrainPhase.lean

### T65: SsThresh Route-B validation (run 170)
- Phase: 5 (Route-B done)

### T27: CidMgmt retire_if_needed Route-B validation (run 169)
- Phase: 5 (Route-B done)

### Earlier targets (T1-T69): All phase 5 (Done)

## CI Status
- lean-ci.yml: exists, passing, healthy (audited run 172)
- lean-toolchain: v4.29.0
- Triggers: PR + push on formal-verification/lean/**
- Cache: keyed on lake-manifest.json hash
- lake build: 70 jobs (run 172 local), 0 sorry, 23 theorems added
- CI looks good: upload-artifact on failure, sorry count check

## Route-B Tests
| Target | Directory | Cases | Run |
|--------|-----------|-------|-----|
| T20 (PacketNumLen) | tests/pkt_num_len/ | 18 | 89 |
| T36 (Bandwidth) | tests/bandwidth_arithmetic/ | 25 | 90 |
| T2 (RangeSet) | tests/rangeset_insert/ | 21 | 96 |
| T43 (AckRanges) | tests/ack_ranges/ | 25 | 102 |
| T31 (H3Frame) | tests/h3_frame/ | 25 | 103 |
| T37 (BytesInFlight) | tests/bytes_in_flight/ | 25 | 112 |
| T38 (PathState) | tests/path_state/ | 75 | 118 |
| T45 (QPACKInteger) | tests/qpack_integer/ | 25 | 122 |
| T44 (StreamStateMachine) | tests/stream_state_machine/ | 46 | 123 |
| T42 (FrameAckEliciting) | tests/frame_ack_eliciting/ | 33 | 124 |
| T33 (H3Settings) | tests/h3_settings/ | 43 | 125 |
| T48 (HyStart++) | tests/hystart/ | 27 | 133 |
| T49 (WindowedFilter) | tests/windowed_filter/ | 24 | 136 |
| T57 (ProbeBWPhase) | tests/probe_bw_phase/ | 10 | 142 |
| T56 (LossDetectionThreshold) | tests/loss_detection_threshold/ | 991 | 144 |
| T59 (TransportErrorCode) | tests/transport_error_code/ | 50 | 146 |
| T61 (StreamFrameType) | tests/stream_frame_type/ | 19 | 147 |
| IdleTimeout | tests/idle_timeout/ | 38 | 148 |
| PRR | tests/prr/ | 25 | 150 |
| T63 (StreamCountLimit) | tests/stream_count_limit/ | 28 | 157 |
| T60 (ProbeRTTStateMachine) | tests/probe_rtt_sm/ | 23 | 158 |
| T32/BBR2Limits | tests/bbr2_limits/ | 1000+ | 159 |
| T66 (AckDelayCodec) | tests/ack_delay_codec/ | 31 | 167 |
| T27 (CidMgmt retire_if_needed) | tests/cid_mgmt_retire/ | 56 | 169 |
| T65 (SsThresh) | tests/ssthresh/ | 25 | 170 |

Total: 2797+ cases, all PASS

## Key Technical Notes
- `split_ifs` NOT available without Mathlib
- `omega` CANNOT handle if-then-else — use `by_cases` + `simp` first
- Best pattern: `by_cases h : cond <;> simp [h] <;> omega`
- `ring` tactic NOT available without Mathlib — use `omega` for linear identities
- For structure predicates like `Gain.isUnity`, `Gain.le`: must add `Decidable` instances or use `omega`
- `Nat.mul_div_cancel bw hd` requires explicit `hd : den > 0`
- `Min.min a b` ≠ `Nat.min a b` for rewriting
- UInt8 bit-ops work cleanly with `decide` for small types
- `nlinarith`, `push_neg`, `norm_num` NOT available without Mathlib
- Use `namespace FVSquad.ModuleName` to avoid name collisions
- For floor-division bounds: use `simp only [defaultParams]` first to evaluate concrete values, then omega
- When using custom Prop predicates with `decide`: MUST add `instance : Decidable (myPred x)` for each

## Next Run Priorities
1. CORRESPONDENCE.md update to cover runs 169-172 (T70/T71/T72/T73)
2. Route-B tests for T73 (BBR2CyclePhaseGain) — confirm gain dispatch matches Rust
3. CRITIQUE.md update for runs 167-172
4. New target: BBR2 cycle-phase state transitions (mode transitions from/to each phase)
5. T26 W_est: add transition condition W_cubic < W_est to Cubic.lean §6
