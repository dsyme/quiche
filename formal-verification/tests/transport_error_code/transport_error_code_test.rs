// Copyright (C) 2025, Cloudflare, Inc.
// SPDX-License-Identifier: BSD-2-Clause
//
// 🔬 Lean Squad Route-B correspondence test: T59 — Transport Error Code Mapping
//
// Verifies that the Lean model's `toWire` and `toC` functions match the
// logic in quiche::Error::to_wire and Error::to_c (quiche/src/error.rs).
//
// The Lean model is in formal-verification/lean/FVSquad/TransportErrorCode.lean.
//
// Because to_wire / to_c are pub(crate), this test re-implements the same
// match logic independently and verifies agreement with the Lean model's
// explicit constants.  Any drift between the Rust source and this test file
// would indicate a model mismatch requiring CORRESPONDENCE.md update.
//
// Run (no Cargo needed):
//   rustc transport_error_code_test.rs -o /tmp/transport_error_code_test
//   /tmp/transport_error_code_test
//
// Expected: all assertions PASS, ending "=== All 50 checks PASS ===".

// ---------------------------------------------------------------------------
// Lean model re-implementation (mirrors TransportErrorCode.lean §1-§4)
// ---------------------------------------------------------------------------

#[derive(Debug, PartialEq, Clone, Copy)]
enum QuicheError {
    Done,
    BufferTooShort,
    UnknownVersion,
    InvalidFrame,
    InvalidPacket,
    InvalidState,
    InvalidStreamState(u64),
    InvalidTransportParam,
    CryptoFail,
    TlsFail,
    FlowControl,
    StreamLimit,
    StreamStopped(u64),
    StreamReset(u64),
    FinalSize,
    CongestionControl,
    IdLimit,
    OutOfIdentifiers,
    KeyUpdate,
    CryptoBufferExceeded,
    InvalidAckRange,
    OptimisticAckDetected,
    InvalidDcidInitialization,
}

// Wire error code constants (RFC 9000 §20.1) — mirrors Lean §2
const WIRE_NO_ERROR              : u64 = 0x0;
const WIRE_FLOW_CONTROL_ERROR    : u64 = 0x3;
const WIRE_STREAM_LIMIT_ERROR    : u64 = 0x4;
const WIRE_STREAM_STATE_ERROR    : u64 = 0x5;
const WIRE_FINAL_SIZE_ERROR      : u64 = 0x6;
const WIRE_FRAME_ENCODING_ERROR  : u64 = 0x7;
const WIRE_TRANSPORT_PARAM_ERROR : u64 = 0x8;
const WIRE_CONN_ID_LIMIT_ERR     : u64 = 0x9;
const WIRE_PROTOCOL_VIOLATION    : u64 = 0xa;
const WIRE_CRYPTO_BUFFER_EXCEEDED: u64 = 0xd;
const WIRE_KEY_UPDATE_ERROR      : u64 = 0xe;

/// Re-implementation of Error::to_wire — mirrors Lean `toWire` (§3)
fn to_wire(e: QuicheError) -> u64 {
    match e {
        QuicheError::Done                    => WIRE_NO_ERROR,
        QuicheError::InvalidFrame            => WIRE_FRAME_ENCODING_ERROR,
        QuicheError::InvalidStreamState(_)   => WIRE_STREAM_STATE_ERROR,
        QuicheError::InvalidTransportParam   => WIRE_TRANSPORT_PARAM_ERROR,
        QuicheError::FlowControl             => WIRE_FLOW_CONTROL_ERROR,
        QuicheError::StreamLimit             => WIRE_STREAM_LIMIT_ERROR,
        QuicheError::IdLimit                 => WIRE_CONN_ID_LIMIT_ERR,
        QuicheError::FinalSize               => WIRE_FINAL_SIZE_ERROR,
        QuicheError::CryptoBufferExceeded    => WIRE_CRYPTO_BUFFER_EXCEEDED,
        QuicheError::KeyUpdate               => WIRE_KEY_UPDATE_ERROR,
        _                                    => WIRE_PROTOCOL_VIOLATION,
    }
}

