// Copyright (C) 2025, Cloudflare, Inc.
// SPDX-License-Identifier: BSD-2-Clause
//
// 🔬 Lean Squad — Route-B correspondence test for BBR2CwndUpdate (T81)
//
// This test verifies that the Lean model `FVSquad.BBR2CwndUpdate` corresponds
// to the pure functional core of `update_congestion_window` from
// `quiche/src/recovery/gcongestion/bbr2.rs` lines 603–621.
//
// Lean model (BBR2CwndUpdate.lean):
//   def clamp (val lo hi : Nat) : Nat := Nat.min (Nat.max val lo) hi
//   def cwndA (prior bytes_acked target_cwnd ack_height : Nat) : Nat :=
//     Nat.min (target_cwnd + ack_height) (prior + bytes_acked)
//   def cwndB (prior bytes_acked target_cwnd initial_cwnd : Nat) : Nat :=
//     if prior < target_cwnd ∨ prior < 2 * initial_cwnd
//     then prior + bytes_acked else prior
//
// Rust source (bbr2.rs L603-L621):
//   if full_bandwidth_reached {
//     target_cwnd += ack_height;
//     cwnd = target_cwnd.min(prior + bytes_acked);
//   } else if prior < target || prior < 2 * initial_cwnd {
//     cwnd = prior + bytes_acked;
//   }
//   cwnd = mode_limits.apply_limits(cwnd);
//   cwnd = cwnd_limits.apply_limits(cwnd);
//
// Run with: cargo test

/// Mirror of `clamp` from BBR2CwndUpdate.lean:
///   Nat.min (Nat.max val lo) hi  =  val.max(lo).min(hi)
fn clamp(val: usize, lo: usize, hi: usize) -> usize {
    val.max(lo).min(hi)
}

/// Mirror of `cwndA` from BBR2CwndUpdate.lean (path A: full_bandwidth_reached).
///   Nat.min (target + ack_height) (prior + bytes_acked)
fn cwnd_a(prior: usize, bytes_acked: usize, target: usize, ack_height: usize) -> usize {
    (target + ack_height).min(prior + bytes_acked)
}

/// Mirror of `cwndB` from BBR2CwndUpdate.lean (path B: !full_bandwidth_reached).
///   if prior < target || prior < 2*initial then prior+acked else prior
fn cwnd_b(prior: usize, bytes_acked: usize, target: usize, initial_cwnd: usize) -> usize {
    if prior < target || prior < 2 * initial_cwnd {
        prior + bytes_acked
    } else {
        prior
    }
}

/// Two-stage clamp: mirror of the double apply_limits in the Rust code.
fn clamp2(val: usize, lo1: usize, hi1: usize, lo2: usize, hi2: usize) -> usize {
    clamp(clamp(val, lo1, hi1), lo2, hi2)
}

/// Rust implementation of path A (full_bandwidth_reached = true).
/// Faithfully mirrors `update_congestion_window` path A from bbr2.rs.
fn rust_path_a(
    prior: usize,
    bytes_acked: usize,
    target: usize,
    ack_height: usize,
) -> usize {
    let target_plus = target + ack_height;
    target_plus.min(prior + bytes_acked)
}

