# Informal Specification: `OctetsMut` byte-buffer read/write

> 🔬 *Written by Lean Squad automated formal verification (run 52).*

**Source**: `octets/src/lib.rs` — `struct OctetsMut<'a>`, lines 391–800.

---

## Purpose

`OctetsMut` is a **cursor-based, mutable byte buffer** used throughout `quiche`
and `octets` for zero-copy serialisation and deserialisation of QUIC and HTTP/3
wire formats.  It wraps a `&mut [u8]` slice and tracks a current read/write
offset (`off`), so that sequential `put_*` and `get_*` calls advance the cursor
without allocating or copying.

The companion immutable type `Octets<'a>` provides the same cursor semantics
for read-only slices.  `OctetsMut` supports both reads and writes.

---

## Data structure

```
OctetsMut {
  buf : &mut [u8]   -- the backing slice; length is fixed at construction
  off : usize       -- current cursor position; 0 ≤ off ≤ buf.len()
}
```

Derived accessors:

| Accessor | Definition | Semantics |
|----------|-----------|-----------|
| `len()` | `buf.len()` | Total buffer length (fixed) |
| `off()` | `self.off` | Current cursor position |
| `cap()` | `buf.len() − self.off` | Remaining bytes after the cursor |

**Primary invariant**: `off + cap = len`, i.e. `self.off + self.cap() = self.buf.len()`.

---

## Preconditions

All write and read operations require `cap() ≥ n`, where `n` is the width
in bytes of the value being read or written.  Operations return
`Err(BufferTooShortError)` when this precondition is not met.

---

## Operations and their postconditions

### Cursor movement

| Operation | Precondition | Effect on `off` | Effect on `buf` |
|-----------|-------------|-----------------|-----------------|
| `skip(n)` | `cap() ≥ n` | `off += n` | unchanged |
| `rewind(n)` | `off ≥ n` | `off -= n` | unchanged |

`skip` and `rewind` are inverses: `skip(n); rewind(n)` restores the original
offset (when both preconditions hold).

### Write operations

| Operation | Width (bytes) | Encoding | Postcondition |
|-----------|--------------|----------|---------------|
| `put_u8(v)` | 1 | literal | `buf[off] = v`, `off' = off + 1` |
| `put_u16(v)` | 2 | big-endian | `buf[off..off+2] = [v >> 8, v & 0xff]`, `off' = off + 2` |
| `put_u32(v)` | 4 | big-endian | `buf[off..off+4]` = big-endian encoding of `v`, `off' = off + 4` |
| `put_u64(v)` | 8 | big-endian | `buf[off..off+8]` = big-endian encoding of `v`, `off' = off + 8` |
| `put_bytes(src)` | `src.len()` | verbatim copy | `buf[off..off+n] = src`, `off' = off + n` |
| `put_varint(v)` | `varint_len(v)` | RFC 9000 §16 | see `Varint.lean` |

After each `put_*`, `cap()` decreases by the width; `len()` is unchanged.

### Read operations

| Operation | Width | Encoding | Return value |
|-----------|-------|----------|--------------|
| `get_u8()` | 1 | literal | `buf[off]` as `u8`; `off' = off + 1` |
| `get_u16()` | 2 | big-endian | `(buf[off] << 8) | buf[off+1]`; `off' = off + 2` |
| `get_u32()` | 4 | big-endian | 4-byte big-endian decode; `off' = off + 4` |
| `get_u64()` | 8 | big-endian | 8-byte big-endian decode; `off' = off + 8` |
| `peek_u8()` | 1 | literal | `buf[off]` as `u8`; `off` unchanged |
| `get_bytes(n)` | `n` | slice | `&buf[off..off+n]`; `off' = off + n` |
| `get_varint()` | variable | RFC 9000 §16 | see `Varint.lean` |

---

## Invariants

1. **Cursor bounds**: `0 ≤ off ≤ buf.len()` at all times.
2. **Capacity identity**: `off + cap() = len()` always holds.
3. **Buffer immutability**: `len()` does not change after construction.
4. **Monotonic write cursor**: `put_*` operations strictly increase `off`
   (unless `rewind` is called).

---

## Round-trip properties (key correctness claims)

These are the properties most worth formally verifying:

