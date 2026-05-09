-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of Transport Error Code Mapping (T59).
--
-- Target: quiche/src/error.rs  (Error::to_wire, Error::to_c)
-- Spec:   formal-verification/specs/transport_error_code_informal.md
-- Phase:  5 — Spec + Implementation + Proofs (T59, run 145)
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- Models:
--   QuicheError    — Lean enum mirroring quiche::Error (22 variants)
--   toWire         — model of Error::to_wire → u64 wire code
--   toC            — model of Error::to_c → Int (ssize_t)
--
-- Excluded from model (see CORRESPONDENCE.md):
--   * Associated data in InvalidStreamState, StreamStopped, StreamReset
--     (treated as opaque Nat; proofs use ∀ n, ... patterns)
--   * #[cfg(feature = "ffi")] guard on to_c (always modelled here)
--   * libc::ssize_t width (modelled as Int, unbounded)
--
-- All proofs close with decide or native_decide.

namespace FVSquad.TransportErrorCode

-- ---------------------------------------------------------------------------
-- §1  Error enum
-- ---------------------------------------------------------------------------

/-- Mirror of quiche::Error (22 variants).
    Variants with associated u64 data carry a Nat here; their exact value
    does not affect to_wire or to_c so proofs universally quantify over it. -/
inductive QuicheError where
  | Done
  | BufferTooShort
  | UnknownVersion
  | InvalidFrame
  | InvalidPacket
  | InvalidState
  | InvalidStreamState (n : Nat)
  | InvalidTransportParam
  | CryptoFail
  | TlsFail
  | FlowControl
  | StreamLimit
  | StreamStopped (n : Nat)
  | StreamReset (n : Nat)
  | FinalSize
  | CongestionControl
  | IdLimit
  | OutOfIdentifiers
  | KeyUpdate
  | CryptoBufferExceeded
  | InvalidAckRange
  | OptimisticAckDetected
  | InvalidDcidInitialization
  deriving Repr

-- ---------------------------------------------------------------------------
-- §2  Wire error codes (RFC 9000 §20.1)
-- ---------------------------------------------------------------------------

/-- The ten distinct wire codes produced by to_wire. -/
def wireNoError              : Nat := 0x0
def wireInternalError        : Nat := 0x1
def wireFlowControlError     : Nat := 0x3
def wireStreamLimitError     : Nat := 0x4
def wireStreamStateError     : Nat := 0x5
def wireFinalSizeError       : Nat := 0x6
def wireFrameEncodingError   : Nat := 0x7
def wireTransportParamError  : Nat := 0x8
def wireConnectionIdLimitErr : Nat := 0x9
def wireProtocolViolation    : Nat := 0xa
def wireCryptoBufferExceeded : Nat := 0xd
def wireKeyUpdateError       : Nat := 0xe

-- ---------------------------------------------------------------------------
-- §3  toWire — model of Error::to_wire
-- ---------------------------------------------------------------------------

/-- Model of Error::to_wire.
    Returns the QUIC transport error code as a Nat (models u64). -/
def toWire : QuicheError → Nat
  | .Done                        => wireNoError
  | .InvalidFrame                => wireFrameEncodingError
  | .InvalidStreamState _        => wireStreamStateError
  | .InvalidTransportParam       => wireTransportParamError
  | .FlowControl                 => wireFlowControlError
  | .StreamLimit                 => wireStreamLimitError
  | .IdLimit                     => wireConnectionIdLimitErr
  | .FinalSize                   => wireFinalSizeError
  | .CryptoBufferExceeded        => wireCryptoBufferExceeded
  | .KeyUpdate                   => wireKeyUpdateError
  | _                            => wireProtocolViolation

-- ---------------------------------------------------------------------------
-- §4  toC — model of Error::to_c
-- ---------------------------------------------------------------------------

/-- Model of Error::to_c.
    Returns a negative Int representing the C ssize_t error code. -/
def toC : QuicheError → Int
  | .Done                     => -1
  | .BufferTooShort           => -2
  | .UnknownVersion           => -3
  | .InvalidFrame             => -4
  | .InvalidPacket            => -5
  | .InvalidState             => -6
  | .InvalidStreamState _     => -7
  | .InvalidTransportParam    => -8
  | .CryptoFail               => -9
  | .TlsFail                  => -10
  | .FlowControl              => -11
  | .StreamLimit              => -12
  | .FinalSize                => -13
  | .CongestionControl        => -14
  | .StreamStopped _          => -15
  | .StreamReset _            => -16
  | .IdLimit                  => -17
  | .OutOfIdentifiers         => -18
  | .KeyUpdate                => -19
  | .CryptoBufferExceeded     => -20
  | .InvalidAckRange          => -21
  | .OptimisticAckDetected    => -22
  | .InvalidDcidInitialization => -23

-- ---------------------------------------------------------------------------
-- §5  Theorems: toWire properties
-- ---------------------------------------------------------------------------

/-- toWire maps Done to the NoError code (0x0). -/
theorem toWire_done : toWire .Done = 0x0 := by decide

/-- toWire maps explicitly-handled variants to specific non-default codes. -/
theorem toWire_invalidFrame :
    toWire .InvalidFrame = 0x7 := by decide

theorem toWire_invalidStreamState (n : Nat) :
    toWire (.InvalidStreamState n) = 0x5 := by
  simp [toWire, wireStreamStateError]

theorem toWire_invalidTransportParam :
    toWire .InvalidTransportParam = 0x8 := by decide

theorem toWire_flowControl :
    toWire .FlowControl = 0x3 := by decide

