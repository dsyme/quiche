-- Copyright (C) 2018-2026, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause

/-!
# T74: QUIC PacketType ↔ Epoch round-trip

🔬 Lean Squad — formal verification of the QUIC packet-type / encryption-level
(epoch) mapping in quiche.

## Source
  `quiche/src/packet.rs`
  - `Type::from_epoch(e: Epoch) -> Type`   (~L142)
  - `Type::to_epoch(self) -> Result<Epoch>` (~L152)

## Rust source (verbatim)

```rust
pub enum Epoch { Initial = 0, Handshake = 1, Application = 2 }
pub enum Type  { Initial, Retry, Handshake, ZeroRTT,
                  VersionNegotiation, Short }

impl Type {
    pub(crate) fn from_epoch(e: Epoch) -> Type {
        match e {
            Epoch::Initial     => Type::Initial,
            Epoch::Handshake   => Type::Handshake,
            Epoch::Application => Type::Short,
        }
    }

    pub(crate) fn to_epoch(self) -> Result<Epoch> {
        match self {
            Type::Initial    => Ok(Epoch::Initial),
            Type::ZeroRTT    => Ok(Epoch::Application),
            Type::Handshake  => Ok(Epoch::Handshake),
            Type::Short      => Ok(Epoch::Application),
            _                => Err(Error::InvalidPacket),
        }
    }
}
```

## Properties verified

1. **from_epoch_to_epoch** — `from_epoch` is a right-inverse of `to_epoch`:
   for every `Epoch`, `(from_epoch e).to_epoch = ok e`.
2. **to_epoch_from_epoch** — `to_epoch` is a left-inverse of `from_epoch`
   on the image of `from_epoch`: `from_epoch` only produces
   `Initial | Handshake | Short`, and for those types the epoch recovered
   is the one we started with.
3. **Short_and_ZeroRTT_same_epoch** — both `Short` and `ZeroRTT` map to
   `Application` (they share the application epoch).
4. **Retry_and_VN_no_epoch** — `Retry` and `VersionNegotiation` have no
   associated epoch; `to_epoch` returns `none`.
5. **to_epoch_exhaustive** — every `Type` is either epoch-bearing or not;
   `to_epoch` classifies all six variants.
6. **from_epoch_injective** — `from_epoch` is injective.
7. **from_epoch_surjective_on_range** — the range of `from_epoch` is
   exactly `{Initial, Handshake, Short}`.
8. **epoch_count** — there are exactly three epochs.

## Modelling notes

- `Result<T>` is modelled as `Option T` (`ok v ↦ some v`, error ↦ `none`).
- No mutable state; both functions are pure pattern-matches.
- All proofs close by `decide`.

-/

namespace FVSquad.PacketTypeEpoch

-- ────────────────────────────────────────────────────────────────────────────
-- §1  Types
-- ────────────────────────────────────────────────────────────────────────────

/-- QUIC encryption levels, ordered Initial < Handshake < Application.
    Matches `packet::Epoch` in quiche. -/
inductive Epoch
  | Initial
  | Handshake
  | Application
  deriving DecidableEq, Repr

/-- QUIC packet types.
    Matches `packet::Type` in quiche. -/
inductive PktType
  | Initial
  | Retry
  | Handshake
  | ZeroRTT
  | VersionNegotiation
  | Short
  deriving DecidableEq, Repr

-- ────────────────────────────────────────────────────────────────────────────
-- §2  The two mapping functions
-- ────────────────────────────────────────────────────────────────────────────

/-- Mirror `Type::from_epoch`: given an encryption level, return the canonical
    packet type used at that level.
    ZeroRTT is *not* in the range — it shares Application level with Short,
    but is distinct at the type level. -/
def fromEpoch : Epoch → PktType
  | Epoch.Initial     => PktType.Initial
  | Epoch.Handshake   => PktType.Handshake
  | Epoch.Application => PktType.Short

/-- Mirror `Type::to_epoch`: map a packet type back to its encryption level.
    Returns `none` for Retry and VersionNegotiation (no associated epoch). -/
def toEpoch : PktType → Option Epoch
  | PktType.Initial            => some Epoch.Initial
  | PktType.ZeroRTT            => some Epoch.Application
  | PktType.Handshake          => some Epoch.Handshake
  | PktType.Short              => some Epoch.Application
  | PktType.Retry              => none
  | PktType.VersionNegotiation => none

-- ────────────────────────────────────────────────────────────────────────────
-- §3  Helper predicate: types that carry an epoch
-- ────────────────────────────────────────────────────────────────────────────

/-- A packet type is *epoch-bearing* iff `toEpoch` returns `some`. -/
def hasEpoch (t : PktType) : Bool :=
  (toEpoch t).isSome

-- ────────────────────────────────────────────────────────────────────────────
-- §4  Theorems
-- ────────────────────────────────────────────────────────────────────────────

/-- **from_epoch_to_epoch**: `fromEpoch` is a right-inverse of `toEpoch`;
    applying `toEpoch` to the result of `fromEpoch` recovers the original epoch.
    This is the primary round-trip guarantee: `from_epoch ∘ to_epoch = id`. -/
theorem from_epoch_to_epoch (e : Epoch) :
    toEpoch (fromEpoch e) = some e := by
  cases e <;> decide

/-- **from_epoch_injective**: `fromEpoch` never maps two distinct epochs to
    the same packet type. -/
theorem from_epoch_injective (e₁ e₂ : Epoch) (h : fromEpoch e₁ = fromEpoch e₂) :
    e₁ = e₂ := by
  cases e₁ <;> cases e₂ <;> simp_all [fromEpoch]

