# Lean Squad Memory — dsyme/quiche

**Last updated**: 2026-03-27 19:10 UTC  
**Commit**: b16ca879 (lean-squad-lean-spec-run2)  
**Run**: https://github.com/dsyme/quiche/actions/runs/23661997161

## FV Targets

| # | Target | Location | Phase | Open PRs/Issues | Notes |
|---|--------|----------|-------|-----------------|-------|
| 1 | varint codec | `octets/src/lib.rs` | 4 — Lean impl + partial proofs | PR #3 (lean-squad-lean-spec-run2) | 5 proved, 2 sorry remain |
| 2 | RangeSet invariants | `quiche/src/ranges.rs` | 1 — Research | — | Sorted/non-overlapping |
| 3 | RTT estimation | `quiche/src/recovery/rtt.rs` | 1 — Research | — | RFC 9002 §5 EWMA |
| 4 | Flow control | `quiche/src/flowcontrol.rs` | 1 — Research | — | Arithmetic invariants |
| 5 | Minmax filter | `quiche/src/minmax.rs` | 1 — Research | — | Windowed min/max |

## Tool Choice

- **Lean 4.29.0** — no Mathlib (network firewall blocks download)
- Core tactics: `omega`, `simp`+`if_pos`/`if_neg`, `by_cases`, `native_decide`

## Key Files

- `formal-verification/RESEARCH.md` — target survey
- `formal-verification/TARGETS.md` — phase tracking
- `formal-verification/specs/varint_informal.md` — informal spec
- `formal-verification/lean/FVSquad/Varint.lean` — Lean 4 spec+impl+proofs
- `formal-verification/lean/lakefile.toml` — Lake project (no Mathlib)
- `formal-verification/lean/lean-toolchain` — leanprover/lean4:v4.29.0
- `.github/workflows/lean-ci.yml` — CI (lake build on every PR)

## Varint Codec (Target 1) — Lean Status

### Proved theorems (no sorry)
- `varint_len_nat_1` : v ≤ 63 → varint_len_nat v = 1
- `varint_len_nat_2` : 64 ≤ v ≤ 16383 → varint_len_nat v = 2
- `varint_len_nat_4` : 16384 ≤ v ≤ 1073741823 → varint_len_nat v = 4
- `varint_len_nat_8` : 1073741824 ≤ v ≤ MAX_VAR_INT → varint_len_nat v = 8
- `varint_len_nat_valid` : result ∈ {1, 2, 4, 8} for valid inputs
- `varint_parse_len_nat_valid` : result ∈ {1, 2, 4, 8} for all bytes
- `varint_len_nat_mono` : a ≤ b → varint_len_nat a ≤ varint_len_nat b
- `varint_encode_length` : encode produces exactly varint_len_nat v bytes
- 6 private inverse lemmas (inv1, inv2, inv2_upper, inv4, inv4_upper, inv8)

### sorry-guarded (Task 5 targets)
- `varint_first_byte_tag` : top 2 bits of first byte encode the length
- `varint_round_trip` : decode(encode(v)) = v for all valid v
  → Needs: bitwise div/mod lemmas (e.g., `(v / 256 ||| 0x40) / 64 = 1`)
  → May need Mathlib for `Nat.div_div_eq_div_mul` etc.

### native_decide verified (all passing)
- Boundary values: 0, 63, 64, 16383, 16384, 1073741823, 1073741824, MAX_VAR_INT
- Test vectors: encode/decode 37, 15293, 494878333, 151288809941952652
- varint_parse_len_nat for all 4 tag regions (0x00..0xFF)

## CI Status

- `lean-ci.yml`: created in PR #3, runs `lake build` on formal-verification/lean/** changes
- Lean toolchain: v4.29.0 (stable)
- Mathlib: unavailable (network firewall); proofs use core Lean 4 only

## Proof Techniques (learned)

1. For if-then-else goals in Lean 4 WITHOUT Mathlib:
   - Use `simp only [if_pos h]` / `simp only [if_neg h]` to reduce branches
   - Use `by_cases` to split on conditions, then `omega` for numeric goals
   - omega handles contradictions like `h : 2 = 1` directly (derives False)
   - DO NOT use `push_neg`, `split_ifs`, `interval_cases` — not in core Lean 4

2. For proving existence theorems with known witnesses:
   - Use `refine ⟨witness, ?_, ?_⟩` then prove each component
   - `unfold f; rw [h]` works when `f` is defined by pattern matching

3. omega limitations in Lean 4.29.0:
   - Works on Nat/Int; does NOT handle UInt64/UInt8 comparisons directly
   - Model core functions over Nat to avoid this limitation
   - After `simp [varint_len_nat]` leaves if-then-else, omega can't split it
   - Use if_pos/if_neg + omega separately

## Open Questions

1. Can Mathlib be installed in future runs? (Try: `lake update` with network access)
2. For varint_round_trip proof, key lemma needed: `(v &&& 0x3F) * 256 + (v &&& 0xFF) = v &&& 0x3FFF` and similar — these need Nat.bitwise lemmas.
3. Non-minimal encodings: RFC 9000 doesn't require rejection — confirmed by test suite.

## Run History

### 2026-03-27 — Run 23661997161
- Tasks: 3 (Formal Spec), 4 (Implementation), 9 (CI)
- Lean 4.29.0 installed and working
- 5 structural theorems fully proved (no sorry)
- 2 sorry remain (round_trip, first_byte_tag)
- PR #3 created: lean-squad-lean-spec-run2
- Status issue created

### 2026-03-27 — Run 23661208608
- Tasks: 1 (Research), 2 (Informal Spec — varint)
- PR #2 created: lean-squad-research-run1
- 5 targets identified

## Next Run Priorities

1. Task 5: Prove `varint_round_trip` and `varint_first_byte_tag`
   - Key: prove `(v / 256 ||| 0x40) / 64 = 1` (first byte of 2-byte encoding has tag 01)
   - And: `(v &&& 0x3F) * 256 + (v &&& 0xFF) = v` for v < 16384
   - May need to install Mathlib or prove bitwise lemmas from scratch
2. Task 2: Informal spec for RangeSet (Target 2)
3. Task 3: Lean spec for RangeSet
