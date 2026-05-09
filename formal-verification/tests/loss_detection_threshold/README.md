# Route-B Test: T56 — Loss Detection Packet Threshold

🔬 Lean Squad correspondence test for `FVSquad/LossDetectionThreshold.lean`.

## What is tested

The Lean model defines `clampToMax` and `updatePktThresh` that implement the
packet-threshold update rule from RFC 9002 §6.1.1 as formalised in
`FVSquad/LossDetectionThreshold.lean`.

This test verifies that the Lean functional model produces identical results to
the Rust implementation in `quiche/src/recovery/congestion/recovery.rs` L657–658:

```rust
// Rust (recovery.rs L657-658):
self.pkt_thresh = self.pkt_thresh.max(thresh.min(MAX_PACKET_THRESHOLD));

// Lean model (LossDetectionThreshold.lean):
def clampToMax (s : Nat) :=
  if s ≤ MAX_PACKET_THRESHOLD then s else MAX_PACKET_THRESHOLD

def updatePktThresh (current spurious : Nat) : Nat :=
  let c := clampToMax spurious
  if current ≤ c then c else current
```

These are semantically identical:
`max(current, min(spurious, MAX)) = max(current, clampToMax(spurious))`

## Constants verified

| Constant | Value | Source |
|----------|-------|--------|
| `INITIAL_PACKET_THRESHOLD` | 3 | `quiche/src/recovery/mod.rs` L51 |
| `MAX_PACKET_THRESHOLD` | 20 | `quiche/src/recovery/mod.rs` L53 |

## Test cases

- **Named cases** (31): explicit input/output pairs including:
  - Lean file `#eval` spot-checks (5 cases)
  - Constant boundary cases (initial, max, zero)
  - Invariant preservation cases
  - Edge cases: spurious=0, current=MAX, over-MAX inputs
- **Exhaustive sweep** (961): all `(current, spurious)` in `[0..30] × [0..30]`
- **Total**: 991 test cases

## How to run

```bash
cd formal-verification/tests/loss_detection_threshold
rustc --edition 2021 loss_detection_threshold_test.rs -o loss_detection_threshold_test
./loss_detection_threshold_test
```

Expected output: `PASS 991/991 test cases`

## Last run result

**PASS 991/991** — run 144 (2026-05-09)

## Coverage notes

- ✅ Models the exact clamping arithmetic (`clampToMax = min(spurious, MAX)`)
- ✅ Models the threshold update rule (`max(current, clamped)`)
- ✅ Exhaustively covers all pairs in `[0..30] × [0..30]`
- ⚠️ Does **not** test the full loss detection algorithm (packet enumeration,
  time thresholds, etc.) — only the threshold arithmetic modelled in Lean
- ⚠️ `time_thresh` (floating-point multiplier) is not modelled in Lean or tested here