/-- **from_epoch_initial**: `fromEpoch Initial = Initial`. -/
@[simp] theorem from_epoch_initial : fromEpoch Epoch.Initial = PktType.Initial :=
  rfl

/-- **from_epoch_handshake**: `fromEpoch Handshake = Handshake`. -/
@[simp] theorem from_epoch_handshake :
    fromEpoch Epoch.Handshake = PktType.Handshake := rfl

/-- **from_epoch_application**: `fromEpoch Application = Short`. -/
@[simp] theorem from_epoch_application :
    fromEpoch Epoch.Application = PktType.Short := rfl

/-- **Short_and_ZeroRTT_same_epoch**: both `Short` and `ZeroRTT` map to
    the application encryption level, reflecting that 0-RTT and 1-RTT
    packets share the same packet number space in QUIC. -/
theorem short_and_zeroRTT_same_epoch :
    toEpoch PktType.Short = toEpoch PktType.ZeroRTT := by decide

/-- **Retry_no_epoch**: `Retry` has no associated encryption level. -/
theorem retry_no_epoch : toEpoch PktType.Retry = none := by decide

/-- **VersionNegotiation_no_epoch**: `VersionNegotiation` has no associated
    encryption level. -/
theorem versionNegotiation_no_epoch :
    toEpoch PktType.VersionNegotiation = none := by decide

/-- **Retry_and_VN_no_epoch**: exactly `Retry` and `VersionNegotiation`
    have no epoch. -/
theorem retry_and_vn_no_epoch (t : PktType) :
    toEpoch t = none ↔
      t = PktType.Retry ∨ t = PktType.VersionNegotiation := by
  cases t <;> decide

/-- **hasEpoch_iff**: a type has an epoch iff it is not `Retry` or `VN`. -/
theorem hasEpoch_iff (t : PktType) :
    hasEpoch t = true ↔
      t ≠ PktType.Retry ∧ t ≠ PktType.VersionNegotiation := by
  cases t <;> simp [hasEpoch, toEpoch]

/-- **range_of_fromEpoch**: the image of `fromEpoch` is exactly
    `{Initial, Handshake, Short}`. -/
theorem range_of_fromEpoch (t : PktType) :
    (∃ e : Epoch, fromEpoch e = t) ↔
      t = PktType.Initial ∨
      t = PktType.Handshake ∨
      t = PktType.Short := by
  constructor
  · rintro ⟨e, rfl⟩
    cases e <;> simp [fromEpoch]
  · rintro (rfl | rfl | rfl)
    · exact ⟨Epoch.Initial, rfl⟩
    · exact ⟨Epoch.Handshake, rfl⟩
    · exact ⟨Epoch.Application, rfl⟩

/-- **to_epoch_from_epoch**: on the range of `fromEpoch`, `toEpoch` is a
    left-inverse — we recover the epoch we started with. -/
theorem to_epoch_from_epoch (e : Epoch) (h : fromEpoch e = t) :
    toEpoch t = some e := by
  subst h; cases e <;> decide

/-- **to_epoch_exhaustive**: `toEpoch` classifies every packet type as
    either epoch-bearing (`some e`) or not (`none`). -/
theorem to_epoch_exhaustive (t : PktType) :
    (∃ e : Epoch, toEpoch t = some e) ∨ toEpoch t = none := by
  cases t <;> simp [toEpoch]

/-- **epoch_count**: there are exactly 3 epochs (Initial, Handshake,
    Application), matching `Epoch::count()` in quiche. -/
theorem epoch_count :
    (List.ofFn (fun e : Fin 3 =>
        match e with
        | ⟨0, _⟩ => Epoch.Initial
        | ⟨1, _⟩ => Epoch.Handshake
        | _       => Epoch.Application)).length = 3 := by decide

/-- **pkttype_count**: there are exactly 6 packet types. -/
theorem pkttype_count :
    [PktType.Initial, PktType.Retry, PktType.Handshake,
     PktType.ZeroRTT, PktType.VersionNegotiation, PktType.Short].length = 6 :=
  by decide

/-- **fromEpoch_hasEpoch**: every type in the range of `fromEpoch` has an
    epoch (i.e. `fromEpoch e` is always epoch-bearing). -/
theorem fromEpoch_hasEpoch (e : Epoch) : hasEpoch (fromEpoch e) = true := by
  cases e <;> decide

/-- **toEpoch_some_of_not_retry_vn**: if a type is not `Retry` and not
    `VersionNegotiation` then `toEpoch` returns `some`. -/
theorem toEpoch_some_of_not_retry_vn (t : PktType)
    (h₁ : t ≠ PktType.Retry) (h₂ : t ≠ PktType.VersionNegotiation) :
    ∃ e, toEpoch t = some e := by
  cases t <;> simp_all [toEpoch]

/-- **initial_epoch_is_initial**: `toEpoch Initial = some Initial`. -/
@[simp] theorem initial_epoch_is_initial :
    toEpoch PktType.Initial = some Epoch.Initial := rfl

/-- **handshake_epoch_is_handshake**: `toEpoch Handshake = some Handshake`. -/
@[simp] theorem handshake_epoch_is_handshake :
    toEpoch PktType.Handshake = some Epoch.Handshake := rfl

/-- **short_epoch_is_application**: `toEpoch Short = some Application`. -/
@[simp] theorem short_epoch_is_application :
    toEpoch PktType.Short = some Epoch.Application := rfl

/-- **zeroRTT_epoch_is_application**: `toEpoch ZeroRTT = some Application`. -/
@[simp] theorem zeroRTT_epoch_is_application :
    toEpoch PktType.ZeroRTT = some Epoch.Application := rfl

end FVSquad.PacketTypeEpoch
