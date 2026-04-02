# Informal Specification — RTT Estimator

🔬 *Lean Squad — informal specification for `quiche/src/recovery/rtt.rs`.*

## Purpose

`RttStats` tracks the round-trip time (RTT) of a QUIC connection.  It maintains
four estimates used by the congestion controller and loss detector:

| Field | Meaning |
|-------|---------|
| `latest_rtt` | Most recently measured RTT sample |
| `smoothed_rtt` | EWMA estimate: weighted moving average of RTT (⅞ weight on history) |
| `rttvar` | RTT variance estimate: EWMA of \|smoothed − adjusted\| |
| `min_rtt` | Window-minimum over the last 300 s (ignores ack delay) |
| `max_rtt` | All-time maximum |

The algorithm follows RFC 9002 §5.

---

## Preconditions

- `initial_rtt > 0` — the constructor requires a positive initial estimate (RFC 9002 mandates a fallback of ~333 ms if no measurement is available).
- `latest_rtt > 0` — all RTT samples are strictly positive durations.
- `ack_delay ≥ 0` — ack delay is non-negative.
- `max_ack_delay ≥ 0` — configured maximum ack delay is non-negative.
- Time (`Instant`) moves forward monotonically between calls.

---

## Postconditions of `new`

After `RttStats::new(initial_rtt, max_ack_delay)`:

1. `smoothed_rtt = initial_rtt`
2. `rttvar = initial_rtt / 2` (integer division)
3. `min_rtt = initial_rtt` (seeded with initial estimate)
4. `max_rtt = initial_rtt`
5. `has_first_rtt_sample = false`
6. `latest_rtt = 0`

---

## Postconditions of `update_rtt` — first call (has_first_rtt_sample = false)

After the first call to `update_rtt(latest_rtt, ack_delay, now, hc)`:

1. `smoothed_rtt = latest_rtt`
2. `rttvar = latest_rtt / 2`
3. `min_rtt = latest_rtt`
4. `max_rtt = latest_rtt`
5. `self.latest_rtt = latest_rtt`
6. `has_first_rtt_sample = true`
7. `ack_delay` is **ignored** on the first sample.

---

## Postconditions of `update_rtt` — subsequent calls

Let `prev` denote the state before the call.

### min_rtt

```
new.min_rtt = running_min(prev.min_rtt, latest_rtt)
            ≤ prev.min_rtt
            ≤ latest_rtt  (since prev.min_rtt was seeded from prior samples)
```

**Note**: `min_rtt` only decreases; it never increases.  It is a window
minimum over the last `RTT_WINDOW = 300 s`, so very old minima may be
discarded.  In the Lean model we abstract this as a monotone-non-increasing
value that always satisfies `min_rtt ≤ latest_rtt`.

### max_rtt

```
new.max_rtt = max(prev.max_rtt, latest_rtt) ≥ prev.max_rtt
```

`max_rtt` only increases.

### ack_delay adjustment

```
if handshake_confirmed:
    ack_delay' = min(ack_delay, max_ack_delay)
else:
    ack_delay' = ack_delay
```

### adjusted_rtt (plausibility filter)

```
adjusted_rtt =
    if latest_rtt ≥ min_rtt + ack_delay':
        latest_rtt − ack_delay'     -- ack delay is plausible; remove it
    else:
        latest_rtt                  -- ack delay suspiciously large; ignore it
```

**Key invariant**: `adjusted_rtt ≥ min_rtt`.

*Proof sketch*: in both branches,
- Branch 1: `latest_rtt ≥ min_rtt + ack_delay' ⟹ latest_rtt − ack_delay' ≥ min_rtt` (by arithmetic).
- Branch 2: `latest_rtt` (unchanged) satisfies `latest_rtt ≥ min_rtt` because `min_rtt` is the minimum of all seen samples.

### smoothed_rtt (EWMA, weight 7/8)

```
new.smoothed_rtt = prev.smoothed_rtt * 7/8 + adjusted_rtt / 8
```

(integer arithmetic)

**Properties**:
- If `prev.smoothed_rtt > 0` and `adjusted_rtt > 0` (i.e., `latest_rtt > 0`), then `new.smoothed_rtt > 0`.
- `smoothed_rtt` converges toward the true RTT as samples accumulate.

### rttvar (EWMA of deviation, weight 3/4)

```
new.rttvar = prev.rttvar * 3/4 + |prev.smoothed_rtt − adjusted_rtt| / 4
```

(integer arithmetic; `|·|` is absolute difference)

**Properties**:
- `rttvar ≥ 0` always (since it is a Nat/Duration).
- If `prev.rttvar = 0` and `prev.smoothed_rtt ≠ adjusted_rtt`, then `new.rttvar > 0`.

---

## Invariants (hold after every call)

