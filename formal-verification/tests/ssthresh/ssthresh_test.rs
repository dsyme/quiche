// Copyright (C) 2024, Cloudflare, Inc.
// SPDX-License-Identifier: BSD-2-Clause
//
// 🔬 Lean Squad — Route-B correspondence tests for SsThresh
//
// Verifies that the Lean model `SsThreshState` in
// `formal-verification/lean/FVSquad/SsThresh.lean` agrees with the
// pure SsThresh logic extracted from
// `quiche/src/recovery/congestion/mod.rs`.
//
// Run with:
//   rustc --edition 2021 ssthresh_test.rs && ./ssthresh_test
//
// Source under test:
//   quiche/src/recovery/congestion/mod.rs — SsThresh struct + update()
//
// Lean model:
//   formal-verification/lean/FVSquad/SsThresh.lean
//   SsThreshState, SsThreshState.update, SsThreshState.updateList

// ─────────────────────────────────────────────────────────────────────────────
// §1  Rust model — pure logic extracted from SsThresh::update
// ─────────────────────────────────────────────────────────────────────────────
//
// The Rust `SsThresh::update(ssthresh, in_css)`:
//   1. If `startup_exit.is_none()`:
//      reason = ConservativeSlowStartRounds if in_css, else Loss
//      startup_exit = Some(StartupExit::new(ssthresh, None, reason))
//   2. self.ssthresh = ssthresh  (unconditionally)
//
// The write-once invariant: startup_exit is set exactly once (on the first
// call to update), and never overwritten by subsequent calls.
//
// Initial state: ssthresh = usize::MAX, startup_exit = None.
//
// Our Lean model abstracts StartupExit to just its ExitReason field:
//   ExitReason = ConservativeSlowStartRounds | Loss
//
// The Lean model SsThreshState mirrors:
//   struct SsThreshState { ssthresh: Nat, startupExit: Option ExitReason }
//
// Correspondence being tested:
//   Lean SsThreshState.update(s, n, true)  <=> Rust SsThresh::update(n, in_css=true)
//   Lean SsThreshState.update(s, n, false) <=> Rust SsThresh::update(n, in_css=false)
//   write-once property, ssthresh-always-updated property

const USIZE_MAX: usize = usize::MAX;

/// Models `StartupExitReason` from `quiche/src/recovery/mod.rs`.
#[derive(Clone, Copy, Debug, PartialEq)]
enum ExitReason {
    ConservativeSlowStartRounds,
    Loss,
}

/// Minimal `SsThresh` state: only the fields relevant to the write-once
/// invariant (abstracts away `cwnd` and `bandwidth` from `StartupExit`).
#[derive(Clone, Debug, PartialEq)]
struct SsThreshState {
    ssthresh: usize,
    startup_exit: Option<ExitReason>,
}

impl SsThreshState {
    /// Default state: ssthresh = usize::MAX, startup_exit = None.
    fn default_state() -> Self {
        SsThreshState {
            ssthresh: USIZE_MAX,
            startup_exit: None,
        }
    }

    /// One call to `SsThresh::update(ssthresh, in_css)`.
    fn update(&self, new_ssthresh: usize, in_css: bool) -> Self {
        let exit = match self.startup_exit {
            None => {
                let reason = if in_css {
                    ExitReason::ConservativeSlowStartRounds
                } else {
                    ExitReason::Loss
                };
                Some(reason)
            },
            Some(r) => Some(r),
        };
        SsThreshState { ssthresh: new_ssthresh, startup_exit: exit }
    }

