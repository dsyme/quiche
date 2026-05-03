// Copyright (C) 2025, Cloudflare, Inc.
// BSD-2-Clause licence (same as quiche)
//
// 🔬 Route-B correspondence test for H3Settings (T33).
//
// Tests that the Lean model in FVSquad/H3Settings.lean faithfully captures
// the `parse_settings_frame` logic from quiche/src/h3/frame.rs.
//
// The Lean model defines:
//   - `isReserved : UInt64 → Bool`       (HTTP/2 reserved identifiers)
//   - `requiresBool : UInt64 → Bool`     (boolean-constrained identifiers)
//   - `applyEntry : Settings → id → v → Option Settings`
//   - `parse : List (id × v) → ParseResult`
//
// This Rust test re-implements both the Lean logic and the Rust spec and
// verifies they agree on all test cases.
//
// Run:
//   rustc h3_settings_test.rs -o /tmp/h3s_test && /tmp/h3s_test

// ─── Identifier constants (match Lean and Rust) ───────────────────────────────

const SETTINGS_QPACK_MAX_TABLE_CAPACITY:  u64 = 0x1;
const SETTINGS_MAX_FIELD_SECTION_SIZE:    u64 = 0x6;
const SETTINGS_QPACK_BLOCKED_STREAMS:     u64 = 0x7;
const SETTINGS_ENABLE_CONNECT_PROTOCOL:   u64 = 0x8;
const SETTINGS_H3_DATAGRAM_00:            u64 = 0x276;
const SETTINGS_H3_DATAGRAM:              u64 = 0x33;

// ─── Lean-model side ──────────────────────────────────────────────────────────

fn is_reserved(id: u64) -> bool {
    id == 0x0 || id == 0x2 || id == 0x3 || id == 0x4 || id == 0x5
}

