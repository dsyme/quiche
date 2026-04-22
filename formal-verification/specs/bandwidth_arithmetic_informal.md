# Informal Specification: Bandwidth Arithmetic Invariants (T36)

> 🔬 *Written by Lean Squad automated formal verification.*

**Target**: `Bandwidth` struct and its arithmetic methods in
`quiche/src/recovery/bandwidth.rs`

**Phase**: 2 — Informal Specification (T36, run 90)

---

## Purpose

`Bandwidth` is a thin wrapper around a `u64` representing network bandwidth in
bits per second. It provides constructors, unit conversions, and arithmetic
operations used throughout the BBR2/gcongestion controller to reason about
sending rates and delivery rates.

The key correctness properties are:

1. **Unit-conversion round-trips**: constructing a `Bandwidth` from a rate in
   one unit and then reading it back in the same unit returns the original
   value (modulo integer rounding).
2. **Ordering consistency**: `from_kbits_per_second` is monotone — larger
   input yields larger bandwidth.
3. **Addition commutativity and associativity** (Nat arithmetic on the
   underlying u64 field).
4. **`from_bytes_per_second` / `to_bytes_per_second` round-trip**: converting
   bytes/s → `Bandwidth` → bytes/s loses at most the low 3 bits (factor-of-8
   rounding, since 1 byte = 8 bits).
5. **`to_bytes_per_period` scaling**: `bps * nanos / 8 / 1e9` is a
   monotone function of both bandwidth and time period.
6. **Special values**: `zero()` has `bits_per_second = 0`; `infinite()` has
   `bits_per_second = u64::MAX`.
7. **`from_bytes_and_time_delta` lower bound**: when `bytes > 0` and
   `time_delta.as_nanos() > 0`, the result is always ≥ 1 bps; when both
   numerator and denominator are 0 (zero bytes), the result is 0.

---

## Type Definition

```rust
pub struct Bandwidth {
    bits_per_second: u64,   // internal representation
}
```

All arithmetic is on `u64`; overflow is not defended against (wraps in
release builds under Rust's default u64 wrapping semantics for multiplication
by f64).

---

## Preconditions

- All inputs are non-negative (the type only stores `u64`).
- `from_bytes_and_time_delta`: no precondition required (all edge cases
  handled: `bytes = 0`, `time_delta = 0`).
- `to_bytes_per_period`: the result is 0 when bandwidth is 0 or time period
  is 0.

---

## Postconditions

### `from_kbits_per_second(k)` → `Bandwidth { bits_per_second: k * 1000 }`

For all `k : u64` such that `k * 1000` does not overflow u64:

```
from_kbits_per_second(k).bits_per_second = k * 1000
```

### `from_bytes_per_second(b)` → `Bandwidth { bits_per_second: b * 8 }`

```
from_bytes_per_second(b).bits_per_second = b * 8
to_bytes_per_second(from_bytes_per_second(b)) = b
```

### `to_bytes_per_second(bw)` → `bw.bits_per_second / 8`

```
to_bytes_per_second(bw) = bw.bits_per_second / 8
```

(Integer division; result ≤ original if not a multiple of 8.)

### Addition

```
(a + b).bits_per_second = a.bits_per_second + b.bits_per_second
```

### Subtraction (checked)

```
(a - b) = Some(c)  ↔  a.bits_per_second ≥ b.bits_per_second
                       ∧  c.bits_per_second = a.bits_per_second - b.bits_per_second
(a - b) = None     ↔  a.bits_per_second < b.bits_per_second
```

### `to_bytes_per_period(bw, t_nanos)`

```
to_bytes_per_period(bw, t) = bw.bits_per_second * t.as_nanos() / 8 / 1_000_000_000
```

Monotone in both arguments:

```
bw1 ≤ bw2 → to_bytes_per_period(bw1, t) ≤ to_bytes_per_period(bw2, t)
t1  ≤ t2  → to_bytes_per_period(bw, t1) ≤ to_bytes_per_period(bw, t2)
```

### Special values

```
zero().bits_per_second = 0
infinite().bits_per_second = u64::MAX
zero()  ≤ bw              (for all bw)
bw      ≤ infinite()      (for all bw)
```

### `from_bytes_and_time_delta` lower bound

```
bytes = 0  →  from_bytes_and_time_delta(bytes, t).bits_per_second = 0
bytes > 0  →  from_bytes_and_time_delta(bytes, t).bits_per_second ≥ 1
```

---

## Invariants

- `Bandwidth` is totally ordered (`PartialOrd + Ord` derived).
- `from_kbits_per_second` is strictly monotone for inputs not overflowing u64.
- Addition is commutative and associative modulo overflow.

---

## Edge Cases

- `to_bytes_per_period` with `time_period = 0`: result is 0 (Nat mul).
- `to_bytes_per_period` with `bw = zero()`: result is 0.
- `from_bytes_and_time_delta(0, any)` = 0 bps.
- `from_bytes_and_time_delta(n > 0, Duration::ZERO)`:
  `nanos` is clamped to 1, so result = `8 * n * 1e9` (very large).
- `from_kbits_per_second(u64::MAX / 1000 + 1)`: overflows — not modelled.

---

## Examples

```
from_kbits_per_second(1).to_bytes_per_period(10_000ms) = 1250
from_kbits_per_second(1).to_bytes_per_period(1000ms)   = 125
from_kbits_per_second(1).to_bytes_per_period(100ms)    = 12
from_bytes_per_second(125).to_bytes_per_second()       = 125
from_bytes_and_time_delta(10, 1000ms).bits_per_second  = 80
zero().bits_per_second                                 = 0
infinite().bits_per_second                             = 18446744073709551615
```

---

## Open Questions

- OQ-T36-1: `Mul<f64>` rounds with `.round()`. When might the rounding
  cause monotonicity to break? (Not modelled in Lean — f64 is excluded.)
- OQ-T36-2: `from_bytes_and_time_delta` with very large `bytes` may overflow
  `8 * bytes * 1e9` even on u64 — the Rust code is not overflow-safe here.
  Worth checking if this is actually reachable from callers.

---

## Lean Modelling Notes

- Represent `Bandwidth` as a Lean `structure` wrapping `Nat` (no overflow).
- Model `Duration` as `Nat` (nanoseconds). Integer division only.
- Exclude `f64`-based `Mul` — not modelable in pure integer Lean.
- `from_bytes_and_time_delta`: model the three-branch formula exactly.
- All key properties provable by `omega` on `Nat` arithmetic.
