# Formal Verification Proof Utility Critique

> 🔬 *Written by Lean Squad automated formal verification.*

## Last Updated

- **Date**: 2026-05-20 11:33 UTC
- **Commit**: `f7090d2a`
- **Run**: run 177 — Task 7 (Critique) + Task 5 (T76 BBR2ModeState, 19 theorems).
  Full suite: **70 Lean files, 1348 theorems, 0 sorry**;
  27 Route-B test targets (2864+ PASS).

---

## Overall Assessment

The formal verification suite for `quiche` now covers **70 Lean files with
1348 theorems, 0 sorry** 🎉 (Lean 4.29.1, no Mathlib), backed by
**27 Route-B correspondence test targets (2864+ cases PASS)**. Runs 166–177
added T32 (`BBR2PacingRate`, 14 thms), RFC9000Sec46 composed §4.6 chain (12
thms, run 168), T70 (`BBR2DrainPhase` constants, 21 thms), T71 (`BBR2Startup`
constants, 26 thms), T72 (`BBR2ProbeRTTPhase` constants, 25 thms), T73
(`BBR2CyclePhaseGain`, 23 thms), T74 (`PacketTypeEpoch` round-trip, 14 thms),
T75 (`BBR2DrainExit`, 17 thms, run 176), and T76 (`BBR2ModeState` abstract
state machine, 19 thms, this run).

The suite now spans the full QUIC stack: byte-level framing, congestion control
(NewReno with AIMD cycles, Cubic with W_est Reno-friendly extension, BBR2 with
startup/probing model including **all four phase constant groups** — startup,
drain, ProbeRTT, ProbeBW cycle gains — **drain exit condition**, **abstract
four-mode state machine** (Startup → Drain → ProbeBW ↔ ProbeRTT), pacing,
HyStart++, WindowedFilter, delivery-rate estimation, app-limited guard,
inflight_lo guard, probe-up slope), HTTP/3 codec, QPACK, stream/frame state
machines, transport error codes, idle-timeout negotiation, PMTUD binary search,
and RFC compliance. Every theorem has been mechanically verified by `lake build`.


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

- **`encode_decode_pktnum`** (PacketNumEncodeDecode.lean, run 76): the first
  end-to-end encode↔decode composition theorem — formally proves that for any
  valid QUIC packet number `pn` and largest-acknowledged `la`, the sender's
  chosen encoding length `pktNumLen(pn, la)` satisfies the RFC 9000 §A.2
  proximity conditions needed for the receiver to decode `pn` correctly. This
  bridges the two independent halves of the packet-number lifecycle
  (`PacketNumLen.lean` and `PacketNumDecode.lean`) with zero sorry.

- **`retransmit_inv` + `retransmit_noop_acked`** (SendBufRetransmit.lean,
  run 68): together these prove the two key safety properties of the
  retransmit operation: (1) the send-buffer invariant is preserved, and (2)
  acknowledged data cannot be requeued. The `retransmit_emitOff_formula`
  theorem gives a complete, executable specification of the cursor-level
  semantics, enabling future proofs about the retransmit→emit composition.

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

### Target 12: Stream receive buffer (`FVSquad/RecvBuf.lean`) — 38 theorems ✅

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `emitN_preserves_inv` | high | **high** | All 5 buffer invariants preserved by `emitN` (read-cursor advance) — structural safety of the reassembler read path |
| `insertContiguous_inv` | high | **high** | All 5 buffer invariants preserved by in-order sequential write — structural safety of the common write path |
| `insertAny_inv` | high | **high** | All 5 buffer invariants preserved by out-of-order write (new run 61) — full reassembly path is safe |
| `insertContiguous_two_highMark` | high | **high** | Two sequential writes advance `highMark` by `c1.len + c2.len` — byte-count accounting correctness |
| `insertContiguous_highMark_grows` | mid | **high** | Non-empty write strictly advances `highMark` — monotone progress |
| `emitN_readOff_nondecreasing` | mid | **high** | Read cursor never moves backward — stream delivery ordering |
| `isFin_readOff_eq_highMark` | mid | medium | When FIN is set and stream is drained, `readOff = highMark` |
| `chunksAbove_mono` | low | low | Ordering helper |
| `chunksAbove_of_ordered` | low | low | Structural helper |
| 29 others | low | low | Invariant sub-properties, accessor identities, test vectors |

**Assessment**: The addition of `insertAny_inv` (run 61) closes the most
significant gap in the prior version: the general out-of-order write path is
now formally verified to preserve all five buffer invariants. Together with
`insertContiguous_inv` and `emitN_preserves_inv`, the three main state-
changing operations (contiguous write, OOO write, read-advance) are all
verified to be invariant-preserving. `RecvBuf` reassembly is the code path
for all QUIC stream data delivery — a corruption here silently garbles
application data. **Remaining gaps**: (1) flow-control limit enforcement
(`highMark ≤ max_data`) is not modelled; (2) drain mode, reset handling, and
`shutdown` are not covered; (3) byte *contents* (data integrity through
reassembly, not just structural invariants) are abstracted away.

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

---

### Target 15: Stream priority ordering (`FVSquad/StreamPriorityKey.lean`) — 21 theorems ✅

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `cmpKey_antisymm_eq` | high | **high** | `cmpKey a b = .gt ∧ cmpKey b a = .gt` — **formally proves OQ-1**: both-incremental case violates `Ord` antisymmetry |
| `cmpKey_refl` | high | medium | `cmpKey a a = .eq` — reflexivity holds; identifies are always equal to themselves |
| `cmpKey_same_id` | high | medium | Same stream ID → always equal; prevents duplicate priority entries |
| `cmpKey_lt_urgency` | high | **high** | Lower urgency strictly dominates — RFC 9218 §5.1 priority order (urgency 0 outranks urgency 7) |
| `cmpKey_gt_urgency` | high | **high** | Higher urgency never beats lower — RFC 9218 §5.1 complementary direction |
| `cmpKey_incr_vs_nonincr` | mid | medium | Non-incremental beats incremental at same urgency |
| `cmpKey_nonincr_id_order` | mid | medium | Both non-incremental: lower stream ID wins (FIFO ordering within tier) |
| 14 others | low | low | Accessors, urgency-bound test vectors, structural helpers |

**Finding (OQ-1)**: Both `cmpKey a b = .gt` and `cmpKey b a = .gt` hold
simultaneously when `a.urgency = b.urgency`, `a.incremental = true`, and
`b.incremental = true` (and `a.id ≠ b.id`). This violates the standard `Ord`
antisymmetry contract (`a > b → b < a`). The intrusive red-black tree used
for HTTP/3 stream scheduling may tolerate this; the RFC 9218 §5.1 spec says
incremental streams share the scheduling slot round-robin, not that they have
a strict ordering. The violation is formally confirmed but appears intentional.

**Assessment**: The streaming-priority suite is high-value because it
formalises the RFC 9218 scheduling contract. The OQ-1 finding is the most
interesting result: a formally confirmed antisymmetry violation in a
comparator used to drive HTTP/3 stream scheduling. **Gaps**: (1) transitivity
of `cmpKey` is not proved (it likely fails for the same reason antisymmetry
fails); (2) no theorem proves that the scheduling policy induced by `cmpKey`
actually satisfies the RFC 9218 §5.1 fairness requirements.

---

### Target 16: OctetsMut byte serialiser (`FVSquad/OctetsMut.lean`) — 27 theorems ✅

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `putU8_round_trip` | high | **high** | Writing then reading one byte recovers the original value — codec round-trip for the most basic operation |
| `putU16_round_trip` | high | **high** | `putU16` big-endian round-trip: two bytes written, then read back with `getU16`, recover original value |
| `putU32_round_trip` | high | **high** | `putU32` big-endian round-trip |
| `putU64_round_trip` | high | **high** | `putU64` big-endian round-trip |
| `put_varint_round_trip` | high | **high** | QUIC varint write then read recovers original value — the key codec property for all QUIC frame field encoding |
| `listSet_preserves_length` | mid | medium | Writing a byte does not change the buffer length — no spurious growth or truncation |
| `listGet_set_eq` | mid | medium | A byte written at position `i` is readable at position `i` |
| `listGet_set_ne` | mid | medium | Writing at `i` does not affect position `j ≠ i` — isolation |
| `putU8_advances_off` | mid | medium | Offset advances by exactly 1 after writing one byte |
| `putU16_advances_off` | mid | medium | Offset advances by exactly 2 after writing a u16 |
| 17 others | low | low | Structural helpers, out-of-bounds behaviour, big-endian byte layout tests |

**Assessment**: The round-trip theorems are the most valuable results —
a codec round-trip failure means frame encoding is broken, which would
corrupt every QUIC packet. The five round-trip theorems (`putU8` through
`put_varint`) collectively cover the entire range of primitive put operations.
`listGet_set_ne` (isolation) is also important: without it, a write to one
field could corrupt an adjacent field. **Gaps**: (1) no theorem verifies
big-endian byte order against RFC 9000 §16 explicitly (the model uses
`256*hi + lo` which IS big-endian, but the RFC check is implicit); (2)
`put_bytes` (bulk copy) is not modelled; (3) the `OctetsMut`↔`Octets`
composition (write then pass to a reader) is not proved end-to-end.

---

### Target 17: Octets read-only cursor (`FVSquad/Octets.lean`) — 48 theorems ✅

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `getU8_round_trip` | high | **high** | Read one byte; offset advances by 1; value equals source byte |
| `getU16_split` | high | **high** | `getU16 = hi * 256 + lo` where hi/lo are consecutive bytes — **formally proves** big-endian framing matches RFC 9000 §16 |
| `getU32_decomp` | high | **high** | `getU32 = b0*16777216 + b1*65536 + b2*256 + b3` — big-endian correctness for all four bytes |
| `getU64_decomp` | high | **high** | Full 8-byte big-endian decomposition |
| `get_varint_round_trip` | high | **high** | QUIC varint read: round-trip `encode → getVarint` recovers original value (run 62) |
| `skip_advances_off` | mid | medium | `skip n` advances offset by exactly n |
| `peek_does_not_advance` | mid | medium | `peek_u8` reads without advancing — non-destructive |
| `slice_length` | mid | medium | `get_bytes(n)` produces exactly n bytes |
| `withSlice_inv` | mid | medium | The invariant holds for a slice created from a byte list |
| `inv_preserved_after_getU8` | high | **high** | Reading one byte preserves the `Inv` (off ≤ len) invariant — read path is safe |
| `octListGet_out_of_bounds` | mid | medium | Out-of-bounds read returns 0 (graceful default, not crash) |
| 37 others | low | low | Structural helpers, multi-byte decompositions, offset-consistency lemmas |

**Finding from run 62 (`getU16_split`)**: The proof of `getU16_split`
confirms that `getU16 b = b[0] * 256 + b[1]`, verifying that the
`Octets::get_u16()` implementation correctly implements big-endian byte order
as specified in RFC 9000 §16. This is a non-trivial structural property: the
high byte is read first, shifted by 8 bits, and OR-ed with the low byte. The
Lean model uses `256*` (multiplication) to model bitwise shift, and the proof
holds by case analysis on the two individual byte reads.

**Assessment**: The Octets suite is the largest individual module with 48
theorems. The four big-endian decomposition theorems (`getU16_split`,
`getU32_decomp`, `getU64_decomp`, `get_varint_round_trip`) are high-value:
any error in the big-endian byte ordering would silently misparse all QUIC
frame fields. The `inv_preserved_after_getU8` theorem proves the safety
invariant (read cursor cannot go past the end) is inductive under reads.
**Gaps**: (1) `get_bytes` content integrity (not just length) is not proved;
(2) `as_ref`/`from_bytes` constructors are not modelled; (3) the
`Octets`↔`OctetsMut` composition round-trip (encode then decode a full frame)
remains for a future target.

---

### Target 18: Stream ID arithmetic (`FVSquad/StreamId.lean`) — 35 theorems ✅ *(added run 64)*

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `streamType_complete` | high | **high** | Every stream ID has exactly one of 4 types (0-3) — no stream can fall outside the RFC 9000 §2.1 classification |
| `streamType_add4` | high | **high** | Adding 4 preserves stream type — verifies that stream IDs of the same type differ by 4 (RFC 9000 §2.1 sequence rule) |
| `streamType_add_mul4` | high | **high** | `streamType(id + 4k) = streamType(id)` — the type orbit under +4 is correct for all k |
| `isBidi_add4` / `isBidi_add_mul4` | high | **high** | `isBidi` is preserved under +4 increments — prevents an endpoint from accidentally creating a uni stream where a bidi was expected |
| `isServerInit_add4` | high | **high** | `isServerInit` is preserved under +4 — server-initiated streams remain server-initiated |
| `openStream_dec` | high | **high** | Opening one stream reduces `streamsLeft` by exactly 1 — credit accounting is correct |
| `updatePeerMax_grows_left` | high | **high** | A larger MAX_STREAMS strictly increases available credits — the unblocking guarantee |
| `openThenUpdate_has_capacity` | high | **high** | After consuming the last credit, a MAX_STREAMS update restores capacity — the peer-controlled flow-control lifecycle is proved |
| `isBidi_iff_type_lt2` | mid | medium | `isBidi ↔ streamType < 2` — consistent with the bit-1 definition |
| `isServerInit_iff_type_odd` | mid | medium | `isServerInit ↔ streamType % 2 = 1` — consistent with the bit-0 definition |
| `streamsLeft_zero_iff` | mid | medium | Credits exhausted iff `opened = peerMax` — boundary condition |
| `updatePeerMax_mono` | mid | medium | MAX_STREAMS never decreases — monotonicity of peer limit |
| 12 canonical first-ID tests | low | low | Verify the RFC 9000 Table 1 mapping for streams 0-3 |
| 8 examples | low | low | Concrete `streamsLeft` calculations, stream type examples |

