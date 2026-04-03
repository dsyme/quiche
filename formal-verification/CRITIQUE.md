# Formal Verification Proof Utility Critique

> 🔬 *Written by Lean Squad automated formal verification.*

## Last Updated

- **Date**: 2026-04-03 16:08 UTC
- **Commit**: `ce100e6`

---

## Overall Assessment

The formal verification suite for `quiche` now covers **six modules with 99
theorems and 0 sorry** (Lean 4.29.0, no Mathlib).  The suite provides
machine-checked confidence in the QUIC varint codec, the RangeSet interval
data structure, the Minmax running-minimum filter, the RTT estimator, the
flow-control window manager, and the NewReno congestion controller.  The most
valuable results are the `varint_round_trip` property (encode/decode identity),
the `RangeSet.insert_preserves_invariant` structural invariant, the
`adjusted_rtt_ge_min_rtt` theorem that prevents an ack-delay-based timing
attack, and the NewReno `cwnd_floor_new_event` property that guarantees the
minimum congestion window floor after any loss event.  The main limitation
across all files is that Lean models use unbounded `Nat` instead of bounded
Rust integers, so overflow/underflow edge cases are not verified.

---

## Proved Theorems

### `FVSquad/Varint.lean` — 10 theorems

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `varint_round_trip` | high | **high** | Core codec correctness; a bug here breaks all QUIC framing |
| `varint_encode_length` | mid | medium | Encodes in expected number of bytes |
| `varint_len_correct` | mid | medium | Length function consistent with encoding |
| `varint_parse_len_one` | low | low | Trivial dispatch case |
| `varint_parse_len_two` | low | low | Trivial dispatch case |
| `varint_parse_len_four` | low | low | Trivial dispatch case |
| `varint_parse_len_eight` | low | low | Trivial dispatch case |
| `varint_encode_none_iff` | mid | medium | Out-of-range inputs rejected |
| `varint_decode_none_iff` | mid | medium | Too-short buffers rejected |
| `varint_encode_produces_valid` | mid | medium | All encoded values are in-range |

**Assessment**: The round-trip theorem is high-value.  The dispatch lemmas are
low-value individually but collectively guard the length-tagging logic.  **Gap**:
no theorem verifies that the 2-bit tag in the first byte is correctly set; a bug
there would corrupt the wire format without failing `round_trip`.

---

### `FVSquad/RangeSet.lean` — 14 theorems

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `insert_preserves_invariant` | high | **high** | Sorted + disjoint + merged invariant |
| `insert_mem` | high | **high** | Inserted range is in the result |
| `insert_superset` | mid | medium | Existing ranges survive insertion |
| `sorted_cons` | low | low | Helper for invariant reasoning |
| `ranges_sorted` | mid | medium | Structural invariant on the list |
| `ranges_nonempty` | mid | medium | No empty intervals stored |
| `range_insert_monotone` | mid | medium | Insert only grows the set |
| `empty_inv` | low | low | Constructor postcondition |
| `insert_go_result_sorted` | mid | medium | Internal helper well-behaved |
| `contains_after_insert` | high | **high** | Membership correct after insert |
| `invariant_after_multiple_inserts` | high | **high** | Stability under repeated ops |
| `merge_preserves_lower` | mid | medium | Merge doesn't lose the lower bound |
| `no_empty_range` | low | low | Helper lemma |
| `sorted_tail_preserved` | low | low | Structural helper |

**Assessment**: The invariant and membership theorems are high-value for a data
structure that directly affects QUIC packet deduplication (ACK tracking).  A bug
in RangeSet could silently cause duplicate-packet acceptance or lost-range
misreporting.  **Gap**: no theorem verifies that `flatten(insert(rs, r))` contains
exactly the union of the points in `rs` and `r` — the current suite verifies
structural properties but not full semantic equivalence to a set union.

---

### `FVSquad/Minmax.lean` — 15 theorems (plus 4 examples)

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `minmax_running_min` | high | **high** | Core running-min correctness |
| `minmax_init_correct` | low | low | Constructor postcondition |
| `minmax_monotone` | mid | medium | Running min is non-increasing |
| `minmax_samples_valid` | mid | medium | Stored samples satisfy ordering |
| `minmax_update_ge_min` | mid | medium | New min ≤ all samples |
| `minmax_window_correct` | mid | medium | Window eviction logic |
| `minmax_three_sample_invariant` | high | **high** | Three-sample data structure invariant |
| + 8 further structural/helper theorems | low–mid | low–medium | |

