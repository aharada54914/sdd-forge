"""Isolated candidate contract tests, not native host permission/identity proof."""
from pathlib import Path
import copy
import hashlib
import importlib.util
import json
import os
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
Q = 'plugins/sdd-quality-loop/scripts/'
MANIFEST = 'reports/review-context/fixture.json'
RECEIPT = MANIFEST + '.receipt.txt'


def sha(value):
    return hashlib.sha256(value).hexdigest()


def receipt(m):
    joined = '\n'.join(e['path'] + '\t' + e['sha256'] for e in m['allowed_input_manifest'])
    text = f"{m['sequence']}|spec|{m['role']}|{m['run_id']}|{m['host_session_id']}|{m['previous_record_sha256']}|allowed-inputs-v1|{sha(joined.encode())}"
    return f"REVIEW_CONTEXT_OK {sha(text.encode())} sequence={m['sequence']} previous_record_sha256={m['previous_record_sha256']} pre_append_tip_sequence={m['sequence'] - 1} identity_unique=yes\n"


def setup(root):
    paths = ['specs/demo/requirements.md', 'specs/demo/acceptance-tests.md',
             'plugins/sdd-review-loop/references/spec-review-calibration.md',
             'reports/spec-review/demo/attempt-1/round-1/precheck-result.json']
    entries = []
    for path in paths:
        full = root / path
        full.parent.mkdir(parents=True, exist_ok=True)
        data = ('fixture: ' + path + '\n').encode()
        full.write_bytes(data)
        entries.append({'path': path, 'sha256': sha(data)})
    m = {'schema': 'review-context-invocation/v2', 'stage': 'spec', 'role': 'spec-reviewer-a',
         'feature': 'demo', 'run_id': 'synthetic-run', 'host_session_id': 'synthetic-host',
         'read_only': True, 'input_mode': 'file-manifest', 'fallback_mode': 'none',
         'identity_ledger_path': 'reports/review-context/identity-ledger.json',
         'identity_ledger_sha256': 'a' * 64, 'previous_record_sha256': 'b' * 64,
         'sequence': 2, 'allowed_input_manifest': entries}
    (root / MANIFEST).parent.mkdir(parents=True)
    return m


def snapshot(root):
    return {str(p.relative_to(root)): ('link', os.readlink(p)) if p.is_symlink() else
            ('dir',) if p.is_dir() else ('file', sha(p.read_bytes())) for p in root.rglob('*')}


def argv(kind, root, baseline=False):
    source = HERE / ('baseline' if baseline else 'candidate') / Q
    if kind == 'bash':
        return ['rtk', 'proxy', 'bash', str(source / 'validate-review-context-set.sh'), MANIFEST, str(root), '--reviewer-receipt', RECEIPT]
    return ['rtk', 'proxy', 'pwsh', '-NoLogo', '-NoProfile', '-File', str(source / 'validate-review-context-set.ps1'),
            '-Manifest', MANIFEST, '-RepositoryRoot', str(root), '-ReviewerReceipt', RECEIPT]


def run_case(name, mutate, expected, kinds=('bash', 'pwsh')):
    for kind in kinds:
        with tempfile.TemporaryDirectory(prefix='a8-digest-fixture-') as temp:
            root = Path(temp).resolve()
            m = setup(root)
            raw = receipt(m)
            raw, extra, manifest_override = mutate(root, m, raw)
            (root / MANIFEST).write_text(json.dumps(m) if manifest_override is None else manifest_override)
            (root / RECEIPT).write_text(raw)
            before = snapshot(root)
            proc = subprocess.run(argv(kind, root) + extra, cwd=root, capture_output=True, text=True)
            assert (proc.returncode == 0) == expected, (kind, name, proc.returncode, proc.stdout, proc.stderr)
            assert snapshot(root) == before, (kind, name, 'unexpected write')
            if expected:
                assert proc.stdout.startswith('REVIEWER_DIGEST_OK ') and not proc.stderr
                assert 'REVIEW_CONTEXT_OK' not in proc.stdout
            else:
                assert 'REVIEWER_DIGEST_OK' not in proc.stdout
            print(kind, name, 'expected-accept' if expected else 'expected-reject')


def mutation(fn, renew=False):
    def apply(root, m, raw):
        fn(root, m)
        return (receipt(m) if renew else raw), [], None
    return apply


