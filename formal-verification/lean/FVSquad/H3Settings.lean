-- Copyright (C) 2025, Cloudflare, Inc.
-- BSD-2-Clause licence (same as quiche)
--
-- 🔬 Lean Squad — Formal specification of `Frame::Settings` parsing
-- invariants from `quiche/src/h3/frame.rs`.
--
-- Target T33: H3 Settings Frame invariants
-- Source: quiche/src/h3/frame.rs — `parse_settings_frame`, `Frame::Settings`
-- RFC: RFC 9114 §7.2.4
-- Phase: 4/5 — Spec + Implementation + Proofs
-- Lean 4.30.0-rc2, no Mathlib dependency.
--
-- Model: the byte-level varint codec is abstracted away.  We model the
--        settings payload as a list of (identifier, value) pairs, already
--        decoded from their varint representation.
--
-- Omitted: byte-buffer I/O (`octets::Octets`), `to_bytes` serialisation,
--          GREASE identifiers, MAX_SETTINGS_PAYLOAD_SIZE byte-count check
--          (modelled as a List length bound), `raw` field,
--          duplicate-entry last-value-wins (modelled, not independently tested).
--
-- Theorems (16 total, 0 sorry):
--   isReserved_{0,2,3,4,5}_true, isReserved_1_false, isReserved_6_false
--   requiresBool_connect, requiresBool_datagram_00, requiresBool_datagram
--   requiresBool_qpack_max_false, requiresBool_qpack_blk_false
--   applyEntry_reserved_none
--   applyEntry_connect_gt1_none, applyEntry_datagram_gt1_none
--   parse_empty, parse_reserved_id_err
--   parse_connect_gt1_err, parse_datagram_gt1_err
--   parse_single_qpack_ok

namespace H3Settings

-- ─── Identifier constants ────────────────────────────────────────────────────

def SETTINGS_QPACK_MAX_TABLE_CAPACITY : UInt64 := 0x1
def SETTINGS_MAX_FIELD_SECTION_SIZE   : UInt64 := 0x6
def SETTINGS_QPACK_BLOCKED_STREAMS    : UInt64 := 0x7
def SETTINGS_ENABLE_CONNECT_PROTOCOL  : UInt64 := 0x8
def SETTINGS_H3_DATAGRAM_00           : UInt64 := 0x276
def SETTINGS_H3_DATAGRAM              : UInt64 := 0x33

-- Reserved HTTP/2 settings identifiers — MUST be rejected.
def isReserved (id : UInt64) : Bool :=
  id == 0x0 || id == 0x2 || id == 0x3 || id == 0x4 || id == 0x5

-- Boolean-constrained identifiers — value must be 0 or 1.
def requiresBool (id : UInt64) : Bool :=
  id == SETTINGS_ENABLE_CONNECT_PROTOCOL ||
  id == SETTINGS_H3_DATAGRAM_00 ||
  id == SETTINGS_H3_DATAGRAM

-- ─── Parsed settings structure ───────────────────────────────────────────────

structure Settings where
  maxFieldSectionSize   : Option UInt64 := none
  qpackMaxTableCapacity : Option UInt64 := none
  qpackBlockedStreams   : Option UInt64 := none
  connectProtocol       : Option UInt64 := none
  h3Datagram            : Option UInt64 := none
  additionalSettings    : List (UInt64 × UInt64) := []
  deriving Repr

-- ─── Parse outcome ───────────────────────────────────────────────────────────

inductive ParseResult
  | ok  (s : Settings)
  | err  -- SettingsError or ExcessiveLoad

-- ─── Single-entry dispatch ────────────────────────────────────────────────────

-- Note: use if-then-else (not match) so that simp can evaluate constant guards.
def applyEntry (s : Settings) (id : UInt64) (v : UInt64) : Option Settings :=
  if isReserved id then none
  else if requiresBool id && decide (v > 1) then none
  else if id == SETTINGS_QPACK_MAX_TABLE_CAPACITY then
    some { s with qpackMaxTableCapacity := some v }
  else if id == SETTINGS_MAX_FIELD_SECTION_SIZE then
    some { s with maxFieldSectionSize := some v }
  else if id == SETTINGS_QPACK_BLOCKED_STREAMS then
    some { s with qpackBlockedStreams := some v }
  else if id == SETTINGS_ENABLE_CONNECT_PROTOCOL then
    some { s with connectProtocol := some v }
  else if id == SETTINGS_H3_DATAGRAM_00 then
    some { s with h3Datagram := some v }
  else if id == SETTINGS_H3_DATAGRAM then
    some { s with h3Datagram := some v }
  else
    some { s with additionalSettings := s.additionalSettings ++ [(id, v)] }

-- ─── Parse a list of (identifier, value) pairs ───────────────────────────────

def parse (pairs : List (UInt64 × UInt64)) : ParseResult :=
  go {} pairs
where
  go (acc : Settings) : List (UInt64 × UInt64) → ParseResult
    | []            => .ok acc
    | (id, v) :: rest =>
      match applyEntry acc id v with
      | none   => .err
      | some s => go s rest

-- ─── Lemmas on `isReserved` ───────────────────────────────────────────────────

theorem isReserved_0   : isReserved 0x0 = true  := by decide
theorem isReserved_2   : isReserved 0x2 = true  := by decide
theorem isReserved_3   : isReserved 0x3 = true  := by decide
theorem isReserved_4   : isReserved 0x4 = true  := by decide
theorem isReserved_5   : isReserved 0x5 = true  := by decide
theorem isReserved_1_false : isReserved 0x1 = false := by decide
theorem isReserved_6_false : isReserved 0x6 = false := by decide

