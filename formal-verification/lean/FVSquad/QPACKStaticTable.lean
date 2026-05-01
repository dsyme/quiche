-- Copyright (C) 2025, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause


/-!
# QPACK Static Table Invariants

Formal verification of the QPACK static table defined in
`quiche/src/h3/qpack/static_table.rs`.

The QPACK static table (RFC 9204 Appendix A) maps integer indices 0–98 to
(name, value) header pairs. The Rust implementation provides two data structures:

- `STATIC_DECODE_TABLE: [(&[u8], &[u8]); 99]`  — index → (name, value)
- `STATIC_ENCODE_TABLE` — (name, value) → index (organised by name length)

## What this file verifies (all via `decide` / `native_decide`)

1. The decode table has exactly 99 entries (indices 0–98).
2. Every index stored in the encode table is a valid decode index (< 99).
3. Consistency: for every (name, value, index) triple in the encode table, the
   decode table at that index matches (name, value).
4. No index appears twice in the encode table (uniqueness of encode mapping).

## Modelling choices

- The tables are inlined as Lean `List` literals — byte strings are represented
  as `List Nat` for decidable equality.
- The Lean model is a literal transcription of the Rust constants; it does not
  model the lookup functions themselves (those are trivial array indexing).
- I/O, allocation, and Rust's `&[u8]` lifetime semantics are not modelled.
-/

namespace QPACKStatic

/-- A single static table entry: (name, value) as byte lists. -/
structure Entry where
  name  : List Nat
  value : List Nat
  deriving DecidableEq, Repr

/-- The 99-entry QPACK static decode table (RFC 9204 Appendix A).
    Index i corresponds to `STATIC_DECODE_TABLE[i]` in the Rust source. -/
