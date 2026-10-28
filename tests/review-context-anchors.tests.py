#!/usr/bin/env python3
"""Resolve named boundary claims to unique current source statements.

The table retains all 32 semantic checks from the former line-number citations,
with intervening code to prevent matching a predicate in an unrelated check.
Only blank/full-line comments and indentation are ignored; executable predicates
must still match. Runtime reservation tests remain in the calling shell suite.
"""
import argparse
from pathlib import Path
import re

SUBJECTS = {'validator': 'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh',
 'precheck': 'plugins/sdd-review-loop/scripts/lib/review-precheck-common.sh',
 'impl-review-precheck': 'plugins/sdd-review-loop/scripts/impl-review-precheck.sh'}

# name, source, exact non-comment statement span for the documented claim.
# Intervening statements bind repeated predicates to their actual enclosing check.
ANCHORS = (
    ('schema', 'validator', (
        '.schema == "review-context-invocation/v2" and',
    )),
    ('input-mode', 'validator', (
        '.input_mode == "file-manifest" and',
    )),
    ('fallback-mode', 'validator', (
        '.fallback_mode == "none" and',
    )),
    ('read-only', 'validator', (
        '.read_only == true and',
    )),
    ('feature', 'validator', (
        '(.feature | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$")) and',
    )),
    ('sequence-type', 'validator', (
        '(.sequence | type == "number" and floor == . and . >= 2) and',
    )),
    ('ledger-path', 'validator', (
        '(.identity_ledger_path == "reports/review-context/identity-ledger.json") and',
    )),
    ('ledger-hash-type', 'validator', (
        '(.identity_ledger_sha256 | type == "string" and test("^[0-9a-f]{64}$")) and',
    )),
    ('task-id', 'validator', (
        '(.task_id | type == "string" and test("^T-[0-9]{3}$")) and',
    )),
    ('gate-declaration-shape', 'validator', (
        '(if has("gate_report_declaration") then',
        '(.gate_report_declaration |',
        'type == "object" and',
        '((keys | sort) == ["path", "sha256"]) and',
    )),
    ('gate-declaration-binding', 'validator', (
        'fail PATH "sdd-evaluator gate-report declaration traverses a symbolic link: $gate_report_declaration_path"',
        'done',
        'gate_report_absolute="$repository_root/$gate_report_declaration_path"',
        '[[ -f "$gate_report_absolute" && ! -L "$gate_report_absolute" ]] ||',
        'fail PATH "sdd-evaluator gate-report declaration is missing or is not a regular file: $gate_report_declaration_path"',
        '[[ "$(sha256_file "$gate_report_absolute")" == "$gate_report_declaration_sha256" ]] ||',
    )),
    ('gate-output-authorization', 'validator', (
        'gate_report_output_is_declared() {',
        'local path=$1 expected_hash=$2',
        '[[ -n "$gate_report_declaration_path" ]] || return 1',
        '[[ "$path" != reports/quality-gate/* ]] || return 1',
        'evaluator_output_is_declared "$path" "$expected_hash" \\',
        '"$repository_root/$gate_report_declaration_path" \'## Post-Fix Artifacts\'',
    )),
    ('stage-role', 'validator', (
        'case "$stage:$role" in',
        'spec:spec-reviewer-a|spec:spec-reviewer-b|impl:impl-reviewer-a|impl:impl-reviewer-b|task:task-reviewer-a|task:task-reviewer-b|quality:sdd-evaluator|domain:domain-reviewer-a|domain:domain-reviewer-b) ;;',
        "*) fail CONTRACT 'stage and role are not an authorized invocation pair' ;;",
    )),
    ('ledger-before-reservation', 'validator', (
        '[[ "$actual_ledger_sha256" == "$bound_ledger_sha256" ]] ||',
    )),
    ('ledger-under-lock', 'validator', (
        '[[ "$(sha256_file "$ledger")" == "$bound_ledger_sha256" ]] ||',
    )),
    ('chain-position', 'validator', (
        '[[ "$sequence" -eq "$expected_sequence" && "$previous_record_sha256" == "$expected_previous" ]] ||',
    )),
    ('existing-record-hash', 'validator', (
        'canonical_record="$record_sequence|$record_stage|$record_role|$record_run|$record_session|$record_previous"',
    )),
    ('new-record-hash', 'validator', (
        'record_text="$sequence|$stage|$role|$run_id|$host_session_id|$previous_record_sha256"',
    )),
    ('implementation-task-binding', 'validator', (
        'if [[ "$stage:$role" == quality:sdd-evaluator ]]; then',
        'implementation_report_count=0',
        'while IFS= read -r candidate_report; do',
        'if [[ "$candidate_report" == "reports/implementation/$feature/$task_id.md" ]]; then',
        'implementation_report_path=$candidate_report',
        'implementation_report_count=$((implementation_report_count + 1))',
        'fi',
        'done < <(jq -r \'.allowed_input_manifest[].path\' "$manifest" | tr -d \'\\r\')',
        '[[ "$implementation_report_count" -eq 1 ]] ||',
        "fail PATH 'sdd-evaluator requires the current task implementation report'",
        '[[ $(sed -n \'/^- \\*\\*Scratch Root\\*\\*: /p\' "$repository_root/$implementation_report_path" |',
        "LC_ALL=C tr -d '\\11\\12\\15\\40-\\176\\200-\\377' | LC_ALL=C wc -c) -eq 0 ]] ||",
        "fail PATH 'implementation Scratch Root contains forbidden control bytes'",
        '[[ "$(read_implementation_report | sed -n \'1p\')" == "# Implementation Report: $task_id" ]] ||',
        "fail PATH 'sdd-evaluator implementation report heading does not match task ID'",
        'grep -Fxq -- "- Task ID: $task_id" <(read_implementation_report) ||',
        "fail PATH 'sdd-evaluator implementation report task field does not match task ID'",
    )),
    ('input-path-admission', 'validator', (
        'is_canonical_path "$path" ||',
        'fail PATH "$role contains a non-canonical repository-relative path: $path"',
        'is_forbidden_review_output "$path" &&',
        'fail PATH "$role contains a forbidden raw reviewer report: $path"',
        'if jq -e --arg p "$path" --arg h "$expected_hash" \\',
        '\'any(.[]; .path == $p and .sha256 == $h)\' <<< "$fixed_references" >/dev/null; then',
        ': # Only references authenticated against this fixed inventory are admitted.',
        'elif [[ "$stage" == impl && "$path" == docs/adr/* ]] && path_is_authorized "$stage" "$role" "$feature" "$path" "$expected_hash"; then',
        ': # Research-selected ADRs are separately bound by the conditional resolver.',
        'elif [[ "$stage" == impl && "$path" == docs/adr/* ]]; then',
        'if [[ "$adr_binding_verified" != true ]]; then',
        "verify_captured_adr_binding || fail CONTRACT 'ADR declaration and input binding disagree'",
        'fi',
        '[[ "$role" == impl-reviewer-a || "$role" == impl-reviewer-b ]] ||',
        "fail PATH 'ADR inputs require an implementation reviewer'",
        'jq -e --arg p "$path" --arg h "$expected_hash" \'any(.[]; .path == $p and .sha256 == $h)\' \\',
        '<<< "$verified_adr_inputs" >/dev/null || fail PATH \'ADR input is outside the verified declaration\'',
        'else',
        'path_is_authorized "$stage" "$role" "$feature" "$path" "$expected_hash" ||',
    )),
    ('input-hash-binding', 'validator', (
        'actual_hash=$(printf \'%s\' "$content_base64" | base64 -d | sha256_text) ||',
        "fail HASH 'implementation captured input hashing failed'",
        'else',
        'actual_hash=$(sha256_file "$candidate")',
    )),
    ('ledger-append', 'validator', (
        "'.records += [{",
    )),
    ('previous-round-summary', 'precheck', (
        'fail "persisted impl reviewer-a manifest is missing previous-round summary"',
    )),
    ('precheck-modes', 'impl-review-precheck', (
        '[[ -z "$MODE" || "$MODE" == "--verify-inputs" || "$MODE" == "--provenance-rereview" ]] ||',
    )),
)


