# Informal Specification: QUIC Peer Stream-Count Limit Update and Query
<!-- 🔬 Lean Squad — T63 informal spec (run 152) -->

## Target

**T63 — QUIC Peer Stream-Count Limit Update Monotonicity**

- **Source**: `quiche/src/stream/mod.rs`
- **Functions**:
  - `StreamMap::update_peer_max_streams_bidi` (line ~529)
  - `StreamMap::update_peer_max_streams_uni` (line ~534)
  - `StreamMap::peer_streams_left_bidi` (line ~577)
  - `StreamMap::peer_streams_left_uni` (line ~588)
  - `StreamMap::get_or_create` stream-open count logic (line ~293)
- **Fields**: `peer_max_streams_bidi: u64`, `peer_max_streams_uni: u64`,
  `local_opened_streams_bidi: u64`, `local_opened_streams_uni: u64`

---

## Purpose

The QUIC RFC (RFC 9000 §4.6) requires that a peer's stream-count limit can
only be **raised**, never lowered. When a `MAX_STREAMS` frame arrives, the
receiver updates its recorded limit using `cmp::max`, ensuring monotone growth.

The `peer_streams_left_*` methods compute how many more streams the local
endpoint may open before hitting the peer's declared limit.

The stream-open code in `get_or_create` enforces the limit at the moment a
new stream is created: the running high-water mark `local_opened_streams_*` is
advanced to `max(current, stream_sequence + 1)`, and the new high-water mark is
rejected if it exceeds `peer_max_streams_*`.

---

## State model

```
peer_max_streams_bidi  : u64   -- peer's declared bidi stream count limit
peer_max_streams_uni   : u64   -- peer's declared uni  stream count limit
local_opened_streams_bidi : u64   -- high-water mark of bidi streams opened locally
local_opened_streams_uni  : u64   -- high-water mark of uni  streams opened locally
```

Invariant (asserted by the enforcement code but not explicitly tracked):
```
local_opened_streams_bidi ≤ peer_max_streams_bidi
local_opened_streams_uni  ≤ peer_max_streams_uni
```

---

## Preconditions

### `update_peer_max_streams_bidi(v)`
- `v : u64` — the value from a received `MAX_STREAMS (Bidi)` frame.
- No precondition on `v` (the RFC allows any u64; the implementation silently
  ignores decrements).

### `update_peer_max_streams_uni(v)`
- Symmetric to bidi.

### `peer_streams_left_bidi()`
- **Implicit precondition** (not enforced at call site, but required to avoid
  wraparound): `local_opened_streams_bidi ≤ peer_max_streams_bidi`.
  - If this invariant is violated, the u64 subtraction wraps to a very large
    value (Rust's u64 arithmetic is wrapping in release mode — this is a
    **latent underflow risk**).

### `peer_streams_left_uni()`
- Symmetric to bidi.

---

## Postconditions

### `update_peer_max_streams_bidi(v)`
```
post.peer_max_streams_bidi = max(pre.peer_max_streams_bidi, v)
```
Monotonicity: `post.peer_max_streams_bidi ≥ pre.peer_max_streams_bidi`
Absorb: if `v ≤ pre.peer_max_streams_bidi` then field is unchanged.
Update: if `v > pre.peer_max_streams_bidi` then field equals `v`.

### `peer_streams_left_bidi()`
```
result = peer_max_streams_bidi - local_opened_streams_bidi
```
Under the invariant: `result ≤ peer_max_streams_bidi`.
After an update that raised the limit by `Δ`, `peer_streams_left_bidi`
increases by at least `Δ`.

---

## Invariants

1. **Monotonicity of limit**: repeated calls to `update_peer_max_streams_bidi`
   with arbitrary values never decrease `peer_max_streams_bidi`.

2. **Idempotence**: calling `update_peer_max_streams_bidi(v)` twice with the
   same `v` produces the same state as calling it once.

3. **Commutativity**: `update(v1)` then `update(v2)` leaves the same state as
   `update(v2)` then `update(v1)` (since max is commutative).

4. **Count invariant** (post stream-open enforcement): every successful
   `get_or_create` call on a locally-initiated stream advances
   `local_opened_streams_*` to at most `peer_max_streams_*`. Therefore at all
   times `local_opened_streams_* ≤ peer_max_streams_*`.

5. **High-water-mark semantics**: `local_opened_streams_bidi` records
   `max(sequence + 1)` over all locally-opened bidi streams. It never
   decreases.

---

## Edge Cases

- `v = 0`: `update_peer_max_streams_bidi(0)` when `peer_max_streams_bidi > 0`
  is a no-op (max ignores the lower value). When both are 0 it is also a no-op.