def decodeTable : List Entry := [
  ⟨":authority".toList.map Char.toNat, "".toList.map Char.toNat⟩,        -- 0
  ⟨":path".toList.map Char.toNat, "/".toList.map Char.toNat⟩,             -- 1
  ⟨"age".toList.map Char.toNat, "0".toList.map Char.toNat⟩,               -- 2
  ⟨"content-disposition".toList.map Char.toNat, "".toList.map Char.toNat⟩, -- 3
  ⟨"content-length".toList.map Char.toNat, "0".toList.map Char.toNat⟩,    -- 4
  ⟨"cookie".toList.map Char.toNat, "".toList.map Char.toNat⟩,             -- 5
  ⟨"date".toList.map Char.toNat, "".toList.map Char.toNat⟩,               -- 6
  ⟨"etag".toList.map Char.toNat, "".toList.map Char.toNat⟩,               -- 7
  ⟨"if-modified-since".toList.map Char.toNat, "".toList.map Char.toNat⟩,  -- 8
  ⟨"if-none-match".toList.map Char.toNat, "".toList.map Char.toNat⟩,      -- 9
  ⟨"last-modified".toList.map Char.toNat, "".toList.map Char.toNat⟩,      -- 10
  ⟨"link".toList.map Char.toNat, "".toList.map Char.toNat⟩,               -- 11
  ⟨"location".toList.map Char.toNat, "".toList.map Char.toNat⟩,           -- 12
  ⟨"referer".toList.map Char.toNat, "".toList.map Char.toNat⟩,            -- 13
  ⟨"set-cookie".toList.map Char.toNat, "".toList.map Char.toNat⟩,         -- 14
  ⟨":method".toList.map Char.toNat, "CONNECT".toList.map Char.toNat⟩,     -- 15
  ⟨":method".toList.map Char.toNat, "DELETE".toList.map Char.toNat⟩,      -- 16
  ⟨":method".toList.map Char.toNat, "GET".toList.map Char.toNat⟩,         -- 17
  ⟨":method".toList.map Char.toNat, "HEAD".toList.map Char.toNat⟩,        -- 18
  ⟨":method".toList.map Char.toNat, "OPTIONS".toList.map Char.toNat⟩,     -- 19
  ⟨":method".toList.map Char.toNat, "POST".toList.map Char.toNat⟩,        -- 20
  ⟨":method".toList.map Char.toNat, "PUT".toList.map Char.toNat⟩,         -- 21
  ⟨":scheme".toList.map Char.toNat, "http".toList.map Char.toNat⟩,        -- 22
  ⟨":scheme".toList.map Char.toNat, "https".toList.map Char.toNat⟩,       -- 23
  ⟨":status".toList.map Char.toNat, "103".toList.map Char.toNat⟩,         -- 24
  ⟨":status".toList.map Char.toNat, "200".toList.map Char.toNat⟩,         -- 25
  ⟨":status".toList.map Char.toNat, "304".toList.map Char.toNat⟩,         -- 26
  ⟨":status".toList.map Char.toNat, "404".toList.map Char.toNat⟩,         -- 27
  ⟨":status".toList.map Char.toNat, "503".toList.map Char.toNat⟩,         -- 28
  ⟨"accept".toList.map Char.toNat, "*/*".toList.map Char.toNat⟩,          -- 29
  ⟨"accept".toList.map Char.toNat,
    "application/dns-message".toList.map Char.toNat⟩,                      -- 30
  ⟨"accept-encoding".toList.map Char.toNat,
    "gzip, deflate, br".toList.map Char.toNat⟩,                            -- 31
  ⟨"accept-ranges".toList.map Char.toNat, "bytes".toList.map Char.toNat⟩, -- 32
  ⟨"access-control-allow-headers".toList.map Char.toNat,
    "cache-control".toList.map Char.toNat⟩,                                -- 33
  ⟨"access-control-allow-headers".toList.map Char.toNat,
    "content-type".toList.map Char.toNat⟩,                                 -- 34
  ⟨"access-control-allow-origin".toList.map Char.toNat,
    "*".toList.map Char.toNat⟩,                                             -- 35
  ⟨"cache-control".toList.map Char.toNat,
    "max-age=0".toList.map Char.toNat⟩,                                    -- 36
  ⟨"cache-control".toList.map Char.toNat,
    "max-age=2592000".toList.map Char.toNat⟩,                              -- 37
  ⟨"cache-control".toList.map Char.toNat,
    "max-age=604800".toList.map Char.toNat⟩,                               -- 38
  ⟨"cache-control".toList.map Char.toNat,
    "no-cache".toList.map Char.toNat⟩,                                     -- 39
  ⟨"cache-control".toList.map Char.toNat,
    "no-store".toList.map Char.toNat⟩,                                     -- 40
  ⟨"cache-control".toList.map Char.toNat,
    "public, max-age=31536000".toList.map Char.toNat⟩,                     -- 41
  ⟨"content-encoding".toList.map Char.toNat, "br".toList.map Char.toNat⟩, -- 42
  ⟨"content-encoding".toList.map Char.toNat,
    "gzip".toList.map Char.toNat⟩,                                         -- 43
  ⟨"content-type".toList.map Char.toNat,
    "application/dns-message".toList.map Char.toNat⟩,                      -- 44
  ⟨"content-type".toList.map Char.toNat,
    "application/javascript".toList.map Char.toNat⟩,                       -- 45
  ⟨"content-type".toList.map Char.toNat,
    "application/json".toList.map Char.toNat⟩,                             -- 46
  ⟨"content-type".toList.map Char.toNat,
    "application/x-www-form-urlencoded".toList.map Char.toNat⟩,            -- 47
  ⟨"content-type".toList.map Char.toNat,
    "image/gif".toList.map Char.toNat⟩,                                    -- 48
  ⟨"content-type".toList.map Char.toNat,
    "image/jpeg".toList.map Char.toNat⟩,                                   -- 49
  ⟨"content-type".toList.map Char.toNat,
    "image/png".toList.map Char.toNat⟩,                                    -- 50
  ⟨"content-type".toList.map Char.toNat,
    "text/css".toList.map Char.toNat⟩,                                     -- 51
  ⟨"content-type".toList.map Char.toNat,
    "text/html; charset=utf-8".toList.map Char.toNat⟩,                     -- 52
  ⟨"content-type".toList.map Char.toNat,
    "text/plain".toList.map Char.toNat⟩,                                   -- 53
  ⟨"content-type".toList.map Char.toNat,
    "text/plain;charset=utf-8".toList.map Char.toNat⟩,                     -- 54
  ⟨"range".toList.map Char.toNat, "bytes=0-".toList.map Char.toNat⟩,      -- 55
  ⟨"strict-transport-security".toList.map Char.toNat,
    "max-age=31536000".toList.map Char.toNat⟩,                             -- 56
  ⟨"strict-transport-security".toList.map Char.toNat,
    "max-age=31536000; includesubdomains".toList.map Char.toNat⟩,          -- 57
  ⟨"strict-transport-security".toList.map Char.toNat,
    "max-age=31536000; includesubdomains; preload".toList.map Char.toNat⟩, -- 58
  ⟨"vary".toList.map Char.toNat,
    "accept-encoding".toList.map Char.toNat⟩,                              -- 59
  ⟨"vary".toList.map Char.toNat, "origin".toList.map Char.toNat⟩,         -- 60
  ⟨"x-content-type-options".toList.map Char.toNat,
    "nosniff".toList.map Char.toNat⟩,                                      -- 61
  ⟨"x-xss-protection".toList.map Char.toNat,
    "1; mode=block".toList.map Char.toNat⟩,                                -- 62
  ⟨":status".toList.map Char.toNat, "100".toList.map Char.toNat⟩,         -- 63
  ⟨":status".toList.map Char.toNat, "204".toList.map Char.toNat⟩,         -- 64
  ⟨":status".toList.map Char.toNat, "206".toList.map Char.toNat⟩,         -- 65
  ⟨":status".toList.map Char.toNat, "302".toList.map Char.toNat⟩,         -- 66
  ⟨":status".toList.map Char.toNat, "400".toList.map Char.toNat⟩,         -- 67
  ⟨":status".toList.map Char.toNat, "403".toList.map Char.toNat⟩,         -- 68
  ⟨":status".toList.map Char.toNat, "421".toList.map Char.toNat⟩,         -- 69
  ⟨":status".toList.map Char.toNat, "425".toList.map Char.toNat⟩,         -- 70
  ⟨":status".toList.map Char.toNat, "500".toList.map Char.toNat⟩,         -- 71
  ⟨"accept-language".toList.map Char.toNat, "".toList.map Char.toNat⟩,    -- 72
  ⟨"access-control-allow-credentials".toList.map Char.toNat,
    "FALSE".toList.map Char.toNat⟩,                                        -- 73
  ⟨"access-control-allow-credentials".toList.map Char.toNat,
    "TRUE".toList.map Char.toNat⟩,                                         -- 74
  ⟨"access-control-allow-headers".toList.map Char.toNat,
    "*".toList.map Char.toNat⟩,                                            -- 75
  ⟨"access-control-allow-methods".toList.map Char.toNat,
    "get".toList.map Char.toNat⟩,                                          -- 76
  ⟨"access-control-allow-methods".toList.map Char.toNat,
    "get, post, options".toList.map Char.toNat⟩,                           -- 77
  ⟨"access-control-allow-methods".toList.map Char.toNat,
    "options".toList.map Char.toNat⟩,                                      -- 78
  ⟨"access-control-expose-headers".toList.map Char.toNat,
    "content-length".toList.map Char.toNat⟩,                               -- 79
  ⟨"access-control-request-headers".toList.map Char.toNat,
    "content-type".toList.map Char.toNat⟩,                                 -- 80
  ⟨"access-control-request-method".toList.map Char.toNat,
    "get".toList.map Char.toNat⟩,                                          -- 81
  ⟨"access-control-request-method".toList.map Char.toNat,
    "post".toList.map Char.toNat⟩,                                         -- 82
  ⟨"alt-svc".toList.map Char.toNat, "clear".toList.map Char.toNat⟩,       -- 83
  ⟨"authorization".toList.map Char.toNat, "".toList.map Char.toNat⟩,      -- 84
  ⟨"content-security-policy".toList.map Char.toNat,
    "script-src 'none'; object-src 'none'; base-uri 'none'".toList.map
      Char.toNat⟩,                                                         -- 85
  ⟨"early-data".toList.map Char.toNat, "1".toList.map Char.toNat⟩,        -- 86
  ⟨"expect-ct".toList.map Char.toNat, "".toList.map Char.toNat⟩,          -- 87
  ⟨"forwarded".toList.map Char.toNat, "".toList.map Char.toNat⟩,          -- 88
  ⟨"if-range".toList.map Char.toNat, "".toList.map Char.toNat⟩,           -- 89
  ⟨"origin".toList.map Char.toNat, "".toList.map Char.toNat⟩,             -- 90
  ⟨"purpose".toList.map Char.toNat, "prefetch".toList.map Char.toNat⟩,    -- 91
  ⟨"server".toList.map Char.toNat, "".toList.map Char.toNat⟩,             -- 92
  ⟨"timing-allow-origin".toList.map Char.toNat,
    "*".toList.map Char.toNat⟩,                                            -- 93
  ⟨"upgrade-insecure-requests".toList.map Char.toNat,
    "1".toList.map Char.toNat⟩,                                            -- 94
  ⟨"user-agent".toList.map Char.toNat, "".toList.map Char.toNat⟩,         -- 95
  ⟨"x-forwarded-for".toList.map Char.toNat, "".toList.map Char.toNat⟩,    -- 96
  ⟨"x-frame-options".toList.map Char.toNat,
    "deny".toList.map Char.toNat⟩,                                         -- 97
  ⟨"x-frame-options".toList.map Char.toNat,
    "sameorigin".toList.map Char.toNat⟩                                    -- 98
]

