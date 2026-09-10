#!/usr/bin/env bash
# RT-20260908-004: real admission checks; no product functions are mocked.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${1:-}" == --downstream-only ]]; then
  # Original task-stage entry points, not patched copies or extracted helpers.
  python3 - "$ROOT" <<'PY'
import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

root = Path(sys.argv[1])
feature = 'adr-downstream-fixture-' + uuid.uuid4().hex
spec = root / 'specs' / feature
reports = {s: root / f'reports/{s}-review' / feature for s in ('spec', 'impl', 'task')}
registry = root / 'specs/workflow-state-registry.json'
original = registry.read_bytes()
data = json.loads(original)
data['entries'].append(dict(feature=feature, profile='lite'))
fixture_registry = (json.dumps(data, indent=2) + '\n').encode()
created = []
passed = failed = inconclusive = 0
digest = lambda b: hashlib.sha256(b).hexdigest()
sha = lambda p: digest(p.read_bytes())
compact = lambda obj: json.dumps(obj, separators=(',', ':'))
def write(path, obj):
    path.write_text(json.dumps(obj) + '\n', encoding='utf-8')
def pins(paths):
    return [dict(path=str(p.relative_to(root)), sha256=sha(p)) for p in paths]
try:
    spec.mkdir()
    created.append(spec)
    for directory in reports.values():
        directory.mkdir()
        created.append(directory)
    registry.write_bytes(fixture_registry)
    (spec / 'requirements.md').write_text('Spec-Review-Status: Passed\n')
    (spec / 'acceptance-tests.md').write_text('# Acceptance\n')
    (spec / 'tasks.md').write_text('## T-001 Fixture\nRisk: low\nRisk Rationale: fixture\n'
                                 'Required Workflow: test-after\n### Blockers\nNone\n')
    adr = 'docs/adr/0033-panelist-supervisor-process-ownership.md'
    if not (root / adr).is_file(): raise RuntimeError('existing ADR input missing')
    design = 'Impl-Review-Status: Passed\nDecision: `' + adr + '`\n'
    (spec / 'design.md').write_text(design)
    layer_names = ('frontend-spec.md', 'infra-spec.md', 'security-spec.md', 'ux-spec.md')
    for name in layer_names: (spec / name).write_text('# Fixture layer\n')
    for stage in ('spec', 'impl'):
        (reports[stage] / 'attempt-1/round-1').mkdir(parents=True)
    commands = [('bash', ['bash', str(root / 'plugins/sdd-review-loop/scripts/task-review-precheck.sh'), feature, '1', '1']),
                ('pwsh', ['pwsh', '-NoProfile', '-File', str(root / 'plugins/sdd-review-loop/scripts/task-review-precheck.ps1'), feature, '1', '1'])]
    negative_cases = ('stale-adr-hash', 'wrong-input-hash', 'missing-contract-extension',
                      'missing-precheck-extension', 'missing-reviewer-adr', 'layer-pin-mismatch',
                      'output-adr-mismatch', 'output-precheck-mismatch', 'output-design-mismatch',
                      'output-identity-mismatch', 'output-multiple-json-empty-b')
    for runtime, command in commands:
        extended_baseline = False
        layer_baseline = False
        for case in ('legacy', 'extended', 'lifecycle-normalized', 'absolute-core', 'layer-bound') + negative_cases:
            destination = reports['task'] / 'attempt-1'
            if destination.exists(): shutil.rmtree(destination)
            for stage in ('spec', 'impl'):
                directory = reports[stage] / 'attempt-1/round-1'
                precheck = directory / 'precheck-result.json'
                summary = directory / 'integrated-summary.json'
                record = {}
                extended = stage == 'impl' and case != 'legacy'
                if extended:
                    dh = digest(design.replace('Passed', 'Pending', 1).encode()) if case == 'lifecycle-normalized' else sha(spec / 'design.md')
                    entries = [dict(path=adr, sha256=sha(root / adr))]
                    if case == 'stale-adr-hash': entries[0]['sha256'] = '0' * 64
                    record = dict(schema='impl-review-precheck/v1', feature=feature, attempt=1, round=1,
                                  design_sha256=dh, requirements_sha256=sha(spec / 'requirements.md'),
                                  acceptance_sha256=sha(spec / 'acceptance-tests.md'), layer_sha256={}, adr_inputs=entries)
                    if case in ('layer-bound', 'layer-pin-mismatch'):
                        record['layer_sha256'] = {name: sha(spec / name) for name in layer_names}
                        if case == 'layer-pin-mismatch': record['layer_sha256']['security-spec.md'] = '0' * 64
                    material = [dh, record['requirements_sha256'], record['acceptance_sha256']]
                    if record['layer_sha256']: material.append(compact(record['layer_sha256']))
                    record['input_sha256'] = digest(':'.join(material + ['adr_inputs/v1', compact(entries)]).encode())
                    if case == 'wrong-input-hash': record['input_sha256'] = '0' * 64
                write(precheck, record)
                if extended and case == 'missing-precheck-extension':
                    without_extension = copy.deepcopy(record)
                    without_extension.pop('adr_inputs')
                    write(precheck, without_extension)
                write(summary, {})
                calibration = 'spec-review-calibration.md' if stage == 'spec' else 'reviewer-calibration.md'
                manifest = pins([spec / 'requirements.md', spec / 'acceptance-tests.md',
                    root / 'plugins/sdd-review-loop/references' / calibration, precheck])
                if stage == 'impl':
                    manifest += [dict(path=f'specs/{feature}/design.md', sha256=record['design_sha256'] if extended else sha(spec / 'design.md'))]
                if extended: manifest += copy.deepcopy(entries)
                if extended and case in ('layer-bound', 'layer-pin-mismatch'):
                    manifest += pins([spec / name for name in layer_names])
                reviewers = [dict(role=f'{stage}-reviewer-{role}', run_id=f'fixture-{stage}-{role}',
                    host_session_id=f'fixture-session-{role}', allowed_input_manifest=copy.deepcopy(manifest)) for role in ('a', 'b')]
                reviewers[1]['allowed_input_manifest'] += pins([summary])
                if extended and case == 'absolute-core':
                    for reviewer in reviewers:
                        for entry in reviewer['allowed_input_manifest']:
                            if not entry['path'].startswith('docs/adr/'):
                                entry['path'] = str(root / entry['path'])
                contract = dict(schema=f'{stage}-review-contract/v1', stage=stage, feature=feature,
                    attempt=1, round=1, run_id=f'fixture-{stage}', verdict='PASS', reviewers=reviewers)
                if extended:
                    contract.update({key: copy.deepcopy(record[key]) for key in
                        ('design_sha256', 'requirements_sha256', 'acceptance_sha256', 'layer_sha256', 'adr_inputs')})
                    if case == 'missing-contract-extension': contract.pop('adr_inputs')
                    if case == 'missing-reviewer-adr':
                        reviewers[1]['allowed_input_manifest'] = [entry for entry in
                            reviewers[1]['allowed_input_manifest'] if entry['path'] != adr]
                write(directory / f'{stage}-review-contract.json', contract)
                if extended:
                    for role, reviewer in zip(('a', 'b'), reviewers):
                        review_output = dict(copy.deepcopy(reviewer), schema=f'impl-reviewer-{role}/v1', stage='impl')
                        if role == 'b':
                            targets = {'output-adr-mismatch': adr,
                                       'output-precheck-mismatch': str(precheck.relative_to(root)),
                                       'output-design-mismatch': f'specs/{feature}/design.md'}
                            for entry in review_output['allowed_input_manifest']:
                                if entry['path'] == targets.get(case): entry['sha256'] = '0' * 64
                            if case == 'output-identity-mismatch': review_output['run_id'] = 'wrong-run'
                        write(directory / f'reviewer-{role}.json', review_output)
                    if case == 'output-multiple-json-empty-b':
                        output_a = directory / 'reviewer-a.json'
                        output_b = directory / 'reviewer-b.json'
                        output_a.write_text(output_a.read_text() + output_b.read_text())
                        output_b.write_text('')
                verdict = dict(schema='integrated-verdict/v1', stage=stage, feature=feature,
                               attempt=1, round=1, run_id=f'fixture-{stage}', verdict='PASS')
                if stage == 'spec':
                    verdict.update(schema='spec-review-integrated-verdict/v1', reviewer_a_run_id='fixture-spec-a',
                        reviewer_b_run_id='fixture-spec-b', reviewer_a_host_session_id='fixture-session-a',
                        reviewer_b_host_session_id='fixture-session-b')
                write(directory / 'integrated-verdict.json', verdict)
            result = subprocess.run(command, cwd=root, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=60)
            output = reports['task'] / 'attempt-1/round-1/precheck-result.json'
            if case in negative_cases:
                # A rejecting positive baseline cannot prove mutation rejection.
                baseline = layer_baseline if case == 'layer-pin-mismatch' else extended_baseline
                ok = baseline and result.returncode != 0 and not output.exists()
                if not baseline:
                    inconclusive += 1
                    print(f'inconclusive: {runtime} downstream {case} exit={result.returncode}; matching positive baseline failed', flush=True)
                else:
                    passed += int(ok)
                    failed += int(not ok)
                    print(f'{"ok" if ok else "not ok"}: {runtime} downstream {case} exit={result.returncode}', flush=True)
                if not ok: print(result.stdout, flush=True)
                continue
            ok = result.returncode == 0 and output.is_file()
            if ok:
                emitted = json.loads(output.read_text())
                ok = emitted.get('schema') == 'task-review-precheck/v1' and emitted.get('feature') == feature
            if case == 'extended': extended_baseline = ok
            if case == 'layer-bound': layer_baseline = ok
            passed += int(ok)
            failed += int(not ok)
            print(f'{"ok" if ok else "not ok"}: {runtime} downstream {case} exit={result.returncode}', flush=True)
            if not ok: print(result.stdout, flush=True)
finally:
    if registry.read_bytes() != fixture_registry:
        raise RuntimeError('registry changed outside fixture; retained directories, no overwrite')
    registry.write_bytes(original)
    for directory in reversed(created): shutil.rmtree(directory)
print(f'ADR downstream: passed={passed} failed={failed} inconclusive={inconclusive}', flush=True)
sys.exit(1 if failed or inconclusive else 0)
PY
  exit $?
fi
if [[ "${1:-}" == --generation-only ]]; then
  # Original entry points, synthetic lite feature: isolate generation/history
  # from full-profile workflow provenance. No existing review is rewritten.
  python3 - "$ROOT" <<'PY'
import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

