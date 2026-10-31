# T-010 design-conformance gap (candidate, 2026-10-04)

This is a non-frozen analysis candidate, not an amendment, approval, review
verdict, or evidence that T-010 is Implementation Complete. It must not
supersede the reviewed specification by itself.

## Exact divergence

| Reviewed contract | Current implementation | Consequence |
|---|---|---|
| `requirements.md:315-325` and `acceptance-tests.md:8` make AC-004's named SKIP last until A5 lands/merges; `requirements.md:480-485` and `acceptance-tests.md:25` give AC-021 the A1+A5 merge boundary. | `tests/fixtures/skip-allowlist-manifest.json` adds `executable_contains(plugins/sdd-bootstrap,resolve-project-context)` to those two activation expressions. | An A5 merge alone no longer activates the two assertions. This is not a harmless formatting change to the approved condition. |
| `design.md:412-477` fixes the A5 item-10 fingerprint at `1886-1915`, `sha256:9b549be9c9d8897c9efd1badbab8a5d4184086649e98a3c31325ef3210561bff`; `tasks.md:1469-1470` requires the exact five entries and fingerprint values. | The manifest cites `2139-2179`, `sha256:1bf6f2e295bcc8ef49ca93755c046ef6a6301b604ae9d33c1aa95e00e4f8b33c` for AC-004 and AC-021. | The shipped value may track the later A5 text, but a fresh comparison and formal re-binding are required. A passing local test that expects the changed value does not prove conformity to the frozen value. |
| `design.md:548-578` permits only `merged(...)` and `fingerprint_match(...)` predicates and requires merged fingerprint drift to hard-fail independently. | The evaluator supports `executable_contains(...)`, and before the current T-010 repair checked drift only while parsing SKIP-shaped output. | The added predicate needs specification review; the zero-SKIP drift gap is an independent implementation defect and must remain hard-fail even if activation is later amended. |

The caller deferral has a real technical motivation, but is not already an
approved replacement for the merge boundary. A5's `design.md:3-11` names a
documented, not implemented, caller integration contract. A7's
`requirements.md:263-270` says its existing suite should adopt the A5 fixture
assertions once that caller insertion point is implemented.
`tests/loop-escalation.tests.sh:883-905` currently records an informational
deferral when its executable-file-only heuristic finds no caller and requires
a real invocation driver when that heuristic finds one. That heuristic is
incomplete: the live `plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/
SKILL.md:63-101` does contain the capability interview caller instruction,
including one Resolver dispatcher invocation and the absent/disabled-legacy
no-subprocess rule. Its presence does not by itself prove the AC-004/AC-021
runtime spy: the existing INFO branch does not drive the interviewer.

Issue #353 named the interviewer caller and caller-contract test pair, and
the current repository does contain both: the live SKILL phase above and
`tests/resolve-project-context-caller-contract.tests.sh`/`.ps1` with a
shared Python checker. That checker verifies static phase adjacency,
required text markers, a committed post-integration anchor, and a heading
relocation mutation. It does not execute an interviewer invocation or spy
on Resolver subprocess creation. PR #473 added only the three live Resolver
files, so its narrow file list must not be used alone to infer the presence
or absence of the separate SKILL/test integration. The earlier assertion
in this candidate that issue #353 remained unimplemented was incorrect and
is superseded by this paragraph. Do not reopen #353 on that basis.

