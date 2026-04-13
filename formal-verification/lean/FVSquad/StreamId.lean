-- Copyright (C) 2018-2024, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of QUIC stream ID arithmetic and
-- stream-credit accounting from RFC 9000 §2.1 and §4.6.
--
-- Source: quiche/src/stream/mod.rs (is_bidi, is_local, peer_streams_left_*)
--         quiche/src/lib.rs (stream_do_send stream-type guards)
--
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- Approximations / abstractions:
--   - Bitwise AND (& 0x1, & 0x2) is modelled via modular arithmetic:
--     (id & 1) ≡ id % 2, (id & 2) ≡ (id / 2) % 2.
--     Equivalence holds for all Nat because Nat binary ↔ decimal agrees.
--   - Stream IDs are Nat (unbounded); u64 overflow is not modelled.
--   - Credit arithmetic models `peer_streams_left_bidi/uni` as Nat subtraction;
--     the invariant `localOpened ≤ peerMax` is encoded as a structure field.
--   - Only the pure classification and credit-accounting functions are proved.
--     Stream lifecycle (open/close/reset) is out of scope.

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §1  Core predicates
--     Mirrors `is_bidi` and `is_local` in quiche/src/stream/mod.rs.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- A stream ID is bidirectional iff bit 1 is clear (id & 0x2 == 0).
    Equivalently, (id % 4) ∈ {0, 1}.
    Mirrors `is_bidi` in quiche/src/stream/mod.rs:837-838. -/
def isBidi (id : Nat) : Bool := id % 4 < 2

/-- A stream ID was initiated by the server iff bit 0 is set (id & 0x1 == 1).
    Equivalently, id is odd.
    Mirrors `is_local(id, true)` in quiche/src/stream/mod.rs:832-833. -/
def isServerInit (id : Nat) : Bool := id % 2 == 1

/-- The RFC 9000 §2.1 stream type: lower 2 bits of the stream ID.
      0 = client-initiated bidi
      1 = server-initiated bidi
      2 = client-initiated uni
      3 = server-initiated uni -/
def streamType (id : Nat) : Nat := id % 4

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §2  Peer-stream credit model
--     Mirrors `peer_streams_left_bidi` / `peer_streams_left_uni`
--     in quiche/src/stream/mod.rs:577-591, and
--     `update_peer_max_streams_bidi/uni` at lines 529-535.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Invariant-carrying model of the peer stream credit state.
    `localOpened` is the number of streams we have opened so far;
    `peerMax`     is the peer-advertised limit (MAX_STREAMS).
    The `inv` field encodes `local_opened_streams ≤ peer_max_streams`. -/
structure StreamCredits where
  localOpened : Nat
  peerMax     : Nat
  inv         : localOpened ≤ peerMax

/-- Remaining streams that can be opened before hitting the peer's limit.
    Mirrors `peer_max_streams_bidi - local_opened_streams_bidi`. -/
def streamsLeft (s : StreamCredits) : Nat := s.peerMax - s.localOpened

/-- Open one new stream: consume one credit.
    Requires `localOpened < peerMax` (i.e., at least one credit remains). -/
def openStream (s : StreamCredits) (h : s.localOpened < s.peerMax) :
    StreamCredits :=
  { localOpened := s.localOpened + 1
    peerMax     := s.peerMax
    inv         := h }

/-- Peer sends MAX_STREAMS update. The new limit is `max` of old and new.
    Mirrors `update_peer_max_streams_bidi`:
      `self.peer_max_streams_bidi = cmp::max(self.peer_max_streams_bidi, v)`. -/
def updatePeerMax (s : StreamCredits) (newMax : Nat) : StreamCredits :=
  let m := Nat.max s.peerMax newMax
  { localOpened := s.localOpened
    peerMax     := m
    inv         := Nat.le_trans s.inv (Nat.le_max_left s.peerMax newMax) }

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §3  Helper lemmas (private)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

private theorem mod4_lt4 (n : Nat) : n % 4 < 4 := Nat.mod_lt n (by omega)

private theorem mod4_add4 (n : Nat) : (n + 4) % 4 = n % 4 := by omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §4  Stream type classification
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- The stream type is always one of exactly 4 values. -/
theorem streamType_range (id : Nat) : streamType id < 4 := mod4_lt4 id

