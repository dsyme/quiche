-- Copyright (C) 2024, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — T61: QUIC STREAM frame type-byte encoding
--
-- Target T61: StreamFrameType
-- Source: quiche/src/frame.rs, encode_stream_header (lines 1326–1350)
-- Phase: 5 — Spec + Implementation + Proofs
-- Lean 4 (v4.29.1), no Mathlib dependency.
--
-- `encode_stream_header` always writes one of exactly two type bytes:
--   0x0E  (fin = false)  = 0b00001110
--   0x0F  (fin = true)   = 0b00001111
--
-- The byte layout (RFC 9000 §19.8):
--   bit 3 (0x08) : STREAM frame base type identifier
--   bit 2 (0x04) : OFF flag — offset field is present (always set here)
--   bit 1 (0x02) : LEN flag — length field is present (always set here)
--   bit 0 (0x01) : FIN flag — matches the `fin` parameter
--
-- Approximations / omissions:
--   * We model only the type-byte computation; the stream_id / offset /
--     length varint encoding is not modelled.
--   * Buffer mutation (OctetsMut) is abstracted away entirely.
--
-- Theorems (12 total, 0 sorry):
--   1.  streamTypeByte_def_false  — 0x0E when fin = false
--   2.  streamTypeByte_def_true   — 0x0F when fin = true
--   3.  streamTypeByte_range      — always ∈ {0x0E, 0x0F}
--   4.  streamTypeByte_base_set   — bit 3 always set (0x08 mask)
--   5.  streamTypeByte_off_set    — bit 2 always set (0x04 mask)
--   6.  streamTypeByte_len_set    — bit 1 always set (0x02 mask)
--   7.  streamTypeByte_fin_iff    — bit 0 ⟺ fin
--   8.  streamTypeByte_injective  — distinct fin values → distinct bytes
--   9.  streamTypeByte_ne         — 0x0E ≠ 0x0F
--   10. streamTypeByte_not_default_stream — never equals 0x08 (bare STREAM)
--   11. streamTypeByte_is_stream_type     — high nibble is 0x0_ (< 0x10)
--   12. streamTypeByte_decode_fin — one can recover fin from the byte

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  Model
-- ─────────────────────────────────────────────────────────────────────────────

/-- The type byte written by `encode_stream_header`.
    Mirrors the bit-OR sequence in the Rust source directly. -/
def streamTypeByte (fin : Bool) : UInt8 :=
  let ty : UInt8 := 0x08
  let ty := ty ||| 0x04   -- OFF flag always set
  let ty := ty ||| 0x02   -- LEN flag always set
  if fin then ty ||| 0x01 else ty

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  Basic value proofs
-- ─────────────────────────────────────────────────────────────────────────────

theorem streamTypeByte_def_false : streamTypeByte false = 0x0E := by decide

theorem streamTypeByte_def_true : streamTypeByte true = 0x0F := by decide

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  Range: only two possible values
-- ─────────────────────────────────────────────────────────────────────────────

theorem streamTypeByte_range (fin : Bool) :
    streamTypeByte fin = 0x0E ∨ streamTypeByte fin = 0x0F := by
  cases fin <;> simp [streamTypeByte_def_false, streamTypeByte_def_true]

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Bit-flag properties
-- ─────────────────────────────────────────────────────────────────────────────

/-- The STREAM base type bit (0x08) is always set. -/
theorem streamTypeByte_base_set (fin : Bool) :
    (streamTypeByte fin &&& 0x08) = 0x08 := by
  cases fin <;> decide

/-- The OFF flag (0x04) is always set. -/
theorem streamTypeByte_off_set (fin : Bool) :
    (streamTypeByte fin &&& 0x04) = 0x04 := by
  cases fin <;> decide

/-- The LEN flag (0x02) is always set. -/
theorem streamTypeByte_len_set (fin : Bool) :
    (streamTypeByte fin &&& 0x02) = 0x02 := by
  cases fin <;> decide

/-- The FIN flag (bit 0) is set iff `fin = true`. -/
theorem streamTypeByte_fin_iff (fin : Bool) :
    (streamTypeByte fin &&& 0x01 = 0x01) ↔ fin = true := by
  cases fin <;> decide

-- ─────────────────────────────────────────────────────────────────────────────
-- §5  Injectivity and distinctness
-- ─────────────────────────────────────────────────────────────────────────────

/-- Different `fin` values produce different bytes. -/
theorem streamTypeByte_injective {a b : Bool}
    (h : streamTypeByte a = streamTypeByte b) : a = b := by
  cases a <;> cases b <;> simp_all [streamTypeByte_def_false, streamTypeByte_def_true]

/-- The two possible bytes are distinct. -/
theorem streamTypeByte_ne : (0x0E : UInt8) ≠ 0x0F := by decide

-- ─────────────────────────────────────────────────────────────────────────────
-- §6  Guard: not a bare STREAM byte
-- ─────────────────────────────────────────────────────────────────────────────

/-- The result is never the bare STREAM type byte 0x08 (no flags). -/
theorem streamTypeByte_not_default_stream (fin : Bool) :
    streamTypeByte fin ≠ 0x08 := by
  cases fin <;> decide

-- ─────────────────────────────────────────────────────────────────────────────
-- §7  STREAM frame type range: high nibble is 0 (byte < 16)
-- ─────────────────────────────────────────────────────────────────────────────

/-- The type byte is in the STREAM frame type range [0x08, 0x0F]. -/
theorem streamTypeByte_is_stream_type (fin : Bool) :
    (streamTypeByte fin).toNat ≥ 0x08 ∧ (streamTypeByte fin).toNat ≤ 0x0F := by
  cases fin <;> decide

-- ─────────────────────────────────────────────────────────────────────────────
-- §8  Decode: FIN bit recovery
-- ─────────────────────────────────────────────────────────────────────────────

/-- One can recover the `fin` flag from the type byte by testing bit 0. -/
theorem streamTypeByte_decode_fin (fin : Bool) :
    (streamTypeByte fin &&& 0x01 = 0x01) = fin := by
  cases fin <;> decide
