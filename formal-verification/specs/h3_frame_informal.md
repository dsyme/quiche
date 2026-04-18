# Informal Specification: HTTP/3 Frame Type Codec Round-Trip (T31)

> 🔬 *Written by Lean Squad automated formal verification.*

**Target**: `Frame::to_bytes` / `Frame::from_bytes` in
`quiche/src/h3/frame.rs`

**RFC reference**: RFC 9114 §7 (HTTP/3 frames)

---

## Purpose

The `Frame` enum represents all HTTP/3 frame types that quiche can send or
receive on a QUIC stream. The two key operations are:

- `Frame::to_bytes(&self, buf: &mut OctetsMut) → Result<usize>`: serialise a
  frame into the wire format, returning the number of bytes written.
- `Frame::from_bytes(frame_type: u64, payload_length: u64, bytes: &[u8]) →
  Result<Frame>`: deserialise a frame payload given an already-parsed type ID
  and payload length.

The primary correctness property is the **round-trip invariant**: for every
frame `f` of a supported type, writing `f` into a buffer and then parsing it
back produces an equal frame.

---

## Frame Types and Type IDs

| Frame type | Type ID | Defined in |
|------------|---------|-----------|
| `Data` | 0x0 | RFC 9114 §7.2.1 |
| `Headers` | 0x1 | RFC 9114 §7.2.2 |
| `CancelPush` | 0x3 | RFC 9114 §7.2.3 |
| `Settings` | 0x4 | RFC 9114 §7.2.4 |
| `PushPromise` | 0x5 | RFC 9114 §7.2.5 |
| `GoAway` | 0x7 | RFC 9114 §7.2.6 |
| `MaxPushId` | 0xD | RFC 9114 §7.2.7 |
| `PriorityUpdateRequest` | 0xF0700 | RFC 9218 §7.1 |
| `PriorityUpdatePush` | 0xF0701 | RFC 9218 §7.2 |
| `Unknown` | (any) | passthrough |

---

## Wire Format

Each frame on the wire consists of:
1. A QUIC variable-length integer (varint): the **frame type**.
2. A QUIC variable-length integer: the **payload length** in bytes.
3. The **payload** of exactly that many bytes.

`to_bytes` writes all three components. `from_bytes` receives the type and
payload length separately (already parsed by the H3 connection layer) and
reads only the payload from the supplied slice.

### Per-variant payload encoding

- **Data** / **Headers**: payload is raw bytes (`payload` / `header_block`).
  Payload length = `bytes.len()`.

- **CancelPush**, **GoAway**, **MaxPushId**: payload is a single varint
  (`push_id` / `id` / `push_id`). Payload length = `varint_len(id)`.

- **PushPromise**: payload = varint `push_id` followed by raw bytes
  `header_block`. Payload length = `varint_len(push_id) + header_block.len()`.

- **PriorityUpdateRequest** / **PriorityUpdatePush**: payload = varint
  `prioritized_element_id` followed by raw bytes `priority_field_value`.
  Payload length = `varint_len(prioritized_element_id) +
  priority_field_value.len()`.

- **Settings**: payload = sequence of (varint key, varint value) pairs.
  Payload length is pre-computed as the sum of `varint_len(k) + varint_len(v)`
  for each active setting. Maximum payload size is `MAX_SETTINGS_PAYLOAD_SIZE`
  = 256 bytes.

- **Unknown**: payload is raw bytes. Payload length = `payload.len()`.

---

## Preconditions

For `to_bytes(f, buf)` to succeed:
1. `buf` must have capacity for the full serialised frame.
2. All varint fields must be in the QUIC varint range [0, 2^62 − 1].
3. For `Settings`, each value of `connect_protocol_enabled` and `h3_datagram`
   must be 0 or 1 (not checked on write — only on read).

For `from_bytes(type_id, payload_len, bytes)` to succeed:
1. `bytes.len() ≥ payload_len`.
2. The payload must be well-formed for the given `type_id`.
3. For `Settings`: `payload_len ≤ MAX_SETTINGS_PAYLOAD_SIZE` (256 bytes).
4. For `Settings`: `connect_protocol_enabled` and `h3_datagram` values must be
   0 or 1; reserved identifiers (0x0, 0x2, 0x3, 0x4, 0x5) cause
   `Error::SettingsError`.

---

## Postconditions

### `to_bytes`
- Returns `Ok(n)` where `n` is the number of bytes consumed from `buf`.
- `n = varint_len(type_id) + varint_len(payload_len) + payload_len`.
- The buffer cursor advances by exactly `n`.

### `from_bytes`
- Returns `Ok(frame)` where `frame` is the decoded frame variant.
- The returned frame satisfies the invariants below.

---

