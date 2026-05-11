# Route-B Correspondence Tests — IdleTimeout

🔬 *Lean Squad — automated formal verification for `dsyme/quiche`.*

## Target

**IdleTimeout: QUIC max_idle_timeout negotiation**

- Source: `quiche/src/lib.rs`, `fn idle_timeout` (lines 8757–8788)
- Lean model: `formal-verification/lean/FVSquad/IdleTimeout.lean`, `def idleTimeout`

## What is tested

The Rust `idle_timeout()` method negotiates the effective idle-timeout duration
from two transport parameters (`loc` = local `max_idle_timeout`, `peer` = peer's
`max_idle_timeout`, both in milliseconds; 0 means "disabled") and the current
PTO estimate.  The pure logic is:

```
if loc == 0 && peer == 0: return None            # both disabled
base := if loc == 0 { peer }
        else if peer == 0 { loc }
        else { min(loc, peer) }
return Some(max(base, 3 * pto))                  # PTO safety clamp
```

The Lean model `idleTimeout (loc peer pto : Nat)` mirrors this exactly.

The test harness (`idle_timeout_test.rs`) contains a standalone Rust extraction
of the pure function and verifies agreement across 38 cases covering:

| Property tested | Cases |
|-----------------|-------|
| Both-zero → None | 3 |
| loc=0, peer nonzero (no/partial/full PTO clamp) | 6 |
| peer=0, loc nonzero (no/partial/full PTO clamp) | 5 |
| Both nonzero, no PTO clamping | 4 |
| Both nonzero, PTO clamp active | 4 |
| Commutativity (loc↔peer swap) | 4 |
| Lean model agrees with Rust extraction | 12 |

## How to run

```bash
cd formal-verification/tests/idle_timeout
rustc --edition 2021 idle_timeout_test.rs && ./idle_timeout_test
```

Expected output: `38/38 tests passed`

## Result

**38/38 PASS** (run 148, 2026-05-10)

## Coverage notes

- Both `u64` (Rust) and `Nat` (Lean) overflow at 0 for unsigned subtraction,
  so the models agree for all practical `max_idle_timeout` values (≤ 2^64-1).
- The harness does not test Duration arithmetic (Rust wraps `u64` ms in
  `Duration::from_millis`); that is outside the scope of the pure model.
- PTO values are expressed in milliseconds; the harness uses integer ms to
  stay in the `Nat` domain of the Lean model.
