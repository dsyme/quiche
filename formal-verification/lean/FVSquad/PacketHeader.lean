-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of QUIC packet-header first-byte
-- encoding and type-code round-trip properties.
--
-- Source: `quiche/src/packet.rs` — `Header::to_bytes` / `Header::from_bytes`
-- RFC:    RFC 9000 §17 (QUIC packet formats)
-- Informal spec: `formal-verification/specs/packet_header_informal.md`
--
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- What is modelled:
--   - The `PacketType` enum and its 2-bit wire type code
--   - The first-byte encoding for long-header and short-header packets
--   - Type-code encode/decode round-trip
--   - FORM_BIT (0x80) and FIXED_BIT (0x40) presence/absence
--
-- Approximations / abstractions:
--   - Only the first-byte and type-code layer is modelled; full buffer
--     serialisation (dcid, scid, token, version fields) is stated but
--     left for future work with a richer buffer model.
--   - `pkt_num_len` (bits 1-0) and `key_phase` (bit 2) are fixed to 0;
--     header-protection mutations of these fields are out of scope.
--   - `VersionNegotiation` is a decode-only type (`to_bytes` rejects it).
--   - All arithmetic uses `Nat`; bytes are values in [0, 255].

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §1 Constants
--    quiche/src/packet.rs lines 45–49
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Long-header form bit (bit 7 of first byte). -/
def FORM_BIT  : Nat := 0x80   -- 128

/-- Fixed bit, always set in valid QUIC packets (bit 6 of first byte). -/
def FIXED_BIT : Nat := 0x40   -- 64

/-- Type-mask: bits 5-4 of the long-header first byte encode packet type. -/
def TYPE_MASK : Nat := 0x30   -- 48

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §2 Packet type
--    Mirrors the `Type` enum in quiche/src/packet.rs lines 121–138.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

inductive PacketType : Type
  | Initial           -- 0x00 in the wire type-code
  | ZeroRTT           -- 0x01 in the wire type-code
  | Handshake         -- 0x02 in the wire type-code
  | Retry             -- 0x03 in the wire type-code
  | VersionNegotiation -- decode-only; to_bytes rejects it
  | Short             -- 1-RTT; different first-byte layout
  deriving DecidableEq, Repr

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §3 Type-code encoder
--    Mirrors the `ty` match arm in `to_bytes` (packet.rs lines 481–488).
--    Returns `none` for types that `to_bytes` does not handle.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Wire 2-bit type code for long-header packet types. -/
def typeCode : PacketType → Option Nat
  | PacketType.Initial            => some 0
  | PacketType.ZeroRTT            => some 1
  | PacketType.Handshake          => some 2
  | PacketType.Retry              => some 3
  | PacketType.VersionNegotiation => none
  | PacketType.Short              => none

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §4 Type-code decoder
--    Mirrors `(first & TYPE_MASK) >> 4` in `from_bytes` (packet.rs 383–387).
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Decode a 2-bit long-header type code back to a `PacketType`. -/
def typeOfCode : Nat → Option PacketType
  | 0 => some PacketType.Initial
  | 1 => some PacketType.ZeroRTT
  | 2 => some PacketType.Handshake
  | 3 => some PacketType.Retry
  | _ => none

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §5 First-byte encoder
--    Long header: `first |= FORM_BIT | FIXED_BIT | (ty << 4)`
--      (packet.rs line 489; `ty << 4` = ty * 16 in Nat, with ty ≤ 3)
--    Short header: `first &= !FORM_BIT; first |= FIXED_BIT`
--      (packet.rs lines 462–465; FORM_BIT cleared, FIXED_BIT set)
--
-- We model the first byte with `pkt_num_len` = 0 and `key_phase` = 0,
-- i.e. the low 6 bits are 0 for long headers and 0 for short headers.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- First byte of a long-header packet (pkt_num_len=0 model). -/
def longFirstByte (ty : PacketType) : Option Nat :=
  typeCode ty |>.map (fun c => FORM_BIT + FIXED_BIT + c * 16)

/-- First byte of a short-header packet (pkt_num_len=0, key_phase=0 model). -/
def shortFirstByte : Nat := FIXED_BIT    -- 0x40 = 64

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §6 Helper: extract bits 5–4 from a byte
--    Models `(byte & TYPE_MASK) >> 4`, i.e. `(byte % 64) / 16`.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Extract the 2-bit long-header type field from a first byte. -/
def typeBitsOf (b : Nat) : Nat := (b % 64) / 16

/-- Test whether bit 7 (FORM_BIT) is set — equivalently, `b ≥ 128`. -/
def formBitSet (b : Nat) : Prop := b / 128 = 1