root = Path(sys.argv[1])
feature = 'adr-generation-fixture-' + uuid.uuid4().hex
spec = root / 'specs' / feature
sr = root / 'reports/spec-review' / feature
ir = root / 'reports/impl-review' / feature
registry = root / 'specs/workflow-state-registry.json'
original_registry = registry.read_bytes()
registry_data = json.loads(original_registry)
registry_data['entries'].append(dict(feature=feature, profile='lite'))
fixture_registry = (json.dumps(registry_data, indent=2) + '\n').encode()
created = []
passed = failed = 0
digest = lambda data: hashlib.sha256(data).hexdigest()
sha = lambda path: digest(path.read_bytes())
write = lambda path, data: path.write_text(json.dumps(data), encoding='utf-8')
try:
    for directory in (spec, sr, ir):
        directory.mkdir()
        created.append(directory)
    registry.write_bytes(fixture_registry)
    (spec / 'requirements.md').write_text('Spec-Review-Status: Passed\n')
    (spec / 'acceptance-tests.md').write_text('# Acceptance\n')
    adr = 'docs/adr/0033-panelist-supervisor-process-ownership.md'
    if not (root / adr).is_file(): raise RuntimeError('existing ADR input missing')
    (spec / 'design.md').write_text('Impl-Review-Status: Pending\nDecision: `' + adr + '`\n')
    layer_names = ('frontend-spec.md', 'infra-spec.md', 'security-spec.md', 'ux-spec.md')
    for name in layer_names: (spec / name).write_text('# Fixture layer\n')
    s1 = sr / 'attempt-1/round-1'
    i1 = ir / 'attempt-1/round-1'
    i2 = ir / 'attempt-1/round-2'
    s1.mkdir(parents=True)
    i1.mkdir(parents=True)
    for name in ('precheck-result.json', 'integrated-summary.json'): write(s1 / name, {})
    pins = lambda paths: [dict(path=p, sha256=sha(root / p)) for p in paths]
    spec_shared = pins([
        f'specs/{feature}/requirements.md', f'specs/{feature}/acceptance-tests.md',
        'plugins/sdd-review-loop/references/spec-review-calibration.md',
        str((s1 / 'precheck-result.json').relative_to(root))])
    spec_reviewers = [dict(role='spec-reviewer-' + role, run_id='fixture-spec-' + role,
                          host_session_id='fixture-session-' + role,
                          allowed_input_manifest=copy.deepcopy(spec_shared)) for role in ('a', 'b')]
    spec_reviewers[1]['allowed_input_manifest'] += pins([str((s1 / 'integrated-summary.json').relative_to(root))])
    write(s1 / 'spec-review-contract.json', dict(schema='spec-review-contract/v1', stage='spec',
          feature=feature, attempt=1, round=1, run_id='fixture-spec', verdict='PASS', reviewers=spec_reviewers))
    write(s1 / 'integrated-verdict.json', dict(schema='spec-review-integrated-verdict/v1', stage='spec',
          feature=feature, attempt=1, round=1, verdict='PASS', reviewer_a_run_id='fixture-spec-a',
          reviewer_b_run_id='fixture-spec-b', reviewer_a_host_session_id='fixture-session-a',
          reviewer_b_host_session_id='fixture-session-b'))
    commands = [('bash', ['bash', str(root / 'plugins/sdd-review-loop/scripts/impl-review-precheck.sh'), feature, '1', '2']),
                ('pwsh', ['pwsh', '-NoProfile', '-File', str(root / 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1'), feature, '1', '2'])]
    for runtime, command in commands:
        baseline = False
        cases = [('design-change', None, None), ('adr-only-change', None, None), ('unchanged', None, None)]
        cases += [(name, None, None) for name in ('legacy-design-change', 'legacy-unchanged',
                  'missing-contract-extension', 'missing-precheck-extension', 'null-extension')]
        for source in ('reservation', 'output'):
            for document in ('requirements.md', 'acceptance-tests.md', 'security-spec.md'):
                cases.append(('mismatch', source, document))
        for case, source, document in cases:
            if i2.exists(): shutil.rmtree(i2)
            legacy = case.startswith('legacy-')
            dh = sha(spec / 'design.md') if case in ('adr-only-change', 'unchanged', 'legacy-unchanged') else '2' * 64
            entries = [dict(path=adr, sha256=sha(root / adr) if case == 'unchanged' else '1' * 64)]
            layers = {name: sha(spec / name) for name in layer_names}
            record = dict(schema='impl-review-precheck/v1', feature=feature, attempt=1, round=1,
                          design_sha256=dh, requirements_sha256=sha(spec / 'requirements.md'),
                          acceptance_sha256=sha(spec / 'acceptance-tests.md'), layer_sha256=layers, adr_inputs=entries)
            material = ':'.join([dh, record['requirements_sha256'], record['acceptance_sha256'],
                                 json.dumps(layers, separators=(',', ':')), 'adr_inputs/v1',
                                 json.dumps(entries, separators=(',', ':'))])
            record['input_sha256'] = digest(material.encode())
            if legacy:
                entries = []
                record.pop('adr_inputs')
                record['input_sha256'] = digest(':'.join([dh, record['requirements_sha256'],
                    record['acceptance_sha256'], json.dumps(layers, separators=(',', ':'))]).encode())
            elif case == 'missing-precheck-extension': record.pop('adr_inputs')
            elif case == 'null-extension': record['adr_inputs'] = None
            write(i1 / 'precheck-result.json', record)
            manifest = pins([f'specs/{feature}/requirements.md', f'specs/{feature}/acceptance-tests.md',
                             str((i1 / 'precheck-result.json').relative_to(root))] +
                            [f'specs/{feature}/{name}' for name in layer_names])
            manifest += [dict(path=f'specs/{feature}/design.md', sha256=dh)] + entries
            reviewers = []
            for role in ('a', 'b'):
                reservation = dict(role='impl-reviewer-' + role, run_id='fixture-impl-' + role,
                                   host_session_id='fixture-impl-session-' + role,
                                   allowed_input_manifest=copy.deepcopy(manifest))
                output = dict(schema='impl-reviewer-' + role + '/v1', stage='impl', **copy.deepcopy(reservation))
                if role == 'b' and case == 'mismatch':
                    target = reservation if source == 'reservation' else output
                    for entry in target['allowed_input_manifest']:
                        if entry['path'] == f'specs/{feature}/{document}': entry['sha256'] = '3' * 64
                reviewers.append(reservation)
                write(i1 / ('reviewer-' + role + '.json'), output)
            contract = dict(record, schema='impl-review-contract/v1', stage='impl', verdict='NEEDS_WORK', reviewers=reviewers)
            if case == 'missing-contract-extension': contract.pop('adr_inputs')
            elif case == 'missing-precheck-extension': contract['adr_inputs'] = entries
            write(i1 / 'impl-review-contract.json', contract)
            result = subprocess.run(command, cwd=root, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=90)
            if case in ('design-change', 'adr-only-change', 'legacy-design-change'):
                good = result.returncode == 0 and (i2 / 'precheck-result.json').is_file()
                if case == 'design-change': baseline = good
            elif case in ('unchanged', 'legacy-unchanged'):
                good = baseline and result.returncode != 0 and 'unchanged' in result.stdout and not i2.exists()
            else:
                binding_diagnostic = ('ADR' in result.stdout or 'reviewer-a and reviewer-b pinned different' in result.stdout)
                good = baseline and result.returncode != 0 and binding_diagnostic and not i2.exists()
            passed += int(good)
            failed += int(not good)
            print(('ok' if good else 'not ok') + ': ' + runtime + ' generation ' +
                  '/'.join(x for x in (case, source, document) if x) +
                  ' exit=' + str(result.returncode) + ' baseline=' + str(baseline), flush=True)
            if not good: print(result.stdout, flush=True)
            if case == 'design-change':
                # Opening is a separate baseline from emitting the extension.
                # Missing emission must fail without hiding the history cases.
                emitted = json.loads((i2 / 'precheck-result.json').read_text()) if good else {}
                current_adrs = [dict(path=adr, sha256=sha(root / adr))]
                current_hashes = [sha(spec / name) for name in
                                  ('design.md', 'requirements.md', 'acceptance-tests.md')]
                material = ':'.join(current_hashes) + ':adr_inputs/v1:' + json.dumps(current_adrs, separators=(',', ':'))
                emission_ok = (good and emitted.get('adr_inputs') == current_adrs and
                               emitted.get('input_sha256') == digest(material.encode()) and
                               emitted.get('layer_sha256') == {})
                passed += int(emission_ok)
                failed += int(not emission_ok)
                print(('ok' if emission_ok else 'not ok') + ': ' + runtime +
                      ' generation emitted ADR set and aggregate hash', flush=True)
finally:
    # Do not overwrite a concurrent user's registry change with a stale backup.
    if registry.read_bytes() == fixture_registry:
        registry.write_bytes(original_registry)
    elif registry.read_bytes() != original_registry:
        raise RuntimeError('registry changed concurrently; fixture retained for inspection: ' + feature)
    for directory in reversed(created): shutil.rmtree(directory)
print('ADR generation: passed=' + str(passed) + ' failed=' + str(failed))
sys.exit(1 if failed else 0)
PY
  exit $?
fi
if [[ "${1:-}" == --precheck-only ]]; then
  # Real original consumers; only synthetic input data is created.
  python3 - "$ROOT" <<'PY'
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

root = Path(sys.argv[1])
feature = 'adr-precheck-fixture-' + uuid.uuid4().hex
spec = root / 'specs' / feature
reports = root / 'reports/impl-review' / feature
adr = 'docs/adr/0033-panelist-supervisor-process-ownership.md'
digest = lambda data: hashlib.sha256(data).hexdigest()
if not (root / adr).is_file():
    raise SystemExit('required existing ADR fixture input is missing')
spec.mkdir()
created_reports = False
failed = 0
passed = 0
try:
    reports.mkdir()
    created_reports = True
    stage = reports / 'attempt-1/round-1'
    stage.mkdir(parents=True)
    (spec / 'design.md').write_text('Decision: `' + adr + '`\n')
    (spec / 'requirements.md').write_text('# Requirements\n')
    (spec / 'acceptance-tests.md').write_text('# Acceptance\n')
    hashes = [digest((spec / name).read_bytes()) for name in
              ('design.md', 'requirements.md', 'acceptance-tests.md')]
    entries = [{'path': adr, 'sha256': digest((root / adr).read_bytes())}]
    compact = json.dumps(entries, separators=(',', ':'))
    record = dict(schema='impl-review-precheck/v1', feature=feature,
                  attempt=1, round=1, design_sha256=hashes[0],
                  requirements_sha256=hashes[1], acceptance_sha256=hashes[2],
                  layer_sha256={}, adr_inputs=entries,
                  input_sha256=digest((':'.join(hashes) + ':adr_inputs/v1:' + compact).encode()))
    commands = [('bash', ['bash', str(root / 'plugins/sdd-review-loop/scripts/impl-review-precheck.sh'), feature, '1', '1', '--verify-inputs']),
                ('pwsh', ['pwsh', '-NoProfile', '-File', str(root / 'plugins/sdd-review-loop/scripts/impl-review-precheck.ps1'), feature, '1', '1', '-VerifyInputs'])]
    for runtime, command in commands:
        baseline = False
        for case in ('bound', 'wrong-adr-hash', 'missing-adr-hash', 'null-adrs', 'wrong-input-hash'):
            data = json.loads(json.dumps(record))
            if case == 'wrong-adr-hash': data['adr_inputs'][0]['sha256'] = '0' * 64
            if case == 'missing-adr-hash': del data['adr_inputs'][0]['sha256']
            if case == 'null-adrs': data['adr_inputs'] = None
            if case == 'wrong-input-hash': data['input_sha256'] = '0' * 64
            (stage / 'precheck-result.json').write_text(json.dumps(data))
            result = subprocess.run(command, cwd=root, text=True, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, timeout=60)
            if case == 'bound':
                good = result.returncode == 0 and 'inputs verified for reviewer invocation.' in result.stdout
                baseline = good
            else:
                good = baseline and result.returncode != 0 and 'ADR' in result.stdout
            passed += int(good)
            failed += int(not good)
            print(('ok' if good else 'not ok') + ': ' + runtime + ' precheck ' + case +
                  ' exit=' + str(result.returncode), flush=True)
            if not good: print(result.stdout, flush=True)
finally:
    shutil.rmtree(spec)
    if created_reports: shutil.rmtree(reports)
print('ADR precheck: passed=' + str(passed) + ' failed=' + str(failed))
sys.exit(1 if failed else 0)
PY
  exit $?
fi
# Ordinary fixtures need a canonical parent; malformed roots are made below.
ADR_TMP_PARENT="$(cd "${TMPDIR:-/tmp}" && pwd -P)"
ADR_TMP="$(mktemp -d "${ADR_TMP_PARENT%/}/sdd-adr-inputs.XXXXXX")"
trap 'rm -rf -- "$ADR_TMP"' EXIT
sha() { shasum -a 256 "$1" | awk '{print $1}'; }
passed=0
failed=0

fixture() {
  local dir=$1 role=$2 mode=$3
  local design=specs/adr-fixture/design.md
  local precheck=reports/impl-review/adr-fixture/attempt-1/round-1/precheck-result.json
  mkdir -p "$dir/specs/adr-fixture" "$dir/docs/adr" \
    "$dir/reports/review-context" "$(dirname "$dir/$precheck")"
  printf '# Design\n' > "$dir/$design"
  if [[ "$mode" != legacy && "$mode" != zero-bound && "$mode" != multi-precheck-* ]]; then
    printf 'Decision: `docs/adr/0001-fixture.md`\n' >> "$dir/$design"
  fi
  # One input table feeds both actual runtime validators. The expected set is
  # specified here, not derived by a second implementation of the lexer.
  case "$mode" in
    path-link-*|path-root-*|path-hardlink-*|path-case-*|json-duplicate-root|json-duplicate-escaped|json-duplicate-nested|json-distinct-nested|json-invalid-utf8|json-bom|json-root-array|json-root-nested-array)
      printf '# Design\n' > "$dir/$design" ;;
    design-invalid-utf8)
      printf '# Design\nInvalid byte: \377\n' > "$dir/$design" ;;
    lex-crlf)
      printf '# Design\r\nDecision: `docs/adr/0001-fixture.md`\r\n' > "$dir/$design" ;;
    lex-repeated)
      printf 'Again: `docs/adr/0001-fixture.md`\n' >> "$dir/$design" ;;
    lex-fence-empty|lex-fence-injected)
      printf '# Design\n```text\n`docs/adr/0001-fixture.md`\n```\n' > "$dir/$design" ;;
    lex-tilde-empty|lex-tilde-injected)
      printf '# Design\n~~~text\n`docs/adr/0001-fixture.md`\n~~~\n' > "$dir/$design" ;;
    lex-long-span-empty|lex-long-span-injected)
      printf '# Design\n``outer `docs/adr/0001-fixture.md` outer``\n' > "$dir/$design" ;;
    lex-escaped-empty|lex-escaped-injected)
      printf '%s\n' '# Design' '\`docs/adr/0001-fixture.md\`' > "$dir/$design" ;;
    lex-indent-empty|lex-indent-injected)
      printf '# Design\n    `docs/adr/0001-fixture.md`\n' > "$dir/$design" ;;
    lex-even-escape)
      printf '%s\n' '# Design' '\\`docs/adr/0001-fixture.md`' > "$dir/$design" ;;
    lex-three-spaces)
      printf '# Design\n   `docs/adr/0001-fixture.md`\n' > "$dir/$design" ;;
    lex-fence-closed)
      printf '# Design\n   ~~~~text\nexample\n   ~~~~~ \t\n`docs/adr/0001-fixture.md`\n' > "$dir/$design" ;;
    lex-tab-empty|lex-tab-injected)
      printf '# Design\n\t`docs/adr/0001-fixture.md`\n' > "$dir/$design" ;;
    lex-unclosed-empty|lex-unclosed-injected)
      printf '# Design\n``unclosed `docs/adr/0001-fixture.md`\n' > "$dir/$design" ;;
    lex-suffix-empty|lex-suffix-injected)
      printf '# Design\n`docs/adr/0001-fixture.md.extra`\n' > "$dir/$design" ;;
    lex-short-close-empty|lex-short-close-injected)
      printf '# Design\n````text\n```\n`docs/adr/0001-fixture.md`\n' > "$dir/$design" ;;
    lex-trailing-close-empty|lex-trailing-close-injected)
      printf '# Design\n~~~text\n~~~still-fenced\n`docs/adr/0001-fixture.md`\n' > "$dir/$design" ;;
  esac
  printf '# Fixture ADR\n' > "$dir/docs/adr/0001-fixture.md"
  local genesis dh ah lh
  genesis=$(printf '%s' '1|spec|spec-reviewer-a|adr-genesis|adr-genesis-session|' | shasum -a 256 | awk '{print $1}')
  jq -n --arg h "$genesis" '{schema:"review-identity-ledger/v1",records:[{
    sequence:1,stage:"spec",role:"spec-reviewer-a",run_id:"adr-genesis",
    host_session_id:"adr-genesis-session",previous_record_sha256:"",record_sha256:$h
  }]}' > "$dir/reports/review-context/identity-ledger.json"
  dh=$(sha "$dir/$design")
  ah=$(sha "$dir/docs/adr/0001-fixture.md")
  # Pin regular bytes first; never hash or open a FIFO to build a fixture.
  case "$mode" in
    fs-fifo|fs-directory|fs-symlink|fs-missing)
      mv "$dir/docs/adr/0001-fixture.md" "$dir/original-adr.md"
      case "$mode" in
        fs-fifo) mkfifo "$dir/docs/adr/0001-fixture.md" ;;
        fs-directory) mkdir "$dir/docs/adr/0001-fixture.md" ;;
        fs-symlink) ln -s ../../original-adr.md "$dir/docs/adr/0001-fixture.md" ;;
      esac ;;
  esac
  jq -n --arg dh "$dh" --arg ah "$ah" --arg mode "$mode" '{
    schema:"impl-review-precheck/v1",feature:"adr-fixture",attempt:1,round:1,
    design_sha256:$dh
  } + (if ($mode == "legacy" or $mode == "legacy-declared" or $mode == "legacy-injected" or ($mode | startswith("multi-precheck-"))) then {} else {
    adr_inputs:[{path:"docs/adr/0001-fixture.md",sha256:$ah}]
  } end)' > "$dir/$precheck"
  # Mutation cases omit invocation ADR entries deliberately: a validator must
  # validate the pinned precheck even when no ADR reaches its per-entry loop.
  local mutation='.'
  case "$mode" in
    path-link-root-legacy) mutation='del(.adr_inputs)' ;;
    path-link-*|path-root-*|path-hardlink-*|path-case-*|zero-bound|json-duplicate-*|json-distinct-nested|json-invalid-utf8|json-bom|design-invalid-utf8|json-root-array|json-root-nested-array) mutation='.adr_inputs = []' ;;
    null-set) mutation='.adr_inputs = null' ;;
    object-set) mutation='.adr_inputs = {}' ;;
    keys-hidden) mutation='.Keys = []' ;;
    keys-lower-hidden) mutation='.keys = []' ;;
    adr-keys-spoof) mutation='.adr_inputs[0].Keys = ["path", "sha256"]' ;;
    missing-hash) mutation='del(.adr_inputs[0].sha256)' ;;
    extra-key) mutation='.adr_inputs[0].unexpected = true' ;;
    duplicate-member) mutation='.adr_inputs += .adr_inputs' ;;
    invalid-hash) mutation='.adr_inputs[0].sha256 = "not-a-sha256"' ;;
    empty-declared-set) mutation='.adr_inputs = []' ;;
    wrong-feature) mutation='.feature = "another-feature"' ;;
    wrong-round) mutation='.round = 2' ;;
    lex-*-empty) mutation='.adr_inputs = []' ;;
  esac
  jq "$mutation" "$dir/$precheck" > "$dir/precheck-mutated.json"
  mv "$dir/precheck-mutated.json" "$dir/$precheck"
  if [[ "$mode" == path-link-root-legacy ]]; then
    jq -e 'has("adr_inputs") | not' "$dir/$precheck" >/dev/null
  fi
  # Pin the malformed stream itself, so rejection cannot be a stale-hash result.
  case "$mode" in
    json-root-array|json-root-nested-array)
      if [[ "$mode" == json-root-array ]]; then
        jq '[.]' "$dir/$precheck" > "$dir/precheck-mutated.json"
      else
        jq '[[.]]' "$dir/$precheck" > "$dir/precheck-mutated.json"
      fi
      mv "$dir/precheck-mutated.json" "$dir/$precheck"
      jq -e 'type == "array" and length == 1' "$dir/$precheck" >/dev/null
      ;;
    json-invalid-utf8|json-bom)
      # Keep valid structure and zero ADRs; an unrelated allowlist rejection
      # must not hide replacement-decoding of a raw invalid byte.
      if [[ "$mode" == json-invalid-utf8 ]]; then
        printf '{"diagnostic":"\377",' > "$dir/precheck-mutated.json"
        jq -jr 'tojson | ltrimstr("{")' "$dir/$precheck" >> "$dir/precheck-mutated.json"
      else
        printf '\357\273\277' > "$dir/precheck-mutated.json"
        cat "$dir/$precheck" >> "$dir/precheck-mutated.json"
      fi
      mv "$dir/precheck-mutated.json" "$dir/$precheck"
      ;;
    json-duplicate-root|json-duplicate-escaped|json-duplicate-nested|json-distinct-nested)
      # Construct raw member syntax: ordinary object serialization would erase
      # the duplicate before the actual validator can observe it.
      local prefix
      case "$mode" in
        json-duplicate-root) prefix='{"adr_inputs":null,' ;;
        json-duplicate-escaped) prefix='{"adr_\u0069nputs":null,' ;;
        json-duplicate-nested) prefix='{"diagnostic":{"tag":0,"t\u0061g":1},' ;;
        json-distinct-nested) prefix='{"diagnostic":{"tag":0,"other":1},' ;;
      esac
      jq -jr --arg prefix "$prefix" '$prefix + (tojson | ltrimstr("{"))' \
        "$dir/$precheck" > "$dir/precheck-mutated.json"
      mv "$dir/precheck-mutated.json" "$dir/$precheck"
      jq -se 'length == 1 and .[0].adr_inputs == []' "$dir/$precheck" >/dev/null
      ;;
    json-multiple-present|json-multiple-absent)
      if [[ "$mode" == json-multiple-absent ]]; then
        jq 'del(.adr_inputs)' "$dir/$precheck" > "$dir/precheck-mutated.json"
        mv "$dir/precheck-mutated.json" "$dir/$precheck"
      fi
      jq -c '.' "$dir/$precheck" > "$dir/precheck-second.json"
      cat "$dir/precheck-second.json" >> "$dir/$precheck"
      jq -se 'length == 2 and all(.[]; type == "object")' "$dir/$precheck" >/dev/null
      ;;
  esac
  lh=$(sha "$dir/reports/review-context/identity-ledger.json")
  local include_adr=false
  case "$mode" in
    bound|adr-keys-spoof|legacy-injected|fs-*|lex-crlf|lex-repeated|lex-even-escape|lex-three-spaces|lex-fence-closed|lex-*-injected) include_adr=true ;;
  esac
  jq -n --arg role "$role" --arg lh "$lh" --arg prev "$genesis" \
    --arg dh "$dh" --arg ah "$ah" --arg pc "$precheck" \
    --arg ph "$(sha "$dir/$precheck")" --argjson include_adr "$include_adr" '{
    schema:"review-context-invocation/v2",input_mode:"file-manifest",
    fallback_mode:"none",read_only:true,stage:"impl",role:$role,feature:"adr-fixture",
    run_id:"adr-run",host_session_id:"adr-session",sequence:2,
    identity_ledger_path:"reports/review-context/identity-ledger.json",
    identity_ledger_sha256:$lh,previous_record_sha256:$prev,
    allowed_input_manifest:([
      {path:"specs/adr-fixture/design.md",sha256:$dh},{path:$pc,sha256:$ph}
    ] + (if $include_adr then [{path:"docs/adr/0001-fixture.md",sha256:$ah}] else [] end))
  }' > "$dir/manifest.json"
  if [[ "$mode" == multi-precheck-* ]]; then
    local second=reports/impl-review/adr-fixture/attempt-1/round-2/precheck-result.json
    mkdir -p "$(dirname "$dir/$second")"
    jq --arg mode "$mode" --arg ah "$ah" '.round = 2 |
      if $mode == "multi-precheck-null" then .adr_inputs = null
      elif ($mode == "multi-precheck-bound" or $mode == "multi-precheck-keys") then
        .adr_inputs = [{path:"docs/adr/0001-fixture.md",sha256:$ah}]
      else . end | if $mode == "multi-precheck-keys" then .Keys = [] else . end' "$dir/$precheck" > "$dir/$second"
    if [[ "$mode" == multi-precheck-stream ]]; then
      printf '%s\n' '{"adr_inputs":null}' '{}' > "$dir/$second"
    elif [[ "$mode" == multi-precheck-invalid ]]; then
      printf '%s\n' '{"adr_inputs":null}' '{' > "$dir/$second"
    fi
    jq --arg p "$second" --arg h "$(sha "$dir/$second")" \
      '.allowed_input_manifest += [{path:$p,sha256:$h}]' \
      "$dir/manifest.json" > "$dir/manifest-next.json"
    mv "$dir/manifest-next.json" "$dir/manifest.json"
  fi
  # Preserve the pinned bytes and vary only path traversal. Zero ADR entries
  # prevent an unrelated ADR allowlist rejection from hiding unsafe reads.
  case "$mode" in
    path-hardlink-precheck)
      mv "$dir/$precheck" "$dir/precheck-target.json"
      ln "$dir/precheck-target.json" "$dir/$precheck"
      [[ "$dir/$precheck" -ef "$dir/precheck-target.json" && ! -L "$dir/$precheck" ]] ;;
    path-hardlink-design)
      mv "$dir/$design" "$dir/design-target.md"
      ln "$dir/design-target.md" "$dir/$design"
      [[ "$dir/$design" -ef "$dir/design-target.md" && ! -L "$dir/$design" ]] ;;
    path-case-precheck)
      mv "$dir/$precheck" "$dir/precheck-target.json"
      mv "$dir/precheck-target.json" "$(dirname "$dir/$precheck")/Precheck-result.json" ;;
    path-case-design)
      mv "$dir/$design" "$dir/design-target.md"
      mv "$dir/design-target.md" "$(dirname "$dir/$design")/Design.md" ;;
    path-link-precheck)
      mv "$dir/$precheck" "$dir/precheck-target.json"
      ln -s "$dir/precheck-target.json" "$dir/$precheck" ;;
    path-link-precheck-parent)
      mv "$dir/reports/impl-review" "$dir/precheck-parent-target"
      ln -s "$dir/precheck-parent-target" "$dir/reports/impl-review" ;;
    path-link-design)
      mv "$dir/$design" "$dir/design-target.md"
      ln -s "$dir/design-target.md" "$dir/$design" ;;
    path-link-design-parent)
      mv "$dir/specs/adr-fixture" "$dir/design-parent-target"
      ln -s "$dir/design-parent-target" "$dir/specs/adr-fixture" ;;
  esac
  if [[ "$mode" == path-case-precheck || "$mode" == path-case-design ]]; then
    local canonical variant actual found=false alias_reachable=false
    if [[ "$mode" == path-case-precheck ]]; then
      canonical="$dir/$precheck"
      variant="$(dirname "$canonical")/Precheck-result.json"
    else
      canonical="$dir/$design"
      variant="$(dirname "$canonical")/Design.md"
    fi
    for actual in "$(dirname "$canonical")"/*; do
      [[ "$actual" != "$canonical" ]]
      if [[ "$actual" == "$variant" ]]; then found=true; fi
    done
    [[ "$found" == true && -f "$variant" && ! -L "$variant" ]]
    if [[ "$canonical" -ef "$variant" ]]; then alias_reachable=true; fi
    printf 'fixture: %s exact-variant-name=true canonical-alias-reachable=%s\n' "$mode" "$alias_reachable"
  fi
}

run_validator() {
  local runtime=$1 dir=$2 manifest_dir=${3:-$2}
  local -a command
  if [[ "$runtime" == bash ]]; then
    command=(bash "$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
      "$manifest_dir/manifest.json" "$dir" --reserve)
  else
    command=(pwsh -NoLogo -NoProfile -File
      "$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"
      -Manifest "$manifest_dir/manifest.json" -RepositoryRoot "$dir" -Reserve)
  fi
  if [[ "$dir" == *-fs-fifo ]]; then
    # Run the actual validator, not an extracted candidate. A blocking read is
    # a test failure, never a successful negative result. Reap its process group.
    python3 - "${command[@]}" <<'PY'
import os
import signal
import subprocess
import sys

try:
    process = subprocess.Popen(sys.argv[1:], start_new_session=True)
except OSError as error:
    print(f"FIFO validator launch failed: {error}", file=sys.stderr)
    sys.exit(125)
try:
    result = process.wait(timeout=15)
except subprocess.TimeoutExpired:
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    process.wait()
    print("FIFO admission timed out; rejection before content read was not proved", file=sys.stderr)
    sys.exit(124)
sys.exit(result if result >= 0 else 128 - result)
PY
  else
    "${command[@]}"
  fi
}

# Build historical review DATA only. No candidate validator is copied or run.
extended_history_fixture() {
  local stage=$1 mode=$2 file digest pc_hash summary_hash layer_hash
  local rel=reports/impl-review/workflow-state-integrity/attempt-1/round-2
  jq -e '[.design_sha256,.requirements_sha256,.acceptance_sha256] |
    all(.[]; type == "string" and test("^[0-9a-f]{64}$"))' \
    "$stage/precheck-result.json" >/dev/null || return 1
  digest=$(jq -jr '[.design_sha256,.requirements_sha256,.acceptance_sha256]|join(":") + ":adr_inputs/v1:[]"' "$stage/precheck-result.json" | shasum -a 256 | awk '{print $1}') || return 1
  jq --arg h "$digest" '.adr_inputs=[] | .layer_sha256={} | .input_sha256=$h' \
    "$stage/precheck-result.json" > "$stage/update.tmp"
  mv "$stage/update.tmp" "$stage/precheck-result.json"
  pc_hash=$(sha "$stage/precheck-result.json")
  # The ADR extension is new: its synthetic reviews use the current role
  # contract. Leave the original no-extension historical controls untouched.
  jq '.checks += [
    {id:"DESIGN-SYSTEM-CONFORMANCE",result:"SKIP",severity:"Minor",finding:"Synthetic CLI-only fixture"},
    {id:"DOMAIN-CONFORMANCE",result:"SKIP",severity:"Minor",finding:"Synthetic fixture has no domain profile"}
  ]' "$stage/reviewer-a.json" > "$stage/update.tmp"
  mv "$stage/update.tmp" "$stage/reviewer-a.json"
  jq '.checks += [
    {id:"DOMAIN-CONFORMANCE",result:"SKIP",severity:"Minor",finding:"Synthetic fixture has no domain profile"}
  ]' "$stage/reviewer-b.json" > "$stage/update.tmp"
  mv "$stage/update.tmp" "$stage/reviewer-b.json"
  jq '.verdict="NEEDS_WORK" | (.checks[]|select(.id=="ADR-PRESENT")) |=
    (.result="FAIL" | .severity="Major" | .finding="Synthetic historical finding")' \
    "$stage/reviewer-a.json" > "$stage/update.tmp"
  mv "$stage/update.tmp" "$stage/reviewer-a.json"
  jq --slurpfile a "$stage/reviewer-a.json" '
    .reviewer_a_check_ids=[$a[0].checks[].id] |
    .reviewer_a_fail_count=1 | .reviewer_a_pass_count=7 | .reviewer_a_skip_count=3' \
    "$stage/integrated-summary.json" > "$stage/update.tmp"
  mv "$stage/update.tmp" "$stage/integrated-summary.json"
  summary_hash=$(sha "$stage/integrated-summary.json")
  for file in impl-review-contract.json integrated-verdict.json; do
    jq '.verdict="NEEDS_WORK" | .reviewer_a_verdict="NEEDS_WORK" |
      .findings_major=1' "$stage/$file" > "$stage/update.tmp"
    mv "$stage/update.tmp" "$stage/$file"
  done
  jq '.adr_inputs=[] | .layer_sha256={}' "$stage/impl-review-contract.json" > "$stage/update.tmp"
  mv "$stage/update.tmp" "$stage/impl-review-contract.json"
  # Equal hashes remain legal with an empty layer pin map (issue #71).
  # Change B's contract AND output together: only cross-reviewer agreement fails.
  for file in reviewer-a.json reviewer-b.json; do
    layer_hash=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    if [[ ( "$mode" == conflicting-layer || "$mode" == conflicting-layer-alias ) && "$file" == reviewer-b.json ]]; then
      layer_hash=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
    fi
    jq --arg pc "$rel/precheck-result.json" --arg ph "$pc_hash" \
      --arg summary "$rel/integrated-summary.json" --arg sh "$summary_hash" \
      --arg lh "$layer_hash" '.allowed_input_manifest |=
      (map(if .path==$pc then .sha256=$ph elif .path==$summary then .sha256=$sh else . end) +
      [{path:"specs/workflow-state-integrity/ux-spec.md",sha256:$lh}])' \
      "$stage/$file" > "$stage/update.tmp"
    mv "$stage/update.tmp" "$stage/$file"
  done
  jq --slurpfile a "$stage/reviewer-a.json" --slurpfile b "$stage/reviewer-b.json" \
    '(.reviewers[]|select(.role=="impl-reviewer-a").allowed_input_manifest)=$a[0].allowed_input_manifest |
     (.reviewers[]|select(.role=="impl-reviewer-b").allowed_input_manifest)=$b[0].allowed_input_manifest' \
    "$stage/impl-review-contract.json" > "$stage/update.tmp"
  mv "$stage/update.tmp" "$stage/impl-review-contract.json"
  if [[ "$mode" == output-only-layer ]]; then
    # The original layer-superset contract permits extra layer inputs in the
    # outputs even when neither role's reservation listed that optional layer.
    jq '(.reviewers[].allowed_input_manifest) |=
      map(select(.path!="specs/workflow-state-integrity/ux-spec.md"))' \
      "$stage/impl-review-contract.json" > "$stage/update.tmp"
    mv "$stage/update.tmp" "$stage/impl-review-contract.json"
  fi
  if [[ "$mode" == conflicting-layer-alias ]]; then
    # B uses an absolute alias for the same layer. Agreement is about the
    # normalized file, not whether two raw path strings happen to be equal.
    local fixture_root=${stage%/reports/impl-review/workflow-state-integrity/attempt-1/round-2}
    jq --arg root "$fixture_root" '(.allowed_input_manifest[] |
      select(.path=="specs/workflow-state-integrity/ux-spec.md").path) |= ($root+"/"+.)' \
      "$stage/reviewer-b.json" > "$stage/update.tmp"
    mv "$stage/update.tmp" "$stage/reviewer-b.json"
    jq --slurpfile b "$stage/reviewer-b.json" '(.reviewers[] |
      select(.role=="impl-reviewer-b").allowed_input_manifest)=$b[0].allowed_input_manifest' \
      "$stage/impl-review-contract.json" > "$stage/update.tmp"
    mv "$stage/update.tmp" "$stage/impl-review-contract.json"
  fi
  # A malformed setup must fail independently of the workflow's early return.
  jq -e '[.checks[]|select(.result=="FAIL" and .severity=="Major")]|length==1' \
    "$stage/reviewer-a.json" >/dev/null
  # Check fixture serialization independently; the original opening fast path
  # cannot establish that the positive control has a valid input digest.
  python3 - "$stage/precheck-result.json" <<'PY'
import hashlib
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    precheck = json.load(stream)
pins = [precheck.get(key) for key in
        ("design_sha256", "requirements_sha256", "acceptance_sha256")]
if not all(isinstance(pin, str) and re.fullmatch(r"[0-9a-f]{64}", pin) for pin in pins):
    sys.exit("fixture setup: invalid core hash")
expected = hashlib.sha256((":".join(pins) + ":adr_inputs/v1:[]").encode("ascii")).hexdigest()
if precheck.get("input_sha256") != expected:
    sys.exit("fixture setup: input digest mismatch")
PY
}

# Fixture DATA only: exercise the original validators' current-PASS consumer.
current_adr_fixture() {
  local stage=$1 mode=$2
  extended_history_fixture "$stage" equal-layer || return 1
  python3 - "$stage" "$mode" <<'PY'
import hashlib
import json
import pathlib
import re
import sys

stage = pathlib.Path(sys.argv[1])
mode = sys.argv[2]
root = stage.parents[4]
rel = stage.relative_to(root).as_posix()
def read(name):
    return json.loads((stage / name).read_text(encoding="utf-8"))
def save(name, obj):
    (stage / name).write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
design = root / "specs/workflow-state-integrity/design.md"
old = design.read_text(encoding="utf-8")
original = "docs/adr/0002-repository-workflow-state-integrity.md"
assert old.count("`" + original + "`") == 1, "fixture ADR declaration drift"
text = old.replace("`" + original + "`", "Synthetic ADR declaration below")
adr = "docs/adr/0001-current-fixture.md"
entries = []
if mode != "current-empty":
    target = root / adr
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("# Synthetic ADR\n", encoding="utf-8")
    entries = [{"path": adr, "sha256": digest(target)}]
    text += "\n`" + adr + "`\n"
design.write_text(text, encoding="utf-8")
# Keep historical core design pins: spec opening permits non-ADR design
# growth, but must not permit a changed ADR authorization set.
pc = read("precheck-result.json")
pc["adr_inputs"] = entries
compact = json.dumps(entries, separators=(",", ":"), ensure_ascii=True)
material = ":".join(pc[k] for k in
                    ("design_sha256", "requirements_sha256", "acceptance_sha256"))
pc["input_sha256"] = hashlib.sha256((material + ":adr_inputs/v1:" + compact).encode("ascii")).hexdigest()
save("precheck-result.json", pc)
a = read("reviewer-a.json")
a["verdict"] = "NEEDS_WORK" if mode == "current-own-opening" else "PASS"
for check in a["checks"]:
    if check["id"] == "ADR-PRESENT" and mode != "current-own-opening":
        check.update(result="PASS", severity="Minor", finding="Synthetic valid ADR")
failures = sum(c["result"] == "FAIL" for c in a["checks"])
summary = read("integrated-summary.json")
summary.update(reviewer_a_fail_count=failures, reviewer_a_pass_count=8-failures, reviewer_a_skip_count=3)
save("integrated-summary.json", summary)
b = read("reviewer-b.json")
for reviewer in (a, b):
    manifest = [x for x in reviewer["allowed_input_manifest"]
                if x["path"] != "specs/workflow-state-integrity/ux-spec.md"]
    for item in manifest:
        if item["path"] in (rel + "/precheck-result.json", rel + "/integrated-summary.json"):
            item["sha256"] = digest(root / item["path"])
    reviewer["allowed_input_manifest"] = manifest + entries
save("reviewer-a.json", a)
save("reviewer-b.json", b)
contract = read("impl-review-contract.json")
contract["adr_inputs"] = entries
for reviewer in contract["reviewers"]:
    source = a if reviewer["role"] == "impl-reviewer-a" else b
    reviewer["allowed_input_manifest"] = source["allowed_input_manifest"]
for name, obj in (("impl-review-contract.json", contract),
                  ("integrated-verdict.json", read("integrated-verdict.json"))):
    obj.update(verdict=a["verdict"], reviewer_a_verdict=a["verdict"], findings_major=failures)
    save(name, obj)
if mode == "current-add":
    design.write_text(text + "\n`docs/adr/0003-unadmitted-fixture.md`\n", encoding="utf-8")
elif mode in ("current-remove", "current-own-opening"):
    design.write_text(text.replace("`" + adr + "`", "Removed declaration"), encoding="utf-8")
elif mode == "current-parent-link":
    directory = root / "docs/adr"
    retained = root / "same-content-adr"
    directory.rename(retained)
    directory.symlink_to(retained, target_is_directory=True)
    assert directory.is_symlink() and digest(root / adr) == entries[0]["sha256"]
assert read("impl-review-contract.json")["verdict"] == a["verdict"]
assert read("integrated-verdict.json")["verdict"] == a["verdict"]
assert len(a["checks"]) == len(b["checks"]) == 11
PY
}

workflow_history_checks() {
  local runtime mode dir stage file rc expect baseline_ok opening current_ok
  local role mutation index anchor_a_ok anchor_b_ok check_baseline_ok extended_ok history_pin_ok
  local boundary_control_ok boundary_early_ok boundary_before boundary_source boundary_mode
  local interrupted_file interrupted_hash preserved late_control_ok late_missing_ok
  local -a check_modes=()
  local -a history_modes=()
  for role in a b; do
    check_modes+=("check-$role-control-0")
    for index in {0..10}; do check_modes+=("check-$role-missing-$index"); done
    for mutation in duplicate unknown case reorder; do check_modes+=("check-$role-$mutation-0"); done
  done
  history_modes=(legacy legacy-precheck-absent legacy-precheck-dangling legacy-precheck-case null-set object-set missing-precheck equal-layer interrupted-a-empty interrupted-a-partial interrupted-b-empty interrupted-b-partial output-only-layer conflicting-layer conflicting-layer-alias canonical-adr-path newline-adr-path duplicate-adr-key duplicate-escaped-adr-key duplicate-nested-role invalid-utf8 duplicate-check missing-b-check wrong-finding-count wrong-reviewer-run wrong-summary-count wrong-summary-id "${check_modes[@]}" history-pin-control history-pin-forged)
  if [[ "${1:-}" == --history-pin-only ]]; then
    history_modes=(legacy history-pin-control history-pin-forged)
  elif [[ "${1:-}" == --late-contract-only ]]; then
    history_modes=(legacy late-contract-control late-contract-missing late-contract-rescue)
  elif [[ "${1:-}" == --pwsh-boundary-only ]]; then
    history_modes=(legacy current-singleton current-pwsh-control current-pwsh-early-poison current-pwsh-poison)
  elif [[ "${1:-}" == --current-adr-only ]]; then
    history_modes=(legacy current-singleton current-empty current-add current-remove current-parent-link current-own-opening)
  else
    history_modes+=(late-contract-control late-contract-missing late-contract-rescue)
    history_modes+=(current-singleton current-empty current-add current-remove current-parent-link current-own-opening)
    history_modes+=(current-pwsh-control current-pwsh-early-poison current-pwsh-poison)
  fi
  for runtime in bash pwsh; do
    if ! command -v "$runtime" >/dev/null 2>&1; then
      printf 'not ok: workflow history runtime unavailable: %s\n' "$runtime"
      failed=$((failed + 1))
      continue
    fi
    baseline_ok=false
    current_ok=false
    boundary_control_ok=false
    boundary_early_ok=false
    anchor_a_ok=false
    anchor_b_ok=false
    extended_ok=false
    history_pin_ok=false
    late_control_ok=false
    late_missing_ok=false
    for mode in "${history_modes[@]}"; do
      # This scheduling seam observes Bash's actual jq call. PowerShell needs
      # its own real read-boundary test; do not claim parity from this fixture.
      if [[ "$runtime" == pwsh && "$mode" == late-contract-* ]]; then continue; fi
      if [[ "$runtime" == bash && "$mode" == current-pwsh-* ]]; then continue; fi
      interrupted_file=''
      interrupted_hash=''
      dir="$ADR_TMP/workflow-$runtime-$mode"
      mkdir -p "$dir/specs" "$dir/reports" \
        "$dir/plugins/sdd-review-loop/references" "$dir/plugins/sdd-quality-loop/references"
      dir="$(cd "$dir" && pwd -P)"
      # Copy only fixture data and reference documents; execute original validators.
      cp -R "$ROOT/specs/workflow-state-integrity" "$dir/specs/"
      for stage in spec impl task; do
        mkdir -p "$dir/reports/$stage-review"
        cp -R "$ROOT/reports/$stage-review/workflow-state-integrity" "$dir/reports/$stage-review/"
      done
      cp "$ROOT/plugins/sdd-review-loop/references/spec-review-calibration.md" \
        "$ROOT/plugins/sdd-review-loop/references/reviewer-calibration.md" "$dir/plugins/sdd-review-loop/references/"
      cp "$ROOT/plugins/sdd-quality-loop/references/risk-gate-matrix.md" \
        "$ROOT/plugins/sdd-quality-loop/references/risk-classification-policy.md" "$dir/plugins/sdd-quality-loop/references/"
      while IFS= read -r file; do
        sed "s#$ROOT#$dir#g" "$file" > "$dir/relocated.tmp"
        mv "$dir/relocated.tmp" "$file"
      done < <(find "$dir/reports" -type f \( -name '*-review-contract.json' -o -name 'reviewer-a.json' -o -name 'reviewer-b.json' \))
      jq '{schema_version,migration_baseline_commit,entries:[.entries[]|select(.feature=="workflow-state-integrity")|.profile="full"|del(.legacy)]}' \
        "$ROOT/specs/workflow-state-registry.json" > "$dir/specs/workflow-state-registry.json"
      stage="$dir/reports/impl-review/workflow-state-integrity/attempt-1/round-2"
      jq '.verdict="NEEDS_WORK"' "$stage/integrated-verdict.json" > "$dir/mutation.tmp"
      mv "$dir/mutation.tmp" "$stage/integrated-verdict.json"
      expect=1
      opening=impl:1:3
      case "$mode" in
        legacy) expect=0 ;;
        current-*)
          current_adr_fixture "$stage" "$mode" || return 1
          # Fixture history has spec attempt 1, rounds 1 and 2. Do not
          # silently test an invalid opening if that fixture history grows.
          [[ -f "$dir/reports/spec-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" ]] || return 1
          [[ ! -d "$dir/reports/spec-review/workflow-state-integrity/attempt-1/round-3" ]] || return 1
          [[ ! -d "$dir/reports/spec-review/workflow-state-integrity/attempt-2" ]] || return 1
          opening=spec:1:3
          if [[ "$mode" == current-singleton || "$mode" == current-empty ]]; then expect=0; fi
          if [[ "$mode" == current-pwsh-control || "$mode" == current-pwsh-poison ]]; then expect=0; fi
          if [[ "$mode" == current-own-opening ]]; then opening=impl:1:3; expect=0; fi
          ;;
        history-pin-control|history-pin-forged|late-contract-*)
          # The actual Bash validator consults SCRIPT_ROOT's Git history, not
          # the data fixture's directory. Use existing history at ROOT; never
          # copy a validator, mock Git, or create commits in the user's tree.
          local evidence_relative calibration_relative pin historical live forged
          evidence_relative=reports/impl-review/workflow-state-integrity/attempt-1/round-2/impl-review-contract.json
          calibration_relative=plugins/sdd-review-loop/references/reviewer-calibration.md
          pin=$(git -C "$ROOT" log --diff-filter=A --format='%H' -- "$evidence_relative") || return 1
          [[ -n "$pin" && "$pin" != *$'\n'* ]] || return 1
          git -C "$ROOT" merge-base --is-ancestor "$pin" HEAD || return 1
          git -C "$ROOT" show "$pin:$calibration_relative" > "$dir/historical-calibration.md" || return 1
          historical=$(sha "$dir/historical-calibration.md")
          jq -e --arg p "$calibration_relative" --arg h "$historical" '
            all(.reviewers[];
              [.allowed_input_manifest[]|select(.path==$p)|.sha256]==[$h])' \
            "$stage/impl-review-contract.json" >/dev/null || return 1
          printf '\nSynthetic fixture-only reference growth.\n' >> "$dir/$calibration_relative"
          live=$(sha "$dir/$calibration_relative")
          [[ "$live" != "$historical" ]] || return 1
          # Restore the real completed verdict: a NEEDS_WORK opening early
          # return would never exercise either historical-pin consumer.
          cp "$ROOT/reports/impl-review/workflow-state-integrity/attempt-1/round-2/integrated-verdict.json" \
            "$stage/integrated-verdict.json"
          jq -e '.verdict=="PASS"' "$stage/integrated-verdict.json" >/dev/null || return 1
          if [[ "$mode" != history-pin-forged ]]; then
            expect=0
          else
            forged=ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
            [[ "$forged" != "$historical" && "$forged" != "$live" ]] || return 1
            for file in impl-review-contract.json reviewer-a.json reviewer-b.json; do
              jq --arg p "$calibration_relative" --arg h "$forged" '
                if has("reviewers") then
                  (.reviewers[].allowed_input_manifest[]|select(.path==$p).sha256)=$h
                else (.allowed_input_manifest[]|select(.path==$p).sha256)=$h end' \
                "$stage/$file" > "$dir/mutation.tmp"
              mv "$dir/mutation.tmp" "$stage/$file"
            done
            jq -e --arg p "$calibration_relative" --arg h "$forged" '
              all(.reviewers[];
                [.allowed_input_manifest[]|select(.path==$p)|.sha256]==[$h])' \
              "$stage/impl-review-contract.json" >/dev/null || return 1
          fi
          printf 'history fixture: runtime=%s git-root=%s introducing-commit=%s live=%s historical=%s\n' \
            "$runtime" "$ROOT" "$pin" "$live" "$historical"
          if [[ "$mode" == late-contract-* ]]; then
            cp "$stage/impl-review-contract.json" "$dir/replacement-contract.json"
            if [[ "$mode" != late-contract-control ]]; then
              expect=1
              for file in impl-review-contract.json reviewer-a.json reviewer-b.json; do
                jq --arg p "$calibration_relative" '
                  if has("reviewers") then (.reviewers[].allowed_input_manifest) |= map(select(.path!=$p))
                  else .allowed_input_manifest |= map(select(.path!=$p)) end' \
                  "$stage/$file" > "$dir/mutation.tmp"
                mv "$dir/mutation.tmp" "$stage/$file"
              done
              jq -e --arg p "$calibration_relative" 'all(.reviewers[];
                all(.allowed_input_manifest[]; .path!=$p))' "$stage/impl-review-contract.json" >/dev/null || return 1
            fi
            if [[ "$mode" != late-contract-missing ]]; then
              mkdir "$dir/bin"
              cp "$ROOT/tests/fixtures/adr-jq-read-boundary.py" "$dir/bin/jq"
              chmod 700 "$dir/bin/jq"
            fi
          fi ;;
        legacy-precheck-absent|legacy-precheck-dangling|legacy-precheck-case)
          # Retire only this fixture's precheck to construct a genuine absent
          # control. Malformed entries must not receive the same exemption.
          mv "$stage/precheck-result.json" "$dir/saved-precheck.json"
          [[ ! -e "$stage/precheck-result.json" && ! -L "$stage/precheck-result.json" ]] || return 1
          if [[ "$mode" == legacy-precheck-absent ]]; then
            expect=0
          elif [[ "$mode" == legacy-precheck-dangling ]]; then
            ln -s absent-precheck-target.json "$stage/precheck-result.json"
            [[ -L "$stage/precheck-result.json" && ! -e "$stage/precheck-result.json" ]] || return 1
          else
            printf '{}\n' > "$stage/Precheck-result.json"
            [[ -f "$stage/Precheck-result.json" ]] || return 1
          fi ;;
        null-set|object-set)
          for file in precheck-result.json impl-review-contract.json; do
            if [[ "$mode" == null-set ]]; then
              jq '.adr_inputs=null' "$stage/$file" > "$dir/mutation.tmp"
            else
              jq '.adr_inputs={}' "$stage/$file" > "$dir/mutation.tmp"
            fi
            mv "$dir/mutation.tmp" "$stage/$file"
          done ;;
        missing-precheck)
          jq '.adr_inputs=[]' "$stage/impl-review-contract.json" > "$dir/mutation.tmp"
          mv "$dir/mutation.tmp" "$stage/impl-review-contract.json" ;;
        equal-layer|output-only-layer|conflicting-layer|conflicting-layer-alias)
          extended_history_fixture "$stage" "$mode"
          if [[ "$mode" == equal-layer || "$mode" == output-only-layer ]]; then expect=0; fi ;;
        canonical-adr-path|newline-adr-path)
          extended_history_fixture "$stage" equal-layer
          local path_entries path_digest path_pc_hash
          path_entries=$(jq -nc --arg mode "$mode" '[{
            path:("docs/adr/0001-history.md" + (if $mode=="newline-adr-path" then "\n" else "" end)),
            sha256:("a" * 64)}]') || return 1
          for file in precheck-result.json impl-review-contract.json; do
            jq --argjson entries "$path_entries" '.adr_inputs=$entries' "$stage/$file" > "$dir/mutation.tmp"
            mv "$dir/mutation.tmp" "$stage/$file"
          done
          path_digest=$(jq -jr '[.design_sha256,.requirements_sha256,.acceptance_sha256]|join(":")' \
            "$stage/precheck-result.json") || return 1
          path_digest=$(printf '%s:adr_inputs/v1:%s' "$path_digest" "$path_entries" | shasum -a 256 | awk '{print $1}') || return 1
          jq --arg h "$path_digest" '.input_sha256=$h' "$stage/precheck-result.json" > "$dir/mutation.tmp"
          mv "$dir/mutation.tmp" "$stage/precheck-result.json"
          path_pc_hash=$(sha "$stage/precheck-result.json")
          for file in reviewer-a.json reviewer-b.json; do
            jq --argjson entries "$path_entries" --arg h "$path_pc_hash" \
              '.allowed_input_manifest |= (map(if .path|endswith("/precheck-result.json") then .sha256=$h else . end) + $entries)' \
              "$stage/$file" > "$dir/mutation.tmp"
            mv "$dir/mutation.tmp" "$stage/$file"
          done
          jq --slurpfile a "$stage/reviewer-a.json" --slurpfile b "$stage/reviewer-b.json" \
            '(.reviewers[]|select(.role=="impl-reviewer-a").allowed_input_manifest)=$a[0].allowed_input_manifest |
             (.reviewers[]|select(.role=="impl-reviewer-b").allowed_input_manifest)=$b[0].allowed_input_manifest' \
            "$stage/impl-review-contract.json" > "$dir/mutation.tmp"
          mv "$dir/mutation.tmp" "$stage/impl-review-contract.json"
          # Assert the exact decoded path and all four bindings independently.
          # Do not create a live ADR: a verified opening checks saved history.
          jq -e --arg mode "$mode" --argjson entries "$path_entries" \
            --slurpfile p "$stage/precheck-result.json" \
            --slurpfile a "$stage/reviewer-a.json" --slurpfile b "$stage/reviewer-b.json" '
            .adr_inputs==$entries and $p[0].adr_inputs==$entries and
            ($entries[0].path == ("docs/adr/0001-history.md" +
              (if $mode=="newline-adr-path" then "\n" else "" end))) and
            all((.reviewers + [$a[0],$b[0]])[];
              ([.allowed_input_manifest[]|select(.path==$entries[0].path)] == $entries))' \
            "$stage/impl-review-contract.json" >/dev/null || return 1
          if [[ "$mode" == canonical-adr-path ]]; then expect=0; fi ;;
        invalid-utf8)
          extended_history_fixture "$stage" equal-layer
          command -v iconv > /dev/null 2>&1 || return 1
          iconv -f UTF-8 -t UTF-8 "$stage/impl-review-contract.json" > /dev/null || return 1
          # A raw digest must not authorize a lossy-decoded replacement string.
          # Keep the JSON structure intact; inject one invalid UTF-8 byte inside
          # a string, not a syntax error or a conflicting ADR declaration.
          {
            jq -j 'tojson | rtrimstr("}")' "$stage/impl-review-contract.json"
            printf ',"encoding_probe":"\377"}\n'
          } > "$dir/mutation.tmp"
          mv "$dir/mutation.tmp" "$stage/impl-review-contract.json"
          if iconv -f UTF-8 -t UTF-8 "$stage/impl-review-contract.json" > /dev/null 2>&1; then
            printf 'fixture setup: invalid UTF-8 mutation was not present\n' >&2
            return 1
          fi ;;
        duplicate-nested-role)
          extended_history_fixture "$stage" equal-layer
          # The equal-layer control already has role in TWO sibling objects.
          # Reject only this same-object repeat, without global-key false positives.
          jq -r 'tojson | sub("\"role\":\"impl-reviewer-a\"";
            "\"role\":null,\"role\":\"impl-reviewer-a\"")' \
            "$stage/impl-review-contract.json" > "$dir/mutation.tmp"
          mv "$dir/mutation.tmp" "$stage/impl-review-contract.json"
          jq --stream -se '[.[] | select(length==2 and .[0]==["reviewers",0,"role"]) | .[1]] == [null,"impl-reviewer-a"]' \
            "$stage/impl-review-contract.json" >/dev/null ;;
        duplicate-adr-key|duplicate-escaped-adr-key)
          extended_history_fixture "$stage" equal-layer
          # Preserve both raw members: ordinary object parsing would erase the
          # malformed first value. Escaped spelling has the same decoded key.
          local duplicate_prefix='{"adr_inputs":null,'
          if [[ "$mode" == duplicate-escaped-adr-key ]]; then
            duplicate_prefix='{"\u0061dr_inputs":null,'
          fi
          jq -r --arg prefix "$duplicate_prefix" '$prefix + (tojson|ltrimstr("{"))' \
            "$stage/impl-review-contract.json" > "$dir/mutation.tmp"
          mv "$dir/mutation.tmp" "$stage/impl-review-contract.json"
          # Stream events retain both keys; assert the attack exists without
          # relying on last-key-wins object parsing or on the tested validator.
          jq --stream -se '[.[] | select(length==2 and .[0]==["adr_inputs"]) | .[1]] == [null,[]]' \
            "$stage/impl-review-contract.json" >/dev/null ;;
        check-*)
          extended_history_fixture "$stage" equal-layer
          local prefix before_ids expected_ids summary_pin
          IFS=- read -r prefix role mutation index <<< "$mode"
          if [[ "$role" == a ]]; then
            # Keep the failed-round opening path reachable even when A's only
            # FAIL is removed. B's independent finding is not mutated here.
            jq '.verdict="NEEDS_WORK" | (.checks[]|select(.id=="DECISION-JUSTIFIED")) |=
              (.result="FAIL" | .severity="Major" | .finding="Independent synthetic B finding")' \
              "$stage/reviewer-b.json" > "$dir/mutation.tmp"
            mv "$dir/mutation.tmp" "$stage/reviewer-b.json"
          fi
          file="$stage/reviewer-$role.json"
          before_ids=$(jq -ce '[.checks[].id] | select(length==11 and (unique|length)==11)' "$file") || return 1
          jq --arg mutation "$mutation" --argjson index "$index" '
            .checks |= (if $mutation=="control" then .
              elif $mutation=="missing" then del(.[$index])
              elif $mutation=="duplicate" then .[1].id=.[0].id
              elif $mutation=="unknown" then .[0].id="UNREGISTERED-CHECK"
              elif $mutation=="case" then .[0].id |= ascii_downcase
              elif $mutation=="reorder" then [.[1],.[0]] + .[2:]
              else error("unknown fixture mutation") end) |
            .verdict=(if any(.checks[]; .result=="FAIL") then "NEEDS_WORK" else "PASS" end)' \
            "$file" > "$dir/mutation.tmp"
          mv "$dir/mutation.tmp" "$file"
          expected_ids=$(jq -cn --argjson ids "$before_ids" --arg m "$mutation" --argjson i "$index" '
            if $m=="control" then $ids
            elif $m=="missing" then [$ids|to_entries[]|select(.key!=$i)|.value]
            elif $m=="duplicate" then [$ids[0],$ids[0]]+$ids[2:]
            elif $m=="unknown" then ["UNREGISTERED-CHECK"]+$ids[1:]
            elif $m=="case" then [($ids[0]|ascii_downcase)]+$ids[1:]
            else [$ids[1],$ids[0]]+$ids[2:] end') || return 1
          jq -e --argjson expected "$expected_ids" --argjson before "$before_ids" --arg mutation "$mutation" \
            '([.checks[].id]==$expected) and
             (if $mutation=="control" then $expected==$before else $expected!=$before end)' "$file" >/dev/null || return 1
          if [[ "$mutation" == control ]]; then expect=0; fi
          # Recompute all dependent DATA even when A's FAIL is omitted.
          # Rejection must concern the ID contract, not stale pins,
          # summary counts or an inconsistent integrated verdict.
          jq --slurpfile a "$stage/reviewer-a.json" '
            .reviewer_a_check_ids=[$a[0].checks[].id] |
            .reviewer_a_fail_count=([$a[0].checks[]|select(.result=="FAIL")]|length) |
            .reviewer_a_pass_count=([$a[0].checks[]|select(.result=="PASS")]|length) |
            .reviewer_a_skip_count=([$a[0].checks[]|select(.result=="SKIP")]|length)' \
            "$stage/integrated-summary.json" > "$dir/mutation.tmp"
          mv "$dir/mutation.tmp" "$stage/integrated-summary.json"
          summary_pin=$(sha "$stage/integrated-summary.json")
          jq --arg h "$summary_pin" '(.allowed_input_manifest[] |
            select(.path|endswith("/round-2/integrated-summary.json")).sha256)=$h' \
            "$stage/reviewer-b.json" > "$dir/mutation.tmp"
          mv "$dir/mutation.tmp" "$stage/reviewer-b.json"
          for file in impl-review-contract.json integrated-verdict.json; do
            jq --slurpfile a "$stage/reviewer-a.json" --slurpfile b "$stage/reviewer-b.json" '
              .reviewer_a_verdict=$a[0].verdict | .reviewer_b_verdict=$b[0].verdict |
              .findings_major=([$a[0].checks[],$b[0].checks[]|select(.result=="FAIL")]|length) |
              .verdict=(if .findings_major>0 then "NEEDS_WORK" else "PASS" end)' \
              "$stage/$file" > "$dir/mutation.tmp"
            mv "$dir/mutation.tmp" "$stage/$file"
          done
          jq --slurpfile b "$stage/reviewer-b.json" '(.reviewers[] |
            select(.role=="impl-reviewer-b").allowed_input_manifest)=$b[0].allowed_input_manifest' \
            "$stage/impl-review-contract.json" > "$dir/mutation.tmp"
          mv "$dir/mutation.tmp" "$stage/impl-review-contract.json"
          # Independently assert the regenerated evidence and untouched anchor.
          jq -e --arg role "$role" --arg pin "$summary_pin" \
            --slurpfile a "$stage/reviewer-a.json" --slurpfile b "$stage/reviewer-b.json" \
            --slurpfile s "$stage/integrated-summary.json" --slurpfile v "$stage/integrated-verdict.json" '
            ($a[0]) as $a | ($b[0]) as $b | ($s[0]) as $s | ($v[0]) as $v |
            ([$a.checks[],$b.checks[]|select(.result=="FAIL" and .severity=="Major")]|length) as $major |
            .findings_major==$major and $v.findings_major==$major and $major>0 and
            .verdict=="NEEDS_WORK" and $v.verdict=="NEEDS_WORK" and
            .reviewer_a_verdict==$a.verdict and $v.reviewer_a_verdict==$a.verdict and
            .reviewer_b_verdict==$b.verdict and $v.reviewer_b_verdict==$b.verdict and
            $s.reviewer_a_check_ids==[$a.checks[].id] and
            $s.reviewer_a_fail_count==([$a.checks[]|select(.result=="FAIL")]|length) and
            $s.reviewer_a_pass_count==([$a.checks[]|select(.result=="PASS")]|length) and
            $s.reviewer_a_skip_count==([$a.checks[]|select(.result=="SKIP")]|length) and
            ([.reviewers[]|select(.role=="impl-reviewer-b")][0].allowed_input_manifest==$b.allowed_input_manifest) and
            ([$b.allowed_input_manifest[]|select(.path|endswith("/round-2/integrated-summary.json"))|.sha256]==[$pin]) and
            (if $role=="a" then $b.verdict=="NEEDS_WORK" and
              ([$b.checks[]|select(.result=="FAIL")]|length)==1 and
              ([$b.checks[]|select(.id=="DECISION-JUSTIFIED" and .result=="FAIL" and .severity=="Major")]|length)==1
             else $a.verdict=="NEEDS_WORK" and
              ([$a.checks[]|select(.result=="FAIL")]|length)==1 end)' \
            "$stage/impl-review-contract.json" >/dev/null || return 1 ;;
        interrupted-*)
          extended_history_fixture "$stage" equal-layer
          local interruption_prefix interruption_kind
          IFS=- read -r interruption_prefix role interruption_kind <<< "$mode"
          interrupted_file="$stage/reviewer-$role.json"
          # Synthetic interrupted output, not a live reviewer or an input-loss
          # simulation. Keep the stale completed-round companions: neither
          # opening tolerance nor saved BLOCKED prose may legitimize them.
          jq --arg kind "$interruption_kind" '
            .verdict="BLOCKED" |
            .checks=(if $kind=="empty" then [] else .checks[:1] end)' \
            "$interrupted_file" > "$dir/mutation.tmp"
          mv "$dir/mutation.tmp" "$interrupted_file"
          jq -e --arg kind "$interruption_kind" '
            .verdict=="BLOCKED" and
            (.checks|length)==(if $kind=="empty" then 0 else 1 end) and
            all(.checks[]; .result=="PASS")' "$interrupted_file" >/dev/null || return 1
          interrupted_hash=$(sha "$interrupted_file") ;;
        duplicate-check|missing-b-check|wrong-finding-count|wrong-reviewer-run|wrong-summary-count|wrong-summary-id)
          extended_history_fixture "$stage" equal-layer
          # Mutate saved evidence DATA after establishing the same positive
          # fixture. Keep the precheck unchanged; summary cases explicitly
          # rebind the changed summary hash in both copies of B's manifest.
          case "$mode" in
            missing-b-check)
              # New extension fixtures have the current eleven-check format.
              # Remove one PASS only: manifests, A's summary and aggregate
              # finding counts stay consistent, so they cannot mask this gap.
              jq -e '(.checks|length)==11 and
                ([.checks[]|select(.id=="DECISION-JUSTIFIED" and .result=="PASS")]|length)==1' \
                "$stage/reviewer-b.json" >/dev/null || return 1
              jq '.checks |= map(select(.id!="DECISION-JUSTIFIED"))' \
                "$stage/reviewer-b.json" > "$dir/mutation.tmp"
              mv "$dir/mutation.tmp" "$stage/reviewer-b.json"
              jq -e '(.checks|length)==10 and .verdict=="PASS" and
                all(.checks[]; .result=="PASS" or .result=="SKIP") and
                ([.checks[].id]|index("DECISION-JUSTIFIED"))==null' \
                "$stage/reviewer-b.json" >/dev/null || return 1 ;;
            wrong-summary-count|wrong-summary-id)
              if [[ "$mode" == wrong-summary-count ]]; then
                # Keep the total and shape valid, but disagree with A's checks.
                jq '.reviewer_a_fail_count=2 | .reviewer_a_pass_count=6' \
                  "$stage/integrated-summary.json" > "$dir/mutation.tmp"
              else
                jq '.reviewer_a_check_ids[0] += "-mismatch"' \
                  "$stage/integrated-summary.json" > "$dir/mutation.tmp"
              fi
              mv "$dir/mutation.tmp" "$stage/integrated-summary.json"
              # Rebind both copies of B's summary pin: rejection must not be
              # explained by a stale summary hash in its manifest.
              local changed_summary_hash
              changed_summary_hash=$(sha "$stage/integrated-summary.json")
              jq --arg h "$changed_summary_hash" '(.allowed_input_manifest[] |
                select(.path|endswith("/round-2/integrated-summary.json")).sha256)=$h' \
                "$stage/reviewer-b.json" > "$dir/mutation.tmp"
              mv "$dir/mutation.tmp" "$stage/reviewer-b.json"
              jq --slurpfile b "$stage/reviewer-b.json" '(.reviewers[] |
                select(.role=="impl-reviewer-b").allowed_input_manifest)=$b[0].allowed_input_manifest' \
                "$stage/impl-review-contract.json" > "$dir/mutation.tmp"
              mv "$dir/mutation.tmp" "$stage/impl-review-contract.json"
              jq -e --slurpfile a "$stage/reviewer-a.json" \
                '((.reviewer_a_check_ids|sort) != ([$a[0].checks[].id]|sort)) or
                 (.reviewer_a_fail_count != ([$a[0].checks[]|select(.result=="FAIL")]|length))' \
                "$stage/integrated-summary.json" >/dev/null ;;
            duplicate-check)
              jq '.checks[1].id=.checks[0].id' "$stage/reviewer-a.json" > "$dir/mutation.tmp"
              mv "$dir/mutation.tmp" "$stage/reviewer-a.json"
              jq -e '([.checks[].id]|length) > ([.checks[].id]|unique|length)' \
                "$stage/reviewer-a.json" >/dev/null ;;
            wrong-finding-count)
              # Change both aggregates together: their mutual equality must
              # not substitute for comparison with the actual reviewer checks.
              for file in impl-review-contract.json integrated-verdict.json; do
                jq '.findings_major=2' "$stage/$file" > "$dir/mutation.tmp"
                mv "$dir/mutation.tmp" "$stage/$file"
              done
              jq -e --slurpfile a "$stage/reviewer-a.json" --slurpfile b "$stage/reviewer-b.json" \
                '.findings_major != ([$a[0].checks[],$b[0].checks[] |
                  select(.result=="FAIL" and .severity=="Major")]|length)' \
                "$stage/impl-review-contract.json" >/dev/null ;;
            wrong-reviewer-run)
              jq '.run_id += "-mismatch"' "$stage/reviewer-a.json" > "$dir/mutation.tmp"
              mv "$dir/mutation.tmp" "$stage/reviewer-a.json"
              jq -e --slurpfile a "$stage/reviewer-a.json" \
                '[.reviewers[]|select(.role=="impl-reviewer-a")][0].run_id != $a[0].run_id' \
                "$stage/impl-review-contract.json" >/dev/null ;;
          esac ;;
      esac
      rc=0
      if [[ "$mode" == current-pwsh-* ]]; then
        boundary_mode=${mode#current-pwsh-}
        boundary_before=$(sha "$stage/precheck-result.json") || return 1
        boundary_source=$(sha "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1") || return 1
        pwsh -NoProfile -NonInteractive -File "$ROOT/tests/fixtures/adr-pwsh-read-boundary.ps1" \
          -FixtureRoot "$dir" -Mode "$boundary_mode" > "$dir/output.log" 2>&1 || rc=$?
      elif [[ "$runtime" == bash && ( "$mode" == late-contract-control || "$mode" == late-contract-rescue ) ]]; then
        ADR_REAL_JQ="$(command -v jq)" ADR_MUTATION_ROOT="$dir" ADR_MUTATION_MODE="$mode" \
          PATH="$dir/bin:$PATH" bash "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.sh" \
          --registry "$dir/specs/workflow-state-registry.json" --feature workflow-state-integrity --opening impl:1:3 > "$dir/output.log" 2>&1 || rc=$?
      elif [[ "$runtime" == bash ]]; then
        bash "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.sh" \
          --registry "$dir/specs/workflow-state-registry.json" --feature workflow-state-integrity --opening "$opening" > "$dir/output.log" 2>&1 || rc=$?
      else
        pwsh -NoProfile -File "$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.ps1" \
          --registry "$dir/specs/workflow-state-registry.json" --feature workflow-state-integrity --opening "$opening" > "$dir/output.log" 2>&1 || rc=$?
      fi
      if [[ "$mode" == legacy && "$rc" == 0 ]]; then baseline_ok=true; fi
      if [[ "$mode" == current-* ]]; then printf 'Diagnostic: %s %s\n' "$runtime" "$mode"; cat "$dir/output.log"; fi
      if [[ "$mode" == current-singleton && "$rc" == 0 ]]; then current_ok=true; fi
      if [[ "$mode" == equal-layer && "$rc" == 0 ]]; then extended_ok=true; fi
      if [[ "$mode" == history-pin-control && "$rc" == 0 ]]; then history_pin_ok=true; fi
      if [[ "$mode" == check-a-control-0 && "$rc" == 0 ]]; then anchor_a_ok=true; fi
      if [[ "$mode" == check-b-control-0 && "$rc" == 0 ]]; then anchor_b_ok=true; fi
      check_baseline_ok=true
      preserved=true
      case "$mode" in
        current-pwsh-*)
          check_baseline_ok=$current_ok
          if ! python3 "$ROOT/tests/fixtures/adr-pwsh-boundary-receipt.py" \
            "$ROOT" "$dir" "$boundary_mode" "$boundary_before" "$boundary_source" "$rc"; then
            preserved=false
          fi
          if [[ "$mode" == current-pwsh-control && "$rc" == 0 && "$preserved" == true && "$baseline_ok" == true && "$current_ok" == true ]]; then
            boundary_control_ok=true
          fi
          if [[ "$mode" == current-pwsh-early-poison ]]; then
            check_baseline_ok=$boundary_control_ok
            if [[ "$rc" == 1 && "$preserved" == true && "$boundary_control_ok" == true ]] && \
              grep -F 'stage-provenance:' "$dir/output.log" >/dev/null && grep -Ei 'adr' "$dir/output.log" >/dev/null; then
              boundary_early_ok=true
            fi
          fi
          if [[ "$mode" == current-pwsh-poison && ( "$boundary_control_ok" != true || "$boundary_early_ok" != true ) ]]; then
            check_baseline_ok=false
          fi
          ;;
        current-*) check_baseline_ok=$current_ok ;;
        late-contract-control|late-contract-rescue)
          if ! jq -e --arg mode "$mode" '.mode==$mode and .jq_exit==0 and
            (.changed==($mode=="late-contract-rescue")) and
            ((.before!=.after)==.changed)' "$dir/mutation-receipt.json" >/dev/null 2>&1; then
            preserved=false
          fi
          if [[ "$preserved" == true ]]; then
            printf 'mutation receipt: '
            jq -c . "$dir/mutation-receipt.json"
          fi
          if [[ "$mode" == late-contract-control && "$rc" == 0 && "$preserved" == true ]]; then late_control_ok=true; fi
          check_baseline_ok=$late_control_ok
          if [[ "$mode" == late-contract-rescue && "$late_missing_ok" != true ]]; then check_baseline_ok=false; fi ;;
        late-contract-missing)
          check_baseline_ok=$late_control_ok
          if [[ "$rc" == 1 ]] && grep -F 'impl reviewer manifests omit required inputs' "$dir/output.log" >/dev/null; then late_missing_ok=true; fi ;;
        history-pin-forged) check_baseline_ok=$history_pin_ok ;;
        interrupted-*)
          check_baseline_ok=$extended_ok
          [[ -f "$interrupted_file" && "$(sha "$interrupted_file")" == "$interrupted_hash" ]] || preserved=false ;;
        check-a-*) check_baseline_ok=$anchor_a_ok ;;
        check-b-*) check_baseline_ok=$anchor_b_ok ;;
      esac
      if [[ "$rc" == "$expect" && "$baseline_ok" == true && "$check_baseline_ok" == true && "$preserved" == true ]] && \
        { [[ "$expect" == 0 ]] || {
          grep -F 'stage-provenance:' "$dir/output.log" >/dev/null &&
          if [[ "$mode" == late-contract-* ]]; then
            grep -F 'impl reviewer manifests omit required inputs' "$dir/output.log" >/dev/null
          elif [[ "$mode" == history-pin-forged ]]; then
            grep -F 'impl reviewer manifest input hash is stale' "$dir/output.log" >/dev/null
          else
            grep -Ei 'adr' "$dir/output.log" >/dev/null
          fi
        }; }; then
        printf 'ok: workflow history %s %s\n' "$runtime" "$mode"
        passed=$((passed + 1))
      else
        printf 'not ok: workflow history %s %s (exit=%s expected=%s baseline=%s)\n' "$runtime" "$mode" "$rc" "$expect" "$baseline_ok"
        cat "$dir/output.log"
        failed=$((failed + 1))
      fi
    done
  done
}

# Deterministically schedule a fixture-only parent replacement immediately
# before the real Bash reader opens its input. This is debugger instrumentation,
# not a replacement validator or a claim that an attacker controls BASH_ENV.
initial_open_checks() {
  local role target action dir before after rc observed expected
  local observer="$ADR_TMP/initial-open-observer.sh"
  cat > "$observer" <<'OBSERVER'
set -T
adr_observe_initial_open() {
  [[ "${candidate:-}" == "$ADR_OBSERVER_TARGET" ]] || return 0
  case "$BASH_COMMAND" in content_base64=*) ;; *) return 0 ;; esac
  [[ ! -e "$ADR_OBSERVER_RECEIPT" ]] || return 0
  local parent=${ADR_OBSERVER_TARGET%/*}
  if [[ "$ADR_OBSERVER_ACTION" == replace ]]; then
    # Keep every byte and SHA pin unchanged; only the acquisition route changes.
    mv -- "$parent" "$parent-held" || exit 125
    ln -s -- "${parent##*/}-held" "$parent" || exit 125
    [[ -L "$parent" && -f "$ADR_OBSERVER_TARGET" ]] || exit 125
  fi
  printf '%s\n' "$ADR_OBSERVER_ACTION" > "$ADR_OBSERVER_RECEIPT"
}
trap adr_observe_initial_open DEBUG
OBSERVER
  for role in impl-reviewer-a impl-reviewer-b; do
    for target in specs/adr-fixture/design.md reports/impl-review/adr-fixture/attempt-1/round-1/precheck-result.json; do
      for action in control replace; do
        dir="$ADR_TMP/initial-$role-${target##*/}-$action"
        fixture "$dir" "$role" legacy
        before=$(sha "$dir/reports/review-context/identity-ledger.json")
        rc=0
        BASH_ENV="$observer" ADR_OBSERVER_TARGET="$dir/$target" \
          ADR_OBSERVER_RECEIPT="$dir/observed.txt" ADR_OBSERVER_ACTION="$action" \
          run_validator bash "$dir" > "$dir/output.log" 2>&1 || rc=$?
        after=$(sha "$dir/reports/review-context/identity-ledger.json")
        observed=missing
        if [[ -f "$dir/observed.txt" ]]; then observed=$(cat "$dir/observed.txt"); fi
        expected=false
        if [[ "$observed" == "$action" ]]; then
          if [[ "$action" == control && "$rc" -eq 0 ]] &&
             [[ $(jq '.records | length' "$dir/reports/review-context/identity-ledger.json") -eq 2 ]]; then
            expected=true
          elif [[ "$action" == replace && "$rc" -gt 0 && "$rc" -lt 124 && "$before" == "$after" ]]; then
            expected=true
          fi
        fi
        if [[ "$expected" == true ]]; then
          printf 'ok: initial-open bash %s %s %s\n' "$role" "$target" "$action"
          passed=$((passed + 1))
        else
          printf 'not ok: initial-open bash %s %s %s (exit=%s observer=%s ledger-unchanged=%s)\n' \
            "$role" "$target" "$action" "$rc" "$observed" "$([[ "$before" == "$after" ]] && printf true || printf false)"
          cat "$dir/output.log"
          failed=$((failed + 1))
        fi
      done
    done
  done
}