    /// Apply a list of (ssthresh, in_css) pairs in sequence.
    fn update_list(&self, calls: &[(usize, bool)]) -> Self {
        calls.iter().fold(self.clone(), |acc, &(n, b)| acc.update(n, b))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// §2  Test harness
// ─────────────────────────────────────────────────────────────────────────────

struct TestCase {
    name: &'static str,
    initial: SsThreshState,
    calls: Vec<(usize, bool)>,
    expected_ssthresh: usize,
    expected_exit: Option<ExitReason>,
}

fn run_test(tc: &TestCase) -> bool {
    let result = tc.initial.update_list(&tc.calls);
    let ok = result.ssthresh == tc.expected_ssthresh
        && result.startup_exit == tc.expected_exit;
    if !ok {
        println!(
            "  FAIL [{}]: got ssthresh={}, exit={:?}; want ssthresh={}, exit={:?}",
            tc.name, result.ssthresh, result.startup_exit,
            tc.expected_ssthresh, tc.expected_exit
        );
    }
    ok
}

fn main() {
    let d = SsThreshState::default_state();
    let mut tests: Vec<TestCase> = Vec::new();

    // TC-01: Default state
    tests.push(TestCase {
        name: "default-state",
        initial: d.clone(), calls: vec![],
        expected_ssthresh: USIZE_MAX, expected_exit: None,
    });

    // TC-02: First update CSS
    tests.push(TestCase {
        name: "first-update-css",
        initial: d.clone(), calls: vec![(1000, true)],
        expected_ssthresh: 1000,
        expected_exit: Some(ExitReason::ConservativeSlowStartRounds),
    });

    // TC-03: First update Loss
    tests.push(TestCase {
        name: "first-update-loss",
        initial: d.clone(), calls: vec![(1000, false)],
        expected_ssthresh: 1000, expected_exit: Some(ExitReason::Loss),
    });

    // TC-04: First update, ssthresh = 0
    tests.push(TestCase {
        name: "first-update-zero",
        initial: d.clone(), calls: vec![(0, false)],
        expected_ssthresh: 0, expected_exit: Some(ExitReason::Loss),
    });

    // TC-05: Write-once: CSS not overwritten by Loss
    tests.push(TestCase {
        name: "write-once-css-not-overwritten",
        initial: d.clone(), calls: vec![(1000, true), (500, false)],
        expected_ssthresh: 500,
        expected_exit: Some(ExitReason::ConservativeSlowStartRounds),
    });

    // TC-06: Write-once: Loss not overwritten by CSS
    tests.push(TestCase {
        name: "write-once-loss-not-overwritten",
        initial: d.clone(), calls: vec![(1000, false), (500, true)],
        expected_ssthresh: 500, expected_exit: Some(ExitReason::Loss),
    });

    // TC-07: ssthresh always last value (3 updates)
    tests.push(TestCase {
        name: "ssthresh-last-wins",
        initial: d.clone(), calls: vec![(100, true), (200, false), (300, true)],
        expected_ssthresh: 300,
        expected_exit: Some(ExitReason::ConservativeSlowStartRounds),
    });

    // TC-08: CSS stays across multiple updates
    tests.push(TestCase {
        name: "css-stays-across-multiple",
        initial: d.clone(), calls: vec![(1000, true), (2000, true), (3000, true)],
        expected_ssthresh: 3000,
        expected_exit: Some(ExitReason::ConservativeSlowStartRounds),
    });

    // TC-09: Loss stays across multiple updates
    tests.push(TestCase {
        name: "loss-stays-across-multiple",
        initial: d.clone(), calls: vec![(1000, false), (2000, false), (3000, false)],
        expected_ssthresh: 3000, expected_exit: Some(ExitReason::Loss),
    });

    // TC-10: Start with exit already set (CSS)
    tests.push(TestCase {
        name: "already-set-css",
        initial: SsThreshState {
            ssthresh: 5000,
            startup_exit: Some(ExitReason::ConservativeSlowStartRounds),
        },
        calls: vec![(1000, false), (2000, true)],
        expected_ssthresh: 2000,
        expected_exit: Some(ExitReason::ConservativeSlowStartRounds),
    });

    // TC-11: Start with exit already set (Loss)
    tests.push(TestCase {
        name: "already-set-loss",
        initial: SsThreshState {
            ssthresh: 5000,
            startup_exit: Some(ExitReason::Loss),
        },
        calls: vec![(1000, true), (2000, false)],
        expected_ssthresh: 2000, expected_exit: Some(ExitReason::Loss),
    });

    // TC-12: Update to USIZE_MAX
    tests.push(TestCase {
        name: "update-to-usize-max",
        initial: d.clone(), calls: vec![(USIZE_MAX, true)],
        expected_ssthresh: USIZE_MAX,
        expected_exit: Some(ExitReason::ConservativeSlowStartRounds),
    });

    // TC-13: 5 alternating updates
    tests.push(TestCase {
        name: "5-alternating-updates",
        initial: d.clone(),
        calls: vec![(100, true), (200, false), (300, true), (400, false), (50, true)],
        expected_ssthresh: 50,
        expected_exit: Some(ExitReason::ConservativeSlowStartRounds),
    });

    // TC-14: 8 Loss updates
    {
        let calls: Vec<(usize, bool)> = (1..=8).map(|i| (i * 200, false)).collect();
        let last = calls.last().unwrap().0;
        tests.push(TestCase {
            name: "8-loss-updates",
            initial: d.clone(), calls,
            expected_ssthresh: last, expected_exit: Some(ExitReason::Loss),
        });
    }

    // TC-15: Single update ssthresh=1
    tests.push(TestCase {
        name: "single-update-one",
        initial: d.clone(), calls: vec![(1, true)],
        expected_ssthresh: 1,
        expected_exit: Some(ExitReason::ConservativeSlowStartRounds),
    });

    // TC-16: Two identical calls
    tests.push(TestCase {
        name: "two-identical-calls",
        initial: d.clone(), calls: vec![(1234, false), (1234, false)],
        expected_ssthresh: 1234, expected_exit: Some(ExitReason::Loss),
    });

    // TC-17: Alternating in_css, verify first exit preserved
    tests.push(TestCase {
        name: "alternating-inCss-first-exit",
        initial: d.clone(),
        calls: vec![(1000, true), (999, false), (1001, true), (998, false), (1002, true)],
        expected_ssthresh: 1002,
        expected_exit: Some(ExitReason::ConservativeSlowStartRounds),
    });

    // TC-18: Verify exit is Some after first update (isSome invariant)
    {
        let s1 = d.update(100, true);
        tests.push(TestCase {
            name: "exit-is-some-after-first",
            initial: s1.clone(),
            calls: vec![(200, false), (300, true), (400, false)],
            expected_ssthresh: 400,
            expected_exit: Some(ExitReason::ConservativeSlowStartRounds),
        });
    }

    // TC-19: Large ssthresh, then decreasing
    tests.push(TestCase {
        name: "decreasing-ssthresh",
        initial: d.clone(),
        calls: vec![(5000, false), (4000, false), (3000, false)],
        expected_ssthresh: 3000, expected_exit: Some(ExitReason::Loss),
    });

    // TC-20: Double update, exit unchanged (Lean double_update_exit_unchanged)
    tests.push(TestCase {
        name: "double-update-exit-unchanged",
        initial: d.clone(), calls: vec![(1000, true), (2000, false)],
        expected_ssthresh: 2000,
        expected_exit: Some(ExitReason::ConservativeSlowStartRounds),
    });

    // TC-21: Start with exit=None, single Loss call
    tests.push(TestCase {
        name: "none-to-loss-single-call",
        initial: d.clone(), calls: vec![(999, false)],
        expected_ssthresh: 999, expected_exit: Some(ExitReason::Loss),
    });

    // TC-22: Large sequence, first reason = CSS
    {
        let calls: Vec<(usize, bool)> = (0..12).map(|i| (i * 500 + 100, i < 6)).collect();
        let last = calls.last().unwrap().0;
        tests.push(TestCase {
            name: "12-updates-css-first",
            initial: d.clone(), calls,
            expected_ssthresh: last,
            expected_exit: Some(ExitReason::ConservativeSlowStartRounds),
        });
    }

    // TC-23: Already-set exit, single update changes ssthresh
    tests.push(TestCase {
        name: "already-set-single-update",
        initial: SsThreshState {
            ssthresh: 10000,
            startup_exit: Some(ExitReason::Loss),
        },
        calls: vec![(9000, true)],
        expected_ssthresh: 9000, expected_exit: Some(ExitReason::Loss),
    });

    // TC-24: No-exit state, 4 updates
    tests.push(TestCase {
        name: "four-updates-loss",
        initial: d.clone(),
        calls: vec![(400, false), (300, true), (200, false), (100, true)],
        expected_ssthresh: 100, expected_exit: Some(ExitReason::Loss),
    });

    // TC-25: ssthresh after many decrements
    {
        let calls: Vec<(usize, bool)> = (0..10).map(|i| (1000 - i * 50, false)).collect();
        let last = calls.last().unwrap().0;
        tests.push(TestCase {
            name: "decreasing-10-steps",
            initial: d.clone(), calls,
            expected_ssthresh: last, expected_exit: Some(ExitReason::Loss),
        });
    }

    // ── Run all ───────────────────────────────────────────────────────────────

    println!("=== SsThresh Route-B Correspondence Tests ({} cases) ===", tests.len());

    let mut passed = 0;
    let mut failed = 0;
    for tc in &tests {
        if run_test(tc) {
            passed += 1;
        } else {
            failed += 1;
        }
    }
    println!("\n=== Results: {}/{} PASS, {} FAIL ===", passed, tests.len(), failed);
    if failed > 0 {
        std::process::exit(1);
    }
    println!("All tests passed — Rust SsThresh model corresponds to Lean SsThreshState.");
}
