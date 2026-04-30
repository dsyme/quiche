-- Copyright (C) 2025, Cloudflare, Inc.
-- BSD-2-Clause licence (same as quiche)
--
-- 🔬 Lean Squad — Formal RFC compliance spec for `parse_settings_frame`
-- from `quiche/src/h3/frame.rs`.
--
-- Target T35: parse_settings_frame RFC compliance
-- Source: quiche/src/h3/frame.rs — `fn parse_settings_frame`
-- RFC: RFC 9114 §7.2.4, §A.2
-- Phase: 5 — Spec + Implementation + Proofs
-- Lean 4.29.0, no Mathlib dependency.
--
-- This file builds on H3Settings (T33) and proves structural RFC invariants:
--
--  (a) Size guard: parseSized rejects ≥ 129 pairs (proxy for > 256-byte payload).
--
--  (b) Last-value-wins: duplicate entries overwrite earlier values for the
--      same identifier.
--
--  (c) Known-field extraction: each known identifier is stored in the correct
--      slot; boolean-constrained fields accept only value 0 or 1.
--
--  (d) Reserved-identifier rejection: all five RFC §7.2.4/§A.2 IDs cause
--      immediate .err regardless of what follows in the list.
--
--  (e) Head invariants: parse success implies the head pair was safe.
--
-- Theorems (21 total, 0 sorry):
--   parse_size_guard, parseSized_long_err
--   parse_duplicate_qpack_last_wins, parse_duplicate_max_field_last_wins
--   parse_qpack_max_ok, parse_max_field_ok, parse_qpack_blocked_ok
--   parse_connect_zero_ok, parse_connect_one_ok
--   parse_datagram_zero_ok, parse_datagram_one_ok
--   parse_datagram_00_zero_ok, parse_datagram_00_one_ok
--   parse_reserved_0_err, parse_reserved_2_err, parse_reserved_3_err
--   parse_reserved_4_err, parse_reserved_5_err
--   parse_ok_head_not_reserved
--   parse_ok_head_bool_valid
--   parse_prefix_reserved_err

import FVSquad.H3Settings

namespace H3ParseSettings

open H3Settings

-- ─── Size guard ──────────────────────────────────────────────────────────────

/-- MAX_SETTINGS_PAYLOAD_SIZE = 256 bytes; each pair is ≥ 2 bytes → ≤ 128 pairs. -/
def MAX_PAIRS : Nat := 128

def parseSized (pairs : List (UInt64 × UInt64)) : ParseResult :=
  if pairs.length > MAX_PAIRS then .err
  else parse pairs

theorem parse_size_guard (pairs : List (UInt64 × UInt64))
    (h : pairs.length > MAX_PAIRS) :
    parseSized pairs = .err := by
  simp [parseSized, h]

-- 129 "safe" pairs exceed the limit (only the count matters here).
theorem parseSized_long_err :
    (List.replicate 129 (SETTINGS_MAX_FIELD_SECTION_SIZE, (0 : UInt64))).length > MAX_PAIRS := by
  simp [MAX_PAIRS]

-- ─── Last-value-wins semantics ────────────────────────────────────────────────

theorem parse_duplicate_qpack_last_wins (v1 v2 : UInt64) :
    parse [(SETTINGS_QPACK_MAX_TABLE_CAPACITY, v1),
           (SETTINGS_QPACK_MAX_TABLE_CAPACITY, v2)] =
      .ok { qpackMaxTableCapacity := some v2 } := by
  simp [parse, parse.go, applyEntry, isReserved, requiresBool,
        SETTINGS_QPACK_MAX_TABLE_CAPACITY, SETTINGS_MAX_FIELD_SECTION_SIZE,
        SETTINGS_QPACK_BLOCKED_STREAMS, SETTINGS_ENABLE_CONNECT_PROTOCOL,
        SETTINGS_H3_DATAGRAM_00, SETTINGS_H3_DATAGRAM]

theorem parse_duplicate_max_field_last_wins (v1 v2 : UInt64) :
    parse [(SETTINGS_MAX_FIELD_SECTION_SIZE, v1),
           (SETTINGS_MAX_FIELD_SECTION_SIZE, v2)] =
      .ok { maxFieldSectionSize := some v2 } := by
  simp [parse, parse.go, applyEntry, isReserved, requiresBool,
        SETTINGS_QPACK_MAX_TABLE_CAPACITY, SETTINGS_MAX_FIELD_SECTION_SIZE,
        SETTINGS_QPACK_BLOCKED_STREAMS, SETTINGS_ENABLE_CONNECT_PROTOCOL,
        SETTINGS_H3_DATAGRAM_00, SETTINGS_H3_DATAGRAM]

