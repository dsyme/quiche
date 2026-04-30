// Copyright (C) 2025, Cloudflare, Inc.
// BSD-2-Clause licence (same as quiche)
//
// Route-B correspondence test for PathState (T38).
//
// Tests that the Lean model in FVSquad/PathState.lean faithfully captures
// the Rust PathState transitions from quiche/src/path.rs.
//
// Run:
//   rustc path_state_test.rs -o /tmp/path_state_test && /tmp/path_state_test

// ─── Rust PathState (copied verbatim from quiche/src/path.rs:53-67) ─────────

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord)]
enum PathState {
    Failed,
    Unknown,
    Validating,
    ValidatingMTU,
    Validated,
}

/// Rust promote_to (mirrors Path::promote_to, path.rs:340)
fn promote_to(current: PathState, new: PathState) -> PathState {
    if current < new { new } else { current }
}

/// Rust on_challenge_sent (path.rs:392 — state transition only)
fn on_challenge_sent(s: PathState) -> PathState {
    promote_to(s, PathState::Validating)
}

/// Rust on_response_received (path.rs:421 — pure state model).
/// `mtu_ok` encodes whether max_challenge_size >= MIN_CLIENT_INITIAL_LEN.
fn on_response_received(s: PathState, mtu_ok: bool) -> PathState {
    let s1 = promote_to(s, PathState::ValidatingMTU);
    if mtu_ok && s1 == PathState::ValidatingMTU {
        promote_to(s1, PathState::Validated)
    } else {
        s1
    }
}

/// Rust on_failed_validation (path.rs:455 — state transition only)
fn on_failed_validation() -> PathState {
    PathState::Failed
}

// ─── Lean model (transliterated from FVSquad/PathState.lean) ────────────────

fn rank(s: PathState) -> u32 {
    match s {
        PathState::Failed        => 0,
        PathState::Unknown       => 1,
        PathState::Validating    => 2,
        PathState::ValidatingMTU => 3,
        PathState::Validated     => 4,
    }
}

fn lean_promote_to(current: PathState, new: PathState) -> PathState {
    if rank(current) < rank(new) { new } else { current }
}

fn lean_on_challenge_sent(s: PathState) -> PathState {
    lean_promote_to(s, PathState::Validating)
}

fn lean_on_response_received(s: PathState, mtu_ok: bool) -> PathState {
    let s1 = lean_promote_to(s, PathState::ValidatingMTU);
    if mtu_ok { lean_promote_to(s1, PathState::Validated) } else { s1 }
}

fn lean_on_failed_validation() -> PathState {
    PathState::Failed
}

fn lean_working(s: PathState) -> bool {
    rank(s) > 0
}

// ─── Test harness ────────────────────────────────────────────────────────────

fn state_name(s: PathState) -> &'static str {
    match s {
        PathState::Failed        => "Failed",
        PathState::Unknown       => "Unknown",
        PathState::Validating    => "Validating",
        PathState::ValidatingMTU => "ValidatingMTU",
        PathState::Validated     => "Validated",
    }
}

struct TestCase {
    description: &'static str,
    operation: &'static str,
    rust_result: PathState,
    lean_result: PathState,
}

