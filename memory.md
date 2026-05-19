# Lean Squad Memory — dsyme/quiche

## Last updated
Run 173 (workflow 26076749132, 2026-05-19)

## FV Toolchain
- Lean 4.29.0 (lake project pinned, lean-toolchain: v4.29.0)
- Lean 4.29.1 (installed by elan stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 173)
- Lean files: 68 (PacketTypeEpoch.lean added)
- Total theorems: ~1540 (+20 from T74)
- Total sorry: 0
- Route-B test targets: 26 (bbr2_cycle_phase_gain added)
- Status issue: #4 (open)
- Open PRs: (new PR from run 173)

## Open PRs (lean-squad label) — as of run 173
- PR run173 (branch lean-squad-run173-26076749132-packet-type-epoch-t74-bbr2-route-b):
  Task 4 — T74 PacketTypeEpoch.lean (20 thms, 0 sorry)
  Task 8 — T73 BBR2CyclePhaseGain Route-B 25/25 PASS

## Targets

### T74: QUIC PacketType ↔ Epoch Round-Trip (NEW run 173)
- Phase: 5 (Done — run 173, 20 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/PacketTypeEpoch.lean
- Source: quiche/src/packet.rs — Type::from_epoch, Type::to_epoch
- Informal spec: formal-verification/specs/packet_type_epoch_informal.md
- Key theorems: from_epoch_to_epoch (round-trip), from_epoch_injective,
  range_of_fromEpoch, short_and_zeroRTT_same_epoch, retry_and_vn_no_epoch,
  hasEpoch_iff, to_epoch_exhaustive, fromEpoch_hasEpoch
- All proofs: decide or simp — fully decidable
- Namespace: FVSquad.PacketTypeEpoch

### T73: BBR2 CyclePhase Gain Assignment (run 172, merged)
- Phase: 5 (Done — run 172, 23 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2CyclePhaseGain.lean
- Route-B: tests/bbr2_cycle_phase_gain/ — 25/25 PASS (run 173)

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
- lean-ci.yml: exists, passing, healthy
- lean-toolchain: v4.29.0
- Triggers: PR + push on formal-verification/lean/**
- lake build: 71 jobs (run 173 local), 0 sorry

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
1. CORRESPONDENCE.md update to cover runs 169-173 (T70/T71/T72/T73/T74)
2. CRITIQUE.md update for runs 167-173
3. New target: BBR2 cycle-phase state transitions (mode transitions in mode.rs)
4. New target: T75 BBR2 Drain exit condition (bytes_in_flight <= bdp0)
5. Route-B tests for T74 (PacketTypeEpoch) — small, fully decidable
