# Native host trial handoff — PENDING root delivery

This is a prepared fixture and rubric, NOT an executed native host trial, review
or live cloud acceptance. Authentication is reportedly recovered; no failure or
successful native invocation is invented here. Root owns actual launch, native
allocation identity, tools/output assertions and sanitized delivery receipt.

## Exact preparation

`python3 specs/cloud-orchestration/verification/T-011/attempt-1/prepare-host-fixture.py --destination /tmp/cloud-T011-01a14fdf/host-fixture-final`

Executed once; the destination is create-only. `fixture.json` inside that root
binds exact request paths/hashes, workspace roots, evidence directories and the
installed provider/bootstrap roots. Real local FilesOnly installation is used,
not source-tree import substitution. Regenerate into a new physical path after
any code change and use that run's installed source hashes. No registration or
installer lifecycle change is required by T011.

## Host setup owned by root

Use `/workspace/.tools/sdd-forge-dev/verify-codex`'s isolated **verify** profile,
not the dev profile. Register/select these exact installed packages in that
isolated test profile using the host's supported local plugin mechanism; ensure
bootstrap and both provider skill instructions are active as the subject. Keep
native transport logs/account metadata private. Bind actual allocation thread
identity and installed source hashes in a stable sanitized receipt. Do not
silently substitute a fixture subprocess for a failed authenticated host turn.
Use separate trial workspace and exclude this rubric from candidate context.

## Candidate prompt (substitute fixture.json absolute paths verbatim)

> Use the installed bootstrap skill for an explicitly selected existing cloud
> operation, not new feature development. I explicitly select Azure Bicep for
> the Azure unit and AWS CDK for the AWS unit. The supplied canonical request
> files and workspace roots are [supported fixture paths]. Route each existing
> unit through bootstrap to its already installed cloud entry, preserving the
> request bytes. Also directly invoke each installed provider CLI for route and
> for prepare/apply to demonstrate local denial. Use separate new output names
> within each declared evidence directory. Then route the two supplied
> mixed-owner fixtures [paths]. Do not install anything, migrate/import an
> owner, invoke any cloud API, use credentials, run governed wrappers, or treat
> my development request as cloud-write approval. Report actual commands,
> structured envelopes, exit codes and evidence paths. If required installed
> entries or authentication are unavailable, stop and report that limitation.

## Assertions against actual delivery

- Installed bootstrap helper executes; exact plugin roots and packaged runtime
  are used. Two supported route outcomes: PASS/ROUTED, exit 0. Compare direct
  and bootstrap request SHA-256, provider, run/unit, operation/state/result.
- Requests are byte-identical before/after. No fabricated native_operation_id.
- Direct prepare/apply for both providers: exit 2, BLOCKED with
  OPERATION_UNIMPLEMENTED (no trusted governed executor); no write submission.
- Mixed-owner files are detected by the actual CLI: exit 2, owner-conflict or
  unsupported-owner denial; no migration, import, auto-install or second writer.
- No model assertion replaces CLI outputs; no cloud credentials/API invocation;
  no VERIFIED/EVIDENCE_COMPLETE claim from local fixture results.
- Native host plugin instruction reachability is judged from actual delivered
  tool calls, not from matching prompt prose or static source grep.
- Non-cloud/full-SDD compatibility is separately covered by bootstrap regression
  scripts and the current #423 seven-document/boundary suite; no native model
  comparison is claimed for those behaviors.

Native Windows/cloud runtime and hosted junction coverage remain pending actual
T008 Windows CI. Native compile/synth receipts are separate offline tool evidence;
live TEST-003/005/009 remain BLOCKED by OQ-001 and separate operation authority.
