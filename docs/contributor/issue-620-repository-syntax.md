# Issue 620: repository JSON / YAML syntax check

## 2026-10-25 selected PR credential preflight

The workflow now checks the exact `SDD_SESSION_PR_TOKEN || github.token` credential
before native installation or a model invocation. The read-only helper
`.github/scripts/check-self-improvement-pr-access.py` lists at most one PR via the
existing `gh` client, with a 30-second timeout. Authentication/access errors,
timeouts and malformed responses fail the workflow early. Failure reporting uses
fixed categories and never includes the token or remote response body. The missing
PAT fallback and final audit-completion/recovery predicates are unchanged.

This catches credentials that cannot even read PRs; a successful read does **not**
prove PR write permission. It does not fix the repository token configuration or
establish production recovery. A read-only fine-grained token may pass this probe
and still fail the actual PR creation. Repository selection, expiry and required
Pull requests write permission must be corrected through the credential owner,
then an actual complete guarded run must succeed. No write probe or remote settings
change is performed by this helper.

Offline checks: `python3 tests/self-improvement-pr-access.tests.py` (10 tests)
and the existing `tests/self-improvement-guard.tests.sh` (71 assertions) passed.

The [failed weekly run](https://github.com/aharada54914/sdd-forge/actions/runs/39191099402)
reported `status=partial` and `json_yaml=false`; the other four checks and its
run/attempt/HEAD checks succeeded. That diagnostic identifies the failed check,
but does not reveal the original parser command or failing paths. Issue #619
reported six historical BOM records and two intentional invalid fixtures, which
the current input scan reproduces. The prompt previously named no parser command
or policy for these cases. Step 4 now names one deterministic command without
changing the completion predicate or historical evidence.

## Frozen CLI

```bash
"${SDD_SYNTAX_PYTHON:-python3}" -I -B .github/scripts/check-repository-syntax.py [--root DIR] [--path REL ...]
```

- `--root`: repository top level (default: the checkout containing the script). Must be a git top level.
- `--path`: repository-relative `.json` / `.yaml` / `.yml` file to add (untracked session additions); its current bytes are validated. The grammar is lexical and host-independent, checked before any filesystem access: `/`-separated segments, none empty, `.` or `..`, and no `\` or `:` anywhere. Absolute, drive (`C:/x`, `C:x`), UNC (`//server/share`, `\\server\share`), backslash, non-canonical, other-suffix or absent paths are usage errors.
- Exit `0` pass, `1` syntax failure or incomplete candidate coverage, `2` usage / git / missing-parser error (`dependency_missing`).
- stdout: one JSON object, schema `repository-syntax-check/v1`, with `result`, `counts` (`json`, `yaml`, `explicit`, `untracked_unchecked`), `complete_candidate_coverage`, `legacy_bom`, `expected_negative` and `failures` (`path` + fixed `category`). No file content or raw parser messages.

## Policy

- Inventory: `git ls-files -z --cached` (tracked and staged) with the three suffixes, read from current working-tree bytes, plus `--path`. No recursive filesystem walk. Other untracked (non-ignored) candidates are never read or named; they are only counted in `untracked_unchecked`. Any such candidate makes `complete_candidate_coverage` `false`, `result` `fail` and the exit code `1`: missing coverage is a failure, never a partial success. Audit from a clean checkout, or stage / `--path` every candidate.
- JSON: strict UTF-8, no BOM, no `NaN` / `Infinity`; never retried as YAML. YAML: strict UTF-8, `yaml.safe_load_all`; a leading UTF-8 BOM is legal YAML syntax and accepted.
- Failure categories: `invalid_json`, `invalid_yaml`, `invalid_utf8`, `bom` (JSON only), `missing`, `not_regular`, `symlink`, `unreadable`, `stale_exception`, `missing_exception`.
- Exceptions are exact path+SHA256 records in the script, and every record must be present:
  - six frozen legacy JSON records with one leading BOM, stripped in memory and reported in `legacy_bom`;
  - two intentional negative fixtures under `tests/fixtures/capability-resolver/resolve-project-context-block/` that must still fail with `invalid_json` / `invalid_utf8`, reported in `expected_negative`.
  Changed bytes, a moved copy, a repaired fixture or a missing record fail. No tracked directory is skipped.
- Runtime outputs vs candidates: the weekly managed prepare step writes run-local controls (`selection.json`, `controls.json`, `validation.json`, `claude-sdk-entry`) under `.sdd-self-improvement/<session>/` before the audit. They are runtime state, not repository inputs, so `.gitignore` ignores only the root directory (`/.sdd-self-improvement/`). Without this rule, prepare's own outputs were counted in `untracked_unchecked` and failed coverage. The rule is anchored: an unrelated untracked JSON, nested or similarly named directories (`docs/.sdd-self-improvement/`, `.sdd-self-improvement-notes/`, `sdd-self-improvement/`) and a force-added or tracked file under the runtime directory remain candidates and still fail when unvalidated or malformed. The checker, completion predicate and frozen exceptions are unchanged.
- Parser: `PyYAML==6.0.3` (`tests/repository-syntax-requirements.txt`), installed into a venv by the weekly workflow and the POSIX regression CI job, exported as `SDD_SYNTAX_PYTHON`.

Applied to the tracked inputs based on `07ed2e98`, the new checker passes with
9,322 JSON and 246 YAML files, six legacy BOM observations and two expected
negatives. The temporary readiness-probe workflow adds one YAML file. These
counts are not a permanent rule, and the checker was not present at the old HEAD.

## Limits

Syntax only: not schema, encoding or consumer compatibility. Local tests do not establish weekly recovery; a real authorized weekly run on the final HEAD with all five checks successful and both `improve` and the recovery finalizer successful is still required, and it also depends on the separate managed-model request prerequisite (`SDD_SELF_IMPROVEMENT_REQUEST`). Tests: `tests/repository-syntax.tests.py` (13 tests, three of them for the runtime ignore boundary), prompt contract in `tests/self-improvement-guard.tests.sh`.

The read-only [Actions readiness probe](https://github.com/aharada54914/sdd-forge/actions/runs/39812329518)
at `62ace211` confirmed that the request variable was unset and no request file
was available through it; the default registry was present. It printed only
booleans and invoked no model. This is a separate pre-audit blocker, not proof
of the original October 19 failure's cause. A configured path alone also cannot
establish fresh observation data or valid model selection. The temporary probe
workflow is removed after recording this result.


### Remaining managed-run prerequisites

At this branch, `contracts/model-policy.v1.json` maps three Claude aliases, but
all remain `candidate` with empty adoption lists. The selector requires
role-specific adoption even for a pin. The current GPT adoption does not cover
Claude or the `self-improvement` role. Requirements REQ-017 and REQ-019 in
`specs/ci-model-modernization/requirements.md` require representative-artifact
evaluation and human-reviewed adoption; successful CLI authentication is not
that evidence.

The workflow also needs a per-run observation producer. Its request is consumed
as supplied, and observations expire after 300 seconds. Committing a timestamped
request or merely setting the variable cannot make it reusable by a weekly job.
The existing discovery adapter supports Codex only; the design permits verified
configuration for Claude, with its limitations recorded. A real current
configuration inspection, source provenance and run scope must precede the
observation timestamp. Do not label static policy entries as discovered account
availability or restore a legacy launch to bypass managed selection.

To finish #620: provision the fresh input through that supported boundary, obtain
real Claude/self-improvement adoption evidence and its required human review,
then run the weekly workflow at the final revision and record all five checks
plus completion/finalizer success. This parser repair does not claim those
operational prerequisites or recovery are complete.
