-- Copyright (C) 2018-2025, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- formal-verification/tests/ack_delay_codec/lean_eval.lean
--
-- Route-B correspondence test — Lean side.
-- Evaluates the AckDelayCodec model on the shared test cases and prints
-- results in the same CSV format as ack_delay_codec_test.rs.
--
-- Run (from formal-verification/lean/):
--   lean ../tests/ack_delay_codec/lean_eval.lean
--
-- The AckDelayCodec model is inlined here so this file can be run
-- standalone without lake (lean --stdin also works).

-- ---------------------------------------------------------------------------
-- Inline model (from FVSquad/AckDelayCodec.lean)
-- ---------------------------------------------------------------------------
namespace AckDelayCodecModel

/-- Encode: divide raw microsecond delay by 2^exp (integer division). -/
def encode (delayMicros : Nat) (exp : Nat) : Nat :=
  delayMicros / 2^exp

/-- Decode: multiply wire-encoded value by 2^exp. -/
def decode (encoded : Nat) (exp : Nat) : Nat :=
  encoded * 2^exp

end AckDelayCodecModel

-- ---------------------------------------------------------------------------
-- Shared test cases (mirrors ack_delay_codec_test.rs)
-- Fields: (delayMicros, exp, description)
-- ---------------------------------------------------------------------------
def testCases : List (Nat × Nat × String) := [
  -- exp = 0: encode/decode are identity
  (0,     0, "exp=0 delay=0"),
  (1,     0, "exp=0 delay=1"),
  (1000,  0, "exp=0 delay=1000"),
  (65535, 0, "exp=0 delay=65535"),

  -- exp = 1
  (0,     1, "exp=1 delay=0"),
  (1,     1, "exp=1 delay=1 (truncated)"),
  (2,     1, "exp=1 delay=2 (exact)"),
  (1000,  1, "exp=1 delay=1000"),
  (1001,  1, "exp=1 delay=1001 (truncated)"),

  -- exp = 2
  (0,     2, "exp=2 delay=0"),
  (3,     2, "exp=2 delay=3 (truncated)"),
  (4,     2, "exp=2 delay=4 (exact)"),
  (100,   2, "exp=2 delay=100"),
  (101,   2, "exp=2 delay=101 (truncated)"),

  -- exp = 3 (QUIC default)
  (0,     3, "exp=3 delay=0"),
  (7,     3, "exp=3 delay=7 (truncated)"),
  (8,     3, "exp=3 delay=8 (exact)"),
  (1000,  3, "exp=3 delay=1000 (exact: 1000/8=125)"),
  (1001,  3, "exp=3 delay=1001 (truncated)"),
  (25000, 3, "exp=3 delay=25ms in micros"),

  -- exp = 10
  (0,      10, "exp=10 delay=0"),
  (1023,   10, "exp=10 delay=1023 (truncated)"),
  (1024,   10, "exp=10 delay=1024 (exact)"),
  (100000, 10, "exp=10 delay=100000"),

  -- exp = 20 (maximum)
  (0,              20, "exp=20 delay=0"),
  (1048575,        20, "exp=20 delay=2^20-1 (truncated)"),
  (1048576,        20, "exp=20 delay=2^20 (exact)"),
  (1000000000000,  20, "exp=20 large delay"),

  -- Round-trip: decode(encode(d,e),e) = d - (d % 2^e)
  (800,  3, "RT exp=3 delay=800 (multiple of 8)"),
  (1600, 4, "RT exp=4 delay=1600 (multiple of 16)"),
  (3072, 6, "RT exp=6 delay=3072 (multiple of 64)")
]

open AckDelayCodecModel

def evalCases : IO Unit := do
  IO.println "# Lean AckDelayCodec evaluation"
  IO.println "# delay_micros,exp,lean_encoded,lean_decoded_rt,description"
  for (delay, exp, desc) in testCases do
    let enc := encode delay exp
    let dec := decode enc exp
    IO.println s!"{delay},{exp},{enc},{dec},\"{desc}\""
  IO.println s!"# Total cases: {testCases.length}"

#eval evalCases
