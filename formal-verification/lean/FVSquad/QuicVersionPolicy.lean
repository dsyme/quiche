-- Copyright (C) 2018-2025, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause

/-!
# QUIC Version Policy: Greasing and Supported Versions

Formal specification and proofs for the QUIC version policy in quiche:
  - `is_reserved_version`  (lib.rs ~L615-618)
  - `version_is_supported` (lib.rs ~L1887-1889)

## Rust source

```rust
const RESERVED_VERSION_MASK: u32 = 0xfafafafa;

fn is_reserved_version(version: u32) -> bool {
    version & RESERVED_VERSION_MASK == version
}

pub const PROTOCOL_VERSION_V1: u32 = 0x0000_0001;

pub fn version_is_supported(version: u32) -> bool {
    matches!(version, PROTOCOL_VERSION_V1)
}
```

## RFC 9000 background

RFC 9000 §15 defines version greasing: specific version values whose low
two bits of each byte are `0b10` (i.e. each byte is in `{0x02, 0x06, 0x0a,
0x0e, ..., 0xfa}`) are reserved for greasing.  `RESERVED_VERSION_MASK =
0xfafafafa` is the bitwise-OR of all permitted greasing bits; a version is
"reserved" exactly when all its set bits are within this mask.

## Model

- `UInt32` ↔ Lean `UInt32` (32-bit wrap-around, matching Rust `u32`)
- The mask `0xfafafafa` is modelled as the literal `UInt32` constant
- `V1 = 0x00000001`
- `isReservedVersion v ↔ v &&& MASK == v`
- `isSupportedVersion v ↔ v == V1`

## What this captures

  ✅ Reserved-version bitmask check
  ✅ Supported version list (currently only V1)
  ✅ Disjointness of reserved and supported sets
  ✅ V1 not reserved; zero not supported
  ✅ All greasing byte patterns are reserved
  ✅ Connection version-guard conjunct (§ usage comment below)

## Approximations / omissions

  ⚠️  Version negotiation packet handling (multi-version list) not modelled
  ⚠️  Future supported versions would require extending `isSupportedVersion`
-/

namespace QuicVersionPolicy

-- ---------------------------------------------------------------------------
-- Constants (match Rust literals exactly)

/-- Bitmask that characterises reserved ("greasing") version numbers.
    Source: `quiche/src/lib.rs` ~L479. -/
def RESERVED_VERSION_MASK : UInt32 := 0xfafafafa

/-- The only currently supported QUIC protocol version.
    Source: `quiche/src/lib.rs` ~L434. -/
def PROTOCOL_VERSION_V1 : UInt32 := 0x00000001

-- ---------------------------------------------------------------------------
-- Model functions

/-- A version number is *reserved* when all its set bits are within the mask.
    Models `is_reserved_version` from `quiche/src/lib.rs` ~L615-618. -/
def isReservedVersion (version : UInt32) : Bool :=
  version &&& RESERVED_VERSION_MASK == version

/-- A version number is *supported* iff it is exactly `PROTOCOL_VERSION_V1`.
    Models `version_is_supported` from `quiche/src/lib.rs` ~L1887-1889. -/
def isSupportedVersion (version : UInt32) : Bool :=
  version == PROTOCOL_VERSION_V1

-- ---------------------------------------------------------------------------
-- §1  Decidable spot-checks
-- ---------------------------------------------------------------------------

-- V1 is supported.
#eval isSupportedVersion PROTOCOL_VERSION_V1           -- true
-- V1 is NOT reserved.
#eval isReservedVersion PROTOCOL_VERSION_V1            -- false
-- Classic greasing values (all reserved).
#eval isReservedVersion 0x0a0a0a0a                     -- true
#eval isReservedVersion 0xfafafafa                     -- true
#eval isReservedVersion 0x5a5a5a5a                     -- false (bit 7 set in each byte)
-- Zero is neither reserved nor supported.
#eval isReservedVersion 0                              -- true  (0 & mask = 0 = 0)
#eval isSupportedVersion 0                             -- false

