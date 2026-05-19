// Copyright (C) 2026, Cloudflare, Inc.
// SPDX-License-Identifier: BSD-2-Clause
//
// 🔬 Lean Squad — Route-B correspondence tests for BBR2CyclePhaseGain (T73)
//
// Verifies that the Lean model in
// `formal-verification/lean/FVSquad/BBR2CyclePhaseGain.lean` correctly
// models the pacing and cwnd gain dispatch in
// `quiche/src/recovery/gcongestion/bbr2/mode.rs`.
//
// Run with:
//   rustc --edition 2021 cycle_phase_gain_test.rs && ./cycle_phase_gain_test
//
// No dependencies beyond a standard Rust toolchain.

// ─────────────────────────────────────────────────────────────────────────────
// §1  Rust model — extracted from mode.rs and bbr2.rs (DEFAULT_PARAMS)
// ─────────────────────────────────────────────────────────────────────────────
//
// CyclePhase::pacing_gain (mode.rs):
//   Up   => probe_bw_probe_up_pacing_gain    (DEFAULT: 1.25)
//   Down => probe_bw_probe_down_pacing_gain   (DEFAULT: 0.90)
//   _    => probe_bw_default_pacing_gain      (DEFAULT: 1.00)
//
// CyclePhase::cwnd_gain (mode.rs):
//   Up   => probe_bw_up_cwnd_gain             (DEFAULT: 2.25)
//   _    => probe_bw_cwnd_gain                (DEFAULT: 2.00)
//
// Lean model (BBR2CyclePhaseGain.lean):
//   Gain = { num: Nat, den: Nat } (rational fraction)
//   Up   pacing_gain = { num = 5, den = 4 }  (= 1.25)
//   Down pacing_gain = { num = 9, den = 10 } (= 0.90)
//   _    pacing_gain = { num = 1, den = 1 }  (= 1.00)
//   Up   cwnd_gain   = { num = 9, den = 4 }  (= 2.25)
//   _    cwnd_gain   = { num = 2, den = 1 }  (= 2.00)

#[derive(Debug, Clone, Copy, PartialEq)]
enum CyclePhase {
    NotStarted,
    Up,
    Down,
    Cruise,
    Refill,
}

// Extracted from DEFAULT_PARAMS in bbr2.rs
struct ProbeBWParams {
    probe_bw_probe_up_pacing_gain: f32,
    probe_bw_probe_down_pacing_gain: f32,
    probe_bw_default_pacing_gain: f32,
    probe_bw_up_cwnd_gain: f32,
    probe_bw_cwnd_gain: f32,
}

impl Default for ProbeBWParams {
    fn default() -> Self {
        ProbeBWParams {
            probe_bw_probe_up_pacing_gain: 1.25,
            probe_bw_probe_down_pacing_gain: 0.9,
            probe_bw_default_pacing_gain: 1.0,
            probe_bw_up_cwnd_gain: 2.25,
            probe_bw_cwnd_gain: 2.0,
        }
    }
}

impl CyclePhase {
    fn pacing_gain(&self, params: &ProbeBWParams) -> f32 {
        match self {
            CyclePhase::Up => params.probe_bw_probe_up_pacing_gain,
            CyclePhase::Down => params.probe_bw_probe_down_pacing_gain,
            _ => params.probe_bw_default_pacing_gain,
        }
    }

