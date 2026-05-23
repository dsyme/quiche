# Lean Squad Memory — dsyme/quiche

## Last updated
Run 185 (workflow 26323441599, 2026-05-23)

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
  - After `simp [f, h]`, do NOT add extra `exact ...` — simp closes the goal
  - For iff proofs with `decide`, use `if-then-else` style in defs (not `decide`)
  - `quiescenceStep` uses `if now > t then true else false` (not `decide (now > t)`)

## Repository State (after run 185)
- Lean files: 76
- Total theorems: ~1599 (lake build passed, 0 sorry)
- Total sorry: 0
- Route-B test targets: 24

## Open PRs (lean-squad label) — as of run 185
- PR run185 (branch lean-squad-run185-26323441599-probertttimer-t82-cwndupdate-tests):
  Task 5 — T82 BBR2ProbeRTTTimer.lean (20 thms, 0 sorry)
  Task 8 — Route-B tests for T81 BBR2CwndUpdate (19 tests, all PASS)
- PRs #146, #153, #154, #155, #157: STALE (content merged into master long ago)

## CI Status
- lean-ci.yml: exists, healthy, passing
- lean-toolchain: v4.29.0
- Triggers: PR + push on formal-verification/lean/**

## Targets

### T82: BBR2 ProbeRTT exit-timer state machine (run 185, DONE)
- Phase: 5 — Done (20 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2ProbeRTTTimer.lean
- Models: congestionStep, quiescenceStep
- Key: exit_time monotone; exit iff timer Some AND expired;
  quiescence exits on None; timer-set iff inflight ≤ target
- Bug-catching potential: HIGH (state machine correctness)

### T81: BBR2 update_congestion_window growth bounds (run 184, DONE)
- Phase: 5 — Done (18 thms, 0 sorry)
- Route-B tests: bbr2_cwnd_update/ (19 tests, all PASS — run 185)
- File: formal-verification/lean/FVSquad/BBR2CwndUpdate.lean

### T80: BBR2BandwidthGrowth (run 182, DONE)
### T79: VarIntLength (run 180, DONE)
### T78: BBR2ProbeBWCycle (run 181, DONE)
### T77: BBR2InflightHiSlope (run 179, DONE)
### Earlier targets (T1-T76): All phase 5 (Done)

## Route-B Tests (24 directories)
ack_delay_codec, ack_ranges, bbr2_cycle_phase_gain, bbr2_limits,
bbr2_cwnd_update (NEW run185),
cid_mgmt_retire, frame_ack_eliciting, h3_settings, hystart,
idle_timeout, loss_detection_threshold, packet_type_epoch, path_state,
pkt_num_len, probe_bw_phase, probe_rtt_sm, prr, qpack_integer,
ssthresh, stream_frame_type, stream_state_machine, transport_error_code,
varint_len, windowed_filter

## Next Run Priorities
1. T83: new research target — could be BBR2 Drain mode exit (simple state machine)
   or H3 settings parse (pure codec)
2. Route-B tests for T82 (BBR2ProbeRTTTimer)
3. Update CORRESPONDENCE.md for T82 and T81/bbr2_cwnd_update tests
4. Extend CRITIQUE.md with T82 assessment

## Status Issue
Issue #4 (open) — updated run 185

## Key Findings
- OQ-1 (run49): StreamPriorityKey antisymmetry violation (intentional by design)
- OQ-RT-1 (run68): zero-length retransmit with off > ackOff may not be no-op
- OQ-FC-1 (run70): RESET_STREAM guard in RecvBuf not modelled
- decode_pktnum_correct spec refinement (run39): non-strict bound counterexample found
- OQ-T43-2 (run100): uncapped block_count in parse_ack_frame — potential DoS vector
- OQ-T37-1 (run103): clock-monotonicity not asserted in BytesInFlight.add/subtract