**Assessment**: The running-min property and three-sample invariant are
important: MinMax is used for the RTT minimum filter that gates ack-delay
adjustment.  A bug could allow spurious RTT under-estimation.  **Gap**: the
Lean model replaces the sliding time-window with a simple structural model;
time-based eviction is not verified.

---

### `FVSquad/RttStats.lean` — 24 theorems

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `adjusted_rtt_ge_min_rtt` | **high** | **high** | Security property: prevents ack-delay attack |
| `rtt_update_smoothed_le_max_prev_adj` | high | high | EWMA contraction — no unbounded growth |
| `rtt_update_rttvar_upper_bound` | high | medium | Variance bounded by max of inputs |
| `rtt_init_invariant` | mid | medium | Initial state satisfies invariants |
| `rtt_update_first_sample` | mid | medium | First RTT sets smoothed = sample |
| `adjusted_rtt_le_latest` | mid | medium | Adjustment never exceeds raw sample |
| `smoothed_rtt_nonneg` | low | low | Trivial non-negativity |
| + 17 further structural/arithmetic theorems | low–mid | low–medium | |

**Assessment**: `adjusted_rtt_ge_min_rtt` is the highest-value result in the
entire suite — it directly closes a class of timing attacks described in RFC 9002
§5.3.  The EWMA contraction theorem (`smoothed ≤ max(prev_smoothed, adj_rtt)`)
verifies that the low-pass filter cannot diverge.  **Gap**: no theorem proves
*lower* bounds on `smoothed_rtt` (it could decay toward 0 faster than the true
network RTT); and the `rttvar` EWMA is only bounded above, not below.

---

### `FVSquad/FlowControl.lean` — 22 theorems

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `fc_no_update_needed_after_update` | high | **high** | Update idempotence (no redundant MAX_DATA frames) |
| `fc_max_data_next_gt_when_should_update` | high | **high** | Limit strictly grows when updating |
| `fc_update_idempotent` | high | **high** | Double-update is a no-op |
| `fc_new_inv` | mid | medium | Constructor establishes invariant |
| `fc_update_preserves_inv` | mid | medium | Update preserves window ≤ max_window |
| `fc_autotune_preserves_inv` | mid | medium | Autotune preserves invariant |
| `fc_ensure_lb_ge` | mid | medium | Lower-bound raise achieves stated goal |
| `fc_max_data_next_ge_consumed` | mid | medium | Proposed limit ≥ consumed |
| `fc_consumed_monotone` | mid | medium | Consumed bytes never decrease |
| `fc_autotune_window_when_tuned` | mid | medium | Correct doubling when tuned |
| + 12 further structural/helper theorems | low–mid | low–medium | |

**Assessment**: The flow-control invariants cover the arithmetic safety properties
well.  `fc_no_update_needed_after_update` is important: if it failed, a receiver
might flood the peer with redundant MAX_DATA frames.  `fc_max_data_next_gt_when_should_update`
confirms the non-decreasing guarantee for MAX_DATA (a violated guarantee would be
a QUIC protocol error).  **Gap**: the autotune timing model uses an abstract
boolean `should_tune`, so the interaction between RTT measurement and window
doubling is not verified.  Also, the overflow risk (`consumed + window` wrapping
u64) is not captured.

---

## Gaps and Recommendations

Prioritised by impact:

1. **Semantic set-union for RangeSet** (high): prove that after inserting range
   `[a,b)`, the points covered by the result equal the old set ∪ `{a..b-1}`.
   This would catch bugs that merge ranges incorrectly.

2. **RTT lower-bound / decay rate** (medium): add theorems showing `smoothed_rtt`
   cannot fall *below* some fraction of `min_rtt`.  This would catch an
   under-smoothing bug that could make the congestion controller too aggressive.

3. **Flow control u64 overflow guard** (medium): add a bounded model (e.g.,
   restrict `consumed + window < 2^62`) and prove no overflow occurs under the
   varint limit.  This closes the one known gap between the Lean model and the
   Rust u64 arithmetic.

4. **Congestion window** (high): `quiche/src/recovery/congestion/` contains
   the CUBIC and New Reno implementations.  Key properties: window only grows
   after ACK; window halves on loss; window ≥ minimum congestion window.  This
   is an important new target.

