# Tasks: epic-136-phase2-gates

Task-Review-Status: Passed

Source: Issues #117, #118, #119, #121, #122 / requirements.md
(Spec-Review-Status: Passed) / design.md (Impl-Review-Status: Passed)

## Lifecycle

`Draft -> Approved -> In Progress -> Implementation Complete -> Done`

A task may enter `Blocked` from any active state. Humans approve tasks.
`implement-task` may set `In Progress`, `Blocked`, or `Implementation Complete`.
Only `quality-gate` may set `Done`.

## Human-Copy Procedure (protected enforcement-chain files)

Every task below changes at least one R-10 protected enforcement-chain file.
The agent stages the exact candidate under
`specs/epic-136-phase2-gates/human-copy/<repository-relative-target>` and
prepares `MANIFEST.sha256`; it never writes the live protected target. Until
T-006 installs the immutable runner, the human validates target identity and
SHA-256, then copies only the listed candidates and runs the named suites. T-006
introduces the bootstrap/update runner specified in design.md; its staged
candidate is itself subject to the same human inspection.

## Global Constraints

- One issue = one commit. Implement in the listed order; no task is Done until
  its independent quality gate PASS is saved.
- `.ps1` sources remain ASCII-only with no BOM and must run under Windows
  PowerShell 5.1.
- Each high/critical risk implementation report begins with the AGENTS.md
  preflight: persisted evidence field, sibling contract/traceability
  counterpart, and a failing mismatch test for every recorded field.
- Preserve unrelated changes and re-run the shared guard corpus after any
  generated-module import change.

---

## T-001 Narrow read-only token classification without relaxing protected writes

Source Issue: https://github.com/aharada54914/sdd-forge/issues/117

Approval: Approved (sudo 2026-07-13T05:53:16.481Z)

Status: Done

Risk: high

Risk Rationale: This changes the R-10 guard's command-token classification in
all three decision runtimes. An over-broad exception could turn an ambiguous or
write payload into an allowed protected-file modification (REQ-001).

Required Workflow: tdd

Security-Sensitive: true

Requirements: REQ-001

Depends On: none

Planned Files:

- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py` (protected — human-copy)
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.js` (protected — human-copy)
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1` (protected — human-copy)
- `tests/phase2-guard-tokenizer.tests.sh` (new, agent-editable)
- `tests/phase2-guard-tokenizer.tests.ps1` (new, agent-editable)

Data Migration: none

Breaking API: no; preserve hook protocol, existing corpus decisions, and all
protected-write denials.

Rollback: human re-copies the prior three guard twins and re-runs the named
focused and parity suites.

### Goal

Make the three tokenizers accept only the proven legal read-only forms from
REQ-001: balanced quoted regex backslashes, standalone `2>&1`, and `ls`/`cat`/
`find` inspection of protected paths. Keep unquoted boundary-changing escapes,
unclosed quotes, unresolved redirect targets, writes, and every ambiguous form
fail-closed and cross-runtime equal.

### Must Read

- `specs/epic-136-phase2-gates/requirements.md`
- `specs/epic-136-phase2-gates/design.md`
- `specs/epic-136-phase2-gates/acceptance-tests.md`
- `specs/epic-136-phase2-gates/security-spec.md`
- `specs/epic-136-phase2-gates/traceability.md`
- `plugins/sdd-quality-loop/references/risk-classification-policy.md`

### Scope

- Capture a failing cross-runtime fixture before changing a guard.
- Stage all three complete guard candidates under `human-copy/` and do not
  alter the live paths.
- Preflight must bind each saved decision fixture to the corresponding
  Python/Node/PowerShell verdict and include a failing parity-mismatch test.

### Done When

- [ ] TEST-001 proves the legal quoted-regex, `2>&1`, and read-only inspection
  fixtures are allowed identically in Python, Node, and PowerShell (AC-001).
- [ ] TEST-002 proves redirects with unresolved targets, `tee`, `cp`, `rm`,
  unquoted boundary-changing backslashes, unclosed quotes, and protected writes
  remain denied identically (AC-002).
- [ ] The implementation report contains RED/GREEN evidence and the required
  high-risk preflight; focused guard, PowerShell 5.1, and parity suites pass.
- [ ] An independent quality-gate report records PASS; the non-frozen
  `specs/epic-136-phase2-gates/verification/T-001/quality-gate-addendum.md`
  records the final requirement and acceptance conclusion.

### Out of Scope

- A complete shell interpreter or permission for an unclassifiable command.

### Blockers

None

---

## T-002 Replace PowerShell HMAC string comparison with a PS5.1-compatible full XOR scan

Source Issue: https://github.com/aharada54914/sdd-forge/issues/118

Approval: Approved (sudo 2026-07-13T08:49:33.453Z)

Status: Done

Risk: high

Risk Rationale: Sudo token verification is a credential boundary. A malformed
decoder or early comparison can leak information or accept a forged signature
(REQ-002; security-spec.md signed-token boundary).

Required Workflow: tdd

Security-Sensitive: true

Requirements: REQ-002

Depends On: T-001 (both stage the complete PowerShell guard; T-002's candidate
must start from the human-applied T-001 version)

Planned Files:

- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1` (protected — human-copy)
- `tests/phase2-sudo-signature.tests.ps1` (new, agent-editable)
- `tests/phase2-sudo-signature-static.tests.sh` (new, agent-editable)

