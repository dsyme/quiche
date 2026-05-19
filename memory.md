# Lean Squad Memory — dsyme/quiche

## Last updated
Run 174 (workflow 26094853817, 2026-05-19)

## FV Toolchain
- Lean 4.29.0 (lake project pinned, lean-toolchain: v4.29.0)
- Lean 4.29.1 (installed by elan stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 174)
- Lean files: 68
- Total theorems: 1312
- Total sorry: 0
- Route-B test targets: 26
- Status issue: #4 (open)

## Open PRs (lean-squad label) — as of run 174
- None (run 173 PR was merged as PR #147)

## CI Status
- lean-ci.yml: exists, healthy, passing
- lean-toolchain: v4.29.0
- Triggers: PR + push on formal-verification/lean/**
- lake build: 0 sorry
- Run 174 improvement: added sorry-warning gate (fails CI if any theorem uses sorry)

## Targets

### T74: QUIC PacketType ↔ Epoch Round-Trip (run 173)
- Phase: 5 (Done — run 173, 14 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/PacketTypeEpoch.lean
- Source: quiche/src/packet.rs — Type::from_epoch, Type::to_epoch
- Key theorems: from_epoch_to_epoch, from_epoch_injective, short_and_zeroRTT_same_epoch
- Route-B: TODO (small, fully decidable — good candidate for next run)

### T73: BBR2 CyclePhase Gain Assignment (run 172, merged)
- Phase: 5 (Done — run 172, 23 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2CyclePhaseGain.lean
- Route-B: 25/25 PASS (run 173)

### T72: BBR2 PROBE_RTT Phase Constants (run 171)
- Phase: 5 (Done — run 171, 25 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2ProbeRTTPhase.lean

### T71: BBR2 Startup Phase Constants (run 170)
- Phase: 5 (Done — run 170, 26 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2Startup.lean

### T70: BBR2 Drain Phase Constants (run 169)
- Phase: 5 (Done)
- File: formal-verification/lean/FVSquad/BBR2DrainPhase.lean

### T65: SsThresh Route-B validation (run 170)
- Phase: 5 (Route-B done)

### T27: CidMgmt retire_if_needed Route-B validation (run 169)
- Phase: 5 (Route-B done)

### Earlier targets (T1-T69): All phase 5 (Done)

## Route-B Tests (26 targets total, 2822+ cases, all PASS)
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
| T73 (BBR2CyclePhaseGain) | tests/bbr2_cycle_phase_gain/ | 25 | 173 |

## Key Technical Notes
- `split_ifs` NOT available without Mathlib
- `omega` CANNOT handle if-then-else — use `by_cases` + `simp` first
- Best pattern: `by_cases h : cond <;> simp [h] <;> omega`
- `ring` tactic NOT available without Mathlib — use `omega` for linear identities
- For structure predicates: must add `Decidable` instances or use `omega`
- `Nat.mul_div_cancel bw hd` requires explicit `hd : den > 0`
- UInt8 bit-ops work cleanly with `decide` for small types
- `nlinarith`, `push_neg`, `norm_num` NOT available without Mathlib
- Use `namespace FVSquad.ModuleName` to avoid name collisions
- For PacketType/Epoch: all theorems close by `decide` — fully decidable

## Next Run Priorities
1. New target: BBR2 cycle-phase state transitions (mode transitions in mode.rs)
2. New target: T75 BBR2 drain exit condition (bytes_in_flight <= bdp0)
3. Route-B tests for T74 (PacketTypeEpoch) — small, fully decidable
4. CORRESPONDENCE.md update to cover T70-T74
5. REPORT.md update to cover runs 169-174