/-- isBidi is true iff the stream type is 0 or 1 (lower 2 bits < 2). -/
theorem isBidi_iff_type_lt2 (id : Nat) : isBidi id = true ↔ streamType id < 2 := by
  simp [isBidi, streamType]

/-- isServerInit is true iff the stream type is odd (1 or 3). -/
theorem isServerInit_iff_type_odd (id : Nat) :
    isServerInit id = true ↔ streamType id % 2 = 1 := by
  simp [isServerInit, streamType]

/-- Bidirectional streams have even type codes (0 or 1 = even index ≡ bit1=0). -/
theorem isBidi_iff_even_type (id : Nat) :
    isBidi id = true ↔ streamType id < 2 := isBidi_iff_type_lt2 id

/-- Unidirectional streams have type codes 2 or 3. -/
theorem notBidi_iff_type_ge2 (id : Nat) : isBidi id = false ↔ 2 ≤ streamType id := by
  simp [isBidi, streamType]

/-- Every stream ID has a well-defined, unique type in {0,1,2,3}. -/
theorem streamType_complete (id : Nat) :
    streamType id = 0 ∨ streamType id = 1 ∨ streamType id = 2 ∨
    streamType id = 3 := by
  simp only [streamType]
  omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §5  Canonical first stream IDs (RFC 9000 Table 1)
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

theorem type_client_bidi_0 : streamType 0 = 0 := by native_decide
theorem type_server_bidi_1 : streamType 1 = 1 := by native_decide
theorem type_client_uni_2  : streamType 2 = 2 := by native_decide
theorem type_server_uni_3  : streamType 3 = 3 := by native_decide

theorem isBidi_0  : isBidi 0 = true  := by native_decide
theorem isBidi_1  : isBidi 1 = true  := by native_decide
theorem isBidi_2  : isBidi 2 = false := by native_decide
theorem isBidi_3  : isBidi 3 = false := by native_decide

theorem isServerInit_0 : isServerInit 0 = false := by native_decide
theorem isServerInit_1 : isServerInit 1 = true  := by native_decide
theorem isServerInit_2 : isServerInit 2 = false := by native_decide
theorem isServerInit_3 : isServerInit 3 = true  := by native_decide

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §6  Stream type is preserved under +4 increments
--
--     RFC 9000 §2.1: "Stream IDs of the same type are created in increasing
--     order" — consecutive stream IDs of the same type differ by 4.
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- Adding 4 to a stream ID preserves its type (lower 2 bits). -/
theorem streamType_add4 (id : Nat) : streamType (id + 4) = streamType id := by
  simp [streamType, mod4_add4]

/-- Adding 4 preserves `isBidi`. -/
theorem isBidi_add4 (id : Nat) : isBidi (id + 4) = isBidi id := by
  have h : (id + 4) % 4 = id % 4 := by omega
  simp only [isBidi, h]

/-- Adding 4 preserves `isServerInit`. -/
theorem isServerInit_add4 (id : Nat) : isServerInit (id + 4) = isServerInit id := by
  have h : (id + 4) % 2 = id % 2 := by omega
  simp only [isServerInit, h]

/-- Adding any multiple of 4 preserves the stream type. -/
theorem streamType_add_mul4 (id k : Nat) :
    streamType (id + 4 * k) = streamType id := by
  induction k with
  | zero => simp [streamType]
  | succ n ih =>
    have step : id + 4 * (n + 1) = (id + 4 * n) + 4 := by omega
    rw [step, streamType_add4, ih]

/-- Streams `id` and `id + 4*k` have the same `isBidi` value. -/
theorem isBidi_add_mul4 (id k : Nat) : isBidi (id + 4 * k) = isBidi id := by
  have h : (id + 4 * k) % 4 = id % 4 := by omega
  simp only [isBidi, h]

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §7  Mutual exclusion between stream types
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- No stream is simultaneously bidirectional and unidirectional. -/
theorem bidi_xor_uni (id : Nat) : ¬(isBidi id = true ∧ isBidi id = false) :=
  fun ⟨h1, h2⟩ => by simp [h1] at h2

/-- A stream cannot be initiated by both client and server. -/
theorem serverInit_xor_clientInit (id : Nat) :
    ¬(isServerInit id = true ∧ isServerInit id = false) :=
  fun ⟨h1, h2⟩ => by simp [h1] at h2

/-- If two stream IDs have the same type, they are congruent mod 4. -/
theorem same_type_iff_cong4 (a b : Nat) :
    streamType a = streamType b ↔ a % 4 = b % 4 := by
  simp [streamType]

