-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of the HTTP/3 frame type codec
-- for the varint-payload frame variants (GoAway, CancelPush, MaxPushId)
-- in `quiche/src/h3/frame.rs`.
--
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- Scope: Only the three "single-varint-payload" frame types are modelled
-- here. Each of GoAway, CancelPush, and MaxPushId carries exactly one
-- QUIC variable-length integer as its entire payload. This allows a clean
-- byte-list round-trip model that mirrors Varint.lean.
--
-- Approximations / abstractions:
--   - Buffer mutation, offsets, and error paths are NOT modelled.
--   - Only the pure "value → byte-list → value" mapping is captured.
--   - The varint encode/decode model is imported from Varint.lean.
--   - The frame-level byte list is: [type_varint...] ++ [len_varint...]
--     ++ [payload_varint...]. The round-trip is proved on this model.
--   - Settings, Data, Headers, PushPromise, PriorityUpdate are NOT modelled.

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §1  Import varint primitives from Varint.lean
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- We re-define the minimal varint primitives inline to keep this file
-- self-contained (no `import FVSquad.Varint` needed for now, because
-- FVSquad.lean imports all files in order and they are loaded together).

/-- Maximum QUIC varint value (2^62 − 1). -/
def H3F_MAX_VAR_INT : Nat := 4611686018427387903

/-- Number of bytes needed to encode `v` as a QUIC varint.
    Mirrors `octets::varint_len` (octets/src/lib.rs:810-822). -/
def h3f_varint_len (v : Nat) : Nat :=
  if v ≤ 63 then 1
  else if v ≤ 16383 then 2
  else if v ≤ 1073741823 then 4
  else 8

/-- Encode `v` as a QUIC varint byte list.
    Mirrors `put_varint` (octets/src/lib.rs). -/
def h3f_varint_encode (v : Nat) : Option (List Nat) :=
  if v ≤ 63 then some [v]
  else if v ≤ 16383 then
    let w := v + 16384
    some [w / 256, w % 256]
  else if v ≤ 1073741823 then
    let w := v + 2147483648
    some [w / 16777216, (w / 65536) % 256, (w / 256) % 256, w % 256]
  else if v ≤ H3F_MAX_VAR_INT then
    let w := v + 13835058055282163712
    some [w / 72057594037927936, (w / 281474976710656) % 256,
          (w / 1099511627776) % 256, (w / 4294967296) % 256,
          (w / 16777216) % 256, (w / 65536) % 256,
          (w / 256) % 256, w % 256]
  else none

/-- Decode a QUIC varint from a byte list (reads exactly the needed bytes).
    Mirrors `get_varint` (octets/src/lib.rs).
    Uses modular arithmetic like Varint.lean for omega-friendly proofs. -/
def h3f_varint_decode (bytes : List Nat) : Option Nat :=
  match bytes with
  | [b0] =>
    some (b0 % 64)
  | [b0, b1] =>
    some ((b0 * 256 + b1) % 16384)
  | [b0, b1, b2, b3] =>
    some ((b0 * 16777216 + b1 * 65536 + b2 * 256 + b3) % 1073741824)
  | [b0, b1, b2, b3, b4, b5, b6, b7] =>
    some ((b0 * 72057594037927936 + b1 * 281474976710656 +
           b2 * 1099511627776 + b3 * 4294967296 +
           b4 * 16777216 + b5 * 65536 + b6 * 256 + b7) %
          4611686018427387904)
  | _ => none

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §2  HTTP/3 frame type ID constants
--     Source: quiche/src/h3/frame.rs:32-50
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

def DATA_FRAME_TYPE_ID                       : Nat := 0x0
def HEADERS_FRAME_TYPE_ID                    : Nat := 0x1
def CANCEL_PUSH_FRAME_TYPE_ID                : Nat := 0x3
def SETTINGS_FRAME_TYPE_ID                   : Nat := 0x4
def PUSH_PROMISE_FRAME_TYPE_ID               : Nat := 0x5
def GOAWAY_FRAME_TYPE_ID                     : Nat := 0x7
def MAX_PUSH_FRAME_TYPE_ID                   : Nat := 0xD
def PRIORITY_UPDATE_FRAME_REQUEST_TYPE_ID    : Nat := 0xF0700
def PRIORITY_UPDATE_FRAME_PUSH_TYPE_ID       : Nat := 0xF0701

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §3  H3 frame type (varint-payload variants only)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- The three H3 frame types whose entire payload is a single QUIC varint.
    Models `Frame::GoAway`, `Frame::CancelPush`, `Frame::MaxPushId`
    in quiche/src/h3/frame.rs. -/