    fn cwnd_gain(&self, params: &ProbeBWParams) -> f32 {
        match self {
            CyclePhase::Up => params.probe_bw_up_cwnd_gain,
            _ => params.probe_bw_cwnd_gain,
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// §2  Lean model reference values
// ─────────────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Copy)]
struct Gain {
    num: u64,
    den: u64,
}

impl Gain {
    fn to_f32(self) -> f32 {
        self.num as f32 / self.den as f32
    }
}

fn lean_pacing_gain(phase: CyclePhase) -> Gain {
    match phase {
        CyclePhase::Up => Gain { num: 5, den: 4 },
        CyclePhase::Down => Gain { num: 9, den: 10 },
        _ => Gain { num: 1, den: 1 },
    }
}

fn lean_cwnd_gain(phase: CyclePhase) -> Gain {
    match phase {
        CyclePhase::Up => Gain { num: 9, den: 4 },
        _ => Gain { num: 2, den: 1 },
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// §3  Test harness
// ─────────────────────────────────────────────────────────────────────────────

fn main() {
    let params = ProbeBWParams::default();
    let all_phases = [
        CyclePhase::NotStarted,
        CyclePhase::Up,
        CyclePhase::Down,
        CyclePhase::Cruise,
        CyclePhase::Refill,
    ];

    let mut passed = 0usize;
    let mut failed = 0usize;

    // Test 1: default params correspondence
    for &phase in &all_phases {
        let rust_pacing = phase.pacing_gain(&params);
        let lean_pacing = lean_pacing_gain(phase);
        let expected_pacing = lean_pacing.to_f32();
        if rust_pacing == expected_pacing {
            passed += 1;
            println!(
                "PASS  {:?} pacing = {} (lean {}/{})",
                phase, rust_pacing, lean_pacing.num, lean_pacing.den
            );
        } else {
            failed += 1;
            println!(
                "FAIL  {:?} pacing = {} but lean {}/{}={}",
                phase, rust_pacing, lean_pacing.num, lean_pacing.den, expected_pacing
            );
        }

        let rust_cwnd = phase.cwnd_gain(&params);
        let lean_cwnd = lean_cwnd_gain(phase);
        let expected_cwnd = lean_cwnd.to_f32();
        if rust_cwnd == expected_cwnd {
            passed += 1;
            println!(
                "PASS  {:?} cwnd   = {} (lean {}/{})",
                phase, rust_cwnd, lean_cwnd.num, lean_cwnd.den
            );
        } else {
            failed += 1;
            println!(
                "FAIL  {:?} cwnd   = {} but lean {}/{}={}",
                phase, rust_cwnd, lean_cwnd.num, lean_cwnd.den, expected_cwnd
            );
        }
    }

    // Test 2: dispatch partitioning — Up vs non-Up
    let custom = ProbeBWParams {
        probe_bw_probe_up_pacing_gain: 1.5,
        probe_bw_probe_down_pacing_gain: 0.75,
        probe_bw_default_pacing_gain: 1.0,
        probe_bw_up_cwnd_gain: 3.0,
        probe_bw_cwnd_gain: 2.0,
    };

    let non_up_phases = [
        CyclePhase::NotStarted,
        CyclePhase::Cruise,
        CyclePhase::Refill,
    ];

    for &phase in &non_up_phases {
        let pg = phase.pacing_gain(&custom);
        if pg == custom.probe_bw_default_pacing_gain {
            passed += 1;
            println!("PASS  {:?} pacing=default dispatch correct", phase);
        } else {
            failed += 1;
            println!(
                "FAIL  {:?} pacing dispatch: got {} want {}",
                phase, pg, custom.probe_bw_default_pacing_gain
            );
        }
        let cg = phase.cwnd_gain(&custom);
        if cg == custom.probe_bw_cwnd_gain {
            passed += 1;
            println!("PASS  {:?} cwnd=default dispatch correct", phase);
        } else {
            failed += 1;
            println!(
                "FAIL  {:?} cwnd dispatch: got {} want {}",
                phase, cg, custom.probe_bw_cwnd_gain
            );
        }
    }

    // Up dispatch
    let up_pg = CyclePhase::Up.pacing_gain(&custom);
    if up_pg == custom.probe_bw_probe_up_pacing_gain {
        passed += 1;
        println!("PASS  Up pacing dispatch correct");
    } else {
        failed += 1;
        println!("FAIL  Up pacing dispatch: got {} want {}", up_pg, custom.probe_bw_probe_up_pacing_gain);
    }
    let up_cg = CyclePhase::Up.cwnd_gain(&custom);
    if up_cg == custom.probe_bw_up_cwnd_gain {
        passed += 1;
        println!("PASS  Up cwnd dispatch correct");
    } else {
        failed += 1;
        println!("FAIL  Up cwnd dispatch: got {} want {}", up_cg, custom.probe_bw_up_cwnd_gain);
    }

    // Down dispatch
    let down_pg = CyclePhase::Down.pacing_gain(&custom);
    if down_pg == custom.probe_bw_probe_down_pacing_gain {
        passed += 1;
        println!("PASS  Down pacing dispatch correct");
    } else {
        failed += 1;
        println!("FAIL  Down pacing dispatch: got {} want {}", down_pg, custom.probe_bw_probe_down_pacing_gain);
    }
    let down_cg = CyclePhase::Down.cwnd_gain(&custom);
    if down_cg == custom.probe_bw_cwnd_gain {
        passed += 1;
        println!("PASS  Down cwnd=default dispatch correct");
    } else {
        failed += 1;
        println!("FAIL  Down cwnd dispatch: got {} want {}", down_cg, custom.probe_bw_cwnd_gain);
    }

    // Test 3: ordering invariants (Lean theorems upPacingGain_ge_unity,
    // downPacingGain_subUnity, etc.)
    let up_pacing = CyclePhase::Up.pacing_gain(&params);
    let down_pacing = CyclePhase::Down.pacing_gain(&params);
    let default_pacing = CyclePhase::Cruise.pacing_gain(&params);
    let up_cwnd = CyclePhase::Up.cwnd_gain(&params);
    let default_cwnd = CyclePhase::Cruise.cwnd_gain(&params);

    // up > default > down  (pacing order)
    if up_pacing > default_pacing && default_pacing > down_pacing {
        passed += 1;
        println!(
            "PASS  pacing ordering: up({}) > default({}) > down({})",
            up_pacing, default_pacing, down_pacing
        );
    } else {
        failed += 1;
        println!(
            "FAIL  pacing ordering violated: up={} default={} down={}",
            up_pacing, default_pacing, down_pacing
        );
    }

    // up_cwnd > default_cwnd
    if up_cwnd > default_cwnd {
        passed += 1;
        println!(
            "PASS  cwnd ordering: up({}) > default({})",
            up_cwnd, default_cwnd
        );
    } else {
        failed += 1;
        println!(
            "FAIL  cwnd ordering violated: up={} default={}",
            up_cwnd, default_cwnd
        );
    }

    // up pacing > 1.0 (super-unity)
    if up_pacing > 1.0 {
        passed += 1;
        println!("PASS  up pacing > 1 (super-unity)");
    } else {
        failed += 1;
        println!("FAIL  up pacing should be > 1, got {}", up_pacing);
    }

    // down pacing < 1.0 (sub-unity)
    if down_pacing < 1.0 {
        passed += 1;
        println!("PASS  down pacing < 1 (sub-unity)");
    } else {
        failed += 1;
        println!("FAIL  down pacing should be < 1, got {}", down_pacing);
    }

    // default pacing == 1.0
    if default_pacing == 1.0 {
        passed += 1;
        println!("PASS  default pacing == 1.0 (unity)");
    } else {
        failed += 1;
        println!("FAIL  default pacing should be 1.0, got {}", default_pacing);
    }

    println!("\nResult: {}/{} PASS", passed, passed + failed);
    if failed > 0 {
        eprintln!("{} case(s) FAILED", failed);
        std::process::exit(1);
    }
    println!("All {} tests PASS ✓", passed);
}
