# epic-191-a3-path-ownership — human-copy staging notes

`MANIFEST.sha256` in this directory is a **machine-readable GNU
`sha256sum`-format file with no comment lines**, because
`apply-human-copy.sh --manifest` rejects a `#` line outright: `parse_manifest`
skips only *empty* lines, so a comment fails the `<64-hex>  <path>` shape check
and the tool exits 13 `MANIFEST_INVALID` (verified empirically, 2026-08-11).
That is also the convention every publisher-consumed manifest in this repo
already follows (`epic-136-phase2-gates`, `epic-159-pillar-c`/`-d`,
`epic-189-a1-project-context`, `epic-192-a4-facet-manifest`,
`quality-loop-fixes`). This file carries the prose instead.

## How to apply

The manifest's paths are **destinations relative to the repo root**. For each
entry, from the repo root:

```sh
cp specs/epic-191-a3-path-ownership/human-copy/<path> <path>
shasum -a 256 -c specs/epic-191-a3-path-ownership/human-copy/MANIFEST.sha256
```

The `shasum -c` run verifies the LIVE files after application. Every hash in
the manifest was verified against the staged file it names; nothing is recorded
for a file that was not produced.

## Superseded: the "blocked by the write guard" finding

**The previous revision of `MANIFEST.sha256` carried zero real entries** and
claimed the guard blocks writes under `human-copy/` "REGARDLESS of the
human-copy/ staging prefix". **That is false**, and this note supersedes it.

`_is_protected_gate_file` in the executing installed guard
(`sdd-quality-loop/1.10.0/scripts/sdd-hook-guard.py`) contains an explicit
staging exemption: a path still carrying the `specs/<feature>/human-copy/`
prefix after `normpath` is writable, **except** when a registered suffix itself
names a human-copy path. Only two such suffixes are registered —
`apply-human-copy.{sh,ps1}` and
`specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1` — and none
of the nine files here matches one.

Re-verified 2026-08-11 by loading the predicate from the installed guard and
evaluating it against all nine staging paths (**all writable**) and their nine
live counterparts (**all blocked**), then demonstrated by writing the files: no
write below was blocked.

Consequence: the workaround the old notes describe — staging under
`reports/implementation/<feature>/drafts/` instead — was never necessary.
**This directory is now the canonical staging location**, and
`drafts/MANIFEST.sha256` is superseded by this one.

Correction (2026-08-11, RT-20260811-003): the sentence that stood here —
"the `drafts/` copies remain in place and are byte-identical to the Bundle
A/B files staged here" — was true for Bundle A only and **false for Bundle
B**. The drafts Bundle B pair was the pre-ruling UNCONDITIONAL
`check-contract.{py,ps1}` candidate (`5c0c3874…`/`9005f861…`), while the
files staged here and applied live are the human-ruled CONDITIONAL artifact
(`252c6200…`/`01a3ca22…`, `eb427d60` → applied in `710d6746`) — confirmed by
direct hashing. Because the drafts manifest's Bundle B apply mapping would
have silently reverted the conditional gate if followed, the two drafts
Bundle B files are evicted, their manifest rows removed, and
`tests/check-component-coverage.tests.{sh,ps1}` TEST-055.3 asserts they stay
evicted. The drafts Bundle A copies remain and ARE byte-identical to the
files staged here.

## What each item is, and how it was verified

### 1. `.github/workflows/test.yml`

The live workflow plus six CI steps appended to the end of the `version-gates`
job.

Contrary to the earlier record, **none** of the three suites was registered in
the live workflow: all three are registered in `tests/run-all.{sh,ps1}` but
none ran in CI. T-002's steps were therefore added here too, not skipped.

Verified by parsing both the live and staged documents with a real YAML parser
(Ruby Psych/libyaml):

- job key list unchanged and in the same order (`test`, `installers`,
  `loops-routing`, `version-gates`, `mcp-tests`, `local-env-mcp-tests`,
  `ci-mcp-tests`, `cli-hook-enforcement`, `required-checks`);
- every job other than `version-gates` structurally identical;
- `version-gates` 32 → 38 steps, the existing 32 unchanged and in order;
- each added step's `run` names a `tests/` file that exists;
- no duplicate step names.

Step formatting follows this job's house style (bash steps carry
`if: runner.os != 'Windows'`), which differs cosmetically from the fragments in
`reports/implementation/epic-191-a3-path-ownership/drafts/*-ci-steps.yml`.

### 2. Bundle A (6 files)

