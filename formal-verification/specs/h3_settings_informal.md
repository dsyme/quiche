# Informal Specification: H3 Settings Frame Invariants (T33)

> 🔬 *Written by Lean Squad automated formal verification.*

**Target**: `Frame::Settings` variant — `to_bytes` serialisation and
`parse_settings_frame` deserialisation in `quiche/src/h3/frame.rs`

**RFC reference**: RFC 9114 §7.2.4 (SETTINGS frame)

---

## Purpose

The HTTP/3 `SETTINGS` frame carries configuration parameters from one endpoint
to the other at the start of a connection. Parameters include QPACK table
capacities, maximum header section sizes, datagram support flags, and
extension-defined values. The implementation must:

1. **Serialise** a structured `Frame::Settings` value into a byte buffer
   (via `to_bytes`).
2. **Deserialise** a byte slice with a pre-parsed frame type and payload length
   into a `Frame::Settings` value (via `parse_settings_frame`, called from
   `Frame::from_bytes`).
3. **Enforce validity constraints** during deserialisation — reject frames with
   reserved identifiers, boolean settings outside {0, 1}, or oversized
   payloads.

---

## Settings Parameters

| Identifier (hex) | Constant | Type | Range |
|-------------------|----------|------|-------|
| 0x1 | `SETTINGS_QPACK_MAX_TABLE_CAPACITY` | u64 | any varint |
| 0x6 | `SETTINGS_MAX_FIELD_SECTION_SIZE` | u64 | any varint |
| 0x7 | `SETTINGS_QPACK_BLOCKED_STREAMS` | u64 | any varint |
| 0x8 | `SETTINGS_ENABLE_CONNECT_PROTOCOL` | u64 | 0 or 1 only |
| 0x33 | `SETTINGS_H3_DATAGRAM` | u64 | 0 or 1 only |
| 0x276 | `SETTINGS_H3_DATAGRAM_00` | u64 | 0 or 1 only |

### Reserved identifiers

The identifiers 0x0, 0x2, 0x3, 0x4, 0x5 overlap with HTTP/2 settings and
MUST be rejected during parsing with a `SettingsError`.

### Unknown identifiers

Any identifier not matching a known constant and not in the reserved set is
stored in `additional_settings: Option<Vec<(u64, u64)>>` without error.

---

## Preconditions (to_bytes)

- The write buffer `b` has enough capacity to hold the serialised frame.
- `connect_protocol_enabled`, `h3_datagram` (if `Some`) hold values that were
  themselves parsed (so at most 0 or 1 — but `to_bytes` does not re-validate).
- For `additional_settings`, each `(identifier, value)` pair holds valid
  varint-encodable u64 values.
- `MAX_SETTINGS_PAYLOAD_SIZE = 256` bytes constrains the total payload.

## Postconditions (to_bytes)

After a successful `to_bytes` call:

1. The frame type varint `SETTINGS_FRAME_TYPE_ID` (0x4) is written first.
2. The payload length varint (the pre-computed `len`) is written second.
3. Each active setting is written as a `(identifier_varint, value_varint)` pair
   in a fixed order: `max_field_section_size`, `qpack_max_table_capacity`,
   `qpack_blocked_streams`, `connect_protocol_enabled`, `h3_datagram`
   (×2 identifiers: 0x276 then 0x33), `grease`, `additional_settings`.
4. The number of bytes written equals `before_cap − after_cap`.

### H3_DATAGRAM double-write property

When `h3_datagram = Some(v)`, **both** identifier 0x276 (`H3_DATAGRAM_00`) and
identifier 0x33 (`H3_DATAGRAM`) are emitted with the same value `v`. This
means the serialised payload contains two settings entries for what is
conceptually one field. This is intentional for backward compatibility but
creates a structural asymmetry with the parsed representation.

---

## Preconditions (parse_settings_frame)

- `settings_length` is the number of bytes available for the settings payload.
- `settings_length ≤ MAX_SETTINGS_PAYLOAD_SIZE = 256`.
- The byte slice contains valid varint-encoded identifier-value pairs that
  together consume exactly `settings_length` bytes.

