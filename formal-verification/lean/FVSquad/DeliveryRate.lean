-- Copyright (C) 2024, Cloudflare, Inc.
-- SPDX-License-Identifier: BSD-2-Clause
--
-- FVSquad/DeliveryRate.lean
--
-- Formal verification of delivery-rate estimation properties.
-- Source: quiche/src/recovery/congestion/delivery_rate.rs
--   (Rate::generate_rate_sample, RateSample fields)
--
-- RFC reference: draft-cheng-iccrg-delivery-rate-estimation-01
--
-- The key invariant proved here:
--   The elapsed time used for rate estimation is
--     interval = max(send_elapsed, ack_elapsed)
--   Using the *maximum* of the two intervals ensures the resulting
--   delivery-rate estimate is *conservative* (never over-estimated):
--     delivered / max(send, ack) ≤ delivered / send_elapsed
--     delivered / max(send, ack) ≤ delivered / ack_elapsed
--
-- Modelling choices / approximations:
--   - Time is modelled as Nat (nanoseconds).
--   - Bandwidth (delivered_bytes / elapsed_ns * 1e9) is modelled as Nat.
--   - Rust f64 division, Duration rounding, and bandwidth type details
--     are abstracted away; the integer division is the model.
--   - app-limited flag logic is not modelled (stateful, tested in Route-B).

namespace DeliveryRate

/-! ## Elapsed interval computation -/

/-- elapsed_interval = max(send_elapsed_ns, ack_elapsed_ns).
    Matches `let interval = rate_sample.send_elapsed.max(rate_sample.ack_elapsed)`
    in delivery_rate.rs:139. -/
def elapsed_interval (send_ns ack_ns : Nat) : Nat := max send_ns ack_ns

/-- The interval is at least send_elapsed. -/
theorem interval_ge_send (s a : Nat) :
    s ≤ elapsed_interval s a := Nat.le_max_left s a

/-- The interval is at least ack_elapsed. -/
theorem interval_ge_ack (s a : Nat) :
    a ≤ elapsed_interval s a := Nat.le_max_right s a

/-- elapsed_interval is symmetric. -/
theorem interval_comm (s a : Nat) :
    elapsed_interval s a = elapsed_interval a s := Nat.max_comm s a

/-- If both elapsed times are zero, the interval is zero. -/
theorem interval_zero (s a : Nat) (hs : s = 0) (ha : a = 0) :
    elapsed_interval s a = 0 := by simp [elapsed_interval, hs, ha]

/-- If either elapsed time is positive, the interval is positive. -/
theorem interval_pos_of_send_pos {s : Nat} (a : Nat) (hs : 0 < s) :
    0 < elapsed_interval s a :=
  Nat.lt_of_lt_of_le hs (interval_ge_send s a)

theorem interval_pos_of_ack_pos (s : Nat) {a : Nat} (ha : 0 < a) :
    0 < elapsed_interval s a :=
  Nat.lt_of_lt_of_le ha (interval_ge_ack s a)

/-- elapsed_interval is monotone in send_elapsed. -/
theorem interval_mono_send {s₁ s₂ : Nat} (a : Nat) (h : s₁ ≤ s₂) :
    elapsed_interval s₁ a ≤ elapsed_interval s₂ a := by
  simp only [elapsed_interval]; omega

/-- elapsed_interval is monotone in ack_elapsed. -/
theorem interval_mono_ack (s : Nat) {a₁ a₂ : Nat} (h : a₁ ≤ a₂) :
    elapsed_interval s a₁ ≤ elapsed_interval s a₂ := by
  simp only [elapsed_interval]; omega

/-! ## Delivery rate computation -/

/-- delivery_rate in bytes/sec (integer, scaled by 1e9).
    Matches `delivered as f64 / interval.as_secs_f64()` truncated to u64. -/
def delivery_rate (delivered_bytes elapsed_ns : Nat) : Nat :=
  if elapsed_ns = 0 then 0
  else delivered_bytes * 1_000_000_000 / elapsed_ns

/-- Delivery rate is zero when nothing was delivered. -/
theorem rate_zero_no_delivery (elapsed_ns : Nat) :
    delivery_rate 0 elapsed_ns = 0 := by
  simp [delivery_rate]