def resolve(sources, document):
    names = [row[0] for row in ANCHORS]
    if len(names) != len(set(names)):
        raise ValueError('duplicate anchor names')
    citations = set(re.findall(r'`boundary:([a-z-]+)`', document))
    if citations != set(names):
        raise ValueError('document/table anchor mismatch')
    if re.search(r'`(?:[\w.-]+\.sh)?:\d+(?:-\d+)?`', document):
        raise ValueError('numeric source citation remains')
    if 'identity_ledger_sha256' not in document or 'do not re-verify' not in document:
        raise ValueError('document lost the ledger exemption')
    resolved = {}
    for name, subject, patterns in ANCHORS:
        code = [(number, line.strip()) for number, line in enumerate(sources[subject].splitlines(), 1)
                if line.strip() and not line.lstrip().startswith('#')]
        statements = [line for _, line in code]
        matches = [(code[start][0], code[start + len(patterns) - 1][0])
                   for start in range(len(code) - len(patterns) + 1)
                   if statements[start:start + len(patterns)] == list(patterns)]
        if len(matches) != 1:
            raise ValueError(f'{name}: expected one semantic location, found {len(matches)}')
        resolved[name] = matches[0]
    for before in ('ledger-before-reservation', 'ledger-under-lock'):
        if resolved[before][1] >= resolved['ledger-append'][0]:
            raise ValueError('ledger hash must be checked before append')
    return resolved


