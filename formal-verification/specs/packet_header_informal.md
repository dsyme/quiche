# Informal Specification: QUIC Packet Header Encode/Decode Roundtrip (T29)

**Target**: `Header::to_bytes` / `Header::from_bytes` in `quiche/src/packet.rs`
**RFC reference**: RFC 9000 §17 (QUIC packet formats)

---

## Purpose

`Header` represents the cleartext (pre-encryption) fields of a QUIC packet
header. Two internal functions form the core serialisation interface:

- `Header::to_bytes(out)` — encodes the header fields into a byte buffer.
- `Header::from_bytes(b, dcid_len)` — decodes a header from a byte buffer.

Together they should satisfy a **roundtrip property**: for any well-formed
header `h`, serialising and then deserialising `h` (with the appropriate
`dcid_len`) yields a header equal to `h`.

This specification covers both long-header packets (Initial, Retry, Handshake,
ZeroRTT, VersionNegotiation) and short-header packets (1-RTT / `Short`).

**Note**: `pkt_num`, `pkt_num_len`, and `key_phase` are set to zero/false by
`to_bytes`/`from_bytes`. Header protection (which encodes these fields
separately) is applied later by `encrypt_hdr`/`decrypt_hdr` and is out of
scope for this specification.

---

## Types

```
PacketType ::= Initial | Retry | Handshake | ZeroRTT | VersionNegotiation | Short

Header ::= {
  ty:          PacketType,
  version:     u32,            -- 0 means VersionNegotiation
  dcid:        bytes,          -- destination connection ID
  scid:        bytes,          -- source connection ID (long headers only)
  pkt_num:     u64,            -- 0 (not part of this layer)
  pkt_num_len: usize,          -- 0 (not part of this layer)
  token:       Option<bytes>,  -- Initial / Retry only
  versions:    Option<[u32]>,  -- VersionNegotiation only
  key_phase:   bool,           -- false (not part of this layer)
}
```

Wire constants:
- `FORM_BIT  = 0x80` — long-header flag in first byte
- `FIXED_BIT = 0x40` — always set in valid QUIC packets
- `TYPE_MASK = 0x30` — long-header packet type in bits 5-4
- Long-header type codes: Initial=0x00, ZeroRTT=0x01, Handshake=0x02, Retry=0x03

---

## Preconditions for `to_bytes`

| Condition | Rationale |
|-----------|-----------|
| `ty ≠ VersionNegotiation` | `to_bytes` returns `Err(InvalidPacket)` for this type |
| `out` has sufficient capacity | otherwise returns `Err(BufferTooShort)` |
| For Short: no dcid length restriction (caller supplies fixed `dcid_len`) | |
| For long headers: `dcid.len() ≤ 255`, `scid.len() ≤ 255` (implicit from `put_u8`) | |
| For Retry: `token` is `Some(_)` | `unwrap()` called on token |

---

## Postconditions for `to_bytes`

Given a well-formed header `h`:

1. **First byte encodes type and form**:
   - Short header: `first_byte & FORM_BIT == 0`, `first_byte & FIXED_BIT != 0`
   - Long header:  `first_byte & FORM_BIT != 0`, `first_byte & FIXED_BIT != 0`
   - Long header type: `(first_byte & TYPE_MASK) >> 4 == type_code(h.ty)`

2. **Long header version**: the 4 bytes after the first byte encode `h.version`
   as big-endian u32.

3. **Connection IDs**: `dcid` is length-prefixed (1-byte length then bytes);
   `scid` is length-prefixed immediately after.

4. **Token**:
   - Initial: varint-length-prefixed token bytes (empty token → varint 0)
   - Retry: raw token bytes, no length prefix

5. **Short header**: encodes only `first_byte || dcid_bytes`; no version,
   no scid, no token.

---

## Preconditions for `from_bytes`

| Condition | Rationale |
|-----------|-----------|
| Buffer is non-empty | needs at least 1 byte for first byte |
| For Short header: `dcid_len` matches the actual DCID length in the buffer | short header has no length field; caller must supply |
| For long headers with `version_is_supported(version)`: `dcid_len_field ≤ 20` | enforced: returns `Err(InvalidPacket)` otherwise |
| For long headers with `version_is_supported(version)`: `scid_len_field ≤ 20` | enforced: returns `Err(InvalidPacket)` otherwise |
| For Retry: buffer has at least 16 bytes after the token start | AEAD integrity tag |

---

## Postconditions for `from_bytes`

1. **Decoded type** matches the first byte's FORM_BIT and TYPE_MASK.
2. **Decoded version** equals the 4 bytes after the first byte (big-endian), or 0
   for VersionNegotiation (when version field == 0).
3. **Decoded dcid/scid** equal the bytes in the buffer after their length prefixes.
4. **Decoded token**:
   - Initial: the token bytes (without length prefix)
   - Retry: the buffer minus the trailing 16-byte AEAD tag
   - Other types: `None`
5. **Decoded versions** (VersionNegotiation): a list of u32s parsed from
   the remainder of the buffer.
6. **pkt_num**, **pkt_num_len**, **key_phase** are all zeroed/false (header
   protection not yet removed).

---

## Roundtrip Properties

### Property RT-1: Long-header encode-then-decode identity

