# Informal Specification: BBR2 Pacing Rate Bounds (T32)

🔬 *Lean Squad — automated formal verification for `dsyme/quiche`.*

**Target**: `quiche/src/recovery/gcongestion/bbr2.rs` — `fn update_pacing_rate`,
             `fn initial_pacing_rate`, `fn pacing_rate`
**Status**: Phase 2 — Informal Spec (run 165)
**Formal spec target**: `formal-verification/lean/FVSquad/BBR2PacingRate.lean`

---

## Purpose

`update_pacing_rate` is called once per ACK inside the BBR2 congestion
controller.  It adjusts `self.pacing_rate` (the rate at which the sender
releases packets into the network) based on the current bandwidth estimate,
the current pacing gain factor, and which phase of BBR2 we are in.

The critical invariant is: **in STARTUP, the pacing rate never decreases**.
This guarantees BBR2 ramps up aggressively when probing for available
bandwidth.

A secondary property is: **pacing_rate is always ≥ target_rate** in STARTUP
(under normal bw_lo_mode), because the update uses `max(current, target)`.

---

## Preconditions

1. `bandwidth_estimate > 0` (if it is zero the function returns early, leaving
   `pacing_rate` unchanged).
2. `pacing_gain > 0` (always true: STARTUP uses 2.885, PROBE_BW uses values
   around 1.0–1.25).
3. `self.pacing_rate` holds the value from the previous ACK event (or the
   initial value after `on_init`).

---

## Postconditions

### Case A — zero bandwidth estimate

```
bandwidth_estimate = 0  →  pacing_rate_after = pacing_rate_before
```

No change; the function returns immediately.

### Case B — first ACK (total_bytes_acked = bytes_acked)

```
pacing_rate_after = min(cwnd / min_rtt, initial_pacing_rate_cap)
```

Where `initial_pacing_rate_cap` is:
- `initial_pacing_rate_bytes_per_second` if configured, or
- `+∞` (no cap) otherwise.

In integer terms (Bandwidth is a `u64` of bits-per-second):
```
pacing_rate_after = min(
    Bandwidth::from_bytes_and_time_delta(cwnd, min_rtt),
    params.initial_pacing_rate_bytes_per_second.map_or(+∞, bps)
)
```

### Case C — full_bandwidth_reached = true (DRAIN or PROBE_BW)

```
pacing_rate_after = target_rate
            where target_rate = bandwidth_estimate * pacing_gain
```

The rate is set exactly to the scaled bandwidth estimate; no monotonicity
constraint is applied (the rate may decrease from STARTUP).

### Case D — STARTUP with early exit conditions

When either:
- `decrease_startup_pacing_at_end_of_round = true` AND
  `pacing_gain < startup_pacing_gain` (end-of-round partial reduction), or
- `bw_lo_mode ≠ Default` AND `loss_events_in_round > 0` (aggressive loss
  response),

the function also sets `pacing_rate = target_rate` (rate may decrease).

### Case E — normal STARTUP (default path)

```
pacing_rate_after = max(pacing_rate_before, target_rate)
```

**Key property**: `pacing_rate_after ≥ pacing_rate_before` — monotone increase.
Also: `pacing_rate_after ≥ target_rate`.

---

## Invariants

1. **STARTUP monotonicity** (Case E): `update_pacing_rate` never reduces the
   pacing rate on the default STARTUP path.  Formally:
   ```
   (bw_lo_mode = Default) → (¬decrease_early) → (¬full_bw_reached) →
       pacing_rate_after ≥ pacing_rate_before
   ```

2. **At-least-target** (Case E): the updated rate is always at least the
   target rate:
   ```
   pacing_rate_after ≥ target_rate
   ```

3. **Target-rate non-negativity**: `bandwidth_estimate * pacing_gain ≥ 0`
   (trivially true for non-negative inputs).

4. **Monotonicity in bandwidth**: if `bandwidth_estimate` increases while
   `pacing_gain` is held fixed, `target_rate` increases, so
   `pacing_rate_after` is non-decreasing (Case E path).

---

## Edge Cases

- **`bandwidth_estimate = 0`**: early return, pacing_rate unchanged.
- **First ACK** (total_bytes_acked = bytes_acked): special path using
  `cwnd / min_rtt` as the initial estimate; may be capped by
  `initial_pacing_rate_bytes_per_second`.
- **Configured `initial_pacing_rate`**: the initial pacing rate is capped at
  the configured value (to avoid over-shooting at startup on known-bandwidth
  links).

---

## Examples

| Scenario | bw_estimate | pacing_gain | pacing_rate_before | pacing_rate_after |
|----------|-------------|-------------|--------------------|-------------------|
| Normal STARTUP | 10 Mbps | 2.885 | 8 Mbps | 28.85 Mbps |
| STARTUP rate already high | 10 Mbps | 2.885 | 50 Mbps | 50 Mbps (max) |
| Full BW reached | 10 Mbps | 1.0 | 50 Mbps | 10 Mbps (set) |
| Zero BW | 0 | any | 30 Mbps | 30 Mbps (no-op) |

---

## Inferred Intent

The `max(current, target)` pattern on the default STARTUP path is the core
BBRv2 invariant that ensures aggressive bandwidth probing: the sender never
slows down while still exploring available bandwidth.  The Cases C and D
intentionally allow rate reductions when bandwidth has been reliably measured
(full_bandwidth_reached) or when loss signals indicate the current rate is
too high.

---

## Open Questions

- **OQ-T32-1**: `Bandwidth` uses a `u64` representation of bits-per-second
  (see `bandwidth.rs`). Can `bandwidth_estimate * pacing_gain` overflow a
  `u64`?  The Lean model should note this potential.
- **OQ-T32-2**: In Case B (first ACK), `min_rtt` could theoretically be
  `Duration::ZERO` (if no RTT sample yet).  How does
  `Bandwidth::from_bytes_and_time_delta` handle a zero duration?
- **OQ-T32-3**: The `pacing_rate` field is read by `fn pacing_rate()` which
  may apply a further MSS-based scaling
  (`pacing_rate * new_mss / old_mss` in `update_mss`).  The formal model
  should clarify which stage of pacing rate applies.

---

## Approach Notes

For the Lean 4 model:
- Model `Bandwidth` as `Nat` (bits-per-second, unbounded integer).
- Model `pacing_gain` as a rational `gainNum / gainDen` (e.g., 2885/1000 for
  STARTUP gain ≈ 2.885).
- `target_rate = bw * gainNum / gainDen` using integer arithmetic.
- The key theorems are all `omega`-closeable:
  - `startup_monotone`: `max a b ≥ a` (trivial)
  - `target_ge_zero`: `0 ≤ target_rate`
  - `startup_ge_target`: `max prev target ≥ target`
  - `case_c_sets_target`: `pacing_rate_after = target_rate` when full_bw_reached
- Estimated Lean file size: ~60–80 lines, all tactics `omega` / `simp`.
