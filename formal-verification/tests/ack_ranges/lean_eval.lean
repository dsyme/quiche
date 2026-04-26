-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — Route-B correspondence test harness for T43 (AckRanges).
--
-- This file evaluates `decodeAckBlocks` (the Lean model from
-- `FVSquad/AckRanges.lean`) on 25 test cases and compares the results
-- against manually-computed expected values derived from the Rust
-- `parse_ack_frame` loop in `quiche/src/frame.rs:1257–1311`.
--
-- Run with:
--   lean lean_eval.lean
--
-- All 25 tests are expressed as `#eval` + `if … then "PASS" else "FAIL"`.
-- If any FAIL appears in the output the harness is failing.

-- Inline the model (duplicated from FVSquad/AckRanges.lean so this file
-- is self-contained).
abbrev AckRange := Nat × Nat

def decodeAckBlocks (la ab : Nat) (blocks : List (Nat × Nat))
    : Option (List AckRange) :=
  if _h : la < ab then none
  else
    let sm0 := la - ab
    let rec loop (sm : Nat) (acc : List AckRange)
        : List (Nat × Nat) → Option (List AckRange)
      | [] => some acc.reverse
      | (gap, blk) :: rest =>
        if sm < 2 + gap then none
        else
          let lg := (sm - gap) - 2
          if lg < blk then none
          else loop (lg - blk) ((lg - blk, lg) :: acc) rest
    loop sm0 [(sm0, la)] blocks

-- ── helpers ──────────────────────────────────────────────────────────────

def check (n : Nat) (result expected : Option (List AckRange)) : IO Unit := do
  if result == expected then
    IO.println s!"  case {n}: PASS"
  else do
    IO.println s!"  case {n}: FAIL"
    IO.println s!"    got      : {result}"
    IO.println s!"    expected : {expected}"

def checkBool (n : Nat) (result expected : Bool) : IO Unit := do
  if result == expected then
    IO.println s!"  case {n}: PASS"
  else
    IO.println s!"  case {n}: FAIL  (got {result}, expected {expected})"

-- ── test suite ───────────────────────────────────────────────────────────

