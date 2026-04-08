# Formal Verification Proof Utility Critique

> 🔬 *Written by Lean Squad automated formal verification.*

## Last Updated

- **Date**: 2026-04-07 17:45 UTC
- **Commit**: `ade740b8`

---

## Overall Assessment

The formal verification suite for `quiche` now covers **fifteen modules with
333 theorems + 19 examples, 0 sorry** (Lean 4.29.0, no Mathlib). Run 49 adds
`StreamPriorityKey.lean` (22 theorems + 7 examples): the ordering comparator
used in HTTP/3 stream scheduling (RFC 9218). The most notable result is a
**formal proof of an Ord law violation (OQ-1)**: the both-incremental case of
`StreamPriorityKey::cmp` returns `Ordering::Greater` for **both** `a.cmp(b)`
and `b.cmp(a)` simultaneously, violating the standard antisymmetry contract.
This is not necessarily a bug — the intrusive red-black tree may tolerate
non-antisymmetric comparators — but it is a formally confirmed deviation from
the Rust `Ord` contract. The prior fourteen modules continue to hold with zero
outstanding `sorry`s. Key previous results include `emitN_le_maxData`
(SendBuf, flow-control safety), `decode_pktnum_correct` (PacketNumDecode, RFC
9000 §A.3 algorithm), and `newScid_seq_fresh` (CidMgmt, CID uniqueness).

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

### `FVSquad/RangeSet.lean` — 16 theorems

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `insert_preserves_invariant` | high | **high** | `sorted_disjoint` maintained by `range_insert` — core structural guarantee |
| `insert_covers_union` | high | **high** | Semantic completeness: inserted range is covered by result (within no-eviction bound) |
| `remove_until_removes_small` | high | **high** | No value ≤ largest survives `range_remove_until` — direct ACK dedup safety property |
| `remove_until_preserves_large` | high | **high** | Covered values above threshold are retained — liveness guarantee |
| `remove_until_preserves_invariant` | mid | **high** | `sorted_disjoint` maintained by `range_remove_until` |
| `singleton_covers_iff` | mid | medium | Membership spec for single-element sets |
| `insert_empty` | mid | medium | Single-range insertion result is structurally correct |
| `insert_empty_covers` | mid | medium | Fresh insertion with correct coverage |
| `sorted_disjoint_tail` | low | low | Structural helper: invariant preserved on tail |
| `sorted_disjoint_head_valid` | low | low | Structural helper: first element satisfies `valid_range` |
| `empty_sorted_disjoint` | low | low | Constructor postcondition |
| `singleton_sorted_disjoint` | low | low | Single-element invariant |
| `empty_covers_nothing` | low | low | Empty set membership is always false |
| `remove_until_empty` | low | low | `range_remove_until` on empty is identity |
| `singleton_not_covers_left` | low | low | Membership excludes values strictly before range start |
| `singleton_not_covers_right` | low | low | Membership excludes values at or after range end |

**Assessment**: The invariant and semantic-union theorems are high-value for a
data structure that directly affects QUIC packet deduplication (ACK tracking).
`remove_until_removes_small` is a direct safety property: if it were false, a
received packet could be falsely acknowledged again.  **Gap**: the model omits
capacity eviction — proved theorems apply only when the set is below capacity.
A future theorem bounding behaviour under eviction would close this gap.

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
| `adjusted_rtt_ge_min_rtt` | **high** | **high** | Security property: prevents ack-delay timing attack (RFC 9002 §5.3) |
| `rtt_update_smoothed_upper_bound` | high | high | EWMA contraction — smoothed RTT ≤ adjusted_rtt when updated |
| `rtt_first_update_smoothed_eq` | mid | medium | First RTT sample sets smoothed = sample exactly |
| `rtt_first_update_min_rtt_eq` | mid | medium | First sample sets min_rtt correctly |
| `adjusted_rtt_le_latest` | mid | medium | Adjustment never exceeds raw sample |
| `rtt_update_min_rtt_le_latest` | mid | medium | min_rtt ≤ latest RTT |
| `rtt_update_min_rtt_le_prev` | mid | medium | min_rtt is non-increasing |
| `rtt_update_max_rtt_ge_latest` | mid | medium | max_rtt tracks maximum correctly |
| `rtt_update_smoothed_pos` | mid | low | Smoothed RTT remains positive |
| `rtt_update_min_rtt_inv` | mid | medium | min_rtt invariant preserved by update |
| + 13 further structural/helper theorems | low–mid | low–medium | Constructor postconditions, helper lemmas |

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