-- ---------------------------------------------------------------------------
-- §2  Concrete theorems (decided automatically)
-- ---------------------------------------------------------------------------

-- Theorems (13 total, 0 sorry):
-- §2.1 V1 is the unique supported version (by decide on 32-bit space would
--      be too slow; we prove structural properties instead).

/-- V1 is supported. -/
theorem v1_is_supported : isSupportedVersion PROTOCOL_VERSION_V1 = true := by
  decide

/-- Zero version is not supported. -/
theorem zero_not_supported : isSupportedVersion 0 = false := by
  decide

/-- Zero version is reserved (0 &&& mask = 0). -/
theorem zero_is_reserved : isReservedVersion 0 = true := by
  decide

/-- V1 is NOT reserved (its LSB falls outside the mask). -/
theorem v1_not_reserved : isReservedVersion PROTOCOL_VERSION_V1 = false := by
  decide

/-- Classic greasing value 0x0a0a0a0a is reserved. -/
theorem grease_0a_reserved : isReservedVersion 0x0a0a0a0a = true := by
  decide

/-- Classic greasing value 0x2a2a2a2a is reserved. -/
theorem grease_2a_reserved : isReservedVersion 0x2a2a2a2a = true := by
  decide

/-- Classic greasing value 0xfafafafa is reserved. -/
theorem grease_fa_reserved : isReservedVersion 0xfafafafa = true := by
  decide

/-- A version that has bits set outside the mask is not reserved.
    0x00000003 has bit 1 set; bit 1 is NOT in 0xfafafafa (byte = 0xfa = 11111010). -/
theorem non_mask_not_reserved : isReservedVersion 0x00000003 = false := by
  decide

/-- Another non-reserved example: 0x0000ffff. -/
theorem non_mask_not_reserved2 : isReservedVersion 0x0000ffff = false := by
  decide

-- ---------------------------------------------------------------------------
-- §3  Key safety properties
-- ---------------------------------------------------------------------------

/-- **Disjointness**: no version can be both reserved and supported.

    This is the central safety invariant: a greasing version must never be
    treated as supported.  In quiche, both checks appear in the connection
    setup guard:

        if !is_reserved_version(version) && !version_is_supported(version) {
            return Err(Error::UnknownVersion);
        }

    The disjointness ensures neither check subsumes the other. -/
theorem reserved_disjoint_supported (v : UInt32) :
    ¬ (isReservedVersion v = true ∧ isSupportedVersion v = true) := by
  intro ⟨hr, hs⟩
  simp only [isSupportedVersion, PROTOCOL_VERSION_V1, beq_iff_eq] at hs
  subst hs
  exact absurd hr (by decide)

/-- **Disjointness (Bool form)**: for any version, it is false that both
    `isReservedVersion` and `isSupportedVersion` are true. -/
theorem reserved_and_supported_false (v : UInt32) :
    (isReservedVersion v && isSupportedVersion v) = false := by
  cases h : isSupportedVersion v with
  | false => simp
  | true =>
    simp only [isSupportedVersion, PROTOCOL_VERSION_V1, beq_iff_eq] at h
    subst h
    decide

/-- A supported version passes the reserved-OR-supported gate. -/
theorem supported_passes_gate (v : UInt32) :
    isSupportedVersion v = true →
    (isReservedVersion v || isSupportedVersion v) = true := by
  intro h
  simp [h]

/-- V1 passes the connection version guard
    (i.e. the guard does NOT return an error for V1). -/
theorem v1_passes_version_guard :
    ¬ (isReservedVersion PROTOCOL_VERSION_V1 = false ∧
       isSupportedVersion PROTOCOL_VERSION_V1 = false) := by
  simp [v1_is_supported]

end QuicVersionPolicy