/-- Test whether bit 6 (FIXED_BIT) is set in the low 7 bits. -/
def fixedBitSet (b : Nat) : Prop := (b % 128) / 64 = 1

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §7 Concrete examples confirming the encoding
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- Long-header Initial: 0xC0 = 192
example : longFirstByte PacketType.Initial = some 0xC0 := by decide
-- Long-header ZeroRTT: 0xD0 = 208
example : longFirstByte PacketType.ZeroRTT = some 0xD0 := by decide
-- Long-header Handshake: 0xE0 = 224
example : longFirstByte PacketType.Handshake = some 0xE0 := by decide
-- Long-header Retry: 0xF0 = 240
example : longFirstByte PacketType.Retry = some 0xF0 := by decide
-- VersionNegotiation and Short have no long-header first byte
example : longFirstByte PacketType.VersionNegotiation = none := by decide
example : longFirstByte PacketType.Short = none := by decide
-- Short header: 0x40 = 64
example : shortFirstByte = 0x40 := by decide
-- Type-code decoder
example : typeOfCode 0 = some PacketType.Initial   := by decide
example : typeOfCode 1 = some PacketType.ZeroRTT   := by decide
example : typeOfCode 2 = some PacketType.Handshake := by decide
example : typeOfCode 3 = some PacketType.Retry     := by decide
example : typeOfCode 4 = none                      := by decide

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §8 Type-code round-trip theorems
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Encode then decode: for every long-header type, decoding the type code
    returns the original type. -/
theorem typeCode_roundtrip (ty : PacketType) (c : Nat)
    (h : typeCode ty = some c) : typeOfCode c = some ty := by
  cases ty <;> simp [typeCode] at h <;> simp [typeOfCode, ← h]

/-- Decode then encode: for valid codes 0–3, encoding the decoded type
    returns the original code. -/
theorem typeOfCode_roundtrip (c : Nat) (ty : PacketType)
    (h : typeOfCode c = some ty) : typeCode ty = some c := by
  match c with
  | 0 => simp [typeOfCode] at h; simp [← h, typeCode]
  | 1 => simp [typeOfCode] at h; simp [← h, typeCode]
  | 2 => simp [typeOfCode] at h; simp [← h, typeCode]
  | 3 => simp [typeOfCode] at h; simp [← h, typeCode]
  | n + 4 => simp [typeOfCode] at h

/-- All valid long-header type codes lie in [0, 3]. -/
theorem typeCode_in_range (ty : PacketType) (c : Nat)
    (h : typeCode ty = some c) : c < 4 := by
  cases ty <;> simp [typeCode] at h <;> omega

/-- `typeCode` is injective on its defined domain. -/
theorem typeCode_injective (a b : PacketType)
    (ha : typeCode a ≠ none) (h : typeCode a = typeCode b) : a = b := by
  cases a <;> cases b <;>
    simp [typeCode] at ha h ⊢ <;> exact h

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §9 FORM_BIT and FIXED_BIT theorems for long headers
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Long-header first byte has FORM_BIT set. -/
theorem longFirstByte_form_bit (ty : PacketType) (fb : Nat)
    (h : longFirstByte ty = some fb) : formBitSet fb := by
  cases ty <;> simp [longFirstByte, typeCode] at h <;>
    simp [formBitSet, FORM_BIT, FIXED_BIT, ← h] <;> decide

/-- Long-header first byte has FIXED_BIT set. -/
theorem longFirstByte_fixed_bit (ty : PacketType) (fb : Nat)
    (h : longFirstByte ty = some fb) : fixedBitSet fb := by
  cases ty <;> simp [longFirstByte, typeCode] at h <;>
    simp [fixedBitSet, FORM_BIT, FIXED_BIT, ← h] <;> decide

/-- The type bits extracted from the long-header first byte equal the
    original type code. -/
theorem longFirstByte_type_bits (ty : PacketType) (c fb : Nat)
    (hc : typeCode ty = some c) (hfb : longFirstByte ty = some fb) :
    typeBitsOf fb = c := by
  simp only [typeBitsOf]
  cases ty <;>
    simp [typeCode, longFirstByte, FORM_BIT, FIXED_BIT] at hc hfb <;>
    omega

/-- Long-header first bytes are all in [0xC0, 0xFF]. -/
theorem longFirstByte_byte_range (ty : PacketType) (fb : Nat)
    (h : longFirstByte ty = some fb) : 192 ≤ fb ∧ fb ≤ 255 := by
  cases ty <;> simp [longFirstByte, typeCode] at h <;>
    simp [FORM_BIT, FIXED_BIT, ← h] <;> decide

