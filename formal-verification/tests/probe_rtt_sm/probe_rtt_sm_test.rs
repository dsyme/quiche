// Copyright (C) 2025, Cloudflare, Inc.
// SPDX-License-Identifier: BSD-2-Clause
//
// 🔬 Lean Squad Route-B correspondence test: T60 — BBR2 ProbeRTT State Machine
//
// Verifies that the Lean model `FVSquad/ProbeRTTStateMachine.lean` agrees with
// a direct re-implementation of the exit_time state machine logic found in
// `quiche/src/recovery/gcongestion/bbr2/probe_rtt.rs`.
//
// The Lean model abstracts Rust's `Instant` as a monotone `Nat` tick counter.
// Here we mirror that abstraction: all times are plain `u64` tick values.
// The Rust source's `on_congestion_event` and `on_exit_quiescence` methods
// are re-expressed as pure functions on (state, params) — stripping out the
// BBRv2NetworkModel, cwnd/pacing updates, and mode transitions that the Lean
// model deliberately omits.
//
// Run (no Cargo needed):
//   rustc probe_rtt_sm_test.rs -o /tmp/probe_rtt_sm_test
//   /tmp/probe_rtt_sm_test
//
// Expected: all PASS lines, then "=== All N checks PASS ===".

// ---------------------------------------------------------------------------
// §1  State and result types  (mirrors ProbeRTTStateMachine.lean §1)
// ---------------------------------------------------------------------------

#[derive(Debug, PartialEq, Clone, Copy)]
enum ProbeRttState {
    /// exit_time = None — inflight has not yet reached the target.
    Draining,
    /// exit_time = Some(t) — timer set; will exit when event_time > t.
    Waiting(u64),
}

#[derive(Debug, PartialEq, Clone, Copy)]
enum ProbeRttResult {
    /// Remain in ProbeRTT with updated state.
    Stay(ProbeRttState),
    /// Phase complete; caller transitions to ProbeBW.
    ExitToProbeBW,
}

// ---------------------------------------------------------------------------
// §2  Lean model re-implemented in Rust (mirrors §2 of the .lean file)
// ---------------------------------------------------------------------------

/// Model of `ProbeRTT::on_congestion_event` — only the exit_time transition.
///
/// Lean source:
/// ```
/// def congestionStep (state eventTime inflight target duration : Nat)
///   : ProbeRttResult :=
///   match state with
///   | .draining =>
///     if inflight ≤ target then .stay (.waiting (eventTime + duration))
///     else .stay .draining
///   | .waiting exitTime =>
///     if eventTime > exitTime then .exitToProbeBW
///     else .stay (.waiting exitTime)
/// ```
fn congestion_step(
    state: ProbeRttState, event_time: u64, inflight: u64, target: u64,
    duration: u64,
) -> ProbeRttResult {
    match state {
        ProbeRttState::Draining => {
            if inflight <= target {
                ProbeRttResult::Stay(ProbeRttState::Waiting(
                    event_time + duration,
                ))
            } else {
                ProbeRttResult::Stay(ProbeRttState::Draining)
            }
        },
        ProbeRttState::Waiting(exit_time) => {
            if event_time > exit_time {
                ProbeRttResult::ExitToProbeBW
            } else {
                ProbeRttResult::Stay(ProbeRttState::Waiting(exit_time))
            }
        },
    }
}

/// Model of `ProbeRTT::on_exit_quiescence` — only the exit_time transition.
///
/// Lean source:
/// ```
/// def quiescenceStep (state : ProbeRttState) (now : Nat) : ProbeRttResult :=
///   match state with
///   | .draining     => .exitToProbeBW
///   | .waiting t    => if now > t then .exitToProbeBW
///                      else .stay (.waiting t)
/// ```
fn quiescence_step(state: ProbeRttState, now: u64) -> ProbeRttResult {
    match state {
        ProbeRttState::Draining => ProbeRttResult::ExitToProbeBW,
        ProbeRttState::Waiting(exit_time) => {
            if now > exit_time {
                ProbeRttResult::ExitToProbeBW
            } else {
                ProbeRttResult::Stay(ProbeRttState::Waiting(exit_time))
            }
        },
    }
}

// ---------------------------------------------------------------------------
// §3  Source-derived oracle
//
// The Rust source (`probe_rtt.rs`) has the exact same logic in:
//   `on_congestion_event`:
//       match self.exit_time {
//           None       => { if bytes_in_flight <= inflight_target {
//                               self.exit_time = Some(event_time + duration) }
//                           Mode::ProbeRTT(self) }
//           Some(exit) => if event_time > exit { into_probe_bw(...) }
//                         else { Mode::ProbeRTT(self) }
//       }
//   `on_exit_quiescence`:
//       match self.exit_time {
//           None             => into_probe_bw(...)
//           Some(t) if now>t => into_probe_bw(...)
//           Some(_)          => Mode::ProbeRTT(self)
//       }
//
// We replicate that logic directly for the oracle comparison.
// ---------------------------------------------------------------------------