### `FVSquad/StreamPriorityKey.lean` — 22 theorems + 7 examples ✅ (added run 49)

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `cmpKey_incr_incr_not_antisymmetric` | high | **high** | **Finding**: proves OQ-1 — both-incremental case returns `.gt` in *both* directions; Ord antisymmetry violated |
| `cmpKey_trans_urgency` | high | **high** | Transitivity across urgency levels: correctly propagates priority ordering |
| `cmpKey_trans_nonincr` | high | high | Transitivity for non-incremental streams at same urgency (id order is transitive) |
| `cmpKey_nonincr_antisymm` | high | high | Non-incremental case satisfies antisymmetry: `a.id < b.id ↔ cmpKey a b = .lt ∧ cmpKey b a = .gt` |
| `cmpKey_antisymm_urgency_lt` | high | high | Urgency-distinct case: antisymmetry holds in both directions |
| `cmpKey_both_incr` | mid | **high** | Case 7 correctness: both-incremental always returns `.gt` — the round-robin approximation |
| `cmpKey_incr_round_robin` | mid | **high** | Round-robin symmetry: neither incremental stream permanently dominates |
| `cmpKey_lt_urgency` | mid | medium | Case 2: lower urgency returns `.lt` |
| `cmpKey_gt_urgency` | mid | medium | Case 3: higher urgency returns `.gt` |
| `cmpKey_both_nonincr` | mid | medium | Case 4: non-incremental reduces to `compare id id` |
| `cmpKey_incr_vs_nonincr` | mid | medium | Case 5: incremental loses to non-incremental |
| `cmpKey_nonincr_vs_incr` | mid | medium | Case 6: non-incremental beats incremental |
| `cmpKey_total` | low | low | Totality: all cases covered, no panic |
| `cmpKey_refl` | low | low | Reflexivity: same key is always `.eq` |
| `cmpKey_same_id` | low | low | ID dominance: same stream-ID → Equal regardless of other fields |
| 7 examples | low | low | Concrete test vectors for all 7 cases |

**Assessment**: The standout result is `cmpKey_incr_incr_not_antisymmetric`
(OQ-1) — a formally proved deviation from the Rust `Ord` contract. Two
distinct incremental streams at the same urgency simultaneously compare as
`Greater` than each other. The intended semantics (round-robin: neither
dominates) is sound as a scheduling policy, but the Rust `Ord` trait docs
require antisymmetry for `BTreeMap` etc. The intrusive red-black tree used
here (`intrusive-collections` crate) accepts custom comparators and may
tolerate this; nonetheless the deviation is now formally documented.
**Gaps**: (1) fairness quantification — no theorem bounds how many rounds
before each incremental stream is served; (2) mixed urgency + incremental
transitivity is proved only for urgency-distinct case; (3) RBTree structural
invariants (tree balance under non-antisymmetric comparator) are out of scope.

---

## Gaps and Recommendations

Prioritised by impact:

1. **RecvBuf general-case write** (high): the `insertContiguous` model covers
   only the common in-order path.  The full `write()` function handles
   out-of-order and overlapping data via BTreeMap range-splitting.  Verifying
   invariant preservation for the general case — particularly the no-gap,
   no-duplicate postcondition — is the highest-value remaining proof target
   for the stream layer.

2. **StreamPriorityKey OQ-1 resolution** (high): follow up with maintainers
   on whether the `intrusive-collections` RBTree tolerates non-antisymmetric
   comparators (OQ-1). If it does not, the incremental round-robin is
   UB-adjacent. A theorem bounding the scheduling round-trip count would
   quantify the fairness guarantee.

3. **Connection ID sequence management** (medium — partially addressed):
   CID byte-content uniqueness and the `retire_if_needed` path are still
   unverified. Disjointness of active CID *values* (not just seqs) is
   security-critical per RFC 9000 §5.1.

4. **CUBIC w_cubic dynamic growth** (medium): the convexity and
   Reno-friendly transition of the CUBIC window curve are not yet proved.
   `wCubicNat_monotone` establishes non-decrease in time; the stronger
   property that W_cubic(t) > W_Reno(t) beyond the transition point would
   confirm correct AIMD–CUBIC mode switching.

5. **RTT lower-bound / decay rate** (medium): add theorems showing
   `smoothed_rtt` cannot fall below some fraction of `min_rtt`.  This
   would catch an under-smoothing bug that could make the congestion
   controller too aggressive.

