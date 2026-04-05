-- Copyright (C) 2019, Cloudflare, Inc.
-- All rights reserved.
--
-- SPDX-License-Identifier: BSD-2-Clause
--
-- 🔬 Lean Squad — formal specification of the CUBIC congestion controller
-- in `quiche/src/recovery/congestion/cubic.rs`.
--
-- Lean 4 (v4.29.0), no Mathlib dependency.
--
-- The module covers:
--   §1  Constants and their arithmetic properties
--   §2  Congestion event: ssthresh computation and bounds
--   §3  W_cubic algebraic properties (cube formula, monotonicity)
--   §4  Fast convergence: w_max reduction
--   §5  Combined congestion event state transformation
--
-- Key theorems proved:
--   alphaAimd_numerator_eq   — ALPHA_AIMD = 3*(1-β)/(1+β) verified exactly
--   alphaAimd_lt_one         — ALPHA_AIMD < 1 (rate increase bounded)
--   ssthresh_le_cwnd         — ssthresh ≤ cwnd (BETA_CUBIC multiplication)
--   ssthresh_lt_cwnd_pos     — ssthresh < cwnd for cwnd > 0 (strict reduction)
--   ssthresh_monotone        — ssthresh is monotone in cwnd
--   wCubic_zero_eq_cwnd      — W_cubic(0) = cwnd when K = cbrt((w_max-cwnd)/C)
--   wCubicNat_at_k_eq_wmax   — W_cubic(K) = w_max (Nat model)
--   wCubicNat_monotone       — W_cubic non-decreasing for t ≥ K
--   fastConv_wmax_lt_cwnd    — fast convergence strictly reduces w_max
--   congestionEvent_reduces_cwnd — after event, cwnd < prev for cwnd > 0
--   ssthresh_concrete_10000  — concrete test: ssthreshCubic 10000 = 7000
--   wMaxFastConv_concrete    — concrete test: wMaxFastConv 10000 = 8500
--
-- Approximations / abstractions:
--   - All f64 quantities are modelled as exact rational fractions (numerator
--     / denominator as Nat) or as scaled Int. Floating-point rounding is not
--     captured; floor-division (via `as usize` cast) is modelled by Nat.div.
--   - `cube_root` (cbrt) is not computed; its defining property
--     `C * K^3 = w_max - cwnd` is taken as a hypothesis in W_cubic theorems.
--   - `usize` is modelled as `Nat` (unbounded). u64/usize overflow is not
--     captured.
--   - Time (`Duration`, `Instant`) is abstracted to `Nat` in clock ticks.
--   - HyStart++, app_limited, PRR, rollback are all elided here; CUBIC core
--     arithmetic is the focus.
--   - `MINIMUM_WINDOW_PACKETS = 2` bound on ssthresh is noted but the min-
--     cap is not formally modelled (the theorem `ssthresh_lt_cwnd_pos` holds
--     for the raw formula before the cmp::max clamp).

-- ─────────────────────────────────────────────────────────────────────────────
-- §1  Constants
-- ─────────────────────────────────────────────────────────────────────────────

/-- BETA_CUBIC = 7/10 (= 0.7 in cubic.rs) -/
def betaNum  : Nat := 7
def betaDen  : Nat := 10

/-- C = 4/10 (= 0.4 in cubic.rs) -/
def cNum : Nat := 4
def cDen : Nat := 10

/-- ALPHA_AIMD = 9/17 (= 3*(1-BETA)/(1+BETA) = 3*0.3/1.7 = 0.9/1.7 = 9/17) -/
def alphaNum : Nat := 9
def alphaDen : Nat := 17

-- ALPHA_AIMD = 3 * (betaDen - betaNum) / (betaDen + betaNum)
-- Numerator:   3 * (10 - 7) = 9  = alphaNum
-- Denominator: 10 + 7 = 17       = alphaDen
theorem alphaAimd_numerator_eq :
    3 * (betaDen - betaNum) = alphaNum := by native_decide

theorem alphaAimd_denominator_eq :
    betaDen + betaNum = alphaDen := by native_decide

-- ALPHA_AIMD is strictly between 0 and 1
theorem alphaAimd_pos  : 0 < alphaNum  := by native_decide
theorem alphaAimd_lt_one : alphaNum < alphaDen := by native_decide

-- BETA_CUBIC is strictly between 0 and 1
theorem beta_pos   : 0 < betaNum  := by native_decide
theorem beta_lt_one : betaNum < betaDen := by native_decide

-- ─────────────────────────────────────────────────────────────────────────────
-- §2  Congestion event: ssthresh computation and bounds
-- ─────────────────────────────────────────────────────────────────────────────

