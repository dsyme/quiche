// Copyright (C) 2025, Cloudflare, Inc.
// BSD-2-Clause licence (same as quiche)
//
// Route-B correspondence test for WindowedFilter (T49).
//
// Tests that the Lean model in FVSquad/WindowedFilter.lean faithfully
// captures the pure value-comparison logic from the Rust
// quiche/src/recovery/gcongestion/bbr/windowed_filter.rs `update` method.
//
// The Lean model (`update_pure`) abstracts away time-based windowing and
// models only the four pure-value cases of the update logic:
//   1. new_sample > best   → reset all three slots to new_sample
//   2. new_sample > second → update second and third to new_sample
//   3. new_sample > third  → update third to new_sample
//   4. otherwise           → no change
//
// Run from the workspace root:
//   rustc formal-verification/tests/windowed_filter/windowed_filter_test.rs \
//         -o /tmp/windowed_filter_test && /tmp/windowed_filter_test

// ─── Estimates type (mirrors Lean `Estimates`) ───────────────────────────────

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct Estimates {
    best: u64,
    second: u64,
    third: u64,
}

impl Estimates {
    fn new(best: u64, second: u64, third: u64) -> Self {
        Estimates { best, second, third }
    }
}

// ─── Lean model (transliterated from FVSquad/WindowedFilter.lean) ────────────

/// Lean: `def reset (s : Nat) : Estimates := { best := s, second := s, third := s }`
fn lean_reset(s: u64) -> Estimates {
    Estimates::new(s, s, s)
}

/// Lean: `def update_second_third (e : Estimates) (s : Nat) : Estimates :=`
///         `{ e with second := s, third := s }`
fn lean_update_second_third(e: Estimates, s: u64) -> Estimates {
    Estimates::new(e.best, s, s)
}

/// Lean: `def update_third_only (e : Estimates) (s : Nat) : Estimates :=`
///         `{ e with third := s }`
fn lean_update_third_only(e: Estimates, s: u64) -> Estimates {
    Estimates::new(e.best, e.second, s)
}

/// Lean: `def update_pure (e : Estimates) (s : Nat) : Estimates :=`
///   `if s > e.best then reset s`
///   `else if s > e.second then update_second_third e s`
///   `else if s > e.third then update_third_only e s`
///   `else e`
fn lean_update_pure(e: Estimates, s: u64) -> Estimates {
    if s > e.best {
        lean_reset(s)
    } else if s > e.second {
        lean_update_second_third(e, s)
    } else if s > e.third {
        lean_update_third_only(e, s)
    } else {
        e
    }
}

// ─── Rust pure-value logic (extracted from windowed_filter.rs) ────────────────
//
// The Rust `update` method mixes time-based windowing with pure value updates.
// We extract only the pure-value path (ignoring time), which is what the Lean
// model captures. This corresponds to the non-windowing case where no estimates
// are expired and the newest estimate is not too old.