5. **Stream-level flow control** (medium): `quiche/src/stream/` uses similar
   window arithmetic to `flowcontrol.rs` but with per-stream state.  The
   connection-level `FlowControl` proofs could be extended or reused.

6. **Varint wire-format tag bits** (medium): add a theorem verifying that the
   2-bit tag in the first byte of an encoded varint matches the length class.
   Current proofs do not cover this aspect.

---

## Concerns

- **Nat vs u64**: all five files model Rust `u64` values as Lean `Nat` (unbounded).
  Overflow is the primary unverified risk; see CORRESPONDENCE.md for per-file
  documentation.  The varint file partially mitigates this by bounding inputs to
  `MAX_VAR_INT = 2^62 − 1`.

- **Autotune timing abstraction**: `FlowControl.autotune_window` and the RTT
  minmax filter both rely on `Instant` comparisons that are abstracted away.
  Proofs about the timing-triggered behaviour (window doubling rate, RTT window
  eviction) are therefore not verified.

- **Mutation vs. pure model**: all Lean files replace mutable Rust state with
  pure functional updates.  Aliasing bugs (e.g., two handles to the same
  `FlowControl`) cannot be captured.  In practice quiche's single-threaded
  connection model makes this safe, but it is an acknowledged gap.

---

## Positive Findings

- **`adjusted_rtt_ge_min_rtt`** (RttStats.lean): the proof required non-trivial
  case analysis on the ack-delay condition.  The theorem directly encodes the
  security rationale from RFC 9002 §5.3, and the proof was not trivial —
  demonstrating that the Lean suite is exercising real proof obligations, not
  just stating tautologies.

- **`fc_max_data_next_gt_when_should_update`** (FlowControl.lean): the `omega`
  tactic closed this automatically after unfolding, confirming the arithmetic
  inequality is tight and non-trivial.

- **`insert_preserves_invariant`** (RangeSet.lean): the inductive proof of
  sorted+disjoint+merged under insertion required substantial case splitting and
  was the most complex proof in the suite.  Its success gives high confidence in
  the ACK-range deduplication logic.

---

### `FVSquad/NewReno.lean` — 13 theorems (added run 34)

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `cwnd_floor_new_event` | high | **high** | cwnd ≥ mss\*2 after any fresh congestion event — directly captures the RFC 6582 minimum-window floor |
| `single_halving` | high | **high** | In-recovery congestion_event is a no-op; prevents compounding halvings for multiple losses in one epoch |
| `congestion_event_sets_recovery` | mid | medium | `in_recovery` flag is set correctly; guards subsequent events |
| `congestion_event_idempotent` | mid | medium | Two consecutive loss events = one; structural safety |
| `slow_start_growth` | mid | medium | Slow start increases cwnd by exactly mss per ACK (not guarded) |
| `ca_ack_no_growth` | mid | medium | CA counter below threshold — window unchanged |
| `ca_ack_growth` | mid | medium | CA counter at threshold — window grows by exactly mss |
| `recovery_no_growth` | low | medium | In-recovery ACK has no effect on cwnd |
| `app_limited_no_growth` | low | low | App-limited ACK has no effect on cwnd |
| `acked_cwnd_monotone` | mid | **high** | on_packet_acked never decreases cwnd — monotone growth invariant |
| `acked_preserves_floor_inv` | mid | **high** | FloorInv is an inductive invariant under ACKs |
| `congestion_event_cwnd_le_of_floor` | mid | medium | Under FloorInv, congestion_event cannot raise cwnd |
| `congestion_event_establishes_floor` | mid | **high** | Any fresh congestion event establishes FloorInv from scratch |

**Assessment**: The floor invariant (`cwnd ≥ mss * 2`) is the most valuable
property — it prevents the connection from stalling at sub-MSS window sizes and
is directly required by RFC 6582.  `single_halving` and `acked_cwnd_monotone`
together guarantee the two core AIMD safety properties: the window never grows
on losses and never shrinks on ACKs.  **Gaps**: (1) no theorem verifies the
exact AIMD growth rate (one MSS per cwnd bytes ACKed) across multiple ACK
callbacks; (2) HyStart++ (CSS branch) is fully abstracted away; (3) the
`f64 * 0.5` cast is modelled as Nat `/2` — the floor-vs-round question from the
informal spec remains unaddressed.