## Round-Trip Invariants

Let `buf` be a sufficiently large buffer and `f` a frame. Let:
- `n = f.to_bytes(&mut buf).unwrap()`
- `(type_id, payload_len, payload_bytes)` be the wire layout of the written
  frame (where `type_id` and `payload_len` are read as varints from `buf`).

Then: `Frame::from_bytes(type_id, payload_len, payload_bytes).unwrap() = f`

with the following **important caveats**:

### Round-trip holds exactly for:
- `Data { payload }` — byte-for-byte
- `Headers { header_block }` — byte-for-byte
- `CancelPush { push_id }` — exact
- `GoAway { id }` — exact
- `MaxPushId { push_id }` — exact
- `Unknown { raw_type, payload }` — exact
- `PushPromise { push_id, header_block }` — exact
- `PriorityUpdateRequest { prioritized_element_id, priority_field_value }` — exact
- `PriorityUpdatePush { .. }` — exact

### Round-trip for Settings is *partial*:
The `Settings` variant has two representation fields (`grease`, `raw`) that are
**not preserved** by round-trip:
- The `grease` field is set to `None` on parsing (grease pairs go into
  `additional_settings`).
- The `raw` field is reconstructed by the parser from the wire bytes; it may
  differ from the original `raw` if `to_bytes` normalises certain settings.
- `additional_settings` on write includes grease; on parse, unknown identifiers
  go into `additional_settings`.

The exact round-trip for Settings is:
```
to_bytes(f) >> from_bytes = f'
```
where `f'` may differ from `f` in `grease` (set to None) and `raw` (set to
the actual on-wire pairs). The **semantic** fields (`max_field_section_size`,
`qpack_max_table_capacity`, `qpack_blocked_streams`, `connect_protocol_enabled`,
`h3_datagram`) are preserved exactly.

---

## Invariants

### Type-ID injectivity
Different frame variants have distinct type IDs. There is no ambiguity in
the mapping:
- `type_id_of(Data) = 0x0`
- `type_id_of(Headers) = 0x1`
- `type_id_of(CancelPush) = 0x3`
- `type_id_of(Settings) = 0x4`
- `type_id_of(PushPromise) = 0x5`
- `type_id_of(GoAway) = 0x7`
- `type_id_of(MaxPushId) = 0xD`
- `type_id_of(PriorityUpdateRequest) = 0xF0700`
- `type_id_of(PriorityUpdatePush) = 0xF0701`

All other type IDs produce `Frame::Unknown`.

### Payload length consistency
For every successfully serialised frame, `to_bytes` returns exactly
`varint_len(type_id) + varint_len(payload_len) + payload_len` bytes, matching
the quiche `to_bytes` return value computation `before - buf.cap()`.

### Settings payload size guard
A `Settings` frame payload of more than 256 bytes is rejected with
`Error::ExcessiveLoad`. This prevents unbounded parsing work for malformed
SETTINGS frames.

### Reserved Settings identifiers
Settings identifiers 0x0, 0x2, 0x3, 0x4, 0x5 are reserved (overlap with
HTTP/2). Receiving any of these causes `Error::SettingsError`.

### Boolean Settings values
`connect_protocol_enabled` and `h3_datagram` must be 0 or 1. Any other value
causes `Error::SettingsError`.

---

## Edge Cases

1. **Empty payload frames**: `Data {}` with `payload = vec![]` writes 2 bytes
   (type varint + length varint 0). `from_bytes(0x0, 0, &[])` must return
   `Frame::Data { payload: vec![] }`. The `TODO` comment in `from_bytes`
   notes 0-length frame handling is not yet complete for all types.

2. **Unknown type IDs**: Any `type_id` not matching a known variant produces
   `Frame::Unknown { raw_type: type_id, payload: bytes.to_vec() }`.

3. **Maximum varint payload**: A `GoAway { id: 2^62 - 1 }` uses 8-byte varint
   encoding for `id`, producing a payload of 8 bytes. `varint_len(2^62 - 1) = 8`.

4. **Settings with all fields None**: An empty Settings frame (all fields None,
   no grease, no additional) writes a 2-byte frame (type 0x4, payload length 0).
   `from_bytes(0x4, 0, &[])` produces `Frame::Settings { all_none, raw: Some([]) }`.

5. **Settings GREASE round-trip**: GREASE identifiers written via `grease:
   Some((k, v))` are read back with `grease: None` but appear in
   `additional_settings`. The semantic content is preserved but the
   representation diverges.

---

## Examples

From the test suite in `frame.rs`:

```rust
// Data frame round-trip
let payload = vec![1u8; 12];
let frame = Frame::Data { payload };
// to_bytes writes: type=0x00 (1 byte), length=12 (1 byte), 12 payload bytes
// from_bytes(0, 12, &buf[2..]) == frame

// CancelPush round-trip
let frame = Frame::CancelPush { push_id: 0 };
// to_bytes writes: type=0x03 (1 byte), length=1 (1 byte), push_id=0 (1 byte)
// from_bytes(3, 1, &buf[2..]) == frame

// Settings round-trip (semantic fields preserved)
let frame = Frame::Settings {
    max_field_section_size: Some(1024), /* rest None */
};
// to_bytes writes: type=0x04 (1 byte), length=3 (1 byte), 0x06 0x51 0x00 (3 bytes)
// from_bytes(4, 3, &buf[2..]).unwrap() has max_field_section_size = Some(1024)
```

---

## Inferred Intent

The round-trip invariant is the primary design contract. The test suite
(`frame.rs` tests module) exercises round-trips for each frame type explicitly,
confirming this is the intended invariant.

The partial-round-trip for Settings (where `grease` is not preserved) is
intentional: GREASE identifiers are implementation-specific state used for
interoperability testing; they are not expected to survive a full parse cycle.

The `raw` field in Settings is a diagnostic field used for unknown-identifier
passthrough; it is reconstructed from the wire bytes rather than being
user-controlled.

---

## Open Questions

1. **OQ-T31-1** (edge case): What happens when `from_bytes` is called with
   `payload_length > bytes.len()`? The `Octets::get_bytes` call will return
   `Error::BufferTooShort`. Is this documented and tested?

2. **OQ-T31-2** (0-length frames): The `TODO` comment in `from_bytes` notes
   that 0-length frame handling is incomplete. Which frame types are affected?
   A `Data {}` frame with empty payload currently parses correctly, but what
   about `CancelPush` or `GoAway` with payload_length=0?

3. **OQ-T31-3** (Settings GREASE reconstruction): When `to_bytes` writes a
   Settings frame with `grease: Some((k, v))` and the resulting bytes are
   re-parsed, the `raw` field will contain `(k, v)` as an unknown identifier.
   Is the `raw` field considered stable API or only for diagnostics?

4. **OQ-T31-4** (payload length vs. actual bytes): Is there a precondition
   that `payload_length` exactly equals `bytes.len()`? The `from_bytes`
   function uses `b.off() < settings_length` for Settings, so it tolerates
   trailing bytes in the payload slice. For other types, it calls
   `get_bytes(payload_length as usize)` which reads exactly `payload_length`
   bytes regardless of `bytes.len()`.

---

## Approximations Needed for Lean Formalisation

1. **Buffer I/O**: The `OctetsMut`/`Octets` buffer infrastructure must be
   modelled. The existing `OctetsMut.lean` and `OctetsRoundtrip.lean` provide
   the foundation, but `put_bytes`/`get_bytes` (bulk copy) is not yet modelled.
   For the FV scope, model each frame type as a pure function from frame value
   to byte list (abstracting the buffer cursor).

2. **Varint encoding**: `varint_len` and `put_varint`/`get_varint` are already
   modelled in `Varint.lean`, `OctetsMut.lean`, and `VarIntRoundtrip.lean`.

3. **Settings GREASE**: The partial round-trip for Settings is complex. For the
   first formalisation pass, scope to the **simple frame types** (GoAway,
   MaxPushId, CancelPush) that have exact round-trips and single-varint payloads.

4. **Error handling**: `from_bytes` returns `Result<Frame>`; for the FV model,
   prove that for well-formed inputs the result is `Ok(frame)` matching the
   input.

5. **`put_bytes`/`get_bytes`**: Bulk byte copy is not yet modelled in the FV
   suite. For `Data` and `Headers` frames, the round-trip trivially holds if
   bytes are copied exactly; a bounded-size model could verify this.

---

## Recommended Lean Formalisation Scope

**Phase 3 (formal spec)**: Focus on the three simplest frame types:
- `GoAway { id }` — single-varint payload
- `MaxPushId { push_id }` — single-varint payload
- `CancelPush { push_id }` — single-varint payload

For each, state:
1. `typeId_of` — the frame type constant is correct
2. `payloadLen_eq` — payload length equals `varint_len(field)`
3. `round_trip` — `from_bytes(type_id, payload_len, to_bytes_payload(f)) = f`

**Phase 4 (implementation extraction)**:
- Define a pure Lean model for each of the three simple frame types
- Model `to_bytes` as a function from frame to byte list
- Model `from_bytes` as a function from `(type_id, byte_list)` to frame option

**Phase 5 (proofs)**:
- Prove the three round-trip theorems
- Prove payload-length consistency (`to_bytes` writes the correct number of bytes)
- Prove type-ID injectivity