## Postconditions (parse_settings_frame)

After a successful call, the returned `Frame::Settings` satisfies:

1. **Known fields populated**: for each recognised identifier in the payload,
   the corresponding `Option<u64>` field is `Some(value)` (with the last value
   winning if duplicated).
2. **Boolean constraint enforced**: if `connect_protocol_enabled = Some(v)`,
   then `v ≤ 1`. If `h3_datagram = Some(v)`, then `v ≤ 1`.
3. **Grease absent**: the parsed result always has `grease = None` — the
   `grease` field is only populated by the caller constructing a frame to send,
   not by the parser. Unknown identifiers go into `additional_settings` instead.
4. **Raw list populated**: `raw = Some(pairs)` where `pairs` is the full
   ordered sequence of `(identifier, value)` pairs encountered during parsing,
   including both duplicate H3_DATAGRAM entries and unknown identifiers.
5. **Size bound enforced**: if `settings_length > 256`, the call fails with
   `ExcessiveLoad`.
6. **Reserved identifiers rejected**: if a 0x0, 0x2, 0x3, 0x4, or 0x5
   identifier appears, the call fails with `SettingsError`.

---

## Invariants

### I1: Boolean invariant

For any `Frame::Settings` value returned by a successful `parse_settings_frame`:

```
connect_protocol_enabled = Some(v) → v ∈ {0, 1}
h3_datagram = Some(v) → v ∈ {0, 1}
```

### I2: Size guard invariant

```
settings_length > 256 → parse_settings_frame returns Err(ExcessiveLoad)
```

### I3: Reserved identifier rejection

```
∀ id ∈ {0, 0x2, 0x3, 0x4, 0x5}: identifier id appears in payload → parse returns Err(SettingsError)
```

### I4: Raw completeness

```
raw = Some(pairs) ∧ pairs contains exactly the (identifier, value) pairs read from the stream in order
```

### I5: H3_DATAGRAM double-entry (serialiser)

When `h3_datagram = Some(v)`, `to_bytes` emits both:
- `(0x276, v)` — the legacy draft-ietf-masque-h3-datagram-00 identifier
- `(0x33, v)` — the final RFC 9297 identifier

Both entries appear in the `raw` list of the subsequently parsed frame.

---

## Edge Cases

### Empty Settings frame

`settings_length = 0` is valid — all fields remain `None`, `raw = Some([])`.

### Settings with all known fields absent

A frame containing only unknown identifiers produces:
- All known `Option<u64>` fields = `None`
- `additional_settings = Some(list_of_pairs)`
- `raw = Some(same_pairs)`

### Maximum size

`settings_length = 256` is accepted. With all identifiers using 2-byte varints
(most real settings fit in 2 bytes) and 2-byte values, 256 bytes can store
roughly 64 settings — more than enough for real use cases.

### Duplicate identifiers

The parser processes pairs sequentially. If an identifier appears twice, the
later value silently overwrites the earlier one in the named field. The `raw`
list preserves both entries in order.

This means: given a payload with `(0x1, 10), (0x1, 20)`, the parsed result
has `qpack_max_table_capacity = Some(20)` and `raw = Some([(0x1,10),(0x1,20)])`.

### GREASE round-trip loss

`to_bytes` encodes a `grease: Some((id, val))` pair (for QUIC GREASE values).
`parse_settings_frame` has no special handling for GREASE — it routes unknown
identifiers into `additional_settings`. Therefore:

- A `Frame::Settings { grease: Some(g), .. }` serialised via `to_bytes` and
  then parsed via `from_bytes` produces a frame with `grease: None` and
  `additional_settings: Some([(g.0, g.1)])`.

This is a known structural asymmetry: the `grease` field is a _write-only_
annotation — it is not reconstructed by the parser.

---

## Formal Properties to Verify (for FVSquad/H3Settings.lean)

These are the propositions to state and attempt to prove in Lean:

1. **`settings_parse_boolean_inv`**: Any Settings frame parsed from valid bytes
   satisfies: `connect_protocol_enabled ∈ {None, Some 0, Some 1}` and
   `h3_datagram ∈ {None, Some 0, Some 1}`.