/-- `longFirstByte` is injective: two types with the same first byte are equal. -/
theorem longFirstByte_injective (a b : PacketType) (fa fb : Nat)
    (ha : longFirstByte a = some fa) (hb : longFirstByte b = some fb)
    (heq : fa = fb) : a = b := by
  have hca : typeCode a ≠ none := by
    cases a <;> simp [longFirstByte, typeCode] at ha ⊢
  have hcb : typeCode b ≠ none := by
    cases b <;> simp [longFirstByte, typeCode] at hb ⊢
  apply typeCode_injective a b hca
  cases a <;> cases b <;>
    simp [longFirstByte, typeCode] at ha hb ⊢ <;>
    simp [FORM_BIT, FIXED_BIT] at ha hb <;>
    omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §10 Short-header first-byte theorems
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Short-header first byte does NOT have FORM_BIT set. -/
theorem shortFirstByte_no_form_bit : ¬ formBitSet shortFirstByte := by
  simp [formBitSet, shortFirstByte, FIXED_BIT]

/-- Short-header first byte DOES have FIXED_BIT set. -/
theorem shortFirstByte_fixed_bit : fixedBitSet shortFirstByte := by
  simp [fixedBitSet, shortFirstByte, FIXED_BIT]

/-- The short-header first byte (0x40) never equals any long-header first
    byte (0xC0–0xF0). -/
theorem short_long_first_byte_differ (ty : PacketType) (fb : Nat)
    (h : longFirstByte ty = some fb) : shortFirstByte ≠ fb := by
  cases ty <;> simp [longFirstByte, typeCode] at h <;>
    simp [shortFirstByte, FORM_BIT, FIXED_BIT, ← h] <;> decide

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §11 Full round-trip theorem (stated; proof deferred to future work)
--
-- Modelling the full buffer encoding requires a richer byte-list model.
-- The theorem below states the key property; the `sorry` marks the gap
-- between the first-byte model above and the full buffer model.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- A simplified header record capturing the fields relevant to the
    first-byte and type-code layer. -/
structure Header where
  ty      : PacketType
  version : Nat         -- 0 for VersionNegotiation
  dcid    : List Nat    -- byte list, each ≤ 255
  scid    : List Nat    -- byte list, long headers only
  token   : Option (List Nat)   -- Initial / Retry only
  deriving Repr

/-- Serialise a long-header `Header` to a minimal byte list:
      [first_byte, v3, v2, v1, v0, dcid_len, dcid..., scid_len, scid...]
    where `first_byte = longFirstByte ty`.
    Only defined for long-header types with a valid type code.
    `pkt_num_len` bits and `key_phase` are always 0 in this model. -/
def encodeLongHeader (h : Header) : Option (List Nat) := do
  let fb ← longFirstByte h.ty
  let v3 := h.version / 16777216
  let v2 := (h.version / 65536) % 256
  let v1 := (h.version / 256) % 256
  let v0 := h.version % 256
  some ([fb, v3, v2, v1, v0,
         h.dcid.length] ++ h.dcid ++
        [h.scid.length] ++ h.scid)

/-- Decode the first byte, type code, and connection IDs from a byte list. -/
def decodeLongHeader (bs : List Nat) (_dcidLen : Nat) : Option Header := do
  match bs with
  | (fb :: v3 :: v2 :: v1 :: v0 :: rest) =>
    let c ← if fb / 128 = 1 then some ((fb % 64) / 16) else none
    let ty ← typeOfCode c
    let version := v3 * 16777216 + v2 * 65536 + v1 * 256 + v0
    match rest with
    | (dl :: rest1) =>
      if dl > rest1.length then none
      else
        let dcid := rest1.take dl
        let rest2 := rest1.drop dl
        match rest2 with
        | (sl :: rest3) =>
          if sl > rest3.length then none
          else
            let scid := rest3.take sl
            some ⟨ty, version, dcid, scid, none⟩
        | [] => none
    | [] => none
  | _ => none

/-- The core long-header round-trip property (T29 RT-1):
    for any well-formed long-header `h`, encoding then decoding yields `h`
    (with the zero'd pkt_num / key_phase fields). -/
theorem longHeader_roundtrip (h : Header)
    (hty   : typeCode h.ty ≠ none)
    (hdlen : h.dcid.length ≤ 255)
    (hslen : h.scid.length ≤ 255)
    (hver  : h.version < 2 ^ 32) :
    ∃ bs, encodeLongHeader h = some bs ∧
          decodeLongHeader bs h.dcid.length =
            some ⟨h.ty, h.version, h.dcid, h.scid, none⟩ := by
  sorry

/-- The version field round-trips through big-endian 4-byte encoding. -/
theorem version_roundtrip (v : Nat) (_hv : v < 2 ^ 32) :
    let v3 := v / 16777216
    let v2 := (v / 65536) % 256
    let v1 := (v / 256) % 256
    let v0 := v % 256
    v3 * 16777216 + v2 * 65536 + v1 * 256 + v0 = v := by
  simp only []
  omega