#[derive(Debug, PartialEq)]
enum OracleResult {
    StaysInProbeRTT { new_exit_time: Option<u64> },
    ExitsToProbeBW,
}

fn oracle_congestion(
    exit_time: Option<u64>, event_time: u64, bytes_in_flight: u64,
    inflight_target: u64, duration: u64,
) -> OracleResult {
    match exit_time {
        None => {
            if bytes_in_flight <= inflight_target {
                OracleResult::StaysInProbeRTT {
                    new_exit_time: Some(event_time + duration),
                }
            } else {
                OracleResult::StaysInProbeRTT { new_exit_time: None }
            }
        },
        Some(exit) => {
            if event_time > exit {
                OracleResult::ExitsToProbeBW
            } else {
                OracleResult::StaysInProbeRTT {
                    new_exit_time: Some(exit),
                }
            }
        },
    }
}

fn oracle_quiescence(exit_time: Option<u64>, now: u64) -> OracleResult {
    match exit_time {
        None => OracleResult::ExitsToProbeBW,
        Some(t) if now > t => OracleResult::ExitsToProbeBW,
        Some(t) => OracleResult::StaysInProbeRTT { new_exit_time: Some(t) },
    }
}

// ---------------------------------------------------------------------------
// §4  Cross-check helpers
// ---------------------------------------------------------------------------

/// Translate the Lean model result to OracleResult for comparison.
fn lean_to_oracle(r: ProbeRttResult) -> OracleResult {
    match r {
        ProbeRttResult::Stay(ProbeRttState::Draining) =>
            OracleResult::StaysInProbeRTT { new_exit_time: None },
        ProbeRttResult::Stay(ProbeRttState::Waiting(t)) =>
            OracleResult::StaysInProbeRTT { new_exit_time: Some(t) },
        ProbeRttResult::ExitToProbeBW => OracleResult::ExitsToProbeBW,
    }
}

fn check(label: &str, lean_result: ProbeRttResult, oracle: OracleResult) {
    let translated = lean_to_oracle(lean_result);
    if translated == oracle {
        println!("PASS  {label}");
    } else {
        eprintln!(
            "FAIL  {label}: lean={:?} oracle={:?}",
            translated, oracle
        );
        std::process::exit(1);
    }
}

// ---------------------------------------------------------------------------
// §5  Test cases (exercising all branches of both transition functions)
// ---------------------------------------------------------------------------

