// Copyright (C) 2025, Cloudflare, Inc.
// SPDX-License-Identifier: BSD-2-Clause
//
// formal-verification/tests/loss_detection_threshold/loss_detection_threshold_test.rs
//
// 🔬 Lean Squad — Route-B correspondence test for T56 LossDetectionThreshold.
//
// Tests that the Lean model of `updatePktThresh` matches the Rust
// implementation in quiche/src/recovery/congestion/recovery.rs L655–660.
//
// The Lean model:
//   clampToMax s  = if s ≤ 20 then s else 20
//   updatePktThresh current spurious = max(current, clampToMax(spurious))
//
// The Rust implementation:
//   self.pkt_thresh = self.pkt_thresh.max(thresh.min(MAX_PACKET_THRESHOLD));
//
// These are mathematically identical:
//   max(current, min(spurious, MAX)) = max(current, clampToMax(spurious))
//
// Run with: rustdoc --test loss_detection_threshold_test.rs
// (or just execute the main() function)

const INITIAL_PACKET_THRESHOLD: u64 = 3;
const MAX_PACKET_THRESHOLD: u64 = 20;

/// Lean model: clampToMax
fn clamp_to_max(s: u64) -> u64 {
    if s <= MAX_PACKET_THRESHOLD {
        s
    } else {
        MAX_PACKET_THRESHOLD
    }
}

/// Lean model: updatePktThresh current spurious
fn update_pkt_thresh_lean(current: u64, spurious: u64) -> u64 {
    let c = clamp_to_max(spurious);
    if current <= c {
        c
    } else {
        current
    }
}

/// Rust implementation from recovery.rs L657-658:
///   self.pkt_thresh = self.pkt_thresh.max(thresh.min(MAX_PACKET_THRESHOLD));
fn update_pkt_thresh_rust(current: u64, spurious: u64) -> u64 {
    current.max(spurious.min(MAX_PACKET_THRESHOLD))
}

fn run_tests() -> (usize, usize) {
    let mut pass = 0usize;
    let mut fail = 0usize;

    // Test cases: (current, spurious, expected_description)
    let cases: Vec<(u64, u64, &str)> = vec![
        // From #eval spot-checks in LossDetectionThreshold.lean
        (3, 3, "initial, no change"),
        (3, 4, "spurious reorder of 4 — increases threshold"),
        (4, 3, "current dominates — no change"),
        (3, 25, "spurious clamped to MAX"),
        (20, 30, "already at MAX — stays at MAX"),
        // Constants
        (INITIAL_PACKET_THRESHOLD, INITIAL_PACKET_THRESHOLD, "initial+initial"),
        (MAX_PACKET_THRESHOLD, MAX_PACKET_THRESHOLD, "max+max"),
        // Edge cases: spurious = 0 → no change (update_spurious_zero theorem)
        (3, 0, "spurious=0, current stays"),
        (10, 0, "spurious=0, current=10 stays"),
        (20, 0, "spurious=0, current=MAX stays"),
        // update_at_max theorem: current=MAX → always MAX
        (20, 0, "at max, spurious=0"),
        (20, 5, "at max, spurious=5"),
        (20, 20, "at max, spurious=MAX"),
        (20, 21, "at max, spurious over MAX"),
        // Boundary around MAX_PACKET_THRESHOLD
        (3, 19, "spurious=MAX-1"),
        (3, 20, "spurious=MAX"),
        (3, 21, "spurious=MAX+1 — clamped"),
        (3, 100, "spurious=100 — clamped to MAX"),
        (15, 18, "spurious < MAX, > current"),
        (18, 15, "current > spurious"),
        // Invariant preservation: INITIAL ≤ result ≤ MAX
        (3, 7, "invariant preserved — update upward"),
        (7, 3, "invariant preserved — current dominates"),
        (3, MAX_PACKET_THRESHOLD, "spurious=MAX exactly"),
        (1, MAX_PACKET_THRESHOLD, "below initial, spurious=MAX"),
        (0, MAX_PACKET_THRESHOLD, "zero current, spurious=MAX"),
        (0, 0, "both zero"),
        (0, 1, "zero current, spurious=1"),
        (1, 0, "current=1, spurious=0"),
        (MAX_PACKET_THRESHOLD - 1, MAX_PACKET_THRESHOLD + 5, "almost-max+over"),
        (MAX_PACKET_THRESHOLD + 1, MAX_PACKET_THRESHOLD, "over-max current (hypothetical)"),
    ];

    for (current, spurious, desc) in &cases {
        let lean_result = update_pkt_thresh_lean(*current, *spurious);
        let rust_result = update_pkt_thresh_rust(*current, *spurious);
        if lean_result == rust_result {
            pass += 1;
        } else {
            eprintln!(
                "FAIL [{}]: update_pkt_thresh({}, {}) — Lean={}, Rust={}",
                desc, current, spurious, lean_result, rust_result
            );
            fail += 1;
        }
    }

    // Exhaustive sweep: all (current, spurious) in [0..30] × [0..30]
    for current in 0u64..=30 {
        for spurious in 0u64..=30 {
            let lean_result = update_pkt_thresh_lean(current, spurious);
            let rust_result = update_pkt_thresh_rust(current, spurious);
            if lean_result == rust_result {
                pass += 1;
            } else {
                eprintln!(
                    "FAIL [exhaustive]: update_pkt_thresh({}, {}) — Lean={}, Rust={}",
                    current, spurious, lean_result, rust_result
                );
                fail += 1;
            }
        }
    }

    (pass, fail)
}

fn main() {
    let (pass, fail) = run_tests();
    let total = pass + fail;
    if fail == 0 {
        println!("PASS {}/{} test cases", pass, total);
    } else {
        eprintln!("FAIL {}/{} test cases failed", fail, total);
        std::process::exit(1);
    }
}
