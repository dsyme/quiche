# Lean Squad Memory — dsyme/quiche

## Last updated
Run 171 (workflow 26032341462, 2026-05-18)

## FV Toolchain
- Lean 4.29.0 (lake project pinned, lean-toolchain: v4.29.0)
- Lean 4.29.1 (installed by elan stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 171)
- Lean files: 66 (BBR2ProbeRTTPhase.lean added; merged PRs #143/#144 content)
- Total theorems: ~1497 (+25 from T72)
- Total sorry: 0
- Route-B test targets: 25 (unchanged)
- Status issue: #4 (open)
- Open PRs: #143, #144, #145

## Open PRs (lean-squad label) — as of run 171
- PR #143 (run169, branch lean-squad-run169-...): BBR2DrainPhase.lean (21 thms) + CidMgmt Route-B
- PR #144 (run170, branch lean-squad-run170-...): BBR2Startup.lean (20 thms) + SsThresh Route-B
- PR #145 (run171, branch lean-squad-run171-...): BBR2ProbeRTTPhase.lean (25 thms, T72)

## Targets

### T72: BBR2 PROBE_RTT Phase Constants (NEW run 171)
- Phase: 5 (Done — run 171, 25 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2ProbeRTTPhase.lean
- Key theorems: probeRttPacingGain_unity, probeRttCwndGain_unity,
  applyProbeRttPacing_identity, applyProbeRttCwnd_identity,
  inflightTarget_lt_bdp, inflightTarget_le_half,
  probeRttPacing_le_startupPacing, drainPacing_le_probeRttPacing,
  probeRttPeriod_gt_duration, probeRttPeriod_ratio_ge_50
- Source: quiche/src/recovery/gcongestion/bbr2.rs DEFAULT_PARAMS probe_rtt section
- Namespace: FVSquad.BBR2ProbeRTTPhase

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
- lean-ci.yml: exists, passing, healthy
- lean-toolchain: v4.29.0
- lake build: 66 files (run 171 local), 0 sorry
- Cache: keyed on lake-manifest.json hash (correct)

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
- For structure predicates like `Gain.isUnity`, `Gain.le`: must `unfold` first before `decide`
- `Nat.mul_div_cancel bw hd` requires explicit `hd : den > 0`
- `Min.min a b` ≠ `Nat.min a b` for rewriting
- UInt8 bit-ops work cleanly with `decide` for small types
- `nlinarith`, `push_neg`, `norm_num` NOT available without Mathlib
- Use `namespace FVSquad.ModuleName` to avoid name collisions
- Cross-module name collision: use namespaces (e.g., Gain struct needs namespace)

## Next Run Priorities
1. CORRESPONDENCE.md update to cover runs 169-171 (T70 DrainPhase, T71 StartupPhase, T72 ProbeRTTPhase)
2. Route-B for BBR2ProbeRTTPhase (T72) — confirm inflight_target matches Rust on concrete inputs
3. CRITIQUE.md update for runs 167-171
4. T26 W_est: add transition condition W_cubic < W_est to Cubic.lean §6
5. New target: BBR2 pacing-rate monotone relationship (T73)
