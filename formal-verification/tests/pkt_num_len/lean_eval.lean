-- Copyright (C) 2024, Cloudflare, Inc.
-- BSD license. See LICENSE for details.
--
-- formal-verification/tests/pkt_num_len/lean_eval.lean
--
-- Route-B correspondence test — Lean side.
-- Evaluates the PacketNumLen model on the shared test cases and prints
-- results in the same CSV format as pkt_num_len_test.rs.
--
-- Run (from formal-verification/lean/):
--   lean ../tests/pkt_num_len/lean_eval.lean
--
-- The PacketNumLen model is inlined here so this file can be run
-- standalone without lake (lean --stdin also works).

-- ---------------------------------------------------------------------------
-- Inline model (from FVSquad/PacketNumLen.lean)
-- ---------------------------------------------------------------------------
namespace PacketNumLen

def numUnacked (pn la : Nat) : Nat := pn - la + 1

def pktNumLen (pn la : Nat) : Nat :=
  if numUnacked pn la ≤ 127 then 1
  else if numUnacked pn la ≤ 32767 then 2
  else if numUnacked pn la ≤ 8388607 then 3
  else 4

end PacketNumLen

-- ---------------------------------------------------------------------------
-- Shared test cases (mirrors pkt_num_len_test.rs)
-- ---------------------------------------------------------------------------
def testCases : List (Nat × Nat × String) := [
  (0,           0,        "numUnacked=1 (min)"),
  (1,           0,        "numUnacked=2"),
  (126,         0,        "numUnacked=127 (last 1-byte)"),
  (127,         0,        "numUnacked=128 (first 2-byte)"),
  (100,         0,        "numUnacked=101"),
  (1000,        0,        "numUnacked=1001"),
  (32766,       0,        "numUnacked=32767 (last 2-byte)"),
  (32767,       0,        "numUnacked=32768 (first 3-byte)"),
  (8388606,     0,        "numUnacked=8388607 (last 3-byte)"),
  (8388607,     0,        "numUnacked=8388608 (first 4-byte)"),
  (10000000,    0,        "numUnacked=10000001"),
  (5,           10,       "pn < la: numUnacked=1 (saturating)"),
  (42,          42,       "pn=la: numUnacked=1"),
  (1126,        1000,     "numUnacked=127 (last 1-byte, offset base)"),
  (1127,        1000,     "numUnacked=128 (first 2-byte, offset base)"),
  (11295746,    11266227, "RFC A.2: pn=0xac5c02 la=0xabe8b3"),
  (11332094,    11266227, "RFC A.2: pn=0xace9fe la=0xabe8b3"),
  (2147483646,  0,        "numUnacked=2^31-1 (QUIC valid max)")
]

open PacketNumLen

def evalCases : IO Unit := do
  IO.println "# Lean pktNumLen evaluation"
  IO.println "# pn,la,lean_result,numUnacked,description"
  for (pn, la, desc) in testCases do
    let nu  := numUnacked pn la
    let len := pktNumLen pn la
    IO.println s!"{pn},{la},{len},{nu},\"{desc}\""
  IO.println s!"# Total cases: {testCases.length}"

#eval evalCases