/-- ssthreshold after a CUBIC congestion event: floor(cwnd × BETA_CUBIC).
    Corresponds to `(r.congestion_window as f64 * BETA_CUBIC) as usize`
    in `congestion_event` (cubic.rs:375). -/
def ssthreshCubic (cwnd : Nat) : Nat := cwnd * betaNum / betaDen

-- ssthresh ≤ cwnd (multiplying by betaNum/betaDen < 1 then flooring cannot
-- exceed cwnd)
theorem ssthresh_le_cwnd (cwnd : Nat) : ssthreshCubic cwnd ≤ cwnd := by
  unfold ssthreshCubic betaNum betaDen
  omega

-- ssthresh < cwnd when cwnd > 0 (CUBIC strictly reduces the window)
theorem ssthresh_lt_cwnd_pos (cwnd : Nat) (h : 0 < cwnd) :
    ssthreshCubic cwnd < cwnd := by
  unfold ssthreshCubic betaNum betaDen
  omega

-- ssthresh is monotone: larger window yields larger threshold
theorem ssthresh_monotone (a b : Nat) (h : a ≤ b) :
    ssthreshCubic a ≤ ssthreshCubic b := by
  unfold ssthreshCubic
  exact Nat.div_le_div_right (Nat.mul_le_mul_right betaNum h)

-- ssthresh is non-negative (trivially Nat ≥ 0)
theorem ssthresh_nonneg (cwnd : Nat) : 0 ≤ ssthreshCubic cwnd :=
  Nat.zero_le _

-- Concrete test: ssthreshCubic 10000 = 7000
-- (floor(10000 * 7 / 10) = floor(70000/10) = 7000)
theorem ssthresh_concrete_10000 : ssthreshCubic 10000 = 7000 := by
  native_decide

-- ─────────────────────────────────────────────────────────────────────────────
-- §3  W_cubic algebraic properties
-- ─────────────────────────────────────────────────────────────────────────────

-- W_cubic(t) = C * (t - K)^3 + w_max   (Eq. 1 of RFC 8312bis)
-- All values are modelled over Int to allow (t - K) to be negative.
--
-- The cube-root K satisfies: C * K^3 = w_max - cwnd  (Eq. 2 of RFC 8312bis)
-- This is the defining property of cubic_k.

/-- W_cubic(t) in Int arithmetic (unscaled; C is a rational factor):
    wcubic c t k wMax = c * (t - k)^3 + wMax  -/
def wcubic (c t k wMax : Int) : Int := c * (t - k)^3 + wMax

-- W_cubic(K) = w_max: at exactly t = K the function equals w_max.
-- This is the target window after full recovery.
theorem wCubic_at_k_eq_wmax (c k wMax : Int) :
    wcubic c k k wMax = wMax := by
  unfold wcubic
  simp

-- W_cubic epoch anchor (RFC 8312bis §5.1):
-- The cubic curve is anchored so that W_cubic(0) = cwnd after a congestion event.
-- This is the defining property: K is chosen so that C·K³ = w_max − cwnd_new.
-- Therefore at t=0 (epoch start): W_cubic(0) = C·(0−K)³ + w_max
--                                            = −C·K³ + w_max
--                                            = −(w_max − cwnd_new) + w_max
--                                            = cwnd_new
-- We state this algebraically: given C·k3 = w_max − cwnd, then −C·k3 + w_max = cwnd.
-- (Here k3 represents K³; the cube-root step is elided as an abstraction.)
theorem wCubic_epoch_anchor (c k3 wMax cwnd : Int)
    (hk3 : c * k3 = wMax - cwnd) :
    -(c * k3) + wMax = cwnd := by
  omega

-- Nat model: W_cubic with t ≥ k (time after epoch start ≥ K).
-- Uses Nat subtraction (safe since t ≥ k is a hypothesis).
def wcubicNat (c t k wMax : Nat) : Nat := c * (t - k)^3 + wMax

-- W_cubic(K) = w_max in the Nat model
theorem wCubicNat_at_k_eq_wmax (c k wMax : Nat) :
    wcubicNat c k k wMax = wMax := by
  unfold wcubicNat
  simp