For any `h` with `h.ty ∈ {Initial, Retry, Handshake, ZeroRTT}` satisfying:
- `h.dcid.len() ≤ 20` (or any length ≤ 255 for unknown versions)
- `h.scid.len() ≤ 20` (or any length ≤ 255 for unknown versions)
- `h.token` is `Some(_)` for Retry, anything for Initial, `None` for others
- Sufficient buffer capacity

If `h.to_bytes(&mut b)` succeeds, then `Header::from_bytes(&mut b', h.dcid.len())`
yields `h'` with:
- `h'.ty == h.ty`
- `h'.version == h.version`
- `h'.dcid == h.dcid`
- `h'.scid == h.scid`
- `h'.token == h.token` (modulo Retry: output token excludes AEAD tag, not
  present in input either)
- `h'.pkt_num == 0`
- `h'.pkt_num_len == 0`
- `h'.key_phase == false`

### Property RT-2: Short-header encode-then-decode identity

For `h` with `h.ty == Short`, `h.scid` empty, `h.token == None`:
- `h.to_bytes(&mut b)` writes `first_byte || h.dcid`
- `Header::from_bytes(&mut b', h.dcid.len())` yields `h'` with
  `h'.ty == Short`, `h'.dcid == h.dcid`, all other fields zeroed.

### Property RT-3: Version-negotiation decode

For a buffer encoding version=0 with a long-header first byte,
`from_bytes` returns `ty == VersionNegotiation` and populates `versions`.
(`to_bytes` does NOT handle VersionNegotiation — this direction only applies
to parsing received packets.)

### Property RT-4: Type-code injectivity

The mapping `type_code: {Initial, ZeroRTT, Handshake, Retry} → {0,1,2,3}` is
injective. Therefore `from_bytes(to_bytes(h))` preserves `ty`.

### Property RT-5: Validity error on overlong DCID/SCID (QUIC v1)

For `h.version == 0x0000_0001` (QUIC v1) with `h.dcid.len() > 20`:
- `to_bytes` succeeds (no check on output side)
- `from_bytes` returns `Err(InvalidPacket)`

This is an asymmetry: the encoder does not validate CID length; the decoder
enforces RFC 9000 §17.2 for supported versions.

---

## Edge Cases

| Case | Expected behaviour |
|------|--------------------|
| Empty dcid/scid | Valid; length prefix is 0 |
| Token = Some([]) for Initial | Encodes as varint 0; decodes as Some([]) |
| token = None for Initial | Encodes as varint 0; decodes as Some([]) (open question) |
| Very long versions list in VersionNegotiation | Parsed until buffer exhausted |
| Buffer too short for claimed lengths | `from_bytes` returns `Err(BufferTooShort)` |
| Retry with zero-byte token | Valid (AEAD tag still required: buffer must be ≥16 bytes) |

---

## Open Questions

- **OQ-T29-1**: `to_bytes` for Initial with `token = None` writes varint 0 (an
  empty token). `from_bytes` then returns `token = Some([])`. Is `None` vs
  `Some([])` a meaningful distinction? The roundtrip is not perfect in this
  case — the encoder normalises `None` to `Some([])` on decode. This should be
  documented or `to_bytes` should be fixed to be consistent.

- **OQ-T29-2**: `to_bytes` does not validate CID lengths against the QUIC v1
  MAX_CID_LEN=20 limit. Should it reject oversized CIDs to make roundtrip more
  symmetric?

- **OQ-T29-3**: `pkt_num_len` in the first byte's low 2 bits is written by
  `to_bytes` (from `h.pkt_num_len - 1`) but decoded as 0 by `from_bytes`. The
  roundtrip is intentionally partial here. This is by design (header protection
  is applied separately), but it means the full `Header` struct is not a
  round-trippable type through `to_bytes`/`from_bytes` alone.

---

## Examples

### Example 1: Initial packet roundtrip
```
h = { ty: Initial, version: 0xafafafaf,
      dcid: [0xba; 9], scid: [0xbb; 7],
      token: Some([0x05, 0x06, 0x07, 0x08]), ... }
to_bytes(h) → [0xc0, 0xaf, 0xaf, 0xaf, 0xaf,
               9, 0xba×9, 7, 0xbb×7, 0x04, 0x05, 0x06, 0x07, 0x08]
from_bytes(above, 9) → h (with pkt_num=0, key_phase=false)
```

### Example 2: Short header roundtrip
```
h = { ty: Short, version: 0, dcid: [0xba; 9], ... }
to_bytes(h) → [0x40, 0xba×9]
from_bytes([0x40, 0xba×9], 9) → h
```

### Example 3: QUIC v1 oversized DCID
```
h = { ty: Initial, version: 0x0000_0001, dcid: [0xba; 21], ... }
to_bytes(h) → Ok (no encoder validation)
from_bytes(above, 21) → Err(InvalidPacket)
```

---

## Approximations and Modelling Notes

- **Buffer model**: the Lean model will represent the buffer as a `List Nat`
  (byte list). The offset cursor is abstracted as a return value.
- **pkt_num / key_phase**: not modelled — always zero. The partial roundtrip
  is explicitly documented.
- **VersionNegotiation**: `to_bytes` does not support this type; `from_bytes`
  does. The Lean model will treat this asymmetry explicitly.
- **Retry AEAD tag**: the 16-byte integrity tag is outside the Header itself
  and not modelled. The Lean model assumes the tag is already stripped from
  the input buffer (or appended separately by the caller).
- **I/O and lifetimes**: `ConnectionId` lifetime annotations are dropped;
  byte lists are owned values.