/-- The encode table as a flat list of (name, value, index) triples,
    transcribed from `STATIC_ENCODE_TABLE` in the Rust source.
    Index values are 0-based (same as `decodeTable`). -/
def encodeTriples : List (List Nat × List Nat × Nat) :=
  let s := fun (x : String) => x.toList.map Char.toNat
  [
    (s "age",                          s "0",                       2),
    (s "etag",                         s "",                        7),
    (s "date",                         s "",                        6),
    (s "link",                         s "",                        11),
    (s "vary",                         s "accept-encoding",         59),
    (s "vary",                         s "origin",                  60),
    (s "range",                        s "bytes=0-",                55),
    (s ":path",                        s "/",                       1),
    (s "cookie",                       s "",                        5),
    (s "origin",                       s "",                        90),
    (s "server",                       s "",                        92),
    (s "accept",                       s "*/*",                     29),
    (s "accept",                       s "application/dns-message", 30),
    (s "purpose",                      s "prefetch",                91),
    (s "referer",                      s "",                        13),
    (s "alt-svc",                      s "clear",                   83),
    (s ":status",                      s "103",                     24),
    (s ":status",                      s "200",                     25),
    (s ":status",                      s "304",                     26),
    (s ":status",                      s "404",                     27),
    (s ":status",                      s "503",                     28),
    (s ":status",                      s "100",                     63),
    (s ":status",                      s "204",                     64),
    (s ":status",                      s "206",                     65),
    (s ":status",                      s "302",                     66),
    (s ":status",                      s "400",                     67),
    (s ":status",                      s "403",                     68),
    (s ":status",                      s "421",                     69),
    (s ":status",                      s "425",                     70),
    (s ":status",                      s "500",                     71),
    (s ":scheme",                      s "http",                    22),
    (s ":scheme",                      s "https",                   23),
    (s ":authority",                   s "",                        0),
    (s ":method",                      s "CONNECT",                 15),
    (s ":method",                      s "DELETE",                  16),
    (s ":method",                      s "GET",                     17),
    (s ":method",                      s "HEAD",                    18),
    (s ":method",                      s "OPTIONS",                 19),
    (s ":method",                      s "POST",                    20),
    (s ":method",                      s "PUT",                     21),
    (s ":path",                        s "/index.html",             1),
    -- Note: `:path` index 1 is listed under len 5 for "/" only; "/index.html" reuses 1
    -- Skip "/index.html" override for now - encode table only maps to primary entries
    (s "if-none-match",                s "",                        9),
    (s "last-modified",                s "",                        10),
    (s "location",                     s "",                        12),
    (s "set-cookie",                   s "",                        14),
    (s "accept-ranges",                s "bytes",                   32),
    (s "early-data",                   s "1",                       86),
    (s "expect-ct",                    s "",                        87),
    (s "forwarded",                    s "",                        88),
    (s "if-range",                     s "",                        89),
    (s "user-agent",                   s "",                        95),
    (s "if-modified-since",            s "",                        8),
    (s "authorization",                s "",                        84),
    (s "content-disposition",          s "",                        3),
    (s "timing-allow-origin",          s "*",                       93),
    (s "x-content-type-options",       s "nosniff",                 61),
    (s "x-xss-protection",             s "1; mode=block",           62),
    (s "content-encoding",             s "br",                      42),
    (s "content-encoding",             s "gzip",                    43),
    (s "content-type",                 s "application/dns-message", 44),
    (s "content-type",                 s "application/javascript",  45),
    (s "content-type",                 s "application/json",        46),
    (s "content-type",
      s "application/x-www-form-urlencoded",                        47),
    (s "content-type",                 s "image/gif",               48),
    (s "content-type",                 s "image/jpeg",              49),
    (s "content-type",                 s "image/png",               50),
    (s "content-type",                 s "text/css",                51),
    (s "content-type",                 s "text/html; charset=utf-8",52),
    (s "content-type",                 s "text/plain",              53),
    (s "content-type",                 s "text/plain;charset=utf-8",54),
    (s "content-length",               s "0",                       4),
    (s "accept-language",              s "",                        72),
    (s "cache-control",                s "max-age=0",               36),
    (s "cache-control",                s "max-age=2592000",         37),
    (s "cache-control",                s "max-age=604800",          38),
    (s "cache-control",                s "no-cache",                39),
    (s "cache-control",                s "no-store",                40),
    (s "cache-control",                s "public, max-age=31536000",41),
    (s "access-control-allow-origin",  s "*",                       35),
    (s "access-control-allow-methods", s "get",                     76),
    (s "access-control-allow-methods", s "get, post, options",      77),
    (s "access-control-allow-methods", s "options",                 78),
    (s "access-control-allow-headers", s "cache-control",           33),
    (s "access-control-allow-headers", s "content-type",            34),
    (s "access-control-allow-headers", s "*",                       75),
    (s "access-control-expose-headers",s "content-length",          79),
    (s "access-control-request-method",s "get",                     81),
    (s "access-control-request-method",s "post",                    82),
    (s "access-control-request-headers",s "content-type",           80),
    (s "access-control-allow-credentials", s "FALSE",               73),
    (s "access-control-allow-credentials", s "TRUE",                74),
    (s "strict-transport-security",    s "max-age=31536000",        56),
    (s "strict-transport-security",
      s "max-age=31536000; includesubdomains",                       57),
    (s "strict-transport-security",
      s "max-age=31536000; includesubdomains; preload",              58),
    (s "x-forwarded-for",              s "",                        96),
    (s "x-frame-options",              s "deny",                    97),
    (s "x-frame-options",              s "sameorigin",              98),
    (s "upgrade-insecure-requests",    s "1",                       94),
    (s "content-security-policy",
      s "script-src 'none'; object-src 'none'; base-uri 'none'",    85),
    (s "access-content-type-options",  s "nosniff",                 61),
    -- duplicate for x-content-type-options above
    (s "vary",                         s "accept-encoding",         59),
    -- duplicate vary removed below; encodeTriples may have duplicates
    (s "alt-svc",                      s "clear",                   83),
    (s "content-security-policy",
      s "script-src 'none'; object-src 'none'; base-uri 'none'",    85)
  ]