def main():
    assert shutil.which('pwsh'), 'PowerShell parity must run, not silently skip'
    run_case('valid-A-no-ledger', lambda r, m, raw: (raw, [], None), True)

    def reviewer_b(root, m):
        m['role'] = 'spec-reviewer-b'
        path = 'reports/spec-review/demo/attempt-1/round-1/integrated-summary.json'
        (root / path).write_bytes(b'{"checks":[]}\n')
        m['allowed_input_manifest'].append({'path': path, 'sha256': sha((root / path).read_bytes())})
    run_case('valid-B-no-ledger', mutation(reviewer_b, True), True)
    run_case('changed-bytes', mutation(lambda r, m: (r / m['allowed_input_manifest'][0]['path']).write_bytes(b'changed')), False)
    run_case('missing-input', mutation(lambda r, m: (r / m['allowed_input_manifest'][0]['path']).unlink()), False)
    for key, value in [('run_id', 'other'), ('host_session_id', 'other'), ('sequence', 3),
                       ('previous_record_sha256', 'c' * 64), ('read_only', False), ('stage', 'impl')]:
        run_case('changed-' + key, mutation(lambda r, m, k=key, v=value: m.update({k: v})), False)
    run_case('reordered-inputs', mutation(lambda r, m: m['allowed_input_manifest'].reverse()), False)
    run_case('removed-input', mutation(lambda r, m: m['allowed_input_manifest'].pop()), False)
    run_case('duplicate-input', mutation(lambda r, m: m['allowed_input_manifest'].append(copy.deepcopy(m['allowed_input_manifest'][0])), True), False)
    for path in ['reports/review-context/identity-ledger.json', 'reports/spec-review/demo/attempt-1/round-1/reviewer-a.json', '../secret',
                 'specs/other/requirements.md', 'Specs/demo/requirements.md']:
        run_case('bad-path-' + path, mutation(lambda r, m, p=path: m['allowed_input_manifest'][0].update(path=p), True), False)
    for label, change in [('unique-no', lambda s: s.replace('unique=yes', 'unique=no')),
                          ('wrong-tip', lambda s: s.replace('tip_sequence=1', 'tip_sequence=9')),
                          ('extra-receipt-line', lambda s: s + 'extra\n'),
                          ('changed-record', lambda s: s.replace('REVIEW_CONTEXT_OK ', 'REVIEW_CONTEXT_OK f', 1))]:
        run_case(label, lambda r, m, raw, f=change: (f(raw), [], None), False)
    run_case('duplicate-json-key', lambda r, m, raw: (raw, [], json.dumps(m)[:-1] + ',"role":"spec-reviewer-a"}'), False)

    def link(root, m, hard=False):
        path = root / m['allowed_input_manifest'][0]['path']
        source = root / 'source'
        path.rename(source)
        if hard:
            os.link(source, path)
        else:
            path.symlink_to(source)
    run_case('symlink-input', mutation(link), False)
    run_case('hardlink-input', mutation(lambda r, m: link(r, m, True)), False)
    run_case('extra-reserve-option', lambda r, m, raw: (raw, ['--reserve'], None), False, ('bash',))
    run_case('extra-reserve-option', lambda r, m, raw: (raw, ['-Reserve'], None), False, ('pwsh',))
    # Rejected old-mode input gives identical status/stdout/stderr before/after.
    with tempfile.TemporaryDirectory(prefix='a8-digest-old-mode-') as temp:
        root = Path(temp).resolve()
        m = setup(root)
        (root / MANIFEST).write_text(json.dumps(m))
        for kind in ('bash', 'pwsh'):
            results = []
            for old in (True, False):
                command = argv(kind, root, old)[:-2]
                proc = subprocess.run(command, cwd=root, text=True, capture_output=True)
                results.append((proc.returncode, proc.stdout, proc.stderr))
            assert results[0] == results[1] and results[0][0] != 0, (kind, results)
            print(kind, 'ordinary-mode-rejection-unchanged')

    spec = importlib.util.spec_from_file_location('candidate_launcher', HERE / 'idle_launcher_candidate.py')
    launcher = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(launcher)
    launcher.ROOT = HERE / 'candidate'
    for role in ('spec-reviewer-a', 'spec-reviewer-b'):
        args, _ = launcher.allocation_args(role)
        command = launcher.digest_command(role)
        assert args[args.index('--allowedTools') + 1] == 'Bash(' + command + ')'
        assert not any(c in command for c in ('*', '\t', '\n', '|', ';', '$', '`'))
        assert args[args.index('--permission-mode') + 1] == 'dontAsk'
        definition = json.loads(args[args.index('--agents') + 1])[role]
        assert definition['tools'] == ['Read', 'Grep', 'Glob', 'Bash']
    print('launcher fixed rule/role checks passed; native matcher NOT TESTED')
    for path, value in json.loads((HERE / 'baseline-hashes.json').read_text()).items():
        assert sha((ROOT / path).read_bytes()) == value, 'original modified: ' + path
    print('protected originals unchanged')


if __name__ == '__main__':
    main()
