# Formal Verification Proof Utility Critique

> 🔬 *Written by Lean Squad automated formal verification.*

## Last Updated

- **Date**: 2026-04-19 09:30 UTC
- **Commit**: `14c1694a`

---

## Overall Assessment

The formal verification suite for `quiche` now covers **24 Lean files with
518 theorems + 187 examples, 3 sorry** (Lean 4.29.1, no Mathlib), and two
further targets at Phase 2 (informal spec done, awaiting Lean formalisation):
T30 (Varint 2-bit tag structural properties) and T31 (H3 frame codec round-trip).
Runs 68–84 added `SendBufRetransmit.lean` (run 68), `VarIntRoundtrip.lean`
(runs 75–77, 2 sorry for 8-byte case), `PacketNumEncodeDecode.lean` (run 76,
0 sorry), `PacketHeader.lean` (run 81, 1 sorry for full round-trip), the H3
frame informal spec T31 (run 82), and the Varint tag informal spec T30 (run 83).
The most notable results are: a **formal proof of an Ord law violation (OQ-1)**
in `StreamPriorityKey::cmp`; the **end-to-end encode↔decode composition theorem**
`encode_decode_pktnum` for all four QUIC packet-number encoding lengths; the
**QUIC packet-header first-byte theorems** (type-code bijection, FORM_BIT and
FIXED_BIT invariants, short/long distinguishability); and the foundational byte-
cursor round-trips (`putU32_freeze_getU32` etc.). Key results include
`emitN_le_maxData` (RFC 9000 §4.1 flow-control safety), `decode_pktnum_correct`
(RFC 9000 §A.3), `newScid_seq_fresh` (CID uniqueness), and `insertAny_inv`
(out-of-order stream reassembly). Run 84 (this run) adds T30 and T31 critique
sections and a Paper Review.

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

### Target 23: VarInt cross-module round-trip (`FVSquad/VarIntRoundtrip.lean`) — 8 theorems 🔄 *(2 sorry — run 75–77)*

| Theorem | Level | Bug-catching potential | Notes |
|---------|-------|----------------------|-------|
| `putVarint_freeze_getVarint_1byte` | high | **high** | `put_varint` (1-byte) → `freeze` → `get_varint` = identity for v < 64 |
| `putVarint_freeze_getVarint_2byte` | high | **high** | 2-byte round-trip for 64 ≤ v < 16384 |
| `putVarint_freeze_getVarint_4byte` | high | **high** | 4-byte round-trip for 16384 ≤ v < 1073741824 |
| `putVarint_freeze_getVarint_8byte` | high | **high** | 8-byte round-trip for v ≥ 1073741824 — **sorry** (blocked on `putU32_bytes_unchanged`) |
| `putVarint_freeze_getVarint` | high | **high** | Combined round-trip for all valid QUIC varint values — **sorry** (inherits 8-byte sorry) |
| `putVarint_off` | mid | medium | Cursor advances by `varintLen(v)` after `put_varint` |
| `putVarint_len` | mid | medium | `putVarint` places exactly `varintLen(v)` bytes |
| `putVarint_first_byte_tag` | mid | medium | First-byte tag bits equal `varintParseLen(first_byte) - 1` — partially sorry for 8-byte |
| 16 examples | low | low | Concrete put→freeze→get at each encoding length verified by `decide` |

**Assessment**: The three completed round-trip theorems (1-byte, 2-byte,
4-byte) directly verify that the varint codec correctly encodes and decodes 75%
of the QUIC varint value space. The 2 sorry for the 8-byte path are a known gap:
the proof requires `putU32_bytes_unchanged` (a lemma about non-aliasing of two
sequential `putU32` calls in `OctetsMut`), which was identified as a pending
addition to `OctetsMut.lean`. Resolving these 2 sorry is a low-effort,
high-value next step. **Gap**: `putVarint_first_byte_tag` is partly proved but
has a sorry for the 8-byte encoding path for the same reason.

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

### Target 29: QUIC packet-header first-byte (`FVSquad/PacketHeader.lean`) — 14 theorems 🔄 *(1 sorry — run 81)*

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
| `version_roundtrip` | high | **high** | QUIC version field (32-bit big-endian) round-trips correctly via `putU32`/`getU32` |
| `longHeader_roundtrip` | high | **high** | Full Header encode↔decode round-trip — **sorry** (requires richer byte-list buffer model) |
| 12 examples | low | low | Concrete first-byte values for each packet type verified by `decide` |

