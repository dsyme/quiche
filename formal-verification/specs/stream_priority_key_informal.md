# Informal Specification: `StreamPriorityKey::cmp`

> 🔬 *Written by Lean Squad automated formal verification (run 48).*

**Target**: `StreamPriorityKey` ordering (`Ord` implementation)
**Source**: `quiche/src/stream/mod.rs`, lines 842–910
**Phase**: 2 — Informal Spec

---

## Purpose

`StreamPriorityKey` is the key type used to order HTTP/3 streams in three
intrusive red-black trees: readable, writable, and flushable (RFC 9218 —
Extensible Prioritization Scheme for HTTP). The `Ord` implementation defines
the scheduling priority of each stream relative to others. A stream that
compares as **lesser** will be serviced before a stream that compares as
**greater**.

The ordering encodes the following RFC 9218 semantics:

1. **Urgency wins** — a lower urgency value (byte in 0–7 RFC range, here a
   `u8`) means the stream is more urgent and is scheduled first.
2. **Non-incremental beats incremental at the same urgency** — non-incremental
   streams must be fully sent before any other same-urgency work; incremental
   streams may be interleaved (round-robined).
3. **Among non-incremental, lower stream-ID wins** — within the same urgency,
   non-incremental streams are serialised in QUIC stream-ID order (ascending).
4. **Among incremental, the existing tree occupant wins** — any incremental
   stream already in the tree sorts before a newly inserted one (round-robin
   by demotion to Greater).
5. **Same stream-ID always compares Equal** — a stream is never scheduled
   before itself.

---

## Fields (modelled)

| Field | Type | Role |
|-------|------|------|
| `id` | `u64` | Unique QUIC stream identifier |
| `urgency` | `u8` | Scheduling urgency (lower = higher priority; default 127) |
| `incremental` | `bool` | If true, data may be interleaved with other streams of equal urgency |

Fields `readable`, `writable`, `flushable` (intrusive tree links) are
infrastructure and do not affect the ordering.

---

## Preconditions

None. `cmp` is total and defined for all pairs of `StreamPriorityKey` values.

---

## Postconditions (complete case analysis)

Let `a` and `b` be two `StreamPriorityKey` values. Then `a.cmp(b)` returns:

| Case | Condition | Result | Rationale |
|------|-----------|--------|-----------|
| 1 | `a.id = b.id` | `Equal` | Same stream, regardless of urgency/incremental flags |
| 2 | `a.id ≠ b.id` and `a.urgency < b.urgency` | `Less` | `a` is more urgent |
| 3 | `a.id ≠ b.id` and `a.urgency > b.urgency` | `Greater` | `b` is more urgent |
| 4 | `a.id ≠ b.id`, `a.urgency = b.urgency`, `¬a.incremental`, `¬b.incremental` | `a.id.cmp(b.id)` | Both non-incremental: order by stream ID |
| 5 | `a.id ≠ b.id`, `a.urgency = b.urgency`, `a.incremental`, `¬b.incremental` | `Greater` | Non-incremental `b` has precedence |
| 6 | `a.id ≠ b.id`, `a.urgency = b.urgency`, `¬a.incremental`, `b.incremental` | `Less` | Non-incremental `a` has precedence |
| 7 | `a.id ≠ b.id`, `a.urgency = b.urgency`, `a.incremental`, `b.incremental` | `Greater` | Both incremental: `b` (the existing occupant) takes precedence |

---

## Invariants

The ordering must satisfy the `Ord` contract laws:

1. **Reflexivity** (`PartialEq`): `a = b ↔ a.id = b.id`.  
   Note that two keys with the same `id` but different `urgency`/`incremental`
   compare as `Equal` but are **not** `PartialEq`-equal. This is an
   intentional design: `PartialEq` is used for identity (same stream), while
   `Ord` is used for scheduling position.

2. **Antisymmetry**: if `a.cmp(b) = Less` then `b.cmp(a) = Greater`.

3. **Transitivity**: if `a.cmp(b) = Less` and `b.cmp(c) = Less` then
   `a.cmp(c) = Less`.