6. **Flow control u64 overflow guard** (medium): add a bounded model
   (restrict `consumed + window < 2^62`) and prove no overflow occurs
   under the varint limit.  This closes the one known gap between the
   Lean model and the Rust u64 arithmetic.

7. **SendBuf retransmission and reset paths** (medium): the current model
   covers write/emit/ack/updateMaxData but not `retransmit()`, `reset()`,
   `shutdown()`, or `stop()`.  These control the stream termination state
   machine and interact non-trivially with flow control.

8. **Varint wire-format tag bits** (low): add a theorem verifying that the
   2-bit tag in the first byte of an encoded varint matches the length class.
   Current proofs do not cover this aspect.

---

## Concerns

- **Nat vs u64**: all fifteen files model Rust `u64`/`usize` values as Lean
  `Nat` (unbounded). Overflow is the primary unverified risk; see
  CORRESPONDENCE.md for per-file documentation.  The varint file partially
  mitigates this by bounding inputs to `MAX_VAR_INT = 2^62 − 1`.

- **StreamPriorityKey OQ-1**: the `cmpKey_incr_incr_not_antisymmetric` theorem
  proves a violation of the Rust `Ord` contract antisymmetry axiom. Whether
  `intrusive-collections` RBTree is safe under a non-antisymmetric comparator
  is currently unknown; until confirmed, the round-robin scheduling proof
  rests on unverified tree behaviour.

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

- **`cmpKey_incr_incr_not_antisymmetric`** (StreamPriorityKey.lean, run 49):
  formal proof that `StreamPriorityKey::cmp` violates Rust `Ord` antisymmetry
  for the both-incremental same-urgency case (`a.cmp(b) = Greater` AND
  `b.cmp(a) = Greater` simultaneously). The concrete counterexample
  `{ id=4, urgency=3, incremental=true }` vs `{ id=7, urgency=3,
  incremental=true }` is verified by `decide`. This finding confirms that the
  round-robin scheduling design intentionally deviates from the standard `Ord`
  contract — the question of whether `intrusive-collections` RBTree is safe
  under this deviation is OQ-1, now formally stated.

- **`decode_pktnum_correct`** (PacketNumDecode.lean, run 39): the first
  end-to-end algorithm correctness theorem in the suite — proves that RFC 9000
  §A.3's packet number decoding function returns the correct result under the
  QUIC proximity invariant, for all three window-shift cases.  During the proof,
  a genuine counterexample to the original (run 38) theorem statement was
  discovered: the non-strict lower-bound allowed an erroneous branch-1 fire at
  `actual_pn = expected_pn − pnHwin`.  The theorem was tightened to use strict
  `<` (as specified in RFC 9000 §A.3 itself), confirming that the FV process
  caught a real precision gap that the original code review missed.

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

---

### DatagramQueue (`FVSquad/DatagramQueue.lean`) — 26 theorems

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `push_preserves_cap_inv` | mid | high | Capacity bound enforced by push: `len ≤ maxLen` after every successful push |
| `pop_preserves_cap_inv` | mid | medium | Capacity can only decrease on pop |
| `purge_preserves_cap_inv` | mid | medium | Purge can only decrease len |
| `push_byteSize_inc` | mid | high | Byte-size counter stays accurate after push |
| `pop_byteSize_dec` | mid | high | Byte-size counter stays accurate after pop — key for bandwidth estimation |
| `push_pop_singleton` | mid | medium | Round-trip: push then pop on empty queue recovers element |
| `push_then_pop_front_unchanged` | mid | high | FIFO ordering: pop returns original front, not the just-pushed element |
| `purge_removes_matching` | mid | medium | Purge correctness: no matching element survives |
| `purge_keeps_non_matching` | mid | medium | Purge completeness: all non-matching elements survive |
| `push_fails_iff_full` | low | medium | Error path: push returns None iff at capacity |
| `purge_noop` / `purge_all` | low | low | Purge identity and full-removal edge cases |
| 15 others | low | low | isEmpty/isFull consistency, new postconditions |

**Assessment**: Mid-level utility.  The three most valuable theorems are
`push_byteSize_inc`/`pop_byteSize_dec` (byte-size invariant, important for
send-budget accounting), `push_then_pop_front_unchanged` (FIFO ordering,
important for datagram delivery order), and `push_preserves_cap_inv` (capacity
bound, important for backpressure).  A real implementation bug in the
`queue_bytes_size` counter would be caught by the byte-size theorems.
**Gaps**: (1) zero-length datagram edge case (byteSize=0 yet !isEmpty) not
covered; (2) `peek_front_bytes` not modelled (requires byte-slice model);
(3) `max_len=0` (immediately full) is consistent with the model but not
separately exercised.

