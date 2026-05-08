# FV Targets — quiche

> 🔬 *Maintained by Lean Squad automated formal verification.*

## Priority Order

| # | Target | Location | Phase | Status | Notes |
|---|--------|----------|-------|--------|-------|
| 1 | QUIC varint codec | `octets/src/lib.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 10 theorems; PR #5 merged |
| 2 | `RangeSet` invariants | `quiche/src/ranges.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 14 theorems incl. `insert_preserves_invariant`; PR #22 merged |
| 3 | Minmax filter | `quiche/src/minmax.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 15 theorems; PR #15 merged |
| 4 | RTT estimation | `quiche/src/recovery/rtt.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 24 theorems incl. `adjusted_rtt_ge_min_rtt`; `FVSquad/RttStats.lean` |
| 5 | Flow control | `quiche/src/flowcontrol.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 22 theorems; `FVSquad/FlowControl.lean`; informal spec in `specs/flowcontrol_informal.md` |
| 6 | Congestion window (NewReno) | `quiche/src/recovery/congestion/reno.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 13 theorems incl. `cwnd_floor_new_event`, `single_halving`; `FVSquad/NewReno.lean` |
| 7 | DatagramQueue | `quiche/src/dgram.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 26 theorems; capacity invariant, byte-size tracking, FIFO ordering; `FVSquad/DatagramQueue.lean` |
| 8 | PRR (Proportional Rate Reduction) | `quiche/src/recovery/congestion/prr.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 20 theorems; RFC 6937 rate bound, SSRB bounds; `FVSquad/PRR.lean` |
| 9 | Packet number decode (RFC 9000 §A.3) | `quiche/src/packet.rs` | 5 — Proofs | ✅ Complete | **0 sorry** — 24 theorems; `decode_pktnum_correct` fully proved (run 39); `FVSquad/PacketNumDecode.lean` |
| 10 | CUBIC congestion control | `quiche/src/recovery/congestion/cubic.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 26 theorems; RFC 8312bis constants, ssthresh reduction, W_cubic algebraic properties, fast convergence; `FVSquad/Cubic.lean` |
| 11 | `RangeBuf` offset arithmetic | `quiche/src/range_buf.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 19 theorems; maxOff invariance under consume, split adjacency, partition; `FVSquad/RangeBuf.lean` |
| 12 | `RecvBuf` stream reassembly | `quiche/src/stream/recv_buf.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 59 theorems; emitN+insertContiguous+insertAny invariant preservation; `insertAny_inv` proves full out-of-order write correctness; `FVSquad/RecvBuf.lean`; informal spec in `specs/stream_recv_buf_informal.md` |
| 13 | `SendBuf` stream send buffer | `quiche/src/stream/send_buf.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 43 theorems; flow-control safety, invariant preservation, FIN consistency; `FVSquad/SendBuf.lean` |
| 14 | Connection ID sequence management | `quiche/src/cid.rs` | 5 — All Proofs | ✅ Done | 21 theorems, 0 sorry; specs/cid_mgmt_informal.md; FVSquad/CidMgmt.lean |
| 15 | Stream priority ordering (`StreamPriorityKey::cmp`) | `quiche/src/stream/mod.rs` | 5 — Proofs | ✅ Done | **0 sorry** — 21 theorems + 7 examples; OQ-1 `Ord` antisymmetry violation proved; `FVSquad/StreamPriorityKey.lean` |
| 16 | `OctetsMut` byte-buffer read/write | `octets/src/lib.rs` | 5 — Proofs ✅ | ✅ Done (run 63) | Cursor-based byte buffer; round-trip, invariant preservation; `FVSquad/OctetsMut.lean` (27 public + 6 private theorems, 0 sorry). Fixed in run 63: Mathlib-only `split_ifs` replaced with `by_cases`; file added to FVSquad.lean manifest. |
| 17 | `Octets` (read-only) byte-buffer | `octets/src/lib.rs` | 5 — Proofs ✅ | ✅ Done (run 62) | Read-only cursor; invariant, getU8/16/32/64, skip/rewind, big-endian decode; `FVSquad/Octets.lean` (48 theorems + 9 examples, 0 sorry) |
| 18 | StreamId RFC 9000 §2.1 arithmetic | `quiche/src/stream/mod.rs` + `lib.rs` | 5 — Proofs | ✅ Done (run 64) | 35 theorems + 8 examples, 0 sorry; PR #51 merged |
| 19 | Octets↔OctetsMut cross-module round-trip | `octets/src/lib.rs` | 5 — Proofs | ✅ Done (run 65) | 20 theorems + 9 examples, 0 sorry; PR #52 merged |
| 20 | `pkt_num_len` / `encode_pkt_num` length selection | `quiche/src/packet.rs` | 5 — Proofs | ✅ Done (run 66) | 20 theorems + 10 examples, 0 sorry; `FVSquad/PacketNumLen.lean` |
| 21 | `SendBuf::retransmit` — retransmit model | `quiche/src/stream/send_buf.rs` | 5 — Proofs | ✅ Done (run 68) | 17 theorems + 10 examples, 0 sorry; `FVSquad/SendBufRetransmit.lean` |
| 22 | `RecvBuf` flow-control bound (`highMark ≤ max_data`) | `quiche/src/stream/recv_buf.rs` | 0 | ⬜ Identified | Gap #2 from CRITIQUE.md; see specs/recv_buf_flowcontrol_informal.md (planned) |
| 23 | `put_varint` → `get_varint` cross-module round-trip | `octets/src/lib.rs` | 5 | ✅ Done (run 75-77) | 8 theorems, 0 sorry; `FVSquad/VarIntRoundtrip.lean` |
| 24 | `encode_pkt_num` → `decode_pkt_num` composition | `quiche/src/packet.rs` | 5 | ✅ Done (run 76) | 10 theorems, 0 sorry; `FVSquad/PacketNumEncodeDecode.lean` |
| 25 | `StreamId`↔`stream_do_send` guard correctness | `quiche/src/lib.rs` | 0 | ⬜ Identified | Gap #6 from CRITIQUE.md; RFC 9000 §2.1 stream-direction guard |
| 26 | CUBIC W_cubic vs W_est Reno-friendly transition | `quiche/src/recovery/congestion/cubic.rs` | 0 | ⬜ Identified | RFC 8312bis §5.8; Cubic.lean already models W_cubic; add W_est and the comparison predicate |
| 27 | `CidMgmt::retire_if_needed` path | `quiche/src/cid.rs` | 0 | ⬜ Identified | Prove auto-retire keeps active-CID count ≤ `active_conn_id_limit` (RFC 9000 §5.1.1) |
| 28 | NewReno multi-cycle AIMD convergence | `quiche/src/recovery/congestion/reno.rs` | 0 | ⬜ Identified | Prove repeated ACK+loss cycles converge to steady AIMD window; extends NewReno.lean |
| 29 | QUIC packet-header encode/decode round-trip | `quiche/src/packet.rs` | 4 | 🔄 Implementation | `FVSquad/PacketHeader.lean` (run 81): 14 theorems, 1 sorry (`longHeader_roundtrip`); full byte-list model needed to close sorry |
| 30 | Varint 2-bit tag consistency | `octets/src/lib.rs` | 5 | ✅ Done | `FVSquad/VarIntTag.lean` (run 85): 15 theorems, 0 sorry; `varint_tag_consistency` + no-overlap lemmas fully proved |
| 31 | H3 frame type codec round-trip | `quiche/src/h3/frame.rs` | 2 | 📝 Informal Spec | `specs/h3_frame_informal.md` (run 82); scope: GoAway/MaxPushId/CancelPush single-varint frames; open questions OQ-T31-1 to OQ-T31-4 |
| 32 | BBR2 pacing rate bounds | `quiche/src/recovery/gcongestion/bbr2.rs` | 0 | ⬜ Identified | Pacing rate ≤ btl_bw * gain; first FV of gcongestion module; see RESEARCH.md T32 |
| 33 | H3 Settings frame invariants | `quiche/src/h3/frame.rs` | 5 | ✅ Done (run 114) | `specs/h3_settings_informal.md` (run 86); boolean constraints, size guard, GREASE RT loss, H3_DATAGRAM double-emit; open questions OQ-T33-1 to OQ-T33-4 |
| 34 | QPACK static table lookup | `quiche/src/h3/qpack/` | 1 | 🔬 Researched | Pure lookup table ~30 Lean lines; all `decide`; run 87 research added |
| 35 | H3 `parse_settings_frame` RFC compliance | `quiche/src/h3/frame.rs` | 2 | 📝 Informal Spec | `specs/parse_settings_frame_informal.md` (run 115); reserved-ID rejection, boolean validation, size guard; OQ-T35-1 to OQ-T35-4 |
| 36 | `Bandwidth` arithmetic invariants | `quiche/src/recovery/bandwidth.rs` | 1 | 🔬 Researched | gcongestion module; all `omega`; ~40 Lean lines; run 88/89 research |
| 37 | `BytesInFlight` counter state-machine invariant | `quiche/src/recovery/bytes_in_flight.rs` | 1 | 🔬 Researched | `bytes > 0 ↔ interval_start.is_some()`; MEDIUM; run 88/89 research |
| 47 | PMTUD binary-search probe_size invariant | `quiche/src/pmtud.rs` | 5 | ✅ Done (run 129) | `FVSquad/Pmtud.lean` (run 129): 12 theorems, 0 sorry; probe_size ∈ [MIN_PLPMTU, max_mtu], binary-search convergence, narrowing, midpoint bounds |
| 48 | HyStart++ RTT threshold clamp + CSS growth divisor | `quiche/src/recovery/congestion/hystart.rs` | 2 | 📝 Informal Spec (run 129) | `specs/hystart_informal.md`; clamp to [4ms, 16ms], css_cwnd_inc monotonicity, css_round_count bounds; ~10 thms, omega |

