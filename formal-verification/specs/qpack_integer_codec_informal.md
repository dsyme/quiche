# Informal Specification: QPACK Integer Encoding / Decoding

**Source**:
- Encoder: `quiche/src/h3/qpack/encoder.rs` — `encode_int`
- Decoder: `quiche/src/h3/qpack/decoder.rs` — `decode_int`
**RFC**: RFC 7541 §5.1 (HPACK integer representation, reused by QPACK/RFC 9204)

---

## Purpose

QPACK (and HPACK) encode arbitrary-length unsigned integers into a variable
number of bytes. A **prefix** parameter (1–8 bits) controls how many bits of
the first byte are used for the integer; the remaining bits of that byte are
used for an opcode or flag.

`encode_int(v, first, prefix, buf)`: writes the integer `v` into `buf`,
OR-ing the high bits of the first byte with `first`.

`decode_int(buf, prefix)`: reads the next integer from `buf`, interpreting
the low `prefix` bits of the first byte, continuing with length-extended
bytes if needed.

---

## Preconditions

### `encode_int`
- `1 ≤ prefix ≤ 8` (only values 1–7 are used in practice; 8 would consume the
  full first byte)
- `v` is a valid `u64`
- `buf` has sufficient capacity to hold the encoded result
- `first` has its low `prefix` bits clear (caller responsibility)

### `decode_int`
- `1 ≤ prefix ≤ 8`
- `buf` contains a well-formed encoding (as produced by `encode_int`)
- Sufficient bytes remain in `buf`

---

## Postconditions

### `encode_int`
- If `v < 2^prefix - 1` (fits in prefix bits): encodes in **exactly 1 byte**
  with value `first | v`.
- Otherwise: first byte is `first | (2^prefix - 1)`, followed by continuation
  bytes encoding `v - (2^prefix - 1)` in base-128 (little-endian 7-bit chunks),
  each with the high bit set to indicate continuation, except the last byte
  whose high bit is 0.

### `decode_int`
- Returns the integer encoded by `encode_int` at the current buffer position.
- Advances the buffer past the consumed bytes.

---

## Invariants

1. **Round-trip**: `decode_int(encode_int(v, 0, prefix, _), prefix) = v`
   for all valid `v` and `1 ≤ prefix ≤ 7`.

2. **Single-byte case**: `v < 2^prefix - 1 → encode_int writes exactly 1 byte`.

3. **Minimum encoding**: for any prefix, `v = 2^prefix - 1` is the smallest
   value requiring a multi-byte encoding.

4. **Continuation bit invariant**: all continuation bytes except the last have
   bit 7 set; the last continuation byte has bit 7 clear.

5. **Overflow protection**: `decode_int` returns `Err(BufferTooShort)` if
   a shift overflow or integer overflow would occur. The checked arithmetic
   (`checked_shl`, `checked_add`) ensures no silent overflow.

6. **Prefix mask**: the mask is always `2^prefix - 1`. For `prefix = 7`, mask
   is 127 (0x7F); for `prefix = 3`, mask is 7.

---

## Edge Cases

- `v = 0`: encodes as single byte `first | 0 = first`.
- `v = 2^prefix - 1`: minimum multi-byte case; first byte is `first | mask`,
  followed by a single `0x00` byte.
- `v = 2^64 - 1` (u64::MAX): encodes in 10 bytes (7-bit chunks of 64 bits);
  `decode_int` should return it without overflow.
- `prefix = 1`: mask = 1; only values 0 encode in single byte; value 1 and
  above require multi-byte encoding.
- Empty buffer: `decode_int` returns `Err(BufferTooShort)`.
- Truncated encoding (final continuation byte missing): `decode_int` returns
  `Err(BufferTooShort)`.

---

## Examples

For `prefix = 5` (mask = 31 = 0x1F), `first = 0x00`:
- `v = 10`:  encodes as `[0x0A]` (single byte, fits in 5 bits)
- `v = 31`:  encodes as `[0x1F, 0x00]` (mask byte + zero-continuation)
- `v = 32`:  encodes as `[0x1F, 0x01]` (mask + 1 continuation byte for v-mask=1)
- `v = 1337`: encodes as `[0x1F, 0x9A, 0x0A]` (from RFC 7541 example §5.1)

---

## Inferred Intent

The `encode_int`/`decode_int` pair implements the standard HPACK/QPACK integer
encoding from RFC 7541 §5.1 verbatim. The `first` parameter allows the caller
to pack flag bits into the unused high bits of the first byte. The `prefix`
parameter determines how many low bits of the first byte carry the integer.

This is a pure encoding/decoding function: no side effects beyond buffer
position advancement. The implementation uses `checked_*` arithmetic for
overflow safety, returning `Err(BufferTooShort)` on overflow (a conservative
error code chosen for simplicity rather than semantic accuracy).

---

## Open Questions

- OQ-QPACKINT-1: For `prefix = 8`, the mask is 255 = 0xFF; is `first`
  guaranteed to be 0x00 in that case? No callers use prefix=8 in the codebase.
- OQ-QPACKINT-2: The `first` parameter ORs into the first byte's high bits.
  If `first` has bits set within the prefix range, behaviour is undefined.
  Should there be a debug assertion `first & mask == 0`?
- OQ-QPACKINT-3: `decode_int` uses `BufferTooShort` for integer overflow — is
  that the right error? A dedicated `IntegerOverflow` variant might be clearer.
