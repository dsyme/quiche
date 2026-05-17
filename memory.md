# Lean Squad Memory — dsyme/quiche

## Last updated
Run 168 (workflow 25987980642, 2026-05-17)

## FV Toolchain
- Lean 4.29.0 (lake project pinned, lean-toolchain: v4.29.0)
- Lean 4.29.1 (installed by elan for recent runs)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 168)
- Lean files: 63 (RFC9000Sec46.lean added)
- Total theorems: ~1431 (+12)
- Total sorry: 0
- Route-B test targets: 23 (ack_delay_codec added in run 167)
- Status issue: #4 (open)

## Open PRs (lean-squad label) — as of run 168
- run168 (branch lean-squad-run168-25987980642-proof-critique):
  Task 5 — RFC9000Sec46.lean (12 thms, 0 sorry) — RFC 9000 §4.6 composed proof
  Task 7 — CRITIQUE.md updated (run 168)

## Targets

### RFC9000Sec46 (new): RFC 9000 §4.6 composed end-to-end
- Phase: 5 (Done — run 168, 12 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/RFC9000Sec46.lean
- Key theorems: rfc9000_peer_max_monotone, rfc9000_peer_gains_n_slots,
  rfc9000_streams_left_gain, step_local_current_increases
- Imports: StreamCreditReturn.lean, StreamCountLimit.lean

### T32: BBR2 pacing rate bounds
- Phase: 5 (Done — run 167, 14 thms, 0 sorry)
- File: formal-verification/lean/FVSquad/BBR2PacingRate.lean
- Key theorems: startup_monotone, startup_ge_target, full_bw_sets_target,
  target_monotone_in_bw, target_monotone_in_gain, zero_bw_unchanged, Case B cap bounds
- Open questions: OQ-T32-1 (bandwidth overflow), OQ-T32-2 (zero min_rtt), OQ-T32-3 (MSS scaling)

### T26: CUBIC W_est Reno-friendly transition
- Phase: 5 (Done — run 165, extension of Cubic.lean §6)
- File: formal-verification/lean/FVSquad/Cubic.lean (§6, 10 new thms, total 36)
- Remaining gap: transition condition W_cubic < W_est not yet modelled

### T27: CidMgmt retire_if_needed
- Phase: 5 (Done — run 164, §10 of CidMgmt.lean, 7 new thms, total 27)
- Remaining gap: retire_prior_to bookkeeping not modelled

### Earlier targets (T1-T69, all): All phase 5 (Done)

## CI Status
- lean-ci.yml: exists, passing, healthy
- lean-toolchain: v4.29.0
- lake build: 63 files (run 168), 0 sorry
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
- For `max` goals: NEVER use omega on `if ... then ... else ...` form of max
  Use `Nat.le_max_left`, `Nat.le_max_right`, `Nat.le_trans` explicitly
  Pattern: `exact Nat.le_trans h (Nat.le_max_right _ _)`
- `le_trans` NOT available at top level — use `Nat.le_trans`

## Next Run Priorities
1. Route-B for T27 (CidMgmt retire_if_needed) — `cid.rs:L359`, retire_if_needed function
2. Route-B for T65 (SsThresh): write-once check vs recovery/congestion
3. Route-B for T32 (BBR2PacingRate): monotone path vs Rust fixture  
4. T26 W_est: add transition condition W_cubic < W_est to Cubic.lean §6
5. CORRESPONDENCE.md update to cover runs 167–168
