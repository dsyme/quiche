# Lean Squad Memory — dsyme/quiche

## Last updated
Run 151 (workflow 25688964827, 2026-05-11)

## FV Toolchain
- Lean 4.29.1 (elan, leanprover/lean4:stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 151)
- Lean files: 54 (53 merged + ProbeRTTStateMachine in open PR)
- Total theorems: ~1048 (1024 + 24 new)
- Total sorry: 0
- Route-B test targets: 19
- Status issue: #4 (open)

## Targets

### T63: QUIC Peer Stream-Count Limit Update Monotonicity
- Phase: 1 (Research — run 151)
- Source: quiche/src/stream/mod.rs L529–L590
- Priority: HIGH
- Key finding: bare u64 subtraction in peer_streams_left_bidi() (line 578)
  is unsafe if local_opened > peer_max (underflow wraps to huge value)
- Next: Task 2 (informal spec) then Task 3+5

### T60: BBR2 ProbeRTT State Machine
- Phase: 5 (Done — run 151)
- File: formal-verification/lean/FVSquad/ProbeRTTStateMachine.lean
- Theorems: 24, sorry: 0
- Informal spec: formal-verification/specs/probe_rtt_state_machine_informal.md
- State: ProbeRttState (draining | waiting t), ProbeRttResult (stay | exitToProbeBW)
- Models: congestionStep, quiescenceStep
- Key theorems: draining→waiting, waiting→exit, quiescence fast-path,
  exit time immutability, exhaustive case dichotomy, cross-function agreement
- CORRESPONDENCE.md: not yet updated
- Route-B tests: not yet

### T62: BBR2 ProbeRTT Phase Parameter Constants
- Phase: 5 (Done — run 150)
- File: formal-verification/lean/FVSquad/ProbeRTTPhase.lean
- Theorems: 26, sorry: 0
- CORRESPONDENCE.md: not yet updated

### T61: QUIC STREAM Frame Type Byte Encoding
- Phase: 5 (Done — run 147)
- File: formal-verification/lean/FVSquad/StreamFrameType.lean
- Theorems: 12, sorry: 0
- CORRESPONDENCE.md: ✅ entry (run 147)
- Route-B tests: ✅ formal-verification/tests/stream_frame_type/ (19 PASS)

### T59: Transport Error Code Mapping
- Phase: 5 (Done — run 145; Route-B run 146)
- File: formal-verification/lean/FVSquad/TransportErrorCode.lean
- Theorems: 37, sorry: 0
- CORRESPONDENCE.md: ✅ entry (run 146)
- Route-B tests: ✅ formal-verification/tests/transport_error_code/ (50 PASS)

### T58: QUIC Stream Limit Enforcement
- Phase: 1 (Research — run 142)
- Source: quiche/src/stream/mod.rs, quiche/src/lib.rs
- Priority: HIGH
- Next: Task 2 (informal spec) then Task 3+5

### T56: Loss Detection Packet Threshold
- Phase: 5 (Done — run 142; Route-B run 144)
- Theorems: 16, sorry: 0; Route-B 991 PASS

### IdleTimeout (T46)
- Phase: 5 (Done — run 128; Route-B run 148)
- Theorems: 12, sorry: 0; Route-B 38 PASS

### T57: BBR2 ProbeBW Phase Gains
- Phase: 5 (Done — run 140; Route-B run 142)
- Theorems: 12, sorry: 0; Route-B 10 PASS

### Earlier targets (T1-T54): All phase 5 (Done)

## CRITIQUE.md Status (run 149)
- Updated to cover PRR (20 thms, RFC 6937 rate-control) and Pmtud (15 thms, RFC 8899)
- Overall status: 52 files, ~998 theorems, 0 sorry
- 18 Route-B targets, 1570+ cases PASS

## CORRESPONDENCE.md Status (run 149)
- ALL 52 Lean files have entries (run 149 refresh)
- T62 (ProbeRTTPhase) NOT YET in CORRESPONDENCE.md
- T60 (ProbeRTTStateMachine) NOT YET in CORRESPONDENCE.md

## Open PRs (lean-squad label)
- run 151 (PR pending): ProbeRTTStateMachine.lean (24 thms) + T63 research

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
| T61 (StreamFrameType) | tests/stream_frame_type/ | 19 | 147 |
| IdleTimeout | tests/idle_timeout/ | 38 | 148 |
| PRR | tests/prr/ | 25 | 150 |

Total: 1595+ cases, all PASS

## Key Technical Notes
- `split_ifs` NOT available without Mathlib
- `omega` CANNOT handle if-then-else — use `by_cases` + `simp` first
- Best pattern for if-then-else proofs: `by_cases h : cond <;> simp [h] <;> omega`
- `simp only [h1, ite_true]` may close goal completely — check before adding more
- `push_neg` NOT available without Mathlib — use `omega` instead
- `split at h` fails on hypothesis goals — use `by_cases` pattern instead
- Use `simp only [defn]` followed by `by_cases` for conditional definitions
- `Min.min a b` ≠ `Nat.min a b` for rewriting purposes — use unfolded ite
- UInt8 bit-ops work cleanly with `decide` for small types
- `cases ht` works for `ht : .waiting exitTime = .waiting t` injections
- Nat division: omega cannot reason about it; use div_add_mod lemmas for bounds

## Next Run Priorities
1. T63: Stream Count Limit — write informal spec then FVSquad/StreamCountLimit.lean
2. T58: Stream Limit Enforcement — write informal spec (Task 2)
3. Add CORRESPONDENCE.md entries for T60 (ProbeRTTStateMachine) and T62 (ProbeRTTPhase)
4. Pmtud Route-B tests (no Route-B yet)
5. Inductive termination theorem for Pmtud binary search