Data Migration: none

Breaking API: no; preserve the signed-token wire format, TTL, and fail-closed
hook behavior.

Rollback: human re-copies the prior PowerShell guard and re-runs the PowerShell
and guard parity suites.

### Goal

Add one internal comparator that first requires exactly 64 hexadecimal
characters, decodes both 32-byte values with two-character `Substring` and
`[Convert]::ToByte(...,16)`, XORs every position, and decides only after the
fixed full scan. `FixedTimeEquals`, `FromHexString`, and direct `sig` string
comparison are forbidden.

### Scope

- Write valid, malformed, and first/middle/final-byte mutation fixtures before
  the protected candidate is staged.
- Add the static body oracle stated in TEST-004 and retain ASCII/no-BOM source.
- Preflight binds the saved comparator verdict to its static loop/body oracle
  and includes a failing mismatch test for each persisted result.

### Done When

- [ ] TEST-003 accepts the valid HMAC and rejects malformed, first-, middle-,
  and final-byte changes using the full 32-byte comparator (AC-003).
- [ ] TEST-004 proves fixed 32-iteration XOR structure, PS5.1 decoding APIs,
  no early loop exit/direct string comparison/`FixedTimeEquals`/`FromHexString`,
  and ASCII/no-BOM source (AC-004).
- [ ] The report records RED/GREEN and the required high-risk preflight; the
  focused PowerShell suite and relevant guard suites pass.
- [ ] An independent quality-gate report records PASS; the non-frozen
  `specs/epic-136-phase2-gates/verification/T-002/quality-gate-addendum.md`
  records the final requirement and acceptance conclusion.

### Out of Scope

- Changing HMAC key management, token payload fields, or TTL.

### Blockers

T-001

---

## T-003 Extract the three PowerShell evidence-path checks into one compatibility-preserving helper

Source Issue: https://github.com/aharada54914/sdd-forge/issues/119

Approval: Approved (sudo 2026-07-13T06:27:16.932Z)

Status: Done

Risk: high

Risk Rationale: Evidence-path validation protects quality-gate provenance.
Refactoring three copies without exact output regression coverage can make one
field accept traversal or lose an automation-visible diagnostic (REQ-003).

Required Workflow: tdd

Requirements: REQ-003

Depends On: none

Planned Files:

- `plugins/sdd-quality-loop/scripts/check-contract.ps1` (protected — human-copy)
- `tests/phase2-contract-path-helper.tests.ps1` (new, agent-editable)
- `tests/fixtures/phase2-contract-path-golden/` (new reviewed fixtures,
  agent-editable)

Data Migration: none

