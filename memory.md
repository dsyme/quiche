# Lean Squad Memory — dsyme/quiche

## Last updated
Run 184 (workflow 26304725999, 2026-05-22)

## FV Toolchain
- Lean 4.29.1 (elan stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)
- Key tactic notes:
  - No `split_ifs`, `push_neg`, `rcases` without Mathlib
  - Use `by_cases h : cond; exact ...` for if-then-else goals
  - `Nat.max_le.mpr`, `Nat.le_min.mpr` for max/min inequalities (no unfolding)
  - `by_cases hv : lo ≤ hi` for clamp case splits, then use `Nat.min_eq_right`
  - `clamp_identity` uses `Nat.max_eq_left hl` + `Nat.min_eq_left hh`
  - clamp2_le_hi1 is FALSE in general — use clamp2_mono instead
  - pathA_clamp_le_acked is false — use pathA_growth_bounded (monotone form)

## Repository State (after run 184)
- Lean files: 75
- Total theorems: ~1579 (lake build passed, 0 sorry)
- Total sorry: 0
- Route-B test targets: 23

## Open PRs (lean-squad label) — as of run 184
- PR #157: T81 research + paper update — STALE (content merged into run184 branch)
- PR #155: T78 BBR2ProbeBWCycle — STALE (conflict, content already in master)
- PR #154: T79 VarIntLength — STALE (conflict, content already in master)
- PR #153: T77 BBR2InflightHiSlope — STALE (conflict, content already in master)
- PR #146: T73 BBR2CyclePhaseGain — STALE (conflict, content already in master)
- PR run184 (branch lean-squad-run184-26304725999-bbr2-cwnd-update-t81):
  Task 5 — T81 BBR2CwndUpdate.lean (18 thms, 0 sorry)
  Task 9 — CI audit (lean-ci.yml healthy, passing)

## CI Status
- lean-ci.yml: exists, healthy, passing
- lean-toolchain: v4.29.0
- Triggers: PR + push on formal-verification/lean/**

## Targets

### T81: BBR2 update_congestion_window growth bounds (run 184, DONE)
- Phase: 5 — Done (18 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2CwndUpdate.lean
- Key: cwndA ≤ prior+bytes_acked; clamp is monotone; two-stage clamp bounded
- Bug-catching potential: HIGH

### T80: BBR2BandwidthGrowth (run 182, DONE)
- Phase: 5 (Done — 20 thms, 0 sorry)

### T79: VarIntLength (run 180, DONE)

### T78: BBR2ProbeBWCycle (run 181, DONE)

### T77: BBR2InflightHiSlope (run 179, DONE)

### Earlier targets (T1-T76): All phase 5 (Done)

## Route-B Tests (23 directories)
ack_delay_codec, ack_ranges, bbr2_cycle_phase_gain, bbr2_limits,
cid_mgmt_retire, frame_ack_eliciting, h3_settings, hystart,
idle_timeout, loss_detection_threshold, packet_type_epoch, path_state,
pkt_num_len, probe_bw_phase, probe_rtt_sm, prr, qpack_integer,
ssthresh, stream_frame_type, stream_state_machine, transport_error_code,
varint_len, windowed_filter

## Next Run Priorities
1. Close stale PRs #146, #153, #154, #155, #157 (all merged into master)
2. T82: new research target — BBR2 probe_rtt entry conditions or H3 qpack encode
3. Route-B tests for T81 (BBR2CwndUpdate) — Rust vs Lean comparison
4. Update CORRESPONDENCE.md for T81
5. Extend CRITIQUE.md with T81 assessment

## Status Issue
Issue #4 (open) — updated run 184

## Key Findings
- OQ-1 (run49): StreamPriorityKey antisymmetry violation (intentional by design)
- OQ-RT-1 (run68): zero-length retransmit with off > ackOff may not be no-op
- OQ-FC-1 (run70): RESET_STREAM guard in RecvBuf not modelled
- decode_pktnum_correct spec refinement (run39): non-strict bound counterexample found
- OQ-T43-2 (run100): uncapped block_count in parse_ack_frame — potential DoS vector
- OQ-T37-1 (run103): clock-monotonicity not asserted in BytesInFlight.add/subtract
