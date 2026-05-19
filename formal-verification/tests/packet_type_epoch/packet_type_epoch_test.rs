// Copyright (C) 2018-2026, Cloudflare, Inc.
// All rights reserved.
//
// SPDX-License-Identifier: BSD-2-Clause
//
// 🔬 Lean Squad — Route-B correspondence test for T74: PacketTypeEpoch.
//
// Tests that the Rust `from_epoch` / `to_epoch` implementation in
// `quiche/src/packet.rs` matches the Lean model in
// `formal-verification/lean/FVSquad/PacketTypeEpoch.lean`.
//
// The Lean model is purely functional with no dependencies on any build
// system; the tests here directly replicate its logic in Rust and compare
// the two side-by-side on every possible input.

// ── Minimal mirror of quiche's packet types ──────────────────────────────

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Epoch {
    Initial,
    Handshake,
    Application,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Type {
    Initial,
    Retry,
    Handshake,
    ZeroRTT,
    VersionNegotiation,
    Short,
}

// ── Rust implementation (verbatim from quiche/src/packet.rs) ─────────────

fn from_epoch(e: Epoch) -> Type {
    match e {
        Epoch::Initial => Type::Initial,
        Epoch::Handshake => Type::Handshake,
        Epoch::Application => Type::Short,
    }
}

fn to_epoch(t: Type) -> Option<Epoch> {
    match t {
        Type::Initial => Some(Epoch::Initial),
        Type::ZeroRTT => Some(Epoch::Application),
        Type::Handshake => Some(Epoch::Handshake),
        Type::Short => Some(Epoch::Application),
        _ => None,
    }
}

// ── Lean model (mirror in Rust) ───────────────────────────────────────────

fn lean_from_epoch(e: Epoch) -> Type {
    match e {
        Epoch::Initial => Type::Initial,
        Epoch::Handshake => Type::Handshake,
        Epoch::Application => Type::Short,
    }
}

fn lean_to_epoch(t: Type) -> Option<Epoch> {
    match t {
        Type::Initial => Some(Epoch::Initial),
        Type::ZeroRTT => Some(Epoch::Application),
        Type::Handshake => Some(Epoch::Handshake),
        Type::Short => Some(Epoch::Application),
        Type::Retry => None,
        Type::VersionNegotiation => None,
    }
}

// ── Test runner ──────────────────────────────────────────────────────────

struct TestResult {
    passed: u32,
    failed: u32,
}

impl TestResult {
    fn new() -> Self {
        TestResult {
            passed: 0,
            failed: 0,
        }
    }

    fn check(&mut self, name: &str, ok: bool) {
        if ok {
            self.passed += 1;
            println!("  PASS  {name}");
        } else {
            self.failed += 1;
            println!("  FAIL  {name}");
        }
    }
}

// ── Test groups ──────────────────────────────────────────────────────────

/// Group 1: Rust ↔ Lean model agreement on `from_epoch` for all 3 epochs.
fn test_from_epoch_agreement(r: &mut TestResult) {
    println!("\n[Group 1] from_epoch: Rust ↔ Lean model");
    for e in [Epoch::Initial, Epoch::Handshake, Epoch::Application] {
        let rust_val = from_epoch(e);
        let lean_val = lean_from_epoch(e);
        r.check(
            &format!("from_epoch({e:?}) rust={rust_val:?} lean={lean_val:?}"),
            rust_val == lean_val,
        );
    }
}

/// Group 2: Rust ↔ Lean model agreement on `to_epoch` for all 6 types.
fn test_to_epoch_agreement(r: &mut TestResult) {
    println!("\n[Group 2] to_epoch: Rust ↔ Lean model");
    let all_types = [
        Type::Initial,
        Type::Retry,
        Type::Handshake,
        Type::ZeroRTT,
        Type::VersionNegotiation,
        Type::Short,
    ];
    for t in all_types {
        let rust_val = to_epoch(t);
        let lean_val = lean_to_epoch(t);
        r.check(
            &format!("to_epoch({t:?}) rust={rust_val:?} lean={lean_val:?}"),
            rust_val == lean_val,
        );
    }
}

/// Group 3: Round-trip `from_epoch ∘ to_epoch = id` (Lean theorem
/// `from_epoch_to_epoch`).
fn test_round_trip_from_to(r: &mut TestResult) {
    println!("\n[Group 3] from_epoch_to_epoch round-trip");
    for e in [Epoch::Initial, Epoch::Handshake, Epoch::Application] {
        let recovered = to_epoch(from_epoch(e));
        r.check(
            &format!("to_epoch(from_epoch({e:?})) = Some({e:?})"),
            recovered == Some(e),
        );
    }
}

/// Group 4: `to_epoch ∘ from_epoch` on the image of `from_epoch`
/// (Lean theorem `to_epoch_from_epoch`).
fn test_round_trip_to_from(r: &mut TestResult) {
    println!("\n[Group 4] to_epoch_from_epoch round-trip on image of from_epoch");
    // image of from_epoch = {Initial, Handshake, Short}
    let cases: &[(Type, Epoch)] = &[
        (Type::Initial, Epoch::Initial),
        (Type::Handshake, Epoch::Handshake),
        (Type::Short, Epoch::Application),
    ];
    for &(t, expected) in cases {
        r.check(
            &format!("to_epoch(from_epoch(e)={t:?}) = Some({expected:?})"),
            to_epoch(t) == Some(expected),
        );
    }
}

/// Group 5: `Short` and `ZeroRTT` share the Application epoch
/// (Lean theorem `short_and_zeroRTT_same_epoch`).
fn test_short_and_zerortt_same_epoch(r: &mut TestResult) {
    println!("\n[Group 5] Short and ZeroRTT share Application epoch");
    r.check(
        "to_epoch(Short) = to_epoch(ZeroRTT)",
        to_epoch(Type::Short) == to_epoch(Type::ZeroRTT),
    );
    r.check(
        "to_epoch(Short) = Some(Application)",
        to_epoch(Type::Short) == Some(Epoch::Application),
    );
    r.check(
        "to_epoch(ZeroRTT) = Some(Application)",
        to_epoch(Type::ZeroRTT) == Some(Epoch::Application),
    );
}

/// Group 6: `Retry` and `VersionNegotiation` have no epoch
/// (Lean theorems `retry_no_epoch`, `versionNegotiation_no_epoch`).
fn test_no_epoch_types(r: &mut TestResult) {
    println!("\n[Group 6] Retry and VersionNegotiation have no epoch");
    r.check("to_epoch(Retry) = None", to_epoch(Type::Retry).is_none());
    r.check(
        "to_epoch(VersionNegotiation) = None",
        to_epoch(Type::VersionNegotiation).is_none(),
    );
}

/// Group 7: `from_epoch` injectivity (Lean theorem `from_epoch_injective`).
fn test_from_epoch_injective(r: &mut TestResult) {
    println!("\n[Group 7] from_epoch injectivity");
    let epochs = [Epoch::Initial, Epoch::Handshake, Epoch::Application];
    for i in 0..3 {
        for j in 0..3 {
            let t1 = from_epoch(epochs[i]);
            let t2 = from_epoch(epochs[j]);
            if i == j {
                r.check(
                    &format!("from_epoch({:?}) = from_epoch({:?})", epochs[i], epochs[j]),
                    t1 == t2,
                );
            } else {
                r.check(
                    &format!(
                        "from_epoch({:?}) ≠ from_epoch({:?})",
                        epochs[i], epochs[j]
                    ),
                    t1 != t2,
                );
            }
        }
    }
}

/// Group 8: Exact values of `from_epoch` and `to_epoch`.
fn test_exact_values(r: &mut TestResult) {
    println!("\n[Group 8] Exact value checks");
    r.check("from_epoch(Initial) = Initial", from_epoch(Epoch::Initial) == Type::Initial);
    r.check(
        "from_epoch(Handshake) = Handshake",
        from_epoch(Epoch::Handshake) == Type::Handshake,
    );
    r.check(
        "from_epoch(Application) = Short",
        from_epoch(Epoch::Application) == Type::Short,
    );
    r.check(
        "to_epoch(Initial) = Some(Initial)",
        to_epoch(Type::Initial) == Some(Epoch::Initial),
    );
    r.check(
        "to_epoch(Handshake) = Some(Handshake)",
        to_epoch(Type::Handshake) == Some(Epoch::Handshake),
    );
    r.check(
        "to_epoch(Short) = Some(Application)",
        to_epoch(Type::Short) == Some(Epoch::Application),
    );
    r.check(
        "to_epoch(ZeroRTT) = Some(Application)",
        to_epoch(Type::ZeroRTT) == Some(Epoch::Application),
    );
}

/// Group 9: Exhaustive epoch-bearing classification
/// (Lean theorem `to_epoch_exhaustive` / `hasEpoch_iff`).
fn test_exhaustive_classification(r: &mut TestResult) {
    println!("\n[Group 9] Exhaustive epoch-bearing classification");
    let epoch_bearing = [Type::Initial, Type::Handshake, Type::ZeroRTT, Type::Short];
    let non_epoch_bearing = [Type::Retry, Type::VersionNegotiation];
    for t in epoch_bearing {
        r.check(
            &format!("to_epoch({t:?}).is_some()"),
            to_epoch(t).is_some(),
        );
    }
    for t in non_epoch_bearing {
        r.check(
            &format!("to_epoch({t:?}).is_none()"),
            to_epoch(t).is_none(),
        );
    }
}

// ── main ─────────────────────────────────────────────────────────────────

fn main() {
    println!("=== T74 PacketTypeEpoch Route-B Correspondence Tests ===");
    let mut r = TestResult::new();

    test_from_epoch_agreement(&mut r);
    test_to_epoch_agreement(&mut r);
    test_round_trip_from_to(&mut r);
    test_round_trip_to_from(&mut r);
    test_short_and_zerortt_same_epoch(&mut r);
    test_no_epoch_types(&mut r);
    test_from_epoch_injective(&mut r);
    test_exact_values(&mut r);
    test_exhaustive_classification(&mut r);

    println!("\n=== Results: {}/{} PASS ===", r.passed, r.passed + r.failed);
    if r.failed > 0 {
        eprintln!("FAILED: {} tests failed", r.failed);
        std::process::exit(1);
    }
}
