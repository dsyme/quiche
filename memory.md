# Lean Squad Memory — dsyme/quiche

## Last updated
Run 167 (workflow 25981547348, 2026-05-17)

## FV Toolchain
- Lean 4.29.0 (lake project pinned, lean-toolchain: v4.29.0)
- Lean 4.29.1 (installed by elan for recent runs)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 167)
- Lean files: 62 (BBR2PacingRate.lean added)
- Total theorems: ~1419 (+14)
- Total sorry: 0
- Route-B test targets: 23 (ack_delay_codec added)
- Status issue: #4 (open)

## Open PRs (lean-squad label) — as of run 167
- run167 (branch lean-squad-run167-25981547348-bbr2pacingrate-ackdelay-rt):
  Task 5 — T32 BBR2PacingRate.lean (14 thms, 0 sorry)
  Task 8 — T66 AckDelay Route-B tests (31/31 PASS)
  CORRESPONDENCE.md — T66 Route-B evidence added

## Targets

### T32: BBR2 pacing rate bounds
- Phase: 5 (Done — run 167, 14 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2PacingRate.lean
- Key theorems: startup_monotone, startup_ge_target, full_bw_sets_target,
  target_monotone_in_bw, target_monotone_in_gain, zero_bw_unchanged, Case B cap bounds
- Open questions: OQ-T32-1 (bandwidth overflow), OQ-T32-2 (zero min_rtt), OQ-T32-3 (MSS scaling)

### T26: CUBIC W_est Reno-friendly transition
- Phase: 5 (Done — run 165, extension of Cubic.lean §6)
- File: formal-verification/lean/FVSquad/Cubic.lean (§6, 10 new thms, total 36)
- CRITIQUE.md entry: run 166 ✅
- CORRESPONDENCE.md entry: run 166 ✅
- Remaining gap: transition condition W_cubic < W_est not yet modelled

### T27: CidMgmt retire_if_needed
- Phase: 5 (Done — run 164, §10 of CidMgmt.lean, 7 new thms, total 27)
- CRITIQUE.md entry: run 166 ✅
- CORRESPONDENCE.md entry: run 166 ✅
- Remaining gap: retire_prior_to bookkeeping not modelled

### T69: QUIC Version Policy
- Phase: 5 (Done — run 163)
- File: formal-verification/lean/FVSquad/QuicVersionPolicy.lean (13 thms, 0 sorry)
- CRITIQUE.md entry: run 166 ✅
- CORRESPONDENCE.md entry: run 163 ✅

### T68: BBR2 Probe-Up Inflight-Hi Slope
- Phase: 5 (Done — run 162)
- File: formal-verification/lean/FVSquad/BBR2ProbeUpSlope.lean (17 thms, 0 sorry)
- CRITIQUE.md entry: run 166 ✅
- CORRESPONDENCE.md entry: run 163 ✅

### T67: BBR2 Inflight Lower Bound Guard
- Phase: 5 (Done — run 161/162)
- File: formal-verification/lean/FVSquad/BBR2InflightLo.lean (15 thms, 0 sorry)
- CRITIQUE.md entry: run 166 ✅
- CORRESPONDENCE.md entry: run 163 ✅

### T66: ACK Delay Encode/Decode Codec
- Phase: 5 (Done — run 160)
- File: formal-verification/lean/FVSquad/AckDelayCodec.lean (16 thms, 0 sorry)
- CRITIQUE.md entry: run 166 ✅
- CORRESPONDENCE.md entry: run 166 ✅

### T65: SsThresh Write-Once Invariant
- Phase: 5 (Done — run 159)
- File: formal-verification/lean/FVSquad/SsThresh.lean (14 thms, 0 sorry)
- CRITIQUE.md entry: run 166 ✅
- CORRESPONDENCE.md entry: run 163 ✅

### T58: QUIC Stream Credit Return
- Phase: 5 (Done — run 158)
- File: formal-verification/lean/FVSquad/StreamCreditReturn.lean (20 thms, 0 sorry)
- CRITIQUE.md entry: run 166 ✅
- CORRESPONDENCE.md entry: run 163 ✅

### T34: QPACK Static Table Lookup
- Phase: 5 (Already Done — exact run unknown)
- File: formal-verification/lean/FVSquad/QPACKStaticTable.lean (12 thms, 0 sorry)

### Earlier targets (T1-T57, T59-T64): All phase 5 (Done)

## CI Status
- lean-ci.yml: exists, passing, healthy
- lean-toolchain: v4.29.0
- lake build: 61 files (run 165), 0 sorry
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

Total: 2691+ cases, all PASS

## Key Technical Notes
- `split_ifs` NOT available without Mathlib
- `omega` CANNOT handle if-then-else — use `by_cases` + `simp` first
- Best pattern: `by_cases h : cond <;> simp [h] <;> omega`
- `simp only [h1, ite_true]` may close goal completely
- `Min.min a b` ≠ `Nat.min a b` for rewriting
- UInt8 bit-ops work cleanly with `decide` for small types
- UInt32 bit-ops: use `cases h : isSupportedVersion v` + subst + decide
- After subst on UInt32 literal: use `exact absurd hr (by decide)` not `simp`
- `simp [CONST] at hs` where CONST is UInt32 may leave `v = literal` not auto-subst
- Use `simp only [..., beq_iff_eq] at hs` then `subst hs` for UInt32 equality
- `Bool.and_eq_false_iff_not_and` does NOT exist; use `cases h : boolExpr with`
- Nat subtraction: saturating; use `omega` for invariant+bounds
- For Nat.div proofs: use `Nat.div_mul_cancel` for exact round-trips
- `ring` does NOT work after `subst` on hypotheses with pow — use `omega`
- `dvd_refl` is NOT available — use `Nat.dvd_refl`
- `norm_num` NOT available without Mathlib — use `decide` for concrete arithmetic
- `push_neg` NOT available without Mathlib — use `by_contra h0; have := by omega`
- `not_lt` NOT available — use omega directly or `by_cases` on the comparison
- `Nat.mod_def : d % m = d - m * (d / m)` — use for % goals where omega fails
- For `lowestSeq (y::ys) ∈ y::ys` IH membership: use `simp [List.mem_cons] at hmem` then `exact Or.inr hmem`
- `List.filter_cons_of_pos hbne` rewrites `filter (a :: rest) = a :: filter rest` when `p a = true`
- `List.length_filter_le` available for bounds on filter length

## Next Run Priorities
1. Route-B for T27 (CidMgmt retire_if_needed) — `cid.rs:L359`, retire_if_needed function
2. Composed theorem: StreamCreditReturn + StreamCountLimit → RFC 9000 §4.6 end-to-end
3. T26 W_est: add transition condition W_cubic < W_est to Cubic.lean §6
4. New Lean file: T32 informal spec has OQ-T32-1 (overflow) worth a separate model
5. Route-B for T32 BBR2PacingRate: fixture comparison monotone path vs Rust
6. New proofs: BBR2 pacing rate informal spec OQs → could find bugs in BBR2
