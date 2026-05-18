# SsThresh Route-B Correspondence Tests

🔬 *Lean Squad — Route-B correspondence validation for SsThresh (T65).*

## What is being tested

The Lean model `FVSquad.SsThresh.SsThreshState` in
`formal-verification/lean/FVSquad/SsThresh.lean` is a functional model of the
`SsThresh` struct in `quiche/src/recovery/congestion/mod.rs`.

The key invariant modelled and proved in Lean:
- `startup_exit` is set **exactly once** on the first call to `update()`
- Subsequent calls update `ssthresh` freely but leave `startup_exit` unchanged
- The exit reason (`CSS` vs `Loss`) is determined solely by the first call's `in_css` flag

## How to run

```bash
cd formal-verification/tests/ssthresh
rustc --edition 2021 ssthresh_test.rs && ./ssthresh_test
```

No dependencies beyond a standard Rust toolchain.

## Test cases (25 total, all PASS)

| Group | Cases | What is tested |
|-------|-------|----------------|
| Default state | 1 | `ssthresh = usize::MAX`, `startup_exit = None` |
| First update | 4 | CSS and Loss reasons set correctly; ssthresh updated |
| Write-once invariant | 6 | Exit reason never overwritten by subsequent calls |
| ssthresh always updated | 4 | `ssthresh` equals last call's value across N updates |
| Non-default initial state | 3 | Starting with exit already set; updates only change ssthresh |
| Boundary values | 3 | `ssthresh = 0`, `ssthresh = usize::MAX`, identical calls |
| Large sequences | 4 | Up to 12 updates; first exit preserved throughout |

## Lean file correspondence

| Lean definition | Rust source | Correspondence |
|-----------------|-------------|----------------|
| `SsThreshState` | `SsThresh` struct | Exact (abstracts `StartupExit` to `ExitReason`) |
| `SsThreshState.default` | `Default::default()` | Exact |
| `SsThreshState.update` | `SsThresh::update()` | Exact |
| `SsThreshState.updateList` | Sequence of `update()` calls | Exact |
| `ExitReason` | `StartupExitReason` | Exact (same two variants) |
| `USIZE_MAX` | `usize::MAX` | Exact (modelled as `2^64 - 1`) |

**Abstraction**: `StartupExit` (which contains `cwnd`, `bandwidth`, and `reason`) is
abstracted to just `ExitReason`. The Lean proofs concern only the write-once property
of `startup_exit` and the ssthresh update semantics, neither of which depends on
`cwnd` or `bandwidth`.

## Last run

Run 170 (workflow 26014249801), 25/25 PASS.
