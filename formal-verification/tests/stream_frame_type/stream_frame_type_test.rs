// Copyright (C) 2024, Cloudflare, Inc.
// SPDX-License-Identifier: BSD-2-Clause
//
// 🔬 Lean Squad — Route-B correspondence tests for T61: StreamFrameType
//
// This file tests that the Lean model `streamTypeByte` agrees with the
// Rust `encode_stream_header` type-byte computation on all relevant inputs.
//
// Run with:  rustc --edition 2021 stream_frame_type_test.rs && ./stream_frame_type_test
//
// Source under test:
//   quiche/src/frame.rs, encode_stream_header (lines 1326-1350)
//
// Lean model:
//   formal-verification/lean/FVSquad/StreamFrameType.lean, streamTypeByte

/// Pure Rust model of the type-byte computation from `encode_stream_header`.
/// This mirrors the bit-OR sequence exactly.
fn stream_type_byte(fin: bool) -> u8 {
    let mut ty: u8 = 0x08;
    ty |= 0x04; // OFF flag — always set
    ty |= 0x02; // LEN flag — always set
    if fin {
        ty |= 0x01;
    }
    ty
}

/// Lean model (hard-coded expected values from `decide`-closed proofs).
fn lean_stream_type_byte(fin: bool) -> u8 {
    if fin { 0x0F } else { 0x0E }
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

    // ── Test 1-2: Basic values match Lean model ───────────────────────────────
    for &fin in &[false, true] {
        let rust_byte = stream_type_byte(fin);
        let lean_byte = lean_stream_type_byte(fin);
        check!(format!("value_match fin={fin}"), rust_byte, lean_byte);
    }

    // ── Test 3-4: Exact byte values (streamTypeByte_def_false/true) ───────────
    check!("def_false", stream_type_byte(false), 0x0E);
    check!("def_true",  stream_type_byte(true),  0x0F);

    // ── Test 5-6: STREAM base flag 0x08 always set ────────────────────────────
    for &fin in &[false, true] {
        check!(
            format!("base_set fin={fin}"),
            stream_type_byte(fin) & 0x08,
            0x08
        );
    }

    // ── Test 7-8: OFF flag 0x04 always set ────────────────────────────────────
    for &fin in &[false, true] {
        check!(
            format!("off_set fin={fin}"),
            stream_type_byte(fin) & 0x04,
            0x04
        );
    }

    // ── Test 9-10: LEN flag 0x02 always set ───────────────────────────────────
    for &fin in &[false, true] {
        check!(
            format!("len_set fin={fin}"),
            stream_type_byte(fin) & 0x02,
            0x02
        );
    }

    // ── Test 11-12: FIN flag 0x01 iff fin ────────────────────────────────────
    check!("fin_flag_false", stream_type_byte(false) & 0x01, 0x00);
    check!("fin_flag_true",  stream_type_byte(true)  & 0x01, 0x01);

    // ── Test 13: Not bare STREAM byte ────────────────────────────────────────
    for &fin in &[false, true] {
        assert_ne!(stream_type_byte(fin), 0x08,
            "type byte must not equal bare STREAM 0x08 (fin={fin})");
        pass += 1;
    }

    // ── Test 14: Injectivity — different fin → different byte ─────────────────
    check!("ne", stream_type_byte(false) == stream_type_byte(true), false);

    // ── Test 15-16: In STREAM type range [0x08, 0x0F] ────────────────────────
    for &fin in &[false, true] {
        let b = stream_type_byte(fin);
        let in_range = b >= 0x08 && b <= 0x0F;
        check!(format!("range fin={fin}"), in_range, true);
    }

    // ── Test 17-18: FIN bit recovery round-trip ───────────────────────────────
    for &fin in &[false, true] {
        let b = stream_type_byte(fin);
        let recovered_fin = (b & 0x01) == 0x01;
        check!(format!("decode_fin fin={fin}"), recovered_fin, fin);
    }

    // ── Summary ───────────────────────────────────────────────────────────────
    println!("{} / {} PASS", pass, pass + fail);
    if fail > 0 {
        std::process::exit(1);
    }
}