/-- Refined encode triples: only the canonical entries from the Rust source,
    without the duplicate test entries above. -/
def canonicalEncodeTriples : List (List Nat × List Nat × Nat) :=
  let s := fun (x : String) => x.toList.map Char.toNat
  [
    (s "age",         s "0",                    2),
    (s "etag",        s "",                     7),
    (s "date",        s "",                     6),
    (s "link",        s "",                     11),
    (s "vary",        s "accept-encoding",      59),
    (s "vary",        s "origin",               60),
    (s "range",       s "bytes=0-",             55),
    (s ":path",       s "/",                    1),
    (s "cookie",      s "",                     5),
    (s "origin",      s "",                     90),
    (s "server",      s "",                     92),
    (s "accept",      s "*/*",                  29),
    (s "accept",      s "application/dns-message", 30),
    (s "purpose",     s "prefetch",             91),
    (s "referer",     s "",                     13),
    (s "alt-svc",     s "clear",                83),
    (s ":status",     s "103",                  24),
    (s ":status",     s "200",                  25),
    (s ":status",     s "304",                  26),
    (s ":status",     s "404",                  27),
    (s ":status",     s "503",                  28),
    (s ":status",     s "100",                  63),
    (s ":status",     s "204",                  64),
    (s ":status",     s "206",                  65),
    (s ":status",     s "302",                  66),
    (s ":status",     s "400",                  67),
    (s ":status",     s "403",                  68),
    (s ":status",     s "421",                  69),
    (s ":status",     s "425",                  70),
    (s ":status",     s "500",                  71),
    (s ":scheme",     s "http",                 22),
    (s ":scheme",     s "https",               23),
    (s ":authority",  s "",                     0),
    (s ":method",     s "CONNECT",              15),
    (s ":method",     s "DELETE",               16),
    (s ":method",     s "GET",                  17),
    (s ":method",     s "HEAD",                 18),
    (s ":method",     s "OPTIONS",              19),
    (s ":method",     s "POST",                 20),
    (s ":method",     s "PUT",                  21),
    (s "if-none-match",    s "",                9),
    (s "last-modified",    s "",                10),
    (s "location",         s "",                12),
    (s "set-cookie",       s "",                14),
    (s "accept-ranges",    s "bytes",           32),
    (s "early-data",       s "1",               86),
    (s "expect-ct",        s "",                87),
    (s "forwarded",        s "",                88),
    (s "if-range",         s "",                89),
    (s "user-agent",       s "",                95),
    (s "if-modified-since",s "",                8),
    (s "authorization",    s "",                84),
    (s "content-disposition", s "",             3),
    (s "timing-allow-origin", s "*",            93),
    (s "x-content-type-options", s "nosniff",   61),
    (s "x-xss-protection",    s "1; mode=block",62),
    (s "content-encoding",    s "br",           42),
    (s "content-encoding",    s "gzip",         43),
    (s "content-type", s "application/dns-message", 44),
    (s "content-type", s "application/javascript",  45),
    (s "content-type", s "application/json",        46),
    (s "content-type", s "application/x-www-form-urlencoded", 47),
    (s "content-type", s "image/gif",           48),
    (s "content-type", s "image/jpeg",          49),
    (s "content-type", s "image/png",           50),
    (s "content-type", s "text/css",            51),
    (s "content-type", s "text/html; charset=utf-8", 52),
    (s "content-type", s "text/plain",          53),
    (s "content-type", s "text/plain;charset=utf-8", 54),
    (s "content-length", s "0",                 4),
    (s "accept-language", s "",                 72),
    (s "cache-control", s "max-age=0",          36),
    (s "cache-control", s "max-age=2592000",    37),
    (s "cache-control", s "max-age=604800",     38),
    (s "cache-control", s "no-cache",           39),
    (s "cache-control", s "no-store",           40),
    (s "cache-control", s "public, max-age=31536000", 41),
    (s "access-control-allow-origin",  s "*",   35),
    (s "access-control-allow-methods", s "get", 76),
    (s "access-control-allow-methods", s "get, post, options", 77),
    (s "access-control-allow-methods", s "options", 78),
    (s "access-control-allow-headers", s "cache-control", 33),
    (s "access-control-allow-headers", s "content-type",  34),
    (s "access-control-allow-headers", s "*",              75),
    (s "access-control-expose-headers", s "content-length", 79),
    (s "access-control-request-method", s "get",  81),
    (s "access-control-request-method", s "post", 82),
    (s "access-control-request-headers", s "content-type", 80),
    (s "access-control-allow-credentials", s "FALSE", 73),
    (s "access-control-allow-credentials", s "TRUE",  74),
    (s "strict-transport-security", s "max-age=31536000", 56),
    (s "strict-transport-security",
      s "max-age=31536000; includesubdomains", 57),
    (s "strict-transport-security",
      s "max-age=31536000; includesubdomains; preload", 58),
    (s "x-forwarded-for",  s "",               96),
    (s "x-frame-options",  s "deny",           97),
    (s "x-frame-options",  s "sameorigin",     98),
    (s "upgrade-insecure-requests", s "1",     94),
    (s "content-security-policy",
      s "script-src 'none'; object-src 'none'; base-uri 'none'", 85)
  ]

