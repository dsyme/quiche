// Copyright (C) 2024, Cloudflare, Inc.
// SPDX-License-Identifier: BSD-2-Clause
//
// 🔬 Lean Squad — Route-B correspondence tests for IdleTimeout
//
// Verifies that the Lean model `idleTimeout` in
// `formal-verification/lean/FVSquad/IdleTimeout.lean` agrees with the pure
// logic extracted from `idle_timeout()` in `quiche/src/lib.rs` (line 8757).
//
// Run with:
//   rustc --edition 2021 idle_timeout_test.rs && ./idle_timeout_test
//
// Source under test:
//   quiche/src/lib.rs, fn idle_timeout (lines 8757–8788)
//
// Lean model:
//   formal-verification/lean/FVSquad/IdleTimeout.lean, def idleTimeout

/// Pure Rust extraction of the `idle_timeout()` logic.
///
/// Parameters:
///   loc     — `local_transport_params.max_idle_timeout` (milliseconds; 0 = disabled)
///   peer    — `peer_transport_params.max_idle_timeout`  (milliseconds; 0 = disabled)
///   pto_ms  — `path.recovery.pto()` expressed in milliseconds (0 = no path)
///
/// Returns `None` iff both loc and peer are 0.
/// Otherwise returns Some(max(base, 3 * pto_ms)) where
///   base = if loc == 0 { peer } else if peer == 0 { loc } else { loc.min(peer) }
fn idle_timeout_pure(loc: u64, peer: u64, pto_ms: u64) -> Option<u64> {
    if loc == 0 && peer == 0 {
        return None;
    }
    let base = if loc == 0 {
        peer
    } else if peer == 0 {
        loc
    } else {
        loc.min(peer)
    };
    let pto_3x = 3 * pto_ms;
    Some(base.max(pto_3x))
}

/// Direct translation of the Lean `idleTimeout` model.
/// (used to double-check correspondence; must agree with idle_timeout_pure)
fn lean_idle_timeout(loc: u64, peer: u64, pto: u64) -> Option<u64> {
    if loc == 0 && peer == 0 {
        return None;
    }
    let base = if loc == 0 {
        peer
    } else if peer == 0 {
        loc
    } else {
        loc.min(peer)
    };
    Some(base.max(3 * pto))
}

fn main() {
    let mut pass = 0usize;
    let mut fail = 0usize;

    macro_rules! check {
        ($desc:expr, $got:expr, $expected:expr) => {{
            let g = $got;
            let e = $expected;
            if g == e {
                pass += 1;
            } else {
                fail += 1;
                eprintln!("FAIL [{}]: got {:?}, expected {:?}", $desc, g, e);
            }
        }};
    }

    // ── Test group 1: both-zero → None ───────────────────────────────────────
    check!("both_zero_pto0",    idle_timeout_pure(0, 0, 0),    None::<u64>);
    check!("both_zero_pto100",  idle_timeout_pure(0, 0, 100),  None::<u64>);
    check!("both_zero_pto1000", idle_timeout_pure(0, 0, 1000), None::<u64>);

    // ── Test group 2: loc zero, peer nonzero ──────────────────────────────────
    check!("loc0_peer3000_pto0",   idle_timeout_pure(0, 3000, 0),   Some(3000));
    check!("loc0_peer3000_pto100", idle_timeout_pure(0, 3000, 100), Some(3000));
    // 3 * 1500 = 4500 > 3000
    check!("loc0_peer3000_pto1500", idle_timeout_pure(0, 3000, 1500), Some(4500));
    // 3 * 1000 = 3000 = peer → Some(3000)
    check!("loc0_peer3000_pto1000", idle_timeout_pure(0, 3000, 1000), Some(3000));
    check!("loc0_peer1_pto0",    idle_timeout_pure(0, 1, 0),    Some(1));
    check!("loc0_peer1_pto1",    idle_timeout_pure(0, 1, 1),    Some(3));

    // ── Test group 3: peer zero, loc nonzero ──────────────────────────────────
    check!("peer0_loc5000_pto0",    idle_timeout_pure(5000, 0, 0),    Some(5000));
    check!("peer0_loc5000_pto100",  idle_timeout_pure(5000, 0, 100),  Some(5000));
    // 3 * 2000 = 6000 > 5000
    check!("peer0_loc5000_pto2000", idle_timeout_pure(5000, 0, 2000), Some(6000));
    check!("peer0_loc1_pto0",    idle_timeout_pure(1, 0, 0),    Some(1));
    check!("peer0_loc1_pto1",    idle_timeout_pure(1, 0, 1),    Some(3));

    // ── Test group 4: both nonzero, no PTO clamping ───────────────────────────
    check!("both_5000_3000_pto0", idle_timeout_pure(5000, 3000, 0), Some(3000));
    check!("both_3000_5000_pto0", idle_timeout_pure(3000, 5000, 0), Some(3000));
    check!("both_equal_pto0",     idle_timeout_pure(4000, 4000, 0), Some(4000));
    check!("both_1_1_pto0",       idle_timeout_pure(1, 1, 0),       Some(1));

    // ── Test group 5: both nonzero, PTO clamping active ───────────────────────
    // min(5000, 3000) = 3000; 3 * 2000 = 6000 > 3000
    check!("both_5000_3000_pto2000", idle_timeout_pure(5000, 3000, 2000), Some(6000));
    // min(1000, 2000) = 1000; 3 * 500 = 1500 > 1000
    check!("both_1000_2000_pto500",  idle_timeout_pure(1000, 2000, 500),  Some(1500));
    // min(1000, 2000) = 1000; 3 * 333 = 999 < 1000
    check!("both_1000_2000_pto333",  idle_timeout_pure(1000, 2000, 333),  Some(1000));
    // min(100, 200) = 100; 3 * 40 = 120 > 100
    check!("both_100_200_pto40",     idle_timeout_pure(100, 200, 40),     Some(120));

    // ── Test group 6: commutativity (loc/peer swap gives same result) ─────────
    let cases = [(5000u64, 3000u64, 0u64), (1000, 2000, 500), (0, 1000, 0), (1000, 0, 200)];
    for (loc, peer, pto) in cases {
        let fwd = idle_timeout_pure(loc, peer, pto);
        let rev = idle_timeout_pure(peer, loc, pto);
        check!(format!("commute ({loc},{peer},{pto})"), fwd, rev);
    }

    // ── Test group 7: Lean model agrees with Rust extraction ─────────────────
    let test_vectors: &[(u64, u64, u64)] = &[
        (0, 0, 0), (0, 0, 100),
        (0, 3000, 0), (0, 3000, 100), (0, 3000, 1500),
        (5000, 0, 0), (5000, 0, 2000),
        (5000, 3000, 0), (3000, 5000, 500),
        (1, 1, 0), (1, 1, 1), (1, 2, 1),
    ];
    for &(loc, peer, pto) in test_vectors {
        let rust_val = idle_timeout_pure(loc, peer, pto);
        let lean_val = lean_idle_timeout(loc, peer, pto);
        check!(format!("lean_agree ({loc},{peer},{pto})"), rust_val, lean_val);
    }

    // ── Summary ───────────────────────────────────────────────────────────────
    println!("{}/{} tests passed", pass, pass + fail);
    if fail > 0 {
        std::process::exit(1);
    }
}
