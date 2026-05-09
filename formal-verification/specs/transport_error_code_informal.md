# Informal Specification: Transport Error Code Mapping (T59)

**Target**: `Error::to_wire` and `Error::to_c` in `quiche/src/error.rs`
**Priority**: MEDIUM (fully decidable, enumerable)
**Lean target**: `formal-verification/lean/FVSquad/TransportErrorCode.lean`

---

## Purpose

The `quiche::Error` enum represents the library's internal error type.
Two mapping functions convert these errors to external representations:

1. **`Error::to_wire()`** (line 185): converts an `Error` value to a QUIC
   wire error code (`u64`) as defined by RFC 9000 §20.1. This value is sent
   on the network in `CONNECTION_CLOSE` frames.
2. **`Error::to_c()`** (line 202, `#[cfg(feature = "ffi")]`): converts an
   `Error` value to a C `ssize_t` for use by the FFI layer. These values are
   part of the public C API contract.

Both functions are total: every `Error` variant maps to exactly one output
value. The mappings are pure (no side effects).

---

## Preconditions

- For `to_wire`: any `Error` variant is valid input.
- For `to_c`: any `Error` variant is valid input; the function is only
  compiled with the `ffi` feature flag.

---

## Postconditions

### `to_wire` postconditions

1. **Correct default**: any `Error` variant not explicitly listed maps to
   `WireErrorCode::ProtocolViolation as u64 = 0xa`.
2. **Exhaustive explicit mapping**: the explicitly-mapped variants cover the
   most specific wire codes:
   - `Done` → `0x0` (NoError)
   - `InvalidFrame` → `0x7` (FrameEncodingError)
   - `InvalidStreamState(_)` → `0x5` (StreamStateError)
   - `InvalidTransportParam` → `0x8` (TransportParameterError)
   - `FlowControl` → `0x3` (FlowControlError)
   - `StreamLimit` → `0x4` (StreamLimitError)
   - `IdLimit` → `0x9` (ConnectionIdLimitError)
   - `FinalSize` → `0x6` (FinalSizeError)
   - `CryptoBufferExceeded` → `0xd` (CryptoBufferExceeded)
   - `KeyUpdate` → `0xe` (KeyUpdateError)
3. **Injectivity property** (partial): distinct explicitly-mapped variants
   produce distinct wire codes. However, `to_wire` is NOT globally injective:
   multiple variants (e.g. `BufferTooShort`, `UnknownVersion`, `TlsFail`,
   `CryptoFail`, `StreamStopped`, etc.) all map to `0xa` (ProtocolViolation).
4. **Range bound**: all outputs are `u64` values in `[0x0, 0x10]`.

### `to_c` postconditions

1. **All outputs are negative**: every variant maps to a negative `ssize_t`
   in the range `[-23, -1]`.
2. **Globally injective**: every `Error` variant maps to a distinct integer.
3. **`Done` maps to -1**: this is the "no data yet" sentinel, distinct from
   error conditions.
4. **No zero**: `to_c` never returns 0 (0 is reserved for success in C).
5. **Monotone with enum order** (informally): variants are assigned codes
   -1, -2, -3, ... in declaration order. This is a convention, not a
   semantic requirement, but the spec should check it holds.

---

## Invariants

- **`to_wire` is total and defined for all 22 `Error` variants**.
- **`to_c` is total, injective, and all values are in `[-23, -1]`**.
- **Wire codes are valid RFC 9000 error codes** (values 0x0–0x10 are the
  defined range; the mapping uses only values from that range).

---

## Edge Cases

1. **`Error::Done`**: semantically not an error — maps to `NoError (0x0)` in
   `to_wire` and to `-1` in `to_c`. Both are documented sentinels.
2. **Parametric variants** (`InvalidStreamState(u64)`, `StreamStopped(u64)`,
   `StreamReset(u64)`): the associated `u64` parameter is ignored by both
   mapping functions. The wire code depends only on the variant tag.
