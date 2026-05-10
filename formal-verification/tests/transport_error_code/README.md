# Route-B Test: T59 — Transport Error Code Mapping

🔬 Lean Squad correspondence test for `FVSquad/TransportErrorCode.lean`.

## What is tested

The Lean model defines two functions that map `QuicheError` variants to numeric
codes:

- `toWire`: maps error variants to RFC 9000 §20.1 wire error codes (u64)
- `toC`: maps error variants to C FFI ssize_t codes (negative integers)

This test re-implements the same match logic as the Rust source
(`quiche/src/error.rs`, `Error::to_wire` and `Error::to_c`) and verifies
that every variant maps to the exact value specified in the Lean model.

### toWire mappings (11 distinct codes for 23 variants)

| Variant | Wire code |
|---------|-----------|
| `Done` | `0x0` (NoError) |
| `InvalidFrame` | `0x7` (FrameEncodingError) |
| `InvalidStreamState(_)` | `0x5` (StreamStateError) |
| `InvalidTransportParam` | `0x8` (TransportParameterError) |
| `FlowControl` | `0x3` (FlowControlError) |
| `StreamLimit` | `0x4` (StreamLimitError) |
| `IdLimit` | `0x9` (ConnectionIdLimitError) |
| `FinalSize` | `0x6` (FinalSizeError) |
| `CryptoBufferExceeded` | `0xd` (CryptoBufferExceeded) |
| `KeyUpdate` | `0xe` (KeyUpdateError) |
| 13 remaining variants | `0xa` (ProtocolViolation) |

**Key finding**: `toWire` is NOT injective — 13 out of 23 variants all map to
`ProtocolViolation (0xa)`. This is an intentional design choice: QUIC does not
distinguish between these error categories at the wire level.

### toC mappings (23 distinct codes)

`toC` IS injective: each variant maps to a unique integer in `[-23, -1]`.
The `Done` variant maps to `-1` (the "no data yet" sentinel used in C FFI).

## Running the test

```bash
rustc formal-verification/tests/transport_error_code/transport_error_code_test.rs \
  -o /tmp/transport_error_code_test
/tmp/transport_error_code_test
```

Expected output: 50 × `PASS` lines followed by `=== All 50 checks PASS ===`.

## Run results (run 146)

```
=== All 50 checks PASS ===
```

50/50 cases pass. The Lean model matches the Rust source exactly.

## Source references

- Rust: `quiche/src/error.rs`, `Error::to_wire` (L185–L202), `Error::to_c` (L205–L228)
- Lean: `formal-verification/lean/FVSquad/TransportErrorCode.lean`
- Informal spec: `formal-verification/specs/transport_error_code_informal.md`
