// Copyright (C) 2025, Cloudflare, Inc.
// BSD-2-Clause licence (same as quiche)
//
// Route-B correspondence test for HyStart++ (T48).
//
// Tests that the Lean model in FVSquad/Hystart.lean faithfully captures
// the pure-computation functions from quiche/src/recovery/congestion/hystart.rs.
//
// Run from the workspace root:
//   rustc formal-verification/tests/hystart/hystart_test.rs -o /tmp/hystart_test && /tmp/hystart_test

// ─── HyStart++ constants (verbatim from hystart.rs) ─────────────────────────

const MIN_RTT_THRESH_MS: u64 = 4;   // Duration::from_millis(4)
const MAX_RTT_THRESH_MS: u64 = 16;  // Duration::from_millis(16)
const CSS_GROWTH_DIVISOR: u64 = 4;

// ─── Rust implementations (pure-functional extraction) ───────────────────────

/// Compute the RTT threshold clamp.
/// Mirrors the inline computation in Hystart::on_packet_acked (hystart.rs:143-145):
///   let rtt_thresh = cmp::max(last_round_min_rtt / 8, MIN_RTT_THRESH);
///   let rtt_thresh = cmp::min(rtt_thresh, MAX_RTT_THRESH);
fn rust_rtt_thresh(last_ms: u64) -> u64 {
    let lo = last_ms / 8;
    let clamped = lo.max(MIN_RTT_THRESH_MS);
    clamped.min(MAX_RTT_THRESH_MS)
}

/// CSS cwnd increment.
/// Mirrors Hystart::css_cwnd_inc (hystart.rs:191-193):
///   pkt_size / CSS_GROWTH_DIVISOR
fn rust_css_cwnd_inc(pkt_size: u64) -> u64 {
    pkt_size / CSS_GROWTH_DIVISOR
}

// ─── Lean model (transliterated from FVSquad/Hystart.lean) ───────────────────

/// Lean model: `def MIN_RTT_THRESH : Nat := 4`
/// Lean model: `def MAX_RTT_THRESH : Nat := 16`
/// Lean model: `def rtt_thresh (last_ms : Nat) : Nat :=`
///   `min (max (last_ms / 8) MIN_RTT_THRESH) MAX_RTT_THRESH`
fn lean_rtt_thresh(last_ms: u64) -> u64 {
    let lo = last_ms / 8;
    lo.max(MIN_RTT_THRESH_MS).min(MAX_RTT_THRESH_MS)
}

/// Lean model: `def CSS_GROWTH_DIVISOR : Nat := 4`
/// Lean model: `def css_cwnd_inc (pkt_size : Nat) : Nat :=`
///   `pkt_size / CSS_GROWTH_DIVISOR`
fn lean_css_cwnd_inc(pkt_size: u64) -> u64 {
    pkt_size / CSS_GROWTH_DIVISOR
}

// ─── Test cases ───────────────────────────────────────────────────────────────

fn main() {
    let mut passed = 0usize;
    let mut failed = 0usize;

    // Helper closure
    let mut check = |label: &str, rust: u64, lean: u64| {
        if rust == lean {
            println!("  PASS  {}: rust={} lean={}", label, rust, lean);
            passed += 1;
        } else {
            println!("  FAIL  {}: rust={} lean={}", label, rust, lean);
            failed += 1;
        }
    };

    // ─── rtt_thresh cases ────────────────────────────────────────────────────
    println!("\n=== rtt_thresh(last_ms) ===");

    // Below minimum: last_ms/8 < 4 → clamp to MIN=4
    check("last_ms=0   → 4", rust_rtt_thresh(0),  lean_rtt_thresh(0));
    check("last_ms=1   → 4", rust_rtt_thresh(1),  lean_rtt_thresh(1));
    check("last_ms=7   → 4", rust_rtt_thresh(7),  lean_rtt_thresh(7));
    check("last_ms=16  → 4", rust_rtt_thresh(16), lean_rtt_thresh(16));
    check("last_ms=23  → 4", rust_rtt_thresh(23), lean_rtt_thresh(23));
    check("last_ms=31  → 4", rust_rtt_thresh(31), lean_rtt_thresh(31));

    // In range: last_ms/8 in [4, 16] → pass-through
    check("last_ms=32  → 4",  rust_rtt_thresh(32),  lean_rtt_thresh(32));
    check("last_ms=40  → 5",  rust_rtt_thresh(40),  lean_rtt_thresh(40));
    check("last_ms=64  → 8",  rust_rtt_thresh(64),  lean_rtt_thresh(64));
    check("last_ms=80  → 10", rust_rtt_thresh(80),  lean_rtt_thresh(80));
    check("last_ms=96  → 12", rust_rtt_thresh(96),  lean_rtt_thresh(96));
    check("last_ms=128 → 16", rust_rtt_thresh(128), lean_rtt_thresh(128));

    // Above maximum: last_ms/8 > 16 → clamp to MAX=16
    check("last_ms=129 → 16", rust_rtt_thresh(129), lean_rtt_thresh(129));
    check("last_ms=160 → 16", rust_rtt_thresh(160), lean_rtt_thresh(160));
    check("last_ms=200 → 16", rust_rtt_thresh(200), lean_rtt_thresh(200));
    check("last_ms=256 → 16", rust_rtt_thresh(256), lean_rtt_thresh(256));
    check("last_ms=500 → 16", rust_rtt_thresh(500), lean_rtt_thresh(500));
    check("last_ms=1000→ 16", rust_rtt_thresh(1000), lean_rtt_thresh(1000));
    check("last_ms=9999→ 16", rust_rtt_thresh(9999), lean_rtt_thresh(9999));

    // ─── css_cwnd_inc cases ──────────────────────────────────────────────────
    println!("\n=== css_cwnd_inc(pkt_size) ===");

    check("pkt=0    → 0",    rust_css_cwnd_inc(0),    lean_css_cwnd_inc(0));
    check("pkt=1    → 0",    rust_css_cwnd_inc(1),    lean_css_cwnd_inc(1));
    check("pkt=3    → 0",    rust_css_cwnd_inc(3),    lean_css_cwnd_inc(3));
    check("pkt=4    → 1",    rust_css_cwnd_inc(4),    lean_css_cwnd_inc(4));
    check("pkt=100  → 25",   rust_css_cwnd_inc(100),  lean_css_cwnd_inc(100));
    check("pkt=1200 → 300",  rust_css_cwnd_inc(1200), lean_css_cwnd_inc(1200));
    check("pkt=1448 → 362",  rust_css_cwnd_inc(1448), lean_css_cwnd_inc(1448));
    check("pkt=9000 → 2250", rust_css_cwnd_inc(9000), lean_css_cwnd_inc(9000));

    // ─── Summary ─────────────────────────────────────────────────────────────
    println!("\n=== Summary ===");
    println!("  Passed: {}", passed);
    println!("  Failed: {}", failed);
    println!("  Total:  {}", passed + failed);

    if failed > 0 {
        eprintln!("FAIL: {} test(s) failed", failed);
        std::process::exit(1);
    } else {
        println!("PASS: {}/{} tests passed", passed, passed + failed);
    }
}
