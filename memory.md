# Lean Squad Memory — dsyme/quiche

**Last updated**: 2026-03-28 01:45 UTC  
**Commit**: f764c90 (lean-squad-run3-varint-proofs)  
**Run**: https://github.com/dsyme/quiche/actions/runs/23674446182

## FV Targets

| # | Target | Location | Phase | Open PRs/Issues | Notes |
|---|--------|----------|-------|-----------------|-------|
| 1 | varint codec | `octets/src/lib.rs` | 5 — ALL PROVED (0 sorry) | PR pending | round_trip + first_byte_tag proved |
| 2 | RangeSet invariants | `quiche/src/ranges.rs` | 2 — Informal Spec | — | specs/rangeset_informal.md written |
| 3 | RTT estimation | `quiche/src/recovery/rtt.rs` | 1 — Research | — | RFC 9002 §5 EWMA |
| 4 | Flow control | `quiche/src/flowcontrol.rs` | 1 — Research | — | Arithmetic invariants |
| 5 | Minmax filter | `quiche/src/minmax.rs` | 1 — Research | — | Windowed min/max |

## Tool Choice

- **Lean 4.29.0** — no Mathlib (network firewall blocks download)
- Core tactics: `omega`, `simp`+`if_pos`/`if_neg`, `by_cases`, `native_decide`, `rw`

## Key Files

- `formal-verification/RESEARCH.md` — target survey
- `formal-verification/TARGETS.md` — phase tracking
- `formal-verification/specs/varint_informal.md` — informal spec (merged in PR #2)
- `formal-verification/specs/rangeset_informal.md` — informal spec (new, PR #4 pending)
- `formal-verification/lean/FVSquad/Varint.lean` — Lean 4 spec+impl+proofs
- `formal-verification/lean/lakefile.toml` — Lake project (no Mathlib)
- `formal-verification/lean/lean-toolchain` — leanprover/lean4:v4.29.0

## Varint Codec (Target 1) — COMPLETE (Phase 5)

### ALL theorems proved (no sorry)
- `varint_len_nat_1/2/4/8` : branch postconditions (if-then-else cases)
- `varint_len_nat_valid` : result ∈ {1, 2, 4, 8} for valid inputs
- `varint_parse_len_nat_valid` : result ∈ {1, 2, 4, 8} for all bytes
- `varint_len_nat_mono` : a ≤ b → varint_len_nat a ≤ varint_len_nat b
- `varint_encode_length` : encode produces exactly varint_len_nat v bytes
- **`varint_round_trip`** : decode(encode(v)) = v for ALL valid v ← KEY SAFETY
- **`varint_first_byte_tag`** : first byte's top-2-bits = length class

### native_decide verified
- All 4 RFC 9000 test vectors, all 8 boundary values
- All parse_len_nat tag regions, non-minimal encoding

### Key proof technique (NEW, successfully verified)
- Use arithmetic (+) instead of bitwise (|||) for encode: equivalent since tag bits don't overlap value bits
- Use arithmetic (%) instead of bitwise (&&&) for decode: equivalent for power-of-2-minus-1 masks
- omega handles: `(v+16384)%16384=v` (2-byte), `(v+2^31)%2^30=v` (4-byte), etc.
- omega handles nested div/mod for constant divisors (key: `(a/b)/c = a/(b*c)`)
- For varint_first_byte_tag: `rw [show b/64 = k from by omega]` reduces match to concrete case
- CRITICAL: omega cannot unfold `def MAX_VAR_INT`. Need `have : v ≤ 4611686018427387903 := hv` or `unfold MAX_VAR_INT at hv` before omega

## RangeSet (Target 2) — Phase 2

### Informal spec: specs/rangeset_informal.md
- 5 invariants identified (I1-I5)
- I3 (insert = set union) is the highest-value FV target
- I1+I2 (sorted, non-empty) are the structural invariants
- Key insight: capacity eviction makes I3 conditional on len < capacity
- Next step: Task 3 — Lean 4 formal spec

### Suggested Lean model
```lean
def RangeSetModel := List (Nat × Nat)  -- sorted list of (start, end) pairs

def sorted_disjoint : RangeSetModel → Prop
def covers : RangeSetModel → Set Nat
-- Then prove: insert_correct, remove_until_correct
```

## CI Status

- **NOTE**: lean-ci.yml could not be committed (protected files). 
  The CI yml file needs manual creation by a maintainer.
- Lean toolchain: v4.29.0 (stable)
- Mathlib: unavailable (network firewall); proofs use core Lean 4 only

## Proof Techniques (learned — updated)

1. For if-then-else goals (Lean 4 without Mathlib):
   - Use `simp [ha, hb, ...]` with boolean hypotheses to reduce if expressions
   - DO NOT use `split_ifs` — Mathlib only
   - Use `by_cases` for all conditions, then `simp [h1, h2, ...] <;> omega`

2. For existence theorems:
   - Use `exact ⟨witness, proof1, proof2⟩`
   - Or `refine ⟨witness, ?_, ?_⟩` then prove each part

3. omega limitations in Lean 4.29.0:
   - CANNOT unfold opaque `def` — use `have : x = n := hv` first
   - DOES handle nested div/mod: `(a/b)/c = a/(b*c)` for constants
   - DOES handle `(v+k)%k = v%k` for constant k

4. For reducing `match` expressions:
   - `have h : expr = k := by omega` + `rw [h]` reduces `match expr with | k => ...`
   - This works for `varint_parse_len_nat` goals

## Open Questions

1. Can Mathlib be installed in future runs? (Try: `lake update` with network access)
2. Should lean-ci.yml be committed in a separate non-protected workflow path?
3. For RangeSet spec: empty range insertion behaviour (open question in spec)
4. For RangeSet spec: capacity semantics when merging doesn't increase len

## Run History

### 2026-03-28 — Run 23674446182
- Tasks: 5 (Proofs — varint), 2 (Informal Spec — RangeSet)
- Lean 4.29.0 working
- ALL varint theorems proved: varint_round_trip + varint_first_byte_tag now proved (0 sorry)
- Key technique: arithmetic encode/decode avoids Mathlib bitwise lemmas; omega handles all arithmetic
- RangeSet informal spec written: specs/rangeset_informal.md
- PR #4 pending (lean-squad-run3-varint-proofs branch)

### 2026-03-27 — Run 23661997161
- Tasks: 3 (Formal Spec), 4 (Implementation), 9 (CI)
- Lean 4.29.0 installed and working
- 5 structural theorems proved, 2 sorry remained (round_trip, first_byte_tag)
- PR #3 was created as Issue (push blocked: lean-ci.yml is a protected workflow file)
- CI setup blocked by GitHub Actions permission model

### 2026-03-27 — Run 23661208608
- Tasks: 1 (Research), 2 (Informal Spec — varint)
- PR #2 created: lean-squad-research-run1 (MERGED)
- 5 FV targets identified and prioritised

## Next Run Priorities

1. Task 3: Lean formal spec for RangeSet (Target 2)
   - Model: `List (Nat × Nat)` sorted by start
   - Key theorem: insert preserves sorted_disjoint invariant
   - Helper lemma: `sorted_disjoint_after_merge`
2. Task 6: Correspondence review — document + vs ||| approximation in Varint
3. Task 7: Proof utility critique — assess quality of varint proofs
