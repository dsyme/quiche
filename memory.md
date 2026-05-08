# Lean Squad Memory — dsyme/quiche

## Last updated
Run 142 (workflow 25570960972, 2026-05-08)

## FV Toolchain
- Lean 4.29.1 (elan, leanprover/lean4:stable)
- Lake project: formal-verification/lean/
- Mathlib: NOT used (stdlib only, intentional)

## Repository State (after run 142)
- Lean files: 50
- Total theorems: ~964
- Total sorry: 0
- Route-B test targets: 14
- Status issue: #4 (open)

## Targets

### T56: Loss Detection Packet Threshold
- Phase: 5 (Done — run 142)
- File: formal-verification/lean/FVSquad/LossDetectionThreshold.lean
- Theorems: 16, sorry: 0
- Source: recovery/mod.rs (L51,53) + recovery/congestion/recovery.rs (L655-660)
- CORRESPONDENCE.md: ✅ entry added (run 142)
- Route-B tests: not yet (simple arithmetic; #eval spot-checks in-file)
- PR: run 142 (pending merge)

### T57: BBR2 ProbeBW Phase Gains
- Phase: 5 (Done — run 138/139, Route-B run 142)
- File: formal-verification/lean/FVSquad/ProbeBWPhase.lean
- Theorems: 12, sorry: 0
- Source: gcongestion/bbr2/mode.rs (L49-75), bbr2.rs (L291-300)
- CORRESPONDENCE.md: ✅ entry added (run 142)
- Route-B tests: ✅ formal-verification/tests/probe_bw_phase/ (10 PASS)
- PR: run 142 (pending merge)

### T58: QUIC Stream Limit Enforcement
- Phase: 1 (Research — run 142)
- Source: quiche/src/stream/mod.rs, quiche/src/lib.rs
- Priority: HIGH
- Next: Task 2 (informal spec) then Task 3+5

### T59: QUIC Transport Error Code Mapping
- Phase: 1 (Research — run 142)
- Source: quiche/src/lib.rs (Error enum), quiche/src/ffi.rs
- Priority: MEDIUM — RECOMMENDED NEXT (fully decidable)
- Next: Task 3+5 (write FVSquad/TransportErrorCode.lean)

### T60: BBR2 ProbeRTT State Machine
- Phase: 1 (Research — run 142)
- Source: quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs
- Priority: MEDIUM
- Next: Task 2 (informal spec)

### Earlier targets (T1-T55): All phase 5 (Done)
- Full history in fv_state.md / state.md
- Key files: HyStartThreshold.lean, BBR2StartupExit.lean, ProbeBWPhase.lean,
  LossDetectionThreshold.lean, etc.

## Open PRs (lean-squad label)
- run 142: T56 LossDetectionThreshold + T57 Route-B tests (pending)

## Status Issue
- #4 open — updated each run

## Key Technical Notes
- `split_ifs` NOT available without Mathlib
- `Nat.max_le_max_left/right`, `Nat.min_le_min_left/right` do NOT exist
- `omega` CANNOT handle if-then-else — use `by_cases` + `simp` first
- Best pattern for if-then-else proofs: define with explicit ite + `by_cases h : cond <;> simp [h] <;> omega`
- `simp only [h1, ite_true]` may close goal completely — check before adding more tactics
- `Min.min a b` ≠ `Nat.min a b` for rewriting purposes — use unfolded ite

## Next Run Priorities
1. T59: Transport Error Code Mapping — write FVSquad/TransportErrorCode.lean (Task 3+5)
2. T58: Stream Limit Enforcement — write informal spec (Task 2)
3. Conference paper update (50 files, ~964 theorems)