/-- Distinct stream types imply the stream IDs are not congruent mod 4. -/
theorem distinct_type_ne_mod4 (a b : Nat) (h : streamType a ≠ streamType b) :
    a % 4 ≠ b % 4 := by
  simp [streamType] at h
  exact h

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §8  Peer stream credit theorems
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

/-- `streamsLeft` is zero when all credits are used. -/
theorem streamsLeft_zero_iff (s : StreamCredits) :
    streamsLeft s = 0 ↔ s.localOpened = s.peerMax := by
  have hinv := s.inv
  simp [streamsLeft]
  omega

/-- Opening one stream reduces `streamsLeft` by exactly 1. -/
theorem openStream_dec (s : StreamCredits) (h : s.localOpened < s.peerMax) :
    streamsLeft (openStream s h) + 1 = streamsLeft s := by
  have hinv := s.inv
  simp [openStream, streamsLeft]
  omega

/-- `streamsLeft` is always ≤ `peerMax`. -/
theorem streamsLeft_le_peerMax (s : StreamCredits) :
    streamsLeft s ≤ s.peerMax := by
  simp [streamsLeft]

/-- After `openStream`, `localOpened` strictly increases. -/
theorem openStream_localOpened_inc (s : StreamCredits) (h : s.localOpened < s.peerMax) :
    (openStream s h).localOpened = s.localOpened + 1 := rfl

/-- `updatePeerMax` never decreases the limit. -/
theorem updatePeerMax_mono (s : StreamCredits) (newMax : Nat) :
    s.peerMax ≤ (updatePeerMax s newMax).peerMax := by
  simp only [updatePeerMax]
  exact Nat.le_max_left s.peerMax newMax

/-- When `newMax > peerMax`, `updatePeerMax` strictly increases `streamsLeft`. -/
theorem updatePeerMax_grows_left (s : StreamCredits) (newMax : Nat)
    (h : s.peerMax < newMax) : streamsLeft s < streamsLeft (updatePeerMax s newMax) := by
  have hinv := s.inv
  simp [updatePeerMax, streamsLeft]
  have hmax : Nat.max s.peerMax newMax = newMax :=
    Nat.max_eq_right (Nat.le_of_lt h)
  rw [hmax]
  omega

/-- `updatePeerMax` preserves the `localOpened` count. -/
theorem updatePeerMax_localOpened (s : StreamCredits) (newMax : Nat) :
    (updatePeerMax s newMax).localOpened = s.localOpened := rfl

/-- After opening and then receiving a MAX_STREAMS update that restores headroom,
    the limit is the updated one and there is capacity again. -/
theorem openThenUpdate_has_capacity (s : StreamCredits)
    (hopen : s.localOpened < s.peerMax) (newMax : Nat)
    (hnew  : (openStream s hopen).localOpened < newMax) :
    0 < streamsLeft (updatePeerMax (openStream s hopen) newMax) := by
  -- Reduce (openStream s hopen).localOpened to s.localOpened + 1
  have hopen_eq : (openStream s hopen).localOpened = s.localOpened + 1 := rfl
  rw [hopen_eq] at hnew
  -- newMax ≤ max(peerMax, newMax)
  have hmax : newMax ≤ Nat.max s.peerMax newMax := Nat.le_max_right s.peerMax newMax
  have hpm : s.peerMax ≤ Nat.max s.peerMax newMax := Nat.le_max_left s.peerMax newMax
  simp only [updatePeerMax, openStream, streamsLeft]
  omega

-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
-- §9  Quick sanity checks
-- ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

example : streamsLeft ⟨0, 10, by omega⟩ = 10 := by native_decide
example : streamsLeft ⟨7, 10, by omega⟩ = 3  := by native_decide
example : streamsLeft ⟨10, 10, by omega⟩ = 0 := by native_decide

-- Streams 0,4,8,... are all client-initiated bidi.
example : isBidi 8 = true   := by native_decide
example : isBidi 12 = true  := by native_decide
-- Streams 2,6,10,... are all client-initiated uni.
example : isBidi 10 = false := by native_decide
-- Streams 1,5,9,... are server-initiated bidi.
example : isServerInit 9 = true  := by native_decide
-- Streams 0,4,8,... are client-initiated.
example : isServerInit 8 = false := by native_decide