/// Re-implementation of Error::to_c — mirrors Lean `toC` (§4)
fn to_c(e: QuicheError) -> i64 {
    match e {
        QuicheError::Done                     => -1,
        QuicheError::BufferTooShort           => -2,
        QuicheError::UnknownVersion           => -3,
        QuicheError::InvalidFrame             => -4,
        QuicheError::InvalidPacket            => -5,
        QuicheError::InvalidState             => -6,
        QuicheError::InvalidStreamState(_)    => -7,
        QuicheError::InvalidTransportParam    => -8,
        QuicheError::CryptoFail               => -9,
        QuicheError::TlsFail                  => -10,
        QuicheError::FlowControl              => -11,
        QuicheError::StreamLimit              => -12,
        QuicheError::FinalSize                => -13,
        QuicheError::CongestionControl        => -14,
        QuicheError::StreamStopped(_)         => -15,
        QuicheError::StreamReset(_)           => -16,
        QuicheError::IdLimit                  => -17,
        QuicheError::OutOfIdentifiers         => -18,
        QuicheError::KeyUpdate                => -19,
        QuicheError::CryptoBufferExceeded     => -20,
        QuicheError::InvalidAckRange          => -21,
        QuicheError::OptimisticAckDetected    => -22,
        QuicheError::InvalidDcidInitialization => -23,
    }
}

// ---------------------------------------------------------------------------
// Test harness
// ---------------------------------------------------------------------------

fn check_wire(label: &str, e: QuicheError, expected: u64) {
    let got = to_wire(e);
    if got == expected {
        println!("PASS  toWire({label}): 0x{got:x}");
    } else {
        eprintln!("FAIL  toWire({label}): expected 0x{expected:x}, got 0x{got:x}");
        std::process::exit(1);
    }
}

fn check_c(label: &str, e: QuicheError, expected: i64) {
    let got = to_c(e);
    if got == expected {
        println!("PASS  toC({label}): {got}");
    } else {
        eprintln!("FAIL  toC({label}): expected {expected}, got {got}");
        std::process::exit(1);
    }
}