def controls(sources, document):
    original = resolve(sources, document)
    shifted = dict(sources)
    shifted['validator'] = '\n# harmless line shift\n' + sources['validator'].replace('\n', '\n# comment\n')
    moved = resolve(shifted, document)
    assert moved['ledger-append'][0] > original['ledger-append'][0]
    patterns = {name: statements for name, _, statements in ANCHORS}
    statement = patterns['read-only'][0]
    # Use exact current lines so indentation remains irrelevant.
    group_lines = sources['validator'].splitlines(keepends=True)
    start, end = original['gate-declaration-shape']
    group = ''.join(group_lines[start - 1:end])
    internal = next(line for line in group.splitlines(keepends=True) if '(keys | sort)' in line)
    mutants = [
        ('unbound research ADR', sources['validator'].replace(' && path_is_authorized "$stage" "$role" "$feature" "$path" "$expected_hash"; then', '; then', 1)),
        ('missing grouped predicate', sources['validator'].replace(group, group.replace(internal, ''), 1)),
        ('duplicate grouped anchor', sources['validator'].replace(group, group + group, 1)),
        ('missing statement', sources['validator'].replace(statement, '', 1)),
        ('duplicate statement', sources['validator'].replace(statement, statement + '\n' + statement, 1)),
        ('changed predicate', sources['validator'].replace(statement, statement.replace('true', 'false'), 1)),
        ('comment counterfeit', sources['validator'].replace(statement, '# ' + statement, 1)),
        ('append reordered', patterns['ledger-append'][0] + '\n' +
         sources['validator'].replace(patterns['ledger-append'][0], '', 1)),
    ]
    for label, value in mutants:
        try:
            resolve(dict(sources, validator=value), document)
        except ValueError:
            continue
        raise AssertionError(f'undetected anchor mutation: {label}')
    for label, changed in (
        ('missing reference', document.replace('`boundary:read-only`', 'read_only')),
        ('unknown reference', document + '\n`boundary:unknown`'),
    ):
        try:
            resolve(sources, changed)
        except ValueError:
            continue
        raise AssertionError(f'undetected document mutation: {label}')
    print('ok: comment shifts accepted; 10 semantic/reference mutations rejected')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument('--list', action='store_true', help='print resolved current source locations')
    args = parser.parse_args()
    sources = {name: (args.repo / path).read_text() for name, path in SUBJECTS.items()}
    document = (args.repo / 'plugins/sdd-review-loop/references/review-context-boundary.md').read_text()
    reviewer = (args.repo / 'plugins/sdd-review-loop/agents/impl-reviewer-a.md').read_text()
    if 'Issue #143' not in reviewer:
        raise ValueError('reviewer lost the documented Issue #143 carve-out')
    resolved = resolve(sources, document)
    if args.list:
        for name, subject, _ in ANCHORS:
            start, end = resolved[name]
            print(f'boundary:{name} {SUBJECTS[subject]}:{start}-{end}')
    else:
        controls(sources, document)
        print(f'ok: {len(resolved)} named anchors; original 32 semantic checks and enclosing statements verified')


if __name__ == '__main__':
    main()