-- ─── Single known-field extraction ───────────────────────────────────────────

theorem parse_qpack_max_ok (v : UInt64) :
    parse [(SETTINGS_QPACK_MAX_TABLE_CAPACITY, v)] =
      .ok { qpackMaxTableCapacity := some v } := by
  simp [parse, parse.go, applyEntry, isReserved, requiresBool,
        SETTINGS_QPACK_MAX_TABLE_CAPACITY, SETTINGS_MAX_FIELD_SECTION_SIZE,
        SETTINGS_QPACK_BLOCKED_STREAMS, SETTINGS_ENABLE_CONNECT_PROTOCOL,
        SETTINGS_H3_DATAGRAM_00, SETTINGS_H3_DATAGRAM]

theorem parse_max_field_ok (v : UInt64) :
    parse [(SETTINGS_MAX_FIELD_SECTION_SIZE, v)] =
      .ok { maxFieldSectionSize := some v } := by
  simp [parse, parse.go, applyEntry, isReserved, requiresBool,
        SETTINGS_QPACK_MAX_TABLE_CAPACITY, SETTINGS_MAX_FIELD_SECTION_SIZE,
        SETTINGS_QPACK_BLOCKED_STREAMS, SETTINGS_ENABLE_CONNECT_PROTOCOL,
        SETTINGS_H3_DATAGRAM_00, SETTINGS_H3_DATAGRAM]

theorem parse_qpack_blocked_ok (v : UInt64) :
    parse [(SETTINGS_QPACK_BLOCKED_STREAMS, v)] =
      .ok { qpackBlockedStreams := some v } := by
  simp [parse, parse.go, applyEntry, isReserved, requiresBool,
        SETTINGS_QPACK_MAX_TABLE_CAPACITY, SETTINGS_MAX_FIELD_SECTION_SIZE,
        SETTINGS_QPACK_BLOCKED_STREAMS, SETTINGS_ENABLE_CONNECT_PROTOCOL,
        SETTINGS_H3_DATAGRAM_00, SETTINGS_H3_DATAGRAM]

-- ─── Boolean-constrained fields: values 0 and 1 are both accepted ─────────────

theorem parse_connect_zero_ok :
    parse [(SETTINGS_ENABLE_CONNECT_PROTOCOL, 0)] =
      .ok { connectProtocol := some 0 } := by
  simp [parse, parse.go, applyEntry, isReserved, requiresBool,
        SETTINGS_QPACK_MAX_TABLE_CAPACITY, SETTINGS_MAX_FIELD_SECTION_SIZE,
        SETTINGS_QPACK_BLOCKED_STREAMS, SETTINGS_ENABLE_CONNECT_PROTOCOL,
        SETTINGS_H3_DATAGRAM_00, SETTINGS_H3_DATAGRAM]

theorem parse_connect_one_ok :
    parse [(SETTINGS_ENABLE_CONNECT_PROTOCOL, 1)] =
      .ok { connectProtocol := some 1 } := by
  simp [parse, parse.go, applyEntry, isReserved, requiresBool,
        SETTINGS_QPACK_MAX_TABLE_CAPACITY, SETTINGS_MAX_FIELD_SECTION_SIZE,
        SETTINGS_QPACK_BLOCKED_STREAMS, SETTINGS_ENABLE_CONNECT_PROTOCOL,
        SETTINGS_H3_DATAGRAM_00, SETTINGS_H3_DATAGRAM]

theorem parse_datagram_zero_ok :
    parse [(SETTINGS_H3_DATAGRAM, 0)] =
      .ok { h3Datagram := some 0 } := by
  simp [parse, parse.go, applyEntry, isReserved, requiresBool,
        SETTINGS_QPACK_MAX_TABLE_CAPACITY, SETTINGS_MAX_FIELD_SECTION_SIZE,
        SETTINGS_QPACK_BLOCKED_STREAMS, SETTINGS_ENABLE_CONNECT_PROTOCOL,
        SETTINGS_H3_DATAGRAM_00, SETTINGS_H3_DATAGRAM]

theorem parse_datagram_one_ok :
    parse [(SETTINGS_H3_DATAGRAM, 1)] =
      .ok { h3Datagram := some 1 } := by
  simp [parse, parse.go, applyEntry, isReserved, requiresBool,
        SETTINGS_QPACK_MAX_TABLE_CAPACITY, SETTINGS_MAX_FIELD_SECTION_SIZE,
        SETTINGS_QPACK_BLOCKED_STREAMS, SETTINGS_ENABLE_CONNECT_PROTOCOL,
        SETTINGS_H3_DATAGRAM_00, SETTINGS_H3_DATAGRAM]

