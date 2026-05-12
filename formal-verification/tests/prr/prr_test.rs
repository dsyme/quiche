// Copyright (C) 2024, Cloudflare, Inc.
// SPDX-License-Identifier: BSD-2-Clause
//
// 🔬 Lean Squad — Route-B correspondence tests for PRR
//
// Verifies that the Lean model `PRR` in
// `formal-verification/lean/FVSquad/PRR.lean` agrees with the pure
// logic extracted from `quiche/src/recovery/congestion/prr.rs`.
//
// Run with:
//   rustc --edition 2021 prr_test.rs && ./prr_test
//
// Source under test:
//   quiche/src/recovery/congestion/prr.rs
//
// Lean model:
//   formal-verification/lean/FVSquad/PRR.lean

// ─────────────────────────────────────────────────────────────────────────────
// §1  Rust extraction — verbatim logic from prr.rs
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Default, Debug, Clone, PartialEq)]
struct PrrRust {
    prr_delivered: usize,
    recoverfs: usize,
    prr_out: usize,
    snd_cnt: usize,
}

impl PrrRust {
    fn on_packet_sent(&mut self, sent_bytes: usize) {
        self.prr_out += sent_bytes;
        self.snd_cnt = self.snd_cnt.saturating_sub(sent_bytes);
    }

    fn congestion_event(&mut self, bytes_in_flight: usize) {
        self.prr_delivered = 0;
        self.recoverfs = bytes_in_flight;
        self.prr_out = 0;
        self.snd_cnt = 0;
    }

