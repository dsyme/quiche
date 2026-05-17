// Copyright (C) 2024, Cloudflare, Inc.
// SPDX-License-Identifier: BSD-2-Clause
//
// 🔬 Lean Squad — Route-B correspondence tests for CidMgmt retire_if_needed
//
// Verifies that the Lean model `CidState.newScidRetire` in
// `formal-verification/lean/FVSquad/CidMgmt.lean` (§10) agrees with the
// pure retire-if-needed logic extracted from `quiche/src/cid.rs`.
//
// Run with:
//   rustc --edition 2021 cid_mgmt_retire_test.rs && ./cid_mgmt_retire_test
//
// Source under test:
//   quiche/src/cid.rs — ConnectionIdentifiers::new_scid (retire_if_needed path)
//
// Lean model:
//   formal-verification/lean/FVSquad/CidMgmt.lean §10
//   CidState.newScidRetire, lowestSeq

// ─────────────────────────────────────────────────────────────────────────────
// §1  Rust model — pure logic extracted from new_scid + retire_if_needed path
// ─────────────────────────────────────────────────────────────────────────────
//
// The Rust `ConnectionIdentifiers::new_scid` path when `retire_if_needed = true`
// and `scids.len() >= source_conn_id_limit`:
//
//   1. Compute `lowest_usable_scid_seq()` → min of all seqs ≥ retire_prior_to.
//      In our model retire_prior_to = 0 (initial), so lowest = min of all seqs.
//   2. Set `retire_prior_to = lowest + 1`  (signals peer to retire the old CID)
//   3. Insert the new CID with the next seq number.
//
// In the Lean model the atomic action is: if |activeSeqs| ≥ limit, remove the
// minimum element, then add nextSeq; otherwise just add nextSeq.

/// Minimal CID state: sequence numbers only (no CID bytes, no path_id).
#[derive(Clone, Debug, PartialEq)]
struct CidState {
    next_seq: u64,
    active_seqs: Vec<u64>,
    limit: usize,
}

impl CidState {
    fn new(next_seq: u64, active_seqs: Vec<u64>, limit: usize) -> Self {
        CidState {
            next_seq,
            active_seqs,
            limit,
        }
    }

    /// Lean model `lowestSeq`: minimum element of the list (0 if empty).
    fn lowest_seq(seqs: &[u64]) -> u64 {
        seqs.iter().copied().min().unwrap_or(0)
    }

    /// Lean model `CidState.newScidRetire`:
    ///   - If |active_seqs| < limit: just add next_seq, increment next_seq.
    ///   - Else: remove lowest seq, add next_seq, increment next_seq.
    fn new_scid_retire(&self) -> CidState {
        let mut result = self.clone();
        if result.active_seqs.len() < result.limit {
            // Normal path
            result.active_seqs.push(result.next_seq);
        } else {
            // retire_if_needed path: remove lowest, add new
            let lowest = Self::lowest_seq(&result.active_seqs);
            result.active_seqs.retain(|&s| s != lowest);
            result.active_seqs.push(result.next_seq);
        }
        result.next_seq += 1;
        result
    }

