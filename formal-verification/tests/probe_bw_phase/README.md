# Route-B Test: T57 — BBR2 ProbeBW Phase Gains

🔬 Lean Squad correspondence test for `FVSquad/ProbeBWPhase.lean`.

## What is tested

The Lean model defines `pacingGain` and `cwndGain` functions that map each
`CyclePhase` variant to an integer gain value (multiplied by 100 to avoid
floating-point). This test verifies those values match the default `Params`
constants in the quiche BBR2 implementation.

| Phase      | pacingGain (×100) | cwndGain (×100) |
|------------|:-----------------:|:---------------:|
| NotStarted | 100               | 200             |
| Up         | 125               | 225             |
| Down       | 90                | 200             |
| Cruise     | 100               | 200             |
| Refill     | 100               | 200             |

Source constants from `quiche/src/recovery/gcongestion/bbr2.rs` (L291–L300):
- `probe_bw_probe_up_pacing_gain = 1.25` → 125
- `probe_bw_probe_down_pacing_gain = 0.90` → 90
- `probe_bw_default_pacing_gain = 1.00` → 100
- `probe_bw_up_cwnd_gain = 2.25` → 225
- `probe_bw_cwnd_gain = 2.00` → 200

## Running the test

```bash
rustc probe_bw_phase_test.rs -o /tmp/probe_bw_phase_test
/tmp/probe_bw_phase_test
```

Expected output: 10 × `PASS` lines followed by `=== All 10 checks PASS ===`.
