# Route-B Correspondence Tests — T61: StreamFrameType

🔬 *Lean Squad — automated formal verification for `dsyme/quiche`.*

## Target

**T61: QUIC STREAM Frame Type Byte Encoding**

- Source: `quiche/src/frame.rs`, `encode_stream_header` (lines 1326–1350)
- Lean model: `formal-verification/lean/FVSquad/StreamFrameType.lean`

## What is tested

The Rust `encode_stream_header` function computes a 1-byte QUIC frame type
tag using a fixed sequence of bitwise OR operations:

```rust
let mut ty: u8 = 0x08;
ty |= 0x04;          // OFF flag — always set
ty |= 0x02;          // LEN flag — always set
if fin { ty |= 0x01; }
```

This always produces exactly `0x0E` (fin=false) or `0x0F` (fin=true).

The Lean model (`streamTypeByte`) mirrors this computation identically. The
Route-B tests verify that both sides agree on:

| Property | Tests |
|----------|-------|
| Rust byte = Lean byte for both fin values | 2 |
| Exact values 0x0E / 0x0F | 2 |
| STREAM base flag (0x08) always set | 2 |
| OFF flag (0x04) always set | 2 |
| LEN flag (0x02) always set | 2 |
| FIN flag (0x01) matches fin | 2 |
| Not bare STREAM byte 0x08 | 2 |
| Injectivity (distinct fin → distinct byte) | 1 |
| Range [0x08, 0x0F] | 2 |
| FIN bit recovery round-trip | 2 |
| **Total** | **19** |

## How to run

```bash
cd formal-verification/tests/stream_frame_type
rustc --edition 2021 stream_frame_type_test.rs && ./stream_frame_type_test
```

Expected output: `19 / 19 PASS`

## Result (run 147, 2026-05-10)

```
19 / 19 PASS
```

All 19 cases pass. The Rust implementation and the Lean formal model agree
on every tested property.

## Coverage

**Covered**: all two possible `fin` values; all stated Lean theorems
(`streamTypeByte_def_false`, `streamTypeByte_def_true`,
`streamTypeByte_range`, `streamTypeByte_base_set`,
`streamTypeByte_off_set`, `streamTypeByte_len_set`,
`streamTypeByte_fin_iff`, `streamTypeByte_injective`,
`streamTypeByte_ne`, `streamTypeByte_not_default_stream`,
`streamTypeByte_is_stream_type`, `streamTypeByte_decode_fin`).

**Not covered**: the varint encoding of stream_id, offset, and length
(not modelled in the Lean spec).