Breaking API: no; exact existing output and exit behavior remains the contract.

Rollback: human re-copies the prior `check-contract.ps1`; revert helper and
fixture additions.

### Goal

Capture complete pre-refactor output for every ordinary/red/green evidence
field and path case, then replace the three inline validators with one
structured helper while callers preserve the exact field-specific diagnostics.

### Scope

- Capture golden stdout, stderr, and exit code before the refactor, LF-normalize
  only for cross-host fixture comparison.
- Cover POSIX/Windows/UNC absolute paths, traversal, unresolvable paths,
  missing files, and valid in-root files for all three fields.
- Preflight binds each persisted golden result to the helper result and a
  failing exact-output mismatch test.

### Done When

- [ ] TEST-005 exactly compares each absolute/traversal/unresolvable golden
  case for `evidence`, `red_evidence`, and `green_evidence` after LF
  normalization (AC-005).
- [ ] TEST-006 proves valid in-root and missing-file behavior retains its
  prior contract for all three fields (AC-006).
- [ ] The report records RED/GREEN and high-risk preflight; focused PowerShell
  tests pass.
- [ ] An independent quality-gate report records PASS; the non-frozen
  `specs/epic-136-phase2-gates/verification/T-003/quality-gate-addendum.md`
  records the final requirement and acceptance conclusion.

### Out of Scope

- Changing the contract schema or relaxing evidence containment rules.

### Blockers

None

---

## T-004 Force the full workflow when deterministic risk policy matches, including `--lite`

Source Issue: https://github.com/aharada54914/sdd-forge/issues/121

Approval: Approved (sudo 2026-07-13T06:47:18.468Z)

Status: Done

Risk: high

Risk Rationale: This controls whether security- and integration-sensitive work
can evade the full SDD review chain. A lexical mismatch or an incorrectly
ordered `--lite` branch could silently downgrade a risky task (REQ-004).

Required Workflow: tdd

Security-Sensitive: true

Requirements: REQ-004

Depends On: none

Planned Files:

- `plugins/sdd-lite/references/risk-upgrade-policy.md` (protected — human-copy)
- `plugins/sdd-lite/scripts/check-risk-upgrade.sh` (protected — human-copy)
- `plugins/sdd-lite/scripts/check-risk-upgrade.ps1` (protected — human-copy)
- `plugins/sdd-lite/skills/lite-spec/SKILL.md` (protected — human-copy)
- `plugins/sdd-ship/skills/ship/SKILL.md` (protected — human-copy)
- `tests/phase2-risk-upgrade.tests.sh` (new, agent-editable)
- `tests/phase2-risk-upgrade.tests.ps1` (new, agent-editable)

Data Migration: none

Breaking API: intentional safety behavior: a risk hit now selects full even
when `--lite` is requested; no-match lite behavior is preserved.

Rollback: human re-copies the prior policy/checkers/skills and re-runs checker
parity and workflow conformance suites.

### Goal

Implement the ordered local checker and invoke it before every lite-selection
path. A match emits its primary and ordered triggers, makes lite-spec stop
before any lite artifact, and makes ship select full despite `--lite`; missing
full inputs fail closed with a bootstrap diagnostic.

### Scope

- Implement the reviewed exact trigger/exclusion matrix in sh and PowerShell,
  including valid UTF-8 non-ASCII boundary behavior and malformed-input exit 2.
- Test the same stdout and exit code in both runtimes, then stage the policy,
  both checkers, and skill updates for human copy.
- Exercise every selection ordering boundary: `--full` bypasses the risk scan;
  default, profile, and `--lite` requests scan before any lite selection;
  opaque or unreadable lite-spec input fails before any artifact write; and
  ship fails closed when either its task block or requirements input is absent.
- Preflight binds each persisted risk verdict to the corresponding sh/PS
  result and ship/lite selection outcome, with a failing parity or track
  mismatch test.

### Done When