    /// Apply `new_scid_retire` n times from a given state.
    fn apply_n(&self, n: usize) -> CidState {
        let mut s = self.clone();
        for _ in 0..n {
            s = s.new_scid_retire();
        }
        s
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// §2  Test harness
// ─────────────────────────────────────────────────────────────────────────────

struct Test {
    name: &'static str,
    before: CidState,
    after: CidState,
}

fn run_tests(tests: &[Test]) -> (usize, usize) {
    let mut pass = 0;
    let mut fail = 0;
    for t in tests {
        let got = t.before.new_scid_retire();
        if got == t.after {
            pass += 1;
        } else {
            eprintln!("FAIL: {}", t.name);
            eprintln!("  before: {:?}", t.before);
            eprintln!("  got:    {:?}", got);
            eprintln!("  want:   {:?}", t.after);
            fail += 1;
        }
    }
    (pass, fail)
}

// ─────────────────────────────────────────────────────────────────────────────
// §3  Property checks (not equality, but invariant assertions)
// ─────────────────────────────────────────────────────────────────────────────

fn check_property(name: &str, ok: bool) -> bool {
    if ok {
        true
    } else {
        eprintln!("PROPERTY FAIL: {}", name);
        false
    }
}

fn main() {
    let mut all_pass = 0usize;
    let mut all_fail = 0usize;

    // ── Group 1: Normal path (below limit) ──────────────────────────────────
    let normal_tests = vec![
        Test {
            name: "normal: single CID, limit 4",
            before: CidState::new(1, vec![0], 4),
            after: CidState::new(2, vec![0, 1], 4),
        },
        Test {
            name: "normal: two CIDs, limit 4",
            before: CidState::new(2, vec![0, 1], 4),
            after: CidState::new(3, vec![0, 1, 2], 4),
        },
        Test {
            name: "normal: three CIDs, limit 4",
            before: CidState::new(3, vec![0, 1, 2], 4),
            after: CidState::new(4, vec![0, 1, 2, 3], 4),
        },
        Test {
            name: "normal: limit 2, one CID",
            before: CidState::new(1, vec![0], 2),
            after: CidState::new(2, vec![0, 1], 2),
        },
        Test {
            name: "normal: limit 1, active=[] edge (0 < 1)",
            before: CidState::new(5, vec![], 1),
            after: CidState::new(6, vec![5], 1),
        },
    ];
    let (p, f) = run_tests(&normal_tests);
    all_pass += p;
    all_fail += f;

    // ── Group 2: At-limit path (retire_if_needed fires) ─────────────────────
    // When |active_seqs| == limit, lowest is retired and new one is added.
    let retire_tests = vec![
        Test {
            name: "retire: limit=2, seqs=[0,1] → retire 0, add 2",
            before: CidState::new(2, vec![0, 1], 2),
            after: CidState::new(3, vec![1, 2], 2),
        },
        Test {
            name: "retire: limit=2, seqs=[1,2] → retire 1, add 3",
            before: CidState::new(3, vec![1, 2], 2),
            after: CidState::new(4, vec![2, 3], 2),
        },
        Test {
            name: "retire: limit=3, seqs=[0,1,2] → retire 0, add 3",
            before: CidState::new(3, vec![0, 1, 2], 3),
            after: CidState::new(4, vec![1, 2, 3], 3),
        },
        Test {
            name: "retire: limit=1, seqs=[7] → retire 7, add 8",
            before: CidState::new(8, vec![7], 1),
            after: CidState::new(9, vec![8], 1),
        },
        Test {
            name: "retire: non-contiguous [3,7], limit=2 → retire 3, add 9",
            before: CidState::new(9, vec![3, 7], 2),
            after: CidState::new(10, vec![7, 9], 2),
        },
        Test {
            name: "retire: reversed order [5,2], limit=2 → retire 2, add 6",
            before: CidState::new(6, vec![5, 2], 2),
            after: CidState::new(7, vec![5, 6], 2),
        },
        Test {
            name: "retire: limit=4, seqs=[0,1,2,3] → retire 0, add 4",
            before: CidState::new(4, vec![0, 1, 2, 3], 4),
            after: CidState::new(5, vec![1, 2, 3, 4], 4),
        },
    ];
    let (p, f) = run_tests(&retire_tests);
    all_pass += p;
    all_fail += f;

    // ── Group 3: Invariant properties after retire ───────────────────────────
    // For each state, verify the key invariants the Lean proofs assert.
    let prop_cases: &[(CidState, &str)] = &[
        (CidState::new(2, vec![0, 1], 2), "at-limit-2"),
        (CidState::new(3, vec![0, 1, 2], 3), "at-limit-3"),
        (CidState::new(4, vec![0, 1, 2, 3], 4), "at-limit-4"),
        (CidState::new(3, vec![1, 2], 2), "below-limit-2"),
        (CidState::new(5, vec![0, 1, 2, 3], 4), "below-limit-4"),
        (CidState::new(10, vec![3, 7], 2), "non-contiguous"),
    ];

    for (state, label) in prop_cases {
        let after = state.new_scid_retire();
        // Invariant 1: next_seq increased by 1
        let ok1 = check_property(
            &format!("{label}: next_seq+1"),
            after.next_seq == state.next_seq + 1,
        );
        // Invariant 2: new seq is in active list
        let ok2 = check_property(
            &format!("{label}: new seq in active"),
            after.active_seqs.contains(&state.next_seq),
        );
        // Invariant 3: count ≤ limit after retire
        let ok3 = check_property(
            &format!("{label}: count ≤ limit"),
            after.active_seqs.len() <= state.limit,
        );
        // Invariant 4 (retire path only): lowest old seq is gone
        if state.active_seqs.len() >= state.limit {
            let lowest = CidState::lowest_seq(&state.active_seqs);
            let ok4 = check_property(
                &format!("{label}: lowest retired (lowest={lowest})"),
                !after.active_seqs.contains(&lowest),
            );
            if !ok4 { all_fail += 1; } else { all_pass += 1; }
        }
        if ok1 && ok2 && ok3 { all_pass += 3; } else { all_fail += 3 - [ok1, ok2, ok3].iter().filter(|&&b| b).count(); all_pass += [ok1, ok2, ok3].iter().filter(|&&b| b).count(); }
    }

    // ── Group 4: Multi-step sequences ───────────────────────────────────────
    // Apply retire 5 times from [0], limit=2 and verify count stays ≤ 2
    let s = CidState::new(1, vec![0], 2);
    for i in 1..=5usize {
        let si = s.apply_n(i);
        let ok = check_property(
            &format!("multi-step i={i}: count ≤ limit"),
            si.active_seqs.len() <= si.limit,
        );
        let ok2 = check_property(
            &format!("multi-step i={i}: next_seq = {}", 1 + i as u64),
            si.next_seq == 1 + i as u64,
        );
        if ok { all_pass += 1; } else { all_fail += 1; }
        if ok2 { all_pass += 1; } else { all_fail += 1; }
    }

    // Apply retire 10 times from limit=3 initial
    let s3 = CidState::new(1, vec![0], 3);
    for i in 1..=10usize {
        let si = s3.apply_n(i);
        let ok = check_property(
            &format!("multi-step-3 i={i}: count ≤ 3"),
            si.active_seqs.len() <= 3,
        );
        if ok { all_pass += 1; } else { all_fail += 1; }
    }

    // ── Result summary ───────────────────────────────────────────────────────
    println!(
        "CidMgmt retire_if_needed Route-B correspondence tests: {}/{} PASS",
        all_pass,
        all_pass + all_fail
    );
    if all_fail > 0 {
        std::process::exit(1);
    }
}
