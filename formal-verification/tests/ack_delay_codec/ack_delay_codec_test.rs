// Copyright (C) 2018-2025, Cloudflare, Inc.
// All rights reserved.
//
// SPDX-License-Identifier: BSD-2-Clause
//
// formal-verification/tests/ack_delay_codec/ack_delay_codec_test.rs
//
// Route-B correspondence test — Rust side.
// Computes the AckDelay encode/decode arithmetic from the Rust implementation
// (quiche/src/lib.rs ~L4490, ~L8178) and prints results in CSV format.
//
// Standalone binary — no quiche dependency needed (just pure arithmetic).
//
// Build and run:
//   rustc ack_delay_codec_test.rs -o ack_delay_test && ./ack_delay_test

/// Encode ACK delay: divide raw microsecond value by 2^exp.
/// Mirrors: ack_delay.as_micros() as u64 / 2u64.pow(ack_delay_exponent)
fn encode(delay_micros: u64, exp: u32) -> u64 {
    delay_micros / 2u64.pow(exp)
}

/// Decode ACK delay: multiply wire value by 2^exp.
/// Mirrors: ack_delay.checked_mul(2u64.pow(ack_delay_exponent))
/// Note: checked_mul returns None on overflow; we use saturating_mul for
/// safety in the test harness. The Lean model uses unbounded Nat.
fn decode(encoded: u64, exp: u32) -> u64 {
    encoded.saturating_mul(2u64.pow(exp))
}

fn main() {
    let cases: Vec<(u64, u32, &str)> = vec![
        // exp = 0: encode/decode are identity
        (0, 0, "exp=0 delay=0"),
        (1, 0, "exp=0 delay=1"),
        (1000, 0, "exp=0 delay=1000"),
        (65535, 0, "exp=0 delay=65535"),

        // exp = 1
        (0, 1, "exp=1 delay=0"),
        (1, 1, "exp=1 delay=1 (truncated)"),
        (2, 1, "exp=1 delay=2 (exact)"),
        (1000, 1, "exp=1 delay=1000"),
        (1001, 1, "exp=1 delay=1001 (truncated)"),

        // exp = 2
        (0, 2, "exp=2 delay=0"),
        (3, 2, "exp=2 delay=3 (truncated)"),
        (4, 2, "exp=2 delay=4 (exact)"),
        (100, 2, "exp=2 delay=100"),
        (101, 2, "exp=2 delay=101 (truncated)"),

        // exp = 3 (QUIC default)
        (0, 3, "exp=3 delay=0"),
        (7, 3, "exp=3 delay=7 (truncated)"),
        (8, 3, "exp=3 delay=8 (exact)"),
        (1000, 3, "exp=3 delay=1000 (exact: 1000/8=125)"),
        (1001, 3, "exp=3 delay=1001 (truncated)"),
        (25000, 3, "exp=3 delay=25ms in micros"),

        // exp = 10
        (0, 10, "exp=10 delay=0"),
        (1023, 10, "exp=10 delay=1023 (truncated)"),
        (1024, 10, "exp=10 delay=1024 (exact)"),
        (100000, 10, "exp=10 delay=100000"),

        // exp = 20 (maximum)
        (0, 20, "exp=20 delay=0"),
        (1048575, 20, "exp=20 delay=2^20-1 (truncated)"),
        (1048576, 20, "exp=20 delay=2^20 (exact)"),
        (1000000000000, 20, "exp=20 large delay"),

        // Round-trip cases
        (800, 3, "RT exp=3 delay=800 (multiple of 8)"),
        (1600, 4, "RT exp=4 delay=1600 (multiple of 16)"),
        (3072, 6, "RT exp=6 delay=3072 (multiple of 64)"),
    ];

    println!("# Rust AckDelayCodec evaluation");
    println!("# delay_micros,exp,rust_encoded,rust_decoded_rt,description");
    for (delay, exp, desc) in &cases {
        let enc = encode(*delay, *exp);
        let dec = decode(enc, *exp);
        println!("{},{},{},{},\"{}\"", delay, exp, enc, dec, desc);
    }
    println!("# Total cases: {}", cases.len());
}
