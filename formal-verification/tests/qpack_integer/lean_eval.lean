-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — Route-B correspondence test harness for T45 (QPACKInteger).
--
-- This file evaluates `encodeInt` and `decodeInt` (the Lean model from
-- `FVSquad/QPACKInteger.lean`) on 25 test cases and compares the results
-- against expected values derived from:
--   - RFC 7541 §5.1 canonical examples (cases 1–3)
--   - Rust encoder/decoder test cases in `quiche/src/h3/qpack/encoder.rs`
--     and `quiche/src/h3/qpack/decoder.rs` (cases 1–3 overlap)
--   - Additional boundary and stress cases (cases 4–25)
--
-- Expected values were computed by manual application of the RFC 7541 §5.1
-- algorithm and cross-checked against the Rust `encode_int`/`decode_int`
-- tests that ship with quiche.
--
-- Run with:
--   lean lean_eval.lean
--
-- A PASS on all 25 cases confirms the Lean model faithfully reproduces
-- the Rust implementation on these inputs.

-- Inline model (from FVSquad/QPACKInteger.lean)

def encodeAux (v : Nat) : List Nat :=
  if v < 128 then [v]
  else (v % 128 + 128) :: encodeAux (v / 128)
termination_by v
decreasing_by apply Nat.div_lt_self <;> omega

def encodeInt (v : Nat) (p : Nat) : List Nat :=
  let mask := 2 ^ p - 1
  if v < mask then [v]
  else mask :: encodeAux (v - mask)

def decodeAux : List Nat -> Option Nat
  | []        => none
  | b :: rest =>
    if b < 128 then some b
    else match decodeAux rest with
         | none   => none
         | some r => some (b % 128 + 128 * r)

def decodeInt (bytes : List Nat) (p : Nat) : Option Nat :=
  let mask := 2 ^ p - 1
  match bytes with
  | []       => none
  | b :: rest =>
    let v := b % (2 ^ p)
    if v < mask then some v
    else match decodeAux rest with
         | none   => none
         | some r => some (mask + r)

-- Helpers

def checkEnc (n : Nat) (v p : Nat) (expected : List Nat) : IO Unit := do
  let result := encodeInt v p
  if result == expected then
    IO.println s!"  case {n}: PASS  encodeInt {v} {p} = {expected}"
  else do
    IO.println s!"  case {n}: FAIL  encodeInt {v} {p}"
    IO.println s!"    got      : {result}"
    IO.println s!"    expected : {expected}"

def checkDec (n : Nat) (bytes : List Nat) (p : Nat) (expected : Option Nat)
    : IO Unit := do
  let result := decodeInt bytes p
  if result == expected then
    IO.println s!"  case {n}: PASS  decodeInt {bytes} {p} = {expected}"
  else do
    IO.println s!"  case {n}: FAIL  decodeInt {bytes} {p}"
    IO.println s!"    got      : {result}"
    IO.println s!"    expected : {expected}"

def checkRT (n : Nat) (v p : Nat) : IO Unit := do
  let encoded := encodeInt v p
  let result  := decodeInt encoded p
  if result == some v then
    IO.println s!"  case {n}: PASS  round-trip v={v} p={p}"
  else do
    IO.println s!"  case {n}: FAIL  round-trip v={v} p={p}"
    IO.println s!"    encoded  : {encoded}"
    IO.println s!"    decoded  : {result}"

-- Test suite

def main : IO Unit := do
  IO.println "=== T45 QPACKInteger Route-B correspondence tests ==="

  -- RFC 7541 / Rust canonical examples
  checkEnc 1 10 5 [10]
  checkEnc 2 1337 5 [31, 154, 10]
  checkEnc 3 42 8 [42]
  checkDec 4 [10, 2] 5 (some 10)
  checkDec 5 [31, 154, 10] 5 (some 1337)
  checkDec 6 [42] 8 (some 42)

  -- Single-byte boundary cases
  checkEnc 7 0 5 [0]
  checkEnc 8 30 5 [30]
  checkEnc 9 31 5 [31, 0]
  checkEnc 10 0 1 [0]
  checkEnc 11 1 1 [1, 0]
  checkEnc 12 126 7 [126]
  checkEnc 13 127 7 [127, 0]

  -- Multi-byte cases
  -- encode 255 with 5-bit prefix:
  --   mask=31, residual=224; 224>=128 -> 224%128+128=224, 224/128=1 -> [224,1]
  checkEnc 14 255 5 [31, 224, 1]

  -- encode 256 with 5-bit prefix:
  --   residual=225; 225>=128 -> 225%128+128=225, 225/128=1 -> [225,1]
  checkEnc 15 256 5 [31, 225, 1]

  -- encode 128 with 5-bit prefix:
  --   residual=97 < 128 -> [31, 97]
  checkEnc 16 128 5 [31, 97]

  -- encode 16384 with 5-bit prefix:
  --   residual=16353; 16353%128=97, 97+128=225; 16353/128=127 < 128 -> [31,225,127]
  checkEnc 17 16384 5 [31, 225, 127]

  checkEnc 18 0 3 [0]
  checkEnc 19 7 3 [7, 0]

  -- Round-trip cases
  checkRT 20 0 5
  checkRT 21 1337 5
  checkRT 22 100 3
  checkRT 23 16383 5
  checkRT 24 255 8
  checkRT 25 0 1

  IO.println "=== done ==="