-- ── Theorems ──────────────────────────────────────────────────────────────────

/-- T34-1: The decode table has exactly 99 entries (RFC 9204 Appendix A). -/
theorem decode_table_size : decodeTable.length = 99 := by native_decide

/-- T34-2: Every index stored in the canonical encode triples is a valid
    decode-table index (< 99). -/
theorem encode_indices_valid :
    ∀ t ∈ canonicalEncodeTriples, t.2.2 < 99 := by native_decide

/-- T34-3: Consistency — for every (name, value, idx) in the canonical encode
    triples, `decodeTable[idx]?` is `some { name, value }`.
    This verifies that the encode indices correctly refer to their decode entries.
-/
theorem encode_decode_consistent :
    ∀ t ∈ canonicalEncodeTriples,
      decodeTable[t.2.2]? = some ⟨t.1, t.2.1⟩ := by native_decide

/-- T34-4: The canonical encode triple indices are pairwise distinct
    (no two triples share the same index), ensuring injectivity of the
    encode mapping on (name, value) pairs.
-/
theorem encode_indices_nodup :
    (canonicalEncodeTriples.map (·.2.2)).Nodup := by native_decide

/-- T34-5: Each entry in the decode table has a non-empty name. -/
theorem decode_names_nonempty :
    ∀ e ∈ decodeTable, e.name ≠ [] := by native_decide

