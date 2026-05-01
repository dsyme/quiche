# Informal Specification: QPACK Static Table Lookup

**Source**: `quiche/src/h3/qpack/static_table.rs`  
**RFC**: RFC 9204 Appendix A (QPACK Static Table)

---

## Purpose

QPACK (RFC 9204) uses a predefined static table of 99 HTTP header
(name, value) pairs to compress headers by encoding common headers as
small integers rather than verbatim strings. The static table is
permanently indexed 0–98 and is identical on both sides of a connection,
requiring no negotiation.

The quiche implementation provides two constant data structures:

1. `STATIC_DECODE_TABLE` — a 99-element array indexed by static index,
   mapping each index to its `(name, value)` byte string pair.
2. `STATIC_ENCODE_TABLE` — a lookup structure indexed by name length, then
   name, then value, producing the corresponding static index.

---

## Preconditions

- Both tables are static constants compiled into the binary; they do not
  change at runtime.
- All indices are 0-based and in the range `[0, 98]`.
- All names and values are ASCII byte strings.

---

## Postconditions / Invariants

1. **Size**: `STATIC_DECODE_TABLE` has exactly 99 entries (indices 0–98).
2. **Valid encode indices**: every index stored in `STATIC_ENCODE_TABLE`
   satisfies `index < 99`.
3. **Encode/decode consistency**: for every `(name, value, index)` triple
   in `STATIC_ENCODE_TABLE`, `STATIC_DECODE_TABLE[index]` equals
   `(name, value)`. (A name/value pair encodes to the index from which it
   decodes back to the same pair.)
4. **Encode index uniqueness**: each index appears at most once across all
   entries of `STATIC_ENCODE_TABLE` (the encode mapping is injective on
   `(name, value)` pairs).
5. **Non-empty names**: every entry has a non-empty name byte string.
6. **ASCII-only**: all name and value bytes are in the range `[0, 127]`.
7. **Decode uniqueness**: no two entries in `STATIC_DECODE_TABLE` have the
   same `(name, value)` pair (all 99 entries are distinct).

---

## Edge Cases

- Several names appear multiple times with different values (e.g., `:method`
  appears 7 times with different HTTP method names). Uniqueness is per
  `(name, value)` pair, not per name alone.
- The encode table is organised by *name length* for fast O(1) lookup via
  array indexing followed by sequential scan over names of the same length.
- Index 0 maps to `(:authority, "")`. Indices are 0-based in the Rust
  implementation (matching the 0-based array indexing), but RFC 9204 uses
  1-based indexing in its specification.

---

## Examples

- `STATIC_DECODE_TABLE[0]` → `(":authority", "")`
- `STATIC_DECODE_TABLE[17]` → `(":method", "GET")`
- `STATIC_DECODE_TABLE[25]` → `(":status", "200")`
- `STATIC_DECODE_TABLE[98]` → `("x-frame-options", "sameorigin")`
- Encoding `(":method", "GET")` → index `17`
- Encoding `(":status", "200")` → index `25`

---

## Inferred Intent

The static table is a performance optimisation: by agreeing on 99 common
header name/value pairs, QPACK can encode a full HTTP header in 1–2 bytes
instead of the full ASCII string. The correctness property is that every
encode/decode round trip is the identity: `decode(encode(n, v)) = (n, v)`.
The dual property — `encode(decode(i)) = i` — holds only for entries that
appear in the encode table (not all decode entries necessarily have an encode
entry, though in practice they do).

---

## Open Questions

- OQ-T34-1: Are there decode-table entries with no corresponding encode-table
  entry? The spec should clarify whether `encode ∘ decode = id` holds for all
  99 entries or only for the subset in `STATIC_ENCODE_TABLE`.
- OQ-T34-2: The `:path` entry at index 1 (`/`) is in the encode table under
  length 5 (`:path`). Is there also a `/index.html` → `1` encode entry? The
  Rust source suggests no — only `"/"` maps to index 1.