## Phase Definitions

| Phase | Name | Description |
|-------|------|-------------|
| 0 | Identified | Added to this list |
| 1 | Research | Surveyed; benefit, tractability, approach documented in RESEARCH.md |
| 2 | Informal Spec | `specs/<name>_informal.md` written |
| 3 | Lean Spec | Lean 4 file with type definitions, theorem statements, and implementation model |
| 4 | Implementation | Lean functional model with implementation details extracted |
| 5 | Proofs | Key theorems proved (or counterexamples found) — 0 sorry |

## Next Actions

1. **Route-B tests (T20)** — ✅ Done in run 89.
   `formal-verification/tests/pkt_num_len/` (18/18 PASS):
   Rust bit-counting vs Lean threshold model verified on all QUIC-valid inputs.
2. **Target 36: Bandwidth arithmetic** *(HIGH, easy)* — All `omega`, ~40 Lean lines.
   Key theorems: `bandwidth_zero_le`, `bandwidth_bytes_roundtrip`, `bandwidth_bits_roundtrip`,
   `bandwidth_add_bits`, `bandwidth_ord_iff`. No Mathlib needed.
3. **Target 31: H3 frame codec round-trip** *(HIGH)* — Informal spec done (run 82).
   Next: write `FVSquad/H3Frame.lean` with GoAway/MaxPushId/CancelPush round-trips.
   OQ-T31-1 to OQ-T31-4 document open questions.
