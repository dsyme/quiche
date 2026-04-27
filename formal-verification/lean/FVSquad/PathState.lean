-- Copyright (C) 2025, Cloudflare, Inc.
-- BSD-2-Clause licence (same as quiche)
--
-- Formal specification of `PathState` from `quiche/src/path.rs`.
--
-- Target T38: PathState monotone progression (RFC 9000 §8.2)
--
-- Model covers:
--   • The five-state ordered enum: Failed < Unknown < Validating
--     < ValidatingMTU < Validated
--   • `promote_to`: monotone (never decreases state)
--   • `on_challenge_sent`: promotes to Validating
--   • `on_response_received`: promotes to ValidatingMTU then optionally Validated
--   • `on_failed_validation`: resets to Failed (intentional non-monotone step)
--
-- Omitted (documented):
--   • All Path struct fields beyond `state` (timers, challenge queues, PMTUD)
--   • Network I/O and SocketAddr handling
--   • MTU probing detail: `mtu_ok` abstracts the `max_challenge_size` threshold
--   • PathMap management and multi-path logic

namespace PathState

-- ─── State enum ────────────────────────────────────────────────────────────

inductive State where
  | Failed
  | Unknown
  | Validating
  | ValidatingMTU
  | Validated
  deriving DecidableEq, Repr, Inhabited

-- Canonical rank, matching Rust's `#[derive(PartialOrd, Ord)]` order.
def State.rank : State → Nat
  | .Failed        => 0
  | .Unknown       => 1
  | .Validating    => 2
  | .ValidatingMTU => 3
  | .Validated     => 4

-- Named Boolean comparators — avoids typeclass-instance simp loops.
def State.le (a b : State) : Bool := a.rank ≤ b.rank
def State.lt (a b : State) : Bool := a.rank < b.rank

-- ─── Operations ────────────────────────────────────────────────────────────

-- Mirrors `Path::promote_to` in `quiche/src/path.rs:L340`:
-- "Promotes the path to the provided state only if the new state is greater."
def promote_to (current new : State) : State :=
  if current.rank < new.rank then new else current

-- Mirrors `Path::on_challenge_sent` (L392)
def on_challenge_sent (s : State) : State :=
  promote_to s .Validating

-- Mirrors `Path::on_response_received` (L421-L453):
-- promotes to ValidatingMTU; `mtu_ok` encodes whether
-- `max_challenge_size ≥ MIN_CLIENT_INITIAL_LEN`.
def on_response_received (s : State) (mtu_ok : Bool) : State :=
  let s1 := promote_to s .ValidatingMTU
  if mtu_ok then promote_to s1 .Validated else s1

-- Mirrors `Path::on_failed_validation` (L455): hard reset, not monotone.
def on_failed_validation : State := .Failed

-- Boolean predicate mirroring `Path::working` (L308): state > Failed.
def working (s : State) : Bool := 0 < s.rank

-- ─── Theorems ──────────────────────────────────────────────────────────────
-- All proved by exhaustive case analysis (`cases s <;> cases t <;> rfl` or
-- `decide`). Each case reduces to a concrete Nat comparison closed by `rfl`.

-- 1. `rank` is injective: distinct states have distinct ranks
theorem rank_injective : ∀ a b : State, a.rank = b.rank → a = b := by
  intro a b h; cases a <;> cases b <;> simp_all [State.rank]

-- 2. The rank ordering is a linear (total) order on State
theorem rank_le_total (a b : State) : a.rank ≤ b.rank ∨ b.rank ≤ a.rank := by
  cases a <;> cases b <;> simp [State.rank]

theorem rank_le_antisymm (a b : State)
    (hab : a.rank ≤ b.rank) (hba : b.rank ≤ a.rank) : a = b :=
  rank_injective a b (Nat.le_antisymm hab hba)

theorem rank_le_trans (a b c : State)
    (hab : a.rank ≤ b.rank) (hbc : b.rank ≤ c.rank) : a.rank ≤ c.rank :=
  Nat.le_trans hab hbc

-- 3. `promote_to` is monotone: result rank ≥ current rank
theorem promote_to_ge_current (s t : State) :
    s.rank ≤ (promote_to s t).rank := by
  cases s <;> cases t <;> simp [promote_to, State.rank]

