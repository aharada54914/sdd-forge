# PR371 / PR381 evaluation compatibility probe

Scope: read-only diagnosis and fixed-commit schema checks, not an independent
review, quality-gate verdict, or integration approval.

## Pinned inputs and comparison

PR371: `9e39c396f4ca8f9abe3c9aabb090868ada17b53f`.
PR381: `3971c93a5705dc15f86ba56cc62118613e4b19db`.
GitHub PR listing during this probe confirms both remain open at these heads.

The endpoint diff strengthens three schemas, preserves the existing skill
protocol, and corrects the report template's reviewer IDs from a sequence to
a mapping. The evaluation schema's Phase R conditional at lines 222-242
requires a reason without counts when unexecuted; when executed, it requires
all five outcome counts and forbids the obsolete reason. The skill's JSON
synthesis example remains compatible with the unexecuted branch. Its later
instruction to update Phase R must be understood as replacing that object,
not retaining `not_ran_reason` when setting `ran` to true.

The committed test driver checks one incomplete executed object but does not
individually exercise all five required/forbidden counts. The additional
probe below closes that diagnostic evidence gap for the pinned schema only;
it is not yet a persistent CI regression test.

## Execution

Command: `rtk proxy node -e <inline read-only Ajv probe>` from the PR381
recovery checkout. All schema/skill inputs were obtained using `git show`
against the pinned PR381 commit; no checkout files were modified or extracted.
Ajv was loaded from existing `mcp/ci-mcp` dependencies with the committed
test driver's strict settings and `validateFormats: false`. No dependency
installation, external provider invocation, or protected-script execution.

The probe parsed the actual skill JSON example, substituted a concrete slug,
matching report path and ISO timestamp, and validated it. Copies were mutated
one field at a time. Full output (exit 0):

```text
ok: synthesis example conforms
ok: unexecuted forbids verified_count
ok: unexecuted forbids not_fixed_count
ok: unexecuted forbids partially_fixed_count
ok: unexecuted forbids claim_error_count
ok: unexecuted forbids new_issues_found
ok: unexecuted requires reason
ok: completed full counts
ok: completed requires verified_count
ok: completed requires not_fixed_count
ok: completed requires partially_fixed_count
ok: completed requires claim_error_count
ok: completed requires new_issues_found
ok: completed forbids stale reason
ok: empty branch rejected
ok: wrong report path rejected
ok: two reviewers required
SUMMARY 17 passed; 0 failed; fixed head 3971c93a5705dc15f86ba56cc62118613e4b19db
```

Not covered: timestamp-format enforcement, actual reviewer output production,
all cross-critique branches, full issue acceptance, native Windows, or the
combined integration candidate. No historical verdict is changed.

## Integration consequence

Preserve PR381's hardened Phase R schema and corrected report mapping when
reconciling PR371; reverting them is unnecessary to accommodate the actual
synthesis example. A future persistent regression should bind the skill
example and both lifecycle branches, including stale-reason rejection.

Windows failure mapping is already documented in
`pr371-mcp-failure-mapping-20260908.md`; do not duplicate the approved T002
repair or rerun unchanged historical heads to seek a favorable result.

Fresh issue #346 body inspection confirms a separate human decision is still
an acceptance requirement: plugin promotion, standalone continuation, or
retirement. Neither these 17 checks nor general merge authorization supplies
that decision or proves the required three-run evidence matrix.

No commit, push, merge, issue closure, task status update, or formal PASS.
