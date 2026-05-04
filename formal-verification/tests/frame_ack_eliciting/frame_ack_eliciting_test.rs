// Copyright (C) 2025, Cloudflare, Inc.
// BSD-2-Clause licence (same as quiche)
//
// Route-B correspondence test for FrameAckEliciting (T42).
//
// Tests that the Lean model in FVSquad/FrameAckEliciting.lean faithfully
// captures the Rust `Frame::ack_eliciting` and `Frame::probing` predicates
// from quiche/src/frame.rs.
//
// The Lean model defines an abstract `FrameKind` enum with 23 variants and
// two boolean functions `ackEliciting` and `probing`.
//
// Run:
//   rustc frame_ack_eliciting_test.rs -o /tmp/fae_test && /tmp/fae_test

// ─── Abstract frame kind (mirrors Lean's FrameKind enum) ─────────────────────

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum FrameKind {
    Padding,
    Ping,
    ACK,
    ResetStream,
    StopSending,
    Crypto,
    NewToken,
    Stream,
    MaxData,
    MaxStreamData,
    MaxStreamsBidi,
    MaxStreamsUni,
    DataBlocked,
    StreamDataBlocked,
    StreamsBlockedBidi,
    StreamsBlockedUni,
    NewConnectionId,
    RetireConnectionId,
    PathChallenge,
    PathResponse,
    ConnectionClose,
    ApplicationClose,
    Datagram,
}

const ALL_KINDS: &[FrameKind] = &[
    FrameKind::Padding,
    FrameKind::Ping,
    FrameKind::ACK,
    FrameKind::ResetStream,
    FrameKind::StopSending,
    FrameKind::Crypto,
    FrameKind::NewToken,
    FrameKind::Stream,
    FrameKind::MaxData,
    FrameKind::MaxStreamData,
    FrameKind::MaxStreamsBidi,
    FrameKind::MaxStreamsUni,
    FrameKind::DataBlocked,
    FrameKind::StreamDataBlocked,
    FrameKind::StreamsBlockedBidi,
    FrameKind::StreamsBlockedUni,
    FrameKind::NewConnectionId,
    FrameKind::RetireConnectionId,
    FrameKind::PathChallenge,
    FrameKind::PathResponse,
    FrameKind::ConnectionClose,
    FrameKind::ApplicationClose,
    FrameKind::Datagram,
];

// ─── Rust model: inline `ack_eliciting` and `probing` ────────────────────────
//
// Mirrors Frame::ack_eliciting (quiche/src/frame.rs:814-823) and
// Frame::probing (quiche/src/frame.rs:825-833).
//
// CryptoHeader, StreamHeader, DatagramHeader are not in the Lean enum because
// they have the same ack-eliciting / probing behaviour as Crypto, Stream, and
// Datagram respectively (they fall through to the default `true`/`false` arms
// in both `!matches!` patterns).

fn rust_ack_eliciting(k: FrameKind) -> bool {
    !matches!(
        k,
        FrameKind::Padding
            | FrameKind::ACK
            | FrameKind::ApplicationClose
            | FrameKind::ConnectionClose
    )
}

fn rust_probing(k: FrameKind) -> bool {
    matches!(
        k,
        FrameKind::Padding
            | FrameKind::NewConnectionId
            | FrameKind::PathChallenge
            | FrameKind::PathResponse
    )
}

// ─── Lean model: transliterated from FVSquad/FrameAckEliciting.lean ──────────
//
// def ackEliciting (k : FrameKind) : Bool
// def probing      (k : FrameKind) : Bool

fn lean_ack_eliciting(k: FrameKind) -> bool {
    !matches!(
        k,
        FrameKind::Padding
            | FrameKind::ACK
            | FrameKind::ApplicationClose
            | FrameKind::ConnectionClose
    )
}

fn lean_probing(k: FrameKind) -> bool {
    matches!(
        k,
        FrameKind::Padding
            | FrameKind::NewConnectionId
            | FrameKind::PathChallenge
            | FrameKind::PathResponse
    )
}

// ─── Test harness ─────────────────────────────────────────────────────────────

