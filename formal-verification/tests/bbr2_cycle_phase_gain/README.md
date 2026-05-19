# BBR2CyclePhaseGain Route-B Correspondence Tests

🔬 *Lean Squad — Route-B correspondence validation for T73 (BBR2CyclePhaseGain).*

## What is being tested

The Lean model `FVSquad.BBR2CyclePhaseGain` in
`formal-verification/lean/FVSquad/BBR2CyclePhaseGain.lean` formally
verifies properties of the BBR2 ProbeBW cycle-phase gain dispatch in
`quiche/src/recovery/gcongestion/bbr2/mode.rs`.

The Lean model represents f32 gain values as exact rational fractions
(`Gain = { num: Nat, den: Nat }`) and proves:
- `Up` pacing gain = 5/4 (1.25) — super-unity
- `Down` pacing gain = 9/10 (0.90) — sub-unity
- All other phases: pacing gain = 1/1 (1.00) — unity
- `Up` cwnd gain = 9/4 (2.25) — elevated
- All other phases: cwnd gain = 2/1 (2.00) — default
- Ordering: `Up > default > Down` for pacing
- Ordering: `Up > default` for cwnd

## How to run

```bash
cd formal-verification/tests/bbr2_cycle_phase_gain
rustc --edition 2021 cycle_phase_gain_test.rs && ./cycle_phase_gain_test
```

No dependencies beyond a standard Rust toolchain.

## Test cases (25 total, all PASS)

| Group | Cases | What is tested |
|-------|-------|----------------|
| Default-params correspondence | 10 | Each phase × {pacing, cwnd} matches Lean fraction |
| Dispatch with custom params | 10 | NotStarted/Cruise/Refill→default, Up/Down dispatch |
| Ordering invariants | 5 | up>default>down pacing; up>default cwnd; super/sub/unity |

## Correspondence status

| Lean definition | Rust function | Correspondence |
|-----------------|--------------|----------------|
| `pacingGain` | `CyclePhase::pacing_gain` | Exact (f32 ≡ num/den) |
| `cwndGain` | `CyclePhase::cwnd_gain` | Exact (f32 ≡ num/den) |
| `defaultParams` | `DEFAULT_PARAMS` in bbr2.rs | Exact value correspondence |

## Lean file

`formal-verification/lean/FVSquad/BBR2CyclePhaseGain.lean` — T73, 23 theorems, 0 sorry.

## Run: 2026-05-19, commit 3c3f69b3

Result: 25/25 PASS