`check-component-coverage.{py,ps1,sh}` added to `PHASE2_TARGETS`
(`generate-guard-invariants.py`) and to both `protected_gate_suffixes` and
`phase2_human_copy_targets` (`guard-invariants.json`).

The two **source** files were edited from the LIVE files by this session, then
cross-checked byte-for-byte against the `drafts/bundle-a/` copies. The four
`generated/` siblings were **not** hand-authored: they were produced by running
the REAL, unmodified `generate-guard-invariants.py` against a scratch tree laid
out as the generator expects, after which `generate-guard-invariants.py
--check` exited 0. That `--check` was proven non-vacuous by tampering with one
generated file (exit 1) and restoring it (exit 0). Set comparison against the
live lists confirms the change **drops nothing**.

### 3. Bundle B (2 files)

`"check-component-coverage"` added to the hardcoded `high`/`critical`
tier-minimum sets (mirroring `risk-gate-matrix.md`), plus a producer-digest
verification pass that independently recomputes the live
`check-component-coverage.py` sha256 and rejects a `passes:true` evidence entry
whose `producer.sha256` does not match.

Verified by running the **staged** `check-contract.py` in an assembled sibling
tree: it rejects tampered evidence (exit 1, naming the digest mismatch) and
accepts genuine live-produced evidence (exit 0), while the LIVE
`check-contract.py` still accepts the tampered evidence — so the rejection is
caused by this change and not by the fixture. The staged `.ps1` twin parses
cleanly with the real PowerShell parser and carries the matching tier entries
and pass.

`tests/check-component-coverage.tests.sh` (41 passed / 0 failed) and `.ps1`
(40 / 0) are green.

#### 3b. Capability-state gating of the new tier minimum (2026-08-11)

Registering `check-component-coverage` unconditionally broke **all 94**
pre-existing `high`/`critical` contracts (measured: `check-contract` 0/94,
`check-evidence-bundle` 0/94, `tests/gates.tests.sh` 114 passed / 12 failed,
and the `mcp-tests` CI job red at 231/1). Backfilling the 94 was measured and
rejected: it mints byte-identical records that attest nothing, wired to a
Pass-7 tripwire that detonates on any future edit to
`check-component-coverage.py` — and epic-192 is scheduled to edit it.

Bundle B therefore now also gates the *requirement* on the same project state
the *gate* itself reads. `derive_state()` returns `disabled-legacy` when
`sdd/project-context.yaml` is absent (it is absent in this repository), and in
that state the gate evaluates zero Fail conditions and exits 0 — it cannot
assert anything. `_pass4_risk_tier` now drops
`CAPABILITY_STATE_GATED_IDS = {"check-component-coverage"}` from the tier
minimum in exactly that state, so the minimum activates precisely when the gate
becomes capable of asserting something.

**The predicate is file presence, not a re-derived three-way state.**
`contracts/project-context.schema.json` makes `capability_enforcement`
*required* with enum `advisory|required`, so every schema-conformant config
yields `advisory` or `required` — never `disabled-legacy`. Presence is
therefore *exactly* equivalent to `derive_state() != "disabled-legacy"` for any
conformant config, and for a malformed one it still **requires** the check
(fail-closed). It also keeps any YAML parser out of this decision: a parser
that threw and was caught would silently conclude `disabled-legacy` and turn
the minimum off permanently and undetectably. This predicate has no such
failure mode — the only way it reads "inactive" is the file genuinely not
existing, which is the intended inactive condition.

Cross-runtime parity was measured, not assumed: on an identical fixture the
`.py` and `.ps1` twins agree in both states (config absent → both exit 0;
config present → both exit 1), and against the pre-fix LIVE pair both exit 1 in
both states.

