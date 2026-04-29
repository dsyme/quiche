# Informal Specification: `parse_settings_frame` RFC Compliance (T35)

🔬 *Lean Squad — automated formal verification for `dsyme/quiche`.*

**Target**: `quiche/src/h3/frame.rs` — `fn parse_settings_frame`
**Status**: Phase 2 — Informal Spec (run 115)
**Formal spec target**: `formal-verification/lean/FVSquad/H3ParseSettings.lean`

---

## Purpose

`parse_settings_frame` decodes an HTTP/3 SETTINGS frame payload from an
`octets::Octets` cursor.  It iterates over (identifier, value) varint pairs
and fills in known fields, rejecting HTTP/2-reserved identifiers and
out-of-range boolean values.

The function is security-relevant: it is the first HTTP/3 function called on
incoming SETTINGS data.  Incorrect acceptance of reserved identifiers would
violate RFC 9114 §7.2.4, potentially enabling cross-protocol downgrade
attacks.

---

## Preconditions

1. `b` is a valid `octets::Octets` pointing at the start of the SETTINGS
   payload.
2. `settings_length` is the byte length of the payload as declared in the
   frame header.
3. `settings_length ≤ MAX_SETTINGS_PAYLOAD_SIZE (= 256)`.
   If this bound is exceeded, the function MUST return `Error::ExcessiveLoad`
   before reading any bytes.

---

## Postconditions

On success (`Ok(Frame::Settings { ... })`):

1. **Reserved-ID rejection**: none of the identifiers `0x0, 0x2, 0x3, 0x4, 0x5`
   appears in the parsed settings (RFC 9114 §7.2.4 §A.2).  If any such
   identifier is present in the wire data, the function returns
   `Err(Error::SettingsError)` instead.

2. **Boolean field validation**: for `SETTINGS_ENABLE_CONNECT_PROTOCOL (0x8)`
   and `SETTINGS_H3_DATAGRAM (0x33 / 0x276)`, the value must be 0 or 1.
   A value > 1 causes `Err(Error::SettingsError)`.

3. **Known-field extraction**: the five known fields are stored in the
   corresponding `Option<u64>` slots:
   - `max_field_section_size` ← identifier 0x6
   - `qpack_max_table_capacity` ← identifier 0x1
   - `qpack_blocked_streams` ← identifier 0x7
   - `connect_protocol_enabled` ← identifier 0x8 (value ∈ {0, 1})
   - `h3_datagram` ← identifier 0x276 or 0x33 (value ∈ {0, 1})
   Each field is set to the last parsed value if the identifier appears
   multiple times (last-value-wins semantics).

4. **Unknown-identifier passthrough**: identifiers not in the known set and
   not in the reserved set are collected into `additional_settings`.

5. **Raw accumulation**: every (identifier, value) pair encountered is
   appended to the `raw` vector regardless of whether the identifier is known.

6. **Size guard**: the function never reads past byte offset `settings_length`
   in `b`.

---

## Invariants

- **Termination**: the cursor advances by at least `2` bytes per iteration
  (two varints ≥ 1 byte each), so the loop terminates within
  `settings_length / 2` iterations.
- **MAX_SETTINGS_PAYLOAD_SIZE** (256 bytes) bounds the raw accumulator size:
  at most 128 entries of the minimum size (2 bytes each).

---

## Edge Cases

1. **Empty payload** (`settings_length = 0`): the loop body is never entered;
   all fields are `None`; `raw` is empty; result is `Ok(Frame::Settings { all None })`.
2. **`settings_length` = MAX_SETTINGS_PAYLOAD_SIZE**: boundary — allowed.
3. **`settings_length` = MAX_SETTINGS_PAYLOAD_SIZE + 1**: immediate
   `Err(Error::ExcessiveLoad)` before reading.
4. **Reserved identifier at first position**: immediate error; no valid fields
   extracted.
5. **Duplicate known identifier**: last value wins for each known field;
   the `raw` vector records all occurrences.
6. **Both `SETTINGS_H3_DATAGRAM_00 (0x276)` and `SETTINGS_H3_DATAGRAM (0x33)`
   present**: both branches write to `h3_datagram`; final value is whichever
   appears last (implementation detail, not specified by RFC).
7. **Cursor truncated** (fewer bytes than expected): `get_varint` returns
   `Err(BufferTooShort)` which propagates out of `parse_settings_frame`.

---

## Examples

| Wire data (hex varints) | Expected result |
|-------------------------|-----------------|
| `[]` (empty) | `Ok(Settings { all None })` |
| `[0x01, 0x00]` (`QPACK_MAX_TABLE_CAPACITY=0`) | `Ok(Settings { qpack_max_table_capacity: Some(0), ... })` |
| `[0x08, 0x00]` (`ENABLE_CONNECT=0`) | `Ok(Settings { connect_protocol_enabled: Some(0) })` |
| `[0x08, 0x02]` (`ENABLE_CONNECT=2`) | `Err(SettingsError)` — value > 1 |
| `[0x02, 0x00]` (reserved 0x2) | `Err(SettingsError)` — reserved id |
| `[0x00, 0x00]` (reserved 0x0) | `Err(SettingsError)` — reserved id |
| 129 × `[0x0A, 0x01]` (≥ 258 bytes) | `Err(ExcessiveLoad)` — payload too large |

---

## Inferred Intent

The purpose of the reserved-identifier check is to prevent HTTP/3 endpoints
from silently accepting settings that carry HTTP/2 semantics and could be
misinterpreted by protocol-aware intermediaries.  The boolean validation for
`connect_protocol_enabled` and `h3_datagram` is a value-range guard; RFC 9114
specifies these as single-bit flags (0 or 1).

---

## Open Questions

- **OQ-T35-1**: What happens if the same identifier appears more than twice?
  The code uses last-value-wins for known fields, but there is no explicit
  deduplication in `raw`.  Is this the intended semantics?

- **OQ-T35-2**: `SETTINGS_H3_DATAGRAM_00 (0x276)` is a legacy draft identifier.
  When both 0x276 and 0x33 are present, should the first or last value win?
  RFC 9297 does not specify the interaction.  Is the current last-value-wins
  behaviour correct?

- **OQ-T35-3**: The `raw` field is `Vec<(u64, u64)>` but is not returned in the
  `Frame::Settings` variant when serialised (`to_bytes`).  Could a
  settings-round-trip lose information stored in `raw`?  Is this intentional?

- **OQ-T35-4**: `MAX_SETTINGS_PAYLOAD_SIZE = 256` is a hard constant.  What is
  the RFC basis for this limit?  RFC 9114 does not specify a maximum SETTINGS
  frame size.  Is this a DoS protection heuristic?

---

## Relationship to T33 (H3Settings invariants)

T33 (`FVSquad/H3Settings.lean`) models the parsed `Frame::Settings` variant
and proves invariants on the *output* (e.g., `connect_protocol_enabled` ≤ 1).
T35 focuses on the *parsing function* itself — the control-flow correctness
of the byte-by-byte loop, the size guard, and the RFC 9114 §7.2.4 reserved-ID
rejection.

The Lean model for T35 should import T33's definitions and prove that every
successfully parsed frame satisfies the T33 invariants — forming a
pre/postcondition pair:

```
parse_settings_frame(bytes) = Ok(s) → H3SettingsInvariant(s)
```