**Assessment**: The type-code bijection and bit-presence theorems are
high-value: a bug in the `to_bytes`/`from_bytes` first-byte encoding would
violate `typeCode_roundtrip`, `longFirstByte_form_bit`, or `short_long_first_byte_differ`,
causing all QUIC traffic to be misclassified. The `version_roundtrip` theorem
closes the version-field correctness proof via the existing `OctetsRoundtrip`
infrastructure. The 1 remaining sorry (`longHeader_roundtrip`) represents the
full buffer encode↔decode round-trip, which requires extending the model to
include DCID, SCID, token, and payload-length fields. This is the key remaining
gap for this target. **Approximations**: only the first-byte layer and the
version field are modelled; pkt_num_len (bits 1–0) and key_phase (bit 2) are
fixed to 0; header protection is out of scope.

---

### Target 30: Varint 2-bit tag structural properties (`specs/varint_tag_informal.md`) — Phase 2 *(informal spec complete — run 83)*

> **Status**: Informal spec done. No Lean file yet. Assessment of forthcoming Lean file.

The T30 informal spec (`specs/varint_tag_informal.md`) covers the *structural*
layer of the QUIC varint codec, independently of the full round-trip (T1, T23):
the relationship between the 2-bit tag in the first byte, the `varint_len`
function, and `varint_parse_len`. Five property groups are specified:

| Property group | Lean type | Expected difficulty | Bug-catching potential |
|---------------|-----------|--------------------|-----------------------|
| §1 — `varint_parse_len` range biconditionals | 4 iff theorems | trivial (`omega`) | **high** |
| §2 — `varint_len` value-range biconditionals | 4 iff theorems | trivial (`omega`) | **high** |
| §3 — Tag–value non-overlap proofs | 4 inequality lemmas | low (`omega`) | medium |
| §4 — Tag consistency (universal) | 1 universal theorem | low (cases+simp+omega) | **high** |
| §5 — `varint_parse_len` completeness/partition | 1 theorem | low (omega/decide) | medium |

**Assessment**: The §1 and §4 theorems are the highest-value results in this
target. The biconditional form of `varint_parse_len` range theorems (§1) is a
strictly stronger statement than the one-directional lemmas already in
`Varint.lean`. A receiver that misreads the 2-bit tag would fail these
theorems. The universal tag consistency theorem (§4) upgrades the existential
`varint_first_byte_tag` in `Varint.lean` to a universally quantified form,
directly stating that `varint_parse_len(first_byte) = varint_len(v)` for *all*
encoding outputs — this is the key structural invariant of the QUIC varint wire
format.

**Bug-catching potential**: Medium-to-high. An implementation that set the wrong
tag bits (e.g. set `0x80` when encoding a 2-byte varint) would fail §1 and §4
immediately. The non-overlap proofs (§3) rule out a class of implementation
errors where the tag and the value bits are accidentally combined in a
conflicting way.

**Approximations**: The model uses the same arithmetic-in-lieu-of-bitwise
approach as T1 and T23. The proof that bitwise OR is equivalent to addition
when the bits do not overlap is exactly the content of §3, so these proofs are
self-validating: they prove the approximation assumption that T1 and T23 took
for granted.

**Effort estimate**: ~120 Lean lines, all closed by `omega` or `simp`+`omega`.
No sorry expected. This is a low-effort, high-value next step (Task 3 in the
next run).

---

### Target 31: HTTP/3 frame codec round-trip (`specs/h3_frame_informal.md`) — Phase 2 *(informal spec complete — run 82)*

> **Status**: Informal spec done. No Lean file yet. Assessment of forthcoming Lean file.

The T31 informal spec (`specs/h3_frame_informal.md`) covers `Frame::to_bytes` and
`Frame::from_bytes` in `quiche/src/h3/frame.rs` — the HTTP/3 frame serialisation
layer. The key correctness property is the round-trip invariant: for a frame `f`,
`from_bytes(type, payload_length, to_bytes(f)) = f`.

| Frame type | Round-trip difficulty | Bug-catching potential |
|------------|----------------------|----------------------|
| `GoAway` (single varint `id`) | low (`omega`) | **high** |
| `MaxPushId` (single varint `push_id`) | low (`omega`) | **high** |
| `CancelPush` (single varint `push_id`) | low (`omega`) | **high** |
| `Settings` (key-value varint pairs) | medium (partial round-trip) | **high** |
| `PushPromise` / `PriorityUpdate*` (varint + raw bytes) | medium | medium |
| `Data` / `Headers` (raw byte arrays) | trivial (identity) | low |

**Assessment**: The recommended Lean scope (GoAway, MaxPushId, CancelPush) covers
the three pure-varint frame types, which are the most tractable and
security-relevant. A bug in encoding `GoAway` (which carries the stream ID of the
last processed stream) could cause a receiver to prematurely terminate streams.
A `CancelPush` encoding error would fail to cancel promised resources. These
are non-trivial correctness properties that QUIC interoperability tests exercise.

