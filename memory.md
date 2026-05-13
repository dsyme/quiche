# Lean Squad Memory — dsyme/quiche

## Last updated
Run 156 (workflow 25795539761, 2026-05-13)

## FV Toolchain
- Lean 4.29.1 (elan, leanprover/lean4:stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 156)
- Lean files: 55
- Total theorems: ~1296 (added 8 convergence theorems to Pmtud)
- Total sorry: 0
- Route-B test targets: 19
- Status issue: #4 (open)

## Targets

### T64: PMTUD Binary Search Convergence (run 156)
- Phase: 5 (Done — run 156)
- File: formal-verification/lean/FVSquad/Pmtud.lean (now 20 theorems, was 12)
- Added §2 "Binary search convergence" with theorems 13–20:
  - gap_decreases_on_failure, gap_decreases_on_success: gap strictly decreases
  - upper_bound_halved: failure gap ≤ ⌊(f−g)/2⌋
  - lower_bound_halved: success gap ≤ ⌊(f−g)/2⌋ + 1
  - binary_search_terminates: key termination property (both outcomes reduce gap)
  - convergence_stable: at convergence, updateProbeSize = g and stays converged
  - gap_pos_of_not_converged: not converged → gap > 1
  - both_halved_bound: combined bound theorem
- CORRESPONDENCE.md: ✅ updated run 156 (added §2 theorem table + impact analysis)

### T63: QUIC Peer Stream-Count Limit Update Monotonicity
- Phase: 5 (Done — run 153)
- File: formal-verification/lean/FVSquad/StreamCountLimit.lean
- Theorems: 16, sorry: 0
- Key finding: bare u64 subtraction in peer_streams_left_*() is unsafe
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
- File: formal-verification/lean/FVSquad/StreamFrameType.lean
- Theorems: 12, sorry: 0
- Route-B tests: ✅ formal-verification/tests/stream_frame_type/ (19 PASS)

### T59: Transport Error Code Mapping
- Phase: 5 (Done — run 145; Route-B run 146)
- Theorems: 37, sorry: 0
- Route-B tests: ✅ (50 PASS)

### T58: QUIC Stream Limit Enforcement
- Phase: 1 (Research — run 142)
- Source: quiche/src/stream/mod.rs, quiche/src/lib.rs
- Priority: HIGH
- Next: Task 2 (informal spec) then Task 3+5

### Earlier targets (T1-T57): All phase 5 (Done)

## CI Status (run 156)
- lean-ci.yml: exists, passing
- lean-toolchain: v4.29.1

## CRITIQUE.md Status (run 153)
- Updated to cover ProbeRTTPhase, ProbeRTTStateMachine, StreamCountLimit
- Overall status: 55 files, ~1272 theorems, 0 sorry
- Needs update: Pmtud §2 (8 new theorems), StreamCountLimit finding

## CORRESPONDENCE.md Status (after run 156)
- ALL 55 Lean files have entries
- Pmtud entry updated: §2 theorem table + O(log n) termination analysis
- ProbeRTTPhase, ProbeRTTStateMachine, StreamCountLimit: entries from run 154

## Open PRs (lean-squad label)
- run 150 (PR #126): ProbeRTTPhase + PRR Route-B tests
- run 151 (PR #127): ProbeRTT SM + T63 research
- run 153 (PR #129): StreamCountLimit + Critique
- run 154 (PR #130): ProbeRTT lifecycle §6 + CORRESPONDENCE T60/T62/T63
- run 156 (branch lean-squad-run156-25795539761-pmtud-convergence-correspondence):
  Task 5 — Pmtud §2 convergence theorems (8 new, 20 total, 0 sorry)
  Task 6 — CORRESPONDENCE.md Pmtud entry updated

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
- Best pattern: `by_cases h : cond <;> simp [h] <;> omega`
- `simp only [h1, ite_true]` may close goal completely
- `Min.min a b` ≠ `Nat.min a b` for rewriting
- UInt8 bit-ops work cleanly with `decide` for small types
- Nat subtraction: saturating; use `omega` for invariant+bounds
- For Nat.div proofs: introduce Nat.div_add_mod witness + Nat.mod_lt, then omega

## Next Run Priorities
1. T58: write informal spec for stream limit enforcement
2. Route-B tests for StreamCountLimit (T63)
3. Route-B tests for ProbeRTTPhase/ProbeRTTStateMachine
4. CRITIQUE.md update to include Pmtud convergence + StreamCountLimit finding
5. Investigate T32 (BBR2 pacing rate bounds)