| ID | Invariant | Significance |
|----|-----------|--------------|
| I1 | `smoothed_rtt > 0` (if `initial_rtt > 0` and all samples > 0) | QUIC requires positive RTT; used in loss timers |
| I2 | `rttvar ≥ 0` | Trivial for non-negative types |
| I3 | `min_rtt ≤ latest_rtt` (after first sample) | `min_rtt` is a true minimum; used in `adjusted_rtt` plausibility check |
| I4 | `max_rtt ≥ latest_rtt` (after every update) | `max_rtt` is a true maximum |
| I5 | `adjusted_rtt ≥ min_rtt` (within each `update_rtt` call) | Prevents negative EWMA inputs |
| I6 | `smoothed_rtt ≥ min_rtt / 2` (approximately) | Informal; hard to prove exactly due to integer division |

---

## Edge Cases

- **Zero initial_rtt**: The code does not explicitly guard against
  `initial_rtt = 0`, but RFC 9002 mandates a positive fallback.  With
  `initial_rtt = 0`, `rttvar = 0` immediately; the loss detector would
  behave incorrectly.  The Lean spec guards theorems with `initial_rtt > 0`.

- **latest_rtt = 0**: Would set `smoothed_rtt = 0` and `rttvar = 0` on the
  first sample.  RFC 9002 requires discarding zero-length RTT samples; this
  invariant is enforced at the caller, not in `RttStats`.

- **ack_delay > latest_rtt**: The plausibility check prevents
  `adjusted_rtt` from going negative — the subtraction only happens when
  `latest_rtt ≥ min_rtt + ack_delay`.

- **Integer arithmetic truncation**: All divisions are integer (floor).
  The EWMA never reaches exactly the current sample in finite time.

- **Overflow**: In the Rust code, `latest_rtt.as_nanos()` returns `u128`,
  and `abs_diff` returns `u128`.  Casting to `u64` could overflow for RTTs
  larger than ~584 years.  This edge case is not guarded and is not modelled
  in Lean (we use unbounded `Nat`).

---

## Examples

### Example 1: Initialisation

```
RttStats::new(100ms, 25ms)
→ smoothed_rtt = 100ms, rttvar = 50ms, min_rtt = 100ms, max_rtt = 100ms
```

### Example 2: First sample

```
update_rtt(120ms, 10ms, now, true)   -- first sample
→ smoothed_rtt = 120ms, rttvar = 60ms, min_rtt = 120ms, max_rtt = 120ms
   (ack_delay ignored on first sample)
```

### Example 3: Plausible ack delay

```
State: smoothed_rtt=120ms, min_rtt=100ms
update_rtt(130ms, 10ms, now, true)
ack_delay' = min(10ms, 25ms) = 10ms
latest_rtt(130) ≥ min_rtt(100) + ack_delay'(10) → adjusted_rtt = 120ms
rttvar = 60*3/4 + |120-120|/4 = 45ms
smoothed_rtt = 120*7/8 + 120/8 = 105 + 15 = 120ms
```

### Example 4: Implausible ack delay (suspiciously large)

```
State: smoothed_rtt=120ms, min_rtt=100ms
update_rtt(105ms, 20ms, now, true)
ack_delay' = min(20ms, 25ms) = 20ms
latest_rtt(105) < min_rtt(100) + ack_delay'(20) = 120 → adjusted_rtt = 105ms
(ack delay is not subtracted)
```

---

## Inferred Intent

- The plausibility check on `ack_delay` is a **security measure**: a malicious
  peer could claim a large ack delay to artificially inflate `adjusted_rtt`,
  causing the sender to overestimate the path RTT and become over-conservative.
  The `min_rtt`-based clamp limits this attack.

- The separate `min_rtt` (excluding ack delay) and `smoothed_rtt` (including
  the plausibility-filtered ack delay) serve different purposes: `min_rtt` is
  a lower bound on path propagation delay; `smoothed_rtt` is used for loss
  detection timers.

---

## Open Questions

1. **Is `max_rtt` safety-critical?** It is not used in loss detection (only
   `smoothed_rtt`, `rttvar`, and `min_rtt` are).  Is it diagnostic-only?
   The field has no accessor exported via the public API; only
   `max_rtt()` (returning `Option<Duration>`) is pub(crate).

2. **Windowed min_rtt vs. absolute min_rtt**: The Lean model simplifies
   `min_rtt` to a non-windowed minimum.  Is the windowing behaviour
   (discarding samples older than 300 s) ever observable in property proofs?

3. **u128 overflow in rttvar**: is the `as u64` cast in
   `abs_diff(adjusted_rtt.as_nanos()) as u64` guarded anywhere?  For
   production RTT values (< 10 s ≈ 10^10 ns), u64 suffices, but the
   code lacks an explicit assertion.