4. **Target 33: H3 Settings frame invariants** *(HIGH)* — Informal spec done (run 86).
   Next: write `FVSquad/H3Settings.lean` with key invariants and RFC constraints.
   OQ-T33-1 to OQ-T33-4 document open questions.
5. **Target 34: QPACK static table lookup** *(LOW effort)* — Pure lookup table;
   provable via `decide`; ~30 Lean lines; closes first QPACK gap.
6. **Target 35: `parse_settings_frame` RFC compliance** *(MEDIUM)* — Prove H2-key
   rejection using case analysis; builds on T33 informal spec.
7. **Target 37: `BytesInFlight` counter invariant** *(MEDIUM)* — State-machine proof;
   `bytes > 0 ↔ interval_start.is_some()`; MEDIUM complexity.
8. **Target 29: Packet-header full roundtrip** *(MEDIUM)* — `PacketHeader.lean` at
   Phase 4 (14 theorems, 1 sorry). Closing `longHeader_roundtrip` requires a
   byte-list buffer model of `encode_pkt_num` + `decode_pkt_num`.
9. **Target 25: StreamId↔stream_do_send guard correctness** — Prove the
   `is_bidi && is_local` guard selects exactly the RFC 9000 §2.1 send-allowed IDs.
10. **Target 26: CUBIC Reno-friendly transition** *(MEDIUM)* — Extend
    `Cubic.lean` with `W_est` model and `cwnd_after_ack_ge_west` theorem.
