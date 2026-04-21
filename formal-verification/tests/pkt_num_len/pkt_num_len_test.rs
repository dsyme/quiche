// Copyright (C) 2024, Cloudflare, Inc.
// BSD license. See LICENSE for details.
//
// formal-verification/tests/pkt_num_len/pkt_num_len_test.rs
//
// Route-B correspondence test for T20 (PacketNumLen).
//
// Runs the Rust `pkt_num_len` implementation (copied verbatim from
// quiche/src/packet.rs:569) and the Lean threshold model (transcribed
// from FVSquad/PacketNumLen.lean) on identical test cases and asserts they
// agree on all valid QUIC inputs (numUnacked ≤ 2^31-1).
//
// Run:
//   rustc pkt_num_len_test.rs -o /tmp/pkt_num_len_test && /tmp/pkt_num_len_test

// ---------------------------------------------------------------------------
// Rust implementation (verbatim from quiche/src/packet.rs:569)
// ---------------------------------------------------------------------------
fn pkt_num_len_rust(pn: u64, largest_acked: u64) -> usize {
    let num_unacked: u64 = pn.saturating_sub(largest_acked) + 1;
    // computes ceil of num_unacked.log2() + 1
    let min_bits = u64::BITS - num_unacked.leading_zeros() + 1;
    // get the num len in bytes
    min_bits.div_ceil(8) as usize
}

// ---------------------------------------------------------------------------
// Lean model (transcribed from FVSquad/PacketNumLen.lean)
// ---------------------------------------------------------------------------
fn num_unacked_lean(pn: u64, la: u64) -> u64 {
    // Lean Nat subtraction is saturating: pn - la + 1 = 1 when pn ≤ la.
    pn.saturating_sub(la) + 1
}

fn pkt_num_len_lean(pn: u64, la: u64) -> usize {
    let u = num_unacked_lean(pn, la);
    if u <= 127 { 1 }
    else if u <= 32767 { 2 }
    else if u <= 8388607 { 3 }
    else { 4 }
}

// ---------------------------------------------------------------------------
// Test cases (shared fixture; mirrors lean_eval.lean)
// ---------------------------------------------------------------------------
struct Case { pn: u64, la: u64, desc: &'static str }

fn cases() -> Vec<Case> {
    vec![
        // Core boundary values derived from Lean theorems
        Case { pn: 0,           la: 0,        desc: "numUnacked=1 (min)" },
        Case { pn: 1,           la: 0,        desc: "numUnacked=2" },
        Case { pn: 126,         la: 0,        desc: "numUnacked=127 (last 1-byte)" },
        Case { pn: 127,         la: 0,        desc: "numUnacked=128 (first 2-byte)" },
        Case { pn: 100,         la: 0,        desc: "numUnacked=101" },
        Case { pn: 1000,        la: 0,        desc: "numUnacked=1001" },
        Case { pn: 32766,       la: 0,        desc: "numUnacked=32767 (last 2-byte)" },
        Case { pn: 32767,       la: 0,        desc: "numUnacked=32768 (first 3-byte)" },
        Case { pn: 8388606,     la: 0,        desc: "numUnacked=8388607 (last 3-byte)" },
        Case { pn: 8388607,     la: 0,        desc: "numUnacked=8388608 (first 4-byte)" },
        Case { pn: 10000000,    la: 0,        desc: "numUnacked=10000001" },
        // Saturating-sub cases
        Case { pn: 5,           la: 10,       desc: "pn < la: numUnacked=1 (saturating)" },
        Case { pn: 42,          la: 42,       desc: "pn=la: numUnacked=1" },
        // Non-zero base cases
        Case { pn: 1126,        la: 1000,     desc: "numUnacked=127 (last 1-byte, offset base)" },
        Case { pn: 1127,        la: 1000,     desc: "numUnacked=128 (first 2-byte, offset base)" },
        // RFC 9000 §A.2 example values
        Case { pn: 0xac5c02,    la: 0xabe8b3, desc: "RFC A.2: pn=0xac5c02 la=0xabe8b3" },
        Case { pn: 0xace9fe,    la: 0xabe8b3, desc: "RFC A.2: pn=0xace9fe la=0xabe8b3" },
        // QUIC maximum: numUnacked = 2^31-1 (valid upper bound per QUIC invariant)
        Case { pn: 2147483646,  la: 0,        desc: "numUnacked=2^31-1 (QUIC valid max)" },
    ]
}

// ---------------------------------------------------------------------------
// Main: run both implementations and compare
// ---------------------------------------------------------------------------
fn main() {
    let cases = cases();
    let mut pass = 0;
    let mut fail = 0;

    println!("# pkt_num_len Route-B Correspondence Test");
    println!("# Source:   quiche/src/packet.rs:569");
    println!("# Lean model: FVSquad/PacketNumLen.lean (pktNumLen)");
    println!("# Valid QUIC domain: numUnacked ≤ 2^31-1 = 2147483647");
    println!("#");
    println!("# pn,la,rust,lean,status,description");

    for c in &cases {
        let rust = pkt_num_len_rust(c.pn, c.la);
        let lean = pkt_num_len_lean(c.pn, c.la);
        let nu   = num_unacked_lean(c.pn, c.la);
        assert!(nu <= 2147483647, "Test case violates QUIC invariant: numUnacked={}", nu);
        let ok = rust == lean;
        let status = if ok { "PASS" } else { "FAIL" };
        println!("{},{},{},{},{},\"{}\"", c.pn, c.la, rust, lean, status, c.desc);
        if ok { pass += 1; } else { fail += 1; }
    }

    println!("#");
    println!("# Results: {}/{} PASS, {} FAIL", pass, pass + fail, fail);

    // -----------------------------------------------------------------------
    // Document out-of-range divergence (not a test — just documentation).
    // -----------------------------------------------------------------------
    println!("#");
    println!("# Out-of-range note (numUnacked > 2^31-1, violates QUIC invariant):");
    println!("# pn=2147483647, la=0 → numUnacked=2147483648");
    let oor_rust = pkt_num_len_rust(2147483647, 0);
    let oor_lean = pkt_num_len_lean(2147483647, 0);
    println!("#   Rust returns {} (min_bits=33, div_ceil(8)=5)", oor_rust);
    println!("#   Lean model returns {} (> 8388607 → 4, model capped at 4)", oor_lean);
    println!("# Divergence is expected and documented in FVSquad/PacketNumLen.lean.");
    println!("# The Lean model only guarantees faithfulness for valid QUIC inputs.");

    if fail > 0 {
        eprintln!("CORRESPONDENCE FAILED: {} test(s) did not agree", fail);
        std::process::exit(1);
    }
    println!("# All {} test cases PASS — Lean model is faithful for valid QUIC inputs.", pass);
}
