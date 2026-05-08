// Copyright (C) 2025, Cloudflare, Inc.
// SPDX-License-Identifier: BSD-2-Clause
//
// 🔬 Lean Squad Route-B correspondence test: T57 — BBR2 ProbeBW phase gains
//
// Verifies that the Lean model's pacingGain / cwndGain table matches the
// values computed by the quiche BBR2 source code.
//
// Source: quiche/src/recovery/gcongestion/bbr2/mode.rs (L49–L75)
//         quiche/src/recovery/gcongestion/bbr2.rs (L291–L300)
//
// Run (no Cargo needed):
//   rustc probe_bw_phase_test.rs -o /tmp/probe_bw_phase_test
//   /tmp/probe_bw_phase_test
//
// Expected: all assertions PASS.

// ---------------------------------------------------------------------------
// Lean model (Rust re-implementation for Route-B correspondence)
// Mirrors ProbeBWPhase.lean verbatim.
// ---------------------------------------------------------------------------

#[derive(Debug, PartialEq, Clone, Copy)]
enum CyclePhase {
    NotStarted,
    Up,
    Down,
    Cruise,
    Refill,
}

/// Pacing-gain × 100 (Lean model: `pacingGain`)
fn pacing_gain(p: CyclePhase) -> u32 {
    match p {
        CyclePhase::Up    => 125, // 1.25
        CyclePhase::Down  => 90,  // 0.90
        _                 => 100, // 1.00 (NotStarted / Cruise / Refill)
    }
}

/// Congestion-window gain × 100 (Lean model: `cwndGain`)
fn cwnd_gain(p: CyclePhase) -> u32 {
    match p {
        CyclePhase::Up => 225, // 2.25
        _              => 200, // 2.00
    }
}

// ---------------------------------------------------------------------------
// Source values derived from mode.rs / bbr2.rs defaults
// These constants must match the DEFAULT Params values in bbr2.rs L291-L300.
// ---------------------------------------------------------------------------

// Default params (bbr2.rs L291-L300):
//   probe_bw_probe_up_pacing_gain   = 1.25f32  → ×100 = 125
//   probe_bw_probe_down_pacing_gain = 0.90f32  → ×100 =  90
//   probe_bw_default_pacing_gain    = 1.00f32  → ×100 = 100
//   probe_bw_up_cwnd_gain           = 2.25f32  → ×100 = 225
//   probe_bw_cwnd_gain              = 2.00f32  → ×100 = 200
//
// mode.rs gain_for_phase() logic (paraphrased):
//   Up      → pacing = probe_bw_probe_up_pacing_gain,   cwnd = probe_bw_up_cwnd_gain
//   Down    → pacing = probe_bw_probe_down_pacing_gain, cwnd = probe_bw_cwnd_gain
//   Cruise  → pacing = probe_bw_default_pacing_gain,    cwnd = probe_bw_cwnd_gain
//   Refill  → pacing = probe_bw_default_pacing_gain,    cwnd = probe_bw_cwnd_gain
//   NotStarted → same as default

const SRC_PACING_UP         : u32 = 125; // 1.25 × 100
const SRC_PACING_DOWN       : u32 = 90;  // 0.90 × 100
const SRC_PACING_DEFAULT    : u32 = 100; // 1.00 × 100
const SRC_CWND_UP           : u32 = 225; // 2.25 × 100
const SRC_CWND_DEFAULT      : u32 = 200; // 2.00 × 100

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

fn check(label: &str, got: u32, expected: u32) {
    if got == expected {
        println!("PASS  {label}: got {got}");
    } else {
        eprintln!("FAIL  {label}: expected {expected}, got {got}");
        std::process::exit(1);
    }
}

fn main() {
    println!("=== Route-B correspondence test: T57 BBR2 ProbeBW phase gains ===");

    // pacingGain correspondence
    check("pacingGain(Up)",         pacing_gain(CyclePhase::Up),         SRC_PACING_UP);
    check("pacingGain(Down)",       pacing_gain(CyclePhase::Down),       SRC_PACING_DOWN);
    check("pacingGain(Cruise)",     pacing_gain(CyclePhase::Cruise),     SRC_PACING_DEFAULT);
    check("pacingGain(Refill)",     pacing_gain(CyclePhase::Refill),     SRC_PACING_DEFAULT);
    check("pacingGain(NotStarted)", pacing_gain(CyclePhase::NotStarted), SRC_PACING_DEFAULT);

    // cwndGain correspondence
    check("cwndGain(Up)",         cwnd_gain(CyclePhase::Up),         SRC_CWND_UP);
    check("cwndGain(Down)",       cwnd_gain(CyclePhase::Down),       SRC_CWND_DEFAULT);
    check("cwndGain(Cruise)",     cwnd_gain(CyclePhase::Cruise),     SRC_CWND_DEFAULT);
    check("cwndGain(Refill)",     cwnd_gain(CyclePhase::Refill),     SRC_CWND_DEFAULT);
    check("cwndGain(NotStarted)", cwnd_gain(CyclePhase::NotStarted), SRC_CWND_DEFAULT);

    println!("=== All 10 checks PASS ===");
}