11. **Target 22: RecvBuf flow-control bound** — Prove `highMark ≤ max_data`
    is maintained by the receive buffer write path.

## Archived / Completed Targets

| # | Target | Phase | PR | Notes |
|---|--------|-------|----|-------|
| 1 | QUIC varint codec | 5 — All Proofs | PR #5 (merged) | round_trip + 9 others; 0 sorry |
| 2 | RangeSet invariants | 5 — All Proofs | PR #22 (merged) | insert_preserves_invariant + 13 others; 0 sorry |
| 3 | Minmax filter | 5 — All Proofs | PR #15 (merged) | 15 theorems; 0 sorry |
| 7 | PRR (Proportional Rate Reduction) | 5 — All Proofs | pending | 20 theorems; 0 sorry |
| 18 | StreamId RFC 9000 §2.1 arithmetic | 5 — All Proofs | run 64 | 35 theorems; 0 sorry |
| 19 | Octets↔OctetsMut cross-module round-trip | 5 — All Proofs | run 65 | 20 theorems + 9 examples; 0 sorry |

---

## New Targets (Run 126)

### Target 46: `idle_timeout` Negotiation

**Phase**: 1 — Identified (research done)  
**Location**: `quiche/src/lib.rs:8757` — `fn idle_timeout()`  
**Priority**: ⭐⭐ HIGH  

RFC 9000 §10.1.1: effective idle timeout = `min(local, peer)` when both
nonzero; fallback to the single nonzero value; then clamp to `max(t, 3*pto)`.

**Key properties**:
- Negotiated timeout ≤ both local and peer values (neither surprised)
- Commutativity: `negotiate(a, b) = negotiate(b, a)`
- None ↔ both are 0
- Final value ≥ 3 × PTO

**Next action**: Write `FVSquad/IdleTimeout.lean` (Task 3+5).

---

### Target 47: PMTUD Binary Search Invariant

**Phase**: 1 — Identified (research done)  
**Location**: `quiche/src/pmtud.rs` — `fn update_probe_size()` and friends  
**Priority**: ⭐ MEDIUM  

Binary search between `largest_successful_probe_size` and
`smallest_failed_probe_size`; probe_size = midpoint when both known.

**Key properties**:
- `probe_size ≤ maximum_supported_mtu` always
- Binary search pivot: `probe_size = (successful + failed) / 2`
- PMTU found ↔ `failed - successful ≤ 1`

**Next action**: Write `FVSquad/Pmtud.lean` (Task 3+5).

---

## New Targets (Run 130)

### Target 48: HyStart++ RTT-threshold clamp + CSS divisor invariant

**Phase**: 5 — All Proofs Done (this run)  
**Location**: `quiche/src/recovery/congestion/hystart.rs`  
**Priority**: ⭐⭐ HIGH  

HyStart++ transitions slow start → CSS → CA. The key purely-computable
properties are:

1. **RTT threshold clamping**: `rtt_thresh = clamp(last/8, 4ms, 16ms)` — bounded
   to [MIN_RTT_THRESH, MAX_RTT_THRESH] regardless of input.
2. **css_cwnd_inc divisor**: exactly `pkt_size / CSS_GROWTH_DIVISOR (=4)`.
3. **Monotonicity**: both functions are monotone in their inputs.
4. **Constant sanity**: CSS_ROUNDS = 5, divisor > 0, MIN ≤ MAX.

**Lean file**: `FVSquad/Hystart.lean` — 13 theorems, 0 sorry, `lake build` ✅

**Next action**: Route-B correspondence tests (Task 8).

---

### Target 49: WindowedFilter ordering invariant

**Phase**: 1 — Identified (research done)  
**Location**: `quiche/src/recovery/gcongestion/bbr/windowed_filter.rs`  
**Priority**: ⭐⭐ HIGH  

Implements Kathleen Nichols' algorithm for windowed min/max estimation using
three samples (best, second-best, third-best). Key invariant: after any
sequence of `reset`/`update` calls, the sample values satisfy
`estimates[0] ≥ estimates[1] ≥ estimates[2]` (value ordering) and the
timestamps satisfy `time[0] ≤ time[1] ≤ time[2]` (recency ordering).

