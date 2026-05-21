// Copyright (C) 2024, Cloudflare, Inc.
// BSD license. See LICENSE for details.
//
// formal-verification/tests/varint_len/varint_len_test.rs
//
// Route-B correspondence test for T79 (VarIntLength).
//
// Runs the Rust `varint_len` implementation (verbatim from
// octets/src/lib.rs:810-822) and the Lean threshold model (transcribed
// from FVSquad/VarIntLength.lean / FVSquad/Varint.lean) on identical test
// cases and asserts they agree on all valid QUIC varint inputs.
//
// Run:
//   rustc varint_len_test.rs -o /tmp/varint_len_test && /tmp/varint_len_test

// ---------------------------------------------------------------------------
// Rust implementation (verbatim from octets/src/lib.rs:810)
// ---------------------------------------------------------------------------
const MAX_VAR_INT: u64 = 4_611_686_018_427_387_903; // 2^62 - 1

fn varint_len_rust(v: u64) -> usize {
    if v <= 63 {
        1
    } else if v <= 16_383 {
        2
    } else if v <= 1_073_741_823 {
        4
    } else if v <= MAX_VAR_INT {
        8
    } else {
        unreachable!("varint too large: {}", v)
    }
}

// ---------------------------------------------------------------------------
// Lean model (transcribed from FVSquad/Varint.lean -- varint_len_nat)
// ---------------------------------------------------------------------------
fn varint_len_lean(v: u64) -> usize {
    if v <= 63 {
        1
    } else if v <= 16_383 {
        2
    } else if v <= 1_073_741_823 {
        4
    } else {
        8
    }
}

// ---------------------------------------------------------------------------
// Test cases
// ---------------------------------------------------------------------------
struct Case {
    v: u64,
    expected: usize,
    desc: &'static str,
}

fn cases() -> Vec<Case> {
    vec![
        // Segment 1: [0, 63] -> len 1
        Case { v: 0,                         expected: 1, desc: "v=0 (min)" },
        Case { v: 1,                         expected: 1, desc: "v=1" },
        Case { v: 32,                        expected: 1, desc: "v=32 (mid seg1)" },
        Case { v: 62,                        expected: 1, desc: "v=62 (penultimate seg1)" },
        Case { v: 63,                        expected: 1, desc: "v=63 (last 1-byte)" },
        // Segment 2: [64, 16383] -> len 2
        Case { v: 64,                        expected: 2, desc: "v=64 (first 2-byte)" },
        Case { v: 65,                        expected: 2, desc: "v=65" },
        Case { v: 100,                       expected: 2, desc: "v=100" },
        Case { v: 1_000,                     expected: 2, desc: "v=1000" },
        Case { v: 8_191,                     expected: 2, desc: "v=8191 (mid seg2)" },
        Case { v: 16_382,                    expected: 2, desc: "v=16382 (penultimate seg2)" },
        Case { v: 16_383,                    expected: 2, desc: "v=16383 (last 2-byte)" },
        // Segment 3: [16384, 1073741823] -> len 4
        Case { v: 16_384,                    expected: 4, desc: "v=16384 (first 4-byte)" },
        Case { v: 16_385,                    expected: 4, desc: "v=16385" },
        Case { v: 100_000,                   expected: 4, desc: "v=100000" },
        Case { v: 1_000_000,                 expected: 4, desc: "v=1000000" },
        Case { v: 536_870_911,               expected: 4, desc: "v=536870911 (mid seg3)" },
        Case { v: 1_073_741_822,             expected: 4, desc: "v=1073741822" },
        Case { v: 1_073_741_823,             expected: 4, desc: "v=1073741823 (last 4-byte)" },
        // Segment 4: [1073741824, MAX_VAR_INT] -> len 8
        Case { v: 1_073_741_824,             expected: 8, desc: "v=1073741824 (first 8-byte)" },
        Case { v: 1_073_741_825,             expected: 8, desc: "v=1073741825" },
        Case { v: 1_000_000_000_000,         expected: 8, desc: "v=1e12" },
        Case { v: 2_305_843_009_213_693_951, expected: 8, desc: "v=2^61-1 (mid seg4)" },
        Case { v: MAX_VAR_INT - 1,           expected: 8, desc: "v=MAX_VAR_INT-1" },
        Case { v: MAX_VAR_INT,               expected: 8, desc: "v=MAX_VAR_INT" },
    ]
}

// ---------------------------------------------------------------------------
// Runner
// ---------------------------------------------------------------------------
fn main() {
    let cases = cases();
    let mut passed = 0;
    let mut failed = 0;

    println!("VarIntLength Route-B correspondence tests (T79)");
    println!("================================================");
    println!("Comparing Rust varint_len vs Lean varint_len_nat model\n");

    for c in &cases {
        let rust_result = varint_len_rust(c.v);
        let lean_result = varint_len_lean(c.v);

        let ok = rust_result == lean_result && rust_result == c.expected;
        if ok {
            passed += 1;
            println!(
                "  PASS  v={:<25} rust={} lean={} ({})",
                c.v, rust_result, lean_result, c.desc
            );
        } else {
            failed += 1;
            println!(
                "  FAIL  v={:<25} rust={} lean={} expected={} ({})",
                c.v, rust_result, lean_result, c.expected, c.desc
            );
        }
    }

    println!("\n================================================");
    println!("Result: {}/{} PASS", passed, cases.len());

    if failed > 0 {
        eprintln!("FAILED: {} test(s) did not pass", failed);
        std::process::exit(1);
    } else {
        println!("All tests PASS -- Lean model agrees with Rust on all cases.");
    }
}