1. **u8 round-trip**: `put_u8(v); rewind(1); get_u8() = v` (when `cap ≥ 1`)
2. **u16 round-trip**: `put_u16(v); rewind(2); get_u16() = v` (when `cap ≥ 2`)
3. **u32 round-trip**: `put_u32(v); rewind(4); get_u32() = v` (when `cap ≥ 4`)
4. **u64 round-trip**: `put_u64(v); rewind(8); get_u64() = v` (when `cap ≥ 8`)
5. **skip/rewind inverse**: `skip(n); rewind(n)` restores `off` (when both preconditions hold)
6. **rewind/skip inverse**: `rewind(n); skip(n)` restores `off` (when both preconditions hold)
7. **cap decrements correctly**: after `put_u8`, `cap'() = cap() − 1`
8. **put preserves len**: `put_u8` does not change `len()`
9. **cursor after put**: `off'() = off() + width` after a successful `put_*`

---

## Edge cases

- **Buffer too short**: `put_u8` when `cap() = 0` → `Err(BufferTooShortError)`.
  The cursor is NOT advanced on error.
- **`rewind` past start**: `rewind(n)` when `off < n` → `Err(BufferTooShortError)`.
- **Zero-length skip**: `skip(0)` is a no-op; always succeeds.
- **Zero-length buffer**: `len() = 0` → all reads and writes return immediately
  with error; `is_empty()` returns `true`.
- **put_u16(0)** / **put_u32(0)**: writes zero bytes in big-endian; get recovers 0.
- **Byte-order correctness**: `get_u16()` on a buffer written by `put_u16(v)` must
  recover `v` regardless of the host's native endianness (always big-endian on wire).

---

## Examples

```
buf = [0u8; 4], off = 0
put_u8(0xAB)  → buf = [0xAB, 0, 0, 0], off = 1, cap = 3
put_u8(0xCD)  → buf = [0xAB, 0xCD, 0, 0], off = 2, cap = 2
rewind(2)     → off = 0, cap = 4
get_u16()     → 0xABCD, off = 2, cap = 2

buf = [0u8; 4], off = 0
put_u32(0x01020304) → buf = [0x01, 0x02, 0x03, 0x04], off = 4, cap = 0
rewind(4)           → off = 0, cap = 4
get_u32()           → 0x01020304 ✓
```

---

## Inferred intent

The design intent is:
- Minimise allocation: the buffer is borrowed, not owned.
- Enable incremental serialisation: callers write fields left-to-right by calling
  `put_*` in sequence, then send the entire backing slice.
- Enable incremental parsing: callers read fields left-to-right by calling
  `get_*` in sequence.
- Support backtracking for length-prefix patterns: a caller can write a
  placeholder, serialise a body, then `rewind` and overwrite the placeholder
  with the measured body length (common in TLS/QUIC frame encoding).

---

## Open questions

- **OQ-1**: For `put_u16`, the Rust implementation uses big-endian byte order
  (network byte order). Is this guaranteed by the macro, or is it
  platform-dependent? (Answer: confirmed big-endian by `byteorder::BigEndian`
  usage in the macros — see `get_u!` and `put_u!` macro definitions.)
- **OQ-2**: Does `put_bytes` fail atomically? If `cap() < src.len()`, is it
  guaranteed that NO bytes are written? (Answer: yes — the length check precedes
  the copy.)
- **OQ-3**: The Lean model will abstract over the actual byte contents of the
  buffer, modelling `put_u8(v); get_u8()` purely algebraically rather than
  tracking byte arrays. Is this sufficient for the key properties?

---

## Approximations for Lean model

1. **`u8`/`u16`/`u32`/`u64` as `Nat`**: values modelled without overflow.
   Round-trip theorems hold unconditionally over `Nat`; separately verify that
   Rust's wrapping behaviour is irrelevant (values are in-range by precondition).
2. **Buffer contents as abstract `List Nat`**: rather than a mutable `Array`,
   the Lean model tracks the buffer as a pure list, updated functionally.
3. **Error paths as preconditions**: `Err(BufferTooShortError)` is modelled by
   requiring the relevant precondition (`cap ≥ n`); the error return is not
   tracked in the Lean model.
4. **Lifetime and aliasing**: `&mut [u8]` ensures exclusive access in Rust;
   the Lean model assumes this and does not need to model ownership/borrowing.
5. **`put_varint` and `get_varint`**: already covered in `FVSquad/Varint.lean`;
   not duplicated here. The `OctetsMut` model focuses on fixed-width primitives.