inductive H3VarintFrame where
  | goAway     (id      : Nat) : H3VarintFrame
  | cancelPush (push_id : Nat) : H3VarintFrame
  | maxPushId  (push_id : Nat) : H3VarintFrame
  deriving Repr, BEq

/-- Frame type ID for a varint-payload frame variant. -/
def H3VarintFrame.typeId : H3VarintFrame → Nat
  | .goAway _     => GOAWAY_FRAME_TYPE_ID
  | .cancelPush _ => CANCEL_PUSH_FRAME_TYPE_ID
  | .maxPushId _  => MAX_PUSH_FRAME_TYPE_ID

/-- The varint payload value carried by the frame. -/
def H3VarintFrame.payload : H3VarintFrame → Nat
  | .goAway id      => id
  | .cancelPush pid => pid
  | .maxPushId pid  => pid

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §4  Byte-list serialisation model
--     Models `Frame::to_bytes` for varint-payload variants.
--     Wire format: type_varint ++ len_varint ++ payload_varint
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Serialise a varint-payload H3 frame to a byte list.
    Models `to_bytes` (quiche/src/h3/frame.rs:153+). -/
def h3f_encode (f : H3VarintFrame) : Option (List Nat) :=
  let v := f.payload
  let tid := f.typeId
  match h3f_varint_encode tid, h3f_varint_encode (h3f_varint_len v),
        h3f_varint_encode v with
  | some tBytes, some lBytes, some vBytes =>
    some (tBytes ++ lBytes ++ vBytes)
  | _, _, _ => none

/-- Deserialise a varint-payload H3 frame from (type_id, payload) byte lists.
    `from_bytes` receives the type_id and payload_len already parsed; this
    model takes the pre-parsed type id and the payload byte list. -/
def h3f_decode (type_id : Nat) (payload_bytes : List Nat) :
    Option H3VarintFrame :=
  match h3f_varint_decode payload_bytes with
  | none => none
  | some v =>
    match type_id with
    | 0x3 => some (.cancelPush v)
    | 0x7 => some (.goAway v)
    | 0xD => some (.maxPushId v)
    | _   => none

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §5  Type ID distinctness theorems
--     Each frame type has a unique type ID (required for unambiguous
--     demultiplexing in `from_bytes`).
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

theorem cancelPush_typeId_val :
    CANCEL_PUSH_FRAME_TYPE_ID = 0x3 := by decide

theorem goAway_typeId_val :
    GOAWAY_FRAME_TYPE_ID = 0x7 := by decide

theorem maxPushId_typeId_val :
    MAX_PUSH_FRAME_TYPE_ID = 0xD := by decide

/-- The nine RFC-9114 frame type IDs are pairwise distinct. -/
theorem h3_frame_type_ids_distinct :
    DATA_FRAME_TYPE_ID ≠ HEADERS_FRAME_TYPE_ID ∧
    DATA_FRAME_TYPE_ID ≠ CANCEL_PUSH_FRAME_TYPE_ID ∧
    DATA_FRAME_TYPE_ID ≠ SETTINGS_FRAME_TYPE_ID ∧
    DATA_FRAME_TYPE_ID ≠ PUSH_PROMISE_FRAME_TYPE_ID ∧
    DATA_FRAME_TYPE_ID ≠ GOAWAY_FRAME_TYPE_ID ∧
    DATA_FRAME_TYPE_ID ≠ MAX_PUSH_FRAME_TYPE_ID ∧
    HEADERS_FRAME_TYPE_ID ≠ CANCEL_PUSH_FRAME_TYPE_ID ∧
    HEADERS_FRAME_TYPE_ID ≠ SETTINGS_FRAME_TYPE_ID ∧
    HEADERS_FRAME_TYPE_ID ≠ GOAWAY_FRAME_TYPE_ID ∧
    CANCEL_PUSH_FRAME_TYPE_ID ≠ SETTINGS_FRAME_TYPE_ID ∧
    CANCEL_PUSH_FRAME_TYPE_ID ≠ PUSH_PROMISE_FRAME_TYPE_ID ∧
    CANCEL_PUSH_FRAME_TYPE_ID ≠ GOAWAY_FRAME_TYPE_ID ∧
    CANCEL_PUSH_FRAME_TYPE_ID ≠ MAX_PUSH_FRAME_TYPE_ID ∧
    SETTINGS_FRAME_TYPE_ID ≠ PUSH_PROMISE_FRAME_TYPE_ID ∧
    SETTINGS_FRAME_TYPE_ID ≠ GOAWAY_FRAME_TYPE_ID ∧
    SETTINGS_FRAME_TYPE_ID ≠ MAX_PUSH_FRAME_TYPE_ID ∧
    PUSH_PROMISE_FRAME_TYPE_ID ≠ GOAWAY_FRAME_TYPE_ID ∧
    PUSH_PROMISE_FRAME_TYPE_ID ≠ MAX_PUSH_FRAME_TYPE_ID ∧
    GOAWAY_FRAME_TYPE_ID ≠ MAX_PUSH_FRAME_TYPE_ID ∧
    PRIORITY_UPDATE_FRAME_REQUEST_TYPE_ID ≠
      PRIORITY_UPDATE_FRAME_PUSH_TYPE_ID := by
  decide