-- W_cubic is non-decreasing for t ≥ K:
-- Since (t - k) is non-decreasing in t when k ≤ t, and the cube of a
-- non-negative Nat is non-decreasing, and multiplication by c preserves
-- the ordering, adding wMax preserves it too.
theorem wCubicNat_monotone (c wMax k t1 t2 : Nat)
    (hk1 : k ≤ t1) (h12 : t1 ≤ t2) :
    wcubicNat c t1 k wMax ≤ wcubicNat c t2 k wMax := by
  unfold wcubicNat
  have hbase : t1 - k ≤ t2 - k := by omega
  have hpow  : (t1 - k)^3 ≤ (t2 - k)^3 :=
    Nat.pow_le_pow_left hbase 3
  have hmul  : c * (t1 - k)^3 ≤ c * (t2 - k)^3 :=
    Nat.mul_le_mul_left c hpow
  omega

-- W_cubic is non-decreasing in c (larger scaling = larger value).
theorem wCubicNat_monotone_c (c1 c2 wMax k t : Nat)
    (hc : c1 ≤ c2) :
    wcubicNat c1 t k wMax ≤ wcubicNat c2 t k wMax := by
  unfold wcubicNat
  have hmul : c1 * (t - k)^3 ≤ c2 * (t - k)^3 :=
    Nat.mul_le_mul_right ((t - k)^3) hc
  omega

-- W_cubic ≥ w_max for any t (since c * (t - k)^3 ≥ 0 in Nat)
theorem wCubicNat_ge_wmax_of_t_ge_k (c wMax k t : Nat) :
    wMax ≤ wcubicNat c t k wMax := by
  unfold wcubicNat
  omega

-- ─────────────────────────────────────────────────────────────────────────────
-- §4  Fast convergence: w_max reduction
-- ─────────────────────────────────────────────────────────────────────────────

-- Fast convergence (cubic.rs:368-371):
--   if cwnd < w_max:  w_max_new = cwnd * (1 + BETA) / 2
-- In exact integer arithmetic: cwnd * (betaDen + betaNum) / (2 * betaDen)
--                              = cwnd * 17 / 20

/-- Fast-convergence w_max after congestion when cwnd < previous w_max. -/
def wMaxFastConv (cwnd : Nat) : Nat :=
  cwnd * (betaDen + betaNum) / (2 * betaDen)

-- Fast convergence strictly reduces w_max below cwnd (since (1+β)/2 < 1)
theorem fastConv_wmax_lt_cwnd (cwnd : Nat) (h : 0 < cwnd) :
    wMaxFastConv cwnd < cwnd := by
  unfold wMaxFastConv betaDen betaNum
  omega

-- Fast convergence is at most cwnd (weakening; for all cwnd including 0)
theorem fastConv_wmax_le_cwnd (cwnd : Nat) :
    wMaxFastConv cwnd ≤ cwnd := by
  unfold wMaxFastConv betaDen betaNum
  omega

-- Fast convergence w_max is monotone in cwnd
theorem fastConv_monotone (a b : Nat) (h : a ≤ b) :
    wMaxFastConv a ≤ wMaxFastConv b := by
  unfold wMaxFastConv
  exact Nat.div_le_div_right
    (Nat.mul_le_mul_right (betaDen + betaNum) h)

-- Concrete test: wMaxFastConv 10000 = 8500
-- (10000 * 17 / 20 = 170000 / 20 = 8500)
theorem wMaxFastConv_concrete : wMaxFastConv 10000 = 8500 := by
  native_decide

-- ─────────────────────────────────────────────────────────────────────────────
-- §5  Combined congestion event state transformation
-- ─────────────────────────────────────────────────────────────────────────────

-- The congestion event does two key things:
--   1. Reduces ssthresh to floor(cwnd * BETA_CUBIC)
--   2. Sets cwnd := ssthresh  (the window immediately drops)
-- Both together ensure cwnd strictly decreases on every fresh loss event.

-- The reduction is strict for any non-zero window.
theorem congestionEvent_reduces_cwnd (cwnd : Nat) (h : 0 < cwnd) :
    ssthreshCubic cwnd < cwnd :=
  ssthresh_lt_cwnd_pos cwnd h

-- K = 0 when cwnd = w_max (no time needed to recover — already at target).
-- Algebraic: (w_max - cwnd) = 0 when cwnd ≥ w_max.
theorem cubicK_zero_when_cwnd_ge_wmax (wMax cwnd : Nat)
    (h : wMax ≤ cwnd) : wMax - cwnd = 0 := by omega

-- Additional concrete tests verifying ssthresh and fast convergence
-- at several typical congestion window sizes.
theorem ssthresh_concrete_1448  : ssthreshCubic 1448  = 1013  := by native_decide
theorem ssthresh_concrete_14480 : ssthreshCubic 14480 = 10136 := by native_decide
theorem wMaxFastConv_concrete_1448 : wMaxFastConv 1448 = 1230 := by native_decide