**Key properties**:
- `reset(v, t)` → all three estimates equal `(v, t)` (trivially verifiable)
- `clear()` → all estimates are `None`
- `get_best()` = `Some(estimates[0].sample)` after any update
- Value monotonicity: `best ≥ second_best ≥ third_best` (ordering invariant)
- After reset, all get_* methods return `Some(same_value)`

**Specification size**: ~15 theorems; `reset` and `clear` trivial by `rfl/decide`,
ordering invariant requires inductive case analysis over `update`.

**Proof tractability**: reset/clear trivially provable; ordering invariant
tractable but requires a small model of the update function using `rcases`.

**Approximations needed**: Abstract away `Instant` using abstract `time : Nat`
parameter; model as maximizing filter (concrete use in BBR).

**Next action**: Write `formal-verification/specs/windowed_filter_informal.md` (Task 2),
then `FVSquad/WindowedFilter.lean` (Task 3+5).

---

### Target 50: RFC 9000 §18.1 Reserved Transport Parameter IDs

**Phase**: 5 — Proofs complete (run 132)
**Location**: `quiche/src/transport_params.rs` (`is_reserved`)
**Priority**: ⭐⭐ MEDIUM

`is_reserved()` checks whether a transport parameter ID belongs to the
RFC 9000 §18.1 reserved arithmetic progression {31*N+27 : N ≥ 0}.

**Key properties**:
- `isReserved(id) ↔ id % 31 = 27` for `id ≥ 27` (RFC 9000 §18.1 compliance)
- Every element of the progression is detected (`isReserved_progression`)
- No non-progression element is detected (`isReserved_gap`)
- Two distinct reserved IDs differ by ≥ 31 (`isReserved_spacing`)

**Lean file**: `FVSquad/TransportParamReserved.lean` — 15 theorems, 0 sorry, `lake build` ✅

---

### Target 55: BBR2 Startup Exit — `full_bandwidth_reached` Monotonicity

**Phase**: 1 — Research (run 138)
**Location**: `quiche/src/recovery/gcongestion/bbr2/network_model.rs`
  (`has_bandwidth_growth`, `check_persistent_queue`, `full_bandwidth_reached`)
**Priority**: ⭐⭐⭐ HIGH

BBR2 exits startup mode when `full_bandwidth_reached` is set by either:
(a) `rounds_without_bandwidth_growth >= startup_full_bw_rounds` AND not
app-limited, or (b) `rounds_with_queueing >= max_startup_queue_rounds`.

**Key properties**:
- `full_bandwidth_reached` is monotone (set-only, never cleared after setting)
- Counter bounds: growth counter and queue counter bounded at trigger threshold
- Threshold trigger correctness (both paths)

**Specification size**: ~12–15 theorems, ~60 Lean lines.

**Proof tractability**: LOW–MEDIUM — all `omega`/`simp`; monotonicity by
structural induction on state transitions.

**Approximations needed**: Abstract `Bandwidth` as `Nat`; ignore
`full_bandwidth_baseline` internals; treat `is_app_limited` as `Bool` parameter.

**Next action**: Write `formal-verification/specs/bbr2_startup_exit_informal.md`
(Task 2), then `FVSquad/BBR2StartupExit.lean` (Task 3+5).

---

### Target 56: Loss Detection Packet Threshold Bounds (RFC 9002 §6.1)

**Phase**: 1 — Research (run 138)
**Location**: `quiche/src/recovery/mod.rs`
  (`INITIAL_PACKET_THRESHOLD`, `MAX_PACKET_THRESHOLD`, `pkt_thresh()`)
**Priority**: ⭐⭐ MEDIUM

Packet-loss threshold adapts in `[3, 20]` per RFC 9002 §6.1. A threshold
outside this range causes missed loss detection or spurious retransmits.

**Key properties**:
- `pkt_thresh` initially equals 3
- `pkt_thresh` always in `[3, 20]`
- Adaptation is non-decreasing until saturated at 20

**Specification size**: ~10–12 theorems, ~50 Lean lines.

**Proof tractability**: LOW — all `omega` on bounded `Nat`.

**Approximations needed**: Treat threshold as `Nat` bounded counter;
ignore time threshold (floating-point).