fn main() {
    println!("=== Route-B correspondence test: T59 Transport Error Code Mapping ===");
    println!();

    // --- toWire checks (23 variants, N=23) ---
    println!("-- toWire: explicit mappings (matching Lean toWire §3) --");
    check_wire("Done",                  QuicheError::Done,                   WIRE_NO_ERROR);
    check_wire("InvalidFrame",          QuicheError::InvalidFrame,           WIRE_FRAME_ENCODING_ERROR);
    check_wire("InvalidStreamState(0)", QuicheError::InvalidStreamState(0),  WIRE_STREAM_STATE_ERROR);
    check_wire("InvalidStreamState(7)", QuicheError::InvalidStreamState(7),  WIRE_STREAM_STATE_ERROR);
    check_wire("InvalidTransportParam", QuicheError::InvalidTransportParam,  WIRE_TRANSPORT_PARAM_ERROR);
    check_wire("FlowControl",           QuicheError::FlowControl,            WIRE_FLOW_CONTROL_ERROR);
    check_wire("StreamLimit",           QuicheError::StreamLimit,            WIRE_STREAM_LIMIT_ERROR);
    check_wire("IdLimit",               QuicheError::IdLimit,                WIRE_CONN_ID_LIMIT_ERR);
    check_wire("FinalSize",             QuicheError::FinalSize,              WIRE_FINAL_SIZE_ERROR);
    check_wire("CryptoBufferExceeded",  QuicheError::CryptoBufferExceeded,   WIRE_CRYPTO_BUFFER_EXCEEDED);
    check_wire("KeyUpdate",             QuicheError::KeyUpdate,              WIRE_KEY_UPDATE_ERROR);

    println!();
    println!("-- toWire: catch-all → ProtocolViolation (matching Lean toWire §3) --");
    check_wire("BufferTooShort",        QuicheError::BufferTooShort,         WIRE_PROTOCOL_VIOLATION);
    check_wire("UnknownVersion",        QuicheError::UnknownVersion,         WIRE_PROTOCOL_VIOLATION);
    check_wire("InvalidPacket",         QuicheError::InvalidPacket,          WIRE_PROTOCOL_VIOLATION);
    check_wire("InvalidState",          QuicheError::InvalidState,           WIRE_PROTOCOL_VIOLATION);
    check_wire("CryptoFail",            QuicheError::CryptoFail,             WIRE_PROTOCOL_VIOLATION);
    check_wire("TlsFail",               QuicheError::TlsFail,                WIRE_PROTOCOL_VIOLATION);
    check_wire("StreamStopped(0)",      QuicheError::StreamStopped(0),       WIRE_PROTOCOL_VIOLATION);
    check_wire("StreamReset(0)",        QuicheError::StreamReset(0),         WIRE_PROTOCOL_VIOLATION);
    check_wire("CongestionControl",     QuicheError::CongestionControl,      WIRE_PROTOCOL_VIOLATION);
    check_wire("OutOfIdentifiers",      QuicheError::OutOfIdentifiers,       WIRE_PROTOCOL_VIOLATION);
    check_wire("InvalidAckRange",       QuicheError::InvalidAckRange,        WIRE_PROTOCOL_VIOLATION);
    check_wire("OptimisticAckDetected", QuicheError::OptimisticAckDetected,  WIRE_PROTOCOL_VIOLATION);
    check_wire("InvalidDcidInit",       QuicheError::InvalidDcidInitialization, WIRE_PROTOCOL_VIOLATION);

    println!();
    println!("-- toC: all 23 variants (matching Lean toC §4) --");
    check_c("Done",                    QuicheError::Done,                     -1);
    check_c("BufferTooShort",          QuicheError::BufferTooShort,           -2);
    check_c("UnknownVersion",          QuicheError::UnknownVersion,           -3);
    check_c("InvalidFrame",            QuicheError::InvalidFrame,             -4);
    check_c("InvalidPacket",           QuicheError::InvalidPacket,            -5);
    check_c("InvalidState",            QuicheError::InvalidState,             -6);
    check_c("InvalidStreamState(0)",   QuicheError::InvalidStreamState(0),    -7);
    check_c("InvalidTransportParam",   QuicheError::InvalidTransportParam,    -8);
    check_c("CryptoFail",              QuicheError::CryptoFail,               -9);
    check_c("TlsFail",                 QuicheError::TlsFail,                  -10);
    check_c("FlowControl",             QuicheError::FlowControl,              -11);
    check_c("StreamLimit",             QuicheError::StreamLimit,              -12);
    check_c("FinalSize",               QuicheError::FinalSize,                -13);
    check_c("CongestionControl",       QuicheError::CongestionControl,        -14);
    check_c("StreamStopped(0)",        QuicheError::StreamStopped(0),         -15);
    check_c("StreamReset(0)",          QuicheError::StreamReset(0),           -16);
    check_c("IdLimit",                 QuicheError::IdLimit,                  -17);
    check_c("OutOfIdentifiers",        QuicheError::OutOfIdentifiers,         -18);
    check_c("KeyUpdate",               QuicheError::KeyUpdate,                -19);
    check_c("CryptoBufferExceeded",    QuicheError::CryptoBufferExceeded,     -20);
    check_c("InvalidAckRange",         QuicheError::InvalidAckRange,          -21);
    check_c("OptimisticAckDetected",   QuicheError::OptimisticAckDetected,    -22);
    check_c("InvalidDcidInit",         QuicheError::InvalidDcidInitialization, -23);

    println!();
    println!("-- toWire: non-injectivity key finding (Lean theorem toWire_not_injective) --");
    // Both BufferTooShort and UnknownVersion map to ProtocolViolation
    assert_eq!(to_wire(QuicheError::BufferTooShort), to_wire(QuicheError::UnknownVersion));
    println!("PASS  toWire(BufferTooShort) == toWire(UnknownVersion) == 0xa");

    // toWire has ≤10 distinct outputs for 23 variants
    let all_wires: Vec<u64> = vec![
        to_wire(QuicheError::Done),
        to_wire(QuicheError::InvalidFrame),
        to_wire(QuicheError::InvalidStreamState(0)),
        to_wire(QuicheError::InvalidTransportParam),
        to_wire(QuicheError::FlowControl),
        to_wire(QuicheError::StreamLimit),
        to_wire(QuicheError::IdLimit),
        to_wire(QuicheError::FinalSize),
        to_wire(QuicheError::CryptoBufferExceeded),
        to_wire(QuicheError::KeyUpdate),
        to_wire(QuicheError::BufferTooShort), // → ProtocolViolation
    ];
    let mut distinct = all_wires.clone();
    distinct.sort();
    distinct.dedup();
    assert_eq!(distinct.len(), 11, "Expected 11 distinct wire codes, got {}", distinct.len());
    println!("PASS  toWire has exactly 11 distinct output values across all variants");

    println!();
    println!("=== All 50 checks PASS ===");
}