- [ ] TEST-007 proves required positive terms force full; exclusions and
  ordinary valid UTF-8 text remain lite eligible; non-ASCII boundary, NUL, and
  invalid-UTF-8 fixtures have the reviewed sh/PS parity; and default, profile,
  and `--lite` scan before any lite selection while `--full` bypasses the scan
  (AC-007).
- [ ] TEST-008 proves lite-spec writes nothing for a policy hit or an opaque/
  unreadable input, and ship forces full even with `--lite` (AC-008).
- [ ] TEST-009 proves an incomplete risk-hit full feature, a missing ship task
  block, and absent requirements stop with their bootstrap/full-track
  diagnostic before invoking the lite gate (AC-009).
- [ ] The report records RED/GREEN and high-risk preflight; focused parity and
  workflow conformance suites pass.
- [ ] An independent quality-gate report records PASS; the non-frozen
  `specs/epic-136-phase2-gates/verification/T-004/quality-gate-addendum.md`
  records the final requirement and acceptance conclusion.

### Out of Scope

- Remote issue retrieval, semantic natural-language classification, or a
  bypass to retain lite after a match.

### Blockers

None

---

## T-005 Generate runtime-native guard-invariant modules from protected canonical data

Source Issue: https://github.com/aharada54914/sdd-forge/issues/122

Approval: Approved (sudo 2026-07-13T09:09:09.7597219Z)

Status: Implementation Complete

Risk: critical

Risk Rationale: This changes the R-10 protection source of truth, all guard
runtime imports, and a CI trust anchor. An incorrect generator or module
loader could weaken protection or make runtimes diverge (REQ-005;
security-spec.md canonical-to-runtime boundary).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: enabled

Requirements: REQ-005

Depends On: T-001, T-002 (the generated guard loaders consume the completed
Python/JavaScript/PowerShell guard candidates and T-002's final PowerShell
candidate already includes T-001)

Planned Files:

- Canonical data, generator, four native modules, guard loader candidates, and
  `test.yml` from `requirements.md#protected-phase-2-target-inventory` (all
  protected changes staged under `human-copy/`)
- `tests/phase2-guard-invariants.tests.sh` (new, agent-editable)
- `tests/phase2-guard-invariants.tests.ps1` (new, agent-editable)

Data Migration: replace duplicated in-source invariants with committed native
generated modules; no user or service data migration.

Breaking API: no external API change; guard decisions retain the existing
protocol. Generated module exports are an internal versioned contract.

Rollback: human restores the prior reviewed canonical/module/loader/CI
candidates as one #122 batch, then re-runs generator check and guard suites.

### Goal

Add protected canonical `guard-invariants.json`, deterministic Python generator,
four committed native outputs, fixed-directory runtime loaders, and CI
`--check`. Preserve every existing R-10 suffix as a union and add every Phase 2
target to the generated protected inventory. T-006 owns protected publication
of these completed candidates.

### Scope

- Start with generator tests and a stale/missing/type/version RED case before
  staging a protected output.
- Prove Python/Node/PowerShell export every required key; the POSIX dispatcher
  exports only schema/provenance and makes no guard decision.
- Prove fixed-directory loaders ignore CWD/PYTHONPATH shadow modules, fail
  closed only when their own module is missing/invalid, and never parse
  canonical JSON at runtime.
- Prove all baseline R-10 paths and every Phase 2 target remain protected.
- Preflight binds canonical fields to every native export and generated source
  digest/schema to CI check; each has a failing stale/parity mismatch test.

### Done When

- [ ] TEST-010 proves deterministic generation of all four native modules,
  complete v1 exports, schema/provenance headers, and canonical schema
  validation (AC-010).
- [ ] TEST-011 proves non-mutating `--check` fails on stale/missing output,
  malformed/type/version input, and generator error; test.yml runs it before
  guard suites (AC-011).
- [ ] TEST-012 proves fixed loader resolution, ignored CWD/PYTHONPATH shadow,
  fail-closed missing/invalid fixed module, no runtime JSON parse, and the
  shared decision corpus from another CWD (AC-012).
