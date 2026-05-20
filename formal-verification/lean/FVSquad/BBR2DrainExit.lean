-- Copyright (C) 2024, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — T75: BBR2 Drain Exit Condition
--
-- Target T75: BBR2DrainExit
-- Source: quiche/src/recovery/gcongestion/bbr2/drain.rs
--   on_congestion_event (lines 62–86)
--   drain_target (lines 117–118)
--   network_model.rs: bdp0/bdp1/bdp (lines 265–275)
-- Phase: 5 — Implementation + Proofs
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- Models the drain-exit decision:
--   drain_target = bdp0 = max_bandwidth × min_rtt_ns / 1_000_000_000
--   shouldExitDrain = bytes_in_flight ≤ drain_target
--   If shouldExitDrain → transition to ProbeBW; else stay in Drain.
--
-- The BDP (bandwidth-delay product) is modelled as a Nat (bytes).
-- Bandwidth and RTT are also Nats (bits/s and nanoseconds respectively);
-- BDP = bw × rtt_ns / 1_000_000_000.
--
-- Approximations / omissions:
--   * f32 floating-point in Rust is replaced by exact Nat arithmetic (floor).
--   * Mode transitions (into_probe_bw) are not modelled; only the guard is.
--   * inflight_lo, pacing-gain updates on entry are not modelled here.
--   * bytes_in_flight comes from the congestion event; its provenance is not
--     modelled.
--
-- Theorems (17 total, 0 sorry):
--   1.  shouldExitDrain_iff
--   2.  shouldExitDrain_zero_bif
--   3.  shouldExitDrain_at_bdp
--   4.  shouldExitDrain_below_bdp
--   5.  stayInDrain_iff
--   6.  stayInDrain_above_bdp
--   7.  exitDrain_monotone_bif
--   8.  exitDrain_monotone_bdp
--   9.  stayInDrain_anti_monotone_bdp
--   10. bdp_monotone_bw
--   11. bdp_monotone_rtt
--   12. bdp_zero_bw
--   13. bdp_zero_rtt
--   14. exitDrain_bw_increase
--   15. exitDrain_rtt_increase
--   16. exitDrain_or_stay_exhaustive
--   17. exitBoundary_is_inflight_eq_bdp_or_less

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  Types and definitions
-- ─────────────────────────────────────────────────────────────────────────────

namespace FVSquad.BBR2DrainExit

/-- State relevant to the drain-exit guard. -/
structure DrainState where
  /-- Current bytes in flight (from congestion event). -/
  bytes_in_flight : Nat
  /-- The BDP target: `bdp0 = max_bw × min_rtt / 1_000_000_000` (floor). -/
  bdp0 : Nat
  deriving Repr

/-- The drain exit decision: exit Drain iff `bytes_in_flight ≤ bdp0`.
    Source: `drain.rs` on_congestion_event line 73–75. -/
def shouldExitDrain (s : DrainState) : Bool :=
  s.bytes_in_flight <= s.bdp0

/-- Compute `bdp0` from bandwidth (bits/s) and min RTT (nanoseconds).
    Uses floor division to match Nat semantics.
    Source: `network_model.rs` bdp/bdp0 (lines 265–274). -/
def computeBdp (bw_bps : Nat) (min_rtt_ns : Nat) : Nat :=
  bw_bps * min_rtt_ns / 1_000_000_000

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  Theorems about shouldExitDrain
-- ─────────────────────────────────────────────────────────────────────────────

/-- `shouldExitDrain` is equivalent to `bytes_in_flight ≤ bdp0`.
    Exact characterisation of the guard. -/
theorem shouldExitDrain_iff (s : DrainState) :
    shouldExitDrain s = true ↔ s.bytes_in_flight ≤ s.bdp0 := by
  simp [shouldExitDrain]

/-- When bytes_in_flight = 0, the drain exit condition always holds. -/
theorem shouldExitDrain_zero_bif (bdp : Nat) :
    shouldExitDrain { bytes_in_flight := 0, bdp0 := bdp } = true := by
  simp [shouldExitDrain]

/-- When bytes_in_flight = bdp0, the exit condition holds (≤ is reflexive). -/
theorem shouldExitDrain_at_bdp (v : Nat) :
    shouldExitDrain { bytes_in_flight := v, bdp0 := v } = true := by
  simp [shouldExitDrain]

/-- When bytes_in_flight < bdp0, the exit condition holds. -/
theorem shouldExitDrain_below_bdp (byif bdp : Nat) (h : byif < bdp) :
    shouldExitDrain { bytes_in_flight := byif, bdp0 := bdp } = true := by
  simp [shouldExitDrain]
  omega

/-- We stay in Drain iff `bytes_in_flight > bdp0`. -/
theorem stayInDrain_iff (s : DrainState) :
    shouldExitDrain s = false ↔ s.bytes_in_flight > s.bdp0 := by
  simp only [shouldExitDrain]
  constructor
  · intro h; simp at h; omega
  · intro h; simp; omega

/-- When bytes_in_flight strictly exceeds bdp0, we stay in Drain. -/
theorem stayInDrain_above_bdp (byif bdp : Nat) (h : byif > bdp) :
    shouldExitDrain { bytes_in_flight := byif, bdp0 := bdp } = false := by
  simp [shouldExitDrain]
  omega

