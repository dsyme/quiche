# HyStart++ Invariants — Informal Specification

**Source**: `quiche/src/recovery/congestion/hystart.rs`  
**RFC**: [draft-ietf-tcpm-hystartplusplus-04](https://datatracker.ietf.org/doc/html/draft-ietf-tcpm-hystartplusplus-04)

---

## Purpose

HyStart++ is a slow-start algorithm that avoids excessive overshoot in TCP/QUIC congestion windows. It transitions from Slow Start (SS) to Conservative Slow Start (CSS) when it detects increasing RTTs, then to Congestion Avoidance (CA) after `CSS_ROUNDS` rounds in CSS.

The key operations with formally verifiable properties are:

1. **`rtt_thresh` clamping**: the RTT threshold used to detect increasing RTTs is clamped to `[MIN_RTT_THRESH, MAX_RTT_THRESH]`
2. **`css_cwnd_inc` divisor**: the cwnd increment during CSS is exactly `pkt_size / CSS_GROWTH_DIVISOR`
3. **`css_round_count` monotonicity**: once in CSS, `css_round_count` increases until it reaches `CSS_ROUNDS`

---

## Constants

| Constant | Value | Meaning |
|----------|-------|---------|
| `MIN_RTT_THRESH` | 4 ms | Minimum RTT threshold for SS→CSS transition |
| `MAX_RTT_THRESH` | 16 ms | Maximum RTT threshold |
| `N_RTT_SAMPLE` | 8 | Samples needed before checking threshold |
| `CSS_GROWTH_DIVISOR` | 4 | Divisor for cwnd increment in CSS |
| `CSS_ROUNDS` | 5 | CSS rounds before exiting to CA |

---

## Preconditions

- `MIN_RTT_THRESH ≤ MAX_RTT_THRESH` (4 ms ≤ 16 ms) — always true by construction.
- `CSS_GROWTH_DIVISOR > 0` — always true (= 4).
- For `rtt_thresh` computation: `last_round_min_rtt` is a valid `Duration` (not `Duration::MAX`).

---

## Postconditions

### `rtt_thresh` clamping

Given `last_round_min_rtt` in `(0, Duration::MAX)`:

```
rtt_thresh = clamp(last_round_min_rtt / 8, MIN_RTT_THRESH, MAX_RTT_THRESH)
```

**Key properties**:
1. `MIN_RTT_THRESH ≤ rtt_thresh` — always.
2. `rtt_thresh ≤ MAX_RTT_THRESH` — always.
3. If `last_round_min_rtt / 8 < MIN_RTT_THRESH`, then `rtt_thresh = MIN_RTT_THRESH`.
4. If `last_round_min_rtt / 8 > MAX_RTT_THRESH`, then `rtt_thresh = MAX_RTT_THRESH`.
5. Otherwise, `rtt_thresh = last_round_min_rtt / 8`.

The clamp is computed as `max(last/8, MIN) |> min(MAX_RTT_THRESH)`.

### `css_cwnd_inc` divisor invariant

```
css_cwnd_inc(pkt_size) = pkt_size / CSS_GROWTH_DIVISOR
```

**Key properties**:
1. `css_cwnd_inc(pkt_size) ≤ pkt_size` — the increment is at most the packet size.
2. `css_cwnd_inc(0) = 0` — zero packet size yields zero increment.
3. `css_cwnd_inc(pkt_size) * CSS_GROWTH_DIVISOR ≤ pkt_size * 1 ≤ pkt_size * CSS_GROWTH_DIVISOR` — monotone.
4. `css_cwnd_inc` is monotone: `a ≤ b → css_cwnd_inc(a) ≤ css_cwnd_inc(b)`.

### `css_round_count` exit condition

After entering CSS:
- `css_round_count` starts at 0.
- Increments by 1 at the end of each CSS round.
- When `css_round_count ≥ CSS_ROUNDS`, the function returns `true` (exit to CA) and resets `css_round_count` to 0.

**Key properties**:
- `css_round_count < CSS_ROUNDS` at all times while still in CSS (before exit).
- Exit to CA happens exactly when `css_round_count` reaches `CSS_ROUNDS`.

---

## Invariants

1. **Threshold bounds invariant**: `MIN_RTT_THRESH ≤ rtt_thresh_computed ≤ MAX_RTT_THRESH`.
2. **CSS cwnd growth is conservative**: `css_cwnd_inc(pkt) ≤ pkt / 4` (growth ≤ 25% of pkt).
3. **CSS round counter bounded**: `css_round_count ≤ CSS_ROUNDS` at all times.
4. **Monotone in CSS**: within a CSS period, `css_round_count` is non-decreasing until reset.

---

## Edge Cases

- `last_round_min_rtt = Duration::ZERO`: `rtt_thresh = max(0, MIN_RTT_THRESH) = MIN_RTT_THRESH`. ✓
- `last_round_min_rtt = Duration::MAX`: excluded by the guard `!= Duration::MAX` before the threshold computation. ✓
- `pkt_size = 0`: `css_cwnd_inc(0) = 0`. ✓
- `pkt_size < CSS_GROWTH_DIVISOR`: `css_cwnd_inc` returns 0 (integer division floors). This is intentional.
- `css_round_count = CSS_ROUNDS - 1` at start of round: the next acknowledgment at round end returns `true` and resets counter.

---

## Examples

| `last_round_min_rtt` | `last/8` | `rtt_thresh` |
|---------------------|----------|--------------|
| 8 ms | 1 ms | 4 ms (= MIN) |
| 32 ms | 4 ms | 4 ms (= MIN) |
| 64 ms | 8 ms | 8 ms |
| 256 ms | 32 ms | 16 ms (= MAX) |

| `pkt_size` | `css_cwnd_inc` |
|-----------|---------------|
| 0 | 0 |
| 1 | 0 |
| 4 | 1 |
| 1200 | 300 |
| 1500 | 375 |

---

## Inferred Intent

The `rtt_thresh` clamp ensures the algorithm is neither too sensitive (threshold < 4 ms) nor too conservative (threshold > 16 ms), matching the RFC §4.2 requirement. The CSS cwnd increment is deliberately slow (1/4 of normal) to probe for bandwidth without overshoot.

---

## Open Questions

1. Should the formal model include the `N_RTT_SAMPLE` counting or only the pure arithmetic properties (clamp and divisor)?
2. Is the `Duration::MAX` sentinel value used safely everywhere? A formal model should treat it as ∞ or avoid it.
3. The `rtt_thresh` uses `last_round_min_rtt / 8` with integer duration arithmetic — is this division rounded toward zero or toward nearest? (Rust Duration division rounds toward zero.)