-- 4. `promote_to` selects the larger of the two states
theorem promote_to_ge_target (s t : State) (h : s.rank ≤ t.rank) :
    promote_to s t = t := by
  cases s <;> cases t <;> simp_all [promote_to, State.rank]

theorem promote_to_stays_if_ge (s t : State) (h : t.rank ≤ s.rank) :
    promote_to s t = s := by
  cases s <;> cases t <;> simp_all [promote_to, State.rank]

-- 5. `promote_to` is idempotent
theorem promote_to_idempotent (s t : State) :
    promote_to (promote_to s t) t = promote_to s t := by
  cases s <;> cases t <;> rfl

-- 6. `promote_to` never strictly lowers the state
theorem promote_to_not_lower (s t : State) :
    ¬ ((promote_to s t).rank < s.rank) := by
  cases s <;> cases t <;> simp [promote_to, State.rank]

-- 7. `on_challenge_sent` produces state ≥ Validating
theorem challenge_sent_ge_validating (s : State) :
    State.Validating.rank ≤ (on_challenge_sent s).rank := by
  cases s <;> simp [on_challenge_sent, promote_to, State.rank]

-- 8. `on_challenge_sent` never lowers the state
theorem challenge_sent_monotone (s : State) :
    s.rank ≤ (on_challenge_sent s).rank :=
  promote_to_ge_current s .Validating

-- 9. `on_response_received` produces state ≥ ValidatingMTU
theorem response_received_ge_validatingMTU (s : State) (mtu_ok : Bool) :
    State.ValidatingMTU.rank ≤ (on_response_received s mtu_ok).rank := by
  cases s <;> cases mtu_ok <;> simp [on_response_received, promote_to, State.rank]

-- 10. When `mtu_ok = true`, state always reaches Validated
theorem response_mtu_ok_validated (s : State) :
    on_response_received s true = .Validated := by
  cases s <;> rfl

-- 11. `on_response_received` never lowers the state
theorem response_received_monotone (s : State) (mtu_ok : Bool) :
    s.rank ≤ (on_response_received s mtu_ok).rank := by
  cases s <;> cases mtu_ok <;> simp [on_response_received, promote_to, State.rank]

-- 12. Concrete normal validation path
-- Unknown → challenge_sent → Validating
theorem normal_path_challenge_sent :
    on_challenge_sent .Unknown = .Validating := rfl

-- Validating → response_received (mtu_ok) → Validated
theorem normal_path_response_mtu_ok :
    on_response_received .Validating true = .Validated := rfl

-- Validating → response_received (no mtu) → ValidatingMTU
theorem normal_path_response_mtu_fail :
    on_response_received .Validating false = .ValidatingMTU := rfl

-- 13. `on_failed_validation` resets to Failed
theorem failed_validation_is_failed : on_failed_validation = .Failed := rfl

-- 14. `working` is true iff state ≠ Failed
theorem working_iff_rank_pos (s : State) : working s = true ↔ 0 < s.rank := by
  simp [working]

theorem working_iff_not_failed (s : State) : working s = true ↔ s ≠ .Failed := by
  cases s <;> simp [working, State.rank]

-- 15. Validated is always working
theorem validated_is_working : working .Validated = true := rfl

-- 16. `on_challenge_sent` always produces a working state
theorem challenge_sent_working (s : State) : working (on_challenge_sent s) = true := by
  cases s <;> rfl

-- 17. `promote_to` from a working state stays working
theorem promote_to_working_stays_working (s t : State)
    (hs : working s = true) : working (promote_to s t) = true := by
  cases s <;> cases t <;> simp_all [working, promote_to, State.rank]

-- 18. Full validation path: Unknown →(challenge)→ Validating →(response, mtu_ok)→ Validated
theorem full_validation_path :
    on_response_received (on_challenge_sent .Unknown) true = .Validated := rfl

-- 19. Concrete spot-checks (each reduces to rfl by computation)
example : promote_to .Failed .Validated = .Validated := rfl
example : promote_to .Validating .Unknown = .Validating := rfl
example : promote_to .ValidatingMTU .Validating = .ValidatingMTU := rfl
example : on_challenge_sent .Failed = .Validating := rfl
example : on_response_received .ValidatingMTU false = .ValidatingMTU := rfl
example : on_response_received .ValidatingMTU true = .Validated := rfl
example : on_challenge_sent .Validated = .Validated := rfl
example : working .Unknown = true := rfl
example : working .Failed = false := rfl

end PathState