/-- Monotone in bytes_in_flight (decreasing): if we exit drain with `byif`,
    we also exit with any `byif' ≤ byif`. -/
theorem exitDrain_monotone_bif (byif byif' bdp : Nat)
    (hexit : shouldExitDrain { bytes_in_flight := byif, bdp0 := bdp } = true)
    (hle : byif' ≤ byif) :
    shouldExitDrain { bytes_in_flight := byif', bdp0 := bdp } = true := by
  simp [shouldExitDrain] at *
  omega

/-- Monotone in bdp (increasing): if we exit drain with `bdp`,
    we also exit with any `bdp' ≥ bdp`. -/
theorem exitDrain_monotone_bdp (byif bdp bdp' : Nat)
    (hexit : shouldExitDrain { bytes_in_flight := byif, bdp0 := bdp } = true)
    (hge : bdp' ≥ bdp) :
    shouldExitDrain { bytes_in_flight := byif, bdp0 := bdp' } = true := by
  simp [shouldExitDrain] at *
  omega

/-- Anti-monotone in bdp for stayInDrain: if we stay with `bdp`,
    we also stay with any `bdp' ≤ bdp`. -/
theorem stayInDrain_anti_monotone_bdp (byif bdp bdp' : Nat)
    (hstay : shouldExitDrain { bytes_in_flight := byif, bdp0 := bdp } = false)
    (hle : bdp' ≤ bdp) :
    shouldExitDrain { bytes_in_flight := byif, bdp0 := bdp' } = false := by
  simp [shouldExitDrain] at *
  omega

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  Theorems about computeBdp
-- ─────────────────────────────────────────────────────────────────────────────

/-- `computeBdp` is monotone in bandwidth: higher bandwidth → larger BDP. -/
theorem bdp_monotone_bw (bw bw' rtt : Nat) (h : bw ≤ bw') :
    computeBdp bw rtt ≤ computeBdp bw' rtt := by
  simp only [computeBdp]
  apply Nat.div_le_div_right
  exact Nat.mul_le_mul_right rtt h

/-- `computeBdp` is monotone in RTT: higher min_rtt → larger BDP. -/
theorem bdp_monotone_rtt (bw rtt rtt' : Nat) (h : rtt ≤ rtt') :
    computeBdp bw rtt ≤ computeBdp bw rtt' := by
  simp only [computeBdp]
  apply Nat.div_le_div_right
  exact Nat.mul_le_mul_left bw h

/-- Zero bandwidth → BDP = 0. -/
theorem bdp_zero_bw (rtt : Nat) : computeBdp 0 rtt = 0 := by
  simp [computeBdp]

/-- Zero RTT → BDP = 0. -/
theorem bdp_zero_rtt (bw : Nat) : computeBdp bw 0 = 0 := by
  simp [computeBdp]

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Derived theorems: how bandwidth/RTT changes affect exit decision
-- ─────────────────────────────────────────────────────────────────────────────

/-- Increasing bandwidth widens the drain exit condition:
    if we exit drain with bandwidth `bw`, we also exit with `bw' ≥ bw`. -/
theorem exitDrain_bw_increase (byif bw bw' rtt : Nat)
    (hexit : shouldExitDrain { bytes_in_flight := byif,
                                bdp0 := computeBdp bw rtt } = true)
    (hge : bw' ≥ bw) :
    shouldExitDrain { bytes_in_flight := byif,
                      bdp0 := computeBdp bw' rtt } = true :=
  exitDrain_monotone_bdp byif (computeBdp bw rtt) (computeBdp bw' rtt)
    hexit (bdp_monotone_bw bw bw' rtt hge)

/-- Increasing RTT widens the drain exit condition:
    if we exit drain with RTT `rtt`, we also exit with `rtt' ≥ rtt`. -/
theorem exitDrain_rtt_increase (byif bw rtt rtt' : Nat)
    (hexit : shouldExitDrain { bytes_in_flight := byif,
                                bdp0 := computeBdp bw rtt } = true)
    (hge : rtt' ≥ rtt) :
    shouldExitDrain { bytes_in_flight := byif,
                      bdp0 := computeBdp bw rtt' } = true :=
  exitDrain_monotone_bdp byif (computeBdp bw rtt) (computeBdp bw rtt')
    hexit (bdp_monotone_rtt bw rtt rtt' hge)

-- ─────────────────────────────────────────────────────────────────────────────
-- §5  Completeness and boundary theorems
-- ─────────────────────────────────────────────────────────────────────────────

/-- Every drain state is either an exit or a stay — no undefined cases. -/
theorem exitDrain_or_stay_exhaustive (s : DrainState) :
    shouldExitDrain s = true ∨ shouldExitDrain s = false := by
  cases shouldExitDrain s <;> simp

/-- Exact boundary: the drain exit condition holds iff byif ≤ bdp0.
    Equivalently: the inflight threshold is exactly bdp0 (tight characterisation). -/
theorem exitBoundary_is_inflight_eq_bdp_or_less (byif bdp : Nat) :
    shouldExitDrain { bytes_in_flight := byif, bdp0 := bdp } = true
    ↔ byif ≤ bdp := by
  simp [shouldExitDrain]

end FVSquad.BBR2DrainExit
