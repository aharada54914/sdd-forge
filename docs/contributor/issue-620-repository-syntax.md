# Issue 620: repository JSON / YAML syntax check

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
  Changed bytes, a moved copy, a repaired fixture or a missing record fail. No directory is skipped.
- Parser: `PyYAML==6.0.3` (`tests/repository-syntax-requirements.txt`), installed into a venv by the weekly workflow and the POSIX regression CI job, exported as `SDD_SYNTAX_PYTHON`.

Applied to the tracked inputs based on `07ed2e98`, the new checker passes with
9,322 JSON and 246 YAML files, six legacy BOM observations and two expected
negatives. The temporary readiness-probe workflow adds one YAML file. These
counts are not a permanent rule, and the checker was not present at the old HEAD.

## Limits

Syntax only: not schema, encoding or consumer compatibility. Local tests do not establish weekly recovery; a real authorized weekly run on the final HEAD with all five checks successful and both `improve` and the recovery finalizer successful is still required, and it also depends on the separate managed-model request prerequisite (`SDD_SELF_IMPROVEMENT_REQUEST`). Tests: `tests/repository-syntax.tests.py`, prompt contract in `tests/self-improvement-guard.tests.sh`.