4. **Totality**: `a.cmp(b)` is always one of `Less`, `Equal`, `Greater` — it
   never panics or produces an unexpected value.

5. **ID-equality dominance**: if `a.id = b.id` then `a.cmp(b) = Equal`,
   regardless of urgency or incremental flag.

---

## Edge Cases

- **Both incremental, same urgency, different IDs**: always `Greater` (case 7).
  This means that if a stream with urgency `u` and `incremental=true` is
  inserted into the tree, all existing same-urgency incremental streams will
  compare as `Less` than it, so they remain ahead — a best-effort round-robin
  approximation.

- **`urgency = 0`** (highest priority): compares less than urgency 1 and above.
  A stream at urgency 0, non-incremental will always sort before any other
  stream with higher urgency.

- **`urgency = 255`** (lowest possible `u8`): compares greater than all
  urgencies below it. A stream at urgency 255 is the last to be serviced in a
  mixed-urgency tree.

- **Equal urgency, non-incremental, equal stream ID**: falls into case 1
  (`a.id = b.id → Equal`), not case 4.

---

## Examples

```
a = {id=4, urgency=3, incremental=false}
b = {id=7, urgency=3, incremental=false}
a.cmp(b) = Less     (case 4: same urgency, both non-incr, id 4 < 7)

a = {id=4, urgency=3, incremental=true}
b = {id=7, urgency=3, incremental=false}
a.cmp(b) = Greater  (case 5: non-incremental b beats incremental a)

a = {id=4, urgency=1, incremental=true}
b = {id=7, urgency=3, incremental=false}
a.cmp(b) = Less     (case 2: urgency 1 < 3)

a = {id=5, urgency=3, incremental=true}
b = {id=5, urgency=3, incremental=false}
a.cmp(b) = Equal    (case 1: same ID)

a = {id=4, urgency=3, incremental=true}
b = {id=7, urgency=3, incremental=true}
a.cmp(b) = Greater  (case 7: both incremental, b takes precedence)
b.cmp(a) = Greater  (case 7: symmetrically, a takes precedence over b)
```

> **Open question OQ-1**: Case 7 produces `Greater` in *both* directions for
> two distinct incremental keys with the same urgency. This means the order is
> **not** antisymmetric when both keys are incremental with the same urgency!
> `a.cmp(b) = Greater` and `b.cmp(a) = Greater` simultaneously. This
> violates the standard `Ord` law (antisymmetry requires that if `a > b` then
> `b < a`). The red-black tree that uses this key may produce non-deterministic
> orderings for equal-urgency incremental streams. Is this intentional? Does the
> intrusive RBTree tolerate a non-antisymmetric comparator?

---

## Inferred Intent

The ordering is designed for use with an intrusive red-black tree where the
minimum element (by `Ord`) is served first. The intent is:

1. **Strict prioritisation** across urgency levels — a stream at urgency 0
   blocks streams at urgency 1+ entirely.
2. **Head-of-line blocking within non-incremental** — non-incremental streams
   at the same urgency are serialised by stream ID, which gives deterministic,
   ordered delivery.
3. **Round-robin for incremental** — by always sorting newly added incremental
   streams as `Greater` than existing ones, the tree approximates a round-robin
   cycle (each send pass services the minimum, then that stream is removed and
   re-inserted as `Greater`, going to the back of the queue).

---

## Approximations for Lean Model

The Lean model will:
- Represent `StreamPriorityKey` as a plain structure `{id : Nat, urgency : Nat, incremental : Bool}`.
- Define `cmpKey a b : Ordering` as the pure seven-case decision function above.
- Prove `Ord` laws: transitivity, totality. **Not** antisymmetry for the
  incremental-incremental case (OQ-1 above — this is a potential spec violation
  in the Rust code).
- `Nat` models `u8` urgency (no overflow; valid urgency values are 0–7 per
  RFC 9218, though quiche uses the full `u8` range).
- `Nat` models `u64` stream IDs (no overflow; for practical stream counts < 2^62).