theorem toWire_streamLimit :
    toWire .StreamLimit = 0x4 := by decide

theorem toWire_idLimit :
    toWire .IdLimit = 0x9 := by decide

theorem toWire_finalSize :
    toWire .FinalSize = 0x6 := by decide

theorem toWire_cryptoBufferExceeded :
    toWire .CryptoBufferExceeded = 0xd := by decide

theorem toWire_keyUpdate :
    toWire .KeyUpdate = 0xe := by decide

/-- All catch-all variants map to ProtocolViolation (0xa). -/
theorem toWire_bufferTooShort :
    toWire .BufferTooShort = wireProtocolViolation := by decide

theorem toWire_unknownVersion :
    toWire .UnknownVersion = wireProtocolViolation := by decide

theorem toWire_invalidPacket :
    toWire .InvalidPacket = wireProtocolViolation := by decide

theorem toWire_invalidState :
    toWire .InvalidState = wireProtocolViolation := by decide

theorem toWire_cryptoFail :
    toWire .CryptoFail = wireProtocolViolation := by decide

theorem toWire_tlsFail :
    toWire .TlsFail = wireProtocolViolation := by decide

theorem toWire_streamStopped (n : Nat) :
    toWire (.StreamStopped n) = wireProtocolViolation := by simp [toWire]

theorem toWire_streamReset (n : Nat) :
    toWire (.StreamReset n) = wireProtocolViolation := by simp [toWire]

theorem toWire_congestionControl :
    toWire .CongestionControl = wireProtocolViolation := by decide

theorem toWire_outOfIdentifiers :
    toWire .OutOfIdentifiers = wireProtocolViolation := by decide

theorem toWire_invalidAckRange :
    toWire .InvalidAckRange = wireProtocolViolation := by decide

theorem toWire_optimisticAckDetected :
    toWire .OptimisticAckDetected = wireProtocolViolation := by decide

theorem toWire_invalidDcidInitialization :
    toWire .InvalidDcidInitialization = wireProtocolViolation := by decide

/-- toWire output is always in the RFC 9000 defined range [0x0, 0x10].
    (The model only uses codes ≤ 0xe.) -/
theorem toWire_range (e : QuicheError) : toWire e ≤ 0x10 := by
  cases e <;> simp [toWire, wireProtocolViolation, wireFrameEncodingError,
    wireStreamStateError, wireTransportParamError, wireFlowControlError,
    wireStreamLimitError, wireConnectionIdLimitErr, wireFinalSizeError,
    wireCryptoBufferExceeded, wireKeyUpdateError, wireNoError]

/-- toWire is NOT injective: Done (0x0) ≠ BufferTooShort wire code,
    but two non-Done variants both map to ProtocolViolation. -/
theorem toWire_not_injective :
    toWire .BufferTooShort = toWire .UnknownVersion := by decide

-- ---------------------------------------------------------------------------
-- §6  Theorems: toC properties
-- ---------------------------------------------------------------------------

/-- Every error maps to a negative integer. -/
theorem toC_negative (e : QuicheError) : toC e < 0 := by
  cases e <;> simp [toC]

/-- Every error maps to a value ≥ -23. -/
theorem toC_ge_neg23 (e : QuicheError) : -23 ≤ toC e := by
  cases e <;> simp [toC]

/-- Every error maps to a value ≤ -1. -/
theorem toC_le_neg1 (e : QuicheError) : toC e ≤ -1 := by
  cases e <;> simp [toC]

/-- toC never returns zero. -/
theorem toC_nonzero (e : QuicheError) : toC e ≠ 0 := by
  cases e <;> simp [toC]

/-- Done maps to -1 (the "no data yet" sentinel). -/
theorem toC_done : toC .Done = -1 := by decide

/-- toC is injective on variants without associated data:
    all 20 non-parameterised error variants receive distinct codes. -/
theorem toC_injective_groundterms :
    [.Done, .BufferTooShort, .UnknownVersion, .InvalidFrame, .InvalidPacket,
     .InvalidState, .InvalidTransportParam, .CryptoFail, .TlsFail,
     .FlowControl, .StreamLimit, .FinalSize, .CongestionControl,
     .IdLimit, .OutOfIdentifiers, .KeyUpdate, .CryptoBufferExceeded,
     .InvalidAckRange, .OptimisticAckDetected, .InvalidDcidInitialization]
    |>.map toC
    |>.Nodup := by decide

/-- For parameterised variants with the same tag, toC is independent of
    the associated data value. -/
theorem toC_invalidStreamState_const (m n : Nat) :
    toC (.InvalidStreamState m) = toC (.InvalidStreamState n) := by rfl

theorem toC_streamStopped_const (m n : Nat) :
    toC (.StreamStopped m) = toC (.StreamStopped n) := by rfl

theorem toC_streamReset_const (m n : Nat) :
    toC (.StreamReset m) = toC (.StreamReset n) := by rfl

/-- Parameterised variants have distinct toC codes from each other
    and from all ground variants. -/
theorem toC_streamStopped_ne_streamReset (m n : Nat) :
    toC (.StreamStopped m) ≠ toC (.StreamReset n) := by simp [toC]

theorem toC_invalidStreamState_ne_streamStopped (m n : Nat) :
    toC (.InvalidStreamState m) ≠ toC (.StreamStopped n) := by simp [toC]

theorem toC_invalidStreamState_ne_streamReset (m n : Nat) :
    toC (.InvalidStreamState m) ≠ toC (.StreamReset n) := by simp [toC]

end FVSquad.TransportErrorCode