**Open questions from the informal spec** that affect the Lean model:
- **OQ-T31-1**: `from_bytes` behaviour when `payload_length > bytes.len()` —
  unclear whether an error or a truncated read. The Lean model must decide which
  to model.
- **OQ-T31-2**: 0-length frames — a TODO in the code; the model may need to
  treat this as out-of-scope.
- **OQ-T31-3**: Settings GREASE round-trip — settings with unknown keys are
  silently dropped; the round-trip can only be partial. This should be explicitly
  scoped out.
- **OQ-T31-4**: `payload_length` vs `bytes.len()` precondition not enforced in
  the Rust API.

**Bug-catching potential**: **High** for GoAway/MaxPushId/CancelPush. A varint
encoding error in any of these frame types would directly affect HTTP/3 stream
and push lifecycle management.

**Effort estimate**: ~150–200 Lean lines for the three simple frame types. The
proof will require the varint round-trip lemmas from T23/VarIntRoundtrip.lean
(or their 1–4-byte sorry-free versions). No sorry expected for the in-scope
types. This is a clear Task 3 target for a future run.

---

## Gaps and Recommendations

### Highest-priority gaps (most likely to catch real bugs)

1. **VarIntRoundtrip 8-byte sorry** — Add `putU32_bytes_unchanged` lemma to
   `OctetsMut.lean`, which directly closes 2 sorry in `VarIntRoundtrip.lean`
   (the 8-byte encode↔decode round-trip and first-byte tag consistency).
   Low effort (~25 Lean lines), high value.

2. **PacketHeader full round-trip sorry** — Extend `PacketHeader.lean` with
   a byte-list model of DCID, SCID, token, and payload-length fields. This
   would close the `longHeader_roundtrip` sorry and formally verify the entire
   QUIC header serialisation path. Medium effort, very high value.

3. **RecvBuf: flow-control enforcement** — `highMark ≤ max_data` is advertised
   to the peer as the receive window. The model does not prove this bound is
   maintained. A violation could cause the peer to send more data than we
   budgeted for, leading to memory exhaustion.

4. **Write `FVSquad/VarIntTag.lean` for T30** — The informal spec is
   complete (`specs/varint_tag_informal.md`, run 83). Next step is Task 3:
   write the Lean file with 4 biconditional `varint_parse_len` range theorems,
   4 `varint_len` biconditionals, the universal tag consistency theorem, and
   non-overlap lemmas. ~120 lines, all `omega` proofs. No sorry expected.
   This also upgrades the existing one-directional `Varint.lean` lemmas to iff.

5. **Write `FVSquad/H3Frame.lean` for T31** — The informal spec is complete
   (`specs/h3_frame_informal.md`, run 82). Next step is Task 3: write the Lean
   file covering GoAway, MaxPushId, and CancelPush round-trips. ~150–200 lines;
   uses `VarIntRoundtrip.lean` lemmas. No sorry expected for in-scope types.
   Scope excludes Settings (partial round-trip) and 0-length frames (code TODO).

6. **StreamId↔StreamDo guard** — The `is_bidi && is_local` guard in
   `stream_do_send` (`quiche/src/lib.rs`) is not proved correct relative to
   RFC 9000 §2.1 stream-type classification.

### Moderate priority

7. **CUBIC: Reno-friendly transition** — W_cubic vs W_est comparison
   (RFC 8312bis §5.8) is unmodelled. This determines CUBIC's fairness to
   coexisting Reno flows.

8. **CidMgmt: retire_if_needed** — The auto-retire path for excess SCIDs
   is not modelled. Prove it maintains `activeCids ≤ active_connection_id_limit`
   (RFC 9000 §5.1.1).

9. **NewReno: AIMD composition** — Repeated ACK+loss cycles are not proved
   to converge. A multi-event induction would confirm AIMD steady-state.

### Observations on proof strength

- The **strongest** results (highest bug-catching potential): `decode_pktnum_correct`,
  `encode_decode_pktnum`, `emitN_le_maxData`, `newScid_seq_fresh`,
  `insertAny_inv`, `streamType_add_mul4`, `putU16_freeze_getU16`/
  `putU32_freeze_getU32`, `pktNumLen_k_coverage`, `retransmit_inv`, and
  `short_long_first_byte_differ`. These directly prove properties that, if
  violated, would cause protocol errors or data corruption.
- The **weakest** results are the `trivial` structural theorems (e.g., `new_*`
  postconditions checking struct field initialisation). Useful for baseline
  consistency but low bug-catching value.
