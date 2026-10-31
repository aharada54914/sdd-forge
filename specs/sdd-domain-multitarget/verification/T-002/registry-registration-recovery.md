# Issue #423 bounded Registry prerequisite recovery

Date: 2026-09-29
Run ID: sdd423-registry-registration-recovery-20260929
Task Attempt Count: 1
Prior Correction Count: 3/3
Prior Additional Correction: nested-state extra1 (preserved)
Result: BLOCKED — protected write refused; implementation unchanged

## Scope and actual cause

This investigation is within the human-approved bounded root-cause repair
scope. It does not reset prior correction history or change task state.

The real Registry dispatcher fails with five independent diagnostics:

- Four existing Python gate masters are absent from the canonical Registry:
  `check-component-coverage`, `check-contract`, `check-criterion-freeze`, and
  `check-hook-activation-handshake`. The validator deliberately scans every
  direct `check-*.py` master and requires one registration per real path
  (`plugins/sdd-quality-loop/scripts/validate-capability-registry.py:197`).
- `check-update-migration` references a nonexistent Python master
  (`contracts/capability-registry.json:8`). A repository-wide filename and
  identifier search found no implementation or concrete success/CLI contract.
  The Foundation design identifies this reference as an illustrative fixture
  (`specs/epic-190-a2-capability-registry/design.md:515`). The durable-workflow
  capability nevertheless refers to it in the real Registry
  (`contracts/capability-registry.json:61`).

Reproduction (run from the repository root):

```text
rtk proxy bash plugins/sdd-quality-loop/scripts/validate-capability-registry.sh --registry contracts/capability-registry.json
```

Exit 1; the complete canonical diagnostics are included in the RED test
output in `registry-registration-evidence.json`. The previously captured
dispatcher logs remain in `nested-state-extra1-evidence.json` unchanged.

## RED and protected refusal

`registry-registration.tests.py` exercises the real Registry and the real
POSIX dispatcher. RED ran two methods with five failures: four missing
registration subtests and the dispatcher still emitting all five diagnostics.
No failing test is reported as an execution-policy refusal.

The subsequent ordinary `apply_patch` attempted only to add the four existing
masters as blocking implementation-stage gates. PreToolUse refused the
protected canonical Registry write. The refusal is recorded separately in
`registry-registration-evidence.json`; no alternate path, sudo, guard change,
stage change, or substitute implementation was attempted. Canonical, vendored,
and generated Registry files remain unchanged at the recorded hashes.

## Candidate and remaining boundary

`registry-registration-candidate.json` is a data-only human-apply candidate
bound to the current canonical hash and HEAD. It names the four additive
entries and the existing vendor/projection outputs to regenerate after a
permitted application. It is not an applied patch or GREEN evidence.

The missing migration gate is not fixed by those four entries. Removing its
reference, changing its stage, or inserting a dummy always-passing script
would weaken the required gate and is not done. Its unavailable required
check must remain explicitly blocking until a concrete contract and real
implementation exist. This prerequisite is independent of the already-fixed
nested provider-state boundary; the validator's nine checks remain intact.

No frozen specification, task lifecycle field, implementation report, formal
quality verdict, commit, push, or PR was changed. T-003 onward remains behind
the current T-002 Blocked dependency. Native Windows and current-head CI are
not evidenced by this local RED investigation.

## Root-cause follow-up and candidate-only verification

The bounded follow-up did not retry the rejected source write. It separated
the additive registration defect from the older fixture/production contract
conflict; prior RED, refusal, correction counts and dispatcher logs remain
unchanged.

The second defect is a design/implementation mismatch, not evidence that a
real migration checker merely needs a guessed implementation:

- A2 design explicitly says its Registry example is an illustrative fixture,
  not literal shipped content (`specs/epic-190-a2-capability-registry/design.md:121`).
  A2 T-001 nevertheless planned fixture-only canonical content
  (`specs/epic-190-a2-capability-registry/tasks.md:182`).
