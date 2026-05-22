# Lean Squad Memory — dsyme/quiche

## Last updated
Run 183 (workflow 26285112292, 2026-05-22)

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

## Repository State (after run 183)
- Lean files: 74
- Total theorems: 1567
- Total sorry: 0
- Route-B test targets: 23

## Open PRs (lean-squad label) — as of run 183
- PR #153: T77 BBR2InflightHiSlope — STALE (content already in master)
- PR #154: T79 VarIntLength + Route-B tests — STALE (content already in master)
- PR #155: T78 BBR2ProbeBWCycle + T80 informal spec — STALE (content already in master)
- PR #146: T73 BBR2CyclePhaseGain — STALE (content already in master)
- PR run183 (branch lean-squad-run183-26285112292-research-t81-paper-update):
  Task 1 — T81 research (BBR2 CWND update bounds)
  Task 11 — Paper update (74 files, 1567 thms, 23 Route-B suites)

## CI Status
- lean-ci.yml: exists, healthy, passing
- lean-toolchain: v4.29.0
- Triggers: PR + push on formal-verification/lean/**

## Targets

### T81: BBR2 update_congestion_window growth bounds (run 183, RESEARCHED)
- Phase: 1 — Research
- Source: quiche/src/recovery/gcongestion/bbr2.rs L603-621
- File: TBD — FVSquad/BBR2CwndUpdate.lean (next run)
- Key: cwnd ≤ prior + bytes_acked, startup: exact, post-clamp ∈ [lo, hi]
- ~15-18 theorems, all omega, imports BBR2Limits
- Bug-catching potential: HIGH

### T80: BBR2BandwidthGrowth (run 182, DONE)
- Phase: 5 (Done — 20 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2BandwidthGrowth.lean

### T79: VarIntLength (run 180, DONE)
- Phase: 5 (Done — 24 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/VarIntLength.lean

### T78: BBR2ProbeBWCycle (run 181, DONE)
- Phase: 5 (Done — 32 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2ProbeBWCycle.lean
- Key: cycle_strongly_connected (every phase reaches every other in ≤4 steps)

### T77: BBR2InflightHiSlope (run 179, DONE)
- Phase: 5 (Done — 19 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2InflightHiSlope.lean

### T76: BBR2ModeState (run 177, DONE)
- Phase: 5 (Done — 19 thms, 0 sorry)

### Earlier targets (T1-T75): All phase 5 (Done)

## Route-B Tests (23 directories)
ack_delay_codec, ack_ranges, bbr2_cycle_phase_gain, bbr2_limits,
cid_mgmt_retire, frame_ack_eliciting, h3_settings, hystart,
idle_timeout, loss_detection_threshold, packet_type_epoch, path_state,
pkt_num_len, probe_bw_phase, probe_rtt_sm, prr, qpack_integer,
ssthresh, stream_frame_type, stream_state_machine, transport_error_code,
varint_len, windowed_filter

## Next Run Priorities
1. T81: write FVSquad/BBR2CwndUpdate.lean (~15-18 thms, all omega, imports BBR2Limits)
2. Close stale PRs #146, #153, #154, #155 (all merged into master already)
3. Route-B tests for T78 (BBR2ProbeBWCycle) and T80 (BBR2BandwidthGrowth)
4. T25: StreamId↔stream_do_send guard correctness
5. T26: CUBIC Reno-friendly transition (W_est model)

## Status Issue
Issue #4 (open) — updated run 183

## Key Findings
- OQ-1 (run49): StreamPriorityKey antisymmetry violation (intentional by design)
- OQ-RT-1 (run68): zero-length retransmit with off > ackOff may not be no-op
- OQ-FC-1 (run70): RESET_STREAM guard in RecvBuf not modelled
- decode_pktnum_correct spec refinement (run39): non-strict bound counterexample found
- OQ-T43-2 (run100): uncapped block_count in parse_ack_frame — potential DoS vector
- OQ-T37-1 (run103): clock-monotonicity not asserted in BytesInFlight.add/subtract
