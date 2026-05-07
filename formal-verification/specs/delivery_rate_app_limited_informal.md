# Informal Specification: App-Limited Guard State Machine (`delivery_rate.rs`)

**Target**: T52 — `Rate::update_app_limited`, `Rate::app_limited`,
`Rate::generate_rate_sample` (bubble-check exit), `Rate::generate_rate_sample`
(rate-sample update guard)

**Source**: `quiche/src/recovery/congestion/delivery_rate.rs`

**RFC reference**: draft-cheng-iccrg-delivery-rate-estimation-01 §4.3

---

## Purpose

The *app-limited guard* controls whether the delivery-rate tracker considers
the current send interval to be limited by the application (i.e., the sender
ran out of data to send rather than hitting a network bottleneck).

When the sender is app-limited, the measured delivery rate may be artificially
low (because the sender was not trying to fill the pipe). If such a sample were
used to update the congestion window, it could cause unnecessary cwnd reduction.

The guard implements three behaviours:
1. **Enter app-limited mode**: mark the packet number up to which the current
   "app-limited bubble" extends.
2. **Exit app-limited mode automatically**: when the last packet in the bubble
   has been acknowledged, the bubble is gone and the guard clears itself.
3. **Conditional sample acceptance**: when in app-limited mode, only update the
   stored delivery-rate bandwidth if the new sample exceeds the previous value.

---

## Preconditions

- `last_sent_packet`: the packet number assigned to the most recently sent
  packet (monotonically increasing per connection, starting at 0).
- `largest_acked`: the highest packet number that has been acknowledged.
- `end_of_app_limited`: 0 means "not app-limited"; > 0 means "app-limited up
  through this packet number".

---

## Core Operations

### `update_app_limited(v: bool)`

```
if v:
    end_of_app_limited = max(last_sent_packet, 1)
else:
    end_of_app_limited = 0
```

**Intent**: entering app-limited mode records the current "high-water mark" of
sent packets. Any ACK for a packet beyond this mark means the app-limited
period is over. The `max(_, 1)` guard ensures `end_of_app_limited` is never
set to 0 when `last_sent_packet = 0`, which would be indistinguishable from
"not app-limited".

### `app_limited() → bool`

```
return end_of_app_limited != 0
```

**Intent**: the flag is purely derived from whether `end_of_app_limited` is
non-zero.

### Bubble-check in `generate_rate_sample`

```
if app_limited() && largest_acked > end_of_app_limited:
    update_app_limited(false)
```

**Intent**: the app-limited "bubble" is the batch of packets sent while the
sender was app-limited. Once the highest such packet has been acknowledged,
the sender has caught up — any future samples reflect normal network-limited
conditions. The guard automatically exits at this point.

### Rate-sample update guard in `generate_rate_sample`

```
if !rate_sample.is_app_limited || new_bandwidth > old_bandwidth:
    update rate_sample.bandwidth = new_bandwidth
```

**Intent**: app-limited samples (where `is_app_limited` was set at send time)
are accepted only if they show a higher rate than the current estimate. This
prevents artificially low rates from reducing the congestion window.

---

## Postconditions

| Operation | Postcondition |
|-----------|---------------|
| `update_app_limited(true)` | `app_limited() = true`, `end_of_app_limited ≥ 1` |
| `update_app_limited(false)` | `app_limited() = false`, `end_of_app_limited = 0` |
| Bubble-check, bubble gone | `app_limited() = false` |
| Bubble-check, bubble not gone | state unchanged |
| Rate guard, `!is_app_limited` | rate always updated |
| Rate guard, `is_app_limited && new > old` | rate updated |
| Rate guard, `is_app_limited && new ≤ old` | rate NOT updated |

---

## Invariants

1. `app_limited() = true ↔ end_of_app_limited ≠ 0` (representation invariant)
2. When `app_limited()`, `end_of_app_limited ≥ 1` (no false-negative from 0)
3. After `update_app_limited(false)`, `app_limited() = false` unconditionally
4. After `update_app_limited(true)`, `app_limited() = true` unconditionally

---

## Edge Cases

- `last_sent_packet = 0`: `max(0, 1) = 1`, so `end_of_app_limited = 1`. The
  flag is correctly set even with no prior sent packets.
- `largest_acked = end_of_app_limited`: the condition is `>`, not `≥`, so the
  bubble is still "live" — exit only occurs strictly after the bubble boundary.
- Double `update_app_limited(true)`: idempotent in the flag; `end_of_app_limited`
  is updated to the new `last_sent_packet` (which may differ from the first call).
- `update_app_limited(false)` when already not app-limited: no-op.

---

## Examples

| last_sent | largest_acked | end_of_app_limited (before) | After update(true) | After bubble-check |
|-----------|--------------|----------------------------|-------------------|-------------------|
| 5 | 0 | 0 | 5, app_limited=true | (no change) |
| 0 | 0 | 0 | 1, app_limited=true | (largest_acked=0 ≤ 1, no exit) |
| 5 | 6 | 5 | — | app_limited=false (6 > 5) |
| 5 | 5 | 5 | — | app_limited=true (5 ≯ 5) |

---

## Open Questions

None — the logic is fully specified by the source code and RFC draft §4.3.
The model closely mirrors the Rust implementation.
