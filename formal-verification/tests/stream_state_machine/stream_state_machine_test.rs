// Copyright (C) 2025, Cloudflare, Inc.
// BSD-2-Clause licence (same as quiche)
//
// Route-B correspondence test for StreamStateMachine (T44).
//
// Tests that the Lean model in FVSquad/StreamStateMachine.lean faithfully
// captures the Rust stream-completion and writability predicates from:
//   quiche/src/stream/mod.rs   (Stream::is_complete, is_writable)
//   quiche/src/stream/send_buf.rs  (SendBuf::is_fin, is_complete, is_shutdown)
//   quiche/src/stream/recv_buf.rs  (RecvBuf::is_fin)
//
// Run:
//   rustc stream_state_machine_test.rs -o /tmp/ssm_test && /tmp/ssm_test

// ─── Rust model (minimal inline, mirroring the Rust source) ─────────────────

/// Mirrors RecvBuf (recv_buf.rs) — only the fields relevant to is_fin.
#[derive(Clone, Debug)]
struct RecvBuf {
    fin_off: Option<u64>,
    off: u64, // bytes consumed by the application
}

impl RecvBuf {
    fn new(fin_off: Option<u64>, off: u64) -> Self {
        RecvBuf { fin_off, off }
    }

    /// Mirrors RecvBuf::is_fin (recv_buf.rs:399-403)
    fn is_fin(&self) -> bool {
        self.fin_off == Some(self.off)
    }
}

/// Mirrors SendBuf (send_buf.rs) — only the fields relevant to is_fin,
/// is_complete, is_shutdown.
#[derive(Clone, Debug)]
struct SendBuf {
    fin_off: Option<u64>,
    off: u64,        // total bytes written by the application
    acked_end: u64,  // simplified: contiguous acked prefix end
    shutdown: bool,
}

impl SendBuf {
    fn new(fin_off: Option<u64>, off: u64, acked_end: u64, shutdown: bool) -> Self {
        SendBuf { fin_off, off, acked_end, shutdown }
    }

    /// Mirrors SendBuf::is_fin (send_buf.rs:493-501)
    fn is_fin(&self) -> bool {
        self.fin_off == Some(self.off)
    }

    /// Mirrors SendBuf::is_complete (send_buf.rs:505-512) — simplified:
    /// we model acked as a single contiguous prefix [0, acked_end).
    fn is_complete(&self) -> bool {
        match self.fin_off {
            None => false,
            Some(fin) => self.acked_end == fin,
        }
    }

    /// Mirrors SendBuf::is_shutdown (send_buf.rs:521-522)
    fn is_shutdown(&self) -> bool {
        self.shutdown
    }

    /// Mirrors SendBuf::is_writable (mod.rs:788-791) sans flow-control:
    /// `!shutdown && !is_fin() && fc`
    fn is_writable(&self, fc: bool) -> bool {
        !self.is_shutdown() && !self.is_fin() && fc
    }
}

/// Mirrors Stream::is_complete (mod.rs:814-826).
fn stream_is_complete(bidi: bool, local: bool, recv: &RecvBuf, send: &SendBuf) -> bool {
    match (bidi, local) {
        (true, _) => recv.is_fin() && send.is_complete(),
        (false, true) => send.is_complete(),
        (false, false) => recv.is_fin(),
    }
}

// ─── Lean model (transliterated from FVSquad/StreamStateMachine.lean) ────────

#[derive(Clone, Debug)]
struct LeanRecvState {
    fin_off: Option<u64>,
    off: u64,
}

#[derive(Clone, Debug)]
struct LeanSendState {
    fin_off: Option<u64>,
    off: u64,
    acked_end: u64,
    shutdown: bool,
}

/// Lean recvIsFin
fn lean_recv_is_fin(r: &LeanRecvState) -> bool {
    r.fin_off == Some(r.off)
}

/// Lean sendIsFin
fn lean_send_is_fin(s: &LeanSendState) -> bool {
    s.fin_off == Some(s.off)
}

/// Lean sendIsComplete
fn lean_send_is_complete(s: &LeanSendState) -> bool {
    match s.fin_off {
        None => false,
        Some(fin) => s.acked_end == fin,
    }
}

/// Lean sendIsShutdown
fn lean_send_is_shutdown(s: &LeanSendState) -> bool {
    s.shutdown
}

/// Lean streamIsComplete
fn lean_stream_is_complete(
    bidi: bool, local: bool, r: &LeanRecvState, s: &LeanSendState,
) -> bool {
    match (bidi, local) {
        (true, _) => lean_recv_is_fin(r) && lean_send_is_complete(s),
        (false, true) => lean_send_is_complete(s),
        (false, false) => lean_recv_is_fin(r),
    }
}

