# Informal Specification — CUBIC Congestion Control

> 🔬 *Written by Lean Squad automated formal verification (run 41).*

**Source**: `quiche/src/recovery/congestion/cubic.rs`  
**Reference**: [draft-ietf-tcpm-rfc8312bis-02](https://tools.ietf.org/html/draft-ietf-tcpm-rfc8312bis-02)

---

## Purpose

CUBIC is a TCP-compatible congestion control algorithm that uses a cubic
function of time to determine the congestion window size. Its key properties
are:

1. **Window reduction on loss**: on a detected loss event, reduce the
   congestion window to `BETA_CUBIC × cwnd` (≈ 70% of current window).
2. **Cubic growth**: after reduction, grow the window according to
   `W_cubic(t) = C × (t − K)³ + w_max`, where `t` is the elapsed time since
   the last reduction, `K` is the time when the window will recover to
   `w_max`, and `w_max` is the window at the time of the reduction.
3. **TCP-friendliness (AIMD mode)**: if CUBIC's cubic function is growing
   slower than Reno-TCP would, CUBIC mimics Reno growth instead
   (`w_est` tracking at rate `ALPHA_AIMD`).
4. **Fast convergence**: if `cwnd < w_max` at loss time (window never
   recovered to prior peak), reduce `w_max` to `cwnd × (1 + BETA) / 2`
   to speed up convergence in multi-flow scenarios.

---

## Constants

| Constant | Value | Purpose |
|----------|-------|---------|
| `BETA_CUBIC` | 0.7 | Multiplicative decrease factor on loss |
| `C` | 0.4 | CUBIC scaling constant (RFC 8312bis §5) |
| `ALPHA_AIMD` | ≈ 0.5294 = 9/17 | TCP-friendliness AIMD increment |

`ALPHA_AIMD = 3 × (1 − β) / (1 + β) = 3 × 0.3 / 1.7 = 0.9 / 1.7 = 9/17`

---

## Preconditions

- `congestion_window > 0` (always maintained by minimum window guard)
- A fresh loss event has occurred (packet sent after current recovery start)
- `max_datagram_size > 0` (MSS, used as a scaling factor)

---

## Postconditions

After `congestion_event`:

1. `ssthresh = max(floor(cwnd × BETA_CUBIC), mss × MINIMUM_WINDOW_PACKETS)`
2. `cwnd = ssthresh` (window immediately reduced)
3. `w_max = cwnd_before_event` (or reduced by fast convergence)
4. `K = cubic_root((w_max − cwnd) / C)` (time to recover to w_max)
5. `w_est = cwnd` (AIMD estimator reset to current window)
6. `alpha_aimd = ALPHA_AIMD` (estimator rate reset)

### Invariants

- `ssthresh ≤ cwnd_before` at all times (window cannot increase on loss)
- `ssthresh > 0` (protected by `max(…, mss × 2)` clamp)
- After `K` units of time: `W_cubic(K) = w_max` (full recovery at K)
- At epoch start (t=0): `W_cubic(0) = cwnd` (starts from reduced window)
- For t ≥ K: `W_cubic(t) ≥ w_max` and increasing (probes beyond prior peak)

---

## Key Equations

### K (cubic root, Eq. 2)

```
K = cbrt((w_max − cwnd) / C)
```

Implies: `C × K³ = w_max − cwnd`, so `W_cubic(0) = −C × K³ + w_max = cwnd`.

### W_cubic(t) (Eq. 1)

```
W_cubic(t) = C × (t − K)³ + w_max
```

- At `t = K`: `W_cubic(K) = w_max` (target)
- For `t > K`: growing (slope ≥ 0 when t ≥ K since `(t−K)² ≥ 0`)
- Monotone non-decreasing for `t ≥ K`

### w_est (AIMD friendliness, Eq. 4)

```
w_est += ALPHA_AIMD × (acked / cwnd)
```

### Fast convergence (§5.4 of draft)

```
if cwnd < w_max:
    w_max_new = cwnd × (1 + BETA_CUBIC) / 2
else:
    w_max_new = cwnd
```

Since `(1 + 0.7)/2 = 0.85 < 1`, fast convergence strictly reduces `w_max`.

---

## Edge Cases

1. **cwnd ≥ w_max**: `K = 0` (no recovery needed; window already at or beyond
   prior peak). The cubic starts at w_max immediately.
2. **Minimum window**: `ssthresh` is clamped at `mss × 2 = 2920` bytes
   (for 1460-byte MSS). Even at this floor, `ssthresh < cwnd` whenever
   `cwnd > mss × 2`.
3. **In recovery**: `congestion_event` is a no-op if the lost packet was sent
   before the current recovery start (prevents cascading reductions on a burst
   of losses from one event).
4. **Spurious recovery rollback**: if very few packets were lost (< 20% of cwnd),
   the prior state is restored (rollback mechanism).

---

## Examples

```
cwnd = 10000 bytes, mss = 1448 bytes:
  ssthresh = floor(10000 × 0.7) = 7000
  wMaxFastConv = floor(10000 × 1.7 / 2) = floor(8500) = 8500

cwnd = 1448 bytes (1 MSS):
  ssthresh = floor(1448 × 0.7) = floor(1013.6) = 1013
  (but clamped to max(1013, 1448×2=2896) → ssthresh = 2896)
  wMaxFastConv = floor(1448 × 1.7 / 2) = floor(1230.8) = 1230
```

---

## Open Questions

1. **Rounding mode**: the Rust code uses `as usize` (truncate toward zero) after
   an `f64` multiplication. For positive values this is equivalent to floor.
   Is this equivalence formally verified anywhere in the quiche test suite?

2. **CUBIC vs Reno transition**: when exactly does the CUBIC controller switch
   from using `W_cubic(t)` to using `w_est`? The condition is
   `w_cubic(t) < w_est`, but the exact semantics of the update ordering are
   subtle.

3. **Idle period adjustment**: `on_packet_sent` shifts the epoch start forward
   when `bytes_in_flight == 0`. This affects `K` computation and is not
   captured by the current Lean model.

4. **K reuse across congestion events**: is `K` always recomputed from scratch
   on each `congestion_event`, or can prior state leak? From the code it is
   always recomputed.