fn requires_bool(id: u64) -> bool {
    id == SETTINGS_ENABLE_CONNECT_PROTOCOL ||
    id == SETTINGS_H3_DATAGRAM_00 ||
    id == SETTINGS_H3_DATAGRAM
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct Settings {
    max_field_section_size:    Option<u64>,
    qpack_max_table_capacity:  Option<u64>,
    qpack_blocked_streams:     Option<u64>,
    connect_protocol:          Option<u64>,
    h3_datagram:               Option<u64>,
    additional_settings:       Vec<(u64, u64)>,
}

impl Default for Settings {
    fn default() -> Self {
        Settings {
            max_field_section_size: None,
            qpack_max_table_capacity: None,
            qpack_blocked_streams: None,
            connect_protocol: None,
            h3_datagram: None,
            additional_settings: vec![],
        }
    }
}

#[derive(Debug, PartialEq, Eq)]
enum ParseResult {
    Ok(Settings),
    Err,
}

fn apply_entry(mut s: Settings, id: u64, v: u64) -> Option<Settings> {
    if is_reserved(id) {
        return None;
    }
    if requires_bool(id) && v > 1 {
        return None;
    }
    if id == SETTINGS_QPACK_MAX_TABLE_CAPACITY {
        s.qpack_max_table_capacity = Some(v);
    } else if id == SETTINGS_MAX_FIELD_SECTION_SIZE {
        s.max_field_section_size = Some(v);
    } else if id == SETTINGS_QPACK_BLOCKED_STREAMS {
        s.qpack_blocked_streams = Some(v);
    } else if id == SETTINGS_ENABLE_CONNECT_PROTOCOL {
        s.connect_protocol = Some(v);
    } else if id == SETTINGS_H3_DATAGRAM_00 {
        s.h3_datagram = Some(v);
    } else if id == SETTINGS_H3_DATAGRAM {
        s.h3_datagram = Some(v);
    } else {
        s.additional_settings.push((id, v));
    }
    Some(s)
}

fn lean_parse(pairs: &[(u64, u64)]) -> ParseResult {
    let mut acc = Settings::default();
    for &(id, v) in pairs {
        match apply_entry(acc, id, v) {
            None    => return ParseResult::Err,
            Some(s) => acc = s,
        }
    }
    ParseResult::Ok(acc)
}

// ─── Rust-spec side ────────────────────────────────────────────────────────────
//
// Direct re-implementation of `parse_settings_frame` logic from
// quiche/src/h3/frame.rs (commit a3b334325b32843f4a97fc996be3f31dbc82a660).
// We omit byte-level varint parsing and MAX_SETTINGS_PAYLOAD_SIZE since the
// test operates on already-decoded (identifier, value) pairs.

fn rust_parse(pairs: &[(u64, u64)]) -> ParseResult {
    let mut max_field_section_size    = None;
    let mut qpack_max_table_capacity  = None;
    let mut qpack_blocked_streams     = None;
    let mut connect_protocol_enabled  = None;
    let mut h3_datagram               = None;
    let mut additional_settings: Vec<(u64, u64)> = vec![];

    for &(identifier, value) in pairs {
        match identifier {
            id if id == SETTINGS_QPACK_MAX_TABLE_CAPACITY => {
                qpack_max_table_capacity = Some(value);
            },
            id if id == SETTINGS_MAX_FIELD_SECTION_SIZE => {
                max_field_section_size = Some(value);
            },
            id if id == SETTINGS_QPACK_BLOCKED_STREAMS => {
                qpack_blocked_streams = Some(value);
            },
            id if id == SETTINGS_ENABLE_CONNECT_PROTOCOL => {
                if value > 1 {
                    return ParseResult::Err;
                }
                connect_protocol_enabled = Some(value);
            },
            id if id == SETTINGS_H3_DATAGRAM_00 || id == SETTINGS_H3_DATAGRAM => {
                if value > 1 {
                    return ParseResult::Err;
                }
                h3_datagram = Some(value);
            },
            0x0 | 0x2 | 0x3 | 0x4 | 0x5 => {
                return ParseResult::Err;
            },
            _ => {
                additional_settings.push((identifier, value));
            },
        }
    }

    ParseResult::Ok(Settings {
        max_field_section_size,
        qpack_max_table_capacity,
        qpack_blocked_streams,
        connect_protocol: connect_protocol_enabled,
        h3_datagram,
        additional_settings,
    })
}

// ─── Test harness ─────────────────────────────────────────────────────────────

fn check(label: &str, pairs: &[(u64, u64)]) -> bool {
    let lean = lean_parse(pairs);
    let rust = rust_parse(pairs);
    if lean == rust {
        return true;
    }
    eprintln!("FAIL: {}", label);
    eprintln!("  pairs: {:?}", pairs);
    eprintln!("  lean: {:?}", lean);
    eprintln!("  rust: {:?}", rust);
    false
}

// For cases that should produce Err on both sides.
fn check_err(label: &str, pairs: &[(u64, u64)]) -> bool {
    let lean = lean_parse(pairs);
    let rust = rust_parse(pairs);
    let lean_ok = lean == ParseResult::Err;
    let rust_ok = rust == ParseResult::Err;
    if lean_ok && rust_ok {
        return true;
    }
    eprintln!("FAIL (expected Err): {}", label);
    eprintln!("  pairs: {:?}", pairs);
    eprintln!("  lean: {:?} (expect Err={})", lean, lean_ok);
    eprintln!("  rust: {:?} (expect Err={})", rust, rust_ok);
    false
}

fn main() {
    let mut passed = 0usize;
    let mut failed = 0usize;

    macro_rules! t {
        ($label:expr, $pairs:expr) => {{
            if check($label, $pairs) { passed += 1; } else { failed += 1; }
        }};
    }
    macro_rules! te {
        ($label:expr, $pairs:expr) => {{
            if check_err($label, $pairs) { passed += 1; } else { failed += 1; }
        }};
    }

    // ── Empty payload ──
    t!("empty",  &[]);

    // ── Single known fields ──
    t!("qpack_max_table_capacity=0",    &[(SETTINGS_QPACK_MAX_TABLE_CAPACITY,  0)]);
    t!("qpack_max_table_capacity=4096", &[(SETTINGS_QPACK_MAX_TABLE_CAPACITY,  4096)]);
    t!("max_field_section_size=0",      &[(SETTINGS_MAX_FIELD_SECTION_SIZE,     0)]);
    t!("max_field_section_size=65535",  &[(SETTINGS_MAX_FIELD_SECTION_SIZE,     65535)]);
    t!("qpack_blocked_streams=0",       &[(SETTINGS_QPACK_BLOCKED_STREAMS,      0)]);
    t!("qpack_blocked_streams=100",     &[(SETTINGS_QPACK_BLOCKED_STREAMS,      100)]);
    t!("connect_protocol=0",            &[(SETTINGS_ENABLE_CONNECT_PROTOCOL,    0)]);
    t!("connect_protocol=1",            &[(SETTINGS_ENABLE_CONNECT_PROTOCOL,    1)]);
    t!("h3_datagram_00=0",              &[(SETTINGS_H3_DATAGRAM_00,             0)]);
    t!("h3_datagram_00=1",              &[(SETTINGS_H3_DATAGRAM_00,             1)]);
    t!("h3_datagram=0",                 &[(SETTINGS_H3_DATAGRAM,                0)]);
    t!("h3_datagram=1",                 &[(SETTINGS_H3_DATAGRAM,                1)]);

    // ── Boolean-violation errors ──
    te!("connect_protocol=2",           &[(SETTINGS_ENABLE_CONNECT_PROTOCOL,    2)]);
    te!("connect_protocol=9",           &[(SETTINGS_ENABLE_CONNECT_PROTOCOL,    9)]);
    te!("connect_protocol=u64::MAX",    &[(SETTINGS_ENABLE_CONNECT_PROTOCOL,    u64::MAX)]);
    te!("h3_datagram_00=2",             &[(SETTINGS_H3_DATAGRAM_00,             2)]);
    te!("h3_datagram_00=255",           &[(SETTINGS_H3_DATAGRAM_00,             255)]);
    te!("h3_datagram=2",                &[(SETTINGS_H3_DATAGRAM,                2)]);
    te!("h3_datagram=100",              &[(SETTINGS_H3_DATAGRAM,                100)]);

    // ── Reserved identifier errors (all five reserved ids) ──
    te!("reserved_0x0",                 &[(0x0,  42)]);
    te!("reserved_0x2",                 &[(0x2,   0)]);
    te!("reserved_0x3",                 &[(0x3,   1)]);
    te!("reserved_0x4",                 &[(0x4,   1)]);
    te!("reserved_0x5",                 &[(0x5,   0)]);

    // ── Error propagates when reserved id appears later in the list ──
    te!("qpack_then_reserved",          &[(SETTINGS_QPACK_MAX_TABLE_CAPACITY, 100), (0x4, 1)]);
    te!("known_then_bool_violation",    &[(SETTINGS_MAX_FIELD_SECTION_SIZE, 1000), (SETTINGS_ENABLE_CONNECT_PROTOCOL, 5)]);

    // ── Unknown identifiers go to additional_settings ──
    t!("unknown_0x1000",                &[(0x1000, 42)]);
    t!("unknown_0xffff",                &[(0xffff,  0)]);
    t!("unknown_grease_0x0a0a",         &[(0x0a0a, 99)]);

    // ── Multi-field combinations ──
    t!("qpack_and_connect",
       &[(SETTINGS_QPACK_MAX_TABLE_CAPACITY, 4096),
         (SETTINGS_ENABLE_CONNECT_PROTOCOL,  1)]);
    t!("all_known_valid",
       &[(SETTINGS_QPACK_MAX_TABLE_CAPACITY,  4096),
         (SETTINGS_MAX_FIELD_SECTION_SIZE,    16384),
         (SETTINGS_QPACK_BLOCKED_STREAMS,     100),
         (SETTINGS_ENABLE_CONNECT_PROTOCOL,   1),
         (SETTINGS_H3_DATAGRAM,               1)]);
    t!("known_plus_unknown",
       &[(SETTINGS_QPACK_MAX_TABLE_CAPACITY, 1024),
         (0x2000, 7)]);
    t!("two_unknowns",
       &[(0x1001, 1), (0x1002, 2)]);

    // ── H3_DATAGRAM_00 and H3_DATAGRAM both write h3_datagram; last wins ──
    t!("datagram_00_then_datagram",
       &[(SETTINGS_H3_DATAGRAM_00, 1), (SETTINGS_H3_DATAGRAM, 0)]);
    t!("datagram_then_datagram_00",
       &[(SETTINGS_H3_DATAGRAM, 0),    (SETTINGS_H3_DATAGRAM_00, 1)]);

    // ── Error after valid entries ──
    te!("valid_then_reserved_mid",
       &[(SETTINGS_MAX_FIELD_SECTION_SIZE, 512),
         (SETTINGS_QPACK_BLOCKED_STREAMS, 10),
         (0x3, 0)]);
    te!("valid_then_bool_viol_end",
       &[(SETTINGS_QPACK_MAX_TABLE_CAPACITY, 256),
         (SETTINGS_H3_DATAGRAM_00, 3)]);

    // ── Duplicate known keys: second overwrites first ──
    t!("duplicate_qpack_max",
       &[(SETTINGS_QPACK_MAX_TABLE_CAPACITY, 256),
         (SETTINGS_QPACK_MAX_TABLE_CAPACITY, 512)]);
    t!("duplicate_connect_valid",
       &[(SETTINGS_ENABLE_CONNECT_PROTOCOL, 0),
         (SETTINGS_ENABLE_CONNECT_PROTOCOL, 1)]);

    // ── Edge values ──
    t!("qpack_max_u64_max",  &[(SETTINGS_QPACK_MAX_TABLE_CAPACITY, u64::MAX)]);
    t!("max_field_sec_max",  &[(SETTINGS_MAX_FIELD_SECTION_SIZE,   u64::MAX)]);
    t!("blocked_streams_max",&[(SETTINGS_QPACK_BLOCKED_STREAMS,    u64::MAX)]);

    // ── Lean theorem: isReserved properties ──
    assert!( is_reserved(0x0), "is_reserved_0");
    assert!( is_reserved(0x2), "is_reserved_2");
    assert!( is_reserved(0x3), "is_reserved_3");
    assert!( is_reserved(0x4), "is_reserved_4");
    assert!( is_reserved(0x5), "is_reserved_5");
    assert!(!is_reserved(0x1), "is_reserved_1_false");
    assert!(!is_reserved(0x6), "is_reserved_6_false");
    assert!(!is_reserved(0x8), "is_reserved_8_false");

    // ── Lean theorem: requiresBool properties ──
    assert!( requires_bool(SETTINGS_ENABLE_CONNECT_PROTOCOL), "requiresBool_connect");
    assert!( requires_bool(SETTINGS_H3_DATAGRAM_00),          "requiresBool_datagram_00");
    assert!( requires_bool(SETTINGS_H3_DATAGRAM),             "requiresBool_datagram");
    assert!(!requires_bool(SETTINGS_QPACK_MAX_TABLE_CAPACITY),"requiresBool_qpack_max_false");
    assert!(!requires_bool(SETTINGS_QPACK_BLOCKED_STREAMS),   "requiresBool_qpack_blk_false");
    assert!(!requires_bool(SETTINGS_MAX_FIELD_SECTION_SIZE),  "requiresBool_max_field_false");

    // ── Lean theorem: parse_empty ──
    assert_eq!(lean_parse(&[]), ParseResult::Ok(Settings::default()), "parse_empty");

    // ── Lean theorem: parse_reserved_id_err ──
    assert_eq!(lean_parse(&[(0x0, 0)]), ParseResult::Err, "parse_reserved_0");
    assert_eq!(lean_parse(&[(0x4, 1)]), ParseResult::Err, "parse_reserved_4");

    // ── Lean theorem: parse_connect_gt1_err ──
    assert_eq!(lean_parse(&[(SETTINGS_ENABLE_CONNECT_PROTOCOL, 2)]),
               ParseResult::Err, "parse_connect_gt1");

    // ── Lean theorem: parse_datagram_gt1_err ──
    assert_eq!(lean_parse(&[(SETTINGS_H3_DATAGRAM, 2)]),
               ParseResult::Err, "parse_datagram_gt1");

    // ── Lean theorem: parse_single_qpack_ok ──
    let expected = Settings {
        qpack_max_table_capacity: Some(4096),
        ..Settings::default()
    };
    assert_eq!(lean_parse(&[(SETTINGS_QPACK_MAX_TABLE_CAPACITY, 4096)]),
               ParseResult::Ok(expected), "parse_single_qpack_ok");

    println!("H3Settings Route-B: {}/{} PASS", passed, passed + failed);
    if failed > 0 {
        std::process::exit(1);
    }
}
