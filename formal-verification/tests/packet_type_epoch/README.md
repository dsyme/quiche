# T74 PacketTypeEpoch Route-B Correspondence Tests

🔬 *Lean Squad — Route-B correspondence validation for T74 (PacketTypeEpoch).*

## What is being tested

The Lean model `FVSquad.PacketTypeEpoch` in
`formal-verification/lean/FVSquad/PacketTypeEpoch.lean` formally verifies
properties of the QUIC packet-type / encryption-epoch mapping in
`quiche/src/packet.rs`:

- `Type::from_epoch(e: Epoch) -> Type`  (~L142)
- `Type::to_epoch(self) -> Result<Epoch>` (~L152)

The Lean model represents both functions as pure pattern-matches over
finite enumerations (`Epoch` has 3 variants, `Type` has 6 variants).
`Result<T>` is modelled as `Option T`. All 14 Lean theorems close by
`decide`.

Key properties tested:

| Lean theorem | What it checks |
|---|---|
| `from_epoch_to_epoch` | `to_epoch(from_epoch(e)) = Some(e)` for all 3 epochs |
| `to_epoch_from_epoch` | left-inverse on image of `from_epoch` |
| `short_and_zeroRTT_same_epoch` | `Short` and `ZeroRTT` both map to `Application` |
| `retry_no_epoch` / `versionNegotiation_no_epoch` | `None` for non-epoch-bearing types |
| `from_epoch_injective` | distinct epochs → distinct types |
| `range_of_fromEpoch` | image is exactly `{Initial, Handshake, Short}` |
| `to_epoch_exhaustive` | every type is either epoch-bearing or not |

## How to run

```bash
cd formal-verification/tests/packet_type_epoch
rustc --edition 2021 packet_type_epoch_test.rs && ./packet_type_epoch_test
```

No dependencies beyond a standard Rust toolchain.

## Test cases (42 total, all PASS)

| Group | Cases | What is tested |
|-------|-------|----------------|
| from_epoch: Rust ↔ Lean model | 3 | Each epoch: Rust impl matches Lean model |
| to_epoch: Rust ↔ Lean model | 6 | Each packet type: Rust impl matches Lean model |
| from_epoch_to_epoch round-trip | 3 | `to_epoch(from_epoch(e)) = Some(e)` for all epochs |
| to_epoch_from_epoch round-trip | 3 | Left-inverse on image of from_epoch |
| Short and ZeroRTT share epoch | 3 | Both map to Application; are equal |
| No-epoch types | 2 | Retry and VN return None |
| Injectivity | 9 | All 3×3 pairs: equal iff same epoch |
| Exact values | 7 | Direct value checks for all meaningful inputs |
| Exhaustive classification | 6 | 4 epoch-bearing + 2 non-epoch-bearing |

## Correspondence status

| Lean definition | Rust function | File | Correspondence |
|---|---|---|---|
| `fromEpoch` | `Type::from_epoch` | `quiche/src/packet.rs:142` | Exact |
| `toEpoch` | `Type::to_epoch` | `quiche/src/packet.rs:152` | Exact (`Result` ↔ `Option`) |

## Lean file

`formal-verification/lean/FVSquad/PacketTypeEpoch.lean` — T74, 14 theorems, 0 sorry.