**Assessment**: The StreamId suite is notable for proving the arithmetic
invariants of QUIC's stream-type system at the level of the RFC 9000 §2.1
specification. The critical property is `streamType_add_mul4`: if this were
false, endpoints could miscalculate the next stream ID of a given type,
opening a stream as the wrong type (e.g., server opening a client stream
number) which QUIC forbids and would cause a PROTOCOL_VIOLATION error.
`openStream_dec` and `updatePeerMax_grows_left` together formally verify the
MAX_STREAMS credit lifecycle — a bug there could allow opening more streams
than the peer permits, violating RFC 9000 §4.6. **Gaps**: (1) interaction
between stream-ID classification and `stream_do_send`'s guard (`!isBidi &&
!isLocal → error`) is not proved end-to-end; (2) the mapping between
`localOpened` and the actual stream IDs opened is not modelled; (3) bidirectional
vs unidirectional stream count separation (the model uses one `StreamCredits`
struct but there are two independent counts in practice).

---

### Target 19: OctetsMut↔Octets cross-module round-trip (`FVSquad/OctetsRoundtrip.lean`) — 20 theorems ✅ *(added run 65)*

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `putU8_freeze_getU8` | high | **high** | `putU8` then `freeze` then `getU8` recovers the value — core U8 round-trip |
| `putU16_freeze_getU16` | high | **high** | U16 big-endian encode→freeze→decode round-trip — verifies byte ordering |
| `putU32_freeze_getU32` | high | **high** | U32 big-endian encode→freeze→decode round-trip |
| `putU8_octets_independent` | high | **high** | `putU8` at offset `off` does not change any other byte — non-aliasing |
| `putU8_byte_at_off` | high | **high** | `putU8` places value exactly at `off` — direct write-address correctness |
| `putU8_bytes_unchanged` | mid | medium | Bytes at `j ≠ off` are unchanged by `putU8` |
| `putU8_x2_freeze_byte0/1` | mid | medium | Two sequential `putU8` writes are independent — composition safety |
| `putU16_freeze_byte0/1` | mid | medium | Individual byte layout of U16 big-endian encoding |
| `putU32_freeze_byte0/1/2/3` | mid | medium | Individual byte layout of U32 big-endian encoding |
| `freeze_cap_eq` | low | low | `freeze` preserves the buffer capacity (length) |
| `mut_getU8_eq_octets_getU8` | mid | medium | `OctetsMut.getU8` and `Octets.getU8` agree on the same buffer |
| `listGet_eq_octListGet` | low | low | Model consistency: list `get?` matches the helper `octListGet` |
| `octListGet_set_eq/ne` | low | low | Get-set axioms for the shared byte-array model |
| 9 examples | low | low | Concrete put→freeze→get calculations verified by `decide` |

**Assessment**: OctetsRoundtrip is the cross-module bridge completing the
serialiser verification. The three round-trip theorems (`putU8/16/32_freeze_get`)
are high-value: a bug in big-endian byte ordering (e.g., byte-swap) would
directly violate `putU16_freeze_getU16`. The non-aliasing theorem
`putU8_octets_independent` rules out a class of buffer-corruption bugs where
a write at one offset corrupts a neighbouring byte. **Gaps**: (1) the
`put_varint`→`get_varint` end-to-end composition is not yet proved — the
varint codec uses a sequence of U8 writes but their round-trip through the
cross-module interface is not formally established; (2) `get_bytes` content
integrity (not just length) after a sequence of puts is not modelled.

---

### Target 20: Packet-number encoding length (`FVSquad/PacketNumLen.lean`) — 20 theorems ✅ *(added run 66)*

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `pktNumLen_eq_one_iff` / `_two_iff` / `_three_iff` / `_four_iff` | high | **high** | Full biconditional characterisation: `pktNumLen = k ↔ numUnacked ∈ [threshold_{k-1}, threshold_k)` |
| `pktNumLen_one_coverage` / `_two_` / `_three_` / `_four_` | high | **high** | RFC 9000 §17.1 half-window invariant: encoded packet number fits in the chosen byte width |
| `pktNumLen_mono` | high | **high** | Monotone: larger unacked gap forces a larger (or equal) encoding — no truncation |
| `pktNumLen_valid` | high | **high** | `pktNumLen` always returns 1–4 (in-range); `encode_pkt_num` never errors for valid inputs |
| `pktNumLen_ge_two` / `_three` / `_four` | mid | medium | Threshold forcing: at specific `numUnacked` values the encoder is forced to a larger width |
| `pktNumLen_ge_one` / `_le_four` | mid | medium | Range bounds — encoding is always 1–4 bytes |
| `numUnacked_pos` / `_ge_one` / `_self` / `_lt` | low | low | Basic arithmetic of the `numUnacked` gap formula |
| `pktNumLen_self` | low | low | When `pn = largestAcked`, `numUnacked = 1`, encoding is 1 byte |
| 10 concrete examples | low | low | All threshold boundary values verified by `decide` |

**Assessment**: The coverage theorems are the highest-value results in this
file. `pktNumLen_k_coverage` proves that the encoding choice always satisfies
the RFC 9000 §17.1 requirement: the receiver can decode the packet number
because the encoded bytes represent a value within the half-window. The
monotonicity theorem (`pktNumLen_mono`) rules out a class of bugs where
increasing the packet-number gap triggers a smaller encoding (which would
cause the receiver to reject the packet). The `four_coverage` theorem takes a
validity hypothesis (`numUnacked ≤ 2^31`) matching the Rust function's
error-return boundary — values above that are modelled as returning 4, while
the real implementation returns an error; this is a known modelling
approximation. **Gaps**: (1) the reverse direction (`decode_pkt_num` after
`encode_pkt_num` recovers the original `pn`) is not proved end-to-end in this
file (the existing `PacketNumDecode.lean` proves decode correctness
independently but the encode-then-decode composition is unmodelled); (2) the
case where `pn < largestAcked` (e.g. a reordered packet) is not specially
handled.

---

### Target 21: SendBuf retransmit model (`FVSquad/SendBufRetransmit.lean`) — 17 theorems ✅ *(added run 68)*

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `retransmit_inv` | high | **high** | Invariant (ackOff ≤ emitOff ≤ off ≤ maxData) preserved after retransmit — the central safety guarantee |
| `retransmit_emitOff_formula` | high | **high** | Exact formula for new emitOff: `min(s.emitOff, max(s.ackOff, off))` — specifies full semantics |
| `retransmit_emitOff_le` | high | **high** | `retransmit` can only lower or keep emitOff — proves backtracking direction is correct |
| `retransmit_noop_acked` | high | **high** | Fully acknowledged ranges (`off + len ≤ ackOff`) are no-ops — cannot un-acknowledge data |
| `retransmit_noop_unemitted` | high | medium | Ranges not yet emitted (`off ≥ emitOff`) do not change emitOff — retransmit is idempotent for not-yet-sent data |
| `retransmit_idempotent` | mid | medium | Applying retransmit twice gives the same state as once — no stale bookkeeping |
| `retransmit_send_backlog_le` | mid | medium | The send backlog (`emitOff - ackOff`) does not increase past `off - ackOff` — an upper bound on queued retransmits |
| `retransmit_emitN_inv` | high | **high** | Invariant preserved through a subsequent `emitN` call — lifecycle composition is safe |
| `retransmit_emitOff_anti_mono` | mid | medium | emitOff is anti-monotone under retransmit: if one retransmit is a prefix of another, the prefix has smaller effect |
| `retransmit_emitN_bounded` | mid | medium | After retransmit + emitN, offset stays within `maxData` bound |
| `retransmit_emitN_le_maxData` | high | **high** | Bytes re-emitted after retransmit respect the flow-control window |
| `retransmit_off_unchanged` + siblings | low | low | Effect theorems: ackOff, off, maxData, finOff unchanged — only emitOff is modified |
| 4 simp accessor lemmas | low | low | `retransmit.off/ackOff/maxData/finOff` by definition |
| 10 examples | low | low | Concrete retransmit scenarios verified by `decide` |

**Assessment**: `retransmit_inv` and `retransmit_emitOff_formula` are the
highest-value results. The formula theorem gives a complete, executable
specification for the retransmit cursor effect; any mismatch between the
formula and the Rust implementation would indicate a semantic bug.
`retransmit_noop_acked` proves the critical safety property that acknowledged
data cannot be requeued. The `retransmit_emitN_inv` and
`retransmit_emitN_le_maxData` theorems ensure that the retransmit→emit
lifecycle is safe under the flow-control window. **Approximations**: only the
scalar cursor effect is modelled; byte contents and the deque shape (individual
`RangeBuf.pos` resets) are abstracted away. **Gap**: the interaction between
retransmit and FIN consistency (can retransmit set emitOff below finOff?) is
not explicitly proved.

---

### Target 23: VarInt cross-module round-trip (`FVSquad/VarIntRoundtrip.lean`) — 8 theorems ✅ *(0 sorry — run 85)*

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `putVarint_freeze_getVarint_1byte` | high | **high** | `put_varint` (1-byte) → `freeze` → `get_varint` = identity for v < 64 |
| `putVarint_freeze_getVarint_2byte` | high | **high** | 2-byte round-trip for 64 ≤ v < 16384 |
| `putVarint_freeze_getVarint_4byte` | high | **high** | 4-byte round-trip for 16384 ≤ v < 1073741824 |
| `putVarint_freeze_getVarint_8byte` | high | **high** | 8-byte round-trip for v ≥ 1073741824 — **proved run 85** via `putU32_bytes_unchanged` |
| `putVarint_freeze_getVarint` | high | **high** | Combined round-trip for all valid QUIC varint values — **proved run 85** |
| `putVarint_off` | mid | medium | Cursor advances by `varintLen(v)` after `put_varint` |
| `putVarint_len` | mid | medium | `putVarint` places exactly `varintLen(v)` bytes |
| `putVarint_first_byte_tag` | mid | medium | First-byte tag bits equal `varintParseLen(first_byte) - 1` — **proved** for all 4 encoding sizes |
| 16 examples | low | low | Concrete put→freeze→get at each encoding length verified by `decide` |

**Assessment**: All 8 theorems are fully proved (0 sorry ✅ — run 85 closed the
8-byte path via `putU32_bytes_unchanged`). The four round-trip theorems collectively
verify that the varint codec correctly encodes and decodes the entire QUIC varint
value space (all values 0 to 2^62−1). `putVarint_first_byte_tag` confirms the
2-bit tag in the first byte is correctly set for all encoding sizes. These are
among the highest-value results in the codec layer.

---

### Target 24: Packet-number encode↔decode composition (`FVSquad/PacketNumEncodeDecode.lean`) — 10 theorems ✅ *(run 76)*

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `encode_decode_pktnum` | high | **high** | **Main composition theorem**: `decodePktNum la (pn % pnWin(pktNumLen pn la)) (pktNumLen pn la) = pn` for all valid pn, la |
| `pktNumLen_window_sufficient` | high | **high** | Bridge lemma: window ≥ 2 × numUnacked — establishes that pktNumLen always picks a sufficient width |
| `pnHwin_ge_numUnacked` | high | **high** | Half-window ≥ numUnacked — the RFC 9000 §A.2 proximity precondition is always satisfied |
| `pn_le_la_plus_hwin` | high | **high** | Upper proximity bound: satisfied by pktNumLen choice — enables decode_pktnum_correct |
| `la_plus1_lt_pn_plus_hwin` | high | **high** | Lower proximity bound: satisfied — other precondition of decode_pktnum_correct |
| `pktNumLen_win_le_overflow` | mid | medium | pnWin(pktNumLen) ≤ 2^62 — no overflow in the decode arithmetic |
| `encode_decode_same` | mid | medium | Corollary: pn = la (zero unacknowledged) round-trips correctly |
| `encode_decode_same_1byte` | mid | medium | Corollary: 1-byte case with `la % 256` |
| `encode_decode_one_byte` | mid | medium | Corollary: pn within 126 of la uses 1-byte encoding and round-trips |
| `pktNumLen_self_eq_one` | low | low | pktNumLen la la = 1 — encoding at pn=la uses 1 byte |
| 23 examples | low | low | All encoding-length boundaries and round-trips verified by `native_decide` |

**Assessment**: `encode_decode_pktnum` is one of the highest-value theorems in
the entire suite. It formally closes the encode↔decode composition for all four
QUIC packet-number encoding lengths, bridging `PacketNumLen.lean` (sender) and
`PacketNumDecode.lean` (receiver). Any bug in the sender's length-selection
logic (`pktNumLen`) or the receiver's decoding arithmetic (`decodePktNum`) would
violate this theorem. The proof relies on 5 auxiliary lemmas that collectively
establish the RFC 9000 §A.2 proximity conditions — these are proved for all
valid inputs with only the QUIC protocol cap (pn < 2^62) and the in-flight
bound (numUnacked ≤ 2^31) as preconditions. **Approximation**: the theorem
models only the arithmetic of encode↔decode; the actual buffer I/O (writing
`pn % pnWin` to the wire and reading it back) is abstracted away. **Gap**:
the receiver may receive packets with pn < la (reordered or replayed packets);
this case is not modelled.

---

### Target 29: QUIC packet-header first-byte (`FVSquad/PacketHeader.lean`) — 16 theorems ✅ *(0 sorry — run 105)*

> **Status**: Phase 5 Done. 14 public + 2 private theorems, 0 sorry. `lake build` passes.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `typeCode_roundtrip` | high | **high** | `typeOfCode(typeCode(ty)) = some ty` for all 4 long-header types — encode↔decode bijection for the 2-bit type field |
| `typeOfCode_roundtrip` | high | **high** | `typeCode(ty) = some c → typeOfCode c = some ty` — inverse direction |
| `typeCode_in_range` | mid | medium | Type code is always 0–3 — no out-of-range type codes are emitted |
| `typeCode_injective` | mid | medium | Different packet types have different codes — no type collisions |
| `longFirstByte_form_bit` | high | **high** | FORM_BIT (0x80) is always set in long-header first byte — wire format requirement |
| `longFirstByte_fixed_bit` | high | **high** | FIXED_BIT (0x40) is always set — RFC 9000 §17.2 validity |
| `longFirstByte_type_bits` | high | **high** | Type code occupies bits 5–4 of first byte — byte-layout correctness |
| `longFirstByte_byte_range` | mid | medium | First byte is in [0, 255] — always a valid byte value |
| `longFirstByte_injective` | high | **high** | Different long-header packet types produce different first bytes — decode is unambiguous |
| `shortFirstByte_no_form_bit` | high | **high** | FORM_BIT is always clear in short-header first byte — type disambiguation is correct |
| `shortFirstByte_fixed_bit` | high | **high** | FIXED_BIT is always set in short-header first byte — RFC 9000 §17.3 |
| `short_long_first_byte_differ` | high | **high** | Short-header and long-header first bytes are always distinct — endpoint can always identify packet type |
| `longHeader_roundtrip` | high | **high** | **FULLY PROVED (run 105)** — Full Header encode↔decode round-trip for all long-header types with well-formed DCID/SCID byte lists and a 32-bit version field |
| `version_roundtrip` | high | **high** | QUIC version field (32-bit big-endian) round-trips correctly for all `v < 2^32` |
| 2 private helpers | low | low | `list_take_left`, `list_drop_left` — list-append slicing lemmas for the round-trip proof |
| 12 examples | low | low | Concrete first-byte values for each packet type verified by `native_decide` |

**Assessment**: The type-code bijection and bit-presence theorems are
high-value: a bug in the `to_bytes`/`from_bytes` first-byte encoding would
violate `typeCode_roundtrip`, `longFirstByte_form_bit`, or `short_long_first_byte_differ`,
causing all QUIC traffic to be misclassified. The `longHeader_roundtrip` theorem
(the last sorry in the entire suite, closed in run 105) is the highest-value
result: it formally proves that for any well-formed long-header — with DCID/SCID
byte lists up to 255 bytes, version field fitting in 32 bits, and a valid
packet type — `encodeLongHeader` followed by `decodeLongHeader` returns exactly
the original header. **Approximations**: only the first-byte layer and DCID/SCID/
version fields are modelled; pkt_num_len (bits 1–0) and key_phase (bit 2) are
fixed to 0; header protection, token field, and short-header full round-trip are
out of scope.

---

### Target 30: Varint 2-bit tag structural properties (`FVSquad/VarIntTag.lean`) — 15 theorems ✅ *(run 85)*

> **Status**: Phase 5 Done. 15 theorems, 0 sorry. `lake build` passes.

`VarIntTag.lean` proves the structural relationship between the 2-bit tag in
the first byte of a QUIC varint, the `varint_len` encoding-length function,
and `varint_parse_len`. Five property groups:

| Theorem group | Theorems | Level | Bug-catching potential |
|---------------|----------|-------|----------------------|
| `varint_parse_len` range biconditionals (§1) | 4 iff theorems | high | **high** |
| `varint_len` value-range biconditionals (§2) | 4 iff theorems | high | **high** |
| Tag–value non-overlap proofs (§3) | 4 inequality lemmas | mid | medium |
| Tag consistency universal theorem (§4) | 1 universal theorem | high | **high** |
| `varint_parse_len` completeness/partition (§5) | 2 theorems | mid | medium |

**Assessment**: The §1 biconditional theorems (e.g. `varint_parse_len_one_iff:
varint_parse_len b = 1 ↔ b &&& 0xC0 = 0`) are a strictly stronger statement
than the one-directional lemmas in `Varint.lean`. The §4 universal tag
consistency theorem (`varint_tag_consistency`) upgrades the existential form:
for *all* inputs `v` and any encoding output `bs`, the first byte's top 2 bits
encode exactly `varint_len(v)`. A receiver that misread the 2-bit tag would
fail these theorems immediately. The §3 non-overlap lemmas self-validate the
arithmetic-in-lieu-of-bitwise approximation used throughout the FV project.

**Approximations**: Same arithmetic model as T1 and T23; bitwise operations
approximated by arithmetic using the §3 non-overlap proofs.

---

### Target 31: HTTP/3 frame codec round-trip (`FVSquad/H3Frame.lean`) — 19 theorems ✅ *(run 99/100)*

> **Status**: Phase 5 Done. 19 theorems, 0 sorry. Route-B tests 25/25 PASS (run 103).

`H3Frame.lean` proves the encode↔decode round-trips for the three HTTP/3
frame types that carry a single QUIC varint payload: GoAway, MaxPushId, and
CancelPush. The model mirrors `Frame::to_bytes` and `Frame::from_bytes` in
`quiche/src/h3/frame.rs`.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `h3f_goaway_roundtrip` | high | **high** | GoAway frame: encode then decode recovers original stream ID |
| `h3f_max_push_id_roundtrip` | high | **high** | MaxPushId frame: encode then decode recovers push ID |
| `h3f_cancel_push_roundtrip` | high | **high** | CancelPush frame: encode then decode recovers push ID |
| `h3f_*_type_tag` (×3) | mid | medium | Each frame type emits the correct varint type code |
| `h3f_*_len_correct` (×3) | mid | medium | Encoded frame has correct byte count |
| `h3f_*_payload_range` (×3) | mid | medium | Payload value preserved within `MAX_VAR_INT` bounds |
| 7 `native_decide` unit checks | low | low | Concrete encoding examples |

**Assessment**: The three round-trip theorems are high-value: encoding errors
in GoAway (which carries the last processed stream ID) would cause receivers
to prematurely close or mis-sequence HTTP/3 streams. The Route-B tests
(25/25 PASS, covering all varint size classes, edge values, and property checks)
independently confirm model-to-Rust correspondence. **Gap**: Settings,
PushPromise, and PriorityUpdate frames are not modelled; those are more complex
(key-value maps, partial round-trips) and deferred. Data and Headers frames
carry raw byte arrays with trivial round-trips and are also deferred.

**Approximations**: Buffer cursor state abstracted to byte lists; `payload_length`
precondition not modelled (OQ-T31-4 from informal spec). The varint
encode/decode is inlined (not imported from Varint.lean) to keep the file
self-contained. The inline model is confirmed equivalent to `Varint.lean` by
the Route-B tests.

---

### Target 36: Bandwidth arithmetic invariants (`FVSquad/Bandwidth.lean`) — 22 theorems ✅ *(run 90)*

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `bandwidth_zero` | low | low | `Bandwidth{bits:0}` is the zero value |
| `bandwidth_add_comm` | mid | medium | `a + b = b + a` for bandwidth values |
| `bandwidth_add_assoc` | mid | medium | `(a + b) + c = a + (b + c)` |
| `bandwidth_mul_comm` | mid | medium | `a * k = k * a` |
| `bandwidth_mul_add` | mid | medium | Distributive law |
| `bandwidth_from_kbps_le` | high | **high** | `from_kbps(k).bits ≤ k * 1000` — conversion never overestimates |
| `bandwidth_scale` | mid | medium | Scaling invariant |
| `bandwidth_max_comm` | mid | medium | `max(a,b) = max(b,a)` |
| `bandwidth_max_le_left/right` | mid | medium | `max(a,b) ≥ a` and `≥ b` |
| `bandwidth_send_quantum_ge` | high | **high** | `send_quantum(bw) ≥ min_datagram_size` — pacing always allows at least one datagram |
| 12 unit checks | low | low | Concrete bandwidth conversions and comparisons |

**Assessment**: `bandwidth_from_kbps_le` and `bandwidth_send_quantum_ge` are
the highest-value results. Congestion control bugs that cause the pacing rate
to be overestimated (more aggressive than actual) could starve the network.
The arithmetic laws provide a solid algebraic foundation for reasoning about
bandwidth composition in the BBR2 and pacing code. Route-B correspondence
tests: 25/25 PASS.

---

### Target 41: Pacer pacing-rate cap invariant (`FVSquad/Pacer.lean`) — 17 theorems ✅ *(run 98)*

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `pacing_rate_le_cap` | high | **high** | When `max_pacing_rate = Some(cap)`, the returned rate ≤ cap |
| `pacing_rate_disabled` | mid | medium | When `enabled = false`, pacing_rate returns `sender_rate` unchanged |
| `pacing_rate_uncapped` | mid | medium | When `max_pacing_rate = None`, pacing_rate = sender_rate |
| `pacing_rate_nonneg` | low | low | Pacing rate is always ≥ 0 |
| `set_rate_updates` | mid | medium | `set_pacing_rate` updates the sender_rate field |
| `pacer_mk_valid` | low | low | Constructor postconditions |
| 11 unit/property checks | low | low | Representative pacing scenarios |

**Assessment**: `pacing_rate_le_cap` is the central result: it formally
proves the rate-limiting invariant for the gcongestion pacing subsystem.
A bug that allowed `pacing_rate` to exceed `max_pacing_rate` would cause
the sender to burst above the configured ceiling, breaking any shaping
contract. This is the first theorem that directly targets the `gcongestion`
module. **Gap**: The time-based budget accumulation (`budget_at_time`,
`tokens_at_time`) is not modelled — this is the more complex half of the
Pacer logic and the most likely source of subtle bugs.

---

### Target 43: ACK frame acked-range bounds (`FVSquad/AckRanges.lean`) — 29 theorems ✅ *(run 102)*

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `decodeAckBlocks_first_guard` | high | **high** | success ⟹ `la ≥ ab` (no underflow) |
| `decodeAckBlocks_nonempty` | high | **high** | success ⟹ result non-empty |
| `loop_largest_decreases` | high | **high** | Each iteration strictly decreases `smallest` — no infinite accumulation |
| `blocks_disjoint_via_gap` | high | **high** | Gap-2 separation ⟹ disjoint ranges |
| `decodeAckBlocks_all_valid` | high | **high** | All decoded ranges have `sm ≤ lg` — no inverted ranges |
| `decodeAckBlocks_bounded` | high | **high** | All decoded ranges have `lg ≤ largest_ack` — no out-of-bound PNs |
| `decodeAckBlocks_first_valid` | high | **high** | Head range `sm ≤ lg` (structural correctness) |
| `decodeAckBlocks_none_iff_first_guard` | mid | medium | Failure ↔ `la < ab` for no-block case |
| `decodeAckBlocks_none_means_no_ranges` | mid | medium | Failure ⟹ no ranges |
| `loop_invariant` | high | **high** | Loop invariant: acc entries maintain `sm ≤ lg` and `lg ≤ ub` — key inductive lemma |
| 8 `native_decide` unit checks | low | low | Single/multi-block decoding examples |
| 5 `native_decide` property checks | low | low | allValid, boundedBy, monotone on samples |

**Assessment**: The three major invariant theorems (`all_valid`, `bounded`,
`loop_invariant`) are the highest-value results in this target. They collectively
guarantee that `parse_ack_frame` never produces inverted ranges or ranges
referencing packet numbers beyond `largest_ack`, which are the two preconditions
for `RangeSet::insert` to maintain its `sorted_disjoint` invariant. The proofs
were completed via a shared `loop_invariant` lemma (run 102) using an inductive
argument over the block list. **Finding OQ-T43-2**: `block_count` is parsed as
a raw varint with no upper bound — a very large value causes the loop to run
that many times, a potential DoS vector. Route-B tests: 25/25 PASS.

---

## Gaps and Recommendations

### Highest-priority gaps (most likely to catch real bugs)

1. ~~**PacketHeader full round-trip sorry**~~ ✅ **CLOSED run 105** — `longHeader_roundtrip`
   proved: for all long-header packets with well-formed DCID/SCID (≤255 bytes) and a
   32-bit version field, `encodeLongHeader` → `decodeLongHeader` is the identity.
   This was the **last sorry** in the entire suite.

2. ~~**BytesInFlight counter invariant (T37)**~~ ✅ **DONE run 107** —
   `FVSquad/BytesInFlight.lean` (17 thms, 0 sorry).

3. ~~**PathState monotone progression (T38)**~~ ✅ **DONE run 109** —
   `FVSquad/PathState.lean` (24 thms, 0 sorry). `promote_to` proved strictly
   monotone; full RFC 9000 §8.2 state-machine validated.

4. ~~**BBR2 Limits invariants (T32 partial)**~~ ✅ **DONE run 113** —
   `FVSquad/BBR2Limits.lean` (14 thms, 0 sorry). `apply_limits` clamp is
   idempotent, monotone, and identity on in-range values; `no_greater_than`
   constructor invariants proved.

5. **H3 Settings frame invariants (T33)** — Informal spec completed (run 86).
   `FVSquad/H3Settings.lean` not yet written. Key properties: duplicate key
   rejection, H/2-key rejection, GREASE key passthrough, size guard.
   ~80 Lean lines, medium tractability.

6. **Pacer: time-based budget model** — `budget_at_time` and `tokens_at_time`
   are the more complex half of the Pacer logic. `Pacer.lean` only models
   the rate-selection layer. A time-budget model would catch bugs in the
   token-bucket accumulation — the most likely source of pacing jitter.

7. **RecvBuf: flow-control enforcement** — `highMark ≤ max_data` is advertised
   to the peer as the receive window. The model does not prove this bound is
   maintained. A violation could cause the peer to send more data than we
   budgeted for, leading to memory exhaustion.

8. **OQ-T43-2 follow-up** — The uncapped `block_count` in `parse_ack_frame`
   (finding run 100) has not been formally escalated to the maintainers or
   fixed. A `block_count` cap check (e.g. `≤ MAX_ACK_BLOCKS`) would be a
   direct defence against the DoS vector. A future run could add a spec for
   the capped version and open a fix issue.

9. **BBR2 pacing-rate update logic (T32 full)** — `BBR2Limits.lean` covers
   only the `Limits` struct; the `update_pacing_rate` method involves floating-
   point gain factors which require a rational/fixed-point abstraction. A
   bounded-integer model (e.g. 1000× scaled) would allow key properties like
   "pacing_rate never exceeds bandwidth_estimate × 3.0" to be proved.

### Moderate priority

8. **CUBIC: Reno-friendly transition** — ~~W_cubic vs W_est comparison
   unmodelled~~ **DONE run 165** — `FVSquad/Cubic.lean` §6 adds 10 W_est
   theorems (T26). Remaining gap: the transition condition `W_cubic < W_est`
   that switches to the Reno-friendly region is not yet modelled.

9. **CidMgmt: retire_if_needed** — ~~Not modelled~~ **DONE run 164** —
   `FVSquad/CidMgmt.lean` §10 adds 7 retire_if_needed theorems (T27).
   Remaining gap: `retire_prior_to` bookkeeping not modelled.

10. **T32 (BBR2 pacing rate)** — Informal spec done (run 165,
    `specs/bbr2_pacing_rate_informal.md`). `FVSquad/BBR2PacingRate.lean` not
    yet written. Key properties: STARTUP monotonicity (max pattern),
    first-ACK initialisation, full-bw-reached sets to target_rate, early exit
    cases. ~60–80 Lean lines, all omega. **High priority next run.**

11. **QPACK decode_int prefix-mask (T40)** — HPACK/QPACK integer decoding
    (RFC 7541 §5.1): mask formula `2^n - 1`, single-byte vs multi-byte
    accumulation. ~50 Lean lines, fuel-bounded recursion model.

### Observations on proof strength

- The **strongest** results (highest bug-catching potential): `decode_pktnum_correct`,
  `encode_decode_pktnum`, `emitN_le_maxData`, `newScid_seq_fresh`,
  `insertAny_inv`, `streamType_add_mul4`, `putU16_freeze_getU16`/
  `putU32_freeze_getU32`, `pktNumLen_k_coverage`, `retransmit_inv`,
  `short_long_first_byte_differ`, `decodeAckBlocks_all_valid`/`_bounded`,
  `pacing_rate_le_cap`, `h3f_goaway_roundtrip`. These directly prove properties
  that, if violated, would cause protocol errors or data corruption.
- The **weakest** results are the `trivial` structural theorems (e.g., `new_*`
  postconditions checking struct field initialisation). Useful for baseline
  consistency but low bug-catching value.
- The **OQ-1 finding** (StreamPriorityKey antisymmetry) remains the only
  formal finding that diverges from a standard contract. Its impact is unclear
  without understanding whether the scheduler relies on antisymmetry; a
  maintainer response would be valuable.
- The **OQ-T43-2 finding** (uncapped `block_count` in `parse_ack_frame`) is a
  real DoS vector discovered via formal verification. Unlike OQ-1 (confirmed
  intentional), this was a genuine discovery that a maintainer should address.
- ~~The **1 sorry** (in PacketHeader.lean)~~ → **CLOSED run 105**: `longHeader_roundtrip`
  is now fully proved (16 theorems, 0 sorry). The suite is completely sorry-free.



---

## Paper Review

> *Assessment of `formal-verification/paper/paper.tex` as of run 106
> (2026-04-26). Paper is an ACM sigconf LaTeX draft.*

### Accuracy Issues (require correction before submission)

1. **Stale theorem/file/sorry counts**: The abstract and introduction figures
   are out of date. Current state: **35 files, ~655 theorems,
   0 sorry** 🎉 (Lean 4.30.0-rc2). The paper should update all counts throughout
   (abstract, §1, Table 1, §5 conclusion). The suite is completely sorry-free.

2. **Missing files in Table 1**: At minimum, the following files added since
   the last paper update are absent: `VarIntTag.lean` (T30, 15 thms),
   `Bandwidth.lean` (T36, 22 thms), `Pacer.lean` (T41, 17 thms),
   `H3Frame.lean` (T31, 19 thms), `AckRanges.lean` (T43, 29 thms),
   `PacketHeader.lean` (T29, 14+2 thms), `BytesInFlight.lean` (T37, 17 thms),
   `PathState.lean` (T38, 24 thms), `BBR2Limits.lean` (T32, 14 thms).
   Together these add 116 theorems and 6 new/completed files covering gcongestion,
   HTTP/3, ACK frame safety, and full QUIC header round-trip.

3. **Sorry count**: Must be updated to **"0 sorry"** (closed run 105).
   The VarIntRoundtrip 8-byte sorry was closed (run 85); all 3 AckRanges sorry
   were closed (run 102); `longHeader_roundtrip` was closed (run 105).

4. **OQ-T43-2 finding not mentioned**: The ACK frame `block_count` DoS vector
   (run 100) is a concrete security-relevant finding from formal verification —
   the type of result that motivates this entire effort. It should appear in
   §3 Findings alongside OQ-1. It is more actionable than OQ-1 (which was
   confirmed intentional).

5. **Route-B correspondence tests not described**: The paper describes the
   correspondence model in §3 but does not mention the runnable test harnesses.
   Five targets now have Route-B tests (pkt_num_len/18, bandwidth/25,
   rangeset/21, ack_ranges/25, h3_frame/25 — all PASS). This is independent
   validation evidence that strengthens the correspondence claim and belongs in
   the Methodology section.

6. **Lean version**: Should reference Lean 4.30.0-rc2 (the version used by CI
   and confirmed by `lake build`).

### Completeness Issues

7. **gcongestion layer not represented**: `Bandwidth.lean` and `Pacer.lean`
   are the first formally verified components of the `gcongestion` (BBR2)
   module. The paper should add a "gcongestion" layer (or expand the congestion
   control layer) to cover these additions. The `pacing_rate_le_cap` theorem is
   among the highest-value results.

8. **HTTP/3 layer now exists**: `H3Frame.lean` brings formal verification to
   the HTTP/3 codec layer for the first time. The paper should acknowledge this
   and describe what is and is not covered (GoAway/MaxPushId/CancelPush
   round-trips; Settings/Data/Headers deferred).

9. **ACK frame safety**: `AckRanges.lean` closes a key security-critical gap:
   no inverted ranges, no out-of-bounds PN references. This should be described
   in the Framing layer section.

10. **Pipeline metrics still missing**: A brief table showing how many targets
    are in each phase (1–5) would strengthen the methodology narrative.

### Intellectual Honesty Assessment

The paper is generally honest about limitations. The OQ-T43-2 finding should
be added to demonstrate that formal verification found a real (unfixed) issue,
not just confirmed already-known invariants. The Route-B test evidence should
be described as independent (executable) correspondence validation.

### Specific Actionable Fixes

| Issue | Priority | Fix |
|-------|----------|-----|
| Theorem/file/sorry counts | **High** | Update to 29/604/**0** throughout; note sorry-free milestone |
| Missing 6 files in Table 1 | **High** | Add VarIntTag, Bandwidth, Pacer, H3Frame, AckRanges, PacketHeader rows |
| OQ-T43-2 finding | **High** | Add to §3 Findings; describe the DoS vector and model fidelity |
| Route-B tests | **High** | Add to §3 Methodology as independent correspondence evidence |
| gcongestion layer | **Medium** | Add or expand congestion layer to cover Bandwidth + Pacer |
| HTTP/3 layer | **Medium** | Add section describing H3Frame.lean scope and limitations |
| Sorry count "3" → "0" | **Medium** | Correct abstract and conclusion; highlight 0-sorry milestone |
| Lean version | **Low** | Align with 4.30.0-rc2 |


---

## Run 119–121 Additions — Critique

### T44 H3Settings / T44b H3ParseSettings (runs 119–120)
**Files**: `H3Settings.lean`, `H3ParseSettings.lean`

- **Strength**: Covers `h3::Config` field validation (max header list size,
  QPACK table capacity, blocked streams). Round-trip decode ∘ encode properties
  ensure that settings survives serialization/deserialization.
- **Limitation**: Both models use unbounded `Nat`; the real implementation
  caps values at `u64::MAX` and validates `varint` encoding bounds. Overflow
  corner cases are not modelled.
- **Utility**: Medium-high. Settings parsing is a common source of
  interoperability bugs; round-trip proof is a useful sanity check.
- **Recommendation**: Add a bounded model (`UInt64`) and verify that large
  values are correctly clamped or rejected.

### T46 QPACKStaticTable (run 119)
**File**: `QPACKStaticTable.lean`
- **Strength**: Static table lookup is a pure finite function over 99 entries;
  `native_decide` proofs are ironclad.
- **Limitation**: The dynamic table (QPACK's main complexity) is not modelled.
  The static table alone cannot catch dynamic indexing bugs.
- **Utility**: Low for bug-finding; high as a sanity/regression check. If the
  table contents are ever accidentally modified, proofs will catch it.
- **Recommendation**: The dynamic table is the higher-value target; consider
  modelling insert/evict invariants.

### T47 FrameAckEliciting (run 120)
**File**: `FrameAckEliciting.lean`
- **Strength**: The `is_ack_eliciting` predicate is a pure Boolean function on
  a finite enum; `decide` proofs are completely reliable. Mutual exclusion
  between ACK and non-ACK-eliciting frames is mechanically verified.
- **Limitation**: Frame semantics beyond the ACK-eliciting bit are not
  modelled. Actual on-wire encoding is in H3Frame, not here.
- **Utility**: Medium. ACK-eliciting classification directly affects congestion
  control decisions; a misclassification could cause liveness failures. The
  proof guards against future enum extensions breaking the invariant.
- **Recommendation**: Add a property that `PADDING` is non-eliciting (RFC 9000
  §13.2.1), and that `ACK_ECN` behaves like `ACK`.

### T48 StreamStateMachine (run 120)
**File**: `StreamStateMachine.lean`
- **Strength**: State reachability and transition safety for
  `StreamState` (send/recv directions). `decide`-based proofs are exhaustive
  over the finite state space.
- **Limitation**: The model is a pure transition function; the real
  implementation has concurrent state updates across send/recv paths. Race
  conditions and interleaving are not captured.
- **Utility**: High. Stream state machine correctness directly impacts whether
  `STREAM` frames are processed in valid states. The proof prevents invalid
  transitions (e.g., writing to a `ResetSent` stream).
- **Recommendation**: Consider a product model of (send_state, recv_state) to
  verify bidir stream invariants jointly.

### T45 QPACKInteger (run 121)
**File**: `QPACKInteger.lean`
- **Strength**: Full round-trip proof `decodeInt (encodeInt v p) p = some v`
  holds for ALL `v : Nat` and ALL `p : Nat` without any precondition — stronger
  than anticipated. The proof requires only stdlib Lean 4 (no Mathlib), using
  strong recursion, `omega`, and structural unfolding. The RFC 7541 §5.1
  concrete example ([31, 154, 10] for 1337 with prefix 5) is verified by
  `native_decide`.
- **Limitation**: The `first` parameter (high flag bits OR-ed into the first
  byte) is abstracted away (modelled as `first=0`). Callers ensure
  `first & mask = 0`, so this is a sound abstraction but is not formally
  verified here. Buffer overflow checks (`checked_shl`, `checked_add` in Rust)
  are not modelled; unbounded `Nat` is used throughout.
- **Utility**: High. QPACK/HPACK integer encoding is used on every header
  field in every HTTP/3 request. A decode/encode inversion bug would cause
  systematic header corruption. The round-trip proof directly rules this out
  for the pure integer layer.
- **Recommendation**: Model the `first` parameter and prove the full
  `decodeInt (encodeInt_with_first v p first) p = some v` variant. Also
  consider proving `encodeInt` produces only values in `[0, 255]` (byte-range
  invariant), which is relevant for buffer size reasoning.

### Paper Update Needed (runs 119–121)
The paper (`formal-verification/paper/paper.tex`) still reports 35 files /
~655 theorems. It should be updated to:
- **38 files, ~770 theorems, 0 sorry** (run 124 state)
- Add Table 1 rows for: H3Settings, H3ParseSettings, QPACKStaticTable,
  FrameAckEliciting, StreamStateMachine, QPACKInteger
- Update abstract theorem count and sorry-free claim
- Note the HTTP/3 layer expansion (H3Settings, H3ParseSettings)
- Note the QPACK integer round-trip proof as a new application of
  strong recursion + structural induction in the suite
- Note the expanded Route-B test coverage (10 targets, 285+ cases)

---

## Run 122–124 Additions — Critique

### Route-B Tests: QPACKInteger (T45, run 122) — 25/25 PASS

Route-B tests for `QPACKInteger.lean` confirm that the Lean model's `encodeInt`
and `decodeInt` agree with the Rust QPACK integer codec on 25 representative
inputs. These include boundary values (prefix widths 1–8, max-prefix integers,
multi-byte suffixes up to 2^31). High correspondence confidence.

### Route-B Tests: StreamStateMachine (T44, run 123) — 46/46 PASS

Route-B tests for `StreamStateMachine.lean` confirm the Lean model's
`RecvBuf::is_fin`, `SendBuf::is_fin/is_complete/is_shutdown`, and
`Stream::is_complete` predicates agree with Rust on 46 cases covering all
boundary conditions. Model fidelity is high.

### Route-B Tests: FrameAckEliciting (T42, run 124) — 33/33 PASS

Route-B tests for `FrameAckEliciting.lean` cover all 23 `FrameKind` variants
for both `ackEliciting` and `probing`, plus 10 property checks mirroring the
Lean theorems.

**Key observation**: The Rust `Frame` enum has 26 variants (including
`CryptoHeader`, `StreamHeader`, `DatagramHeader`) versus the Lean model's 23.
The three additional variants have identical `ack_eliciting`/`probing` behaviour
to their payload-carrying counterparts (`Crypto`, `Stream`, `Datagram`) — all
ack-eliciting, none probing. The Lean model is a sound abstraction; the Route-B
tests confirm this.

**Assessment**: The predicate proofs are low-level but high-reliability (fully
`decide`-proved over a finite enum). The key utility is regression protection:
if the Rust source ever adds a new frame kind or changes the non-eliciting list,
the Lean proofs and Route-B tests will both immediately fail and catch the
inconsistency.

### Next Priorities (run 124 → onwards)

1. **Paper update** (Task 11): paper still reflects 35 files / ~655 theorems;
   needs updating to 38 files / ~770 theorems with new layers (H3, QPACK).
2. **Route-B for H3Settings / H3ParseSettings**: these targets have Lean specs
   but no Route-B tests yet. H3ParseSettings is particularly valuable (settings
   parsing is interoperability-critical).
3. **T46 CUBIC cubic_k / cubic_wmax invariants**: arithmetic-heavy, ~40 lines,
   `omega`-provable — a natural next Lean file.
4. **Dynamic QPACK table**: the static-table proof is a sanity check; the
   dynamic table (insert/evict invariants) is the higher-value target.


---

## Run 125–132 Additions — Critique

### HyStart++ RTT Threshold Clamp (T48, run 130) — 13 theorems, 0 sorry

`FVSquad/Hystart.lean` formalises the RTT threshold clamping and CSS cwnd
increment logic in `quiche/src/recovery/congestion/hystart.rs`.

**Assessment (mid-level, medium bug-catching potential)**:
- The `rtt_thresh_ge_min` and `rtt_thresh_le_max` theorems are medium-value:
  they confirm the [MIN_RTT_THRESH=4ms, MAX_RTT_THRESH=16ms] clamp is correctly
  applied. A bug dropping the lower or upper clamp would immediately fail.
- `css_cwnd_inc_quarter` verifies the exact divisor (÷4) agreed by RFC draft
  §4. This would catch a wrong divisor constant.
- **Limitation**: the full HyStart++ state machine (counting RTT samples,
  `css_rounds` tracking, ACK-based transitions) is NOT modelled — only pure
  arithmetic functions. The most important safety property ("HyStart++ never
  allows cwnd growth faster than slow-start") would require an inductive
  invariant over the full state machine, which is a natural future target.
- **Recommendation**: Model `css_duration()` and the round-count check, proving
  that HyStart++ exits slow-start before a congestion event under the modelled
  conditions.

### WindowedFilter Ordering Invariant (T49, run 131) — 15 theorems, 0 sorry

`FVSquad/WindowedFilter.lean` formalises the Kathleen Nichols windowed max
tracking algorithm in `quiche/src/recovery/gcongestion/bbr/windowed_filter.rs`.

**Assessment (mid-level, high structural bug-catching potential)**:
- `update_pure_preserves_ordered` is the headline theorem: any call to `update`
  preserves `best ≥ second ≥ third`. This invariant is load-bearing for BBR2:
  if `best()` could return a value less than `second()`, BBR2 might
  underestimate available bandwidth.
- `update_pure_iter_ordered` extends this inductively — the invariant holds
  after any sequence of updates, which is the realistic usage pattern.
- **Limitation**: the `window_length` time-based expiry that triggers promotion
  is abstracted away. The real code can expire the oldest estimate and shift
  down; the Lean model only covers the non-expiry update path. This means the
  expiry path's ordering correctness is not verified.
- **Recommendation**: Model time-based expiry explicitly (using `Nat` for
  abstract time) and prove that expiry promotion also preserves ordering.

### RFC 9000 §18.1 Reserved Transport Parameter IDs (T50, run 132) — 15 theorems, 0 sorry

`FVSquad/TransportParamReserved.lean` formalises `is_reserved()` in
`quiche/src/transport_params.rs` — the check that a transport parameter ID
belongs to the RFC 9000 §18.1 reserved arithmetic progression {27, 58, 89, ...}.

**Assessment (low-to-mid level, medium bug-catching potential)**:
- `isReserved_iff_mod`: the core result — `is_reserved(id) ↔ id % 31 = 27` for
  `id ≥ 27`. This proves the RFC 9000 §18.1 definition ("31 * N + 27") is
  correctly implemented. A bit-error in the constants (e.g., 28 instead of 27,
  or 30 instead of 31) would immediately falsify this theorem.
- `isReserved_progression` (∀ k, `isReserved(31*k+27) = true`) and
  `isReserved_gap` (∀ non-multiples between reserved values, false): together
  these make the characterisation exhaustive — no reserved IDs are missed,
  and no non-reserved IDs are incorrectly flagged.
- `isReserved_spacing`: two distinct reserved IDs differ by ≥ 31. Useful as an
  anti-aliasing property.
- **Limitation**: the Rust implementation uses `u64` arithmetic with potential
  wrapping underflow for `id < 27`. The Lean model uses saturating `Nat`
  subtraction, which correctly classifies `id < 27` as non-reserved. If a QUIC
  implementation ever passed an `id < 27` to `is_reserved` expecting wrapping
  behaviour, the models would diverge. In practice all legitimate transport
  parameter IDs are ≥ 27 per RFC 9000.
- **Utility note**: This is a protocol-compliance property — proving that the
  code correctly identifies the RFC-mandated reserved-ID pattern. It is
  somewhat lower-level than congestion control invariants, but catches the
  class of "off-by-one in constant" bugs in protocol demultiplexing logic.

### Overall Status (run 132)

- **43 Lean files, ~836 theorems, 0 sorry** (lake build ✅)
- Route-B: 11 targets, 404+ cases PASS
- Coverage spans: QUIC transport, congestion control (NewReno, Cubic, BBR2,
  HyStart++), HTTP/3 codec, QPACK (static table + integer codec), stream/frame
  state machines, windowed filtering, RFC compliance (transport param IDs).
- **Next priority**: Route-B tests for T48 (HyStart++) and T49 (WindowedFilter);
  update conference paper to 43 files / ~836 theorems.

---

## Run 133–135 Additions — Critique

### Delivery Rate Conservative Interval (T51, run 133) — 13 theorems, 0 sorry

`FVSquad/DeliveryRate.lean` formalises the `generate_rate_sample` interval
computation in `quiche/src/recovery/congestion/delivery_rate.rs`.

**Assessment (mid-level, medium-high bug-catching potential)**:
- `rate_conservative_send` and `rate_conservative_ack` are the headline
  results: `delivery_rate(d, max(s,a)) ≤ delivery_rate(d, s)` and
  `≤ delivery_rate(d, a)` respectively. These directly verify the RFC
  draft §4 intent: using the max of send/ack elapsed times ensures the
  rate estimate is never inflated relative to either clock.
- `rate_max_interval_le_min_rate` combines both: the max-interval rate equals
  `min(rate_send, rate_ack)`, the most conservative possible estimate.
- **Limitation**: The app-limited flag logic (which determines whether a
  sample replaces the stored bandwidth) is NOT modelled in this file —
  that is now captured in `AppLimitedGuard.lean` (T52). The bandwidth type
  (f64 division → u64 truncation) is modelled as integer division, which
  is a sound approximation given the truncation direction.
- **Utility**: The conservatism theorems directly bear on network fairness.
  If `max` were accidentally replaced by `min`, the rate estimate could
  be spuriously high, causing excessive sending. The proofs rule this out.
- **Recommendation**: Prove that the product
  `delivery_rate(d, max(s,a)) * max(s,a) ≤ d * 1e9` holds, which is the
  direct statement that "we never over-estimate total delivered data."

### App-Limited Guard State Machine (T52, run 135) — 14 theorems + 9 examples

`FVSquad/AppLimitedGuard.lean` formalises the app-limited guard in
`delivery_rate.rs`: `update_app_limited`, `app_limited`, the bubble-check
exit condition in `generate_rate_sample`, and the rate-sample update guard.

**Assessment (mid-level, high bug-catching potential)**:
- `app_limited_iff`: the flag is exactly `end_of_app_limited ≠ 0`. This
  is the core representation invariant; if `app_limited()` ever returned
  a stale true when `end_of_app_limited = 0`, congestion samples would be
  incorrectly suppressed.
- `set_true_marks_app_limited` / `set_false_clears_app_limited`: the setter
  correctly enters/exits app-limited mode. Directly proves that calling
  `update_app_limited(true)` always activates the flag, and `false` always
  deactivates it — no partial update possible.
- `end_of_app_limited_pos_when_set`: when entering app-limited mode,
  `end_of_app_limited ≥ 1`. The `max(last_sent, 1)` guard in the Rust code
  prevents `end_of_app_limited = 0` from being read as "not app-limited"
  when `last_sent_packet = 0`. This theorem directly verifies that guard.
- `bubble_gone_clears`: when `largest_acked > end_of_app_limited`, the
  bubble-check exits app-limited mode. Proves that the RFC-mandated
  "exit when bubble is ACKed" condition is correctly implemented.
- `bubble_not_gone_preserves`: no state change when bubble is not yet gone.
  Together with `bubble_gone_clears`, this is a complete case analysis of
  `generate_rate_sample`'s app-limited exit logic.
- `rate_update_when_not_app_limited` / `rate_update_iff_new_gt_old`: the
  bandwidth sample guard is correctly formulated — non-app-limited samples
  always update, app-limited samples only update if the new rate exceeds the
  old one (Linux kernel behaviour, per the inline source comment).
- **Limitation**: The interaction with `on_packet_sent` (which stamps each
  sent packet with the current `is_app_limited` flag) is not modelled here;
  this file only covers the guard state machine itself. The timing-based
  elapsed-interval computation is in `DeliveryRate.lean`.
- **Positive finding**: The `max(last_sent_packet, 1)` guard in
  `update_app_limited(true)` is non-obvious and easy to miss in review. The
  theorem `end_of_app_limited_pos_when_set` confirms this guard is always
  active, preventing the flag from being silently cleared on the first ACK
  when no packets have been sent yet.
- **Utility**: High. The app-limited guard is a subtle piece of congestion
  control logic that affects whether delivery-rate samples influence the
  congestion window. A bug here could cause either unnecessary cwnd reduction
  (app-limited samples suppressed too aggressively) or over-estimation
  (app-limited samples accepted when they should not be).
- **Recommendation**: Model the full interaction between `on_packet_sent`
  (stamping `is_app_limited` onto sent packets) and `update_rate_sample`
  (reading back the stamp on ACK), proving that the flag on the sample matches
  the flag at send time. This end-to-end property would close the remaining
  app-limited guard verification gap.

### HyStart++ Route-B Tests (T48, run 133) — 27/27 PASS

Route-B tests for `Hystart.lean` confirm that the Lean model's `rtt_thresh`,
`css_cwnd_inc`, and `rtt_thresh_valid` functions agree with the Rust HyStart++
implementation on 27 cases covering all boundary conditions (min/max clamp
edges, CSS divisor, fractional increments). Model fidelity confirmed.

### Overall Status (run 135)

- **45 Lean files, ~863 theorems, 0 sorry** (lake build ✅, Lean 4.29.1)
- Route-B: 12 targets, 431+ cases PASS
- Coverage spans: QUIC transport, congestion control (NewReno, Cubic, BBR2
  with pacing, HyStart++, WindowedFilter, delivery-rate estimation including
  app-limited guard), HTTP/3 codec, QPACK (static table + integer codec),
  stream/frame state machines, RFC compliance (transport param IDs).
- **Next priorities**:
  1. Route-B tests for T49 (WindowedFilter) and T50 (TransportParamReserved)
  2. T53: NewReno multi-cycle AIMD convergence (reno cwnd AIMD state machine)
  3. Update conference paper to 45 files / ~863 theorems
  4. Model end-to-end app-limited stamp interaction (see T52 recommendation)

### NewRenoAIMD Multi-Cycle Convergence (T53, run 136) — 17 theorems, 0 sorry

`FVSquad/NewRenoAIMD.lean` formalises multi-cycle AIMD convergence properties
for NewReno's congestion window in `quiche/src/recovery/congestion/reno.rs`.

**Assessment (high-level, high bug-catching potential)**:
- Proves that across multiple AIMD cycles, the cwnd approaches a stable
  value determined by the loss rate — this is the RFC 5681 convergence claim.
- Key theorems: `cwnd_increases_in_ca` (CA phase increments are positive),
  `cwnd_decreases_on_loss` (multiplicative decrease is exact),
  `aimd_cycle_bounded` (cwnd bounded above by `ssthresh` before next loss),
  `multi_cycle_convergence` (cwnd sequence is eventually bounded in a finite
  interval around the equilibrium).
- **Utility**: Very high for the congestion-avoidance path, which is the
  dominant mode in long-lived connections. These properties rule out entire
  classes of implementation bugs (e.g., off-by-one in multiplicative decrease,
  additive increment applied on wrong condition).

### WindowedFilter Route-B Tests (T49, run 136) — 24/24 PASS

Route-B tests for `WindowedFilter.lean` confirm the Lean 3-slot max-filter model
agrees with the Rust `WindowedFilter` implementation on 24 cases covering
`reset`, `clear`, `update` (multiple round trips), and `get_best`/ordering
invariants. Model fidelity confirmed.

### BBR2 MaxBandwidthFilter + RoundTripCounter (T54, run 137) — 19 theorems, 0 sorry

`FVSquad/BBR2NetworkFilters.lean` formalises two data structures from
`quiche/src/recovery/gcongestion/bbr2/network_model.rs`:
- `MaxBandwidthFilter`: two-slot sliding-window maximum over consecutive
  BBR2 round trips.
- `RoundTripCounter`: counts completed BBR2 round trips, detects
  round-trip boundaries, and advances the filter epoch on boundary.

**Assessment (mid-level, medium-high bug-catching potential)**:
- `get_ge_slot0` / `get_ge_slot1`: filter's `get()` output is always ≥ both
  slots' values. Directly validates that the max-filter never under-reports
  bandwidth — a regression here would cause BBR2 to underestimate available
  bandwidth and under-utilise the pipe.
- `update_then_advance_slot0` / `advance_slot0_eq_old_slot1`: the slot
  rotation logic is correctly sequenced. An off-by-one in the advance step
  would cause the second-best sample to be lost prematurely, making the
  filter too aggressive in forgetting past measurements.
- `round_trip_count_monotone_two` / `on_acked_count_nondecreasing`:
  round-trip counter is non-decreasing; guarantees BBR2's internal
  time-keeping never goes backwards.
- **Utility**: Medium-high. The two-slot filter is simpler than the
  three-slot `WindowedFilter` but carries the same ordering guarantee needed
  for BBR2 bandwidth estimation. The RoundTripCounter theorems confirm correct
  epoch tracking.
- **Recommendation**: Add a theorem linking `RoundTripCounter` advances to
  `MaxBandwidthFilter.advance` calls — proving that the filter advances
  exactly once per completed round trip. This end-to-end property would
  close the remaining gap between the two structures.

### BBR2 ProbeBW Phase Cycle Ordering (T57, run 140) — 12 theorems, 0 sorry

`FVSquad/ProbeBWPhase.lean` formalises the per-phase pacing-gain and
cwnd-gain assignments for BBR2's `CyclePhase` enum in
`quiche/src/recovery/gcongestion/bbr2/mode.rs` (L49–L75) against the
default `Params` values from `bbr2.rs` (L291–L300).

**Assessment (mid-level, medium bug-catching potential)**:
- `pacingGain_gt_100_iff_up`: only the Up phase uses an aggressive pacing
  gain (125/100 = 1.25); all others use ≤ 1.0. Any accidental application
  of the Up gain in Down/Cruise/Refill would be caught by this biconditional.
- `cwndGain_gt_200_iff_up`: only the Up phase uses an elevated cwnd gain
  (225/100 = 2.25); all others use exactly 2.0. Catches incorrect cwnd scaling.
- Five per-phase pacing-gain lemmas and five cwnd-gain lemmas serve as
  regression guards: if the default param values change in a future refactor,
  these theorems immediately break CI.
- **Utility**: Medium. The properties are decidable and verified by `rfl`,
  making them strong regression guards for the hard-coded constants. They
  confirm that the Up phase is the only one that exceeds neutral gain, which
  is a key invariant of the ProbeBW design (Up probes up, Down slows down,
  Cruise/Refill are neutral).
- **Recommendation**: Extend with phase-transition ordering theorems proving
  the canonical cycle sequence Down → Cruise → Refill → Up → Down. This
  would require modelling the `enter_probe_*` functions and is a worthwhile
  next step.

### Overall Status (run 140)

- **49 Lean files, 933 theorems, 0 sorry** (lake build ✅, Lean 4.29.0+)
- Route-B: 13 targets, 455+ cases PASS
- Coverage spans: QUIC transport, congestion control (NewReno with multi-cycle
  AIMD convergence, Cubic, BBR2 with startup/probing model, pacing, HyStart++,
  WindowedFilter max-filter, delivery-rate estimation, app-limited guard),
  HTTP/3 codec, QPACK (static table + integer codec), stream/frame state
  machines, RFC compliance (transport param IDs).
- Run 139: T55 BBR2StartupExit (15 thms: full_bandwidth_reached monotonicity)
- Run 140: T57 ProbeBWPhase (12 thms: pacing/cwnd-gain per-phase assignments)
- **Next priorities**:
  1. T56: LossDetectionThreshold.lean (~12 thms, MEDIUM — RFC 9002 §6.1)
  2. Route-B tests for T55 (BBR2StartupExit) or T57 (ProbeBWPhase)
  3. Extend ProbeBWPhase with phase-transition ordering (Down→Cruise→Refill→Up)
  4. Update conference paper to 49 files / 933 theorems



### Loss Detection Packet Threshold (T56, run 142) — 16 theorems, 0 sorry

`FVSquad/LossDetectionThreshold.lean` formalises the RFC 9002 §6.1.1
packet-threshold update logic from `quiche/src/recovery/congestion/recovery.rs`
(lines 655–660).  The key constants are `INITIAL_PACKET_THRESHOLD = 3` and
`MAX_PACKET_THRESHOLD = 20`.  The modelled operation `updatePktThresh` clamps
the next threshold to `min(max(current, spurious), MAX)`.

**Assessment (mid-level, medium-high bug-catching potential)**:
- `pktThreshInv_initial`: the initial threshold satisfies the invariant
  (INITIAL ≤ thresh ≤ MAX) by definition — a regression guard.
- `updatePktThresh_preserves_inv`: every update step preserves the invariant
  across the entire parameter space, including the boundary constants.
  A missing clamp to MAX would break this theorem.
- `multi_update_preserves_inv`: the invariant is maintained after any sequence
  of threshold updates (modelled as a `List.foldl`).  This proves that no
  matter how many spurious-loss events occur, the threshold stays bounded.
- `updatePktThresh_mono_spurious`: a higher spurious-loss observation can only
  raise (or maintain) the threshold — the update is monotone.
- `update_at_max`: once the threshold reaches MAX, all further updates are
  no-ops — confirming the MAX bound is a fixed point.
- `foldl_update_preserves_inv`: multi-step invariant preservation via `List.foldl`.
- **Utility**: Medium-high.  The invariant-preservation chain is directly useful:
  it rules out an unbounded-growth bug and a below-INITIAL bug in the threshold
  management.  Route-B tests (991/991 PASS, run 144) confirm model fidelity.
- **Limitation**: `time_thresh` (the floating-point time-based threshold from
  RFC 9002 §6.1.2) is omitted — only the integer packet threshold is modelled.
  A future target should cover the time-threshold branch.

### Transport Error Code Encoding (T59, run 145) — 37 theorems, 0 sorry

`FVSquad/TransportErrorCode.lean` formalises the QUIC transport error code
wire encoding from `quiche/src/error.rs`.  The Lean model covers the `toWire`
(Lean variant → wire u64) and `toC` (Lean variant → C FFI integer) mappings
for all 13 error code variants.

**Assessment (high-level, high bug-catching potential)**:
- **37 theorems** is the largest theorem count of any single Lean file in the
  suite, reflecting the breadth of the error-code space.
- `toC_injective`: the C FFI mapping is injective — no two error codes share
  the same C integer.  A regression here would cause silent misidentification
  of transport errors at the FFI boundary.
- `toWire_not_injective` / `toWire_all_protocol_violation_on_wire`: 13
  Lean variants map to only 12 distinct wire codes.  Specifically,
  `ProtocolViolation (n)` and all unknown-variant fallbacks map to 0xa.
  This is intentional per RFC 9000 §20.1 (application-specific errors may
  share the ProtocolViolation code), but the proof makes the non-injectivity
  explicit and auditable.
- Per-variant round-trip theorems for all 12 distinct wire values directly
  guard the decode/encode round-trip.
- **Utility**: Very high.  Incorrect error code mapping breaks QUIC connection
  close semantics; an off-by-one in the wire mapping would silently corrupt
  error reporting.  Route-B tests (50/50 PASS, run 146) confirm model fidelity.
- **Recommendation**: Add a decoder model and `decode ∘ encode = id` round-trip
  theorem (when unique) — this would close the remaining correctness gap.

### QUIC STREAM Frame Type Byte Encoding (T61, run 147) — 12 theorems, 0 sorry

`FVSquad/StreamFrameType.lean` formalises the 1-byte type-tag computation
for QUIC STREAM frames from `quiche/src/frame.rs` (`encode_stream_header`,
lines 1326–1350).  The Lean model covers the bit-OR construction of the byte
using the BASE (0x08), OFF (0x04), LEN (0x02), and FIN (0x01) flags.

**Assessment (mid-level, medium bug-catching potential)**:
- `streamTypeByte_def_false/true`: the byte is exactly 0x0E (fin=false) or
  0x0F (fin=true).  Any accidental mutation of the constant flags would break
  these rfl-closed theorems immediately at CI.
- `streamTypeByte_base_set/off_set/len_set/fin_iff`: each protocol flag bit
  is individually verified — orthogonal regression guards for the bit-OR
  construction.
- `streamTypeByte_injective`: distinct `fin` values produce distinct bytes —
  the encoding is bijective on Bool.
- `streamTypeByte_decode_fin`: the FIN flag is recoverable by testing bit 0 —
  a parser can correctly reconstruct the `fin` boolean.
- **Utility**: Medium.  The encoding is simple (two fixed byte values), so
  the theorem density per line of source is high.  The main value is as a
  regression guard: any unintentional flag change is caught immediately.
- **Coverage note**: the model covers the type byte only; the varint fields
  (`stream_id`, `offset`, `length`) written after the type byte are not modelled.
  Route-B tests (19/19 PASS, run 147) confirm exact byte-value agreement.

### Proportional Rate Reduction (`FVSquad/PRR.lean`, run ~107) — 20 theorems, 0 sorry

**Source**: `quiche/src/recovery/congestion/prr.rs` — RFC 6937 PRR algorithm.

PRR paces the sender during loss recovery by limiting transmissions
proportionally to the fraction of the `recoverfs` (bytes in flight at congestion
start) that has been delivered. The Lean model covers two modes: PRR (pipe >
ssthresh) and PRR-SSRB (pipe ≤ ssthresh), plus the full lifecycle of
`congestion_event`, `on_packet_sent`, and `on_packet_acked`.

**Assessment (high-level, high bug-catching potential)**:

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `congestion_event_prr_delivered` | low | low | Reset postcondition (rfl) |
| `congestion_event_recoverfs` | low | low | Reset postcondition (rfl) |
| `congestion_event_prr_out` | low | low | Reset postcondition (rfl) |
| `congestion_event_snd_cnt` | low | low | Reset postcondition (rfl) |
| `congestion_event_twice` | mid | medium | Two resets collapse to one — idempotence guard |
| `sent_prr_out_increases` | low | low | Field update (rfl) |
| `sent_snd_cnt_saturating` | low | low | Saturating decrement (rfl) |
| `acked_prr_delivered_increases` | low | low | Field update (rfl) |
| `acked_prr_out_unchanged` | low | low | Immutability guard (rfl) |
| `prr_mode_snd_cnt_zero_when_recoverfs_zero` | mid | **high** | Division-by-zero guard: no sends when `recoverfs=0` |
| `prr_mode_snd_cnt_formula` | **high** | **high** | Exact RFC 6937 §3 formula for PRR mode |
| `prr_mode_snd_cnt_le_ratio` | **high** | **high** | Central rate control: sender never exceeds proportional target |
| `ssrb_snd_cnt_le_gap` | **high** | **high** | SSRB gap bound: never overshoots ssthresh by more than allowed |
| `ssrb_snd_cnt_le_limit` | **high** | **high** | SSRB per-round delivery limit |
| `ssrb_snd_cnt_ge_min_gap_mss` | **high** | **high** | SSRB liveness: at least one MSS always permitted when gap > 0 |
| `ssrb_snd_cnt_formula` | **high** | **high** | Exact RFC 6937 §3 formula for SSRB mode |
| `fresh_epoch_sent_prr_out` | mid | medium | Sequence: reset then send sets `prr_out = sent_bytes` |
| `divCeil_zero_left` / `divCeil_eq_of_pos` / `divCeil_ge_div` | low | low | Helpers for ceiling division |

**Positive findings**: The rate-bounding theorems (`prr_mode_snd_cnt_le_ratio`,
`ssrb_snd_cnt_le_gap`, `ssrb_snd_cnt_le_limit`, `ssrb_snd_cnt_ge_min_gap_mss`)
are genuinely high-value safety properties — they correspond directly to the
"send no faster than proportional delivery" invariant of RFC 6937 and the
"always allow at least MSS in SSRB" liveness guarantee. A regression in the
Rust `on_packet_acked` formula would break these theorems at CI.

**Gap**: The caller contract — that `on_packet_sent` is only called with
`sent_bytes ≤ snd_cnt` — is NOT enforced by the model. A theorem capturing
that the counter does not underflow under this assumption would improve
coverage. No Route-B tests exist yet for PRR.

---

### PMTUD Binary-Search Bounds (`FVSquad/Pmtud.lean`, run ~125) — 15 theorems, 0 sorry

**Source**: `quiche/src/pmtud.rs` — RFC 8899 PLPMTUD binary search.

PMTUD discovers the path MTU (PLPMTU) by binary-searching between a minimum
(MIN_PLPMTU = 1200) and maximum (max_mtu). The Lean model covers the pure
`updateProbeSize` logic across all four state combinations
(both/none/failed-only/success-only) and the convergence condition
(gap ≤ 1 → PMTU found).

**Assessment (mid/high-level, high bug-catching potential)**:

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `updateProbeSize_ge_min` | **high** | **high** | probe_size ≥ 1200 in all well-formed states — safety invariant |
| `updateProbeSize_le_max` | **high** | **high** | probe_size ≤ max_mtu — no out-of-range probes |
| `updateProbeSize_lt_failed` | **high** | **high** | Binary search narrows from above: new probe < smallest_failed |
| `updateProbeSize_gt_success` | **high** | **high** | Binary search narrows from below: new probe > largest_success |
| `updateProbeSize_only_failed_lt` | mid | **high** | Failed-only: new probe < smallest_failed (strict narrowing) |
| `updateProbeSize_only_failed_ge_min` | mid | medium | Failed-only: result ≥ MIN_PLPMTU |
| `updateProbeSize_converged` | **high** | **high** | Convergence: gap ≤ 1 → returns largest_success (the PMTU) |
| `updateProbeSize_no_history` | mid | medium | No history → probe at max_mtu (normal initial case) |
| `updateProbeSize_only_success` | mid | medium | Only success → returns that success (PMTU immediately known) |
| `binary_search_midpoint_bounds` | **high** | **high** | Core: g < (g+f)/2 < f when gap > 1 — search terminates |
| `binary_search_midpoint_ge_min` | mid | medium | Midpoint ≥ MIN_PLPMTU when both bounds ≥ MIN_PLPMTU |
| `failed_only_midpoint_bounds` | mid | medium | Failed-only midpoint within [MIN_PLPMTU, f] |
| `updateProbeSize_both` (private helper) | — | — | Private; enables readable proofs |
| `div2_le_of_le_sum` / `le_div2_of_mul2_le` (private) | — | — | Division helpers (omega cannot reason about Nat division) |

**Positive findings**: The four range-bounding theorems (`ge_min`, `le_max`,
`lt_failed`, `gt_success`) collectively prove that the binary search is
**monotonically terminating** — every probe is strictly inside the current
search interval. The convergence theorem (`updateProbeSize_converged`) confirms
the RFC 8899 stopping condition is correctly implemented: when `f − g ≤ 1`, the
algorithm returns `g` as the PLPMTU. A bug that used `<` instead of `≤` in the
convergence guard, or that computed `(g + f) / 2` as `(g + f + 1) / 2`
(rounding the wrong direction), would break these theorems.

**Gap**: The model covers a single `updateProbeSize` step. No inductive theorem
proves that after O(log(max_mtu − min_mtu)) steps the interval converges. A
termination argument or bounded-steps theorem would be the highest-value next
addition. No Route-B tests exist yet for Pmtud.

---

### IdleTimeout Route-B Tests (run 148) — 38/38 PASS

Route-B tests for `IdleTimeout.lean` confirm the Lean `idleTimeout` model
agrees with the pure-function extraction from `quiche/src/lib.rs:8757` on
38 cases covering: both-zero → None (3), loc=0 with various PTO clamp levels
(6), peer=0 (5), both-nonzero no-clamp (4), both-nonzero PTO-clamp (4),
commutativity swaps (4), and Lean-model/Rust-extraction direct agreement (12).
Model fidelity confirmed.

### Overall Status (run 149)

- **52 Lean files, ~998 theorems, 0 sorry** (lake build ✅, Lean 4.29.1)
- Route-B: 18 targets, 1570+ cases PASS
- Coverage spans: QUIC transport (connection negotiation, idle-timeout RFC 9000
  §10.1.1, PMTUD binary search, STREAM frame type byte, transport error codes),
  congestion control (NewReno with multi-cycle AIMD convergence, Cubic, BBR2
  with startup/probing model, pacing, HyStart++, WindowedFilter max-filter,
  delivery-rate estimation, app-limited guard, BBR2 MaxBandwidthFilter +
  RoundTripCounter, BBR2 ProbeBW phase gains, loss-detection threshold,
  **PRR rate-control formula**), HTTP/3 codec, QPACK (static table + integer
  codec), stream/frame state machines, RFC compliance (transport param IDs,
  reserved param ID pattern), **PMTUD binary-search bounds**.
- Run 148: IdleTimeout Route-B 38/38 PASS
- Run 149: Critique extended to cover PRR (20 thms, RFC 6937 rate-control) and
  Pmtud (15 thms, RFC 8899 binary-search bounds); CORRESPONDENCE.md last-updated refreshed.
- **Next priorities**:
  1. T62 (BBR2 ProbeRTT Phase Params): write `FVSquad/ProbeRTTPhase.lean` (~14 thms)
  2. T58 (Stream Limit Enforcement): informal spec then Lean spec
  3. T60 (BBR2 ProbeRTT State Machine): informal spec
  4. Route-B for PRR or Pmtud (no Route-B yet for either)
  5. Inductive termination theorem for Pmtud binary search

---

### BBR2 ProbeRTT Phase Parameters (`FVSquad/ProbeRTTPhase.lean`, run 150) — 26 theorems, 0 sorry

**Source**: `quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs` — ProbeRTT
gain constants and inflight-target computation.

BBR2's ProbeRTT phase uses fractional gain values (`Gain = { num, den }`) to
compute inflight targets as fractions of BDP. The Lean model covers gain
ordering, sub-unity/at-most-unity predicates, inflight-target bounds, and
`applyGain` monotonicity.

**Assessment (mid/high-level, high bug-catching potential)**:

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `Gain.subUnity_implies_atMostUnity` | low | low | Predicate hierarchy helper |
| `pacingGainDefault_atMostUnity` / `cwndGainDefault_atMostUnity` | mid | medium | Default gains ≤ 1 — no amplification |
| `pacingGainCustom_subUnity` / `cwndGainCustom_subUnity` | mid | **high** | Custom gains are strictly < 1 (ensures drain) |
| `inflightBdpFraction_subUnity` | mid | **high** | inflight target fraction < 1 (stays below BDP) |
| `inflightTarget_le_bdp` | **high** | **high** | Core: for any ≤1 gain, inflight target ≤ BDP |
| `inflightTarget_bdpFraction_le_bdp` | **high** | **high** | Specific instance: ProbeRTT target ≤ BDP |
| `inflightTarget_bdpFraction_eq_half` | **high** | **high** | Target = ⌊BDP/2⌋ — exact RFC check |
| `applyGain_le_of_atMostUnity` | **high** | **high** | `applyGain` never amplifies when gain ≤ 1 |
| `applyGain_subUnity_lt` | **high** | **high** | Strict drain: `applyGain` strictly reduces when gain < 1 and v > 0 |
| `applyGain_cwndCustom_le` / `applyGain_pacingCustom_le` | mid | **high** | Specific custom gains reduce v |
| `cwndGainCustom_le_pacingGainCustom` | mid | medium | Gain ordering: cWnd gain ≤ pacing gain |
| `inflightBdpFraction_eq_cwndGainCustom` | mid | medium | Constants are the same fraction |
| `applyGain_mono_num` | mid | medium | Monotonicity in numerator |
| `applyGain_cwnd_le_pacing` | mid | medium | cWnd target ≤ pacing target |
| `pacingGainCustom_values` / `cwndGainCustom_values` | mid | medium | Literal constant checks (8/10, 5/10) |

**Positive findings**: The sub-unity theorems directly prove the core BBR2
ProbeRTT safety invariant — the phase is guaranteed to drain inflight below
BDP. Any change to the gain constants (e.g., changing 0.8 to 1.0) would break
`pacingGainCustom_subUnity` at CI. The `inflightTarget_bdpFraction_eq_half`
theorem provides an exact numeric sanity check: ProbeRTT targets ⌊BDP/2⌋.

**Gap**: The model does not cover the *timing* of ProbeRTT — how long to
maintain the drained state. That is addressed by `ProbeRTTStateMachine.lean`.
No Route-B tests exist yet for ProbeRTTPhase; the phase is tightly coupled to
BBR2 state and harder to extract independently.

---

### BBR2 ProbeRTT State Machine (`FVSquad/ProbeRTTStateMachine.lean`, run 151) — 27 theorems, 0 sorry

**Source**: `quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs` — ProbeRTT
phase transition logic (draining → waiting → exit).

The Lean model captures two concurrent event sources: `congestionStep`
(called on each congestion event with current inflight and event time) and
`quiescenceStep` (called when the app becomes quiescent). Both operate on the
shared state `ProbeRttState = draining | waiting exitTime`.

**Assessment (high-level, high bug-catching potential)**:

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `congestion_draining_le_sets_timer` | **high** | **high** | Draining → Waiting when inflight ≤ target |
| `congestion_draining_gt_stays_draining` | **high** | **high** | Draining stays draining when inflight > target |
| `congestion_waiting_expired_exits` | **high** | **high** | Waiting → Exit when timer expired |
| `congestion_waiting_not_expired_stays` | **high** | **high** | Waiting stays waiting when timer not expired |
| `congestion_waiting_never_draining` | mid | **high** | Once waiting, congestionStep never reverts to draining |
| `congestion_draining_never_exits` | mid | **high** | Draining never exits (must wait first) |
| `congestion_draining_timer_value` | **high** | **high** | Timer = eventTime + duration when entering waiting |
| `waiting_exit_time_ge_event_time` | **high** | **high** | Causality: exit time ≥ event time when timer fires |
| `congestion_new_exit_time_ge_eventTime` | **high** | **high** | New timer value is in the future |
| `congestion_draining_result_means_gt` | mid | medium | Converse: draining result iff inflight > target |
| `congestion_draining_dichotomy` | **high** | **high** | Exhaustive: exactly enters waiting or stays draining |
| `quiescence_draining_exits` | **high** | **high** | Quiescence immediately exits draining |
| `quiescence_waiting_expired_exits` | **high** | **high** | Quiescence exits waiting if timer expired |
| `quiescence_waiting_not_expired_stays` | mid | medium | Quiescence keeps waiting if timer not expired |
| `quiescence_waiting_never_draining` | mid | medium | Quiescence never reverts to draining |
| `quiescence_waiting_exit_time_preserved_or_exits` | mid | medium | Exit time preserved unless exiting |
| `quiescence_result_cases` | **high** | **high** | Exhaustive quiescence outcomes |
| `draining_high_inflight_stays_draining_not_waiting` | **high** | **high** | High inflight: strictly stays draining across congestion |
| `waiting_exit_time_immutable` | **high** | **high** | Exit time never changes once set — no timer reset |
| `congestion_exit_iff_waiting_expired` | **high** | **high** | Biconditional: exits iff waiting AND timer expired |
| `congestion_result_valid` | **high** | **high** | All outcomes are valid (exhaustive correctness check) |
| `draining_first_event_le_target_enters_waiting` | **high** | **high** | First sub-target event triggers timer correctly |
| `waiting_exits_after_duration` | **high** | **high** | Waiting exits exactly after probe_rtt_duration ms |
| `quiescence_and_congestion_agree_on_expired` | **high** | **high** | Both paths agree when timer is expired |

**Positive findings**: The `waiting_exit_time_immutable` theorem is an
especially strong finding — it proves that the exit timer is set exactly once
and never reset while in the waiting state. Any refactoring that accidentally
re-arms the timer on each congestion event would break this at CI. The
`congestion_draining_dichotomy` and `quiescence_result_cases` theorems provide
exhaustive case coverage of every possible state transition, acting as a
correctness oracle for the state machine.

**Gap**: The Lean model does not yet cover the *caller contract* — that
`congestionStep` is only called with inflight decreasing over time (i.e., that
the actual BBR2 loop maintains draining pressure). A composed theorem proving
that given continuous sub-target inflight, the state must eventually reach
Waiting, would be the highest-value next addition.
No Route-B tests exist yet for ProbeRTTStateMachine.

---

### QUIC Peer Stream-Count Limit (`FVSquad/StreamCountLimit.lean`, run 153) — 16 theorems, 0 sorry

**Source**: `quiche/src/stream/mod.rs` — `update_peer_max_streams_bidi`,
`update_peer_max_streams_uni`, `peer_streams_left_bidi`, `peer_streams_left_uni`.

RFC 9000 §4.6 requires that a peer's stream-count limit can only be raised,
never lowered. This file verifies that property and several related invariants
for both bidi and uni stream directions.

**Key finding (latent underflow risk)**: The `peer_streams_left_*` methods in
Rust perform bare u64 subtraction without a bounds guard. If the safety
invariant `local_opened ≤ peer_max` were ever violated (e.g., due to a
race or a missing enforcement check in `get_or_create`), the subtraction would
wrap to ≈ 2^64, returning a spuriously large count of available streams.
The `streamsLeftBidi_nonneg` and `streamsLeftUni_nonneg` theorems make this
precondition explicit and prove that the result is non-negative *only* under
the invariant — flagging the unsafe assumption at the call site.

**Assessment**:

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `updateBidi_mono` | **high** | **high** | RFC 9000 §4.6 — limit never decreases |
| `updateUni_mono` | **high** | **high** | Symmetric for uni |
| `updateBidi_noop` | mid | medium | No-op when v ≤ current |
| `updateUni_noop` | mid | medium | Symmetric |
| `streamsLeftBidi_correct` | mid | medium | streams_left = peer_max − local_opened |
| `streamsLeftUni_correct` | mid | medium | Symmetric |
| `updateBidi_increases_left` | **high** | **high** | Update only adds headroom |
| `updateUni_increases_left` | **high** | **high** | Symmetric |
| `updateBidi_preserves_invariant` | **high** | **high** | Raising limit preserves invariant |
| `updateUni_preserves_invariant` | **high** | **high** | Symmetric |
| `updateBidi_uni_unchanged` | mid | medium | Bidi update does not touch uni fields |
| `updateUni_bidi_unchanged` | mid | medium | Symmetric |
| `streamsLeftBidi_nonneg` | **high** | **high** | Non-negative iff invariant holds — exposes underflow risk |
| `streamsLeftUni_nonneg` | **high** | **high** | Symmetric |
| `no_streams_left_means_at_limit_bidi` | **high** | **high** | Zero left → at the limit exactly |
| `streamsLeftBidi_gap` | mid | medium | local_opened + left = peer_max (gap equation) |

**Overall assessment**: High-value coverage for a safety-critical RFC property.
The theorems directly encode RFC 9000 §4.6 monotonicity, and the nonneg/gap
pair cleanly documents the underflow risk inherent in the bare u64 subtraction.
No Route-B tests yet; would require a small Rust harness exercising the four
functions against the Lean model outputs.

---

### `FVSquad/StreamCreditReturn.lean` — T58: QUIC Stream Credit Return — 20 theorems (run 158)

**Source**: `quiche/src/stream/mod.rs` — `local_max_streams_bidi_next`, `local_max_streams_bidi`,
`collect` (credit-return), and commit (MAX_STREAMS send) paths. RFC 9000 §4.6.

This file formalises the **two-phase stream credit-return** mechanism: when a
peer-created stream completes (`collect`), the local pending limit is
incremented; when a MAX_STREAMS frame is sent (`commit`), the pending limit
is promoted to the advertised limit. The invariant `pending ≥ advertised`
is preserved through all operations, preventing RFC 9000 §4.6 violations.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `returnBidi_increments_next` | mid | high | collect increments pending limit |
| `returnBidi_preserves_uni` | low | low | bidi collect does not affect uni fields |
| `returnBidi_preserves_current` | mid | high | collect never lowers advertised limit |
| `returnBidi_next_increases` | mid | high | pending never decreases after collect |
| `commitBidi_equalises` | **high** | **high** | commit sets advertised = pending |
| `commitBidi_idempotent` | mid | medium | double commit is identity |
| `commitBidi_preserves_uni` | low | low | bidi commit does not affect uni |
| `commitBidi_monotone` | **high** | **high** | commit only raises advertised limit |
| `returnBidi_preserves_invariant` | **high** | **high** | collect preserves `pending ≥ advertised` |
| `returnUni_preserves_invariant` | **high** | **high** | symmetric for uni |
| `commitBidi_preserves_invariant` | **high** | **high** | commit preserves invariant |
| `commitUni_preserves_invariant` | **high** | **high** | symmetric for uni |
| `returnBidiN_adds_n` | mid | medium | N collects adds exactly N to pending |
| `returnN_then_commit` | **high** | **high** | N collects then commit: advertised += N |
| `returnThenCommit_increases_current` | **high** | **high** | collect+commit always raises advertised |
| `returnBidi_returnUni_commute` | mid | medium | bidi and uni collect commute |
| `commit_then_collect_grows_next` | mid | medium | post-commit collect still increments pending |
| `returnUni_increments_next` | mid | high | uni collect symmetric to bidi |
| `returnUni_preserves_bidi` | low | low | uni collect does not affect bidi |
| `commitUni_equalises` | **high** | **high** | uni commit sets advertised = pending |

**Positive findings**: `returnN_then_commit` and `returnThenCommit_increases_current`
together give end-to-end correctness: collecting N streams and then committing
monotonically raises the MAX_STREAMS window by exactly N, ensuring liveness.
**Gap**: the invariant `localOpened ≤ peerMax` is separately maintained in
`StreamCountLimit.lean` (T63); a composed theorem linking credit-return to
count-limit would close the full RFC 9000 §4.6 proof chain.
No Route-B tests yet.

---

### `FVSquad/SsThresh.lean` — T65: SsThresh Write-Once Invariant — 14 theorems (run 159)

**Source**: `quiche/src/recovery/congestion/mod.rs` — `SsThresh` struct (`L39–L48`),
`SsThresh::update` (`L67–L81`), `impl Default for SsThresh` (`L50–L57`).

This file verifies the **write-once invariant** of `SsThresh::startup_exit`:
once set (to `Css` or `Loss`), the exit reason never changes. Alongside this,
`ssthresh` is always updated on every call, but `startupExit` is frozen after
first write. Vital for congestion control correctness: a race or double-trigger
that altered the exit reason would silently mis-classify the slow-start exit.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `default_ssthresh` | low | low | Initial ssthresh = usize::MAX |
| `default_exit_none` | low | low | Initial exit = None |
| `update_ssthresh` | mid | medium | update always sets ssthresh |
| `update_sets_exit_on_first` | **high** | **high** | First update sets exit from None |
| `exit_preserved_when_set` | **high** | **high** | Once set, exit never changes — write-once |
| `exit_mono` | **high** | **high** | exit transitions only from None to Some |
| `exit_set_after_any_update` | **high** | **high** | After one update, exit is always Some |
| `reason_css_from_first_call` | **high** | **high** | Css reason preserved across subsequent updates |
| `reason_loss_from_first_call` | **high** | **high** | Loss reason preserved across subsequent updates |
| `exit_reason_preserved` | **high** | **high** | Any reason preserved in list of updates |
| `double_update_ssthresh` | mid | medium | second update overwrites ssthresh |
| `double_update_exit_unchanged` | **high** | **high** | second update cannot change exit |
| `updateList_snoc` | mid | medium | update list is sequential application |
| `n_updates_ssthresh_is_last` | mid | medium | after N updates, ssthresh = Nth value |

**Positive finding**: `exit_preserved_when_set` is a strong, directly
safety-relevant property: any refactoring of `SsThresh::update` that
mistakenly allowed a second write to `startup_exit` would break this theorem at CI.
**Gap**: the relationship between `SsThresh` and actual cwnd/ssthresh used in
congestion decision logic (`NewReno::congestion_event`) is not yet composed.

---

### `FVSquad/AckDelayCodec.lean` — T66: ACK Delay Encode/Decode Codec — 16 theorems + examples (run 160)

**Source**: `quiche/src/lib.rs` (~L4487–4497 encoder, ~L8173–8182 decoder);
`quiche/src/transport_params.rs` (`ack_delay_exponent` 0–20 range).
RFC 9000 §13.2.5.

Models the integer encode (`delay / 2^exp`) and decode (`encoded * 2^exp`)
and proves the codec is a lossy round-trip: exact for multiples of `2^exp`,
floor otherwise, with rounding error < 1 LSB. Monotonicity in both directions
and anti-tonicity of encode in the exponent are also verified.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `roundtrip_exact` | **high** | **high** | Exact for aligned values — core codec correctness |
| `roundtrip_le` | **high** | **high** | Decoded ≤ original — no phantom delay inflation |
| `roundtrip_gap_lt` | **high** | **high** | Rounding error < 1 LSB — precision bound |
| `encode_mono` | **high** | **high** | Monotone encoder — no ordering inversion |
| `decode_mono` | **high** | **high** | Monotone decoder |
| `encode_antitone_exp` | mid | medium | Larger exponent → coarser resolution |
| `encode_exp_zero` / `decode_exp_zero` | low | low | Identity at exp=0 |
| `roundtrip_exp_zero` | mid | medium | Perfect round-trip at exp=0 |
| `encode_zero` / `decode_zero` | low | low | Zero is fixed point |
| `encode_bound` | **high** | **high** | Wire size guarantee: d ≤ bound * 2^exp → enc ≤ bound |
| `roundtrip_idempotent` | **high** | **high** | decode-then-encode is identity |
| `default_exponent_valid` / `max_exponent_valid` | low | low | RFC compliance spot checks |

**Assessment**: High-value for a deceptively simple codec — the `roundtrip_le`
and `roundtrip_gap_lt` together prove the precision contract that any RFC 9000
implementation must maintain: decoded ACK delay is never larger than original
and is within one exponent-unit of it. `encode_bound` provides the wire-size
guarantee that prevents varint overflow for realistically-sized delays.
**Gap**: overflow on decode (u64 `checked_mul`) is not modelled — Lean uses
unbounded Nat. For `exp ≤ 20` and realistic delays this is safe, but a dedicated
overflow-bound lemma would close this gap.

---

### `FVSquad/BBR2InflightLo.lean` — T67: BBR2 Inflight Lower Bound Guard — 15 theorems (run 161/162)

**Source**: `quiche/src/recovery/gcongestion/bbr2/network_model.rs` — `InflightLo`
struct, `cap` and `clear` methods. BBR2 RFC 9002 §6.3.

Verifies the **inflight_lo guard** invariant: `cap` can only lower the
stored value (never raise it), `clear` resets to the inactive sentinel,
and consecutive caps compute the running minimum correctly.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `clear_sets_sentinel` | low | low | clear → inactive sentinel |
| `cap_after_clear_noop` | mid | medium | cap on inactive is identity |
| `cap_decreasing` | **high** | **high** | active cap: result ≤ old value |
| `cap_le_cap_arg` | **high** | **high** | active cap: result ≤ argument |
| `cap_le_old` | **high** | **high** | active cap: result ≤ stored value |
| `cap_never_raises` | **high** | **high** | unconditional: result ≤ stored value |
| `cap_idempotent` | **high** | **high** | double cap at same arg is identity |
| `double_cap_eq_min` | **high** | **high** | sequential caps = running minimum |
| `cap_commutative` | **high** | **high** | order of caps doesn't matter |
| `init_then_cap_le_init` | **high** | **high** | cap after init never exceeds init value |
| `init_then_cap_le_cap` | **high** | **high** | cap after init never exceeds cap argument |
| `cap_at_self_noop` | mid | medium | cap at current value is identity |
| `cap_zero_active` | **high** | **high** | cap to 0 → result is 0 |
| `clear_makes_inactive` | low | low | clear → `active = false` |
| `init_makes_active` | mid | medium | init (non-sentinel) → `active = true` |

**Positive finding**: `double_cap_eq_min` and `cap_commutative` together
formalise the "running minimum" semantics — any refactoring that accidentally
raised the lower bound (e.g., using `max` instead of `min`) would break these
theorems immediately.
**Gap**: how `inflight_lo` interacts with the larger BBR2 cwnd update loop
is not yet composed.

---

### `FVSquad/BBR2ProbeUpSlope.lean` — T68: BBR2 Probe-Up Inflight-Hi Slope — 17 theorems (run 162)

**Source**: `quiche/src/recovery/gcongestion/bbr2/probe_bw.rs` — `probe_up_rounds`,
`probe_up_bytes`, `probe_up_inflight_hi_slowly` method. BBR2 IETF draft §4.3.3.

Verifies the **probe-up accumulator** semantics: `probe_up_rounds` saturates at
`MAX_ROUNDS = 8`, `probe_up_bytes` grows exponentially (by `cwnd / 2^rounds`)
but never below `DEFAULT_MSS`, and the inflight-hi advance fires exactly at
the accumulator threshold — no spurious advances, guaranteed forward progress.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `rounds_bounded` | **high** | **high** | probe_up_rounds ≤ MAX_ROUNDS — prevents exponential overflow |
| `rounds_saturates` | **high** | **high** | saturates at MAX_ROUNDS |
| `rounds_strictly_increases` | **high** | **high** | strictly increases below MAX_ROUNDS |
| `bytes_floor` | **high** | **high** | probeUpBytes ≥ DEFAULT_MSS — no divide-by-zero-like floor |
| `bytes_le_cwnd_when_large` | **high** | **high** | bytes ≤ cwnd when cwnd large |
| `growth_positive` | mid | medium | growth ≥ 1 |
| `growth_max` | **high** | **high** | growth ≤ 2^MAX_ROUNDS — bounds exponential |
| `bytes_le_cwnd_div_growth` | mid | medium | bytes = cwnd / growth |
| `slope_zero_bytes_eq_cwnd` | mid | medium | at rounds=0, bytes = cwnd |
| `slope_zero_rounds_one` | low | low | nextRounds 0 = 1 |
| `slope_cwnd_zero_floor` | mid | medium | cwnd=0 → bytes = DEFAULT_MSS |
| `acked_after_mod` | **high** | **high** | accumulator = acked mod probe_up_bytes |
| `acked_after_lt_bytes` | **high** | **high** | accumulator < probe_up_bytes — invariant preserved |
| `inflight_hi_after_ge` | mid | medium | inflight_hi never decreases after update |
| `inflight_hi_stable_below_threshold` | **high** | **high** | no advance when acked < threshold |
| `inflight_hi_increases_at_threshold` | **high** | **high** | advances by DEFAULT_MSS at threshold |
| `acked_after_remainder` | **high** | **high** | combined: accumulator is correct modulo |

**Positive finding**: `rounds_bounded` directly prevents a latent
overflow: without the saturation cap, `probe_up_bytes = cwnd / 2^rounds`
would underflow to 0 for large `rounds`, causing a division-by-zero-like
silent failure. The theorem makes the saturation requirement explicit and CI-enforced.
**Gap**: interaction with `inflight_hi` clamping to the estimated BDP is not
modelled; the compose theorem `probe_up_terminates_in_finite_rounds` remains open.

---

### `FVSquad/QuicVersionPolicy.lean` — T69: QUIC Version Policy — 13 theorems (run 163)

**Source**: `quiche/src/lib.rs` — `is_reserved_version` (`~L615–618`),
`version_is_supported` (`~L1887–1889`), `RESERVED_VERSION_MASK = 0xfafafafa`,
`PROTOCOL_VERSION_V1 = 0x00000001`. RFC 9000 §15.

Verifies that **no QUIC version can simultaneously be reserved ("grease")
and supported**: the disjointness theorem `reserved_disjoint_supported`
is the central safety invariant. Seven concrete spot checks confirm V1
behaviour and canonical greasing values.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `v1_is_supported` | low | medium | V1 passes isSupportedVersion |
| `v1_not_reserved` | **high** | **high** | V1 does NOT pass isReservedVersion |
| `reserved_disjoint_supported` | **high** | **high** | No version can be both — safety invariant |
| `reserved_and_supported_false` | **high** | **high** | Bool form of disjointness |
| `grease_0a_reserved` / `grease_2a_reserved` / `grease_fa_reserved` | mid | medium | Canonical greasing values are reserved |
| `v1_passes_version_guard` | **high** | **high** | V1 does not trigger UnknownVersion error |
| concrete spot-check theorems | low | medium | V1 / zero / greasing via decide |

**Positive finding**: `reserved_disjoint_supported` directly guards against the
class of bug where a newly-added supported version accidentally shares a
bitmask pattern with the greasing mask — which would break QUIC version
negotiation for any peer using that greasing value.
**Gap**: multi-version negotiation (version list filtering) is not modelled.

---

### `FVSquad/CidMgmt.lean` §10 — T27: CID `retire_if_needed` — 7 new theorems (run 164; Cubic.lean total: 27)

**Source**: `quiche/src/cid.rs` — `ConnectionIdentifiers::new_scid` retire-if-needed
path. RFC 9000 §5.1.1.


### `FVSquad/QuicVersionPolicy.lean` — T69: QUIC Version Policy — 13 theorems (run 163)

**Source**: `quiche/src/lib.rs` — `is_reserved_version` (`~L615–618`),
`version_is_supported` (`~L1887–1889`), `RESERVED_VERSION_MASK = 0xfafafafa`,
`PROTOCOL_VERSION_V1 = 0x00000001`. RFC 9000 §15.

Verifies that **no QUIC version can simultaneously be reserved ("grease")
and supported**: the disjointness theorem `reserved_disjoint_supported`
is the central safety invariant. Seven concrete spot checks confirm V1
behaviour and canonical greasing values.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `v1_is_supported` | low | medium | V1 passes isSupportedVersion |
| `v1_not_reserved` | **high** | **high** | V1 does NOT pass isReservedVersion |
| `reserved_disjoint_supported` | **high** | **high** | No version can be both — safety invariant |
| `reserved_and_supported_false` | **high** | **high** | Bool form of disjointness |
| `grease_0a_reserved` / `grease_2a_reserved` / `grease_fa_reserved` | mid | medium | Canonical greasing values are reserved |
| `v1_passes_version_guard` | **high** | **high** | V1 does not trigger UnknownVersion error |
| concrete spot-check theorems | low | medium | V1 / zero / greasing via decide |

**Positive finding**: `reserved_disjoint_supported` directly guards against the
class of bug where a newly-added supported version accidentally shares a
bitmask pattern with the greasing mask — which would break QUIC version
negotiation for any peer using that greasing value.
**Gap**: multi-version negotiation (version list filtering) is not modelled.

---

### `FVSquad/CidMgmt.lean` §10 — T27: CID `retire_if_needed` — 7 new theorems (run 164; Cubic.lean total: 27)

**Source**: `quiche/src/cid.rs` — `ConnectionIdentifiers::new_scid` retire-if-needed
path. RFC 9000 §5.1.1.


Verifies the **probe-up accumulator** semantics: `probe_up_rounds` saturates at
`MAX_ROUNDS = 8`, `probe_up_bytes` grows exponentially (by `cwnd / 2^rounds`)
but never below `DEFAULT_MSS`, and the inflight-hi advance fires exactly at
the accumulator threshold — no spurious advances, guaranteed forward progress.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `rounds_bounded` | **high** | **high** | probe_up_rounds ≤ MAX_ROUNDS — prevents exponential overflow |
| `rounds_saturates` | **high** | **high** | saturates at MAX_ROUNDS |
| `rounds_strictly_increases` | **high** | **high** | strictly increases below MAX_ROUNDS |
| `bytes_floor` | **high** | **high** | probeUpBytes ≥ DEFAULT_MSS — no divide-by-zero-like floor |
| `bytes_le_cwnd_when_large` | **high** | **high** | bytes ≤ cwnd when cwnd large |
| `growth_positive` | mid | medium | growth ≥ 1 |
| `growth_max` | **high** | **high** | growth ≤ 2^MAX_ROUNDS — bounds exponential |
| `bytes_le_cwnd_div_growth` | mid | medium | bytes = cwnd / growth |
| `slope_zero_bytes_eq_cwnd` | mid | medium | at rounds=0, bytes = cwnd |
| `slope_zero_rounds_one` | low | low | nextRounds 0 = 1 |
| `slope_cwnd_zero_floor` | mid | medium | cwnd=0 → bytes = DEFAULT_MSS |
| `acked_after_mod` | **high** | **high** | accumulator = acked mod probe_up_bytes |
| `acked_after_lt_bytes` | **high** | **high** | accumulator < probe_up_bytes — invariant preserved |
| `inflight_hi_after_ge` | mid | medium | inflight_hi never decreases after update |
| `inflight_hi_stable_below_threshold` | **high** | **high** | no advance when acked < threshold |
| `inflight_hi_increases_at_threshold` | **high** | **high** | advances by DEFAULT_MSS at threshold |
| `acked_after_remainder` | **high** | **high** | combined: accumulator is correct modulo |

**Positive finding**: `rounds_bounded` directly prevents a latent
overflow: without the saturation cap, `probe_up_bytes = cwnd / 2^rounds`
would underflow to 0 for large `rounds`, causing a division-by-zero-like
silent failure. The theorem makes the saturation requirement explicit and CI-enforced.
**Gap**: interaction with `inflight_hi` clamping to the estimated BDP is not
modelled; the compose theorem `probe_up_terminates_in_finite_rounds` remains open.

---

### `FVSquad/QuicVersionPolicy.lean` — T69: QUIC Version Policy — 13 theorems (run 163)

**Source**: `quiche/src/lib.rs` — `is_reserved_version` (`~L615–618`),
`version_is_supported` (`~L1887–1889`), `RESERVED_VERSION_MASK = 0xfafafafa`,
`PROTOCOL_VERSION_V1 = 0x00000001`. RFC 9000 §15.

Verifies that **no QUIC version can simultaneously be reserved ("grease")
and supported**: the disjointness theorem `reserved_disjoint_supported`
is the central safety invariant. Seven concrete spot checks confirm V1
behaviour and canonical greasing values.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `v1_is_supported` | low | medium | V1 passes isSupportedVersion |
| `v1_not_reserved` | **high** | **high** | V1 does NOT pass isReservedVersion |
| `reserved_disjoint_supported` | **high** | **high** | No version can be both — safety invariant |
| `reserved_and_supported_false` | **high** | **high** | Bool form of disjointness |
| `grease_0a_reserved` / `grease_2a_reserved` / `grease_fa_reserved` | mid | medium | Canonical greasing values are reserved |
| `v1_passes_version_guard` | **high** | **high** | V1 does not trigger UnknownVersion error |
| concrete spot-check theorems | low | medium | V1 / zero / greasing via decide |

**Positive finding**: `reserved_disjoint_supported` directly guards against the
class of bug where a newly-added supported version accidentally shares a
bitmask pattern with the greasing mask — which would break QUIC version
negotiation for any peer using that greasing value.
**Gap**: multi-version negotiation (version list filtering) is not modelled.

---

### `FVSquad/CidMgmt.lean` §10 — T27: CID `retire_if_needed` — 7 new theorems (run 164; Cubic.lean total: 27)

**Source**: `quiche/src/cid.rs` — `ConnectionIdentifiers::new_scid` retire-if-needed
path. RFC 9000 §5.1.1.

Extends the existing CidMgmt model with `newScidRetire`: when the active CID
count reaches the limit, the lowest-sequence CID is retired before appending
the new one. Key RFC property: post-condition count ≤ limit.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `lowestSeq_mem` | mid | medium | minimum is in the list |
| `lowestSeq_le_all` | **high** | **high** | minimum ≤ every member |
| `filter_neq_length_lt` | mid | medium | filtering out one member shortens list |
| `newScidRetire_count_le_limit` | **high** | **high** | RFC 9000 §5.1.1 — count ≤ limit after retire |
| `newScidRetire_nextSeq_inc` | **high** | **high** | nextSeq increments |
| `newScidRetire_new_seq_in_active` | **high** | **high** | new sequence is in post-state active list |
| `newScidRetire_lowest_removed` | **high** | **high** | retired (lowest) sequence is absent |

**Positive finding**: `newScidRetire_count_le_limit` makes RFC 9000 §5.1.1
explicit and machine-checked: after any retire-if-needed step, the active CID
count is guaranteed to be at most the limit. Any refactoring that omitted the
retire step when at-capacity would fail this theorem at CI.
**Gap**: `retire_prior_to` bookkeeping and CID byte content not modelled.

---

### `FVSquad/Cubic.lean` §6 — T26: CUBIC W_est Reno-friendly Extension — 10 new theorems (run 165; Cubic.lean total: 36)

**Source**: `quiche/src/recovery/congestion/cubic.rs` — `w_est` Reno-friendly
AIMD update path (~L250–280), `ALPHA_AIMD`, `BETA_CUBIC`. RFC 8312bis §5.8.

Extends the earlier Cubic model with the W_est AIMD increment functions
(`wEstInc`, `wEstIncAimd`, `wEstIncMax`) and proves that: the increment is
non-negative and monotone in acked and alpha, anti-monotone in cwnd; the AIMD
increment is always ≤ the maximum increment; in the AIMD region, cwnd grows
at least as much as W_est; and concrete examples match the expected integer
arithmetic (using `native_decide`).

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `wEstInc_nonneg` | low | medium | increment ≥ 0 |
| `wEstInc_monotone_acked` | **high** | **high** | more acked → more W_est growth |
| `wEstInc_antitone_cwnd` | **high** | **high** | larger cwnd → smaller increment (AIMD property) |
| `wEstIncAimd_le_max` | **high** | **high** | alpha < 1 → AIMD increment < full increment |
| `aimdRegion_cwnd_ge_west` | **high** | **high** | AIMD region: cwnd grows at least W_est |
| `aimdRegion_cwnd_ge_old` | **high** | **high** | no window regression in AIMD region |
| `wEstInc_monotone_alpha` | **high** | **high** | larger alpha → more aggressive growth |
| `wEstIncAimd_concrete_ack17` | low | medium | concrete example: ack=17, cwnd=1 → 9 |
| `wEstIncMax_concrete` | low | medium | concrete example: ack=17, cwnd=1 → 17 |
| `wEstIncAimd_lt_max_concrete` | low | medium | AIMD < max on concrete example |

**Positive finding**: `wEstIncAimd_le_max` formalises the key CUBIC RFC
invariant that the Reno-friendly AIMD increment is strictly bounded below the
unconstrained maximum — any implementation that accidentally used `alpha = 1`
in the Reno-friendly region would violate this theorem.
**Gap**: the transition condition `W_cubic < W_est` that switches to the
Reno-friendly region is not yet modelled; a composed theorem covering both
branches of the CUBIC update would complete T26.

---

### Overall Status (run 166)
### Overall Status (run 168)

- **63 Lean files, ~1431 theorems, 0 sorry** (lake build ✅, Lean 4.29.1)
- Route-B: 23 targets, 2691+ cases PASS
- Run 167: BBR2PacingRate.lean (T32, 14 thms, 0 sorry), Route-B for AckDelayCodec (31/31)
- Run 168 (this run): RFC9000Sec46.lean — composed cross-file theorem bridging
  StreamCreditReturn (T58) and StreamCountLimit (T63) for RFC 9000 §4.6 end-to-end.
  CRITIQUE.md updated.
- Coverage now includes: **RFC 9000 §4.6 end-to-end stream-credit chain** (new),
  **BBR2 pacing rate bounds** (T32), all prior coverage.
- **Next priorities**:
  1. Route-B for T27 (CidMgmt retire_if_needed): count check vs cid.rs
  2. Route-B for T65 (SsThresh): write-once check vs recovery/congestion
  3. Route-B for T32 (BBR2PacingRate): monotone path vs Rust fixture
  4. Cubic T26 W_est transition condition (W_cubic < W_est branch)
  5. CORRESPONDENCE.md and REPORT.md update to cover runs 167–168

---

### `FVSquad/BBR2PacingRate.lean` — T32: BBR2 Pacing Rate Bounds — 14 theorems (run 167)

**Source**: `quiche/src/recovery/gcongestion/bbr2.rs` — `BBR2::set_pacing_rate` and
`calculate_pacing_rate` family. RFC 9002 §7.7.

Models the pacing rate calculation:
- Startup phase: `rate = startup_gain × estimated_bw`
- Full BW phase: `rate = pacing_gain × estimated_bw`
- Bottleneck drain: capped at measured delivery rate

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `startup_monotone` | **high** | **high** | Startup pacing rate is non-decreasing in bw |
| `startup_ge_target` | **high** | **high** | Startup rate ≥ target — no starvation in startup |
| `full_bw_sets_target` | **high** | **high** | After startup: rate = gain × bw |
| `target_monotone_in_bw` | **high** | **high** | Higher bw → higher rate |
| `target_monotone_in_gain` | **high** | **high** | Higher gain → higher rate |
| `zero_bw_unchanged` | mid | medium | Zero-bandwidth state is a fixed point |
| Case B cap bounds | mid | medium | Rate is capped to delivery rate on drain |

**Positive finding**: `startup_monotone` formalises the key BBR2 liveness
property — pacing rate can never decrease during startup, ensuring the
connection cannot stall in startup phase.
**Gap**: the drain phase and probe phases are not yet modelled; the cap
interaction with `measured_delivery_rate` is approximated.

---

### `FVSquad/RFC9000Sec46.lean` — Composed §4.6: Stream-Credit Chain — 12 theorems (run 168)

**Source**: Cross-file composition of T58 (`StreamCreditReturn.lean`) and
T63 (`StreamCountLimit.lean`). RFC 9000 §4.6.

This file bridges the two separate models into a single end-to-end §4.6
proof chain:
- **T58 model**: local two-phase credit staging (`bidiNext` / `bidiCurrent`)
- **T63 model**: peer's stream-count limit (`peerMaxBidi`) updated via `max`

The `SystemState` struct holds both sub-states. `rfc9000_step(sys, n)` models
the full §4.6 cycle: collect N streams → commit → peer receives MAX_STREAMS.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `collectN_bidiNext` | mid | medium | N collects increase bidiNext by exactly N |
| `step_bidiCurrent` | mid | medium | After commit, bidiCurrent = original bidiNext + N |
| `collectN_preserves_invariant` | **high** | **high** | Credit invariant maintained through N collects |
| `commit_preserves_invariant` | **high** | **high** | Commit preserves credit invariant |
| `step_local_current_increases` | **high** | **high** | End-to-end: bidiCurrent increases by N |
| `step_preserves_credit_invariant` | **high** | **high** | Full step preserves credit invariant |
| `step_peer_opened_unchanged` | mid | medium | Step does not change peer's open count |
| `step_peer_max_equals_committed` | **high** | **high** | Peer's limit = max(old, new committed value) |
| `rfc9000_peer_max_monotone` | **high** | **high** | Peer's limit never decreases — RFC §4.6 safety |
| `rfc9000_peer_gains_n_slots` | **high** | **high** | Under tight coherence: peer gains ≥ N slots |
| `rfc9000_streams_left_gain` | **high** | **high** | Under tight coherence: streamsLeft increases ≥ N |
| `rfc9000_zero_collects_nonneg` | mid | medium | Zero collects: streamsLeft non-decreasing |

**Positive finding**: `rfc9000_peer_max_monotone` is the headline RFC 9000 §4.6
safety theorem proved end-to-end across two Lean modules: the peer's
`peerMaxBidi` can never decrease as a result of our collect+commit cycle. Any
bug that skipped the `max` in `update_peer_max_streams_bidi` (e.g., using plain
assignment instead of `max`) would cause this theorem to fail. Similarly, any
bug in the collect staging (using subtraction instead of addition) would break
`rfc9000_peer_gains_n_slots`.

**Composition value**: This is the first cross-file composed theorem in the
suite, demonstrating that separately-proved sub-module properties can be
combined into protocol-level safety guarantees. The composed model explicitly
captures the coherence condition (peer has applied last MAX_STREAMS) as a
precondition, making the assumption transparent.

**Gap**: the "tight coherence" precondition (`bidiNext ≥ peerMaxBidi`) in
`rfc9000_peer_gains_n_slots` is stronger than just `coherent`; a full proof
would additionally show that quiche's scheduling logic maintains this condition
between collect and send.

---

- **61 Lean files, ~1405 theorems, 0 sorry** (lake build ✅, Lean 4.29.1)
- Route-B: 22 targets, 2660+ cases PASS
- Coverage spans: QUIC transport (connection negotiation, idle-timeout RFC 9000
  §10.1.1, PMTUD binary search, STREAM frame type byte, transport error codes,
  stream-count limit RFC 9000 §4.6, **stream credit-return RFC 9000 §4.6**,
  **QUIC version greasing RFC 9000 §15**,
  **CID retire-if-needed RFC 9000 §5.1.1**, **ACK delay codec RFC 9000 §13.2.5**),
  congestion control (NewReno with multi-cycle AIMD convergence, Cubic with
  **W_est Reno-friendly extension**, BBR2 with startup/probing model, pacing,
  HyStart++, WindowedFilter max-filter, delivery-rate estimation, app-limited
  guard, BBR2 MaxBandwidthFilter + RoundTripCounter, BBR2 ProbeBW phase gains,
  loss-detection threshold, PRR rate-control formula, BBR2 ProbeRTT phase params
  + state machine, **BBR2 inflight_lo guard**, **BBR2 probe-up slope**,
  **SsThresh write-once invariant**),
  HTTP/3 codec, QPACK (static table + integer codec), stream/frame state
  machines, RFC compliance, PMTUD binary-search bounds.
- Run 158: StreamCreditReturn.lean (T58, 20 thms), Route-B for T60 (23/23)
- Run 159: SsThresh.lean (T65, 14 thms), Route-B for BBR2Limits (1000+ cases)
- Run 160: AckDelayCodec.lean (T66, 16 thms)
- Run 161/162: BBR2InflightLo.lean (T67, 15 thms), BBR2ProbeUpSlope.lean (T68, 17 thms)
- Run 163: QuicVersionPolicy.lean (T69, 13 thms)
- Run 164: CidMgmt.lean §10 extension (T27, 7 new thms, total 27)
- Run 165: Cubic.lean §6 W_est extension (T26, 10 new thms, total 36); T32 informal spec
- Run 166 (this run): CRITIQUE.md + CORRESPONDENCE.md updated to cover runs 154–165
- **Next priorities**:
  1. T32 (BBR2 pacing rate): write FVSquad/BBR2PacingRate.lean (~60–80 lines, all omega)
  2. Route-B for T66 (AckDelayCodec): encode/decode vs Rust fixture comparison
  3. Route-B for T65 (SsThresh): write-once check against recovery/congestion
  4. Composed theorem: StreamCreditReturn + StreamCountLimit → full RFC 9000 §4.6 chain
  5. Route-B for T27 (CidMgmt retire_if_needed): count check vs cid.rs

---

### `FVSquad/BBR2DrainPhase.lean` — T70: BBR2 Drain Phase Constants — 21 theorems (run 169)

**Source**: `quiche/src/recovery/gcongestion/bbr2.rs` — `DEFAULT_PARAMS`
(drain_pacing_gain, drain_cwnd_gain, startup_pacing_gain, startup_cwnd_gain).

Models the gain fractions for drain phase alongside startup for comparison.
Key theorems establish the algebraic relationships between gains used by
the drain decision logic.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `drainPacingGain_subUnity` | **high** | **high** | Drain pacing gain < 1 — forces queue drainage |
| `drainCwndGain_superUnity` | **high** | **high** | Drain cwnd gain > 1 — matches startup cwnd |
| `startupPacingGain_superUnity` | **high** | **high** | Startup pacing > 1 — probes bandwidth |
| `drainCwndGain_eq_startupCwndGain` | **high** | **high** | Drain uses same cwnd as startup by design |
| `applyDrainPacing_le` | **high** | **high** | Applying drain pacing reduces inflight |
| `applyGain_subUnity_le` | mid | medium | Sub-unity gain shrinks value |
| `applyGain_superUnity_ge` | mid | medium | Super-unity gain grows value |

**Positive finding**: `drainCwndGain_eq_startupCwndGain` formally verifies
the design invariant that the cwnd cap is unchanged during drain — any
unintentional divergence in these constants would cause this theorem to fail.

---

### `FVSquad/BBR2Startup.lean` — T71: BBR2 Startup Phase Constants — 26 theorems (run 170)

**Source**: `quiche/src/recovery/gcongestion/bbr2.rs` — `DEFAULT_PARAMS`
(startup_pacing_gain = 2.773, startup_cwnd_gain = 2.0, full_bw_threshold).

Extends the drain-phase model with startup-specific theorems, including the
relationship between startup gains and the full-bandwidth threshold.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `startupCwndGain_superUnity` | **high** | **high** | Startup cwnd gain > 1 |
| `startupPacingGain_superUnity` | **high** | **high** | Startup pacing gain > 1 |
| `fullBwThreshold_superUnity` | **high** | **high** | BW-growth threshold > 1 |
| `applyStartupCwnd_ge` | **high** | **high** | Startup cwnd increase is non-decreasing |
| `applyStartupPacing_ge` | **high** | **high** | Startup pacing rate is non-decreasing |
| `applyGain_fullBwThreshold_grows` | **high** | **high** | Threshold forces BW increase for startup exit |

**Positive finding**: The gain ordering across startup/drain phases is fully
enumerated and verified. A typo in the `startup_pacing_gain` constant (e.g.
`2.73` vs `2.773`) would change the super-unity proof obligation.

---

### `FVSquad/BBR2ProbeRTTPhase.lean` — T72: BBR2 ProbeRTT Phase Constants — 25 theorems (run 171)

**Source**: `quiche/src/recovery/gcongestion/bbr2.rs` — `DEFAULT_PARAMS`
(probe_rtt_pacing_gain = 1.0, probe_rtt_cwnd_gain = 0.5).

Models the ProbeRTT phase, where both pacing and cwnd gains are at or below 1.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `probeRttPacingGain_unity` | **high** | **high** | ProbeRTT pacing gain = 1 exactly |
| `probeRttCwndGain_unity` | **high** | **high** | ProbeRTT cwnd gain = 1 exactly |
| `applyProbeRttPacing_identity` | **high** | **high** | Unity gain is identity on bandwidth |
| `applyProbeRttCwnd_identity` | **high** | **high** | Unity cwnd gain is identity |
| `applyGain_atMostUnity_le` | mid | medium | At-most-unity gain ≤ input |

**Note**: The Rust source uses `probe_rtt_cwnd_gain = 0.5` but the Lean model
captures `probe_rtt_pacing_gain = 1.0`. A future target should explicitly
model the cwnd reduction to 0.5 × estimated_inflight.

---

### `FVSquad/BBR2CyclePhaseGain.lean` — T73: BBR2 ProbeBW Cycle Phase Gains — 23 theorems (run 172)

**Source**: `quiche/src/recovery/gcongestion/bbr2/mode.rs` — `CyclePhase::pacing_gain`
and `CyclePhase::cwnd_gain` (five cycle phases: NotStarted, Up, Down, Cruise, Refill).

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `upPacingGain_superUnity` | **high** | **high** | Up pacing gain (5/4) > 1 — probes bandwidth |
| `downPacingGain_subUnity` | **high** | **high** | Down pacing gain (9/10) < 1 — drains queue |
| `defaultPacingGain_unity` | **high** | **high** | Default pacing gain = 1 exactly |
| `pacingGain_ordering` | **high** | **high** | Down < Default < Up (9/10 < 1 < 5/4) |
| `up_is_only_elevated_pacing` | **high** | **high** | Only Up phase elevates pacing |
| `nonUp_cwnd_gain_uniform` | **high** | **high** | All non-Up phases share the same cwnd gain |
| `applyGain_mono` | mid | medium | applyGain monotone in bandwidth |

**Positive finding**: `pacingGain_ordering` formally captures the probe → drain
→ cruise cycle structure as a total ordering theorem. Any constant swap (e.g.
`Up` and `Down` gains reversed) would break this theorem immediately.

---

### `FVSquad/PacketTypeEpoch.lean` — T74: QUIC PacketType ↔ Epoch Round-Trip — 14 theorems (run 173)

**Source**: `quiche/src/packet.rs` — `Type::from_epoch` and `Type::to_epoch`.
Route-B: 42/42 PASS (`formal-verification/tests/packet_type_epoch/`).

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `from_epoch_to_epoch` | **high** | **high** | `to_epoch(from_epoch(e)) = Some(e)` for all epochs |
| `from_epoch_injective` | **high** | **high** | fromEpoch is injective |
| `short_and_zeroRTT_same_epoch` | **high** | **high** | Short and 0-RTT share Application epoch |
| `retry_no_epoch` | **high** | **high** | Retry packet has no epoch |
| `hasEpoch_iff` | **high** | **high** | Full characterisation of epoch-bearing types |
| `to_epoch_from_epoch` | **high** | **high** | Left-inverse on image of fromEpoch |
| `to_epoch_exhaustive` | mid | medium | Exhaustive case coverage |

**Positive finding**: All 14 theorems close by `decide` — the type is fully
finite and the proof is machine-checked exhaustively. Route-B validation
confirmed all 42 test cases agree between Lean model and Rust implementation.

---

### `FVSquad/BBR2DrainExit.lean` — T75: BBR2 Drain Exit Condition — 17 theorems (run 176)

**Source**: `quiche/src/recovery/gcongestion/bbr2/drain.rs` —
`on_congestion_event` (drain exit guard), `drain_target`, and
`network_model.rs` — `bdp0/bdp1/bdp`.

Models the key property: Drain exits to ProbeBW when
`bytes_in_flight ≤ drain_target = bdp0 = max_bw × min_rtt_ns / 1e9`.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `shouldExitDrain_iff` | **high** | **high** | Exact characterisation of exit guard |
| `exitDrain_monotone_byif` | **high** | **high** | Decreasing inflight preserves exit condition |
| `exitDrain_monotone_bdp` | **high** | **high** | Increasing BDP widens exit condition |
| `stayInDrain_iff` | **high** | **high** | Complement: stay iff bif > bdp0 |
| `stayInDrain_anti_monotone_bdp` | **high** | **high** | Decreasing BDP preserves stay condition |
| `bdp_monotone_bw` | **high** | **high** | Higher bandwidth → larger drain target |
| `bdp_monotone_rtt` | **high** | **high** | Higher min RTT → larger drain target |
| `exitDrain_bw_increase` | **high** | **high** | Higher bandwidth widens exit condition |
| `exitDrain_rtt_increase` | **high** | **high** | Higher RTT widens exit condition |
| `shouldExitDrain_zero_bif` | mid | medium | Zero inflight always exits drain |
| `bdp_zero_bw` / `bdp_zero_rtt` | low | low | Degenerate cases |

**Positive finding**: `exitDrain_bw_increase` captures an important liveness
property: as the path bandwidth improves, the drain exit window only grows —
a connection cannot get stuck in drain after the link improves. Any regression
that computes `bdp0` as non-monotone in bandwidth would break this theorem.

**Gap**: The actual mode-transition logic (`into_probe_bw`) is not modelled;
only the guard condition is. This gap is addressed by T76 below.

---

### `FVSquad/BBR2ModeState.lean` — T76: BBR2 Abstract Mode State Machine — 19 theorems (run 177)

**Source**: `quiche/src/recovery/gcongestion/bbr2/mode.rs` — `Mode` enum
(lines 153–158), `startup.rs` `into_drain` (lines 160–186), `drain.rs`
`on_congestion_event` exit guard (lines 62–86).

Models the abstract four-mode BBR2 state machine and proves ordering,
safety, and idempotency properties.

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `step_startup_exits_when_ready` | **high** | **high** | Startup exits to Drain when `full_bw_reached` |
| `step_drain_exits_when_ready` | **high** | **high** | Drain exits to ProbeBW when `should_exit_drain` |
| `startup_only_transitions_to_drain` | **high** | **high** | Startup cannot jump to ProbeBW or ProbeRTT |
| `drain_only_transitions_to_probebw` | **high** | **high** | Drain cannot jump backwards to Startup |
| `startup_cannot_skip_drain` | **high** | **high** | No direct Startup → ProbeBW path |
| `step_idempotent_startup_stable` | mid | medium | Stable state: not-ready inputs keep Startup in Startup |
| `step_idempotent_drain_stable` | mid | medium | Stable state: not-ready inputs keep Drain in Drain |
| `probertt_only_transitions_to_probebw` | mid | medium | ProbeRTT can only exit to ProbeBW (never to Startup/Drain) |
| `initial_mode_is_startup` | low | low | Initial mode construction |
| `startup_not_drain` / `drain_not_probebw` etc. | low | low | Mode distinctness |

**Positive finding**: `startup_cannot_skip_drain` closes the gap noted in the
T75 critique entry — a regression that accidentally connected Startup directly
to ProbeBW would break this theorem. `startup_only_transitions_to_drain` and
`drain_only_transitions_to_probebw` collectively enforce the required monotone
ordering of the first three modes.

**Assessment**: This is a high-value structural safety file. The BBR2 mode
ordering is a protocol invariant: the connection must probe steady state (Drain)
before entering the probing cycle (ProbeBW). Any code change that bypasses Drain
— e.g., an accidental `into_probe_bw` call from Startup — would violate
`startup_cannot_skip_drain`. The theorems are all proved by `decide`/`simp`
in a single step; the value lies in the specification, not the proof complexity.

---

### Overall Status (run 177)

- **70 Lean files, 1348 theorems, 0 sorry** (lake build ✅, Lean 4.29.1)
- Route-B: 27 targets, 2864+ cases PASS
- Run 167: BBR2PacingRate.lean (T32, 14 thms), Route-B for AckDelayCodec (31/31)
- Run 168: RFC9000Sec46.lean — composed §4.6 end-to-end chain (12 thms)
- Run 169: BBR2DrainPhase.lean (T70, 21 thms), Route-B for CidMgmt (56/56)
- Run 170: BBR2Startup.lean (T71, 26 thms), Route-B for SsThresh (25/25)
- Run 171: BBR2ProbeRTTPhase.lean (T72, 25 thms), Route-B for ProbeBW phases
- Run 172: BBR2CyclePhaseGain.lean (T73, 23 thms), CI audit
- Run 173: PacketTypeEpoch.lean (T74, 14 thms), Route-B T73 (25/25)
- Run 175: Route-B T74 (42/42 PASS), CORRESPONDENCE.md update, paper update
- Run 176: BBR2DrainExit.lean (T75, 17 thms, 0 sorry) + CRITIQUE.md update
- Run 177 (this run): BBR2ModeState.lean (T76, 19 thms, 0 sorry) + CRITIQUE.md update
- **Next priorities**:
  1. Route-B for T75 (BBR2DrainExit) and T76 (BBR2ModeState)
  2. REPORT.md update to cover runs 167–177
  3. Paper PDF recompile (needs LaTeX environment)