---

### Target 9: PacketNumDecode (24 theorems, 0 sorry) ✅

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `decode_mod_win_exact` | mid | **high** | If the arithmetic model were wrong, the central RFC 9000 §17.1 invariant would fail. Proves the decoded number carries the right low-order bits. |
| `test_vector_rfc_example` + 6 others | low | medium | 7 concrete test vectors cross-validate the model against quiche's own test suite. Any discrepancy in the arithmetic model would surface here. |
| `candidate_lt_expected_plus_win` / `expected_lt_candidate_plus_win` | low | medium | Structural bounds on candidate proximity to expected_pn; used in branch-2 upper bound. |
| `decode_branch2_upper` | mid | medium | Downward-adjustment result stays ≤ expected + hwin. Would catch an off-by-one in the branch condition. |
| `decode_branch1_overflow_guard` | mid | **high** | Proves the overflow guard correctly prevents the result exceeding 2^62. A missing or wrong guard could allow illegal QUIC packet numbers in practice. |
| `candidate_shift_win` | low | low | Structural monotonicity lemma. Useful for inductive arguments. |
| `decode_pktnum_correct` | high | **high** | Main correctness theorem: under QUIC invariant, decode returns the right packet number. **FULLY PROVED** (run 39) via 3-way window-quotient case split with `mul_uniq_in_range`. |
| `mul_uniq_in_range` | low | low | Helper: unique-multiple-in-interval lemma. Used internally by `decode_pktnum_correct`. |
| `decode_nonneg` | trivial | none | Trivially true for Nat; no bug-catching value. |

**Findings from run 39**: During the proof of `decode_pktnum_correct` an
**edge case was discovered**: the original theorem statement had `hprox2 :
largest_pn + 1 ≤ actual_pn + pnHwin` (non-strict). A counterexample exists at
`actual_pn = expected_pn − pnHwin` where branch 1 fires and returns
`actual_pn + win` instead of `actual_pn`. This is a genuine divergence between
the arithmetic Lean model and the RFC 9000 §A.3 invariant, which uses a strict
lower bound (`actual_pn > expected_pn − pn_hwin`). The theorem was corrected to
use strict `<` plus bounds `hoverflow : actual_pn < 2^62` and `hwin_le :
pnWin ≤ 2^62` (both always satisfied in real QUIC usage).

**Overall assessment**: `PacketNumDecode` is now fully verified. The
`decode_pkt_num` function is called for every received QUIC packet, and a
decode error would result in dropped or misrouted packets. The proof covers
the complete RFC 9000 §A.3 correctness argument for all three window-shift
cases (upward adjustment, downward adjustment, no adjustment).

---

### Target 10: CUBIC congestion control (`FVSquad/Cubic.lean`) — 26 theorems ✅

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `wCubic_epoch_anchor` | high | **high** | RFC 8312bis §5.1: CUBIC curve passes through the reduction point at epoch start — verifies the fundamental W_max anchor property |
| `ssthresh_lt_cwnd_pos` | high | **high** | On every fresh loss event, ssthresh < cwnd (strict reduction) — the key CUBIC safety property |
| `fastConv_wmax_lt_cwnd` | high | **high** | Fast convergence: w_max is reduced below cwnd when below prior peak |
| `wCubicNat_monotone` | high | medium | W_cubic is non-decreasing in time — confirms the "restore-then-grow" curve shape |
| `wCubicNat_ge_wmax_of_t_ge_k` | mid | medium | W_cubic ≥ w_max when t ≥ K — curve correctly rises above the prior peak |
| `congestionEvent_reduces_cwnd` | mid | **high** | cwnd > 0 → new_cwnd < cwnd; strict reduction on congestion |
| `wCubicNat_at_k_eq_wmax` | mid | medium | W_cubic(K) = w_max — exact epoch-anchor identity (Nat model) |
| `fastConv_monotone` | mid | low | Monotonicity of fast-convergence w_max function |
| 18 others | low | low | Concrete test vectors, structural helpers, parameter bounds |