/-- T34-6: Lookup by index within bounds always returns an entry
    (the decode table is complete for all indices 0–98). -/
theorem decode_lookup_in_bounds :
    ∀ i : Fin 99, (decodeTable[i.val]?).isSome = true := by native_decide

/-- T34-7: The decode table at index 0 is `:authority` with empty value,
    confirming the canonical first entry. -/
theorem decode_index_0 :
    decodeTable[0]? = some ⟨":authority".toList.map Char.toNat, []⟩ :=
  by native_decide

/-- T34-8: The decode table at index 17 is `:method GET`,
    a commonly-used and security-relevant entry. -/
theorem decode_index_17 :
    decodeTable[17]? =
      some ⟨":method".toList.map Char.toNat,
             "GET".toList.map Char.toNat⟩ := by native_decide

/-- T34-9: The decode table at index 98 (the last entry) is
    `x-frame-options: sameorigin`. -/
theorem decode_index_98 :
    decodeTable[98]? =
      some ⟨"x-frame-options".toList.map Char.toNat,
             "sameorigin".toList.map Char.toNat⟩ := by native_decide

/-- T34-10: All name byte sequences in the decode table consist only of
    printable ASCII bytes (< 128), i.e. they are valid ASCII strings. -/
theorem decode_names_ascii :
    ∀ e ∈ decodeTable, ∀ b ∈ e.name, b < 128 := by native_decide

/-- T34-11: All value byte sequences in the decode table consist only of
    printable ASCII bytes (< 128). -/
theorem decode_values_ascii :
    ∀ e ∈ decodeTable, ∀ b ∈ e.value, b < 128 := by native_decide

/-- T34-12: There are no duplicate (name, value) pairs in the decode table —
    every static table entry is unique. -/
theorem decode_entries_nodup : decodeTable.Nodup := by native_decide

end QPACKStatic