The current A7 spy branch's own self-check (`tests/loop-escalation.tests.sh:
863-868`) calls the shadow command directly, proving only the spy records
such a call. Its three subsequent `build_fixture` calls (`:871-875`) create
temporary files; `tests/lib/fixture-matrix-builder.sh:33-130` neither drives
the interviewer nor calls Resolver. The present INFO/`ok` at `:900-905`
therefore has zero opportunity to observe the skill's real decision. The
A5 caller-contract suites were rerun on 2026-10-04 (Bash and PowerShell,
both exit 0, anchor `99133e6c154a928451ce2dd84f71e414e318fe53005b98ef1fd59b1acf491d9c`,
heading ordinal 4); these are structural checks, not the missing runtime
spy. A bounded correction must remove the false-green executable-file-only
deferral and supply a real interviewer invocation driver with an observable
dispatcher boundary before AC-004/AC-021 can be marked verified. Merely
rechecking the Markdown or adding a synthetic CLI is not that proof.

## Bounded resolution decision before Implementation Complete

1. Determine whether the approved merge-gated ACs should be satisfied by
   wiring the real caller and the A7 invocation driver, using the existing A5
   caller contract, or whether the approved requirements/ACs need a prospective
   condition change. The latter is a scope-changing specification amendment,
   not an implicit ratification of the current manifest. Its review must
   explicitly reconcile `requirements.md`, `acceptance-tests.md`, `design.md`,
   `tasks.md`, and traceability while preserving AC-035's merged-drift hard
   failure. No frozen artifact is changed by this candidate.
2. Recompute the A5 fingerprint from the actual admitted A5 source revision
   and compare both windows. If a new digest is correct, bind that exact
   source/range/digest in the formally reviewed specification and T-010 task;
   do not treat the current manifest's self-test as independent proof.
3. Only after the selected contract is reviewed, execute AC-004/AC-021
   against the applicable live caller and then perform independent T-010
   quality-gate evaluation. Current-head CI green and the scoped zero-SKIP
   repair are narrower evidence, not a substitute for those steps.

No external model, formal reservation, approval decision, or Done status is
created by this document.

## 2026-10-04 bounded live-host driver investigation

The existing repo-local runner is not an interviewer process driver.
`tests/resolve-project-context-caller-contract-check.py:22-125` checks the
live Markdown phase, required markers, normalized window digest, ordinal and
relocation mutation. `tests/workflow-scenarios/workflow-scenarios.tests.sh:
347-375` explicitly substitutes a proxy for a non-executable SKILL.md. A
bounded search of `tests/` and `scripts/` found no existing command that
invokes the real bootstrap/interviewer skill on F1/F3/F4 under a host.
`tests/lib/loop-driver.sh` is a fixture loop driver, not that host. These
observations do not turn static checks into runtime proof.

The installed Claude CLI's local `--help` exposes `--plugin-dir`, `--print`,
`--output-format=stream-json`, and `--permission-mode`; the plugin descriptor
exists at `plugins/sdd-bootstrap/.claude-plugin/plugin.json`. This supplies a
documented host invocation *candidate*, not a completed or authorized
test result. A bounded driver would need an isolated scratch project with
the reviewed plugin bytes and one case-specific Project Context/approval
fixture, pinned source/target revision and feature slug, the normal host
hooks/permissions intact, and a fresh interviewer session per case. It must
capture the host tool-call trace and terminal outcome, prove that each run
actually reached the relevant capability/validation decision, then assert
no Resolver dispatcher call for F1 absent Context and F3/F4 invalid Context.
A positive valid-Context control must prove the same trace can observe one
real dispatcher call; a direct self-call to a PATH spy is insufficient.
All fixture writes stay in scratch. A host permission or SDD hook refusal is
recorded and not re-expressed through another executor. The exact F3/F4
expected stop diagnostic must be fixed from the governing A1/A5 contract
before execution, not inferred from zero calls.

There is an additional entry-boundary prerequisite: the interviewer
`SKILL.md:23-29` says it is internal and **not directly invocable** in Claude
Code. The actual entry is `/sdd-bootstrap:bootstrap` (`bootstrap/SKILL.md:
20-35`), whose `:105-159` track routing first requires a live
hook-activation canary and approval-sidecar validation; an invalid Context
stops before interviewer invocation. Its full-track route then initiates
artifact generation and review gates (`:161-193`). Thus an ad hoc
`/sdd-bootstrap-interviewer` turn would be a false test, while running the
full entry in the dirty owner checkout risks unrelated writes. Before a
real-host fixture is run, the scratch project must prove normal hooks
active and constrain the run to its own disposable files using the host's
ordinary permission boundary; a test that stops at `CAPABILITY_RUNTIME_UNAVAILABLE`
or an untrusted-clone hook omission is not F1/F3/F4 evidence. No such
host-valid scratch fixture or first model turn was created here, so this
candidate is not yet executable evidence.

Minimal false-green correction candidate for the Bash and PowerShell A7
twins: replace the executable-source-only caller detector and
`ok ... deferred` branch (`tests/loop-escalation.tests.sh:883-905`, with
PowerShell counterpart) with an explicit *unverified/failing* outcome when
the live skill phase exists but no interviewer run was driven. Keep the
fixture builder's own success and spy self-check as narrow assertions only.
Do not relabel zero observed fixture invocations as AC-004/AC-021 PASS or
silently extend their frozen merge activation through the new manifest
predicate. This correction would deliberately make the current suite red
until a real driver and reviewed activation contract are supplied; it is a
candidate, not an applied edit or quality verdict. A5 `design.md:2139-2179`
also calls for the caller-contract suite's no-call and exactly-one-call
spy fixtures after the phase is implemented, independently of A7's static
tests.