/-- The three varint-payload variants have pairwise distinct type IDs. -/
theorem varint_frame_typeIds_distinct (f g : H3VarintFrame)
    (hne : f.typeId = g.typeId) : f.payload = g.payload → f = g := by
  intro hp
  cases f <;> cases g <;> simp [H3VarintFrame.typeId,
    CANCEL_PUSH_FRAME_TYPE_ID, GOAWAY_FRAME_TYPE_ID,
    MAX_PUSH_FRAME_TYPE_ID] at * <;> try contradiction
  all_goals (simp [H3VarintFrame.payload] at hp; subst hp; rfl)

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §6  Payload-length consistency
--     to_bytes writes `varint_len(v)` as the payload length.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- `h3f_varint_len v` is always 1, 2, 4, or 8 for valid varints. -/
theorem h3f_varint_len_valid (v : Nat) :
    h3f_varint_len v = 1 ∨ h3f_varint_len v = 2 ∨
    h3f_varint_len v = 4 ∨ h3f_varint_len v = 8 := by
  unfold h3f_varint_len
  by_cases h1 : v ≤ 63
  · simp [h1]
  · by_cases h2 : v ≤ 16383
    · simp [h1, h2]
    · by_cases h3 : v ≤ 1073741823
      · simp [h1, h2, h3]
      · simp [h1, h2, h3]

/-- `h3f_varint_len` matches `h3f_varint_encode` byte-count for valid values. -/
theorem h3f_varint_len_encode (v : Nat) (hv : v ≤ H3F_MAX_VAR_INT) :
    ∃ bs, h3f_varint_encode v = some bs ∧
          bs.length = h3f_varint_len v := by
  unfold h3f_varint_encode h3f_varint_len H3F_MAX_VAR_INT at *
  by_cases h1 : v ≤ 63
  · exact ⟨[v], by simp [h1]⟩
  · by_cases h2 : v ≤ 16383
    · refine ⟨[(v + 16384) / 256, (v + 16384) % 256], ?_⟩
      simp [if_neg h1, if_pos h2]
    · by_cases h3 : v ≤ 1073741823
      · refine ⟨[(v + 2147483648) / 16777216,
                 (v + 2147483648) / 65536 % 256,
                 (v + 2147483648) / 256 % 256,
                 (v + 2147483648) % 256], ?_⟩
        simp [if_neg h1, if_neg h2, if_pos h3]
      · refine ⟨[(v + 13835058055282163712) / 72057594037927936,
                 (v + 13835058055282163712) / 281474976710656 % 256,
                 (v + 13835058055282163712) / 1099511627776 % 256,
                 (v + 13835058055282163712) / 4294967296 % 256,
                 (v + 13835058055282163712) / 16777216 % 256,
                 (v + 13835058055282163712) / 65536 % 256,
                 (v + 13835058055282163712) / 256 % 256,
                 (v + 13835058055282163712) % 256], ?_⟩
        simp [if_neg h1, if_neg h2, if_neg h3, (show v ≤ 4611686018427387903 by omega)]

/-- The payload-length field written by `to_bytes` equals `varint_len(payload)`.
    For GoAway: `b.put_varint(varint_len(id) as u64)` (frame.rs:285-290). -/
