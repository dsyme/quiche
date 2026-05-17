# Lean Squad Memory — dsyme/quiche

## Last updated
Run 169 (workflow 25997972536, 2026-05-17)

## FV Toolchain
- Lean 4.29.0 (lake project pinned, lean-toolchain: v4.29.0)
- Lean 4.29.1 (installed by elan stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 169)
- Lean files: 64 (BBR2DrainPhase.lean added)
- Total theorems: ~1452 (+21 from T70)
- Total sorry: 0
- Route-B test targets: 24 (cid_mgmt_retire added)
- Status issue: #4 (open)

## Open PRs (lean-squad label) — as of run 169
- run169 (branch lean-squad-run169-25997972536-drain-phase-cid-retire-9a3b2c1f):
  Task 5 — BBR2DrainPhase.lean (21 thms, 0 sorry) — T70 drain phase constants
  Task 8 — Route-B for T27 CidMgmt retire_if_needed (56/56 PASS)

## Targets

### T70: BBR2 Drain Phase Constants (NEW run 169)
- Phase: 5 (Done — run 169, 21 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2DrainPhase.lean
- Key theorems: drainPacingGain_subUnity, drainCwndGain_eq_startupCwndGain,
  applyDrainPacing_le, applyDrainPacing_le_applyStartupPacing,
  drainPacingGain_times_divisor_le_unity, concrete numeric checks
- Source: quiche/src/recovery/gcongestion/bbr2.rs DEFAULT_PARAMS drain section
- Uses namespace FVSquad.BBR2DrainPhase (avoids Gain name collision)

### T27: CidMgmt retire_if_needed Route-B validation (run 169)
- Phase: 5 (Route-B done)
- Lean file: formal-verification/lean/FVSquad/CidMgmt.lean §10
- Route-B: formal-verification/tests/cid_mgmt_retire/ — 56/56 PASS (run 169)

### Earlier targets (T1-T69, all): All phase 5 (Done)

## CI Status
- lean-ci.yml: exists, passing, healthy
- lean-toolchain: v4.29.0
- lake build: 64 files (run 169), 0 sorry
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

Total: 2747+ cases, all PASS

## Key Technical Notes
- `split_ifs` NOT available without Mathlib
- `omega` CANNOT handle if-then-else — use `by_cases` + `simp` first
- Best pattern: `by_cases h : cond <;> simp [h] <;> omega`
- `simp only [h1, ite_true]` may close goal completely
- `Min.min a b` ≠ `Nat.min a b` for rewriting
- UInt8 bit-ops work cleanly with `decide` for small types
- `nlinarith`, `push_neg`, `norm_num` NOT available without Mathlib
- Use `namespace FVSquad.ModuleName` to avoid name collisions across files
- `le_refl` → use `Nat.le_refl` or `Nat.le.refl`
- Cross-module name collision: use namespaces (e.g., Gain struct needs namespace)
- `Nat.div_le_div_of_mul_le_mul` is NOT available; use calc + existing lemmas

## Next Run Priorities
1. Route-B for T65 (SsThresh): write-once check vs recovery/congestion
2. Route-B for T32 (BBR2PacingRate): monotone path vs Rust fixture
3. New target: BBR2 Startup phase constants (analogous to T70 Drain)
4. CORRESPONDENCE.md update to cover runs 167–169
5. T26 W_est: add transition condition W_cubic < W_est to Cubic.lean §6
