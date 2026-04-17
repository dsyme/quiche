# Informal Specification: put_varint → get_varint Cross-Module Round-Trip (T23)

**Target**: `octets/src/lib.rs` — `OctetsMut::put_varint` + `OctetsMut::get_varint`
  (and by symmetry, `Octets::get_varint`)
**Priority**: HIGH
**FV Phase**: 2 (Informal Spec)
**Status**: Identified in run 68, informal spec written in run 74.

---

## Purpose

QUIC encodes variable-length integers throughout its wire format (RFC 9000 §16).
The `put_varint` function writes a `u64` value into a mutable byte buffer as a
1, 2, 4, or 8-byte big-endian integer with a 2-bit length tag in the MSBs.
`get_varint` reads such an encoding back from a (mutable or immutable) buffer
cursor, stripping the 2-bit tag and returning the original `u64` value.

The round-trip property is: **writing then reading a varint always returns the
original value**, for all values in the valid range `[0, MAX_VAR_INT]`.

This property is foundational. Every QUIC packet field encoded as a varint
(stream IDs, offsets, lengths, error codes, flow-control limits, …) depends on
the encode/decode round-trip being lossless.

**Relation to existing proofs**: `FVSquad/Varint.lean` already proves
`varint_round_trip` — a round-trip over the pure byte-list model (`varint_encode`
→ `varint_decode`). T23 closes the gap between that pure model and the actual
OctetsMut/Octets cursor API, following the same "put-freeze-get" pattern
established in `FVSquad/OctetsRoundtrip.lean` for u8, u16, u32.

---

## Preconditions

1. `v ≤ MAX_VAR_INT` (= 4 611 686 018 427 387 903 = 2^62 − 1). Values larger
   than MAX_VAR_INT cannot be encoded; `put_varint` panics (via
   `unreachable!()`) on such inputs.
2. The mutable buffer `OctetsMut` has at least `varint_len(v)` bytes of
   remaining capacity: `buf.cap() >= varint_len(v)`.
   - `varint_len(v)` returns 1, 2, 4, or 8 depending on which of the four
     ranges `v` falls into (see §Length Thresholds below).
3. The reader cursor (either `OctetsMut` or `Octets`) is positioned at the
   same byte offset at which `put_varint` wrote. In the "freeze" pattern the
   write cursor's initial `off` becomes the read cursor's `off`.

---

## Postconditions

1. **Lossless round-trip**: after `put_varint(v)` completes, calling
   `get_varint()` on the same byte range returns `Ok(v)`.
2. **Cursor advance**: both writer and reader advance by exactly `varint_len(v)`
   bytes; no bytes before or after the encoded varint are disturbed.
3. **Exact byte layout**: the encoded bytes match the RFC 9000 §16 wire format:
   - 1-byte: `[v]`, top 2 bits = `00`
   - 2-byte: `[(v + 0x4000) / 256, (v + 0x4000) % 256]`, top 2 bits = `01`
   - 4-byte: big-endian u32 of `v + 0x80000000`, top 2 bits = `10`
   - 8-byte: big-endian u64 of `v + 0xC000000000000000`, top 2 bits = `11`
4. **Self-delimiting**: `varint_parse_len(first_byte)` equals `varint_len(v)`,
   so a receiver can determine the encoding length from the first byte alone.

---

## Invariants

- **Tag consistency**: the 2-bit length tag written by `put_varint` and parsed
  by `varint_parse_len` agree: `varint_parse_len(first_byte) == varint_len(v)`.
  This is already proved in `Varint.lean` as `varint_first_byte_tag`.
- **Buffer length preservation**: `put_varint` does not change the length of
  the underlying byte slice (only its contents and the offset field).
- **Independence**: bytes at offsets outside `[off, off + varint_len(v))` are
  unchanged after `put_varint`.

---

## Length Thresholds (varint_len)

| Value range | Encoding length | 2-bit tag (top 2 bits of first byte) |
|-------------|----------------|---------------------------------------|
| 0 ≤ v ≤ 63 | 1 byte | `00` |
| 64 ≤ v ≤ 16 383 | 2 bytes | `01` |
| 16 384 ≤ v ≤ 1 073 741 823 | 4 bytes | `10` |
| 1 073 741 824 ≤ v ≤ MAX_VAR_INT | 8 bytes | `11` |

These thresholds are defined in `varint_len` (`octets/src/lib.rs:810`) and
mirrored as `varint_len_nat` in `Varint.lean`.

---

## Edge Cases