2. **`settings_parse_size_guard`**: `parse_settings_frame` with
   `settings_length > 256` returns `Err(ExcessiveLoad)`.

3. **`settings_reserved_rejected`**: A payload beginning with identifier
   `id ∈ {0, 2, 3, 4, 5}` causes `parse_settings_frame` to return
   `Err(SettingsError)`.

4. **`settings_roundtrip_simple`**: For a frame with only non-boolean fields
   (qpack_max_table_capacity, max_field_section_size, qpack_blocked_streams)
   and no grease or additional_settings:
   - `to_bytes` followed by `from_bytes` recovers the same option values for
     those three fields.

5. **`settings_h3datagram_double_emit`**: When `h3_datagram = Some(v)`,
   the serialised byte sequence contains both the 0x276 identifier and the
   0x33 identifier, each paired with value `v`.

6. **`settings_payload_length_bound`**: The length computed in `to_bytes` (the
   `len` variable) equals the sum `Σ (varint_len(id) + varint_len(val))` over
   all active settings — bounded above by `MAX_SETTINGS_PAYLOAD_SIZE = 256`.

7. **`settings_empty_parse`**: Parsing with `settings_length = 0` produces a
   `Frame::Settings` with all Option fields `None`, `grease = None`,
   `raw = Some []`, `additional_settings = None`.

8. **`settings_duplicate_last_wins`**: If the same known identifier appears
   twice in the payload, the later value is the one stored in the named field.

---

## Open Questions

- **OQ-T33-1**: Can `settings_length` be less than `b.off()` at the end of
  the while loop, e.g., if a varint extends beyond the declared length? The
  loop condition `b.off() < settings_length` would stop early, but the
  remaining bytes are silently ignored. Is this intentional?

- **OQ-T33-2**: The `to_bytes` implementation does not check that the computed
  `len` is ≤ 256 before writing. A frame constructed with many
  `additional_settings` entries could exceed `MAX_SETTINGS_PAYLOAD_SIZE`.
  Would such a frame be rejected by `parse_settings_frame` on the receiver?

- **OQ-T33-3**: `SETTINGS_H3_DATAGRAM_00` (0x276) and `SETTINGS_H3_DATAGRAM`
  (0x33) are both legacy/current identifiers for the same extension. The
  parser treats them interchangeably (last write wins). Is it specified whether
  the receiver should prefer one over the other? (RFC 9297 defines 0x33; the
  earlier draft used 0x276.)

- **OQ-T33-4**: The `raw` field is not serialised by `to_bytes` (it is
  ignored via `..` in the match arm). What is the intended use of `raw` in the
  outgoing direction? It appears to serve as an audit trail for received frames
  only.

---

## Examples

### Example 1: round-trippable Settings (no grease, no additional)

```
Frame::Settings {
  max_field_section_size: Some(16384),
  qpack_max_table_capacity: Some(0),
  qpack_blocked_streams: Some(0),
  connect_protocol_enabled: None,
  h3_datagram: None,
  grease: None,
  additional_settings: None,
  raw: None,
}
```

Wire bytes (type=0x04, then pairs): `04 <len> 06 <16384varint> 01 00 07 00`

Parsed back: same fields, with `raw = Some [(0x6, 16384), (0x1, 0), (0x7, 0)]`.

### Example 2: h3_datagram double-write

```
Frame::Settings { h3_datagram: Some(1), (rest None) }
```

Wire bytes include: `... 82 76 01 33 01 ...`
(0x276 encoded as 2-byte varint `82 76`, value 01; then 0x33, value 01)

Parsed: `h3_datagram = Some(1)`, `raw = Some [(0x276, 1), (0x33, 1)]`.

### Example 3: reserved identifier rejection

A payload with bytes encoding identifier=0x2 returns `Err(SettingsError)`.

### Example 4: boolean validation

Payload with `SETTINGS_ENABLE_CONNECT_PROTOCOL = 2` returns `Err(SettingsError)`.
