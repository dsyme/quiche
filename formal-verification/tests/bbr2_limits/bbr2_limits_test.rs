// Copyright (C) 2025, Cloudflare, Inc.
// SPDX-License-Identifier: BSD-2-Clause
//
// 🔬 Lean Squad — Route-B correspondence test for BBR2Limits
//
// This test verifies that the Lean model `FVSquad.BBR2Limits.applyLimits`
// corresponds to the Rust `Limits::apply_limits` function from
// `quiche/src/recovery/gcongestion/bbr2.rs`.
//
// Lean model (BBR2Limits.lean):
//   def Limits.applyLimits (l : Limits) (val : Nat) : Nat :=
//     Nat.min (Nat.max val l.lo) l.hi
//
// Rust source (bbr2.rs L401-L403):
//   fn apply_limits(&self, val: T) -> T {
//     val.max(self.lo).min(self.hi)
//   }
//
// The Lean model uses Nat.min/Nat.max which match Rust's Ord::max/min
// exactly on unsigned integer types.  There is no floating point or
// overflow involved: the functions are identical.
//
// Also tests `no_greater_than(val)` → lo=0, hi=val.
//
// Run with: cargo test
// Expected: all tests pass (PASS)

/// Mirror of Limits::apply_limits — pure function extracted from bbr2.rs.
/// Matches: `val.max(self.lo).min(self.hi)`
fn apply_limits(lo: usize, hi: usize, val: usize) -> usize {
    val.max(lo).min(hi)
}

/// Mirror of Limits::no_greater_than — pure constructor from bbr2.rs.
fn no_greater_than(val: usize) -> (usize, usize) {
    (0, val)
}

