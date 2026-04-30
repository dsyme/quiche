-- Copyright (C) 2025, Cloudflare, Inc.
-- BSD-2-Clause licence (same as quiche)
--
-- Formal specification of `Frame::ack_eliciting` and `Frame::probing`
-- from `quiche/src/frame.rs`.
--
-- Target T42: ack_eliciting / probing predicates
--
-- Model covers:
--   • An abstract `FrameKind` enum mirroring all variants in `Frame`
--   • `ackEliciting`: true for all frame kinds EXCEPT Padding, ACK,
--     ApplicationClose, ConnectionClose (matches the `!matches!` pattern)
--   • `probing`: true only for Padding, NewConnectionId, PathChallenge,
--     PathResponse (matches the `matches!` pattern)
--
-- Omitted (documented):
--   • Payload fields of each frame (not relevant to these predicates)
--   • Encoding/decoding logic
--   • QLOG serialization

namespace FrameAckEliciting

-- ─── Frame kind enum ───────────────────────────────────────────────────────

inductive FrameKind where
  | Padding
  | Ping
  | ACK
  | ResetStream
  | StopSending
  | Crypto
  | NewToken
  | Stream
  | MaxData
  | MaxStreamData
  | MaxStreamsBidi
  | MaxStreamsUni
  | DataBlocked
  | StreamDataBlocked
  | StreamsBlockedBidi
  | StreamsBlockedUni
  | NewConnectionId
  | RetireConnectionId
  | PathChallenge
  | PathResponse
  | ConnectionClose
  | ApplicationClose
  | Datagram
  deriving DecidableEq, Repr, Inhabited

-- ─── Predicates ────────────────────────────────────────────────────────────

-- Mirrors `Frame::ack_eliciting` (quiche/src/frame.rs:L814)
-- Returns false only for Padding, ACK, ApplicationClose, ConnectionClose.
def ackEliciting (k : FrameKind) : Bool :=
  match k with
  | .Padding          => false
  | .ACK              => false
  | .ApplicationClose => false
  | .ConnectionClose  => false
  | _                 => true

-- Mirrors `Frame::probing` (quiche/src/frame.rs:L825)
-- Returns true only for Padding, NewConnectionId, PathChallenge, PathResponse.
def probing (k : FrameKind) : Bool :=
  match k with
  | .Padding           => true
  | .NewConnectionId   => true
  | .PathChallenge     => true
  | .PathResponse      => true
  | _                  => false

-- ─── Theorems ──────────────────────────────────────────────────────────────

-- 1. Exact characterisation of non-ack-eliciting frames
theorem ackEliciting_false_iff (k : FrameKind) :
    ackEliciting k = false ↔
    k = .Padding ∨ k = .ACK ∨ k = .ApplicationClose ∨ k = .ConnectionClose := by
  cases k <;> simp [ackEliciting]

-- 2. Exact characterisation of ack-eliciting frames
theorem ackEliciting_true_iff (k : FrameKind) :
    ackEliciting k = true ↔
    ¬ (k = .Padding ∨ k = .ACK ∨ k = .ApplicationClose ∨ k = .ConnectionClose) := by
  cases k <;> simp [ackEliciting]

-- 3. Exact characterisation of probing frames
theorem probing_true_iff (k : FrameKind) :
    probing k = true ↔
    k = .Padding ∨ k = .NewConnectionId ∨ k = .PathChallenge ∨ k = .PathResponse := by
  cases k <;> simp [probing]

-- 4. Exact characterisation of non-probing frames
theorem probing_false_iff (k : FrameKind) :
    probing k = false ↔
    ¬ (k = .Padding ∨ k = .NewConnectionId ∨ k = .PathChallenge ∨ k = .PathResponse) := by
  cases k <;> simp [probing]

-- 5. Spot-checks: non-ack-eliciting frames
theorem padding_not_ack_eliciting  : ackEliciting .Padding = false          := rfl
theorem ack_not_ack_eliciting      : ackEliciting .ACK = false              := rfl
theorem appclose_not_ack_eliciting : ackEliciting .ApplicationClose = false := rfl
theorem connclose_not_ack_eliciting: ackEliciting .ConnectionClose = false  := rfl