-- ─── Lemmas on `requiresBool` ─────────────────────────────────────────────────

theorem requiresBool_connect :
    requiresBool SETTINGS_ENABLE_CONNECT_PROTOCOL = true  := by decide
theorem requiresBool_datagram_00 :
    requiresBool SETTINGS_H3_DATAGRAM_00 = true           := by decide
theorem requiresBool_datagram :
    requiresBool SETTINGS_H3_DATAGRAM = true              := by decide
theorem requiresBool_qpack_max_false :
    requiresBool SETTINGS_QPACK_MAX_TABLE_CAPACITY = false := by decide
theorem requiresBool_qpack_blk_false :
    requiresBool SETTINGS_QPACK_BLOCKED_STREAMS = false    := by decide

-- ─── `applyEntry` rejects reserved identifiers ────────────────────────────────

theorem applyEntry_reserved_none (s : Settings) (id : UInt64) (v : UInt64)
    (h : isReserved id = true) :
    applyEntry s id v = none := by
  simp [applyEntry, h]

-- ─── `applyEntry` rejects boolean violations ─────────────────────────────────

-- ─── `applyEntry` rejects boolean violations ─────────────────────────────────

theorem applyEntry_connect_gt1_none (s : Settings) (v : UInt64)
    (hv : v > 1) :
    applyEntry s SETTINGS_ENABLE_CONNECT_PROTOCOL v = none := by
  simp [applyEntry, isReserved, requiresBool, SETTINGS_ENABLE_CONNECT_PROTOCOL,
        SETTINGS_H3_DATAGRAM_00, SETTINGS_H3_DATAGRAM, hv]

theorem applyEntry_datagram_gt1_none (s : Settings) (v : UInt64)
    (hv : v > 1) :
    applyEntry s SETTINGS_H3_DATAGRAM v = none := by
  simp [applyEntry, isReserved, requiresBool, SETTINGS_H3_DATAGRAM,
        SETTINGS_H3_DATAGRAM_00, SETTINGS_ENABLE_CONNECT_PROTOCOL, hv]

-- ─── parse: empty list yields default Settings ────────────────────────────────

theorem parse_empty : parse [] = .ok {} := by
  simp [parse, parse.go]

-- ─── parse: reserved identifier propagates error ─────────────────────────────

theorem parse_reserved_id_err (id : UInt64) (v : UInt64)
    (rest : List (UInt64 × UInt64)) (h : isReserved id = true) :
    parse ((id, v) :: rest) = .err := by
  simp [parse, parse.go, applyEntry, h]

-- ─── parse: boolean violation propagates error ───────────────────────────────

theorem parse_connect_gt1_err (v : UInt64)
    (rest : List (UInt64 × UInt64)) (hv : v > 1) :
    parse ((SETTINGS_ENABLE_CONNECT_PROTOCOL, v) :: rest) = .err := by
  simp [parse, parse.go, applyEntry, isReserved, requiresBool,
        SETTINGS_ENABLE_CONNECT_PROTOCOL, SETTINGS_H3_DATAGRAM_00,
        SETTINGS_H3_DATAGRAM, hv]

theorem parse_datagram_gt1_err (v : UInt64)
    (rest : List (UInt64 × UInt64)) (hv : v > 1) :
    parse ((SETTINGS_H3_DATAGRAM, v) :: rest) = .err := by
  simp [parse, parse.go, applyEntry, isReserved, requiresBool,
        SETTINGS_H3_DATAGRAM, SETTINGS_H3_DATAGRAM_00,
        SETTINGS_ENABLE_CONNECT_PROTOCOL, hv]

-- ─── parse: single known field succeeds ──────────────────────────────────────

theorem parse_single_qpack_ok (v : UInt64) :
    parse [(SETTINGS_QPACK_MAX_TABLE_CAPACITY, v)] =
      .ok { qpackMaxTableCapacity := some v } := by
  simp [parse, parse.go, applyEntry, isReserved, requiresBool,
        SETTINGS_QPACK_MAX_TABLE_CAPACITY, SETTINGS_MAX_FIELD_SECTION_SIZE,
        SETTINGS_QPACK_BLOCKED_STREAMS, SETTINGS_ENABLE_CONNECT_PROTOCOL,
        SETTINGS_H3_DATAGRAM_00, SETTINGS_H3_DATAGRAM]

-- ─── Concrete validation examples ────────────────────────────────────────────

-- Reserved id 0x0 is rejected.
#eval parse [(0x0, 0)]                    -- expect err

-- Reserved id 0x4 (the SETTINGS frame type itself) is rejected.
#eval parse [(0x4, 1)]                    -- expect err

-- connect_protocol = 2 is rejected.
#eval parse [(SETTINGS_ENABLE_CONNECT_PROTOCOL, 2)]  -- expect err

-- Valid settings accepted.
#eval parse [(SETTINGS_QPACK_MAX_TABLE_CAPACITY, 4096),
             (SETTINGS_ENABLE_CONNECT_PROTOCOL, 1),
             (SETTINGS_H3_DATAGRAM, 1)]   -- expect ok

-- Unknown identifier goes to additionalSettings.
#eval parse [(0x1000, 42)]               -- expect ok with additionalSettings

-- decide checks
example : isReserved 0x4 = true  := by decide
example : isReserved 0x6 = false := by decide
example : requiresBool SETTINGS_H3_DATAGRAM = true := by decide

end H3Settings