- [ ] TEST-001 through TEST-004 are rerun after generated imports; their saved
  results remain PASS and cross-runtime decisions remain equal.
- [ ] The report records RED/GREEN and critical-tier preflight; cross-model
  consensus, signed evidence bundle, and a distinct second human approver are
  recorded before Done.
- [ ] An independent quality-gate report records PASS; the non-frozen
  `specs/epic-136-phase2-gates/verification/T-005/quality-gate-addendum.md`
  records the generation/loading conclusion for AC-010 through AC-012.

### Out of Scope

- Runtime parsing of canonical JSON, dynamic inventory expansion, or making
  the POSIX dispatcher a second guard-decision implementation. Protected
  publication and rollback are T-006.

### Blockers

T-001, T-002

---

## T-006 Publish the protected #122 batch with handle-relative Windows semantics

Source Issue: https://github.com/aharada54914/sdd-forge/issues/122

Approval: Approved (sudo 2026-07-14T01:20:00Z)

Status: Implementation Complete

Risk: critical

Risk Rationale: This task publishes the complete protected #122 batch and
defines failure/rollback behavior across R-10 trust anchors. Namespace
substitution, hard-link overwrite, or partial recovery could weaken live
enforcement even when generated candidates are correct (REQ-005;
security-spec.md canonical-to-runtime boundary).

Required Workflow: tdd

Security-Sensitive: true

Cross-Model: enabled

Requirements: REQ-005

Depends On: T-003, T-004, T-005 (publication consumes the completed evidence-
path, risk-policy, canonical, generated, loader, guard, CI, and immutable
runner candidate set)

Planned Files:

- `specs/epic-136-phase2-gates/human-copy/specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1`
  (staged protected candidate only)
- `specs/epic-136-phase2-gates/human-copy/MANIFEST.sha256`
- `tests/phase2-guard-invariants.tests.ps1`
- `reports/implementation/epic-136-phase2-gates/T-006.md`

Data Migration: none; this publishes committed source artifacts and records
pre-install digests, not user or service data.

Breaking API: none; the runner is a human-operated repository-local boundary.

Rollback: the human uses the reviewed complete prior batch; the runner refuses
partial, remapped, or digest-mismatched rollback input and re-runs post-install
verification after restoring every recorded pre-install digest.

### Goal

Replace path-based protected publication with a Windows PowerShell 5.1
`AnchoredCopySession` that reads authority, manifest, and sources through held
root-relative no-follow handles, prepares all verified same-parent temporaries,
and publishes each directory entry by parent-handle-relative atomic rename.

### Scope

- Start with failing static/native-contract, source/parent substitution,
  hard-link-alias, preparation-cleanup, and injected rename/rollback fixtures.
- Reject unsupported Windows, language mode, filesystem, native API, reparse,
  link, remap, duplicate, omission, expansion, and digest conditions before the
  first live replacement whenever the failure occurs before publication.
- Hold and re-use each verified source handle; hold destination parents; verify
  every temporary before publication; leave an exact candidate-prefix/previous-
  suffix state on injected rename failure; then prove complete rollback.

### Done When

- [ ] TEST-013 proves bootstrap/update inventory binding, anchored authority and
  source reads, same-handle copy, parent substitution resistance, hard-link-
  alias-safe atomic rename, all-temporary verification, cleanup, unsupported-
  capability denial, fixed-index prefix state, complete rollback, and final
  R-10 denial including `test.yml` (AC-013).
- [ ] The implementation report records failing RED evidence before runner
  changes, GREEN evidence, critical preflight, cross-model consensus, a signed
  evidence bundle, and a distinct second human approver before Done.
- [ ] An independent quality-gate report records PASS; the non-frozen
  `specs/epic-136-phase2-gates/verification/T-006/quality-gate-addendum.md`
  records the AC-013 publication and rollback conclusion.

### Out of Scope

- Canonical schema, generator, native exports, runtime loader behavior, or CI
  drift policy, which are completed by T-005.

### Blockers

T-003, T-004, T-005
