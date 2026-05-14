# BBR2 Limits — Route-B Correspondence Tests

🔬 *Lean Squad — automated formal verification for `dsyme/quiche`.*

## Target

`FVSquad.BBR2Limits` — formal model of `Limits::apply_limits` and
`Limits::no_greater_than` from
`quiche/src/recovery/gcongestion/bbr2.rs` (lines 391–412).

## Lean Model

```lean
-- BBR2Limits.lean
def Limits.applyLimits (l : Limits) (val : Nat) : Nat :=
  Nat.min (Nat.max val l.lo) l.hi

def Limits.noGreaterThan (val : Nat) : Limits :=
  { lo := 0, hi := val }
```

## Rust Source

```rust
// bbr2.rs L401-L403
fn apply_limits(&self, val: T) -> T {
    val.max(self.lo).min(self.hi)
}

// bbr2.rs L407-L410
pub(crate) fn no_greater_than(val: T) -> Self {
    Self { lo: T::from(0), hi: val }
}
```

## Correspondence

The Lean model uses `Nat.min (Nat.max val lo) hi`, which is
mathematically identical to Rust's `val.max(lo).min(hi)` for
all unsigned integer inputs.  There is **no floating point**
and **no overflow** involved — the correspondence is exact.

| Lean definition | Rust function | Correspondence |
|----------------|---------------|----------------|
| `Limits.applyLimits` | `Limits::apply_limits` | Exact (identical semantics) |
| `Limits.noGreaterThan` | `Limits::no_greater_than` | Exact |
| `Limits.Valid` | (invariant: lo ≤ hi) | Structural invariant |

## How to Run

```bash
cd formal-verification/tests/bbr2_limits
cargo test
```

## Results (run 159)

```
running 15 tests
test tests::hi_usize_max_is_no_upper_clamp ... ok
test tests::idempotence_sweep ... ok
test tests::lean_rust_agreement_sweep ... ok  (1000 cases: 10×10×10 grid)
test tests::lo_equals_hi_always_returns_hi ... ok
test tests::lo_zero_is_no_lower_clamp ... ok
test tests::monotonicity_in_val ... ok
test tests::lo_gt_hi_invalid_range_clamps_to_hi ... ok
test tests::no_greater_than_apply_clamps_above ... ok
test tests::no_greater_than_hi_is_val ... ok
test tests::no_greater_than_lo_is_zero ... ok
test tests::val_above_hi_is_lowered ... ok
test tests::val_below_lo_is_raised ... ok
test tests::val_eq_hi_unchanged ... ok
test tests::val_eq_lo_unchanged ... ok
test tests::val_in_range_unchanged ... ok

test result: ok. 15 passed; 0 failed; 0 ignored
```

Total: **15 tests, 1000+ cases, all PASS**.

## Coverage

| Category | Cases | Notes |
|----------|-------|-------|
| val < lo (raised to lo) | 3 | direct |
| val > hi (lowered to hi) | 3 | direct |
| val in [lo, hi] (unchanged) | 3 | direct |
| val == lo | 1 | boundary |
| val == hi | 1 | boundary |
| lo == hi | 3 | degenerate |
| lo = 0 (no lower clamp) | 3 | typical BBR2 usage |
| hi = usize::MAX (no upper clamp) | 3 | unbounded |
| lo > hi (invalid range → always hi) | 3 | edge case |
| no_greater_than constructor | 3 | lo=0, hi=val |
| Lean-Rust sweep (10×10×10 grid) | 1000 | exact agreement |
| Idempotence | 7 | apply twice = apply once |
| Monotonicity in val | 28 pairs | apply_limits is monotone |

## What Is and Is Not Covered

**Covered:**
- The pure clamping logic `val.max(lo).min(hi)` on `usize` values
- The `no_greater_than` constructor invariant (lo=0, hi=val)
- Edge cases: degenerate [lo,lo], unbounded, invalid lo>hi ranges

**Not covered:**
- Generic type parameter instantiation other than `usize`
- The full BBRv2 congestion control state that uses `Limits`
- Pacing rate calculations that call `apply_limits` (involve f32)
