# Lean Squad Memory — dsyme/quiche

## Last updated
Run 158 (workflow 25841769885, 2026-05-14)

## FV Toolchain
- Lean 4.29.0 (lake project pinned, lean-toolchain: v4.29.0)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 158)
- Lean files: 56 (added StreamCreditReturn.lean)
- Total theorems: ~1316
- Total sorry: 0
- Route-B test targets: 21 (added probe_rtt_sm run 158)
- Status issue: #4 (open)

## Open PRs (lean-squad label) — as of run 158
- run158 (branch lean-squad-run158-25841769885-probertt-sm-routeb-stream-credit):
  Task 5 — T58 StreamCreditReturn.lean (20 thms, 0 sorry)
  Task 8 — T60 Route-B tests (23/23 PASS)

## Targets

### T58: QUIC Stream Credit Return (run 158)
- Phase: 5 (Done — run 158)
- File: formal-verification/lean/FVSquad/StreamCreditReturn.lean
- Theorems: 20, sorry: 0
- Models collect() + update_max_streams_bidi/uni from stream/mod.rs
- Key: returnBidiN_adds_n, returnN_then_commit, creditInvariant preservation
- CORRESPONDENCE.md: ✅ entry added run 158

### T64: PMTUD Binary Search Convergence (run 156)
- Phase: 5 (Done — run 156)
- File: formal-verification/lean/FVSquad/Pmtud.lean (20 theorems)
- CORRESPONDENCE.md: ✅ updated run 156

### T63: QUIC Peer Stream-Count Limit Update Monotonicity
- Phase: 5 (Done — run 153)
- File: formal-verification/lean/FVSquad/StreamCountLimit.lean (16 thms)
- Route-B tests: ✅ formal-verification/tests/stream_count_limit/ (28 PASS, run 157)

### T60: BBR2 ProbeRTT State Machine
- Phase: 5 (Done — run 151; §6 lifecycle theorems run 154)
- File: formal-verification/lean/FVSquad/ProbeRTTStateMachine.lean (35 thms)
- Route-B tests: ✅ formal-verification/tests/probe_rtt_sm/ (23/23 PASS, run 158)
- CORRESPONDENCE.md: ✅ entry added run 154, Route-B updated run 158

### T62: BBR2 ProbeRTT Phase Parameter Constants
- Phase: 5 (Done — run 150)
- File: formal-verification/lean/FVSquad/ProbeRTTPhase.lean (21 thms)
- CORRESPONDENCE.md: ✅ entry added run 154

### Earlier targets (T1-T57, T59, T61): All phase 5 (Done)

## CI Status
- lean-ci.yml: exists, passing
- lean-toolchain: v4.29.0
- lake build: 59 jobs, 0 sorry (run 158)

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

Total: 1646+ cases, all PASS

## Key Technical Notes
- `split_ifs` NOT available without Mathlib
- `omega` CANNOT handle if-then-else — use `by_cases` + `simp` first
- Best pattern: `by_cases h : cond <;> simp [h] <;> omega`
- `simp only [h1, ite_true]` may close goal completely
- `Min.min a b` ≠ `Nat.min a b` for rewriting
- UInt8 bit-ops work cleanly with `decide` for small types
- Nat subtraction: saturating; use `omega` for invariant+bounds
- For Nat.div proofs: introduce Nat.div_add_mod witness + Nat.mod_lt, then omega
- `creditInvariant` proofs: use `obtain ⟨hb, hu⟩ := h` then direct omega
- `simp [creditInvariant, ...]` sometimes leaves goals for `obtain` + direct Nat.le proofs

## Next Run Priorities
1. T32 (BBR2 pacing rate bounds): gcongestion, phase 1 research
2. Route-B tests for ProbeRTTPhase (constant values: 10/10, 8/10, 5/10 gains)
3. CRITIQUE.md update: T58 StreamCreditReturn + T60 Route-B
4. New target research: stream_id parity/initiation invariants, ack_delay_exponent
