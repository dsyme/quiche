# Route-B Correspondence Tests — CidMgmt retire_if_needed

🔬 *Lean Squad — automated formal verification for `dsyme/quiche`.*

## Target

**T27: CidMgmt retire_if_needed — RFC 9000 §5.1.1**

- Source: `quiche/src/cid.rs` — `ConnectionIdentifiers::new_scid` (retire_if_needed path)
- Lean model: `formal-verification/lean/FVSquad/CidMgmt.lean` §10 (`CidState.newScidRetire`, `lowestSeq`)

## What is tested

The Rust `new_scid(retire_if_needed=true)` path is invoked when the active SCID
count reaches `source_conn_id_limit`.  Instead of returning an `IdLimit` error,
it retires the **lowest-sequence** active CID (`lowest_usable_scid_seq()`) and
inserts the new one.  RFC 9000 §5.1.1 requires this to keep the active CID
count within negotiated limits.

The Lean model in `CidMgmt.lean §10` defines this atomically as
`CidState.newScidRetire`:
- If `|activeSeqs| < limit`: behaves identically to `newScid` (normal path).
- Else: remove `lowestSeq(activeSeqs)`, then add `nextSeq`, increment `nextSeq`.

The Rust extraction in `cid_mgmt_retire_test.rs` implements the same logic
as a standalone function `CidState::new_scid_retire` with no external
dependencies.

## Invariants checked

For every state transition, the tests verify:

1. `nextSeq` is incremented by exactly 1.
2. The newly allocated sequence number is present in `activeSeqs`.
3. `|activeSeqs| ≤ limit` after the call (the RFC 9000 §5.1.1 property).
4. When the retire path fires, the **lowest** old seq is no longer in `activeSeqs`.

## How to run

```bash
rustc --edition 2021 cid_mgmt_retire_test.rs && ./cid_mgmt_retire_test
```

No external dependencies. Requires Rust 1.60+.

## Test cases (56 total)

| Group | Cases | Coverage |
|-------|-------|---------|
| Normal path (below limit) | 5 | single/two/three CIDs, various limits |
| At-limit retire path | 7 | limit 1/2/3/4, contiguous seqs, non-contiguous, reversed |
| Invariant checks (6 states × ~3 properties + retire check) | 24 | next_seq, new seq in active, count≤limit, lowest retired |
| Multi-step from limit=2, 5 steps × 2 props | 10 | count ≤ limit, next_seq progression |
| Multi-step from limit=3, 10 steps | 10 | count ≤ limit across 10 retire calls |

## Result (run 169)

```
CidMgmt retire_if_needed Route-B correspondence tests: 56/56 PASS
```

Lean model and Rust source agree on all 56 cases.

## Correspondence to Lean model

| Rust function | Lean definition | Correspondence |
|--------------|----------------|---------------|
| `new_scid(retire_if_needed=true)` | `CidState.newScidRetire` | **exact** — same conditional structure |
| `lowest_usable_scid_seq()` | `lowestSeq` | **abstraction** — Lean ignores `retire_prior_to` filter; models initial state where all seqs are usable |
| `scids.len() >= limit` | `activeSeqs.length ≥ limit` | **exact** |
| `self.retire_prior_to = lowest + 1` | implicit in `filter (· ≠ lowestSeq)` | **abstraction** — bookkeeping not modelled |

## What this does NOT cover

- `retire_prior_to` bookkeeping (the Lean model approximates this as removing
  the single lowest seq atomically; the Rust may signal multiple retirements
  via `retire_prior_to` across multiple calls).
- Actual CID byte content (modelled as sequence numbers only).
- `reset_token` / `path_id` fields.
- The error path: `retire_if_needed=false` with full count → `Error::IdLimit`.
- Concurrent path migrations with active `retire_prior_to > 0` on initial state.
