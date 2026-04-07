# Informal Specification: Connection ID Sequence Management

> 🔬 *Written by Lean Squad automated formal verification.*

**Target**: `quiche/src/cid.rs` — `ConnectionIdentifiers` struct,
`new_scid` / `retire_scid` methods.

**Phase**: 2 (Informal Spec)

---

## Purpose

QUIC connections are identified by **Connection IDs (CIDs)** that both peers
use to route packets. Each CID is tagged with a monotone **sequence number**
(RFC 9000 §5.1) assigned by the generator. The sequence number serves two
purposes:

1. **Deduplication**: the receiver can detect and ignore a duplicate
   `NEW_CONNECTION_ID` frame by checking whether the sequence number is
   already known.
2. **Orderly retirement**: `RETIRE_PRIOR_TO` instructs the peer to retire all
   CIDs with sequence numbers below a threshold; strict monotonicity ensures
   this is well-defined.

The `ConnectionIdentifiers` struct tracks:
- **`scids`**: active source CIDs (those we send; peer uses them as DCIDs).
- **`dcids`**: active destination CIDs (those the peer sends; we use them).
- **`next_scid_seq`**: the sequence number that will be assigned to the *next*
  new source CID.

This spec focuses on the source-CID sequence machinery because it is the
side managed by `quiche` (not the peer).

---

## Preconditions for `new_scid`

- The connection is not using zero-length SCIDs.
- Either the active SCID count is below `source_conn_id_limit`, or
  `retire_if_needed = true` (which retires the oldest CID to make room).
- The provided `cid` is either fresh or already present with an identical
  `reset_token`.
- For non-initial SCIDs (`seq ≠ 0`) a non-`None` `reset_token` must be
  provided.

## Postconditions for `new_scid`

- **Sequence assignment**: the returned sequence number equals the value of
  `next_scid_seq` **before** the call.
- **Monotone increment**: after the call, `next_scid_seq` has increased by 1
  (unless the CID was a duplicate, in which case it is unchanged).
- **Uniqueness**: the new entry's sequence number is distinct from every other
  entry currently in `scids`.
- **Membership**: the new entry is present in `scids` after the call.
- **Bounded size**: `scids.len() ≤ 2 * source_conn_id_limit − 1`.

## Preconditions for `retire_scid`

- `seq < next_scid_seq` (can only retire a CID that was previously issued).
- The CID being retired must not be the one that appeared as the DCID in the
  packet that carried the retire request (RFC 9000 §19.16).

## Postconditions for `retire_scid`

- The entry with the given `seq` is removed from `scids`.
- The retired CID is placed onto `retired_scids` for application notification.
- `next_scid_seq` is **unchanged** (retirement does not reclaim sequence
  numbers).

---

## Invariants

The following invariants hold at all times between public calls:

1. **Seq monotonicity** (`I1`): `0 < next_scid_seq` — at least the initial
   CID (seq 0) has been issued.
2. **Uniqueness** (`I2`): all sequence numbers in `scids` are pairwise
   distinct.
3. **Seq bound** (`I3`): every sequence number in `scids` is
   `< next_scid_seq`.
4. **Non-empty** (`I4`): `scids` always contains at least one entry (the
   active CID in use on the initial path).
5. **Size bound** (`I5`): `scids.len() ≤ 2 * source_conn_id_limit − 1`.

---

## Key Properties for Formal Verification

### P1: `next_scid_seq` is strictly increasing

Each successful `new_scid` call (for a fresh CID) increments `next_scid_seq`
by exactly 1. It never decreases. Sequence numbers are never reused.

**Why this matters**: CID reuse would violate RFC 9000 §5.1 and break the
QUIC connection migration anti-linkability guarantee — two paths could be
correlated if their CIDs share a sequence number.

### P2: All active SCID sequence numbers are distinct

At any point, the set `{e.seq | e ∈ scids}` has no duplicates.

**Why this matters**: duplicate sequence numbers would make `retire_prior_to`
semantics ambiguous and could prevent correct retirement.

### P3: All active SCID sequence numbers are below `next_scid_seq`

Every sequence number currently in `scids` was assigned in a prior `new_scid`
call, so it is strictly less than the next-to-be-assigned number.

**Why this matters**: attempting to retire a seq ≥ `next_scid_seq` is an
error (RFC 9000 §19.16); this invariant makes that check sound.

### P4: `new_scid` assigns the current `next_scid_seq`

The sequence number returned by `new_scid` equals the value of
`next_scid_seq` at call entry (for a fresh CID).

---

## Edge Cases

- **Duplicate CID**: if the same byte-string CID is inserted twice with the
  same `reset_token`, `new_scid` returns the *existing* sequence number and
  does **not** increment `next_scid_seq`.
- **Zero-length SCID**: if `zero_length_scid = true`, `new_scid` immediately
  returns `InvalidState` without modifying any state.
- **At limit with `retire_if_needed = false`**: returns `IdLimit` without
  modifying state.
- **Retiring seq ≥ next_scid_seq**: returns `InvalidState` (guards against
  peer-injected future sequence numbers).
- **Retiring the last active CID**: currently allowed for SCIDs (the
  application is responsible for registering a replacement before sending).

---

## Concrete Examples

```
Initial state: next_scid_seq = 1, scids = [{seq:0, ...}]

new_scid(cid_A) → returns 1, next_scid_seq = 2
new_scid(cid_B) → returns 2, next_scid_seq = 3
new_scid(cid_A, same token) → returns 1 (duplicate), next_scid_seq = 3
retire_scid(0) → removes seq:0, next_scid_seq still 3
new_scid(cid_C) → returns 3, next_scid_seq = 4
```

Invariant check after each step:
- All seqs in scids are distinct: ✓ (1, 2 after step 2; 1, 2, 1-duplicate
  blocked; 1, 2 after retire; 1, 2, 3 after step 5)
- All seqs < next_scid_seq: ✓

---

## Inferred Intent

The design intentionally never reuses sequence numbers so that:
1. `retire_prior_to = k` has a clear meaning: retire everything below `k`,
   with no ambiguity about which of two same-numbered CIDs to retire.
2. The peer can detect retransmitted `NEW_CONNECTION_ID` frames (idempotent
   reception) by sequence number.
3. Sequence numbers form a total order that defines the "age" of each CID.

---

## Open Questions

1. **Is `retire_scid` allowed to leave `scids` empty?** If the last CID is
   retired and no new one is registered, subsequent packet routing fails.
   Should there be a formal "at least one active SCID" invariant?
2. **What is the exact relationship between `retire_prior_to` and active
   seqs?** After a `retire_if_needed` path, the oldest CID is retired — is
   `scids` guaranteed to still have a CID with seq ≥ `retire_prior_to`?
3. **DCID sequence management**: the DCID side has a symmetric structure but
   different ownership semantics (assigned by the peer). Worth extending the
   formal model to cover both sides.

---

> 🔬 Lean Squad — automated formal verification for `dsyme/quiche`.
