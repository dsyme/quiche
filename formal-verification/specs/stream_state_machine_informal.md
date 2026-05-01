# Informal Specification: QUIC Stream State Machine

**Source**: `quiche/src/stream/mod.rs` (Stream, RecvBuf, SendBuf)  
**RFC**: RFC 9000 §3 — Stream States

---

## Purpose

Each QUIC stream has two independent half-streams: a **receive half** and a
**send half**. Each half progresses through a lifecycle defined by RFC 9000.
This spec captures the observable state predicates and their relationships for
a bidirectional stream as implemented in quiche.

---

## Stream Halves

### Send Half (`SendBuf`)

| Predicate | Meaning |
|-----------|---------|
| `is_fin()` | A FIN has been queued (final size known) |
| `is_complete()` | All bytes have been sent and acknowledged (peer confirmed receipt) |
| `is_shutdown()` | Send side was reset (`RESET_STREAM`) |

State progression (send):
```
Open → [fin set] → DataSent → [all acked] → DataRecvd (complete)
Open → [reset] → ResetSent → [acked] → ResetRecvd (shutdown)
```

### Receive Half (`RecvBuf`)

| Predicate | Meaning |
|-----------|---------|
| `is_fin()` | All expected bytes have been received and consumed (FIN consumed) |
| `is_shutdown()` | Receive side was reset by peer (`RESET_STREAM` received) |
| `is_readable()` | There are bytes available to read |

---

## Stream Completeness

The `Stream::is_complete` method determines whether the stream may be garbage-
collected. It depends on stream directionality (local vs. remote, bidi vs. uni):

| Directionality | `is_complete` condition |
|----------------|------------------------|
| Bidirectional (bidi) | `recv.is_fin() AND send.is_complete()` |
| Local unidirectional (send-only) | `send.is_complete()` |
| Remote unidirectional (recv-only) | `recv.is_fin()` |

### Key Preconditions
- `is_bidi`: determined by stream ID bit 1 (`id & 2 == 0`)
- `is_local`: determined by stream ID bit 0 matching server flag

---

## Preconditions

- Stream IDs encode directionality and locality in their lower 2 bits.
- A stream cannot go back from `is_complete()` to writable or readable states.
- `is_readable()` can only be true while not yet `is_fin()`.
- `is_writable()` requires `!send.is_shutdown() && !send.is_fin()`.

---

## Postconditions / Invariants

1. **Monotonicity of fin**: Once `recv.is_fin()` is true, it stays true.
2. **Monotonicity of send completion**: Once `send.is_complete()` is true, it stays true.
3. **Shutdown excludes writable**: `send.is_shutdown()` implies `!is_writable()`.
4. **Fin excludes writable**: `send.is_fin()` implies `!is_writable()`.
5. **Complete implies fin (send-only)**: `is_complete()` on a send-only stream implies `send.is_complete()`.
6. **is_complete implies not writable**: `is_complete()` implies `!is_writable()`.
7. **Directionality is immutable**: `is_bidi(id)` and `is_local(id, is_server)` are purely determined by `id` and `is_server`; they do not change.

---

## Edge Cases

- A stream can be simultaneously in fin-received state and reset — the
  implementation should handle the `RESET_STREAM` arriving after FIN gracefully.
- Zero-length bidirectional streams with FIN on both halves are immediately
  complete.

---

## Examples

- Stream 0 (client-initiated bidi): `is_bidi=true`, `is_local=true` (for client). Complete when both halves done.
- Stream 3 (server-initiated uni): `is_bidi=false`, `is_local=false` (for client). Complete when recv done.

---

## Open Questions

- OQ-STREAM-1: Is it guaranteed that `recv.is_fin()` and `recv.is_shutdown()` are mutually exclusive? The implementation may allow both flags.
- OQ-STREAM-2: After `send.is_shutdown()`, can additional data be written? (Expected: no, but not explicitly enforced in all code paths.)
- OQ-STREAM-3: The completeness condition for bidi streams requires both send AND recv completion. Is there a risk of a stream being "half-zombie" (one side complete, other blocked) indefinitely?

---

## Inferred Intent

The `is_complete` predicate is the cleanup gate: only when a stream is complete
is it safe to remove it from the active stream table. The three-way case split
in `is_complete` mirrors RFC 9000 §3's separate state machines for the send and
receive sides of a bidirectional stream, with unidirectional streams having only
one relevant side.
