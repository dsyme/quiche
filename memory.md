# Lean Squad Memory — dsyme/quiche

## Last updated
Run 157 (workflow 25818377528, 2026-05-13)

## FV Toolchain
- Lean 4.29.1 (elan, leanprover/lean4:stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)
- lean-toolchain: leanprover/lean4:v4.29.1 (updated run 157, was v4.29.0)

## Repository State (after run 157)
- Lean files: 57 (after merging open PRs 126, 151, 153, 154)
- Total theorems: ~1296 (includes ProbeRTTPhase 21, ProbeRTTStateMachine 35, StreamCountLimit 16, Pmtud §2 8 new)
- Total sorry: 0
- Route-B test targets: 20 (added StreamCountLimit run 157)
- Status issue: #4 (open)

## Open PRs (lean-squad label) — as of run 157
All 4 prior open PRs (#126, #127, #129, #130) merged locally into run 157 branch.
- run 157 (branch lean-squad-run157-25818377528-stream-count-limit-routeb-ci):
  Task 8 — T63 Route-B tests (28/28 PASS)
  Task 9 — lean-toolchain updated to v4.29.1

## Targets

### T64: PMTUD Binary Search Convergence (run 156)
- Phase: 5 (Done — run 156)
- File: formal-verification/lean/FVSquad/Pmtud.lean (20 theorems)
- Binary search convergence §2 (theorems 13–20): all proved, 0 sorry
- CORRESPONDENCE.md: ✅ updated run 156

### T63: QUIC Peer Stream-Count Limit Update Monotonicity
- Phase: 5 (Done — run 153)
- File: formal-verification/lean/FVSquad/StreamCountLimit.lean
- Theorems: 16, sorry: 0
- Key finding: bare u64 subtraction in peer_streams_left_*() is unsafe
- Route-B tests: ✅ formal-verification/tests/stream_count_limit/ (28 PASS, run 157)
- CORRESPONDENCE.md: ✅ entry added run 154

### T60: BBR2 ProbeRTT State Machine
- Phase: 5 (Done — run 151; §6 lifecycle theorems added run 154)
- File: formal-verification/lean/FVSquad/ProbeRTTStateMachine.lean
- Theorems: 35 (27 original + 8 lifecycle), sorry: 0
- CORRESPONDENCE.md: ✅ entry added run 154

### T62: BBR2 ProbeRTT Phase Parameter Constants
- Phase: 5 (Done — run 150)
- File: formal-verification/lean/FVSquad/ProbeRTTPhase.lean
- Theorems: 21, sorry: 0
- CORRESPONDENCE.md: ✅ entry added run 154

### T61: QUIC STREAM Frame Type Byte Encoding
- Phase: 5 (Done — run 147)
- Theorems: 12, sorry: 0
- Route-B tests: ✅ 19 PASS

### T59: Transport Error Code Mapping
- Phase: 5 (Done — run 145; Route-B run 146)
- Theorems: 37, sorry: 0
- Route-B tests: ✅ 50 PASS

### T58: QUIC Stream Limit Enforcement
- Phase: 1 (Research — run 142)
- Source: quiche/src/stream/mod.rs, quiche/src/lib.rs
- Priority: HIGH
- Next: Task 2 (informal spec) then Task 3+5

### Earlier targets (T1-T57): All phase 5 (Done)

## CI Status (run 157)
- lean-ci.yml: exists, passing
- lean-toolchain: v4.29.1 (updated run 157)
- lake build: 58 jobs, 0 sorry

## CRITIQUE.md Status (run 153)
- Updated to cover ProbeRTTPhase, ProbeRTTStateMachine, StreamCountLimit
- Needs update: Pmtud §2 (8 new theorems), StreamCountLimit Route-B (28 cases)

## CORRESPONDENCE.md Status (run 154)
- ALL 55 Lean files have entries
- All ProbeRTT* and StreamCountLimit entries added

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

Total: 1623+ cases, all PASS

## Key Technical Notes
- `split_ifs` NOT available without Mathlib
- `omega` CANNOT handle if-then-else — use `by_cases` + `simp` first
- Best pattern: `by_cases h : cond <;> simp [h] <;> omega`
- `simp only [h1, ite_true]` may close goal completely
- `Min.min a b` ≠ `Nat.min a b` for rewriting
- UInt8 bit-ops work cleanly with `decide` for small types
- Nat subtraction: saturating; use `omega` for invariant+bounds
- For Nat.div proofs: introduce Nat.div_add_mod witness + Nat.mod_lt, then omega

## Next Run Priorities
1. T58: write informal spec for stream limit enforcement
2. Route-B tests for ProbeRTTPhase/ProbeRTTStateMachine
3. CRITIQUE.md update to include Pmtud convergence + StreamCountLimit Route-B result
4. Investigate T32 (BBR2 pacing rate bounds)
