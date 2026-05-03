# Route-B Correspondence Tests: H3Settings (T33)

🔬 *Lean Squad — automated formal verification for `dsyme/quiche`.*

## Target

**T33 — H3 Settings Frame Invariants**

- **Lean model**: `formal-verification/lean/FVSquad/H3Settings.lean`
- **Rust source**: `quiche/src/h3/frame.rs` — `parse_settings_frame`
- **RFC**: RFC 9114 §7.2.4

## What Is Tested

The Lean model defines:

- `isReserved : UInt64 → Bool` — identifiers inherited from HTTP/2 that MUST be rejected
- `requiresBool : UInt64 → Bool` — identifiers constrained to values 0 or 1
- `applyEntry : Settings → id → v → Option Settings` — per-entry dispatch
- `parse : List (id × v) → ParseResult` — full settings-list parser

The test re-implements both sides (Lean model logic and Rust spec) in a
standalone Rust file and verifies they agree on all test cases.

## Test Cases (43 total)

| Category | Cases |
|----------|-------|
| Empty payload | 1 |
| Single known fields (all 6 standard ids, valid values) | 12 |
| Boolean-violation errors (`connect_protocol`, `h3_datagram_00`, `h3_datagram` with `v > 1`) | 7 |
| Reserved identifier errors (all 5 reserved ids) | 5 |
| Error propagation (reserved/bool-violation mid-list) | 4 |
| Unknown identifiers → `additional_settings` | 3 |
| Multi-field combinations | 6 |
| Duplicate keys (last-value-wins) | 2 |
| Edge values (`u64::MAX`) | 3 |

Plus inline assertion checks for all named Lean theorems:
- `isReserved_0/2/3/4/5_true`, `isReserved_1/6/8_false`
- `requiresBool_connect/datagram_00/datagram` etc.
- `parse_empty`, `parse_reserved_id_err`, `parse_connect_gt1_err`, `parse_datagram_gt1_err`, `parse_single_qpack_ok`

## How to Run

```bash
rustc formal-verification/tests/h3_settings/h3_settings_test.rs -o /tmp/h3s_test
/tmp/h3s_test
```

Expected output:

```
H3Settings Route-B: 43/43 PASS
```

## Result

**43/43 PASS** (run 125, 2026-05-03, commit `a3b334325b32843f4a97fc996be3f31dbc82a660` merged with run-124 branch)

## What Is Not Covered

- Byte-level varint encoding/decoding (out of scope; tested in VarIntRoundtrip Route-B)
- `MAX_SETTINGS_PAYLOAD_SIZE` byte-count check (not modelled in Lean)
- GREASE identifiers (treated as unknown; fall into `additional_settings`)
- `raw` field (not modelled in Lean)

The correspondence between the Lean model and the Rust source is documented in
`formal-verification/CORRESPONDENCE.md` under **T33 H3Settings**.