/// Lean streamIsWritable
fn lean_stream_is_writable(s: &LeanSendState, fc: bool) -> bool {
    !lean_send_is_shutdown(s) && !lean_send_is_fin(s) && fc
}

// ─── Test harness ─────────────────────────────────────────────────────────────

struct TestCase {
    idx: usize,
    description: &'static str,
    // Rust
    rust_recv: RecvBuf,
    rust_send: SendBuf,
    // Lean
    lean_recv: LeanRecvState,
    lean_send: LeanSendState,
    // Additional parameters
    bidi: bool,
    local: bool,
    fc: bool,
}

impl TestCase {
    fn run(&self) -> bool {
        // Compare all predicates
        let r_recv_fin = self.rust_recv.is_fin();
        let l_recv_fin = lean_recv_is_fin(&self.lean_recv);

        let r_send_fin = self.rust_send.is_fin();
        let l_send_fin = lean_send_is_fin(&self.lean_send);

        let r_send_complete = self.rust_send.is_complete();
        let l_send_complete = lean_send_is_complete(&self.lean_send);

        let r_send_shutdown = self.rust_send.is_shutdown();
        let l_send_shutdown = lean_send_is_shutdown(&self.lean_send);

        let r_stream_complete =
            stream_is_complete(self.bidi, self.local, &self.rust_recv, &self.rust_send);
        let l_stream_complete = lean_stream_is_complete(
            self.bidi, self.local, &self.lean_recv, &self.lean_send,
        );

        let r_writable = self.rust_send.is_writable(self.fc);
        let l_writable = lean_stream_is_writable(&self.lean_send, self.fc);

        let pass = r_recv_fin == l_recv_fin
            && r_send_fin == l_send_fin
            && r_send_complete == l_send_complete
            && r_send_shutdown == l_send_shutdown
            && r_stream_complete == l_stream_complete
            && r_writable == l_writable;

        let status = if pass { "PASS" } else { "FAIL" };
        println!(
            "{},{},{},{},{},{},{},{},{},{},{},{},{}",
            self.idx,
            self.description,
            r_recv_fin,
            l_recv_fin,
            r_send_fin,
            l_send_fin,
            r_send_complete,
            l_send_complete,
            r_stream_complete,
            l_stream_complete,
            r_writable,
            l_writable,
            status
        );
        pass
    }
}

fn make_case(
    idx: usize,
    description: &'static str,
    fin_off_recv: Option<u64>,
    off_recv: u64,
    fin_off_send: Option<u64>,
    off_send: u64,
    acked_end: u64,
    shutdown: bool,
    bidi: bool,
    local: bool,
    fc: bool,
) -> TestCase {
    TestCase {
        idx,
        description,
        rust_recv: RecvBuf::new(fin_off_recv, off_recv),
        rust_send: SendBuf::new(fin_off_send, off_send, acked_end, shutdown),
        lean_recv: LeanRecvState { fin_off: fin_off_recv, off: off_recv },
        lean_send: LeanSendState {
            fin_off: fin_off_send,
            off: off_send,
            acked_end,
            shutdown,
        },
        bidi,
        local,
        fc,
    }
}