**Assessment**: The epoch-anchor and strict-reduction theorems are high-value.
`wCubic_epoch_anchor` formally verifies the mathematical property that defines
CUBIC's recovery behaviour: after a loss, the window starts at the correct
fractional reduction point and the CUBIC curve is anchored there.
`ssthresh_lt_cwnd_pos` prevents the pathological case of a loss event that
fails to reduce the congestion window. **Gap**: (1) the Reno-friendly
transition theorem (W_cubic vs W_est comparison) is not proved; (2) the f64
cube root (`libm::cbrt`) is abstracted as a hypothesis — the libm
implementation is not verified; (3) no multi-loss-event monotonicity theorem
verifies that repeated losses converge the window correctly.

---

### Target 11: RangeBuf offset arithmetic (`FVSquad/RangeBuf.lean`) — 19 theorems ✅

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `consume_maxOff` | high | **high** | `consume` preserves `maxOff` — the BTreeMap key in `RecvBuf` is stable across partial reads. A violation would corrupt the BTreeMap ordering |
| `split_adjacent` | high | **high** | `left.maxOff = right.off` — no gap, no overlap between split halves. A violation would create a data hole or duplicate region |
| `split_maxOff` | mid | **high** | `right.maxOff = original.maxOff` — split preserves the right-side boundary |
| `consume_split_maxOff` | mid | medium | Composing consume then split preserves maxOff |
| `split_len_partition` | mid | medium | `left.len + right.len = original.len` — partition is complete, no byte loss |
| `split_left_fin_false` | mid | medium | Left half never carries the FIN bit — only the rightmost split fragment can be terminal |
| `split_right_fin` | mid | medium | Right half inherits the original FIN flag |
| `maxOff_identity` | low | low | `maxOff = curOff + curLen` — definitional consistency |
| 11 others | low | low | Structural helpers, test vectors, monotonicity |

**Assessment**: `consume_maxOff` and `split_adjacent` are the most important
theorems: both prove properties relied upon by the `RecvBuf` reassembler.
`RecvBuf` keys its BTreeMap on `max_off`; a `consume` call that changed
`max_off` would silently corrupt the tree. `split_adjacent` proves the
partition is exact — a gap would silently drop bytes. These theorems are
foundational for the RecvBuf proofs. **Gap**: byte contents are abstracted
away; data integrity through consume and split is not verified.

---

### Target 12: Stream receive buffer (`FVSquad/RecvBuf.lean`) — 32 theorems ✅

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `emitN_preserves_inv` | high | **high** | All 5 buffer invariants preserved by `emitN` (read-cursor advance) — structural safety of the reassembler read path |
| `insertContiguous_inv` | high | **high** | All 5 buffer invariants preserved by in-order sequential write — structural safety of the common write path |
| `insertContiguous_two_highMark` | high | **high** | Two sequential writes advance `highMark` by `c1.len + c2.len` — byte-count accounting correctness |
| `insertContiguous_highMark_grows` | mid | **high** | Non-empty write strictly advances `highMark` — monotone progress |
| `emitN_readOff_nondecreasing` | mid | **high** | Read cursor never moves backward — stream delivery ordering |
| `isFin_readOff_eq_highMark` | mid | medium | When FIN is set and stream is drained, `readOff = highMark` |
| `chunksAbove_mono` | low | low | Ordering helper |
| `chunksAbove_of_ordered` | low | low | Structural helper |
| 24 others | low | low | Invariant sub-properties, accessor identities, test vectors |

**Assessment**: The invariant-preservation theorems are high-value for the
most complex data structure in the stream layer. The RecvBuf reassembler is
the code path for all QUIC stream data delivery; a bug corrupting chunk
ordering or byte accounting would silently produce garbled application data.
`insertContiguous_inv` is the key result — it proves the well-formedness
invariant is an inductive invariant of the common write path. **Gaps**:
(1) `insertContiguous` models only the contiguous (in-order) path; the
general overlapping-write case is not proved; (2) flow-control limit
enforcement (`highMark ≤ max_data`) is not modelled; (3) drain mode and
reset handling are not covered.

---

