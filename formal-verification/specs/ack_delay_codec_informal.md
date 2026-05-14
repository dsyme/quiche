# Informal Specification: ACK Delay Encode/Decode Codec

**Target**: T66 — ACK delay encode/decode round-trip  
**Source files**:
- `quiche/src/lib.rs` lines ~4487–4497 (encoder)
- `quiche/src/lib.rs` lines ~8173–8182 (decoder)
- `quiche/src/transport_params.rs` lines 173, 206, 316–322 (exponent validation)

---

## Purpose

QUIC ACK frames carry an `ack_delay` field that encodes the delay between
receiving the largest acknowledged packet and sending the ACK.  The raw delay
(in microseconds) is too large to send directly, so it is scaled by a
negotiated exponent:

- **Encoding** (sender): `encoded = delay_micros / 2^exponent`
- **Decoding** (receiver): `decoded_micros = encoded * 2^exponent`

The exponent is negotiated via the `ack_delay_exponent` transport parameter
(RFC 9000 §18.2, default 3, maximum 20).

---

## Preconditions

- `exponent: u64` satisfies `exponent ≤ 20`
- `delay_micros: u64` is the raw ACK delay in microseconds
- For a lossless round-trip: `delay_micros` is a multiple of `2^exponent`

---

## Postconditions

### Encoding
- `encoded = delay_micros / 2^exponent` (integer division, truncating)
- `encoded ≤ delay_micros` (encoding never exceeds raw value)
- `encoded` fits in a QUIC varint (`encoded ≤ MAX_VAR_INT = 2^62 - 1`) — this
  is guaranteed when `delay_micros ≤ MAX_VAR_INT * 2^exponent`; the transport
  parameter enforcement (exponent ≤ 20) and the ACK delay being a time
  measurement bounded by connection lifetime ensure this in practice.

### Decoding
- `decoded_micros = encoded * 2^exponent`
- On overflow, `checked_mul` returns `None` → `Error::InvalidFrame` is raised

### Round-Trip
- If `delay_micros` is exactly divisible by `2^exponent`:
  - `decode(encode(delay_micros, exp), exp) = delay_micros`
- In general: `decode(encode(delay_micros, exp), exp) ≤ delay_micros`
  (encoding truncates, decoding is exact — so the round-trip gives back
   the largest multiple of `2^exp` that does not exceed `delay_micros`)
- More precisely: `decode(encode(d, e), e) = (d / 2^e) * 2^e`

---

## Invariants

- The exponent is validated on receipt: if `ack_delay_exponent > 20`, the
  transport parameters are rejected (`Error::InvalidTransportParam`)
- Default exponent is 3 (scaling factor 8)
- The exponent is constant for the lifetime of the connection (set once
  during transport parameter negotiation)

---

## Edge Cases

- `exponent = 0`: no scaling; `encode(d, 0) = d`, `decode(d, 0) = d`
- `exponent = 20`: maximum allowed; scaling factor is 2^20 = 1,048,576
- `delay_micros = 0`: `encode(0, e) = 0`, `decode(0, e) = 0`
- Overflow in decode: `encoded * 2^exponent > u64::MAX` →
  `checked_mul` returns `None` → `InvalidFrame` error

---

## Examples

With `exponent = 3`:

| `delay_micros` | encoded | decoded |
|----------------|---------|---------|
| 0              | 0       | 0       |
| 8              | 1       | 8       |
| 1000           | 125     | 1000    |
| 1001           | 125     | 1000    |  ← truncation (not a multiple of 8)
| 25000          | 3125    | 25000   |

With `exponent = 0`:

| `delay_micros` | encoded | decoded |
|----------------|---------|---------|
| 42             | 42      | 42      |

---

## Inferred Intent

The codec is a lossy compression of ACK delays in multiples of `2^exponent`
microseconds. The RFC intends that the exponent be small enough that the
quantisation error is negligible (the default of 3 → 8µs granularity is
adequate for virtually all networks). The formal property of interest is
that `decode ∘ encode` is the identity on multiples of `2^exponent`, and
that the decoded result is always the floor to the nearest multiple otherwise.

---

## Open Questions

1. **OQ-T66-1**: Is there a check that the `encoded` value fits in a QUIC
   varint before transmission? The send path divides by `2^exponent` but does
   not appear to explicitly bounds-check the result against `MAX_VAR_INT`.
   For delays representable as u64 microseconds divided by 2^exponent, overflow
   is unlikely in practice, but a formal bound has not been proved.

2. **OQ-T66-2**: When the sender and receiver use different exponents (sender
   uses local, receiver uses peer), is the correct exponent applied on each
   side? The code uses `local_transport_params.ack_delay_exponent` for encoding
   and `peer_transport_params.ack_delay_exponent` for decoding — is this always
   the same value when both sides have negotiated successfully?