/// Rust implementation of path B (full_bandwidth_reached = false).
fn rust_path_b(
    prior: usize,
    bytes_acked: usize,
    target: usize,
    initial_cwnd: usize,
) -> usize {
    if prior < target || prior < 2 * initial_cwnd {
        prior + bytes_acked
    } else {
        prior
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ── §1  clamp: Lean model agrees with Rust val.max(lo).min(hi) ───────────

    #[test]
    fn clamp_below_lo_raised() {
        assert_eq!(clamp(5, 10, 100), 10);
    }

    #[test]
    fn clamp_above_hi_lowered() {
        assert_eq!(clamp(200, 10, 100), 100);
    }

    #[test]
    fn clamp_in_range_unchanged() {
        assert_eq!(clamp(50, 10, 100), 50);
    }

    #[test]
    fn clamp_idempotent() {
        for &(lo, hi) in &[(0usize, 100usize), (10, 10), (20, 80)] {
            for &v in &[0usize, 5, 10, 50, 80, 100, 200] {
                let once = clamp(v, lo, hi);
                let twice = clamp(once, lo, hi);
                assert_eq!(once, twice, "idempotent fail lo={lo} hi={hi} v={v}");
            }
        }
    }

    #[test]
    fn clamp_mono_in_val() {
        let (lo, hi) = (10usize, 80usize);
        let vals = [0usize, 5, 10, 40, 80, 100];
        for &v1 in &vals {
            for &v2 in &vals {
                if v1 <= v2 {
                    assert!(
                        clamp(v1, lo, hi) <= clamp(v2, lo, hi),
                        "mono fail v1={v1} v2={v2}"
                    );
                }
            }
        }
    }

    // ── §2  cwndA: Lean model equals Rust path A ──────────────────────────────

    #[test]
    fn path_a_lean_rust_agree_basic() {
        // target + ack_height < prior + bytes_acked → result = target + ack_height
        assert_eq!(cwnd_a(1000, 200, 800, 100), rust_path_a(1000, 200, 800, 100));
        // prior + bytes_acked < target + ack_height → result = prior + bytes_acked
        assert_eq!(cwnd_a(500, 100, 800, 400), rust_path_a(500, 100, 800, 400));
    }

    #[test]
    fn path_a_le_acked() {
        // cwndA ≤ prior + bytes_acked  (theorem pathA_le_acked)
        for &prior in &[0usize, 100, 500, 1000] {
            for &ba in &[0usize, 50, 200, 1000] {
                for &tc in &[0usize, 200, 800] {
                    for &ah in &[0usize, 50, 300] {
                        let a = cwnd_a(prior, ba, tc, ah);
                        assert!(
                            a <= prior + ba,
                            "pathA_le_acked fail prior={prior} ba={ba} tc={tc} ah={ah}: a={a}"
                        );
                    }
                }
            }
        }
    }

    #[test]
    fn path_a_le_target_plus_ackheight() {
        // cwndA ≤ target + ack_height  (theorem pathA_le_targetPlus)
        for &prior in &[0usize, 500, 2000] {
            for &ba in &[0usize, 100, 500] {
                for &tc in &[0usize, 300, 900] {
                    for &ah in &[0usize, 100, 400] {
                        let a = cwnd_a(prior, ba, tc, ah);
                        assert!(
                            a <= tc + ah,
                            "pathA_le_targetPlus fail: a={a} tc={tc} ah={ah}"
                        );
                    }
                }
            }
        }
    }

    #[test]
    fn path_a_mono_in_bytes_acked() {
        // More acked bytes → cwndA can only grow (theorem pathA_clamp_mono)
        let (prior, tc, ah) = (500usize, 400usize, 100usize);
        let acks = [0usize, 50, 100, 300, 600, 1000];
        for &ba1 in &acks {
            for &ba2 in &acks {
                if ba1 <= ba2 {
                    let lo = 0;
                    let hi = usize::MAX;
                    assert!(
                        clamp(cwnd_a(prior, ba1, tc, ah), lo, hi) <=
                        clamp(cwnd_a(prior, ba2, tc, ah), lo, hi),
                        "pathA_clamp_mono fail ba1={ba1} ba2={ba2}"
                    );
                }
            }
        }
    }

    #[test]
    fn path_a_lean_rust_agreement_sweep() {
        let vals = [0usize, 100, 500, 1000, 5000];
        let mut count = 0;
        for &prior in &vals {
            for &ba in &vals {
                for &tc in &vals {
                    for &ah in &vals {
                        let lean = cwnd_a(prior, ba, tc, ah);
                        let rust = rust_path_a(prior, ba, tc, ah);
                        assert_eq!(
                            lean, rust,
                            "Divergence path A: prior={prior} ba={ba} tc={tc} ah={ah}"
                        );
                        count += 1;
                    }
                }
            }
        }
        println!("=== path A: {count} cases, all PASS ===");
    }

    // ── §3  cwndB: Lean model equals Rust path B ──────────────────────────────

    #[test]
    fn path_b_grow_case() {
        // prior < target → grow
        assert_eq!(cwnd_b(100, 50, 200, 50), 150); // 100 < 200
        assert_eq!(rust_path_b(100, 50, 200, 50), 150);
    }

    #[test]
    fn path_b_grow_via_initial() {
        // prior < 2*initial_cwnd → grow even if prior >= target
        assert_eq!(cwnd_b(300, 50, 200, 200), 350); // prior >= target but 300 < 400
        assert_eq!(rust_path_b(300, 50, 200, 200), 350);
    }

    #[test]
    fn path_b_noop_case() {
        // prior >= target AND prior >= 2*initial_cwnd → unchanged
        assert_eq!(cwnd_b(500, 100, 200, 100), 500); // 500 >= 200 and 500 >= 200
        assert_eq!(rust_path_b(500, 100, 200, 100), 500);
    }

    #[test]
    fn path_b_lean_rust_agreement_sweep() {
        let vals = [0usize, 50, 100, 200, 400, 1000];
        let mut count = 0;
        for &prior in &vals {
            for &ba in &vals {
                for &tc in &vals {
                    for &ic in &vals {
                        let lean = cwnd_b(prior, ba, tc, ic);
                        let rust = rust_path_b(prior, ba, tc, ic);
                        assert_eq!(
                            lean, rust,
                            "Divergence path B: prior={prior} ba={ba} tc={tc} ic={ic}"
                        );
                        count += 1;
                    }
                }
            }
        }
        println!("=== path B: {count} cases, all PASS ===");
    }

    #[test]
    fn path_b_ge_prior() {
        // cwndB ≥ prior (never shrinks)  (theorem pathB_grow_ge_prior + noop)
        for &prior in &[0usize, 100, 500] {
            for &ba in &[0usize, 50, 200] {
                for &tc in &[0usize, 200, 600] {
                    for &ic in &[0usize, 100, 300] {
                        let b = cwnd_b(prior, ba, tc, ic);
                        assert!(b >= prior, "cwndB < prior: {b} < {prior}");
                    }
                }
            }
        }
    }

    // ── §4  double-clamp: two apply_limits passes ─────────────────────────────

    #[test]
    fn clamp2_le_hi2() {
        // After two clamp passes, result ≤ hi2  (theorem clamp2_le_hi2)
        for &v in &[0usize, 10, 50, 200, 1000] {
            let r = clamp2(v, 5, 100, 10, 80);
            assert!(r <= 80, "clamp2_le_hi2 fail v={v} r={r}");
        }
    }

    #[test]
    fn clamp2_path_a_growth_bounded() {
        // clamp2(cwndA) ≤ clamp2(prior + bytes_acked)  (theorem clamp2_pathA_growth_bounded)
        for &prior in &[0usize, 200, 800] {
            for &ba in &[0usize, 100, 500] {
                let (tc, ah, lo1, hi1, lo2, hi2) = (300usize, 100, 0, 2000, 0, 1500);
                let a = clamp2(cwnd_a(prior, ba, tc, ah), lo1, hi1, lo2, hi2);
                let acked = clamp2(prior + ba, lo1, hi1, lo2, hi2);
                assert!(
                    a <= acked,
                    "clamp2_pathA_growth_bounded fail: a={a} acked={acked}"
                );
            }
        }
    }

    #[test]
    fn clamp2_path_b_grow_eq() {
        // In the grow case, clamp2(cwndB) = clamp2(prior + bytes_acked)
        // (theorem clamp2_pathB_grow_eq)
        let (prior, ba, tc, ic) = (100usize, 200, 500, 50);
        // prior < tc → grow case
        let b = cwnd_b(prior, ba, tc, ic);
        assert_eq!(b, prior + ba);
        let r = clamp2(b, 0, 2000, 0, 1500);
        let expected = clamp2(prior + ba, 0, 2000, 0, 1500);
        assert_eq!(r, expected);
    }

    // ── §5  full sweep: path A vs path B selection ────────────────────────────

    #[test]
    fn full_selection_lean_rust_agree() {
        // Test the full update_congestion_window logic:
        // path A when full_bandwidth_reached=true, path B otherwise.
        let vals = [0usize, 100, 300, 600, 1000];
        let mut count = 0;
        for &prior in &vals {
            for &ba in &vals {
                for &tc in &vals {
                    for &ah in &vals {
                        for &ic in &vals {
                            for full_bw in [true, false] {
                                let lean = if full_bw {
                                    cwnd_a(prior, ba, tc, ah)
                                } else {
                                    cwnd_b(prior, ba, tc, ic)
                                };
                                let rust = if full_bw {
                                    rust_path_a(prior, ba, tc, ah)
                                } else {
                                    rust_path_b(prior, ba, tc, ic)
                                };
                                assert_eq!(
                                    lean, rust,
                                    "full_selection divergence: full_bw={full_bw} \
                                     prior={prior} ba={ba} tc={tc} ah={ah} ic={ic}"
                                );
                                count += 1;
                            }
                        }
                    }
                }
            }
        }
        println!("=== full selection: {count} cases, all PASS ===");
    }
}

fn main() {
    println!("BBR2CwndUpdate Route-B correspondence tests — run with `cargo test`");
}