fn main() {
    let mut passed = 0usize;
    let mut failed = 0usize;

    println!("=== Route-B Correspondence Tests: FrameAckEliciting (T42) ===\n");
    println!("{:<22} {:>15} {:>15} {:>15} {:>15} {:>8}",
        "FrameKind", "rust_eliciting", "lean_eliciting", "rust_probing", "lean_probing", "result");
    println!("{}", "-".repeat(95));

    for &k in ALL_KINDS {
        let re = rust_ack_eliciting(k);
        let le = lean_ack_eliciting(k);
        let rp = rust_probing(k);
        let lp = lean_probing(k);

        let ok = re == le && rp == lp;
        if ok {
            passed += 1;
        } else {
            failed += 1;
        }

        let result = if ok { "PASS" } else { "FAIL" };
        println!("{:<22} {:>15} {:>15} {:>15} {:>15} {:>8}",
            format!("{:?}", k), re, le, rp, lp, result);
    }

    // Additional property checks (mirrors theorems in FrameAckEliciting.lean)

    println!("\n=== Property checks ===");

    // T1: ackEliciting_false_iff — exactly the four non-eliciting kinds
    let non_eliciting: Vec<FrameKind> = ALL_KINDS.iter().copied()
        .filter(|&k| !lean_ack_eliciting(k)).collect();
    let expected_non_eliciting = vec![
        FrameKind::Padding, FrameKind::ACK,
        FrameKind::ConnectionClose, FrameKind::ApplicationClose,
    ];
    let prop1 = non_eliciting == expected_non_eliciting;
    println!("[T1] non-eliciting set = {{Padding,ACK,AppClose,ConnClose}}: {}",
        if prop1 { "PASS" } else { "FAIL" });
    if prop1 { passed += 1; } else { failed += 1; }

    // T2: probing_true_iff — exactly the four probing kinds
    let probing_kinds: Vec<FrameKind> = ALL_KINDS.iter().copied()
        .filter(|&k| lean_probing(k)).collect();
    let expected_probing = vec![
        FrameKind::Padding, FrameKind::NewConnectionId,
        FrameKind::PathChallenge, FrameKind::PathResponse,
    ];
    let prop2 = probing_kinds == expected_probing;
    println!("[T2] probing set = {{Padding,NewConnId,PathChal,PathResp}}: {}",
        if prop2 { "PASS" } else { "FAIL" });
    if prop2 { passed += 1; } else { failed += 1; }

    // T3: ackEliciting_true_or_padding — Ping is ack-eliciting
    let prop3 = lean_ack_eliciting(FrameKind::Ping);
    println!("[T3] Ping is ack-eliciting: {}",
        if prop3 { "PASS" } else { "FAIL" });
    if prop3 { passed += 1; } else { failed += 1; }

    // T4: ACK not ack-eliciting
    let prop4 = !lean_ack_eliciting(FrameKind::ACK);
    println!("[T4] ACK is not ack-eliciting: {}",
        if prop4 { "PASS" } else { "FAIL" });
    if prop4 { passed += 1; } else { failed += 1; }

    // T5: PathChallenge is probing
    let prop5 = lean_probing(FrameKind::PathChallenge);
    println!("[T5] PathChallenge is probing: {}",
        if prop5 { "PASS" } else { "FAIL" });
    if prop5 { passed += 1; } else { failed += 1; }

    // T6: Ping is NOT probing
    let prop6 = !lean_probing(FrameKind::Ping);
    println!("[T6] Ping is not probing: {}",
        if prop6 { "PASS" } else { "FAIL" });
    if prop6 { passed += 1; } else { failed += 1; }

    // T7: Padding is both non-eliciting AND probing
    let prop7 = !lean_ack_eliciting(FrameKind::Padding) && lean_probing(FrameKind::Padding);
    println!("[T7] Padding is non-eliciting AND probing: {}",
        if prop7 { "PASS" } else { "FAIL" });
    if prop7 { passed += 1; } else { failed += 1; }

    // T8: all ack-eliciting types
    let eliciting_count = ALL_KINDS.iter().filter(|&&k| lean_ack_eliciting(k)).count();
    let prop8 = eliciting_count == 19; // 23 total - 4 non-eliciting
    let t8_msg = if prop8 { "PASS".to_string() } else { format!("FAIL (got {})", eliciting_count) };
    println!("[T8] exactly 19 ack-eliciting kinds (of 23): {}", t8_msg);
    if prop8 { passed += 1; } else { failed += 1; }

    // T9: exactly 4 probing kinds
    let probing_count = ALL_KINDS.iter().filter(|&&k| lean_probing(k)).count();
    let prop9 = probing_count == 4;
    let t9_msg = if prop9 { "PASS".to_string() } else { format!("FAIL (got {})", probing_count) };
    println!("[T9] exactly 4 probing kinds: {}", t9_msg);
    if prop9 { passed += 1; } else { failed += 1; }

    // T10: Stream is ack-eliciting
    let prop10 = lean_ack_eliciting(FrameKind::Stream);
    println!("[T10] Stream is ack-eliciting: {}",
        if prop10 { "PASS" } else { "FAIL" });
    if prop10 { passed += 1; } else { failed += 1; }

    println!("\n=== RESULT: {}/{} PASS ===", passed, passed + failed);

    if failed > 0 {
        std::process::exit(1);
    }
}