- T-001 implementation copied that example verbatim into the canonical
  Registry, explicitly acknowledging the absent checker and deferring its
  existence validation to T-004's fixture coverage
  (`reports/implementation/epic-190-a2-capability-registry/T-001.md:44`).
- T-004 later recorded the canonical missing implementation and unregistered
  master as sanctioned gaps, using a clean synthetic Registry instead of
  reconciling the shipped Registry (`reports/implementation/epic-190-a2-capability-registry/T-004.md:217`).
- A2 acceptance tests require generic existing-file validation and exhaustive
  real-master registration, but define no migration algorithm or CLI
  (`specs/epic-190-a2-capability-registry/acceptance-tests.md:40`).
  ADR-0017 mentions migration simulation generally and uses this gate as a
  YAML example, not an executable contract (`docs/adr/0017-gate-stage-model.md:42`,
  `docs/adr/0017-gate-stage-model.md:89`).

Caller/contract audit: an exact identifier search across quality-loop scripts,
A2 validator/projection suites, and A2/423 acceptance/design/requirements
finds only generated Registry data under executable scripts, the A2 JSON
example, and no concrete migration-check caller or behavior test. The real
data path is canonical/vendor Registry -> validator check (b) -> Resolver
Registry validation -> capability matching -> `resolved_gates[]` join
(`plugins/sdd-quality-loop/scripts/validate-capability-registry.py:83`,
`plugins/sdd-quality-loop/scripts/resolve-project-context.py:2515`).
The available CLI is the **Registry validator**, `--registry` (plus test-only
`--repo-root`), which emits diagnostics/exit 1 for missing implementation;
there is no `check-update-migration` executable to have a CLI contract.

Deleting the example capability is not an acceptable implicit fix. The
Resolver derives `minimum_enforcement: required` and non-Lite eligibility
from matched capabilities, while no matches omit enforcement and yield Lite
eligibility (`plugins/sdd-quality-loop/scripts/resolve-project-context.py:2560`,
`plugins/sdd-quality-loop/scripts/resolve-project-context.py:2574`). Removing
`durable-workflow` would drop its data/PII facets, replay-safety review check,
required migration gate and Lite upgrade. Issue #423 REQ-003 and TEST-003c /
TEST-004 instead require unavailable legacy-required checks to remain
explicitly BLOCKED until an approved versioned migration
(`specs/sdd-domain-multitarget/requirements.md:148`,
`specs/sdd-domain-multitarget/acceptance-tests.md:17`). No other production
capability was found that preserves those obligations.

Thus the unresolved minimum contract is: whether `durable-workflow` is a
supported production capability or a fixture to isolate; if production,
which migration input/base/target and compatibility invariants are checked,
what evidence/output schema and success/failure/unavailable exit semantics
apply, and where the actual callers dispatch it; if fixture-only, what
approved versioned migration preserves or explicitly replaces the current
required obligations before removing it. None is inferred or implemented
here. A passing dummy, validator weakening, stage change, or silent capability
deletion was not made.

The 4-registration candidate now has complete staged canonical, vendored,
and generated files under `human-copy/T-002-registry/`. Existing projection
`load_registry` / `build_projection` / `render` functions and the real POSIX
validator are reused, not replaced. `registry-registration.tests.py
--candidate` passes four methods: exact hash/HEAD-bound additive delta,
vendor/projection/manifests consistency, exact remaining missing-gate
diagnostic, and all four real-master registrations. The candidate validator
still exits 1 with **only** `implementation-ref-missing: check-update-migration`.
This is candidate GREEN for the bounded registration repair, not full gate
PASS or source GREEN. The canonical dispatcher still has all five diagnostics.

One read-only `python3 -c` import/render attempt was also denied by PreToolUse;
it was not retried and no source application used an alternate route. The
authorized task-owned candidate suite subsequently reused the existing
projection functions successfully. The existing publisher's duplicate-name
rule requires two manifests rather than one three-file atomic publication;
the human-only preparation documents that limitation and exact baseline
hashes. Neither publisher invocation, formal gate, Windows execution, nor
source application was performed.