### Target 13: Stream send buffer (`FVSquad/SendBuf.lean`) — 43 theorems ✅

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `emitN_le_maxData` | high | **high** | **Security property**: `emitOff` can never exceed `maxData` after any emit — the sender cannot exceed the peer's flow-control credit (RFC 9000 §4.1) |
| `emitN_le_off` | high | **high** | The sender cannot emit beyond bytes that have been written — prevents sending uninitialised data |
| `write_preserves_inv` | high | **high** | All 4 invariants preserved by write (I1–I4 inductive under append) |
| `sb_emitN_preserves_inv` | high | **high** | All 4 invariants preserved by emitN — emitting bytes maintains well-formedness |
| `updateMaxData_preserves_inv` | high | **high** | MAX_DATA increase preserves invariants — flow-control update is safe |
| `write_possible_after_updateMaxData` | high | **high** | If peer sends MAX_DATA ≥ off + n, there is capacity for n bytes — the unblocking guarantee |
| `write_after_setFin_isFin_false` | mid | **high** | Writing past FIN invalidates is_fin — prevents data-after-FIN |
| `ackContiguous_preserves_inv` | mid | medium | ACK processing preserves all invariants |
| `setFin_preserves_inv` | mid | medium | Setting FIN preserves invariants |
| `setFin_isFin` | mid | medium | `setFin` correctly sets the FIN flag |
| `write_compose` | mid | medium | Sequential writes compose correctly: `write(n₁).write(n₂) = write(n₁+n₂)` |
| `cap_grows_after_updateMaxData` | mid | medium | Capacity strictly increases when MAX_DATA is raised |
| `cap_exhausted_after_write_cap` | mid | medium | Writing exactly `cap` bytes exhausts capacity |
| `ackContiguous_mono` | low | medium | ACK offset is non-decreasing |
| `emitN_emitOff_mono` | low | medium | Emit offset is non-decreasing |
| `updateMaxData_mono` | low | low | maxData is non-decreasing |
| 27 others | low | low | Accessor identities, test vectors, structural helpers |

**Assessment**: `emitN_le_maxData` is the most security-relevant theorem in
the entire suite — it formally proves the QUIC flow-control invariant for the
send path at the level of individual byte offsets. A violation would allow a
malicious receiver to withhold MAX_DATA updates and force the sender into
negative credit, or (more practically) a sender implementation bug could
exceed the advertised limit and violate the QUIC connection. The four
invariant-preservation theorems collectively prove that the send buffer
maintains its well-formedness under all modelled operations. **Gaps**:
(1) retransmission, reset, shutdown, and stop paths not modelled; (2) the ack
model uses contiguous-prefix only (not the full RangeSet ack); (3) Nat vs u64
overflow is not captured; (4) `blocked_at` and `error` fields not modelled.

---

### Target 14: Connection ID sequence management (`FVSquad/CidMgmt.lean`) — 21 theorems ✅

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `newScid_preserves_inv` | high | **high** | All 5 CID invariants preserved by `newScid` — structural safety of the SCID issuing path (RFC 9000 §5.1.1) |
| `retireScid_preserves_inv` | high | **high** | All 5 invariants preserved by `retireScid` — the retire path cannot corrupt the sequence state |
| `newScid_seq_fresh` | high | **high** | Newly issued seq was not previously active — duplicates are formally impossible |
| `retireScid_removes` | high | **high** | Target seq is absent after retire — the retire contract is honoured |
| `retireScid_keeps_others` | high | high | Non-target seqs are unaffected — retire has no collateral damage |
| `activeSeqs_lt_nextSeq` | mid | medium | All active seqs are strictly below `nextSeq` — sequence-number ordering invariant (I3) |
| `newScid_nextSeq_strict` | mid | medium | `nextSeq` strictly advances — no wrap-around under natural-number model |
| `newScid_two_distinct` | mid | medium | Two successive `newScid` calls always yield different seqs |
| `applyNewScid_nextSeq` | mid | medium | After k calls, `nextSeq` = initial + k — exact accounting |
| `applyNewScid_length` | mid | medium | Active set grows by exactly k — capacity accounting correctness |
| 11 others | low | low | Accessors, list helpers (`allDistinct_append_fresh`, `filter_length_le`, etc.) |

**Assessment**: The CidMgmt suite captures the security-critical property
from RFC 9000 §5.1.1: every source Connection ID has a unique sequence number
that is never reused. `newScid_seq_fresh` is the key result — it proves that
the allocator never issues a sequence number already present in the active set.
`newScid_preserves_inv` proves that the five-part well-formedness invariant
(including the SCID count bound `|active| ≤ 2·limit−1` mandated by RFC 9000
§5.1.1) is an inductive invariant. **Gaps**: (1) CID byte content (duplicate
CID detection) is not modelled; (2) the `retire_if_needed` path is not
modelled; (3) path-binding, reset-token, and `retire_prior_to` semantics are
entirely out of scope; (4) integer overflow on `u64` sequence numbers is not
captured (practically irrelevant: 2^64 CID retirements is not feasible).
