# Lean Squad Memory — dsyme/quiche

## Last updated
Run 160 (workflow 25877523443, 2026-05-14)

## FV Toolchain
- Lean 4.29.1 (lake project pinned, lean-toolchain: v4.29.0)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 160)
- Lean files: 58 (added AckDelayCodec.lean)
- Total theorems: ~1351 (18 new)
- Total sorry: 0
- Route-B test targets: 22
- Status issue: #4 (open)

## Open PRs (lean-squad label) — as of run 160
- run158 (branch lean-squad-run158-25841769885-probertt-sm-routeb-stream-credit):
  Task 5 — T58 StreamCreditReturn.lean (20 thms, 0 sorry)
  Task 8 — T60 Route-B tests (23/23 PASS)
- run159 (branch lean-squad-run159-25856468108-new-target-routeb):
  Task 5 — T65 SsThresh.lean (17 thms, 0 sorry)
  Task 8 — BBR2Limits Route-B tests (15 tests, 1000+ cases PASS)
- run160 (branch lean-squad-run160-25877523443-bbr2pacing-informal):
  Task 2 — T66 AckDelayCodec informal spec
  Task 5 — T66 AckDelayCodec.lean (18 thms, 0 sorry)

## Targets

### T66: ACK Delay Encode/Decode Codec (run 160)
- Phase: 5 (Done — run 160)
- File: formal-verification/lean/FVSquad/AckDelayCodec.lean
- Informal spec: formal-verification/specs/ack_delay_codec_informal.md
- Theorems: 18, sorry: 0
- Models: encode/decode from lib.rs ~L4487-4497 and ~L8173-8182
- Key: roundtrip_exact (multiples of 2^exp), roundtrip_gap_lt (floor semantics)
- Open Qs: OQ-T66-1 (varint bound check), OQ-T66-2 (local vs peer exponent)
- CORRESPONDENCE.md: not yet updated

### T65: SsThresh Write-Once Invariant (run 159)
- Phase: 5 (Done — run 159)
- File: formal-verification/lean/FVSquad/SsThresh.lean
- Theorems: 17, sorry: 0

### T58: QUIC Stream Credit Return (run 158)
- Phase: 5 (Done — run 158)
- File: formal-verification/lean/FVSquad/StreamCreditReturn.lean
- Theorems: 20, sorry: 0

### T64: PMTUD Binary Search Convergence (run 156)
- Phase: 5 (Done — run 156)
- File: formal-verification/lean/FVSquad/Pmtud.lean (20 theorems)

### T63: QUIC Peer Stream-Count Limit Update Monotonicity
- Phase: 5 (Done — run 153)
- File: formal-verification/lean/FVSquad/StreamCountLimit.lean (16 thms)
- Route-B tests: ✅ formal-verification/tests/stream_count_limit/ (28 PASS)

### T60: BBR2 ProbeRTT State Machine
- Phase: 5 (Done — run 151; §6 lifecycle theorems run 154)
- File: formal-verification/lean/FVSquad/ProbeRTTStateMachine.lean (35 thms)
- Route-B tests: ✅ formal-verification/tests/probe_rtt_sm/ (23/23 PASS, run 158)

### Earlier targets (T1-T57, T59, T61, T62, T64): All phase 5 (Done)

## CI Status
- lean-ci.yml: exists, passing
- lean-toolchain: v4.29.0
- lake build: 61 jobs (run 160), 0 sorry

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

Total: 2660+ cases, all PASS

## Key Technical Notes
- `split_ifs` NOT available without Mathlib
- `omega` CANNOT handle if-then-else — use `by_cases` + `simp` first
- Best pattern: `by_cases h : cond <;> simp [h] <;> omega`
- `simp only [h1, ite_true]` may close goal completely
- `Min.min a b` ≠ `Nat.min a b` for rewriting
- UInt8 bit-ops work cleanly with `decide` for small types
- Nat subtraction: saturating; use `omega` for invariant+bounds
- For Nat.div proofs: use `Nat.div_mul_cancel` for exact round-trips
- For gap proofs: use `Nat.mod_def` + `Nat.mul_comm` to connect d%n to d-n*(d/n)
- `ring` does NOT work after `subst` on hypotheses with pow — use `omega`
- `dvd_refl` is NOT available — use `Nat.dvd_refl`
- `dvd_mul_left` is NOT available — use `Nat.dvd_mul_left`
- validExponent as Prop with `decide` requires `abbrev` not `def`

## Next Run Priorities
1. Route-B tests for T66 (AckDelayCodec) — verify encode/decode match lib.rs
2. T32 (BBR2 pacing rate): full informal spec (f32 → Rat approximation)
3. CRITIQUE.md update: T65 SsThresh + BBR2Limits Route-B + T66
4. CORRESPONDENCE.md update: add T66 AckDelayCodec entry
