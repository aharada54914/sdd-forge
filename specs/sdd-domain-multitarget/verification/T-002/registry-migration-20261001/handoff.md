# Implementation handoff: RT-20260930-001 durable-workflow migration candidate

Run ID: sdd423-registry-migration-20261001
Task Attempt Count: 1 (candidate-only, as instructed: at most one iteration)
Status: Implementation Complete for the candidate scope; migration NOT applied, NOT Done.

Current candidate addendum (2026-10-01): `candidate-report.md` records the
separate candidate resolver and real-CLI RED/GREEN. The comparison below is
the production resolver with canonical versus data-only candidate Registry;
it does not describe the corrected candidate resolver. Candidate Python
SHA-256 after comment-only simplification: `ae27deb32d5af3d31dcbfd505812fd737603a9d682476451a855d48fb36ed511`.

Human-only isolated regression handoff (prepared, **not executed**): clone
`/private/tmp/issue423-resolver-regression.CfwaIT/checkout` is at HEAD
`06bc32cc26f2d67adb02e827610b5230e1658f72`. Candidate Registry SHA-256
is `42b884b2b58d2b370b03b64b115d0f20b7a049e60b5e715e673fe12c022564c1`;
candidate Python is `ae27deb32d5af3d31dcbfd505812fd737603a9d682476451a855d48fb36ed511`.
The exact one-time human command is:

```sh
rtk proxy python3 /Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge/specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/human-stage-isolated-clone.py
```

It requires `APPLY-ISSUE423-ISOLATED-CLONE` at the prompt and is limited to
that temporary clone. The six baseline hashes, backup/failure behavior, and
unexecuted existing-driver scope are in `candidate-report.md`. The helper
was syntax-checked only; no staging, existing-driver regression, formal
review, CI, or production application has occurred. The candidate-specific
CLI suite has since passed 5 methods/9 subcases, including unaffected Lite.

## Changed paths (all new, under this directory only)

- `migration-note.md` -- versioned migration decision, compatibility mapping, evidenced gap, proposed minimum source change
- `candidate/capability-registry.candidate.json` -- production candidate (4 real gates registered, durable-workflow/check-update-migration removed)
- `fixture/capability-registry.fixture.json` -- isolated illustrative example
- `fixture/plugins/sdd-quality-loop/scripts/check-update-migration.py` -- fixture-only placeholder (always fails honestly; not a pass stub)
- `fixture/plugins/sdd-quality-loop/references/provider-terms.json` -- fixture-isolation dependency stub
- `registry-migration.tests.py` -- regression suite (10 methods)
- `handoff.md` -- this file

No canonical, vendored, generated, human-copy, frozen spec/task, or ticket file was written; all reads of those were read-only, for evidence.

## Commands and exact results

RED (untouched canonical, real dispatcher):
```
rtk proxy sh plugins/sdd-quality-loop/scripts/validate-capability-registry.sh --registry contracts/capability-registry.json
```
Exit 1, 5 diagnostics (`implementation-ref-missing: check-update-migration` + 4 `unregistered-script`). Unchanged from prior evidence.

Candidate GREEN (real dispatcher):
```
rtk proxy sh plugins/sdd-quality-loop/scripts/validate-capability-registry.sh --registry specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/candidate/capability-registry.candidate.json
```
Exit 0: `validate-capability-registry: all 9 checks passed.`

Candidate regression suite:
```
rtk proxy python3 specs/sdd-domain-multitarget/verification/T-002/registry-migration-20261001/registry-migration.tests.py -v
```
Exit 0, `Ran 10 tests ... OK` (4 test classes: four-registration retention, phantom-gate-free validation + untouched-canonical-fail documentation, fixture isolation, and the legacy-obligation-gap evidence).

## Goals status

1. Four real gate registrations stay blocking -- proved, GREEN.
2. Production registry validates without the phantom example gate -- proved, GREEN (candidate only; canonical untouched, confirmed still RED).
3. Legacy durable-workflow-selecting contexts stay BLOCKED, not silently stripped of obligations -- **not achievable by registry data alone under the existing unmodified production resolver**; proved as a data-only baseline gap (`LegacySelectedContextObligationGap` test class). The separate candidate resolver addresses this in `candidate-report.md`, without production application.
4. Fixture demonstrates the example without production phantom references -- proved, GREEN.

## Pending

### 2026-10-01 execution update (supersedes earlier unexecuted handoff)

The human staged all six targets in the isolated clone; independent readback
matched all six reported hashes. The 12 existing paired Bash/macOS PowerShell
drivers then returned exit 0 (1,266 counted checks plus two caller-driver
successes). See `reports/verification/issue423-paired-regression-20261001.md`
for the exact scope and logs. These counts are not unique acceptance criteria,
native Windows results, CI or a quality-gate verdict.

The owner worktree still has the original six production targets. Publication
uses the same pinned helper with `--owner-worktree` and human confirmation
`APPLY-ISSUE423-OWNER-WORKTREE`. No human approval, task status, historical
review or Git state was changed by this execution update. Fresh owner checks
and formal T-002 evaluation remain required before T-003 implementation.

- The minimum candidate `resolve-project-context.py` change is implemented and CLI-tested separately (`candidate-report.md`); protected application and formal gate remain pending.
- Applying `candidate/capability-registry.candidate.json` to `contracts/capability-registry.json` (and regenerating the vendored/generated projections) remains a separate, protected-file publication step, not performed here.
- Formal quality-gate rerun for T-002 with fresh evidence, once the above is authorized and applied.
- RT-20260930-001 remains open; this candidate does not close it.