-- 6. Spot-checks: ack-eliciting frames
theorem ping_ack_eliciting         : ackEliciting .Ping = true              := rfl
theorem stream_ack_eliciting       : ackEliciting .Stream = true            := rfl
theorem crypto_ack_eliciting       : ackEliciting .Crypto = true            := rfl
theorem reset_stream_ack_eliciting : ackEliciting .ResetStream = true       := rfl
theorem new_token_ack_eliciting    : ackEliciting .NewToken = true          := rfl
theorem max_data_ack_eliciting     : ackEliciting .MaxData = true           := rfl
theorem datagram_ack_eliciting     : ackEliciting .Datagram = true          := rfl

-- 7. Spot-checks: probing frames
theorem padding_probing            : probing .Padding = true                := rfl
theorem new_cid_probing            : probing .NewConnectionId = true        := rfl
theorem path_challenge_probing     : probing .PathChallenge = true          := rfl
theorem path_response_probing      : probing .PathResponse = true           := rfl

-- 8. Spot-checks: non-probing frames
theorem ping_not_probing           : probing .Ping = false                  := rfl
theorem stream_not_probing         : probing .Stream = false                := rfl
theorem ack_not_probing            : probing .ACK = false                   := rfl
theorem crypto_not_probing         : probing .Crypto = false                := rfl

-- 9. Key relationship: most probing-only frames ARE ack-eliciting
-- (PathChallenge, PathResponse, NewConnectionId are ack-eliciting AND probing)
theorem path_challenge_is_ack_eliciting : ackEliciting .PathChallenge = true := rfl
theorem path_response_is_ack_eliciting  : ackEliciting .PathResponse = true  := rfl
theorem new_cid_is_ack_eliciting        : ackEliciting .NewConnectionId = true := rfl

-- 10. Exception: Padding is the only frame that is BOTH non-ack-eliciting and probing
theorem padding_both_non_ack_and_probing :
    ackEliciting .Padding = false ∧ probing .Padding = true := by decide

-- 11. Exhaustive enumeration: count of non-ack-eliciting kinds = 4
theorem count_non_ack_eliciting :
    (List.filter (fun k => !ackEliciting k)
      [.Padding, .Ping, .ACK, .ResetStream, .StopSending, .Crypto, .NewToken,
       .Stream, .MaxData, .MaxStreamData, .MaxStreamsBidi, .MaxStreamsUni,
       .DataBlocked, .StreamDataBlocked, .StreamsBlockedBidi, .StreamsBlockedUni,
       .NewConnectionId, .RetireConnectionId, .PathChallenge, .PathResponse,
       .ConnectionClose, .ApplicationClose, .Datagram]).length = 4 := by decide

-- 12. Exhaustive enumeration: count of probing kinds = 4
theorem count_probing :
    (List.filter (fun k => probing k)
      [.Padding, .Ping, .ACK, .ResetStream, .StopSending, .Crypto, .NewToken,
       .Stream, .MaxData, .MaxStreamData, .MaxStreamsBidi, .MaxStreamsUni,
       .DataBlocked, .StreamDataBlocked, .StreamsBlockedBidi, .StreamsBlockedUni,
       .NewConnectionId, .RetireConnectionId, .PathChallenge, .PathResponse,
       .ConnectionClose, .ApplicationClose, .Datagram]).length = 4 := by decide

-- 13. All 23 frame kinds have a definite Boolean value for ackEliciting
theorem ackEliciting_total (k : FrameKind) :
    ackEliciting k = true ∨ ackEliciting k = false := by
  cases (ackEliciting k) <;> simp

-- 14. All 23 frame kinds have a definite Boolean value for probing
theorem probing_total (k : FrameKind) :
    probing k = true ∨ probing k = false := by
  cases (probing k) <;> simp

-- 15. The non-ack-eliciting set and probing set overlap exactly at Padding
theorem non_ack_eliciting_and_probing_intersection :
    ∀ k : FrameKind,
      ackEliciting k = false ∧ probing k = true ↔ k = .Padding := by
  intro k; cases k <;> simp [ackEliciting, probing]

end FrameAckEliciting
