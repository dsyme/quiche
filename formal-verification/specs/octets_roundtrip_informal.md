# Informal Specification: Octets ↔ OctetsMut Cross-Module Round-Trip

**Target**: Cross-module consistency between `Octets<'a>` and `OctetsMut<'a>`
**Source**: `octets/src/lib.rs` (lines 135–800)
**FV file**: `formal-verification/lean/FVSquad/OctetsRoundtrip.lean`

🔬 *Lean Squad — automated formal verification.*

---

## Purpose

The `octets` crate provides two cursor types over a shared byte slice:

- **`Octets<'a>`**: immutable read cursor — borrows `&'a [u8]`, provides
  `get_u8`, `get_u16`, `get_u32`, `get_u64`, and `get_varint` operations
  that advance an internal offset.
- **`OctetsMut<'a>`**: mutable read/write cursor — borrows `&'a mut [u8]`,
  provides both `get_*` and `put_*` operations.

The two types share the same in-memory byte representation: both hold a
pointer to a `u8` slice and an offset. In real usage, the usual pattern is:

1. Allocate a zeroed byte buffer.
2. Write fields into it using an `OctetsMut` cursor.
3. When writing is done, the `OctetsMut` borrow ends and the raw bytes are
   accessible.
4. Wrap those same bytes in an `Octets` cursor to parse/verify them.

The specification captures the **consistency requirement** between the two
types: whatever `put_*` writes into the underlying bytes, a subsequent
`get_*` on an `Octets` cursor over the *same* buffer at the *same* position
must read back the original value.

---

## Preconditions

- The buffer is large enough to hold the value being written:
  - `put_u8`: at least 1 byte remaining (`cap ≥ 1`)
  - `put_u16`: at least 2 bytes remaining (`cap ≥ 2`)
  - `put_u32`: at least 4 bytes remaining (`cap ≥ 4`)
  - `put_u64`: at least 8 bytes remaining (`cap ≥ 8`)
- For `put_u16`, the value `v` satisfies `v < 65536` (fits in 16 bits).
- For `put_u32`, the value `v` satisfies `v < 2^32` (fits in 32 bits).
- For `put_u64`, the value `v` satisfies `v < 2^64` (fits in 64 bits).

---

## Postconditions

### Read-helper equivalence

The internal list-read helpers in the two Lean models (`listGet` from
`OctetsMut.lean` and `octListGet` from `Octets.lean`) are definitionally
equal:

```
∀ (l : List Nat) (i : Nat), listGet l i = octListGet l i
```

### OctetsMut.getU8 ↔ OctetsState.getU8 on the same buffer

Reading a byte at position `off` from the same underlying byte list gives
the same result regardless of whether you use the `OctetsMutState.getU8` or
`OctetsState.getU8` cursor:

```
∀ buf off, OctetsMutState.getU8 {buf, off} =
  (OctetsState.getU8 {buf, off}).map (fun (v, s') => (v, {buf := s'.buf, off := s'.off}))
```

### put_u8 / Octets.getU8 round-trip

After writing byte `v` at offset `off` with `OctetsMut.put_u8`, an
`Octets` cursor positioned at `off` reads back exactly `v`:

```
putU8 {buf, off} v = some s' →
  OctetsState.getU8 {buf := s'.buf, off} = some (v, {buf := s'.buf, off := off + 1})
```

### put_u16 / Octets.getU16 round-trip (v < 65536)

After writing a 16-bit value `v` in network byte order at offset `off`, an
`Octets` cursor at `off` reads back exactly `v`:

```
putU16 {buf, off} v = some s' → v < 65536 →
  OctetsState.getU16 {buf := s'.buf, off} = some (v, {buf := s'.buf, off := off + 2})
```

### put_u32 / Octets.getU32 round-trip (v < 2^32)

```
putU32 {buf, off} v = some s' → v < 2^32 →
  OctetsState.getU32 {buf := s'.buf, off} = some (v, {buf := s'.buf, off := off + 4})
```

### Independent bytes: put then getU8 at a different offset is unchanged

Writing at offset `off` does not modify the byte at any other offset `j ≠ off`:

```
putU8 {buf, off} v = some s' → j ≠ off →
  octListGet s'.buf j = octListGet buf j
```

---

## Invariants

- Both cursor types maintain the invariant `off ≤ buf.length`.
- `put_u8` preserves the length of the underlying buffer.
- After `put_u8 v` at offset `off`, the buffer at positions `off` contains
  `v` and all other positions are unchanged.

---

## Edge Cases

- **Buffer too short**: if `cap = 0`, `put_u8` returns `none` and the
  buffer is not modified; the corresponding `get_u8` also returns `none`.
- **Offset at end**: `off = buf.length` means cap = 0; both read and write
  operations fail.
- **Zero-length buffer**: `put_u8` immediately fails; no bytes are written.
- **Value = 0**: `put_u8 0` writes a zero byte; reading it back must return 0.
- **Maximum byte value**: `put_u8 255` writes `0xFF`; reading it back must
  return 255.

---

## Examples

```
-- Write 0x42 at offset 0 into a 4-byte zero buffer, then read with Octets:
-- OctetsMut: { buf = [0,0,0,0], off = 0 } →put_u8 0x42→ { buf = [0x42,0,0,0], off = 1 }
-- Octets:    { buf = [0x42,0,0,0], off = 0 } →get_u8→ (0x42, { off = 1 })

-- Write 0x0102 as U16 at offset 0, then read:
-- [0x01, 0x02, 0, 0] read at offset 0 gives 256*1+2 = 258 = 0x0102

-- Write 0x01020304 as U32 at offset 0, then read:
-- [0x01, 0x02, 0x03, 0x04] read at offset 0 gives 16777216+131072+768+4 = 0x01020304
```

---

## Inferred Intent

The two cursor types are designed to share the same wire representation.
The `put_*` / `get_*` naming mirrors network-packet serialization workflows:
write with `OctetsMut`, then hand the buffer to a parser that uses `Octets`.
The formal specification captures that this workflow is internally consistent:
the bytes written by `OctetsMut` are exactly the bytes read back by `Octets`.

---

## Open Questions

- **OQ-A**: Is the `put_u64` round-trip intentionally limited to values
  `v < 2^64`? In Lean we model `Nat` (unbounded), but the Rust type is `u64`
  so the precondition is implicitly guaranteed by the type system.
- **OQ-B**: The `get_varint` operation has masking (`& 0x3fff`, `& 0x3fffffff`,
  `& 0x3fffffffffffffff`). Should a varint round-trip spec cover `put_varint /
  get_varint` as well? (Not in scope for this target — deferred to Varint.lean
  which already covers varint encoding.)