- `v = u64::MAX`: sets the limit to `u64::MAX`, effectively removing it.
- **Underflow in `peer_streams_left_bidi`**: if `local_opened_streams_bidi >
  peer_max_streams_bidi` (which the enforcement code prevents under normal
  operation), the subtraction wraps. This is a safety property we should prove
  cannot occur given the enforcement invariant.
- Rapid stream opening close to the limit: the high-water-mark update using
  `cmp::max` means that opening stream ID 8 (sequence = 2) when sequence = 1
  is already recorded leaves `local_opened_streams_bidi = 3` even though only
  two streams have been opened (sparse stream IDs are counted by max sequence,
  not by number of open streams). This is correct per RFC 9000.

---

## Examples

1. Initial: `peer_max = 100`, `local_opened = 0`.
   - `update(50)` → `peer_max = 100` (no change; 50 < 100).
   - `update(150)` → `peer_max = 150` (raised to 150).
   - `peer_streams_left = 150 − 0 = 150`.

2. `peer_max = 10`, `local_opened = 8`.
   - `peer_streams_left = 2`.
   - Open two more streams (sequences 8, 9 → local_opened becomes 10).
   - `peer_streams_left = 0`.
   - Attempt to open another → `get_or_create` returns `StreamLimit`.

3. `peer_max = 5`, `local_opened = 5`.
   - `update(5)` → `peer_max = 5` (idempotent).
   - `update(4)` → `peer_max = 5` (monotone, ignores decrease).
   - `update(6)` → `peer_max = 6`, `peer_streams_left = 1`.

---

## Inferred Intent

The design follows RFC 9000 §4.6: "Endpoints MUST NOT exceed the limit set by
their peer. An endpoint that receives a frame with a stream ID exceeding the
limit it has set MUST treat this as a connection error of type STREAM_LIMIT_ERROR."

The `cmp::max` in `update_peer_max_streams_*` is a direct implementation of the
RFC requirement that stream count limits are monotone. The high-water-mark
approach in `get_or_create` is slightly surprising (it counts *sequences* ever
opened, not simultaneously open streams), but is the correct interpretation of
the RFC's stream ID space.

---

## Open Questions

1. **OQ-T63-1**: Is there a runtime assertion or invariant check that
   `local_opened_streams_* ≤ peer_max_streams_*`? If not, what prevents the
   `peer_streams_left_*` underflow from being triggered by a race condition or
   by code that bypasses `get_or_create`?

2. **OQ-T63-2**: Does `peer_streams_left_bidi` return a saturating value or
   `Option<u64>` at higher levels of the API? At the `StreamMap` level it is
   bare wrapping arithmetic.

3. **OQ-T63-3**: The RFC says stream IDs 0, 4, 8, … are the bidi streams
   opened by the client. The `stream_sequence = id >> 2` computation is correct
   but means sparse stream IDs (e.g., opening ID 40 before ID 4) consume limit
   budget in a non-obvious way. Is this the intended semantics?

---

## Proposed Lean Properties (T63 → FVSquad/StreamCountLimit.lean)

```lean
-- Monotonicity of limit update
theorem update_mono (limit v : Nat) :
    updatePeerMaxStreams limit v ≥ limit

-- Idempotence
theorem update_idem (limit v : Nat) :
    updatePeerMaxStreams (updatePeerMaxStreams limit v) v =
    updatePeerMaxStreams limit v

-- Commutativity
theorem update_comm (limit v1 v2 : Nat) :
    updatePeerMaxStreams (updatePeerMaxStreams limit v1) v2 =
    updatePeerMaxStreams (updatePeerMaxStreams limit v2) v1

-- Safety: if invariant holds, peer_streams_left ≥ 0 (no underflow)
-- (trivially true in Lean where subtraction is saturating, but meaningful
--  as a model of the unsafe Rust u64 behaviour under the invariant)
theorem streams_left_no_underflow (limit opened : Nat)
    (h : opened ≤ limit) : limit - opened ≥ 0

-- After update, streams_left increases by the raise amount
theorem streams_left_after_update (limit opened v : Nat)
    (h : opened ≤ limit) (hv : v > limit) :
    (updatePeerMaxStreams limit v) - opened = v - opened

-- Count invariant: stream open respects limit (enforcement correctness)
-- For all sequences seq: get_or_create succeeds only if seq + 1 ≤ peer_max
theorem open_respects_limit (opened limit seq : Nat)
    (h : opened ≤ limit) (hok : seq + 1 ≤ limit) :
    Nat.max opened (seq + 1) ≤ limit
```

These properties are all provable by `omega` or `simp + omega` — fully
decidable or arithmetic, no complex induction needed.