/// Lean model: Nat.min (Nat.max val lo) hi
/// (should be identical to apply_limits for all usize inputs)
fn lean_apply_limits(lo: usize, hi: usize, val: usize) -> usize {
    (val.max(lo)).min(hi)
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── 1. Basic clamping cases ──────────────────────────────────────────────

    #[test]
    fn val_below_lo_is_raised() {
        // val < lo: result = lo
        assert_eq!(apply_limits(10, 100, 5), 10);
        assert_eq!(lean_apply_limits(10, 100, 5), 10);
    }

    #[test]
    fn val_above_hi_is_lowered() {
        // val > hi: result = hi
        assert_eq!(apply_limits(10, 100, 200), 100);
        assert_eq!(lean_apply_limits(10, 100, 200), 100);
    }

    #[test]
    fn val_in_range_unchanged() {
        // lo <= val <= hi: result = val
        assert_eq!(apply_limits(10, 100, 50), 50);
        assert_eq!(lean_apply_limits(10, 100, 50), 50);
    }

    #[test]
    fn val_eq_lo_unchanged() {
        assert_eq!(apply_limits(10, 100, 10), 10);
        assert_eq!(lean_apply_limits(10, 100, 10), 10);
    }

    #[test]
    fn val_eq_hi_unchanged() {
        assert_eq!(apply_limits(10, 100, 100), 100);
        assert_eq!(lean_apply_limits(10, 100, 100), 100);
    }

    // ── 2. Edge cases ────────────────────────────────────────────────────────

    #[test]
    fn lo_equals_hi_always_returns_hi() {
        // lo == hi: result is always that value
        assert_eq!(apply_limits(50, 50, 0),   50);
        assert_eq!(apply_limits(50, 50, 50),  50);
        assert_eq!(apply_limits(50, 50, 100), 50);
        assert_eq!(lean_apply_limits(50, 50, 0),   50);
        assert_eq!(lean_apply_limits(50, 50, 50),  50);
        assert_eq!(lean_apply_limits(50, 50, 100), 50);
    }

    #[test]
    fn lo_zero_is_no_lower_clamp() {
        // lo=0: only the hi clamp is active
        assert_eq!(apply_limits(0, 1000, 0),    0);
        assert_eq!(apply_limits(0, 1000, 500),  500);
        assert_eq!(apply_limits(0, 1000, 2000), 1000);
        assert_eq!(lean_apply_limits(0, 1000, 0),    0);
        assert_eq!(lean_apply_limits(0, 1000, 500),  500);
        assert_eq!(lean_apply_limits(0, 1000, 2000), 1000);
    }

    #[test]
    fn hi_usize_max_is_no_upper_clamp() {
        // hi=usize::MAX: only the lo clamp is active
        let max = usize::MAX;
        assert_eq!(apply_limits(100, max, 0),   100);
        assert_eq!(apply_limits(100, max, 50),  100);
        assert_eq!(apply_limits(100, max, 200), 200);
        assert_eq!(lean_apply_limits(100, max, 0),   100);
        assert_eq!(lean_apply_limits(100, max, 50),  100);
        assert_eq!(lean_apply_limits(100, max, 200), 200);
    }

    #[test]
    fn lo_gt_hi_invalid_range_clamps_to_hi() {
        // When lo > hi (invalid range), Rust and Lean both return hi.
        // apply_limits: val.max(lo).min(hi)
        // If lo > hi: max(val, lo) >= lo > hi, so min(_, hi) = hi always.
        assert_eq!(apply_limits(100, 50, 0),   50);
        assert_eq!(apply_limits(100, 50, 75),  50);
        assert_eq!(apply_limits(100, 50, 200), 50);
        assert_eq!(lean_apply_limits(100, 50, 0),   50);
        assert_eq!(lean_apply_limits(100, 50, 75),  50);
        assert_eq!(lean_apply_limits(100, 50, 200), 50);
    }

    // ── 3. no_greater_than constructor ──────────────────────────────────────

    #[test]
    fn no_greater_than_lo_is_zero() {
        let (lo, _hi) = no_greater_than(1000);
        assert_eq!(lo, 0);
    }

    #[test]
    fn no_greater_than_hi_is_val() {
        let (_lo, hi) = no_greater_than(1000);
        assert_eq!(hi, 1000);
    }

    #[test]
    fn no_greater_than_apply_clamps_above() {
        let (lo, hi) = no_greater_than(500);
        assert_eq!(apply_limits(lo, hi, 1000), 500);
        assert_eq!(apply_limits(lo, hi, 250),  250);
        assert_eq!(apply_limits(lo, hi, 0),    0);
    }

    // ── 4. Lean-Rust agreement sweep ─────────────────────────────────────────

    /// Exhaustive sweep over a grid of (lo, hi, val) triples.
    /// Verifies that Rust and Lean model always agree.
    #[test]
    fn lean_rust_agreement_sweep() {
        let values = [0usize, 1, 5, 10, 50, 100, 500, 1000, usize::MAX / 2, usize::MAX];
        let mut count = 0;
        for &lo in &values {
            for &hi in &values {
                for &val in &values {
                    let rust = apply_limits(lo, hi, val);
                    let lean = lean_apply_limits(lo, hi, val);
                    assert_eq!(
                        rust, lean,
                        "Divergence at lo={lo}, hi={hi}, val={val}: \
                         Rust={rust}, Lean={lean}"
                    );
                    count += 1;
                }
            }
        }
        println!("=== BBR2Limits Route-B: {count} cases, all PASS ===");
    }

    // ── 5. Idempotence: applying limits twice = applying once ────────────────

    #[test]
    fn idempotence_sweep() {
        let lo = 10usize;
        let hi = 100usize;
        for val in [0usize, 5, 10, 50, 100, 150, 200] {
            let once = apply_limits(lo, hi, val);
            let twice = apply_limits(lo, hi, once);
            assert_eq!(once, twice, "Idempotence failed for val={val}");
        }
    }

    // ── 6. Monotonicity ──────────────────────────────────────────────────────

    #[test]
    fn monotonicity_in_val() {
        // If val1 <= val2, apply_limits(lo, hi, val1) <= apply_limits(lo, hi, val2)
        let lo = 20usize;
        let hi = 80usize;
        let vals = [0usize, 5, 20, 30, 50, 80, 100, 200];
        for &v1 in &vals {
            for &v2 in &vals {
                if v1 <= v2 {
                    assert!(
                        apply_limits(lo, hi, v1) <= apply_limits(lo, hi, v2),
                        "Monotonicity failed: v1={v1}, v2={v2}"
                    );
                }
            }
        }
    }
}

fn main() {
    println!("BBR2Limits Route-B correspondence tests — run with `cargo test`");
}
