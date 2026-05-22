# Informal Specification: BBR2 `has_bandwidth_growth`

**Target**: T80  
**Source**: `quiche/src/recovery/gcongestion/bbr2/network_model.rs` `has_bandwidth_growth` (L630–662) and `check_persistent_queue` (L669–686)  
**Phase**: 2 — Informal Specification  
**RFC Reference**: RFC 9002 §A, [BBR2 draft](https://datatracker.ietf.org/doc/draft-cardwell-iccrg-bbr-congestion-control/)

---

## Purpose

`has_bandwidth_growth` determines whether the BBR2 Startup phase has observed
meaningful bandwidth growth in the most recent round trip. The return value is
used to decide whether to exit Startup or remain in it.

Startup exits when bandwidth stops growing — detected either by:
1. The bandwidth failing to grow above `baseline × full_bw_threshold` for
   `startup_full_bw_rounds` consecutive non-app-limited rounds
   (`has_bandwidth_growth` counter path), OR
2. Persistent queueing observed over `max_startup_queue_rounds` rounds
   (`check_persistent_queue` path).

---

## Inputs

| Name | Type | Description |
|------|------|-------------|
| `max_bandwidth` | bandwidth | Maximum bandwidth sample from the windowed filter |
| `full_bandwidth_baseline` | bandwidth | Highest bandwidth seen at start of a growth round |
| `rounds_without_bandwidth_growth` | u64 | Counter of consecutive non-growth rounds (mutable) |
| `full_bw_threshold` | f32 (≥ 1.0) | Growth threshold ratio (default 1.25 × 0.9 = ~1.08...) |
| `startup_full_bw_rounds` | u64 | Rounds without growth to declare saturation (default 3) |
| `ignore_app_limited_for_no_bandwidth_growth` | bool | If true, skip app-limited rounds |
| `is_valid` (from event) | bool | Whether the congestion event has send-state info |
| `is_app_limited` (from event) | bool | Whether the last packet was app-limited |

---

## Postconditions

### Return value

- Returns **`true`** iff `max_bandwidth ≥ full_bandwidth_baseline × full_bw_threshold`.
  - Side-effect: resets `rounds_without_bandwidth_growth` to 0.
  - Side-effect: updates `full_bandwidth_baseline := max_bandwidth`.
- Returns **`false`** in all other cases.

### Counter update (only when returning false)

- If `is_valid = false`: counter is **not** incremented (early return false).
- If `is_valid = true` and `ignore_round = false`: counter is incremented by 1.
  - `ignore_round = ignore_app_limited_for_no_bandwidth_growth AND is_app_limited`.
- If `is_valid = true` and `ignore_round = true`: counter is **not** incremented.

### `full_bandwidth_reached` flag

Set to `true` (irrevocably) when **all** of:
1. `rounds_without_bandwidth_growth ≥ startup_full_bw_rounds` (after the update above), AND
2. `is_app_limited = false`.

Once `full_bandwidth_reached = true`, it is never reset (it is a monotone flag).

---

## Invariants

1. **Monotone baseline**: `full_bandwidth_baseline` only increases — it is updated to
   `max_bandwidth` only when `max_bandwidth ≥ baseline × threshold`.
2. **Counter monotonicity**: `rounds_without_bandwidth_growth` is reset to 0 on
   growth, otherwise either held or incremented. It never decreases except via reset.
3. **Monotone `full_bandwidth_reached`**: once `true`, remains `true` forever.
4. **App-limited guard**: `full_bandwidth_reached` is never set to `true` while
   `is_app_limited = true` via this path (app-limited rounds do not count).

---

## Edge Cases

- `max_bandwidth = 0`: threshold `0 × threshold = 0`, so `max_bandwidth ≥ 0` always
  true → function returns true (growth observed). This is a degenerate case where the
  model may not correctly signal growth; in practice the bandwidth filter won't be 0.
- `full_bw_threshold = 1.0`: any non-decreasing bandwidth counts as growth.
- `startup_full_bw_rounds = 0`: impossible in practice (checked at config time);
  if it were 0, then `rounds_without_bw_growth ≥ 0` is always true and Startup
  would exit after one round without growth (even when ignoring app-limited rounds).
- Repeated app-limited rounds: the counter does not advance; `full_bandwidth_reached`
  is never set through this path alone.

---

## Examples

| Scenario | `max_bw ≥ baseline × thr` | `is_valid` | `is_app_limited` | Return | Counter after | `fbr` |
|----------|--------------------------|------------|-----------------|--------|---------------|-------|
| Growth detected | true | — | — | true | 0 (reset) | unchanged |
| No growth, valid, not app-limited | false | true | false | false | counter+1 | set if counter+1 ≥ rounds |
| No growth, valid, app-limited | false | true | true | false | counter+0 (ignored) | not set |
| No growth, invalid | false | false | — | false | counter+0 | not set |
| Counter reaches threshold | false | true | false | false | rounds | true |

---

## Inferred Intent

The function implements a *three-strikes* style bandwidth saturation detector:
three consecutive non-app-limited rounds without bandwidth growth signal that
the network has been fully probed. The `is_valid`/`is_app_limited` guards ensure
that ambiguous rounds (where send state was not measurable or the sender was
application-constrained) are not counted against the sender.

The design intentionally ignores app-limited rounds to avoid premature Startup
exits when the application is not sending at full rate.

---

## Open Questions

1. **OQ-T80-1**: When `is_valid = false`, is the full return-false (no counter
   update) the intended semantics, or should the round count in edge cases?
   The comment says "last_packet_send_state not available" — this seems correct
   but is underdocumented.
2. **OQ-T80-2**: Is there a risk of `rounds_without_bandwidth_growth` overflowing
   `u64` if Startup is stuck for extremely long? In practice unreachable, but an
   assertion would help.
3. **OQ-T80-3**: The interaction between `has_bandwidth_growth` and
   `check_persistent_queue` (both can set `full_bandwidth_reached`) is undocumented.
   Both paths are independent — is there a scenario where one should take priority?
