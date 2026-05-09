# Lean Squad Memory — dsyme/quiche

## Last updated
Run 144 (workflow 25598205203, 2026-05-09)

## FV Toolchain
- Lean 4.29.1 (elan, leanprover/lean4:stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 144)
- Lean files: 50
- Total theorems: ~949
- Total sorry: 11 (across 10 files)
- Route-B test targets: 14
- Status issue: #4 (open)

## Targets

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

### T58: QUIC Stream Limit Enforcement
- Phase: 1 (Research — run 142)
- Source: quiche/src/stream/mod.rs, quiche/src/lib.rs
- Priority: HIGH
- Next: Task 2 (informal spec) then Task 3+5

### T59: QUIC Transport Error Code Mapping
- Phase: 2 (Informal Spec — run 143)
- Source: quiche/src/error.rs (Error::to_wire, Error::to_c)
- Informal spec: formal-verification/specs/transport_error_code_informal.md
- Priority: MEDIUM — write FVSquad/TransportErrorCode.lean next run
- Key finding: to_wire is NOT injective (many → ProtocolViolation 0xa);
  to_c IS injective (all 22 variants → distinct [-23, -1])
- OQs: OQ-T59-1 (OutOfIdentifiers asymmetry), OQ-T59-2 (C API stability),
  OQ-T59-3 (Error::Done reachability)
- Next: Task 3+5 (fully decidable with decide/native_decide)

### T60: BBR2 ProbeRTT State Machine
- Phase: 1 (Research — run 142)
- Source: quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs
- Priority: MEDIUM
- Next: Task 2 (informal spec)

### Earlier targets (T1-T54): All phase 5 (Done)

## CORRESPONDENCE.md Status (run 143)
- ALL 50 Lean files now have entries — NO GAPS
- Known mismatches: none

## Open PRs (lean-squad label)
- run 143: CORRESPONDENCE.md 4 new entries + T59 informal spec (pending)
- run 144: REPORT update (50 files, 949 thms) + Route-B T56 991/991

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

Total: 1463 cases, all PASS

## Key Technical Notes
- `split_ifs` NOT available without Mathlib
- `omega` CANNOT handle if-then-else — use `by_cases` + `simp` first
- Best pattern for if-then-else proofs: define with explicit ite + `by_cases h : cond <;> simp [h] <;> omega`
- `simp only [h1, ite_true]` may close goal completely — check before adding more tactics
- `Min.min a b` ≠ `Nat.min a b` for rewriting purposes — use unfolded ite

## Next Run Priorities
1. T59: Transport Error Code Mapping — write FVSquad/TransportErrorCode.lean (Task 3+5)
   All proofs should be decide/native_decide. ~15 theorems, ~80 lines.
2. T58: Stream Limit Enforcement — write informal spec (Task 2)
3. T60: BBR2 ProbeRTT State Machine — write informal spec (Task 2)
4. Close sorry in BBR2StartupExit, ProbeBWPhase, LossDetectionThreshold (Task 5)