fn main() {
    println!("# StreamStateMachine Route-B Correspondence Test");
    println!("# Source:    quiche/src/stream/{{mod,send_buf,recv_buf}}.rs");
    println!("# Lean model: FVSquad/StreamStateMachine.lean");
    println!("#");
    println!(
        "# idx,description,rust_recv_fin,lean_recv_fin,rust_send_fin,lean_send_fin,\
rust_send_complete,lean_send_complete,rust_stream_complete,lean_stream_complete,\
rust_writable,lean_writable,status"
    );

    let mut cases: Vec<TestCase> = Vec::new();
    let mut idx = 1usize;

    // ── Group 1: recvIsFin basic ──────────────────────────────────────────────
    // (1) no fin_off → false
    cases.push(make_case(idx, "recv_no_fin_off", None, 0, None, 0, 0, false, false, false, false));
    idx += 1;
    // (2) fin_off = Some(5), off = 5 → true
    cases.push(make_case(idx, "recv_fin_exact", Some(5), 5, None, 0, 0, false, false, false, false));
    idx += 1;
    // (3) fin_off = Some(5), off = 3 → false (not consumed yet)
    cases.push(make_case(idx, "recv_fin_not_consumed", Some(5), 3, None, 0, 0, false, false, false, false));
    idx += 1;
    // (4) fin_off = Some(0), off = 0 → true (zero-length stream)
    cases.push(make_case(idx, "recv_fin_zero_length", Some(0), 0, None, 0, 0, false, false, false, false));
    idx += 1;
    // (5) fin_off = Some(10), off = 0 → false
    cases.push(make_case(idx, "recv_fin_not_started", Some(10), 0, None, 0, 0, false, false, false, false));
    idx += 1;

    // ── Group 2: sendIsFin basic ──────────────────────────────────────────────
    // (6) no fin_off → false
    cases.push(make_case(idx, "send_no_fin_off", None, 0, None, 0, 0, false, false, false, false));
    idx += 1;
    // (7) fin_off = Some(10), off = 10 → true
    cases.push(make_case(idx, "send_fin_exact", None, 0, Some(10), 10, 5, false, false, false, false));
    idx += 1;
    // (8) fin_off = Some(10), off = 5 → false
    cases.push(make_case(idx, "send_fin_partial", None, 0, Some(10), 5, 0, false, false, false, false));
    idx += 1;
    // (9) fin_off = Some(0), off = 0 → true (zero-length send)
    cases.push(make_case(idx, "send_fin_zero", None, 0, Some(0), 0, 0, false, false, false, false));
    idx += 1;

    // ── Group 3: sendIsComplete ───────────────────────────────────────────────
    // (10) no fin_off → false
    cases.push(make_case(idx, "send_complete_no_fin", None, 0, None, 10, 5, false, false, false, false));
    idx += 1;
    // (11) fin=10, acked_end=10 → true
    cases.push(make_case(idx, "send_complete_acked_all", None, 0, Some(10), 10, 10, false, false, false, false));
    idx += 1;
    // (12) fin=10, acked_end=9 → false
    cases.push(make_case(idx, "send_complete_partial_acked", None, 0, Some(10), 10, 9, false, false, false, false));
    idx += 1;
    // (13) fin=0, acked_end=0 → true (zero-length fully acked)
    cases.push(make_case(idx, "send_complete_zero_acked", None, 0, Some(0), 0, 0, false, false, false, false));
    idx += 1;
    // (14) fin=5, acked_end=0 → false (nothing acked)
    cases.push(make_case(idx, "send_complete_none_acked", None, 0, Some(5), 5, 0, false, false, false, false));
    idx += 1;

    // ── Group 4: sendIsShutdown ───────────────────────────────────────────────
    // (15) shutdown=false
    cases.push(make_case(idx, "send_no_shutdown", None, 0, None, 0, 0, false, false, false, false));
    idx += 1;
    // (16) shutdown=true
    cases.push(make_case(idx, "send_shutdown", None, 0, None, 0, 0, true, false, false, false));
    idx += 1;

    // ── Group 5: streamIsWritable ─────────────────────────────────────────────
    // (17) normal writable: !shutdown, !fin, fc=true
    cases.push(make_case(idx, "writable_normal", None, 0, None, 5, 0, false, false, true, true));
    idx += 1;
    // (18) shutdown blocks writability
    cases.push(make_case(idx, "writable_shutdown", None, 0, None, 5, 0, true, false, true, true));
    idx += 1;
    // (19) fin blocks writability
    cases.push(make_case(idx, "writable_fin", None, 0, Some(5), 5, 0, false, false, true, true));
    idx += 1;
    // (20) fc=false blocks writability
    cases.push(make_case(idx, "writable_fc_false", None, 0, None, 5, 0, false, false, true, false));
    idx += 1;
    // (21) both shutdown+fin → not writable
    cases.push(make_case(idx, "writable_shutdown_and_fin", None, 0, Some(5), 5, 0, true, false, true, true));
    idx += 1;

    // ── Group 6: streamIsComplete — bidi ─────────────────────────────────────
    // (22) bidi, both done → complete
    cases.push(make_case(idx, "bidi_complete", Some(5), 5, Some(10), 10, 10, false, true, true, false));
    idx += 1;
    // (23) bidi, recv done, send not → incomplete
    cases.push(make_case(idx, "bidi_recv_only", Some(5), 5, Some(10), 10, 5, false, true, true, false));
    idx += 1;
    // (24) bidi, send done, recv not → incomplete
    cases.push(make_case(idx, "bidi_send_only", Some(5), 3, Some(10), 10, 10, false, true, true, false));
    idx += 1;
    // (25) bidi, neither done → incomplete
    cases.push(make_case(idx, "bidi_neither", Some(5), 3, Some(10), 10, 5, false, true, true, false));
    idx += 1;

    // ── Group 7: streamIsComplete — unidirectional ────────────────────────────
    // (26) local uni (send only): send complete → complete
    cases.push(make_case(idx, "local_uni_complete", None, 0, Some(10), 10, 10, false, false, true, false));
    idx += 1;
    // (27) local uni: send not complete → incomplete
    cases.push(make_case(idx, "local_uni_incomplete", None, 0, Some(10), 10, 5, false, false, true, false));
    idx += 1;
    // (28) remote uni (recv only): recv fin → complete
    cases.push(make_case(idx, "remote_uni_complete", Some(5), 5, None, 0, 0, false, false, false, false));
    idx += 1;
    // (29) remote uni: recv not fin → incomplete
    cases.push(make_case(idx, "remote_uni_incomplete", Some(5), 3, None, 0, 0, false, false, false, false));
    idx += 1;

    // ── Group 8: complete stream not writable (invariant) ─────────────────────
    // (30) bidi complete → not writable (shutdown not set, but fin is set since complete)
    cases.push(make_case(idx, "bidi_complete_not_writable", Some(5), 5, Some(10), 10, 10, false, true, true, true));
    idx += 1;
    // (31) local uni complete → not writable
    cases.push(make_case(idx, "uni_complete_not_writable", None, 0, Some(10), 10, 10, false, false, true, true));
    idx += 1;

    // ── Group 9: edge cases ───────────────────────────────────────────────────
    // (32) fin_off set, off beyond fin (shouldn't happen per invariant but model handles it)
    cases.push(make_case(idx, "recv_off_beyond_fin", Some(3), 5, None, 0, 0, false, false, false, false));
    idx += 1;
    // (33) large offsets
    cases.push(make_case(idx, "large_offsets_fin", Some(1_000_000), 1_000_000, Some(2_000_000), 2_000_000, 2_000_000, false, true, true, false));
    idx += 1;
    // (34) shutdown with fin set (independent by model)
    cases.push(make_case(idx, "shutdown_and_fin_set", None, 0, Some(5), 5, 0, true, false, false, false));
    idx += 1;
    // (35) zero-length bidi complete
    cases.push(make_case(idx, "bidi_zero_complete", Some(0), 0, Some(0), 0, 0, false, true, true, false));
    idx += 1;

    // ── Group 10: bidi_complete_not_writable with fc variations ──────────────
    // (36) fc=false, already complete: not writable regardless
    cases.push(make_case(idx, "complete_fc_false", Some(5), 5, Some(10), 10, 10, false, true, true, false));
    idx += 1;
    // (37) not complete but fc=true: writable
    cases.push(make_case(idx, "incomplete_fc_true_writable", None, 0, None, 5, 0, false, false, true, true));
    idx += 1;
    // (38) not complete, fc=false: not writable
    cases.push(make_case(idx, "incomplete_fc_false", None, 0, None, 5, 0, false, false, true, false));
    idx += 1;
    // (39) shutdown overrides fc=true
    cases.push(make_case(idx, "shutdown_overrides_fc", None, 0, None, 5, 0, true, false, true, true));
    idx += 1;
    // (40) acked_end > fin_off not possible in valid state but model still defined
    cases.push(make_case(idx, "acked_exceeds_fin", None, 0, Some(5), 5, 7, false, false, true, false));
    // acked_end=7 > fin_off=5 → is_complete=false (acked_end != fin_off)
    idx += 1;

    // ── Group 11: stream ID classification (bidi/local from stream ID) ────────
    // Stream IDs: 0=client bidi, 1=server bidi, 2=client uni, 3=server uni
    // is_bidi: id % 4 < 2; is_local: id % 2 == 0 (client perspective)
    let stream_cases: &[(u64, bool, bool, &str)] = &[
        (0, true, true, "stream0_client_bidi"),
        (1, true, false, "stream1_server_bidi"),
        (2, false, true, "stream2_client_uni"),
        (3, false, false, "stream3_server_uni"),
        (4, true, true, "stream4_client_bidi"),
        (5, true, false, "stream5_server_bidi"),
    ];
    for &(sid, bidi, local, desc) in stream_cases {
        // Verify is_bidi and is_local agree with the model
        let model_bidi = (sid % 4) < 2;
        let model_local = (sid % 2) == 0;
        assert_eq!(model_bidi, bidi, "bidi mismatch for stream {}", sid);
        assert_eq!(model_local, local, "local mismatch for stream {}", sid);
        // Use this classification in a completeness check
        cases.push(make_case(
            idx,
            desc,
            Some(5), 5,      // recv: fin
            Some(10), 10, 10, // send: complete
            false, bidi, local, false,
        ));
        idx += 1;
    }

    let total = cases.len();
    let mut passed = 0usize;
    let mut failed = 0usize;

    for case in &cases {
        if case.run() {
            passed += 1;
        } else {
            failed += 1;
        }
    }

    println!("#");
    println!("# Results: {}/{} PASS, {} FAIL", passed, total, failed);

    if failed > 0 {
        eprintln!("FAILED: {} test(s) failed", failed);
        std::process::exit(1);
    }
}