fn rust_update_pure(best: u64, second: u64, third: u64, new_sample: u64)
    -> (u64, u64, u64)
{
    // Reset if new sample is a new best (ignoring time-based reset).
    if new_sample > best {
        return (new_sample, new_sample, new_sample);
    }
    let (mut s1, mut s2, mut s3) = (best, second, third);
    // Update second and third if new_sample > second.
    if new_sample > s2 {
        s2 = new_sample;
        s3 = new_sample;
    } else if new_sample > s3 {
        // Update only third.
        s3 = new_sample;
    }
    (s1, s2, s3)
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

fn check(
    label: &str,
    e: Estimates,
    s: u64,
    exp: Estimates,
    passed: &mut usize,
    failed: &mut usize,
) {
    let lean_out = lean_update_pure(e, s);
    let (rb, rs, rt) = rust_update_pure(e.best, e.second, e.third, s);
    let rust_out = Estimates::new(rb, rs, rt);

    let lean_ok = lean_out == exp;
    let corr_ok = lean_out == rust_out;

    if lean_ok && corr_ok {
        *passed += 1;
    } else {
        *failed += 1;
        println!("FAIL  {}", label);
        if !lean_ok {
            println!("  lean: {:?}  expected: {:?}", lean_out, exp);
        }
        if !corr_ok {
            println!("  lean: {:?}  rust: {:?}", lean_out, rust_out);
        }
    }
}

// ─── Test cases ───────────────────────────────────────────────────────────────

fn main() {
    let mut passed = 0usize;
    let mut failed = 0usize;

    // ── Case 1: reset (new_sample > best) ────────────────────────────────────
    let e = Estimates::new(10, 7, 5);

    check("reset: sample=20 > best=10 → all 20",
        e, 20, Estimates::new(20, 20, 20), &mut passed, &mut failed);

    check("reset: sample=11 > best=10 → all 11",
        e, 11, Estimates::new(11, 11, 11), &mut passed, &mut failed);

    check("reset: sample=10+1 just above best",
        Estimates::new(5, 3, 1), 6, Estimates::new(6, 6, 6),
        &mut passed, &mut failed);

    // ── Case 2: update_second_third (sample > second but ≤ best) ─────────────
    check("update_second_third: sample=8 (>7 second, ≤10 best)",
        e, 8, Estimates::new(10, 8, 8), &mut passed, &mut failed);

    check("update_second_third: sample=9 (>7 second, ≤10 best)",
        e, 9, Estimates::new(10, 9, 9), &mut passed, &mut failed);

    check("update_second_third: sample equals best (=10, not >)",
        e, 10, Estimates::new(10, 10, 10), &mut passed, &mut failed);

    // ── Case 3: update_third_only (sample > third but ≤ second) ──────────────
    check("update_third_only: sample=6 (>5 third, ≤7 second)",
        e, 6, Estimates::new(10, 7, 6), &mut passed, &mut failed);

    check("update_third_only: sample=7 (=second, not >)",
        e, 7, Estimates::new(10, 7, 7), &mut passed, &mut failed);

    check("update_third_only: sample=5+1=6",
        Estimates::new(15, 10, 4), 5, Estimates::new(15, 10, 5),
        &mut passed, &mut failed);

    // ── Case 4: no change (sample ≤ third) ───────────────────────────────────
    check("no change: sample=5 = third",
        e, 5, Estimates::new(10, 7, 5), &mut passed, &mut failed);

    check("no change: sample=4 < third",
        e, 4, Estimates::new(10, 7, 5), &mut passed, &mut failed);

    check("no change: sample=0",
        e, 0, Estimates::new(10, 7, 5), &mut passed, &mut failed);

    // ── Uniform initial state (all slots equal) ───────────────────────────────
    let u = Estimates::new(10, 10, 10);

    check("uniform: sample=11 > best → reset to 11",
        u, 11, Estimates::new(11, 11, 11), &mut passed, &mut failed);

    check("uniform: sample=10 = all → no change",
        u, 10, Estimates::new(10, 10, 10), &mut passed, &mut failed);

    check("uniform: sample=9 < all → no change",
        u, 9, Estimates::new(10, 10, 10), &mut passed, &mut failed);

    // ── reset then update ─────────────────────────────────────────────────────
    let r = lean_reset(20);  // { 20, 20, 20 }

    check("after reset(20): sample=25 → reset to 25",
        r, 25, Estimates::new(25, 25, 25), &mut passed, &mut failed);

    check("after reset(20): sample=15 (not >20) → no change",
        r, 15, Estimates::new(20, 20, 20), &mut passed, &mut failed);

    // ── ordered invariant checks via lean_update_pure ─────────────────────────
    // For all cases, output.best >= output.second >= output.third
    let cases: &[(Estimates, u64)] = &[
        (Estimates::new(100, 80, 60), 90),
        (Estimates::new(100, 80, 60), 70),
        (Estimates::new(100, 80, 60), 50),
        (Estimates::new(100, 80, 60), 110),
        (Estimates::new(50, 50, 50), 30),
        (Estimates::new(50, 50, 50), 60),
    ];

    for (e, s) in cases {
        let out = lean_update_pure(*e, *s);
        let ordered = out.best >= out.second && out.second >= out.third;
        if ordered {
            passed += 1;
        } else {
            failed += 1;
            println!("FAIL  ordering violated: e={:?} s={} out={:?}", e, s, out);
        }
    }

    // ── Sequence: multiple updates preserve ordering ───────────────────────────
    let mut state = lean_reset(100);
    let sequence: &[u64] = &[90, 80, 110, 95, 85, 75, 120, 100, 60, 50];
    let mut seq_ok = true;
    for &s in sequence {
        state = lean_update_pure(state, s);
        if !(state.best >= state.second && state.second >= state.third) {
            seq_ok = false;
            println!("FAIL  sequence ordering violated at sample={}: {:?}", s, state);
        }
    }
    if seq_ok {
        passed += 1;
    } else {
        failed += 1;
    }

    // ── Final report ──────────────────────────────────────────────────────────
    println!();
    println!("Results: {} passed, {} failed", passed, failed);
    if failed > 0 {
        std::process::exit(1);
    }
}