- The **OQ-1 finding** (StreamPriorityKey antisymmetry) remains the only
  formal finding that diverges from a standard contract. Its impact is unclear
  without understanding whether the scheduler relies on antisymmetry; a
  maintainer response would be valuable.
- The **3 sorry** (2 in VarIntRoundtrip, 1 in PacketHeader) are all identified
  with clear resolutions: adding one lemma to OctetsMut.lean closes 2 of them;
  the third requires a richer buffer model.



---

## Paper Review

> *Assessment of `formal-verification/paper/paper.tex` as of run 84
> (2026-04-19). Paper is a 632-line ACM sigconf LaTeX draft.*

### Accuracy Issues (require correction before submission)

1. **Stale theorem count**: The abstract and Introduction claim **504
   theorems, 23 files, 2 sorry**. The current project state is **518
   theorems, 24 files, 3 sorry** (PacketHeader.lean added in run 81;
   VarIntRoundtrip.lean gained a third sorry). The theorem table in
   §3.1 does not include `PacketHeader.lean` at all.

2. **Missing `PacketHeader.lean` in Table 1**: The paper's proof-inventory
   table lists 23 files and totals 504 theorems. `PacketHeader.lean` (14
   theorems, run 81) is not present. It should be added to the Framing
   layer with key result `typeCode_roundtrip` / `short_long_first_byte_differ`.

3. **`PacketNumEncodeDecode.lean` key result mis-labelled**: Table 1 shows
   `encode_decode_inv` as the key result, but the actual theorem name in
   the code is `encode_decode_pktnum`. The abstract and Introduction mention
   the composition theorem but do not name it; §3 findings should add a
   `encode_decode_pktnum` highlight (parallel to the §A.3 decode result).

4. **Sorry count in abstract**: "502 of these theorems are fully sorry-free;
   2 sorry obligations remain" — should be "515 are sorry-free; 3 sorry remain"
   (2 in VarIntRoundtrip, 1 in PacketHeader).

5. **Conclusion future work**: "proving the QUIC packet-header encode/decode
   round-trip (T29, the next highest-priority target)" — T29 is now partially
   done (14 theorems in PacketHeader.lean). This sentence should be updated
   to describe what remains: the full byte-list round-trip sorry
   (`longHeader_roundtrip`), which requires a richer buffer model.

6. **Lean version**: Abstract and §2 say "Lean 4.29.0". The actual installed
   version (as reported by elan/CI) is **Lean 4.29.1**. Minor but should
   be consistent.

### Completeness Issues

7. **`encode_decode_pktnum` is a headline result** — The §3 findings section
   does not mention this theorem, even though it is arguably the second most
   important result in the project (it formally closes the encode↔decode
   composition for all four QUIC packet-number encoding lengths). It should
   be added as a named finding, parallel to the RFC §A.3 decode result.

8. **No pipeline metrics**: The paper describes a "five-phase pipeline" but
   gives no data on how many targets are in each phase, how long the pipeline
   takes, or what fraction of targets stall at which phase. A brief table
   in §3 would strengthen the methodology contribution.

9. **T30 and T31 informal specs not mentioned**: Runs 82–83 completed
   informal specs for T30 (Varint 2-bit tag) and T31 (H3 frame codec).
   The paper's §5 (Conclusion / Future Work) could mention these as the
   next verification targets, strengthening the forward-looking narrative.

### Intellectual Honesty Assessment

The paper is generally honest about its limitations (§4.2 Limitations
section is comprehensive). The correspondence audit result ("no mismatches
found") is accurately presented. The OQ-1 finding is correctly described
as intentional design.

One concern: the abstract says the proofs "cover core QUIC algorithms from
byte-level framing through congestion control and stream management" — this
is accurate for the proved targets, but neither HTTP/3 nor the async/tokio
layer is mentioned as out-of-scope. A single sentence clarifying that the
HTTP/3 layer is not yet covered (only the H3 frame informal spec exists)
would improve precision.

### Specific Actionable Fixes

| Issue | Priority | Fix |
|-------|----------|-----|
| Theorem/file/sorry counts | **High** | Update abstract, intro, table, conclusion to 518/24/3 |
| Missing PacketHeader.lean row | **High** | Add row to Table 1; update figure |
| `encode_decode_pktnum` finding | **High** | Add §3 subsection (analogous to RFC §A.3 subsection) |
| Sorry count "502/2" | **High** | Correct to "515/3" |
| Future work on T29 | **Medium** | Update to describe the `longHeader_roundtrip` sorry gap |
| Lean version "4.29.0" vs "4.29.1" | **Low** | Align with CI-reported version |
| HTTP/3 out-of-scope | **Low** | Add one sentence in §1 or §4.2 |

