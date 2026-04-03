# Informal Specification — Flow Control Window Arithmetic

> 🔬 *Written by Lean Squad automated formal verification.*
> Source: `quiche/src/flowcontrol.rs`

---

## Purpose

`FlowControl` manages the receiver-side QUIC flow-control window for a
connection or stream.  The receiver tracks how many bytes it has consumed,
tells the sender the *maximum* it is permitted to send (`max_data`), and
periodically issues window updates to permit more data.

The key invariant is:

> `consumed ≤ max_data` — the receiver never grants a limit smaller than
> what the sender has already been allowed to consume.

An autotuning mechanism doubles the *window* size (up to `max_window`)
when updates arrive rapidly (within RTT × 2), reducing the number of
window-update frames on high-bandwidth paths.

---

## Data Structure

```rust
struct FlowControl {
    consumed:    u64,            // bytes consumed so far
    max_data:    u64,            // current limit advertised to peer
    window:      u64,            // receive-window size (for update policy)
    max_window:  u64,            // ceiling on window
    last_update: Option<Instant> // time of most recent max_data update
}
```

**Representation invariants** (must hold after construction and all mutations):

1. `window ≤ max_window`
2. `consumed ≤ max_data` — enforced by construction and by the protocol
   (the sender must respect the limit; the receiver only updates upward)

---

## Constructor

`FlowControl::new(max_data, window, max_window)`:

- Sets `consumed = 0`.
- Sets `window = min(window, max_window)` — silently clamps.
- Sets `max_data` and `max_window` as supplied.
- `last_update = None`.

**Postcondition**: invariants 1 and 2 hold.

---

## Operations

### `add_consumed(delta)`

Increases `consumed` by `delta`.

- **Precondition**: `consumed + delta ≤ max_data` (enforced by the QUIC
  protocol; the sender must not exceed the limit).
- **Postcondition**: `consumed` increases monotonically.
- **Note**: this operation does NOT change `max_data`; it only tracks how
  much has been consumed so far.

### `should_update_max_data() → bool`

Returns `true` when the available window (`max_data − consumed`) has
fallen below half the current window size:

```
available_window < window / 2
```

**Semantics**: this is a trigger to send a MAX_DATA frame.  The threshold
`window / 2` avoids sending too many update frames on low-consumption
connections.

**Postcondition (after `update_max_data`)**: `should_update_max_data()`
returns `false` immediately after `update_max_data` is called, because:
  `max_data_next = consumed + window`  →  available = `window` ≥ `window / 2`.

### `max_data_next() → u64`

Returns the proposed new limit: `consumed + window`.

- **Property**: `max_data_next ≥ consumed` (trivially, since `window ≥ 0`).
- **Property**: `max_data_next ≥ max_data` — the new limit is never
  *smaller* than the current one, provided `consumed + window ≥ max_data`.
  This holds in practice because `should_update_max_data` is only `true`
  when `available < window / 2`, i.e., `max_data − consumed < window / 2`,
  i.e., `max_data < consumed + window / 2 ≤ consumed + window = max_data_next`.

### `update_max_data(now)`

Commits the new limit:

```
max_data  ← consumed + window
last_update ← Some(now)
```

**Postcondition**:
- `max_data = consumed + window` immediately after the call.
- `should_update_max_data()` is `false` immediately after the call.
- `max_data` does not decrease (see `max_data_next` reasoning above).

### `autotune_window(now, rtt)`

If `last_update` is set and `now − last_update < rtt × 2`, doubles the
window (clamped to `max_window`).

- **Approximation in model**: `Instant` arithmetic is time-based; modelled
  as an abstract boolean parameter `should_tune : Bool`.
- **Postcondition**: `window ≤ max_window` still holds after the call.

### `set_window(w)` (private)

Sets `window ← min(w, max_window)`.

**Postcondition**: `window ≤ max_window`.

### `set_window_if_not_tuned_yet(w)`

Sets the window (via `set_window`) only if `last_update.is_none()`.

**Semantics**: lets initial configuration be overridden before the first
window update, but does not override autotuned values.

### `ensure_window_lower_bound(min_window)`

If `min_window > window`, calls `set_window(min_window)`.

**Postcondition**: `window ≥ min(min_window, max_window)`.

---

## Edge Cases

| Scenario | Expected Behaviour |
|----------|--------------------|
| `window > max_window` at construction | silently clamped; `window = max_window` |
| `consumed` reaches `max_data` exactly | `available_window = 0 < window / 2` (if `window > 0`), so `should_update = true` |
| `window = 0` | `window / 2 = 0`; `available_window < 0` is impossible; `should_update` is always `false` |
| `autotune` doubles `window` past `max_window` | `set_window` clamps to `max_window` |
| `ensure_window_lower_bound` with argument ≥ `max_window` | `window` is clamped to `max_window` |

---

## Examples

```
new(max_data=100, window=20, max_window=100):
  consumed=0, max_data=100, window=20, max_window=100

add_consumed(85):
  consumed=85, available=15 ≥ 10 = window/2  →  should_update=false

add_consumed(10):  consumed=95
  available=5 < 10 = window/2  →  should_update=true

max_data_next() = 95 + 20 = 115
update_max_data():  max_data=115

After autotune (within RTT×2):  window=40 (doubled)
```

---

## Open Questions / Ambiguities

1. **Integer overflow**: `consumed + window` could overflow `u64` in theory;
   the code does no overflow check.  In practice QUIC limits max stream/conn
   offsets to 2^62−1 (varint), so overflow is unreachable in compliant code.
2. **`add_consumed` without `should_update` check**: callers are responsible
   for checking `should_update_max_data` after `add_consumed`; missing this
   check could let the sender stall.  This is a liveness property, not a
   safety property.
3. **`autotune_window` time model**: whether `now − last_update < rtt × 2`
   uses monotonic or wall-clock time is implementation-dependent.
4. **Non-monotonicity risk**: if `max_data_next()` is called when
   `consumed + window < max_data` (i.e., `should_update` is `false` and the
   window has shrunk), calling `update_max_data` would *decrease* `max_data`,
   violating QUIC (MAX_DATA frames must be non-decreasing).  The code relies
   on callers only invoking `update_max_data` when `should_update_max_data()`
   is true.

---

## Inferred Intent

The design bundles *measurement* (`consumed`) and *policy* (`window`,
`max_window`, `should_update_max_data`) in a single struct.  The window-
doubling autotuner mirrors TCP receive-buffer autotuning: detect high-
throughput sessions by observing rapid acknowledgements and expand the
window to keep the pipe full.

The critical safety property is that `max_data` never decreases and
`consumed ≤ max_data` always holds — these are enforced by the protocol
layer, not by `FlowControl` internally.
