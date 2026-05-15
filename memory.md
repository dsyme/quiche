# Lean Squad Memory — dsyme/quiche

## Last updated
Run 163 (workflow 25933740409, 2026-05-15)

## FV Toolchain
- Lean 4.29.0 (lake project pinned, lean-toolchain: v4.29.0)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 163)
- Lean files: 61 (added QuicVersionPolicy.lean T69)
- Total theorems: ~1388 (13 new from T69)
- Total sorry: 0
- Route-B test targets: 22
- Status issue: #4 (open)

## Open PRs (lean-squad label) — as of run 163
- run163 (branch lean-squad-run163-25933740409-quic-version-correspondence):
  Task 5 — T69 QuicVersionPolicy.lean (13 thms, 0 sorry)
  Task 6 — CORRESPONDENCE.md updates for T67, T68, T69

## Targets

### T69: QUIC Version Policy (run 163)
- Phase: 5 (Done — run 163)
- File: formal-verification/lean/FVSquad/QuicVersionPolicy.lean
- Theorems: 13, sorry: 0
- Models: is_reserved_version + version_is_supported from lib.rs ~L479/615/434/1887
- Key: disjointness invariant reserved ∩ supported = ∅
  + V1 not reserved (greasing safety)
  + canonical greasing values (0x0a0a0a0a, 0x2a2a2a2a, 0xfafafafa) are reserved
- CORRESPONDENCE.md: updated (run 163)

### T68: BBR2 Probe-Up Inflight-Hi Slope (run 162)
- Phase: 5 (Done — run 162)
- File: formal-verification/lean/FVSquad/BBR2ProbeUpSlope.lean
- Theorems: 17, sorry: 0
- CORRESPONDENCE.md: updated (run 163)

### T67: BBR2 Inflight Lower Bound Guard (run 161/162)
- Phase: 5 (Done — run 162)
- File: formal-verification/lean/FVSquad/BBR2InflightLo.lean
- Theorems: 15, sorry: 0
- CORRESPONDENCE.md: updated (run 163)

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
- lean-ci.yml: exists, passing, healthy
- lean-toolchain: v4.29.0
- lake build: 64 jobs (run 163), 0 sorry
- Cache: keyed on lake-manifest.json hash (correct)
- Triggers: PR + push to main/master on formal-verification/lean/**

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
- UInt32 bit-ops: use `cases h : isSupportedVersion v` + subst + decide for disjointness
- After subst on UInt32 literal: use `exact absurd hr (by decide)` not `simp`
- `simp [CONST] at hs` where CONST is UInt32 may leave `v = literal` not auto-subst
- Use `simp only [..., beq_iff_eq] at hs` then `subst hs` for UInt32 equality
- `Bool.and_eq_false_iff_not_and` does NOT exist; use `cases h : boolExpr with`
- Nat subtraction: saturating; use `omega` for invariant+bounds
- For Nat.div proofs: use `Nat.div_mul_cancel` for exact round-trips
- `ring` does NOT work after `subst` on hypotheses with pow — use `omega`
- `dvd_refl` is NOT available — use `Nat.dvd_refl`
- `norm_num` NOT available without Mathlib — use `decide` for concrete arithmetic
- `push_neg` NOT available without Mathlib — use `by_contra h0; have := by omega` pattern
- `Nat.mod_def : d % m = d - m * (d / m)` — use for % goals where omega fails

## Next Run Priorities
1. Route-B tests for T66 (AckDelayCodec) — verify encode/decode match lib.rs
2. Route-B tests for T67 (BBR2InflightLo) — verify against network_model.rs
3. Route-B tests for T68 (BBR2ProbeUpSlope) — verify against probe_bw.rs
4. CRITIQUE.md update: T67 + T68 + T69 additions
5. T32 (BBR2 pacing rate with f32 → scaled-int): write informal spec + lean file