fn main() {
    println!(
        "=== Route-B correspondence test: T60 BBR2 ProbeRTT State Machine ==="
    );
    let mut n = 0usize;

    // -----------------------------------------------------------------------
    // congestionStep — DRAINING state
    // -----------------------------------------------------------------------

    // draining, inflight > target → stays draining
    let (et, inf, tgt, dur) = (100u64, 500u64, 300u64, 200u64);
    check(
        "congestion/draining: inflight>target stays draining",
        congestion_step(ProbeRttState::Draining, et, inf, tgt, dur),
        oracle_congestion(None, et, inf, tgt, dur),
    );
    n += 1;

    // draining, inflight == target → sets timer
    let (et, inf, tgt, dur) = (100u64, 300u64, 300u64, 200u64);
    check(
        "congestion/draining: inflight==target sets timer",
        congestion_step(ProbeRttState::Draining, et, inf, tgt, dur),
        oracle_congestion(None, et, inf, tgt, dur),
    );
    n += 1;

    // draining, inflight < target → sets timer
    let (et, inf, tgt, dur) = (50u64, 100u64, 300u64, 200u64);
    check(
        "congestion/draining: inflight<target sets timer",
        congestion_step(ProbeRttState::Draining, et, inf, tgt, dur),
        oracle_congestion(None, et, inf, tgt, dur),
    );
    n += 1;

    // draining, inflight = 0, target = 0 → timer set (boundary)
    let (et, inf, tgt, dur) = (0u64, 0u64, 0u64, 200u64);
    check(
        "congestion/draining: both zero sets timer",
        congestion_step(ProbeRttState::Draining, et, inf, tgt, dur),
        oracle_congestion(None, et, inf, tgt, dur),
    );
    n += 1;

    // draining, target=0, inflight=1 → stays draining
    let (et, inf, tgt, dur) = (10u64, 1u64, 0u64, 200u64);
    check(
        "congestion/draining: inflight>0 target=0 stays draining",
        congestion_step(ProbeRttState::Draining, et, inf, tgt, dur),
        oracle_congestion(None, et, inf, tgt, dur),
    );
    n += 1;

    // draining, large values
    let (et, inf, tgt, dur) = (u64::MAX / 4, u64::MAX / 8, u64::MAX / 4, 1000u64);
    check(
        "congestion/draining: large values inflight<=target sets timer",
        congestion_step(ProbeRttState::Draining, et, inf, tgt, dur),
        oracle_congestion(None, et, inf, tgt, dur),
    );
    n += 1;

    // -----------------------------------------------------------------------
    // congestionStep — WAITING state
    // -----------------------------------------------------------------------

    // waiting, event_time > exit_time → exits
    let (exit_t, et, inf, tgt, dur) = (300u64, 301u64, 100u64, 300u64, 200u64);
    check(
        "congestion/waiting: event>exit exits ProbeRTT",
        congestion_step(ProbeRttState::Waiting(exit_t), et, inf, tgt, dur),
        oracle_congestion(Some(exit_t), et, inf, tgt, dur),
    );
    n += 1;

    // waiting, event_time == exit_time → stays
    let (exit_t, et, inf, tgt, dur) = (300u64, 300u64, 100u64, 300u64, 200u64);
    check(
        "congestion/waiting: event==exit stays",
        congestion_step(ProbeRttState::Waiting(exit_t), et, inf, tgt, dur),
        oracle_congestion(Some(exit_t), et, inf, tgt, dur),
    );
    n += 1;

    // waiting, event_time < exit_time → stays (inflight irrelevant)
    let (exit_t, et, inf, tgt, dur) = (500u64, 300u64, 0u64, 1000u64, 200u64);
    check(
        "congestion/waiting: event<exit stays (inflight irrelevant)",
        congestion_step(ProbeRttState::Waiting(exit_t), et, inf, tgt, dur),
        oracle_congestion(Some(exit_t), et, inf, tgt, dur),
    );
    n += 1;

    // waiting, inflight above target but timer expired → exits
    let (exit_t, et, inf, tgt, dur) = (100u64, 200u64, 9999u64, 1u64, 50u64);
    check(
        "congestion/waiting: inflight>target but expired exits",
        congestion_step(ProbeRttState::Waiting(exit_t), et, inf, tgt, dur),
        oracle_congestion(Some(exit_t), et, inf, tgt, dur),
    );
    n += 1;

    // waiting, exit_time = 0, event_time = 1 → exits
    let (exit_t, et, inf, tgt, dur) = (0u64, 1u64, 0u64, 0u64, 0u64);
    check(
        "congestion/waiting: exit=0 event=1 exits",
        congestion_step(ProbeRttState::Waiting(exit_t), et, inf, tgt, dur),
        oracle_congestion(Some(exit_t), et, inf, tgt, dur),
    );
    n += 1;

    // waiting, exit_time = 0, event_time = 0 → stays
    let (exit_t, et, inf, tgt, dur) = (0u64, 0u64, 0u64, 0u64, 0u64);
    check(
        "congestion/waiting: exit=0 event=0 stays",
        congestion_step(ProbeRttState::Waiting(exit_t), et, inf, tgt, dur),
        oracle_congestion(Some(exit_t), et, inf, tgt, dur),
    );
    n += 1;

    // -----------------------------------------------------------------------
    // quiescenceStep — DRAINING state
    // -----------------------------------------------------------------------

    // draining always exits
    check(
        "quiescence/draining: always exits",
        quiescence_step(ProbeRttState::Draining, 0),
        oracle_quiescence(None, 0),
    );
    n += 1;

    check(
        "quiescence/draining: always exits (large time)",
        quiescence_step(ProbeRttState::Draining, 99999),
        oracle_quiescence(None, 99999),
    );
    n += 1;

    // -----------------------------------------------------------------------
    // quiescenceStep — WAITING state
    // -----------------------------------------------------------------------

    // now > exit → exits
    let (exit_t, now) = (100u64, 101u64);
    check(
        "quiescence/waiting: now>exit exits",
        quiescence_step(ProbeRttState::Waiting(exit_t), now),
        oracle_quiescence(Some(exit_t), now),
    );
    n += 1;

    // now == exit → stays
    let (exit_t, now) = (100u64, 100u64);
    check(
        "quiescence/waiting: now==exit stays",
        quiescence_step(ProbeRttState::Waiting(exit_t), now),
        oracle_quiescence(Some(exit_t), now),
    );
    n += 1;

    // now < exit → stays
    let (exit_t, now) = (500u64, 200u64);
    check(
        "quiescence/waiting: now<exit stays",
        quiescence_step(ProbeRttState::Waiting(exit_t), now),
        oracle_quiescence(Some(exit_t), now),
    );
    n += 1;

    // now = 0, exit = 0 → stays
    check(
        "quiescence/waiting: both zero stays",
        quiescence_step(ProbeRttState::Waiting(0), 0),
        oracle_quiescence(Some(0), 0),
    );
    n += 1;

    // -----------------------------------------------------------------------
    // §6  Composed lifecycle cases (mirrors §6 theorems in .lean)
    // -----------------------------------------------------------------------

    // Two-step happy path: draining → waiting → exit
    // Mirrors `draining_to_exit_two_steps`
    let (t0, t1, inf0, inf1, tgt, dur) = (50u64, 260u64, 200u64, 100u64, 300u64, 200u64);
    let step1 = congestion_step(ProbeRttState::Draining, t0, inf0, tgt, dur);
    let state1 = match step1 {
        ProbeRttResult::Stay(s) => s,
        _ => panic!("Expected Stay"),
    };
    let step2 = congestion_step(state1, t1, inf1, tgt, dur);
    let oracle1 = oracle_congestion(None, t0, inf0, tgt, dur);
    let exit_t = match oracle1 {
        OracleResult::StaysInProbeRTT { new_exit_time: Some(t) } => t,
        _ => panic!("Expected timer set"),
    };
    let oracle2 = oracle_congestion(Some(exit_t), t1, inf1, tgt, dur);
    check(
        "composed/two-step happy path exits on step2",
        step2,
        oracle2,
    );
    n += 1;

    // Draining stays draining when inflight always above target
    // Mirrors `draining_absorbing_above_target`
    let (et, inf, tgt, dur) = (100u64, 1000u64, 300u64, 200u64);
    let r = congestion_step(ProbeRttState::Draining, et, inf, tgt, dur);
    assert!(
        matches!(r, ProbeRttResult::Stay(ProbeRttState::Draining)),
        "FAIL absorbing: expected Stay(Draining)"
    );
    check(
        "composed/draining absorbing above target",
        r,
        oracle_congestion(None, et, inf, tgt, dur),
    );
    n += 1;

    // Waiting never returns to draining (congestion step)
    // Mirrors `waiting_never_returns_to_draining`
    let (exit_t, et, inf, tgt, dur) = (400u64, 200u64, 0u64, 1000u64, 50u64);
    let r = congestion_step(ProbeRttState::Waiting(exit_t), et, inf, tgt, dur);
    assert!(
        !matches!(r, ProbeRttResult::Stay(ProbeRttState::Draining)),
        "FAIL: waiting returned to draining"
    );
    check(
        "composed/waiting never returns to draining",
        r,
        oracle_congestion(Some(exit_t), et, inf, tgt, dur),
    );
    n += 1;

    // Minimum ProbeRTT duration: exit happens only after duration ticks
    // Mirrors `minimum_probertt_duration`
    // Set timer at t0=1000, duration=200; event at t1=1201 should exit
    let (t0, dur, t1, inf, tgt) = (1000u64, 200u64, 1201u64, 50u64, 300u64);
    let s = congestion_step(ProbeRttState::Draining, t0, inf, tgt, dur);
    let s2 = match s {
        ProbeRttResult::Stay(state) => state,
        _ => panic!("Expected Stay from draining→waiting"),
    };
    let r = congestion_step(s2, t1, inf, tgt, dur);
    check(
        "composed/minimum duration: exits after t0+duration",
        r,
        oracle_congestion(Some(t0 + dur), t1, inf, tgt, dur),
    );
    n += 1;

    // Timer at t0=1000, dur=200; event at t1=1200 (not >1200) should stay
    let (t0, dur, t1, inf, tgt) = (1000u64, 200u64, 1200u64, 50u64, 300u64);
    let s = congestion_step(ProbeRttState::Draining, t0, inf, tgt, dur);
    let s2 = match s {
        ProbeRttResult::Stay(state) => state,
        _ => panic!("Expected Stay"),
    };
    let r = congestion_step(s2, t1, inf, tgt, dur);
    check(
        "composed/minimum duration: stays at exactly t0+duration",
        r,
        oracle_congestion(Some(t0 + dur), t1, inf, tgt, dur),
    );
    n += 1;

    // -----------------------------------------------------------------------
    println!("=== All {n} checks PASS ===");
}