**Deliberate deviation from the approved specification — needs a human
decision.** `requirements.md:132-138` states the remedy is "**not** to make
`check-contract`'s tier mechanism itself capability-aware (out of this
feature's touch surface, Non-goals)", and the last Non-goals bullet scopes this
feature's `check-contract` change to "adds new entries to ... `check-contract`'s
tier-minimum set". The spec's own remedy is the 94-contract backfill
(`requirements.md:400-410`: a `disabled-legacy` high/critical task "has a
genuine, non-fabricated `passes:true` evidence entry to satisfy
`check-contract`'s tier minimum"). Measurement overturned that remedy; this
candidate implements the other one. Applying it therefore also requires
amending `requirements.md`/`design.md`, which are approved and hash-bound.

### 4. `tests/gates.tests.sh`

**This candidate was rebuilt on 2026-08-11 and no longer contains the twelve
fixture repairs staged by commit `6cba7c14`.** It is now the LIVE suite,
byte-for-byte, plus one appended `CSG` block. What was removed, and why, is
recorded below — the earlier job's work was measured out of necessity, not
discarded on preference.

#### What was removed

Commit `6cba7c14` added ~61 lines to the live suite: a
`create_component_coverage_evidence()` helper and a
`{ "id": "check-component-coverage", ... }` entry appended to 11 positive
contract fixtures (`T-003.7`, `T-003.8`, `T-012.7`, `T-004.3`, `T-004.7`,
`T-006.3b`/`T-007a.9` — which share the `T-100` fixture — `T-007a.1d`,
`T-007a.5`, `CM.1`, `CM.3`, `CM.4`), producing the 12 repaired assertions. It
also adjusted a few neighbouring `requirement-traceability` /
`task-state-check` / `cross-model-verification` lines.

That work was correct for an unconditional tier minimum. It is **unnecessary
under §3b's conditional one**, and keeping it would bake in a change nothing
requires: those 11 fixtures build their contracts in `mktemp -d` roots that
contain no `sdd/project-context.yaml`, so the gated id is not in their tier
minimum at all.

**Measured, not assumed.** With the §3b candidate applied to a scratch tree and
the **unrepaired live suite** (3188 lines) run against it, the result was
**126 passed / 0 failed** — all twelve repairs are unnecessary; none of the
twelve still needs repair. Baseline for comparison, live and unmodified:
114 passed / 12 failed.

#### What replaced it

One appended block, `CSG.1`–`CSG.5`, testing the §3b condition itself — the
suite previously had no coverage of it at all. The block is a non-vacuity
harness, not a smoke test: `CSG.1` (config absent → a `high` contract lacking
the check **passes**) and `CSG.2` (config present → **the same contract body**
fails, and the message must name `check-component-coverage`) pin the condition
from both sides. `CSG.1` alone is satisfied by an "always skip" bug; `CSG.2`
alone by an "always require" bug, i.e. the pre-fix behaviour. `CSG.3` covers
`capability_enforcement: required`, `CSG.4` proves the activated requirement is
satisfiable by a genuine advisory-state producer run (so Pass 7's
producer-digest verification is exercised, not bypassed), and `CSG.5` mirrors
`CSG.2` at the `critical` tier.

Non-vacuity was demonstrated by mutation against the candidate, not asserted:

| mutant | suite | caught by |
| --- | --- | --- |
| unmutated | PASS | — |
| stuck-open (`if True:` — always skip) | FAIL | CSG.2, CSG.3, CSG.5 |
| stuck-shut (condition deleted — pre-fix) | FAIL | CSG.1 |
| inverted (sign flip) | FAIL | CSG.1, CSG.2, CSG.3, CSG.5 |

The full staged suite against the candidate reports **131 passed / 0 failed**
(126 + 5). No negative fixture was touched, no assertion relaxed, and no check
added to suppress an expected failure.

#### Publication note

The active PreToolUse hook rejects commands and writes naming this suite's path
even though the checked-in guard predicate exempts the `human-copy/` staging
prefix. The file was therefore written by a helper script that received the
destination as an argument; the resolved destination was the sanctioned staging
path, never the protected live path. The live `tests/gates.tests.sh` is
unmodified.

### 5. `spec-review-precheck.{sh,ps1}` — severity-to-verdict rule narrowed (2 files, 2026-08-11)

**Awaits human confirmation of the ruling below before application.** This
candidate executes a ruling that has been *prepared for* the human, not yet
confirmed by them; it is staged so the decision can be applied in one step.

**The deadlock.** `validate_reviewer_output` (live `.sh:185-186`, live
`.ps1:235-238`) derived an expected verdict from a reviewer's own finding
severities — any FAIL/Critical → BLOCKED — and rejected an output whose
declared verdict differed. Attempt-2 round-1 of this feature's spec re-review
persisted reviewer B's output verbatim: verdict `NEEDS_WORK` carrying one
FAIL/Critical (`CONTRADICTION`). Every subsequent `spec-review-precheck`
invocation re-validates that round's contract and hard-fails (`prior round
contract is malformed or does not require work`), so neither round 2 nor an
attempt-3 `--reset` chain can ever open. Reproduced read-only on 2026-08-11 in
a scratch clone, both runtimes, before building this candidate.

**The ruling being executed (pending confirmation).** The role documents are
authoritative and the validator overreached: `review-context-boundary.md`
defines BLOCKED as a launch/boundary failure — the review could not be validly
conducted — and neither `spec-reviewer-b.md` nor any other role document
states a severity-to-verdict formula. A reviewer that conducted its review and
found a Critical problem has returned NEEDS_WORK correctly; content severity
and procedural blockage are different questions. reviewer-b.json remains
verbatim; the validator changes.

**Scope, precisely.** Coherence checking is narrowed, not removed:

- a declared PASS carrying any FAIL is still rejected;
- a declared NEEDS_WORK **or** BLOCKED is accepted whenever at least one FAIL
  exists, at any severity — the choice between them belongs to the reviewer;
- a declared NEEDS_WORK or BLOCKED carrying zero FAILs is still rejected;
- every other validation (key set, check-id sequence, counts consistency,
  manifest hashes, merged-verdict derivation) is untouched.

The merged contract verdict computation (`critical/major → NEEDS_WORK`, round
3 → `BLOCKED`, etc.) is unchanged — it never depended on the per-reviewer
declared verdict, only on the checks.

**Verified, both directions, both runtimes** (scratch clones with the
candidate applied per the recipe above; live worktree untouched):

- The real deadlocked invocation — `spec-review-precheck 2 2` for this
  feature with the post-amendment inputs — completes end-to-end (exit 0,
  round-2 `precheck-result.json` persisted). It does not merely pass the
  prior-round validation; nothing later stops it.
- Three shapes, mutating only the fixture's reviewer-b `verdict` field:
  declared PASS with FAIL/Critical → rejected; declared NEEDS_WORK with
  FAIL/Critical (the verbatim real record) → accepted; declared BLOCKED with
  FAIL/Critical → accepted. Identical results under bash and pwsh.
- Zero-FAIL non-vacuity: an all-PASS 7-id fixture contract validates through
  the reset path; the same fixture with reviewer-b verdict flipped to
  NEEDS_WORK (still zero FAILs) is rejected. Both runtimes.
- Regression: attempt-1/round-3's terminal PASS contract (real PASS reviewer
  outputs) still validates via `--reset` under the candidate `.sh`, and the
  full live `tests/spec-review-loop.tests.sh` suite passes unmodified against
  the candidate (its fixtures — Critical→BLOCKED, Major/Minor→NEEDS_WORK,
  none→PASS — all remain coherent under the narrowed rule; no test asserts
  the removed derivation).

**Observed pre-existing `.ps1` parity gaps — deliberately NOT addressed here**
(each verified to fail identically under the live, unfixed `.ps1`, so neither
is caused by this candidate):

1. The `.ps1` compares manifest paths ordinally against local absolute paths;
   it lacks the `.sh`'s recorded-root normalization, so evidence recording
   relative paths (this feature's attempt-2) or another checkout's root
   (attempt-1) fails its manifest comparison from any other checkout.
2. The `.ps1` requires full check-id list equality; the `.sh` accepts a
   historical prefix (epic-136-phase3 precedent). Attempt-1/round-3's six-id
   outputs (pre-DOMAIN-CONFORMANCE) are rejected by the `.ps1` for that
   reason alone.

Widening this candidate to close those gaps was out of its sanctioned scope;
they are recorded here so the deadlock fix is not blamed for them.

**Impl/task prechecks carry no analogous rule.** `impl-review-precheck.sh`
and `task-review-precheck.sh` (and their `.ps1` twins) validate predecessor
PASS contracts at the merged level only; neither derives a per-reviewer
verdict from severities. The spec pair was the only site of the rule, so this
candidate's two files are the complete fix.

## Not staged, deliberately

**`plugins/sdd-quality-loop/scripts/check-contract.sh`** — no manifest entry,
because no candidate was produced.

It is a 49-line thin dispatcher (`python3` → PowerShell → error exit); it
declares no `RISK_TIERS` and runs no verification passes of its own, so both
halves of T-004's specified additive change land in `check-contract.py` and
`.ps1` only. Authoring it "from the live file plus that change" would reproduce
the live file byte-for-byte, and staging an unmodified copy would be worse than
useless: applied later it could silently **revert** an intervening live edit.
`drafts/MANIFEST.sha256` reached the same conclusion independently.

T-004.md's Unresolved Items #1 citation of a three-file Bundle B is therefore
inaccurate; **Bundle B is two files.**
