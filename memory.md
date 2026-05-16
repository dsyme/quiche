# Lean Squad Memory — dsyme/quiche

## Last updated
Run 165 (workflow 25959142089, 2026-05-16)

## FV Toolchain
- Lean 4.29.0 (lake project pinned, lean-toolchain: v4.29.0)
- Lean 4.29.1 (installed by elan for run 165)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 165)
- Lean files: 61 (unchanged)
- Total theorems: ~1405 (+10 from T26 W_est extension)
- Total sorry: 0
- Route-B test targets: 22
- Status issue: #4 (open)

## Open PRs (lean-squad label) — as of run 165
- run164 (branch lean-squad-run164-25952591048-cid-retire-if-needed): T27 CidMgmt (MERGED into master before run165)
- run165 (branch lean-squad-run165-25959142089-cubic-west-bbr2pacing):
  Task 2 — T32 BBR2 pacing rate informal spec (specs/bbr2_pacing_rate_informal.md)
  Task 5 — T26 CUBIC W_est Reno-friendly theorems (10 new thms in Cubic.lean)

## Targets

### T27: CidMgmt retire_if_needed (run 164)
- Phase: 5 (Done — run 164)
- File: formal-verification/lean/FVSquad/CidMgmt.lean (extended §10)
- New theorems: 7 (lowestSeq_mem, lowestSeq_le_all, filter_neq_length_lt,
  newScidRetire_count_le_limit, newScidRetire_nextSeq_inc,
  newScidRetire_new_seq_in_active, newScidRetire_lowest_removed)
- Key: RFC 9000 §5.1.1 — after retire-if-needed, count ≤ limit
- Precondition: count ≤ limit before call (fires at exactly-limit)
- Approximation: retire_prior_to bookkeeping not modelled

### T34: QPACK Static Table Lookup (discovered done in run 164)
- Phase: 5 (Already Done — exact run unknown, was in memory as phase 1)
- File: formal-verification/lean/FVSquad/QPACKStaticTable.lean
- Theorems: 12, sorry: 0
- TARGETS.md: shows phase 1 (needs update)

### T69: QUIC Version Policy (run 163)
- Phase: 5 (Done — run 163)
- File: formal-verification/lean/FVSquad/QuicVersionPolicy.lean
- Theorems: 13, sorry: 0

### T68: BBR2 Probe-Up Inflight-Hi Slope (run 162)
- Phase: 5 (Done — run 162)
- File: formal-verification/lean/FVSquad/BBR2ProbeUpSlope.lean
- Theorems: 17, sorry: 0

### T67: BBR2 Inflight Lower Bound Guard (run 161/162)
- Phase: 5 (Done — run 162)
- File: formal-verification/lean/FVSquad/BBR2InflightLo.lean
- Theorems: 15, sorry: 0

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
- lake build: 64 jobs (run 164), 0 sorry
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
1. T32 (BBR2 pacing rate): write FVSquad/BBR2PacingRate.lean — informal spec done run165, ~60-80 lines, all omega
2. T26 (CUBIC W_est): informal spec still needed for TARGETS.md/specs/ — add specs/cubic_west_informal.md
3. Route-B tests for T66 (AckDelayCodec) — verify encode/decode match lib.rs
4. Route-B tests for T67 (BBR2InflightLo) — verify against network_model.rs
5. CRITIQUE.md update: T67 + T68 + T69 + T27 + T26 additions
6. TARGETS.md: update T34 to phase 5 (QPACKStaticTable already done); add T26 entry

## T26: CUBIC W_est Reno-friendly transition (run 165)
- Phase: 5 (Done — run 165, extension of Cubic.lean §6)
- File: formal-verification/lean/FVSquad/Cubic.lean (extended with §6)
- New theorems: 10 (wEstInc_nonneg, wEstInc_monotone_acked, wEstInc_antitone_cwnd,
  wEstIncAimd_le_max, aimdRegion_cwnd_ge_west, aimdRegion_cwnd_ge_old,
  wEstInc_monotone_alpha, wEstIncAimd_concrete_ack17, wEstIncMax_concrete,
  wEstIncAimd_lt_max_concrete)
- Cubic.lean now: 36 theorems, 0 sorry
- Note: no separate informal spec file written (TARGETS.md needs updating)

## T32: BBR2 pacing rate bounds (run 165)
- Phase: 2 (Informal spec written — run 165)
- File (spec): formal-verification/specs/bbr2_pacing_rate_informal.md
- Key properties: STARTUP monotonicity (max pattern), first-ACK initialisation,
  full-bw-reached sets to target_rate, early exit cases
- 3 open questions: OQ-T32-1 (bandwidth overflow), OQ-T32-2 (zero min_rtt),
  OQ-T32-3 (MSS scaling interaction)
- Next: write FVSquad/BBR2PacingRate.lean (~60-80 lines, all omega)
