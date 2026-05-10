# Lean Squad Memory — dsyme/quiche

## Last updated
Run 146 (workflow 25619893713, 2026-05-10)

## FV Toolchain
- Lean 4.29.1 (elan, leanprover/lean4:stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 146)
- Lean files: 51
- Total theorems: ~986
- Total sorry: 0
- Route-B test targets: 16 (T59 added this run)
- Status issue: #4 (open)

## Targets

### T61: QUIC STREAM Frame Type Byte Encoding
- Phase: 1 (Research — run 146)
- Source: quiche/src/frame.rs encode_stream_header (L1326-L1350)
- Priority: MEDIUM-LOW
- Key: encode_stream_header always produces 0x0e or 0x0f — only 2 possible values
- Next: Task 3+5 (write FVSquad/StreamFrameType.lean directly)

### T62: BBR2 ProbeRTT Phase Parameter Constants
- Phase: 1 (Research — run 146)
- Source: quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs
- Priority: MEDIUM
- Key: pacing_gain=0.8, cwnd_gain=0.5 (both sub-unity → inflight drain guaranteed)
- Next: Write informal spec (Task 2) then Task 3+5

### T59: Transport Error Code Mapping
- Phase: 5 (Done — run 145; Route-B run 146)
- File: formal-verification/lean/FVSquad/TransportErrorCode.lean
- Theorems: 37, sorry: 0
- CORRESPONDENCE.md: ✅ entry (run 146)
- Route-B tests: ✅ formal-verification/tests/transport_error_code/ (50 PASS)
- Key findings: toWire NOT injective (13 variants → ProtocolViolation 0xa); toC IS injective

### T60: BBR2 ProbeRTT State Machine
- Phase: 1 (Research — run 142)
- Source: quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs
- Priority: MEDIUM
- Next: Task 2 (informal spec)

### T58: QUIC Stream Limit Enforcement
- Phase: 1 (Research — run 142)
- Source: quiche/src/stream/mod.rs, quiche/src/lib.rs
- Priority: HIGH
- Next: Task 2 (informal spec) then Task 3+5

### T56: Loss Detection Packet Threshold
- Phase: 5 (Done — run 142; Route-B run 144)
- File: formal-verification/lean/FVSquad/LossDetectionThreshold.lean
- Theorems: 16, sorry: 1
- CORRESPONDENCE.md: ✅ entry (run 143)
- Route-B tests: ✅ formal-verification/tests/loss_detection_threshold/ (991 PASS)
- Notes: 1 sorry remains (float time_thresh not modelled)

### T57: BBR2 ProbeBW Phase Gains
- Phase: 5 (Done — run 140; Route-B run 142)
- File: formal-verification/lean/FVSquad/ProbeBWPhase.lean
- Theorems: 12, sorry: 1
- CORRESPONDENCE.md: ✅ entry
- Route-B tests: ✅ formal-verification/tests/probe_bw_phase/ (10 PASS)

### T55: BBR2 Startup Exit
- Phase: 5 (Done — run 139)
- File: formal-verification/lean/FVSquad/BBR2StartupExit.lean
- Theorems: 15, sorry: 1

### Earlier targets (T1-T54): All phase 5 (Done)

## CORRESPONDENCE.md Status (run 146)
- ALL 51 Lean files now have entries — NO GAPS
- Known mismatches: none

## Open PRs (lean-squad label)
- run 146: T59 Route-B tests + CORRESPONDENCE.md T59 entry + research T61/T62

## Status Issue
- #4 open — updated each run

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

Total: 1513 cases, all PASS

## Key Technical Notes
- `split_ifs` NOT available without Mathlib
- `omega` CANNOT handle if-then-else — use `by_cases` + `simp` first
- Best pattern for if-then-else proofs: define with explicit ite + `by_cases h : cond <;> simp [h] <;> omega`
- `simp only [h1, ite_true]` may close goal completely — check before adding more tactics
- `Min.min a b` ≠ `Nat.min a b` for rewriting purposes — use unfolded ite
- `decide` CANNOT handle ∀ n : Nat — use `simp [toWire/toC]` for parameterised cases
- `cases e <;> decide` fails for parameterised variants — use `cases e <;> simp [f]`

## Next Run Priorities
1. T61: STREAM Frame Type Byte Encoding — write FVSquad/StreamFrameType.lean (Task 3+5)
2. T58: Stream Limit Enforcement — write informal spec (Task 2) then Task 3+5
3. T62: BBR2 ProbeRTT Phase Params — write informal spec (Task 2)
4. Close sorry in BBR2StartupExit, ProbeBWPhase, LossDetectionThreshold (Task 5)