def main : IO Unit := do
  IO.println "=== T43 AckRanges Route-B correspondence tests ==="

  -- 1. Single block, no additional blocks
  check 1 (decodeAckBlocks 10 3 []) (some [(7, 10)])

  -- 2. Single block covering entire range [0..la]
  check 2 (decodeAckBlocks 5 5 []) (some [(0, 5)])

  -- 3. Zero-span block (la = ab = 0)
  check 3 (decodeAckBlocks 0 0 []) (some [(0, 0)])

  -- 4. First-block underflow → none
  check 4 (decodeAckBlocks 3 5 []) none

  -- 5. Two blocks, standard case: la=20 ab=4 gap=2 blk=3
  --    first=(16,20), lg=(16-2)-2=12, sm'=12-3=9 → second=(9,12)
  check 5 (decodeAckBlocks 20 4 [(2, 3)]) (some [(16, 20), (9, 12)])

  -- 6. Three blocks: la=100 ab=10 → first=(90,100)
  --    gap=5 blk=8 → lg=(90-5)-2=83 sm'=75 → (75,83)
  --    gap=3 blk=4 → lg=(75-3)-2=70 sm'=66 → (66,70)
  check 6 (decodeAckBlocks 100 10 [(5, 8), (3, 4)])
    (some [(90, 100), (75, 83), (66, 70)])

  -- 7. Loop gap underflow: smallest=7 gap=6 → 7 < 8 → none
  check 7 (decodeAckBlocks 10 3 [(6, 0)]) none

  -- 8. Loop blk underflow: lg=4 blk=20 → 4 < 20 → none
  check 8 (decodeAckBlocks 10 3 [(2, 20)]) none

  -- 9. Zero gap (minimum gap=0): la=10 ab=0 gap=0 blk=0
  --    first=(10,10), lg=(10-0)-2=8 sm'=8 → (8,8)
  check 9 (decodeAckBlocks 10 0 [(0, 0)]) (some [(10, 10), (8, 8)])

  -- 10. Minimal gap=0 blk=0 repeated
  check 10 (decodeAckBlocks 20 0 [(0, 0), (0, 0)])
    (some [(20, 20), (18, 18), (16, 16)])

  -- 11. la=0 ab=0 no blocks
  check 11 (decodeAckBlocks 0 0 []) (some [(0, 0)])

  -- 12. Large values: la=1000 ab=100 gap=50 blk=200
  --     first=(900,1000), lg=(900-50)-2=848 sm'=648 → (648,848)
  check 12 (decodeAckBlocks 1000 100 [(50, 200)])
    (some [(900, 1000), (648, 848)])

  -- 13. ab = la (single point): la=7 ab=7
  check 13 (decodeAckBlocks 7 7 []) (some [(0, 7)])

  -- 14. Four blocks with zero-span second range
  --     la=50 ab=5 → first=(45,50)
  --     gap=0 blk=0 → lg=43 sm'=43 → (43,43)
  --     gap=0 blk=0 → lg=41 sm'=41 → (41,41)
  --     gap=0 blk=0 → lg=39 sm'=39 → (39,39)
  check 14 (decodeAckBlocks 50 5 [(0, 0), (0, 0), (0, 0)])
    (some [(45, 50), (43, 43), (41, 41), (39, 39)])

  -- 15. Exact boundary: sm=2 gap=0 blk=0 → sm=2 ≥ 2+0 OK, lg=0 sm'=0
  --     la=2 ab=0 → first=(2,2), gap=0 blk=0 → lg=0 sm'=0 → (0,0)
  check 15 (decodeAckBlocks 2 0 [(0, 0)]) (some [(2, 2), (0, 0)])

  -- 16. sm exactly equals 2+gap (boundary pass): sm=5 gap=3 → sm=5=2+3 OK
  --     la=8 ab=3 → sm0=5, gap=3 blk=0 → sm=5 ≥ 5 OK, lg=0 sm'=0 → (0,0)
  check 16 (decodeAckBlocks 8 3 [(3, 0)]) (some [(5, 8), (0, 0)])

  -- 17. sm=4 gap=3 → sm=4 < 2+3=5 → fail
  check 17 (decodeAckBlocks 7 3 [(3, 0)]) none

  -- 18. All ranges valid: sample from §6 example in AckRanges.lean
  checkBool 18 ((decodeAckBlocks 100 10 [(5, 8), (3, 4)]).map
    (fun rs => rs.all (fun r => r.1 ≤ r.2)) == some true) true

  -- 19. All ranges bounded by la=100
  checkBool 19 ((decodeAckBlocks 100 10 [(5, 8), (3, 4)]).map
    (fun rs => rs.all (fun r => r.2 ≤ 100)) == some true) true

  -- 20. Strict monotone decrease check
  checkBool 20 ((decodeAckBlocks 100 10 [(5, 8), (3, 4)]).map (fun rs =>
    (List.zip rs rs.tail).all (fun (r1, r2) => r2.2 + 2 ≤ r1.1)) == some true) true

  -- 21. la=1 ab=0 gap=0 blk=0 → first=(1,1), lg=(1-0)-2 = underflow → none
  --     In Nat: 1-0-2 = 0 (saturated), 0 < 0 is false so blk check: 0 ≥ 0 OK
  --     sm' = 0-0 = 0 → (0,0)
  check 21 (decodeAckBlocks 1 0 [(0, 0)]) none

  -- 22. la=2 ab=0 gap=0 blk=0 → sm=2, lg=(2-0)-2=0, sm'=0 → first=(2,2),(0,0)
  --     (boundary: sm=2 ≥ 2+0=2, OK)
  check 22 (decodeAckBlocks 2 0 [(0, 0)]) (some [(2, 2), (0, 0)])

  -- 23. Non-empty on valid input
  checkBool 23 (decodeAckBlocks 50 0 [(0, 0), (0, 0)]).isSome true

  -- 24. Large block count (5 blocks)
  --     la=50 ab=2 → sm0=48, first=(48,50)
  --     gap=1 blk=0 → lg=45 sm'=45 → (45,45)
  --     gap=1 blk=0 → lg=42 sm'=42 → (42,42)
  --     gap=1 blk=0 → lg=39 sm'=39 → (39,39)
  --     gap=1 blk=0 → lg=36 sm'=36 → (36,36)
  check 24 (decodeAckBlocks 50 2 [(1,0),(1,0),(1,0),(1,0)])
    (some [(48,50),(45,45),(42,42),(39,39),(36,36)])

  -- 25. Underflow on second block after success on first
  --     la=10 ab=2 → sm=8, first=(8,10)
  --     gap=0 blk=0 → lg=6 sm'=6 → (6,6)
  --     gap=0 blk=10 → lg=4, 4<10 → none
  check 25 (decodeAckBlocks 10 2 [(0,0),(0,10)]) none

  IO.println "=== done ==="
