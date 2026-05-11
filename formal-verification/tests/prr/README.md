# Route-B Correspondence Tests — PRR

🔬 *Lean Squad — automated formal verification for `dsyme/quiche`.*

## Target

**PRR: Proportional Rate Reduction (RFC 6937)**

- Source: `quiche/src/recovery/congestion/prr.rs`
- Lean model: `formal-verification/lean/FVSquad/PRR.lean`

## What is tested

The Rust `PRR` struct implements RFC 6937 Proportional Rate Reduction for
QUIC loss recovery. The three key operations are:

- `congestion_event(bytes_in_flight)` — resets all state at epoch start
- `on_packet_sent(sent_bytes)` — increases `prr_out`, decrements `snd_cnt`
- `on_packet_acked(delivered, pipe, ssthresh, mss)` — updates `prr_delivered`
  and recomputes `snd_cnt` via either PRR mode (`pipe > ssthresh`) or
  PRR-SSRB mode (`pipe ≤ ssthresh`)

The Lean model in `PRR.lean` defines these as pure functional operations on a
`PRR` structure with `Nat` fields. The `divCeil` helper is defined in Lean and
replicated in Rust as `div_ceil_lean`.

## How to run

```bash
rustc --edition 2021 prr_test.rs && ./prr_test
```

No external dependencies. Requires Rust 1.60+ for `div_ceil`.

## Test cases (25 total)

| Group | Cases | Coverage |
|-------|-------|---------|
| congestion_event reset | 3 | zero flight, nonzero flight, double CE |
| on_packet_sent | 3 | within snd_cnt, saturating, zero send |
| PRR mode (pipe > ssthresh) | 5 | basic, two acks, sent+ack, zero recoverfs, saturating |
| PRR-SSRB mode (pipe ≤ ssthresh) | 6 | basic, pipe=ssthresh, pipe=0, two acks, sent+ack, large MSS |
| RFC 6937 example sequence | 2 | round 1, round 2 |
| Edge cases | 6 | fresh state, zero ack, small values, gap capped, multiple CEs, large prr_out |

## Result (run 150)

```
PRR Route-B correspondence tests: 25/25 PASS
```

Lean model and Rust source agree on all 25 cases.

## What this does NOT cover

- Multi-epoch sequences with many consecutive CEs (state accumulated across 5+
  recovery periods)
- The `max(snd_cnt, 0)` final guard in the Rust (always a no-op for `usize`/`Nat`)
- Caller protocol: `on_packet_sent` invoked with `sent_bytes > snd_cnt` is legal
  in the Rust (saturating) and in the Lean model; the contract that
  `sent_bytes ≤ snd_cnt` is not enforced by either