3. **`OptimisticAckDetected`**: maps to `ProtocolViolation (0xa)` in
   `to_wire` (not explicitly listed, falls through to `_`). Maps to `-22`
   in `to_c`.
4. **`InvalidDcidInitialization`**: maps to `ProtocolViolation (0xa)` in
   `to_wire`. Maps to `-23` in `to_c`.

---

## Examples

| Error variant | `to_wire()` output | `to_c()` output |
|---|---|---|
| `Done` | `0x0` | `-1` |
| `BufferTooShort` | `0xa` | `-2` |
| `InvalidFrame` | `0x7` | `-4` |
| `FlowControl` | `0x3` | `-11` |
| `StreamLimit` | `0x4` | `-12` |
| `FinalSize` | `0x6` | `-13` |
| `KeyUpdate` | `0xe` | `-19` |
| `CryptoBufferExceeded` | `0xd` | `-20` |
| `InvalidDcidInitialization` | `0xa` | `-23` |

---

## Inferred Intent

The `to_wire` mapping is designed to send the most semantically appropriate
wire error code when a `CONNECTION_CLOSE` frame must be sent. Variants that
don't have a specific RFC 9000 code default to `ProtocolViolation` — a catch-all
that indicates the peer violated the QUIC protocol without a more specific
categorization.

The `to_c` mapping provides a stable numeric API for C callers. The values are
assigned sequentially in declaration order for predictability. The injectivity
property is critical for C callers: each error must be distinguishable.

---

## Open Questions

1. **OQ-T59-1**: Should `OutOfIdentifiers` (maps to `-18` in `to_c`,
   `0xa` in `to_wire`) have a more specific wire error code? It is related
   to connection ID exhaustion, which maps to `0x9` (ConnectionIdLimitError)
   — but `IdLimit` (too many IDs *provided*) already uses `0x9`. The
   asymmetry (`IdLimit → 0x9` but `OutOfIdentifiers → 0xa`) may be
   intentional — maintainer should confirm.
2. **OQ-T59-2**: The `to_c` values are part of the public C API. Are they
   documented in a header or changelog as stable? Changing them would be an
   API break. Formal verification of the mapping would help catch accidental
   renumbering.
3. **OQ-T59-3**: `Error::Done` maps to `NoError (0x0)` in `to_wire`. In
   practice, `Done` is used as a "no data" sentinel and not a real error.
   Should `Done` even be passable to `to_wire`? The call site
   (`lib.rs:L2911`) wraps it in `e.to_wire()` only in an error arm, so in
   normal operation this path is not taken for `Done` — but the mapping
   exists and produces a defined output.

---

## Approach for Lean Specification

The `to_wire` and `to_c` functions are finite-domain pure functions: they
take one of 22 enum variants and return a fixed value. The natural Lean
approach is:

1. Define the `Error` type as an inductive type mirroring the Rust enum
   (with or without parameters for the parametric variants).
2. Define `toWire : Error → Nat` and `toC : Error → Int`.
3. Prove injectivity of `toC` by `decide`.
4. Prove range bounds (`0 ≤ toWire e ≤ 0x10`, `-23 ≤ toC e ≤ -1`) by `decide`.
5. Prove that `toC` has no zero by `decide`.
6. Prove specific variant mappings by `decide` (spot checks).
7. Prove that `toWire` is *not* injective (by counterexample: two variants
   mapping to `0xa`).

All of these proofs are fully decidable and should close with `decide` or
`native_decide`.

**Approximations needed**:
- Parametric variants (`InvalidStreamState(u64)` etc.) may need to be
  represented as a single constructor (ignoring the parameter) for `decide`
  to work, since `decide` cannot quantify over `u64` ranges.
- `to_c` is gated by `#[cfg(feature = "ffi")]`; the Lean spec models it
  unconditionally.