# ADR0034 scope correction (2026-09-11): retained stronger transport diagnostic,
# not a default admission guarantee. Its known failures are not a product PASS.
if [[ "${1:-}" == --initial-open-only ]]; then
  initial_open_checks
fi
if [[ "${1:-}" == --initial-open-only ]]; then
  printf 'ADR initial open: passed=%s failed=%s\n' "$passed" "$failed"
  [[ "$failed" -eq 0 ]]
  exit
fi

if [[ "${1:-}" != --admission-json-only && "${1:-}" != --admission-path-only && "${1:-}" != --multi-precheck-only && "${1:-}" != --keys-only ]]; then
  workflow_history_checks "${1:-}"
fi
if [[ "${1:-}" == --workflow-only || "${1:-}" == --history-pin-only || "${1:-}" == --late-contract-only || "${1:-}" == --current-adr-only || "${1:-}" == --pwsh-boundary-only ]]; then
  printf 'ADR workflow history: passed=%s failed=%s\n' "$passed" "$failed"
  [[ "$failed" -eq 0 ]]
  exit
fi

runtimes=(bash)
if command -v pwsh >/dev/null 2>&1; then runtimes+=(pwsh)
else printf 'SKIP: PowerShell unavailable (not a PowerShell pass)\n'; fi
for runtime in "${runtimes[@]}"; do
  for role in impl-reviewer-a impl-reviewer-b; do
    for mode in legacy legacy-declared legacy-injected multi-precheck-legacy multi-precheck-null multi-precheck-bound multi-precheck-stream multi-precheck-invalid multi-precheck-keys keys-hidden keys-lower-hidden adr-keys-spoof zero-bound bound fs-fifo fs-directory fs-symlink fs-missing \
      omitted null-set object-set missing-hash extra-key json-multiple-present json-multiple-absent \
      json-duplicate-root json-duplicate-escaped json-duplicate-nested json-distinct-nested \
      json-invalid-utf8 json-bom design-invalid-utf8 json-root-array json-root-nested-array \
      path-link-precheck path-link-precheck-parent path-link-design path-link-design-parent path-link-root \
      path-link-root-legacy path-root-dot path-root-dotdot path-root-empty-component \
      path-hardlink-precheck path-hardlink-design path-case-precheck path-case-design \
      duplicate-member invalid-hash empty-declared-set wrong-feature wrong-round \
      lex-crlf lex-repeated lex-fence-empty lex-fence-injected \
      lex-tilde-empty lex-tilde-injected lex-long-span-empty lex-long-span-injected \
      lex-escaped-empty lex-escaped-injected lex-indent-empty lex-indent-injected \
      lex-even-escape lex-three-spaces lex-fence-closed \
      lex-tab-empty lex-tab-injected lex-unclosed-empty lex-unclosed-injected \
      lex-suffix-empty lex-suffix-injected lex-short-close-empty lex-short-close-injected \
      lex-trailing-close-empty lex-trailing-close-injected; do
      if [[ "${1:-}" == --keys-only ]]; then
        case "$mode" in legacy|keys-hidden|keys-lower-hidden|multi-precheck-keys|adr-keys-spoof) ;; *) continue ;; esac
      fi
      if [[ "${1:-}" == --multi-precheck-only ]]; then
        case "$mode" in multi-precheck-*) ;; *) continue ;; esac
      fi
      if [[ "${1:-}" == --admission-json-only ]]; then
        case "$mode" in
          legacy|zero-bound|json-multiple-present|json-multiple-absent|json-duplicate-*|json-distinct-nested|json-invalid-utf8|json-bom|design-invalid-utf8|json-root-array|json-root-nested-array) ;;
          *) continue ;;
        esac
      fi
      if [[ "${1:-}" == --admission-path-only ]]; then
        case "$mode" in legacy|zero-bound|path-link-*|path-root-*|path-hardlink-*|path-case-*) ;; *) continue ;; esac
      fi
      dir="$ADR_TMP/$runtime-$role-$mode"
      fixture "$dir" "$role" "$mode"
      validator_dir="$dir"
      if [[ "$mode" == path-link-root || "$mode" == path-link-root-legacy ]]; then
        # The root itself is the only symlink; all descendant inputs and pins
        # remain regular and unchanged. Both paths stay inside this fixture.
        validator_dir="$dir-root-link"
        ln -s "$dir" "$validator_dir"
      fi
      # Vary the raw root only. Every spelling still identifies this fixture,
      # so a rejection cannot be explained by a missing input or stale pin.
      # Do not canonicalize these negative inputs before invoking the product.
      case "$mode" in
        path-root-dot) validator_dir="$dir/." ;;
        path-root-dotdot)
          mkdir "$dir/root-child"
          validator_dir="$dir/root-child/.." ;;
        path-root-empty-component)
          validator_dir="$ADR_TMP//$runtime-$role-$mode" ;;
      esac
      # This assertion is fixture setup, not product validation: malformed
      # spellings must reach the same directory, never a nonexistent target.
      [[ "$validator_dir" -ef "$dir" ]]
      before=$(sha "$dir/reports/review-context/identity-ledger.json")
      rc=0
      # Keep the invocation manifest path ordinary and unchanged, isolating
      # RepositoryRoot rejection from manifest-path validation.
      run_validator "$runtime" "$validator_dir" "$dir" > "$dir/output.log" 2>&1 || rc=$?
      after=$(sha "$dir/reports/review-context/identity-ledger.json")
      expect_accept=false
      case "$mode" in
        legacy|legacy-declared|multi-precheck-legacy|zero-bound|path-hardlink-*|json-distinct-nested|json-bom|bound|lex-crlf|lex-repeated|lex-even-escape|lex-three-spaces|lex-fence-closed|lex-*-empty) expect_accept=true ;;
      esac
      if { [[ "$expect_accept" == false && "$rc" -gt 0 && "$rc" -lt 124 && "$before" == "$after" ]]; } ||
         { [[ "$expect_accept" == true && "$rc" -eq 0 ]] &&
           [[ $(jq '.records | length' "$dir/reports/review-context/identity-ledger.json") -eq 2 ]]; }; then
        printf 'ok: %s %s %s\n' "$runtime" "$role" "$mode"
        passed=$((passed + 1))
      else
        ledger_unchanged=false
        [[ "$before" != "$after" ]] || ledger_unchanged=true
        printf 'not ok: %s %s %s (exit=%s ledger-unchanged=%s)\n' \
          "$runtime" "$role" "$mode" "$rc" "$ledger_unchanged"
        cat "$dir/output.log"
        failed=$((failed + 1))
      fi
    done
  done
done
printf 'ADR admission: passed=%s failed=%s\n' "$passed" "$failed"
# The ordinary entry point must include actual precheck consumers too.
# Preserve the admission result and run both groups even when one is red.
precheck_status=0
generation_status=0
downstream_status=0
if [[ "$#" -eq 0 ]]; then
  bash "$ROOT/tests/impl-review-adr-inputs.tests.sh" --precheck-only || precheck_status=$?
  bash "$ROOT/tests/impl-review-adr-inputs.tests.sh" --generation-only || generation_status=$?
  bash "$ROOT/tests/impl-review-adr-inputs.tests.sh" --downstream-only || downstream_status=$?
fi
[[ "$failed" -eq 0 && "$precheck_status" -eq 0 && "$generation_status" -eq 0 && "$downstream_status" -eq 0 ]]