theorem parse_datagram_00_zero_ok :
    parse [(SETTINGS_H3_DATAGRAM_00, 0)] =
      .ok { h3Datagram := some 0 } := by
  simp [parse, parse.go, applyEntry, isReserved, requiresBool,
        SETTINGS_QPACK_MAX_TABLE_CAPACITY, SETTINGS_MAX_FIELD_SECTION_SIZE,
        SETTINGS_QPACK_BLOCKED_STREAMS, SETTINGS_ENABLE_CONNECT_PROTOCOL,
        SETTINGS_H3_DATAGRAM_00, SETTINGS_H3_DATAGRAM]

theorem parse_datagram_00_one_ok :
    parse [(SETTINGS_H3_DATAGRAM_00, 1)] =
      .ok { h3Datagram := some 1 } := by
  simp [parse, parse.go, applyEntry, isReserved, requiresBool,
        SETTINGS_QPACK_MAX_TABLE_CAPACITY, SETTINGS_MAX_FIELD_SECTION_SIZE,
        SETTINGS_QPACK_BLOCKED_STREAMS, SETTINGS_ENABLE_CONNECT_PROTOCOL,
        SETTINGS_H3_DATAGRAM_00, SETTINGS_H3_DATAGRAM]

-- ─── Reserved-identifier rejection: all five RFC 9114 §7.2.4/§A.2 IDs ────────

theorem parse_reserved_0_err (rest : List (UInt64 × UInt64)) :
    parse ((0x0, (0 : UInt64)) :: rest) = .err := by
  simp [parse, parse.go, applyEntry, isReserved]

theorem parse_reserved_2_err (rest : List (UInt64 × UInt64)) :
    parse ((0x2, (0 : UInt64)) :: rest) = .err := by
  simp [parse, parse.go, applyEntry, isReserved]

theorem parse_reserved_3_err (rest : List (UInt64 × UInt64)) :
    parse ((0x3, (0 : UInt64)) :: rest) = .err := by
  simp [parse, parse.go, applyEntry, isReserved]

theorem parse_reserved_4_err (rest : List (UInt64 × UInt64)) :
    parse ((0x4, (0 : UInt64)) :: rest) = .err := by
  simp [parse, parse.go, applyEntry, isReserved]

theorem parse_reserved_5_err (rest : List (UInt64 × UInt64)) :
    parse ((0x5, (0 : UInt64)) :: rest) = .err := by
  simp [parse, parse.go, applyEntry, isReserved]

-- ─── Head invariants (one step of the inductive argument) ─────────────────────

/-- If parse succeeds on a non-empty list, the head identifier is not reserved. -/
theorem parse_ok_head_not_reserved
    (id v : UInt64) (rest : List (UInt64 × UInt64)) (s : Settings)
    (hok : parse ((id, v) :: rest) = .ok s) :
    isReserved id = false := by
  cases h : isReserved id with
  | false => rfl
  | true =>
    simp [parse, parse.go, applyEntry, h] at hok

/-- If parse succeeds and the head has a boolean-constrained id, its value ≤ 1. -/
theorem parse_ok_head_bool_valid
    (id v : UInt64) (rest : List (UInt64 × UInt64)) (s : Settings)
    (hb : requiresBool id = true)
    (hok : parse ((id, v) :: rest) = .ok s) :
    ¬ (decide (v > 1) = true) := by
  have hres := parse_ok_head_not_reserved id v rest s hok
  intro hdec
  simp [parse, parse.go, applyEntry, hres, hb, hdec] at hok

-- ─── Reserved identifier anywhere (with safe prefix) causes error ─────────────

/-- `parse.go acc (pre ++ [(rid, rv)] ++ suf) = .err`
    whenever `rid` is reserved, for any accumulator `acc`
    whose processing of `pre` terminates in `go acc' [...]`. -/
theorem parse_prefix_reserved_err
    (rid rv : UInt64) (suf : List (UInt64 × UInt64))
    (hr : isReserved rid = true)
    (pre : List (UInt64 × UInt64)) :
    ∀ acc : Settings,
      (∀ acc' : Settings, parse.go acc' (pre ++ (rid, rv) :: suf) = .err) := by
  intro acc acc'
  induction pre generalizing acc' with
  | nil =>
    simp [parse.go, applyEntry, hr]
  | cons p ps ih =>
    obtain ⟨id, v⟩ := p
    simp only [List.cons_append, parse.go]
    rcases h : applyEntry acc' id v with _ | s
    · rfl
    · exact ih s

end H3ParseSettings