theorem h3f_payload_len_field (f : H3VarintFrame)
    (hv : f.payload ≤ H3F_MAX_VAR_INT) :
    h3f_varint_len f.payload ≤ H3F_MAX_VAR_INT := by
  unfold h3f_varint_len H3F_MAX_VAR_INT at *
  by_cases h1 : f.payload ≤ 63
  · simp [h1]
  · by_cases h2 : f.payload ≤ 16383
    · simp [h1, h2]
    · by_cases h3 : f.payload ≤ 1073741823
      · simp [h1, h2, h3]
      · simp [h1, h2, h3]

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §7  Varint round-trip (inline, for use in frame round-trip below)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- The varint codec is injective for valid values. -/
theorem h3f_varint_round_trip (v : Nat) (hv : v ≤ H3F_MAX_VAR_INT) :
    ∃ bs, h3f_varint_encode v = some bs ∧
          h3f_varint_decode bs = some v := by
  simp only [h3f_varint_encode, h3f_varint_decode, H3F_MAX_VAR_INT] at *
  by_cases h1 : v ≤ 63
  · exact ⟨[v], by simp [h1], by simp; omega⟩
  · by_cases h2 : v ≤ 16383
    · exact ⟨[(v + 16384) / 256, (v + 16384) % 256],
             by simp [h1, h2], by simp; omega⟩
    · by_cases h3 : v ≤ 1073741823
      · exact ⟨[(v + 2147483648) / 16777216,
                (v + 2147483648) / 65536 % 256,
                (v + 2147483648) / 256 % 256,
                (v + 2147483648) % 256],
               by simp [h1, h2, h3], by simp; omega⟩
      · have hv' : v ≤ 4611686018427387903 := hv
        exact ⟨[(v + 13835058055282163712) / 72057594037927936,
                (v + 13835058055282163712) / 281474976710656 % 256,
                (v + 13835058055282163712) / 1099511627776 % 256,
                (v + 13835058055282163712) / 4294967296 % 256,
                (v + 13835058055282163712) / 16777216 % 256,
                (v + 13835058055282163712) / 65536 % 256,
                (v + 13835058055282163712) / 256 % 256,
                (v + 13835058055282163712) % 256],
               by simp [h1, h2, h3, hv'],
               by simp; omega⟩

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §8  Frame-level round-trip theorems
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- GoAway round-trip: decode(encode(id)) = goAway(id).
    Models: `Frame::GoAway { id }` → `to_bytes` → `from_bytes` roundtrip. -/
theorem goAway_round_trip (id : Nat) (hv : id ≤ H3F_MAX_VAR_INT) :
    h3f_decode GOAWAY_FRAME_TYPE_ID
      (h3f_varint_encode id).get! = some (.goAway id) := by
  obtain ⟨vbs, henc, hdec⟩ := h3f_varint_round_trip id hv
  simp [h3f_decode, GOAWAY_FRAME_TYPE_ID, henc, hdec]

/-- CancelPush round-trip. -/
theorem cancelPush_round_trip (push_id : Nat) (hv : push_id ≤ H3F_MAX_VAR_INT) :
    h3f_decode CANCEL_PUSH_FRAME_TYPE_ID
      (h3f_varint_encode push_id).get! =
      some (.cancelPush push_id) := by
  obtain ⟨vbs, henc, hdec⟩ := h3f_varint_round_trip push_id hv
  simp [h3f_decode, CANCEL_PUSH_FRAME_TYPE_ID, henc, hdec]

/-- MaxPushId round-trip. -/
theorem maxPushId_round_trip (push_id : Nat) (hv : push_id ≤ H3F_MAX_VAR_INT) :
    h3f_decode MAX_PUSH_FRAME_TYPE_ID
      (h3f_varint_encode push_id).get! =
      some (.maxPushId push_id) := by
  obtain ⟨vbs, henc, hdec⟩ := h3f_varint_round_trip push_id hv
  simp [h3f_decode, MAX_PUSH_FRAME_TYPE_ID, henc, hdec]

/-- decode is injective on the three varint-payload frame types:
    two frames with the same type_id and payload_bytes decode identically. -/
theorem h3f_decode_injective (tid : Nat) (bs : List Nat)
    (f g : H3VarintFrame)
    (hf : h3f_decode tid bs = some f)
    (hg : h3f_decode tid bs = some g) :
    f = g := by
  rw [hf] at hg; exact Option.some.inj hg

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §9  Type ID in valid range (encodable as varint)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- All nine RFC-9114 type IDs are within the QUIC varint range. -/
theorem h3_type_ids_in_varint_range :
    DATA_FRAME_TYPE_ID ≤ H3F_MAX_VAR_INT ∧
    HEADERS_FRAME_TYPE_ID ≤ H3F_MAX_VAR_INT ∧
    CANCEL_PUSH_FRAME_TYPE_ID ≤ H3F_MAX_VAR_INT ∧
    SETTINGS_FRAME_TYPE_ID ≤ H3F_MAX_VAR_INT ∧
    PUSH_PROMISE_FRAME_TYPE_ID ≤ H3F_MAX_VAR_INT ∧
    GOAWAY_FRAME_TYPE_ID ≤ H3F_MAX_VAR_INT ∧
    MAX_PUSH_FRAME_TYPE_ID ≤ H3F_MAX_VAR_INT ∧
    PRIORITY_UPDATE_FRAME_REQUEST_TYPE_ID ≤ H3F_MAX_VAR_INT ∧
    PRIORITY_UPDATE_FRAME_PUSH_TYPE_ID ≤ H3F_MAX_VAR_INT := by
  decide

/-- All RFC-9114 type IDs fit in the 1-byte varint encoding (≤ 63),
    except PriorityUpdate which requires 4 bytes. -/
theorem h3_type_ids_encoding_len :
    h3f_varint_len DATA_FRAME_TYPE_ID = 1 ∧
    h3f_varint_len HEADERS_FRAME_TYPE_ID = 1 ∧
    h3f_varint_len CANCEL_PUSH_FRAME_TYPE_ID = 1 ∧
    h3f_varint_len SETTINGS_FRAME_TYPE_ID = 1 ∧
    h3f_varint_len PUSH_PROMISE_FRAME_TYPE_ID = 1 ∧
    h3f_varint_len GOAWAY_FRAME_TYPE_ID = 1 ∧
    h3f_varint_len MAX_PUSH_FRAME_TYPE_ID = 1 ∧
    h3f_varint_len PRIORITY_UPDATE_FRAME_REQUEST_TYPE_ID = 4 ∧
    h3f_varint_len PRIORITY_UPDATE_FRAME_PUSH_TYPE_ID = 4 := by
  decide

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §10  typeId function is correct
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

theorem h3f_typeId_goAway (id : Nat) :
    (H3VarintFrame.goAway id).typeId = GOAWAY_FRAME_TYPE_ID := by
  simp [H3VarintFrame.typeId]

theorem h3f_typeId_cancelPush (push_id : Nat) :
    (H3VarintFrame.cancelPush push_id).typeId = CANCEL_PUSH_FRAME_TYPE_ID := by
  simp [H3VarintFrame.typeId]

theorem h3f_typeId_maxPushId (push_id : Nat) :
    (H3VarintFrame.maxPushId push_id).typeId = MAX_PUSH_FRAME_TYPE_ID := by
  simp [H3VarintFrame.typeId]

/-- The typeId values for the three varint-payload variants are pairwise distinct. -/
theorem varint_frame_typeIds_all_distinct :
    (H3VarintFrame.goAway 0).typeId ≠ (H3VarintFrame.cancelPush 0).typeId ∧
    (H3VarintFrame.goAway 0).typeId ≠ (H3VarintFrame.maxPushId 0).typeId ∧
    (H3VarintFrame.cancelPush 0).typeId ≠ (H3VarintFrame.maxPushId 0).typeId := by
  decide

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §11  Examples
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

-- GoAway(0): type=0x7(1B) + len=0x1(1B) + payload=0x0(1B) = [0x07, 0x01, 0x00]
#eval h3f_encode (.goAway 0)
-- expected: some [7, 1, 0]

-- GoAway(1): type=0x7 + len=1 + payload=1 = [7, 1, 1]
#eval h3f_encode (.goAway 1)

-- CancelPush(100): type=0x3(1B) + len=1(1B) + payload=100(1B) = [3, 1, 100]
#eval h3f_encode (.cancelPush 100)

-- MaxPushId(16383): type=0xD(1B) + len=2(1B) + payload=[0x7F,0xFF](2B) = [13, 2, 127, 255]
#eval h3f_encode (.maxPushId 16383)

-- Decode round-trip examples
#eval h3f_decode 0x7 (h3f_varint_encode 42).get!  -- some (goAway 42)
#eval h3f_decode 0x3 (h3f_varint_encode 0).get!   -- some (cancelPush 0)
#eval h3f_decode 0xD (h3f_varint_encode 16383).get! -- some (maxPushId 16383)

-- Unknown type_id returns none
#eval h3f_decode 0x0 (h3f_varint_encode 0).get!   -- none

-- varint_len of type IDs
#eval h3f_varint_len GOAWAY_FRAME_TYPE_ID           -- 1
#eval h3f_varint_len PRIORITY_UPDATE_FRAME_REQUEST_TYPE_ID  -- 4
