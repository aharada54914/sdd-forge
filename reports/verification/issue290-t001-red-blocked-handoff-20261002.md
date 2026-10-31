# Issue #290 T-001 RED / protected-write handoff (2026-10-02)

Run ID: issue290-concept-t001-20261002-01 (local execution label only; no formal ledger reservation found)
Task Attempt Count: 1
Task state: In Progress (set by root; this implementer made no status change)

## Candidate and actual execution

- One fresh Claude Sonnet CLI run, session `0d8fce7c-75ef-403b-a8a9-43a4d4cfb8c0`, exec handle `41234`, exited 0 and wrote `/private/tmp/issue290-concept-t001-snapshot-20261002-01/reports/implementation/sdd-domain-concept-test/T-001-candidate.patch` (1087 lines). Input manifest validation returned `TASK_INPUT_OK` against source and read-only snapshot.
- Applied only the candidate test hunks to `tests/validate-approval-sidecar.tests.sh` and `tests/validate-approval-sidecar.tests.ps1`. The shell suite then exited 1 with 52 PASS and 22 FAIL. The 22 failures are new concept-test fixtures hitting the pre-existing two-value approval-sidecar schema enum (`SIDECAR_SCHEMA_VIOLATION`, exit 47). This is the expected test-first RED; no GREEN was observed.
- The attempted production hunk contained `contracts/concept-test.v1.schema.json`, `contracts/approval-sidecar.schema.json`, and `plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py`. `apply_patch` was refused before execution by the PreToolUse hook: `SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。` No production hunk was applied, no alternate tool/host was used, and no new model run was launched.

## Candidate audit and unresolved design

- The candidate is not T-001-complete: it omits all `concept-test.md` versus JSON agreement checks. Requirements `requirements.md:13` specifies sibling `concept-test.{md,json}` paths, so path location is resolvable. But the Markdown machine-readable form or an exact JSON-to-Markdown render contract is not specified. Requirements `requirements.md:46`, design `design.md:14,30`, and acceptance tests `acceptance-tests.md:61-84` require rejecting mismatch across feature, proposal, rationale, relation, input path/hash, and decision for all four classifications. Repository search found no existing `concept-test.md` or reusable strict Markdown/JSON renderer. A deterministic fixed renderer shared by T-001 validator and T-002 authoring is a possible minimal design decision, not an authorized assumption.
- Candidate validator order rehashes `inputs[].path` before verifying the sidecar HMAC. Thus an untrusted JSON document can cause reads of a caller-specified path before signature verification; this needs correction before any production use.
- Candidate selects JSON input only for the new sidecar schema, defaulting to YAML and retaining duplicate-ID checks for the two existing schemas. That compatibility rationale was inspected, but because the protected production hunk was refused, no new-schema GREEN or old-schema post-change regression was run.
- The candidate's `relation` and `inputs` JSON field spellings remain proposals pending the Markdown contract decision; the high-risk preflight is in `reports/implementation/sdd-domain-concept-test/T-001.md`.

No task status/verdict, protected file, production signature, commit, push, or PR was changed by this implementer. The two test-file diffs are intentionally left in RED for root disposition. The prior handshake challenge emit refusal remains in force and was not retried or rerouted.

## Human resolution — 2026-10-02

The owner answered: 「固定形式で生成・全項目照合する」. This resolves the
Markdown-format choice above: authoring generates a fixed Markdown representation
from the Concept Test JSON; validation uses the same rendering definition and
compares every field, including the complete input path/hash list. Free-form
Markdown must not become a second, partially checked decision source.

This resolution does not establish an implementation or a passing test. The
historical missing-format finding above is retained as history and is superseded
only as a design choice. Frozen reviewed documents, approvals, and verdicts remain
unchanged. Exact rendering, all-field mismatch regressions, and signature-before-
input-read ordering still need implementation and independent review. The actual
protected-write refusal remains a separate execution blocker; this decision does
not authorize routing around it.

## Minimal implementation contract — independent audit, 2026-10-02

Read-only auditor: `root/issue290_render_contract_audit`. This is a supplemental
code/design audit, not a formal gate verdict or identity reservation.

- Reuse one Python rendering function for T-001 validation and T-002 authoring.
  After JSON schema validation, render `# Concept Test\n\n`, followed by every
  line of `json.dumps(obj, ensure_ascii=False, sort_keys=True, indent=2,
  allow_nan=False)` indented by four spaces, and a final LF. The indented JSON
  block avoids a separate Markdown parser and table/fence escaping rules.
- Compare the complete sibling Markdown bytes with that rendering. Preserve
  ordered input entries; include every schema field, not a selected field map.
  Missing Markdown, additional prose, changed fields, and changed line endings
  must reject rather than silently normalize.
- On the new concept-test route, authenticate the sidecar before reading paths
  named by its content. Preserve the existing two schema routes and duplicate-ID
  checks. A bad HMAC paired with an instrumented input path must fail before that
  path is read.
- Cover the existing TEST-051–078 mismatch requirements, all four classifications,
  and a second input entry changed, omitted, or reordered. Schema-invalid input
  and unknown keys must remain rejected. Reuse existing test drivers.

Evidence inspected by the auditor: `requirements.md:13,46`, `design.md:14,30,40`,
`acceptance-tests.md:51-84`, and the existing validator at lines 909–922, plus the
candidate and T-001 preflight. These references are local inspection pointers,
not immutable evidence hashes. No source application, GREEN, formal review,
commit, push, or merge follows from this audit. The protected-write refusal above
remains unresolved.