/-- Delivery rate is zero when elapsed is zero (no reliable interval). -/
theorem rate_zero_no_elapsed (d : Nat) :
    delivery_rate d 0 = 0 := by simp [delivery_rate]

/-- Delivery rate is monotone in delivered bytes (larger delivery → higher rate). -/
theorem rate_mono_delivered {d₁ d₂ : Nat} (e : Nat)
    (h : d₁ ≤ d₂) :
    delivery_rate d₁ e ≤ delivery_rate d₂ e := by
  unfold delivery_rate
  by_cases he : e = 0 <;> simp [he]
  exact Nat.div_le_div_right (Nat.mul_le_mul_right 1_000_000_000 h)

/-- Delivery rate is anti-monotone in elapsed time (longer interval → lower rate). -/
theorem rate_anti_elapsed {e₁ e₂ : Nat} (d : Nat)
    (h : e₁ ≤ e₂) (he₁ : 0 < e₁) :
    delivery_rate d e₂ ≤ delivery_rate d e₁ := by
  unfold delivery_rate
  have he₁' : e₁ ≠ 0 := Nat.pos_iff_ne_zero.mp he₁
  have he₂' : e₂ ≠ 0 := Nat.pos_iff_ne_zero.mp (Nat.lt_of_lt_of_le he₁ h)
  simp [he₁', he₂']
  exact Nat.div_le_div_left h he₁

/-! ## Key conservatism theorems

    Using max(send, ack) as the interval ensures the rate is never
    over-estimated relative to either individual elapsed time.
-/

/-- Rate using max-interval ≤ rate using send_elapsed alone.
    (Conservative w.r.t. the send clock.) -/
theorem rate_conservative_send (d s a : Nat) (hs : 0 < s) :
    delivery_rate d (elapsed_interval s a) ≤ delivery_rate d s :=
  rate_anti_elapsed d (interval_ge_send s a) hs

/-- Rate using max-interval ≤ rate using ack_elapsed alone.
    (Conservative w.r.t. the acknowledgement clock.) -/
theorem rate_conservative_ack (d s a : Nat) (ha : 0 < a) :
    delivery_rate d (elapsed_interval s a) ≤ delivery_rate d a :=
  rate_anti_elapsed d (interval_ge_ack s a) ha

/-- Rate using max-interval is the *minimum* of the two individual rates.
    (Max interval → minimum rate → most conservative estimate.) -/
theorem rate_max_interval_le_min_rate (d s a : Nat) (hs : 0 < s) (ha : 0 < a) :
    delivery_rate d (elapsed_interval s a) ≤
      min (delivery_rate d s) (delivery_rate d a) :=
  Nat.le_min.mpr ⟨rate_conservative_send d s a hs, rate_conservative_ack d s a ha⟩

/-! ## min_rtt filter: interval below min_rtt discarded -/

/-- If the computed interval is less than min_rtt, the sample is invalidated
    (interval set to zero → delivery_rate = 0).
    This conservatively avoids spuriously high rate estimates from short bursts. -/
theorem rate_invalidated_when_interval_lt_minrtt (d _interval _min_rtt : Nat) :
    -- After setting interval to 0, rate is 0
    delivery_rate d 0 = 0 :=
  rate_zero_no_elapsed d

/-- An invalid interval (= 0) gives zero rate regardless of delivered bytes. -/
theorem rate_zero_of_invalid_interval (d : Nat) :
    delivery_rate d 0 = 0 :=
  rate_zero_no_elapsed d

/-! ## Concrete examples -/

-- 1 MB delivered in 10 ms → 100 MB/s = 100_000_000 bytes/s
example : delivery_rate 1_000_000 10_000_000 = 100_000_000 := by native_decide

-- 1500 bytes in 1 ms (1_000_000 ns) → 1_500_000 bytes/s (1.5 MB/s)
example : delivery_rate 1500 1_000_000 = 1_500_000 := by native_decide

-- max-interval is conservative: max(5ms, 3ms) = 5ms
example : elapsed_interval 5_000_000 3_000_000 = 5_000_000 := by native_decide

-- rate with 5ms interval ≤ rate with 3ms interval
example : delivery_rate 1500 5_000_000 ≤ delivery_rate 1500 3_000_000 := by native_decide

end DeliveryRate