**Next action**: Write `FVSquad/LossDetectionThreshold.lean` (Task 3+5).

---

### Target 57: BBR2 ProbeBW Phase Cycle Ordering

**Phase**: 1 — Research (run 138)
**Location**: `quiche/src/recovery/gcongestion/bbr2/probe_bw.rs`
  (phase transitions)
**Priority**: ⭐⭐ MEDIUM

ProbeBW cycles through 4 sub-phases in a fixed order. Phase transition bugs
would cause incorrect pacing/probing behaviour.

**Key properties**:
- `nextPhase` maps only valid transitions (Down→Cruise→Refill→Up→Down)
- No self-loops; Down reachable within 3 steps from any phase
- All properties are `decide`-provable on 4-element enum

**Specification size**: ~8–10 theorems, ~40 Lean lines.

**Proof tractability**: TRIVIAL — all `decide`.

**Approximations needed**: Abstract cwnd/bandwidth; model phase label only.

**Next action**: Write `FVSquad/ProbeBWPhase.lean` (Task 3+5).


---

### Target 58: QUIC Stream Limit Enforcement

**Phase**: 1 — Research (run 142)
**Location**: `quiche/src/stream/mod.rs`, `quiche/src/lib.rs`
**Priority**: ⭐⭐⭐ HIGH

QUIC connections enforce limits on the number of concurrent streams
(`max_streams_bidi`, `max_streams_uni`). Incorrect enforcement could allow
stream exhaustion attacks or break the RFC 9000 §4.6 invariant.

**Key properties**:
- Stream ID assignment is monotonically increasing
- Never exceed the negotiated `max_streams` limit
- `streams_blocked` is raised iff the limit is reached
- Peer-initiated vs. local-initiated counts stay disjoint (even/odd ID split)

**Specification size**: ~12 theorems, ~60 Lean lines.

**Proof tractability**: MEDIUM — omega-provable once modelled as Nat counters.

**Approximations needed**: Model stream table as a `Finset` of IDs; ignore
per-stream flow control (covered separately).

**Next action**: Write informal spec, then `FVSquad/StreamLimit.lean` (Task 2+3).

---

### Target 59: QUIC Transport Error Code Mapping

**Phase**: 1 — Research (run 142)
**Location**: `quiche/src/lib.rs` (`Error` enum), `quiche/src/ffi.rs`
**Priority**: ⭐⭐ MEDIUM

The `Error` enum maps QUIC transport errors to Rust error variants and to
wire-format error codes. An incorrect mapping would cause RFC 9000 non-compliance.

**Key properties**:
- `Error::to_wire()` is injective (no two variants map to the same code)
- Every wire code returned is a valid QUIC transport error code (≤ 0x1c)
- Round-trip: `from_wire(to_wire(e)) = Some(e)` for all defined variants

**Specification size**: ~8 theorems, ~50 Lean lines.

**Proof tractability**: TRIVIAL — `decide` on a finite enum.

**Approximations needed**: Model only the named QUIC error codes; crypto-level
TLS alerts use a different mapping (excluded).

**Next action**: Write `FVSquad/TransportErrorCode.lean` (Task 3+5 — immediately).

---

### Target 60: BBR2 ProbeRTT State Machine

**Phase**: 1 — Research (run 142)
**Location**: `quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs`
**Priority**: ⭐⭐ MEDIUM

ProbeRTT periodically reduces cwnd to probe min-RTT. The state machine has
a timing invariant: ProbeRTT mode must be held for at least `PROBE_RTT_DURATION`
before exiting.

**Key properties**:
- Enter condition: min_rtt estimate expired AND not already in ProbeRTT
- Exit condition: held for ≥ `PROBE_RTT_DURATION` AND inflight ≤ probe_rtt_cwnd
- `cwnd_during_probe_rtt` ≤ regular cwnd (cwnd reduction guaranteed)
- No re-entry during the hold period

**Specification size**: ~10 theorems, ~55 Lean lines.

**Proof tractability**: MEDIUM — requires modelling `Instant` as abstract Nat ticks.

**Approximations needed**: Time represented as monotone Nat counter; f32 RTT
stored as Nat microseconds; cwnd as Nat bytes.

**Next action**: Write informal spec first (Task 2).
