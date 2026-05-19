# Informal Specification: QUIC PacketType ↔ Epoch Mapping (T74)

🔬 *Lean Squad — informal specification for T74.*

## Purpose

The QUIC protocol associates each packet type with an *encryption level* (also
called *epoch* in quiche).  Encryption levels determine which TLS keys are
used to protect packet contents.  There are exactly three epochs:

| Epoch | Numeric | Used by |
|-------|---------|---------|
| Initial | 0 | Initial handshake packets |
| Handshake | 1 | TLS handshake completion packets |
| Application | 2 | 1-RTT data packets and 0-RTT early data |

The quiche implementation provides two functions in `quiche/src/packet.rs`:

- `Type::from_epoch(e: Epoch) -> Type` — given an epoch, return the canonical
  packet type used at that epoch level.
- `Type::to_epoch(self) -> Result<Epoch>` — given a packet type, return the
  epoch it belongs to, or an error if the type has no associated epoch.

These functions are used throughout the connection state machine when
dispatching packets to the correct encryption context.

## Preconditions

- `from_epoch`: no precondition; defined for all three `Epoch` values.
- `to_epoch`: no precondition; defined for all six `Type` values.

## Postconditions

**`from_epoch`:**
- `from_epoch(Initial) = Type::Initial`
- `from_epoch(Handshake) = Type::Handshake`
- `from_epoch(Application) = Type::Short`

**`to_epoch`:**
- `to_epoch(Type::Initial) = Ok(Initial)`
- `to_epoch(Type::Handshake) = Ok(Handshake)`
- `to_epoch(Type::Short) = Ok(Application)`
- `to_epoch(Type::ZeroRTT) = Ok(Application)` — 0-RTT shares the application epoch
- `to_epoch(Type::Retry) = Err(InvalidPacket)` — no associated epoch
- `to_epoch(Type::VersionNegotiation) = Err(InvalidPacket)` — no associated epoch

## Invariants

1. **Round-trip (from→to)**: `to_epoch(from_epoch(e)) = Ok(e)` for all epochs.
   `from_epoch` is a right-inverse of `to_epoch`.

2. **Injectivity**: `from_epoch` is injective — distinct epochs produce distinct types.

3. **Range**: the range of `from_epoch` is exactly `{Initial, Handshake, Short}`.
   Note `ZeroRTT` is *not* in the range of `from_epoch`, even though it maps
   to Application. The canonical type for Application is `Short`.

4. **ZeroRTT and Short share Application**: both `Type::ZeroRTT` and
   `Type::Short` map to `Epoch::Application`. This is intentional in QUIC:
   0-RTT early data and 1-RTT data share the same packet number space.

5. **Retry and VersionNegotiation have no epoch**: these packet types exist
   at the protocol negotiation layer, not at any TLS encryption level.

6. **Epoch-bearing characterisation**: a packet type `t` is epoch-bearing iff
   `t ∉ {Retry, VersionNegotiation}`.

## Edge cases

- `from_epoch` never produces `ZeroRTT`, `Retry`, or `VersionNegotiation`.
- Calling `to_epoch` on `Retry` or `VersionNegotiation` is valid but returns
  an error — callers must handle this case.
- `from_epoch(Application)` yields `Short`, not `ZeroRTT`, even though both
  share the Application epoch.

## Examples

```
from_epoch(Initial)     = Type::Initial
from_epoch(Handshake)   = Type::Handshake
from_epoch(Application) = Type::Short

to_epoch(Type::Initial)            = Ok(Initial)
to_epoch(Type::ZeroRTT)            = Ok(Application)
to_epoch(Type::Handshake)          = Ok(Handshake)
to_epoch(Type::Short)              = Ok(Application)
to_epoch(Type::Retry)              = Err(InvalidPacket)
to_epoch(Type::VersionNegotiation) = Err(InvalidPacket)
```

## Inferred intent

The design reflects the QUIC key schedule: three TLS encryption levels map to
three quiche epoch values.  `from_epoch` gives a canonical type per level;
`to_epoch` gives the level for a type that carries one.

The asymmetry (ZeroRTT shares Application with Short, but from_epoch(Application)
= Short) is intentional: `from_epoch` is used when *sending* a packet at a
given level, and the wire format for Application-epoch data is always the Short
header (1-RTT).  0-RTT is a special case: it uses the Application keys but a
distinct Long header type at the wire level.

## Open questions

None — both functions are straightforward pattern-matches with no ambiguity.

## Lean spec file

`formal-verification/lean/FVSquad/PacketTypeEpoch.lean` — T74, ~20 theorems.