    fn on_packet_acked(
        &mut self, delivered_data: usize, pipe: usize, ssthresh: usize,
        max_datagram_size: usize,
    ) {
        self.prr_delivered += delivered_data;
        self.snd_cnt = if pipe > ssthresh {
            if self.recoverfs > 0 {
                (self.prr_delivered * ssthresh)
                    .div_ceil(self.recoverfs)
                    .saturating_sub(self.prr_out)
            } else {
                0
            }
        } else {
            let limit = std::cmp::max(
                self.prr_delivered.saturating_sub(self.prr_out),
                delivered_data,
            ) + max_datagram_size;
            std::cmp::min(ssthresh - pipe, limit)
        };
        self.snd_cnt = std::cmp::max(self.snd_cnt, 0);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// §2  Lean model translation in Rust
//     Mirrors PRR.lean §3 exactly: same field names, same definitions.
// ─────────────────────────────────────────────────────────────────────────────

fn div_ceil_lean(a: usize, b: usize) -> usize {
    // divCeil a b = if b = 0 then 0 else (a + b - 1) / b
    if b == 0 {
        0
    } else {
        (a + b - 1) / b
    }
}

#[derive(Default, Debug, Clone, PartialEq)]
struct PrrLean {
    prr_delivered: usize,
    recoverfs: usize,
    prr_out: usize,
    snd_cnt: usize,
}

impl PrrLean {
    fn congestion_event(&self, bytes_in_flight: usize) -> PrrLean {
        PrrLean {
            prr_delivered: 0,
            recoverfs: bytes_in_flight,
            prr_out: 0,
            snd_cnt: 0,
        }
    }

    fn on_packet_sent(&self, sent_bytes: usize) -> PrrLean {
        PrrLean {
            prr_delivered: self.prr_delivered,
            recoverfs: self.recoverfs,
            prr_out: self.prr_out + sent_bytes,
            snd_cnt: self.snd_cnt.saturating_sub(sent_bytes),
        }
    }

    fn on_packet_acked(
        &self, delivered_data: usize, pipe: usize, ssthresh: usize,
        mss: usize,
    ) -> PrrLean {
        let new_del = self.prr_delivered + delivered_data;
        let snd_cnt = if pipe > ssthresh {
            if self.recoverfs > 0 {
                div_ceil_lean(new_del * ssthresh, self.recoverfs)
                    .saturating_sub(self.prr_out)
            } else {
                0
            }
        } else {
            let max_part = std::cmp::max(
                new_del.saturating_sub(self.prr_out),
                delivered_data,
            ) + mss;
            std::cmp::min(ssthresh.saturating_sub(pipe), max_part)
        };
        PrrLean {
            prr_delivered: new_del,
            recoverfs: self.recoverfs,
            prr_out: self.prr_out,
            snd_cnt,
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// §3  Parallel state runner — drives both impls with the same operations
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone)]
enum Op {
    CongestionEvent(usize),
    Sent(usize),
    Acked {
        delivered: usize,
        pipe: usize,
        ssthresh: usize,
        mss: usize,
    },
}

fn run_rust(ops: &[Op]) -> PrrRust {
    let mut s = PrrRust::default();
    for op in ops {
        match op {
            Op::CongestionEvent(f) => s.congestion_event(*f),
            Op::Sent(b) => s.on_packet_sent(*b),
            Op::Acked { delivered, pipe, ssthresh, mss } =>
                s.on_packet_acked(*delivered, *pipe, *ssthresh, *mss),
        }
    }
    s
}

fn run_lean(ops: &[Op]) -> PrrLean {
    let mut s = PrrLean::default();
    for op in ops {
        match op {
            Op::CongestionEvent(f) => s = s.congestion_event(*f),
            Op::Sent(b) => s = s.on_packet_sent(*b),
            Op::Acked { delivered, pipe, ssthresh, mss } =>
                s = s.on_packet_acked(*delivered, *pipe, *ssthresh, *mss),
        }
    }
    s
}

fn states_match(r: &PrrRust, l: &PrrLean) -> bool {
    r.prr_delivered == l.prr_delivered
        && r.recoverfs == l.recoverfs
        && r.prr_out == l.prr_out
        && r.snd_cnt == l.snd_cnt
}

// ─────────────────────────────────────────────────────────────────────────────
// §4  Test cases
// ─────────────────────────────────────────────────────────────────────────────

fn main() {
    let mut pass = 0usize;
    let mut fail = 0usize;

    macro_rules! check {
        ($desc:expr, $ops:expr) => {{
            let ops: &[Op] = $ops;
            let r = run_rust(ops);
            let l = run_lean(ops);
            if states_match(&r, &l) {
                pass += 1;
            } else {
                fail += 1;
                eprintln!(
                    "FAIL [{}]:\n  rust: {:?}\n  lean: {:?}",
                    $desc, r, l
                );
            }
        }};
    }

    // ── Group 1: congestion_event resets state ────────────────────────────────
    check!("ce_zero_flight", &[Op::CongestionEvent(0)]);
    check!("ce_1000", &[Op::CongestionEvent(1000)]);
    check!("ce_twice", &[
        Op::CongestionEvent(1000),
        Op::CongestionEvent(2000)
    ]);

    // ── Group 2: on_packet_sent ───────────────────────────────────────────────
    check!("ce_then_sent_within_snd_cnt", &[
        Op::CongestionEvent(5000),
        Op::Acked { delivered: 1000, pipe: 6000, ssthresh: 3000, mss: 1000 },
        Op::Sent(500),
    ]);
    check!("sent_saturates_snd_cnt", &[
        Op::CongestionEvent(5000),
        Op::Acked { delivered: 1000, pipe: 6000, ssthresh: 3000, mss: 1000 },
        Op::Sent(10000),
    ]);
    check!("sent_zero", &[Op::CongestionEvent(1000), Op::Sent(0)]);

    // ── Group 3: PRR mode (pipe > ssthresh) ──────────────────────────────────
    check!("prr_mode_basic", &[
        Op::CongestionEvent(10000),
        Op::Acked { delivered: 1000, pipe: 10000, ssthresh: 5000, mss: 1000 },
    ]);
    check!("prr_mode_two_acks", &[
        Op::CongestionEvent(10000),
        Op::Acked { delivered: 1000, pipe: 10000, ssthresh: 5000, mss: 1000 },
        Op::Acked { delivered: 1000, pipe: 9000, ssthresh: 5000, mss: 1000 },
    ]);
    check!("prr_mode_then_sent", &[
        Op::CongestionEvent(10000),
        Op::Acked { delivered: 1000, pipe: 10000, ssthresh: 5000, mss: 1000 },
        Op::Sent(500),
        Op::Acked { delivered: 1000, pipe: 9500, ssthresh: 5000, mss: 1000 },
    ]);
    check!("prr_zero_recoverfs", &[
        Op::CongestionEvent(0),
        Op::Acked { delivered: 500, pipe: 600, ssthresh: 400, mss: 100 },
    ]);
    check!("prr_overflow_saturating", &[
        Op::CongestionEvent(10000),
        Op::Sent(1000),
        Op::Acked { delivered: 1000, pipe: 11000, ssthresh: 5000, mss: 1000 },
    ]);

    // ── Group 4: PRR-SSRB mode (pipe ≤ ssthresh) ────────────────────────────
    check!("ssrb_basic", &[
        Op::CongestionEvent(10000),
        Op::Acked { delivered: 1000, pipe: 1000, ssthresh: 5000, mss: 1000 },
    ]);
    check!("ssrb_pipe_equals_ssthresh", &[
        Op::CongestionEvent(10000),
        Op::Acked { delivered: 1000, pipe: 5000, ssthresh: 5000, mss: 1000 },
    ]);
    check!("ssrb_pipe_zero", &[
        Op::CongestionEvent(10000),
        Op::Acked { delivered: 500, pipe: 0, ssthresh: 5000, mss: 1000 },
    ]);
    check!("ssrb_two_acks", &[
        Op::CongestionEvent(10000),
        Op::Acked { delivered: 1000, pipe: 1000, ssthresh: 5000, mss: 1000 },
        Op::Acked { delivered: 1000, pipe: 1000, ssthresh: 5000, mss: 1000 },
    ]);
    check!("ssrb_sent_then_ack", &[
        Op::CongestionEvent(10000),
        Op::Sent(1000),
        Op::Acked { delivered: 500, pipe: 1000, ssthresh: 5000, mss: 1000 },
    ]);
    check!("ssrb_large_mss", &[
        Op::CongestionEvent(10000),
        Op::Acked { delivered: 300, pipe: 2000, ssthresh: 5000, mss: 9000 },
    ]);

    // ── Group 5: RFC 6937 example sequence ───────────────────────────────────
    // RFC 6937 §5: assume FlightSize=10*MSS, ssthresh=5*MSS, MSS=1000.
    // After loss: recoverfs=10000, ssthresh=5000.
    // Each RTT: receive ack for 1 MSS (pipe decrements by 1 MSS as well).
    {
        let mss = 1000usize;
        let recoverfs = 10 * mss;
        let ssthresh = 5 * mss;

        let ops_r1: &[Op] = &[
            Op::CongestionEvent(recoverfs),
            Op::Acked { delivered: mss, pipe: recoverfs, ssthresh, mss },
        ];
        check!("rfc6937_round1", ops_r1);

        let ops_r2: &[Op] = &[
            Op::CongestionEvent(recoverfs),
            Op::Acked { delivered: mss, pipe: recoverfs, ssthresh, mss },
            Op::Sent(500),
            Op::Acked { delivered: mss, pipe: recoverfs - mss, ssthresh, mss },
        ];
        check!("rfc6937_round2", ops_r2);
    }

    // ── Group 6: Edge cases ──────────────────────────────────────────────────
    check!("fresh_default_state", &[]);
    check!("ce_then_zero_ack", &[
        Op::CongestionEvent(5000),
        Op::Acked { delivered: 0, pipe: 5000, ssthresh: 3000, mss: 1000 },
    ]);
    check!("small_values", &[
        Op::CongestionEvent(2),
        Op::Acked { delivered: 1, pipe: 3, ssthresh: 1, mss: 1 },
        Op::Sent(1),
        Op::Acked { delivered: 1, pipe: 2, ssthresh: 1, mss: 1 },
    ]);
    check!("ssrb_gap_capped_by_mss", &[
        Op::CongestionEvent(10000),
        Op::Acked { delivered: 100, pipe: 4990, ssthresh: 5000, mss: 50 },
    ]);
    check!("multiple_ce_resets", &[
        Op::CongestionEvent(8000),
        Op::Acked { delivered: 1000, pipe: 8000, ssthresh: 4000, mss: 1000 },
        Op::Sent(500),
        Op::CongestionEvent(7500),
        Op::Acked { delivered: 500, pipe: 7500, ssthresh: 3000, mss: 1000 },
    ]);
    check!("acked_pipe_below_ssthresh_large_prr_out", &[
        Op::CongestionEvent(6000),
        Op::Sent(2000),
        Op::Acked { delivered: 1000, pipe: 3000, ssthresh: 4000, mss: 1000 },
    ]);

    // ── Summary ───────────────────────────────────────────────────────────────
    println!("PRR Route-B correspondence tests: {}/{} PASS", pass, pass + fail);
    if fail > 0 {
        std::process::exit(1);
    }
}
