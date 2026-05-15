# Lean Squad Memory — dsyme/quiche

## Last updated
Run 161 (workflow 25900534260, 2026-05-15)

## FV Toolchain
- Lean 4.29.1 (lake project pinned, lean-toolchain: v4.29.0)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 161)
- Lean files: 59 (added BBR2InflightLo.lean)
- Total theorems: ~1358 (15 new)
- Total sorry: 0
- Route-B test targets: 22
- Status issue: #4 (open)

## Open PRs (lean-squad label) — as of run 161
- run161 (branch lean-squad-run161-25900534260-bbr2inflightlo-report):
  Task 5 — T67 BBR2InflightLo.lean (15 thms, 0 sorry)
  Task 10 — REPORT.md update (59 files, 1358 thms, 0 sorry)

## Targets

### T67: BBR2 Inflight Lower Bound Guard (run 161)
- Phase: 5 (Done — run 161)
- File: formal-verification/lean/FVSquad/BBR2InflightLo.lean
- Theorems: 15, sorry: 0
- Models: clear_inflight_lo / cap_inflight_lo from network_model.rs ~L750-758
- Key: sentinel SENTINEL=2^64-1 guards cap; cap_after_clear_noop, cap_never_raises,
  double_cap_eq_min, cap_commutative, cap_idempotent
- SafeCap precondition: cap values < SENTINEL to avoid degenerate sentinel-cap edge case
- CORRESPONDENCE.md: not yet updated

### T66: ACK Delay Encode/Decode Codec (run 160)
- Phase: 5 (Done — run 160)
- File: formal-verification/lean/FVSquad/AckDelayCodec.lean
- Theorems: 18, sorry: 0

### T65: SsThresh Write-Once Invariant (run 159)
- Phase: 5 (Done — run 159)
- File: formal-verification/lean/FVSquad/SsThresh.lean
- Theorems: 17, sorry: 0

### T58: QUIC Stream Credit Return (run 158)
- Phase: 5 (Done — run 158)
- File: formal-verification/lean/FVSquad/StreamCreditReturn.lean
- Theorems: 20, sorry: 0

### Earlier targets (T1-T57, T59-T64): All phase 5 (Done)

## CI Status
- lean-ci.yml: exists, passing
- lean-toolchain: v4.29.0
- lake build: 62 jobs (run 161), 0 sorry

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
- `validExponent as Prop with `decide` requires `abbrev` not `def`
- Sentinel guards: `by_cases h : s.lo = SENTINEL; simp [h]; ...` pattern
- `Nat.min_le_right c s.lo : min c s.lo ≤ s.lo` (NOT `s.lo ≤ min c s.lo`)
- Min commutativity: use `Nat.min_left_comm` (or `simp [Nat.min_comm, Nat.min_left_comm]`)
- `Nat.ne_of_lt` for h : a < b → a ≠ b

## Next Run Priorities
1. Route-B tests for T66 (AckDelayCodec) — verify encode/decode match lib.rs
2. T32 (BBR2 pacing rate with f32 → scaled-int): write informal spec
3. CRITIQUE.md update: T67 BBR2InflightLo + recent additions
4. CORRESPONDENCE.md update: add T67 and T66 entries