1. **v = 0**: encodes to `[0x00]` (1 byte), round-trips to 0.
2. **v = 63 (boundary 1-byte max)**: encodes to `[0x3F]`.
3. **v = 64 (boundary 2-byte min)**: encodes to `[0x40, 0x40]`.
4. **v = MAX_VAR_INT**: encodes to `[0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]`
   (all-ones encoding), round-trips to MAX_VAR_INT.
5. **Non-minimal encoding** (`put_varint_with_len`): `put_varint_with_len(37, 2)`
   writes 37 in 2 bytes (`[0x40, 0x25]`); `get_varint` correctly reads 37 back.
   The round-trip holds for any length ≥ `varint_len(v)` provided the value fits.
6. **Buffer exactly at capacity**: if `cap() == varint_len(v)`, `put_varint`
   succeeds and consumes the entire remaining buffer.
7. **Buffer too short**: if `cap() < varint_len(v)`, `put_varint` returns
   `Err(BufferTooShort)` without modifying the buffer.

---

## Examples (Concrete Input/Output)

RFC 9000 §A.1 test vectors (also verified in `Varint.lean`):

| Value | Encoded bytes | varint_len |
|-------|--------------|------------|
| 37 | `0x25` | 1 |
| 15 293 | `0x7b 0xbd` | 2 |
| 494 878 333 | `0x9d 0x7f 0x3e 0x7d` | 4 |
| 151 288 809 941 952 652 | `0xc2 0x19 0x7c 0x5e 0xff 0x14 0xe8 0x8c` | 8 |

---

## Inferred Intent

The core intent is that `put_varint` + `get_varint` form a lossless codec pair
for all values in `[0, MAX_VAR_INT]`. The 2-bit length tag embedded in the first
byte serves dual purposes: it encodes the length (so receivers know how many bytes
to read) and it divides the value space into four non-overlapping ranges (so the
codec is self-delimiting).

The `put_varint_with_len` variant allows *over-long* encodings (e.g., writing 37
in 2 bytes) — this is explicitly permitted by RFC 9000 §16 and round-trips
correctly, since `get_varint` strips the tag bits and only returns the value.

---

## Open Questions

**OQ-T23-1**: Is the invariant `varint_parse_len(first_byte) == varint_len(v)`
required to hold for *over-long* encodings produced by `put_varint_with_len`?
It does **not** — `put_varint_with_len(37, 2)` sets the 2-byte tag, but
`varint_len(37) == 1`. The round-trip still holds; only the tag no longer matches
the minimal encoding length. The Lean spec should either restrict to minimal
encodings or state the tag property only for `put_varint` (not `put_varint_with_len`).

**OQ-T23-2**: `get_varint` on `OctetsMut` and on `Octets` have nearly identical
implementations (both read from `self.buf[self.off..]`). The Lean proof should
confirm they are equivalent on the same underlying buffer. OctetsRoundtrip.lean
already proves `listGet_eq_octListGet` for the single-byte case; this would
generalise it to the varint case.

---

## Lean Proof Plan

The proof follows the pattern from `OctetsRoundtrip.lean`:

1. **Bridge theorem** (T23-A): `put_varint(v)` in the `OctetsMutState` model
   writes exactly `varint_encode(v)` bytes starting at `s.off`. This connects
   the pure `Varint.lean` model to the stateful cursor model.

2. **Tag theorem** (T23-B): `varint_parse_len_nat(first_byte_after_put)` equals
   `varint_len_nat(v)`. This follows directly from `varint_first_byte_tag` in
   `Varint.lean` via the bridge theorem.

3. **Round-trip theorem** (T23-C): the headline property:
   ```
   theorem putVarint_freeze_getVarint (s s' : OctetsMutState) (v : Nat)
       (hv : v ≤ MAX_VAR_INT) (h : s.putVarint v = some s') :
       OctetsMutState.getVarint { buf := s'.buf, off := s.off } =
         some (v, { buf := s'.buf, off := s.off + varint_len_nat v })
   ```

4. **Independence** (T23-D): bytes outside `[s.off, s.off + varint_len_nat v)`
   are unchanged by `put_varint`.

5. **Octets variant** (T23-E): the same round-trip holds when the reader uses
   `Octets.get_varint` (immutable cursor) rather than `OctetsMut.get_varint`,
   using the `freeze` pattern from OctetsRoundtrip.lean.

The most tractable approach is to directly expand `put_varint_with_len` case-by-case
(4 cases), use the byte-by-byte helpers from OctetsMut.lean, and apply `omega` for
the arithmetic. The `varint_round_trip` theorem in Varint.lean provides the
decode-from-list identity; the bridge connects it to the cursor state.

---

*Written by 🔬 Lean Squad (run 74, workflow 24504131685). See status issue #4.*