fn run_tests() -> Vec<TestCase> {
    let all_states = [
        PathState::Failed,
        PathState::Unknown,
        PathState::Validating,
        PathState::ValidatingMTU,
        PathState::Validated,
    ];

    let mut cases = Vec::new();

    // 1. promote_to: all (current, new) pairs — 25 combinations
    for &current in &all_states {
        for &new in &all_states {
            cases.push(TestCase {
                description: "promote_to",
                operation: "promote_to",
                rust_result: promote_to(current, new),
                lean_result: lean_promote_to(current, new),
            });
        }
    }

    // 2. on_challenge_sent: all 5 states
    for &s in &all_states {
        cases.push(TestCase {
            description: "on_challenge_sent",
            operation: "on_challenge_sent",
            rust_result: on_challenge_sent(s),
            lean_result: lean_on_challenge_sent(s),
        });
    }

    // 3. on_response_received: all 5 states × 2 mtu_ok values = 10
    for &s in &all_states {
        for &mtu_ok in &[false, true] {
            cases.push(TestCase {
                description: if mtu_ok { "on_response_received(mtu=true)" }
                             else      { "on_response_received(mtu=false)" },
                operation: "on_response_received",
                rust_result: on_response_received(s, mtu_ok),
                lean_result: lean_on_response_received(s, mtu_ok),
            });
        }
    }

    // 4. on_failed_validation: single result
    cases.push(TestCase {
        description: "on_failed_validation",
        operation: "on_failed_validation",
        rust_result: on_failed_validation(),
        lean_result: lean_on_failed_validation(),
    });

    // 5. working predicate: all 5 states
    // (represent as Validated <-> true, Failed <-> false using sentinel states)
    for &s in &all_states {
        let rust_working = s > PathState::Failed;
        let lean_working_result = lean_working(s);
        // Encode as state for uniform comparison: Validated=working, Failed=not
        cases.push(TestCase {
            description: "working",
            operation: "working",
            rust_result: if rust_working { PathState::Validated } else { PathState::Failed },
            lean_result: if lean_working_result { PathState::Validated } else { PathState::Failed },
        });
    }

    // 6. Concrete sequence: full normal validation path
    // Unknown --(challenge_sent)--> Validating --(response,mtu=true)--> Validated
    {
        let after_challenge = on_challenge_sent(PathState::Unknown);
        let lean_after_challenge = lean_on_challenge_sent(PathState::Unknown);
        cases.push(TestCase {
            description: "seq: Unknown->challenge_sent",
            operation: "sequence",
            rust_result: after_challenge,
            lean_result: lean_after_challenge,
        });

        let after_response = on_response_received(after_challenge, true);
        let lean_after_response = lean_on_response_received(lean_after_challenge, true);
        cases.push(TestCase {
            description: "seq: Validating->response(mtu=true)",
            operation: "sequence",
            rust_result: after_response,
            lean_result: lean_after_response,
        });
    }

    // 7. MTU-only path: Unknown -> challenge -> response(mtu=false) -> ValidatingMTU
    {
        let s1 = on_challenge_sent(PathState::Unknown);
        let s2 = on_response_received(s1, false);
        let ls1 = lean_on_challenge_sent(PathState::Unknown);
        let ls2 = lean_on_response_received(ls1, false);
        cases.push(TestCase {
            description: "seq: Validating->response(mtu=false)",
            operation: "sequence",
            rust_result: s2,
            lean_result: ls2,
        });
    }

    // 8. Failed path: Unknown -> challenge -> response -> failed_validation
    {
        let s1 = on_challenge_sent(PathState::Unknown);
        let s2 = on_response_received(s1, false);
        let s3 = on_failed_validation();
        let ls1 = lean_on_challenge_sent(PathState::Unknown);
        let ls2 = lean_on_response_received(ls1, false);
        let ls3 = lean_on_failed_validation();
        cases.push(TestCase {
            description: "seq: ValidatingMTU->failed",
            operation: "sequence",
            rust_result: s3,
            lean_result: ls3,
        });
        // verify intermediate states agreed too
        let _ = (s2, ls2); // already checked above
    }

    // 9. Idempotency: promote_to(promote_to(s, t), t) == promote_to(s, t)
    for &s in &all_states {
        for &t in &all_states {
            let r1 = promote_to(s, t);
            let r2 = promote_to(r1, t);
            let l1 = lean_promote_to(s, t);
            let l2 = lean_promote_to(l1, t);
            cases.push(TestCase {
                description: "idempotency",
                operation: "promote_to idempotent",
                rust_result: r2,
                lean_result: l2,
            });
        }
    }

    cases
}

fn main() {
    println!("# PathState Route-B Correspondence Test");
    println!("# Source:   quiche/src/path.rs (PathState, promote_to, on_challenge_sent, etc.)");
    println!("# Lean model: FVSquad/PathState.lean");
    println!("#");
    println!("# idx,operation,rust_result,lean_result,status,description");

    let cases = run_tests();
    let mut pass = 0usize;
    let mut fail = 0usize;

    for (i, tc) in cases.iter().enumerate() {
        let status = if tc.rust_result == tc.lean_result { "PASS" } else { "FAIL" };
        println!("{},{},{},{},{},\"{}\"",
            i + 1,
            tc.operation,
            state_name(tc.rust_result),
            state_name(tc.lean_result),
            status,
            tc.description,
        );
        if status == "PASS" { pass += 1; } else { fail += 1; }
    }

    println!("#");
    println!("# Results: {}/{} PASS, {} FAIL", pass, pass + fail, fail);

    if fail > 0 {
        eprintln!("FAILED: {} test(s) failed", fail);
        std::process::exit(1);
    }
}
