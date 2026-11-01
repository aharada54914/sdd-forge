#!/usr/bin/env python3
"""Tracked-file census and native-tool adapters; not a product gate registry."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from verification import unique_object

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = {'.sh': 'bash', '.bash': 'bash', '.ps1': 'powershell', '.psm1': 'powershell',
             '.py': 'python', '.ts': 'typescript', '.tsx': 'typescript', '.js': 'javascript',
             '.mjs': 'javascript', '.cjs': 'javascript', '.json': 'json', '.yml': 'yaml',
             '.yaml': 'yaml', '.md': 'markdown'}
FENCES = {'sh': 'bash', 'shell': 'bash', 'bash': 'bash', 'ps1': 'powershell',
          'powershell': 'powershell', 'python': 'python', 'py': 'python',
          'js': 'javascript', 'javascript': 'javascript', 'ts': 'typescript',
          'typescript': 'typescript', 'json': 'json', 'yaml': 'yaml', 'yml': 'yaml'}


def git(root, *args):
    return subprocess.run(['git', *args], cwd=root, check=True, capture_output=True,
                          timeout=60).stdout


def classify(path, raw):
    """Classification is routing, never evidence that a file complies."""
    parts = Path(path).parts
    language = LANGUAGES.get(Path(path).suffix.lower())
    surfaces = {language} if language else set()
    text = raw.decode('utf-8', errors='replace')
    if text.startswith('#!'):
        first = text.splitlines()[0]
        matched = next((lang for token, lang in [('python', 'python'), ('bash', 'bash'),
                      ('/sh', 'bash'), ('pwsh', 'powershell'), ('node', 'javascript')]
                        if token in first), 'unknown-shebang')
        surfaces.add(matched)
    if language == 'markdown':
        for label in re.findall(r'^\s*```([^\s`]*)[^\n]*$', text, re.M):
            if label:
                surfaces.add('embedded:' + FENCES.get(label.lower(), 'unknown'))
    if path.startswith('.github/workflows/'):
        surfaces.add('workflow')
    if 'human-copy' in parts or 'human-copy-candidate' in parts:
        return 'protected-human-copy', surfaces, 'Reviewed application bundle; use existing mirror/application owner.'
    if parts[0] in {'specs', 'reports', 'research'}:
        return 'historical', surfaces, 'Specification/research/evidence record; inspect references before changing recorded bytes.'
    if parts[0] == 'tests':
        return 'current-test', surfaces, 'Executable test or test input; bad fixtures need a specific control, not blanket exclusion.'
    if 'templates' in parts or 'template' in parts:
        return 'current-template', surfaces, 'Distributed template; unresolved placeholders need contextual review.'
    if language in {'bash', 'powershell', 'python', 'typescript', 'javascript'}:
        return 'current-code', surfaces, 'Live source or distributed executable (including generated outputs).'
    if language in {'json', 'yaml'} or Path(path).suffix in {'.toml', '.ini', '.cfg'}:
        return 'current-config', surfaces, 'Current configuration or structured input.'
    if language == 'markdown' or surfaces:
        return 'current-guidance', surfaces, 'Current prose or embedded executable surface requires contextual review.'
    return 'asset', surfaces, 'No recognized executable surface; classification still requires review.'


def census(root):
    root = root.resolve()
    entries = []
    for record in git(root, 'ls-files', '--stage', '-z').split(b'\0'):
        if not record:
            continue
        metadata, encoded = record.split(b'\t', 1)
        mode, blob, stage = metadata.decode('ascii').split()
        path = encoded.decode('utf-8')
        candidate = root / path
        if stage != '0' or mode not in {'100644', '100755', '120000'}:
            raise ValueError('unmerged, symlink or unsupported tracked file: ' + repr(path))
        if mode == '120000':
            if not candidate.is_symlink():
                raise ValueError('tracked symlink changed type: ' + repr(path))
            raw = os.fsencode(os.readlink(candidate))
            entries.append({'path': path, 'git_blob': blob, 'source_sha256': hashlib.sha256(raw).hexdigest(),
                            'classification': 'asset', 'surfaces': ['symlink'], 'state': 'needs-review',
                            'owner_issue': None, 'evidence': [],
                            'reason': 'Symlink target not followed or counted twice; review link contract separately.'})
            continue
        if not candidate.resolve().is_relative_to(root) or candidate.is_symlink():
            raise ValueError('tracked file escapes repository: ' + repr(path))
        raw = candidate.read_bytes()
        classification, surfaces, reason = classify(path, raw)
        entries.append({'path': path, 'git_blob': blob, 'source_sha256': hashlib.sha256(raw).hexdigest(),
                        'classification': classification, 'surfaces': sorted(surfaces),
                        'state': 'unreviewed', 'owner_issue': None, 'evidence': [], 'reason': reason})
    if not entries:
        raise ValueError('empty tracked population')
    return {'schema': 'coding-standards-population/v1',
            'base_commit': git(root, 'rev-parse', '--verify', 'HEAD').decode().strip(),
            'generated_at': datetime.now(timezone.utc).isoformat(), 'entries': entries}


def load_tools(root):
    config = json.loads((root / 'tests/coding-standards/tools.json').read_text(), object_pairs_hook=unique_object)
    if (set(config) != {'schema', 'ruff_version', 'shellcheck_version', 'shellcheck_codes', 'exceptions'}
            or config['schema'] != 'coding-standards-tools/v1'
            or config['ruff_version'] != '0.13.3' or config['shellcheck_version'] != '0.11.0'
            or config['shellcheck_codes'] != ['SC2086', 'SC2046', 'SC2155']):
        raise ValueError('invalid native tool configuration')
    for row in config['exceptions']:
        if (not isinstance(row, dict) or set(row) != {'path', 'sha256', 'tools', 'reason', 'control'}
                or not row['reason'].strip() or row['tools'] != ['ruff']
                or Path(row['path']).is_absolute() or '..' in Path(row['path']).parts
                or Path(row['control']).is_absolute() or '..' in Path(row['control']).parts
                or not (root / row['path']).resolve().is_relative_to(root.resolve())
                or (root / row['path']).is_symlink()
                or not (root / row['control']).resolve().is_relative_to(root.resolve())
                or not (root / row['control']).is_file()
                or hashlib.sha256((root / row['path']).read_bytes()).hexdigest() != row['sha256']):
            raise ValueError('invalid or stale bounded exception')
    return config


def invoke(command, root, *, stdin=None):
    result = subprocess.run(command, cwd=root, input=stdin, text=True, capture_output=True, timeout=120)
    if result.returncode not in (0, 1):
        raise ValueError('native tool execution failed: ' + command[0])
    return result


def scan(root, mode, base, language):
    population = census(root)
    config = load_tools(root)
    rows = population['entries']
    if mode == 'diff':
        # Reuse the existing NUL-safe git revision selector; absence is not zero changes.
        import importlib.util
        spec = importlib.util.spec_from_file_location('verification_impact', ROOT / 'tests/verification-impact.py')
        impact = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(impact)
        changed, status = impact.changed_paths(root, base, 'HEAD')
        if status != 'diff-available':
            raise ValueError('diff base unavailable; fetch history or run all mode')
        # Include staged/unstaged tracked edits: daily feedback inspects current bytes too.
        changed.update(git(root, 'diff', '--no-renames', '--name-only', '-z', 'HEAD', '--')
                       .decode('utf-8').split('\0'))
        rows = [row for row in rows if row['path'] in changed]
    supported = {'python', 'bash', 'powershell', 'typescript', 'javascript'}
    languages = supported if language == 'all' else {language}
    selected = [row for row in rows if row['classification'].startswith('current-')
                and languages.intersection(row['surfaces'])]
    result = {'schema': 'coding-standards-scan/v1', 'mode': mode,
              'revision': population['base_commit'], 'status': 'complete',
              'population_count': len(population['entries']), 'selected_count': len(selected),
              'inspected_count': 0, 'excluded': [], 'findings': [], 'tools': [],
              'manual_review': 'unknown', 'manual_unreviewed_count': len(population['entries']),
              'outside_native_selection_count': len(rows) - len(selected), 'finding_count': None}
    for lang in sorted(languages):
        files = [row['path'] for row in selected if lang in row['surfaces']]
        if not files:
            result['tools'].append({'language': lang, 'status': 'no-targets', 'target_count': 0})
            continue
        before_findings = len(result['findings'])
        if lang == 'python':
            version = invoke(['ruff', '--version'], root).stdout.strip()
            if version != 'ruff ' + config['ruff_version']:
                raise ValueError('unsupported Ruff version')
            excluded = {row['path'] for row in config['exceptions'] if 'ruff' in row['tools']}
            result['excluded'].extend(row for row in config['exceptions'] if row['path'] in files)
            files = [path for path in files if path not in excluded]
            if not files:
                result['tools'].append({'language': lang, 'status': 'bounded-exceptions-only',
                                        'version': version, 'target_count': 0})
                continue
            output = invoke(['ruff', 'check', '--no-cache', '--config',
                             str(root / 'tests/shared-launch-python/pyproject.toml'),
                             '--output-format=json', '--', *files], root)
            diagnostics = json.loads(output.stdout)
            if not isinstance(diagnostics, list):
                raise ValueError('invalid Ruff output')
            for row in diagnostics:
                result['findings'].append({'path': Path(row['filename']).relative_to(root).as_posix(),
                    'line': row['location']['row'], 'column': row['location']['column'],
                    'native_rule': row['code'], 'rule_id': 'CS-020', 'message': row['message'],
                    'tool': 'ruff', 'version': version})
        elif lang == 'bash':
            version = invoke(['shellcheck', '--version'], root).stdout
            if 'version: ' + config['shellcheck_version'] + '\n' not in version:
                raise ValueError('unsupported ShellCheck version')
            version = config['shellcheck_version']
            output = invoke(['shellcheck', '--format=json1', '--norc',
                             '--include=' + ','.join(config['shellcheck_codes']), '--', *files], root)
            diagnostics = json.loads(output.stdout)['comments']
            for row in diagnostics:
                result['findings'].append({'path': row['file'], 'line': row['line'],
                    'column': row['column'], 'native_rule': 'SC' + str(row['code']),
                    'rule_id': 'CS-019' if row['code'] == 2155 else 'CS-001',
                    'message': row['message'], 'tool': 'shellcheck', 'version': version})
            # Include filtering must never turn a syntax failure into an empty PASS.
            for path in files:
                syntax = invoke(['bash', '-n', '--', path], root)
                if syntax.returncode:
                    result['findings'].append({'path': path, 'line': 1, 'column': 1,
                        'native_rule': 'bash-syntax', 'rule_id': 'CS-019',
                        'message': 'Bash syntax error', 'tool': 'bash', 'version': 'native'})
        elif lang in {'typescript', 'javascript'}:
            output = invoke(['node', str(root / 'tests/coding-standards/typescript.mjs')], root,
                            stdin=json.dumps([str(root / path) for path in files]))
            diagnostics = json.loads(output.stdout)
            version = diagnostics['version']
            for row in diagnostics['findings']:
                result['findings'].append({'path': Path(row['path']).relative_to(root).as_posix(),
                    'line': row['line'], 'column': row['column'], 'native_rule': row['code'],
                    'rule_id': 'CS-021', 'message': row['message'], 'tool': 'typescript', 'version': version})
        else:
            output = invoke(['pwsh', '-NoProfile', '-File',
                             str(root / 'tests/coding-standards/powershell.ps1')], root,
                            stdin=json.dumps([str(root / path) for path in files]))
            diagnostics = json.loads(output.stdout)
            version = diagnostics['version']
            if diagnostics['analyzer_version'] != '1.25.0':
                raise ValueError('unsupported PSScriptAnalyzer version')
            if not version.startswith('7.'):
                raise ValueError('unsupported PowerShell runtime')
            for row in diagnostics['findings']:
                result['findings'].append({'path': Path(row['path']).relative_to(root).as_posix(),
                    'line': row['line'], 'column': row['column'], 'native_rule': row['code'],
                    'rule_id': {'PSAvoidUsingInvokeExpression': 'CS-001',
                                'PSAvoidAssignmentToAutomaticVariable': 'CS-012',
                                'PSAvoidUsingPlainTextForPassword': 'CS-010'}.get(row['code'], 'CS-019'),
                    'message': row['message'], 'tool': 'PSScriptAnalyzer/native-parser',
                    'version': version + '/1.25.0'})
        if output.returncode == 1 and len(result['findings']) == before_findings:
            raise ValueError('tool failed without parsed diagnostics')
        result['inspected_count'] += len(files)
        result['tools'].append({'language': lang, 'status': 'executed', 'version': version,
                                'target_count': len(files)})
    for finding in result['findings']:
        finding['reference'] = 'docs/contributor/coding-standards/common.md#' + finding['rule_id'].lower()
    result['finding_count'] = len(result['findings'])
    result['status'] = 'violations' if result['findings'] else 'complete'
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['census', 'scan'])
    parser.add_argument('--root', type=Path, default=ROOT)
    parser.add_argument('--mode', choices=['all', 'diff'], default='all')
    parser.add_argument('--base')
    parser.add_argument('--language', choices=['all', 'bash', 'python', 'powershell', 'typescript', 'javascript'], default='all')
    args = parser.parse_args()
    try:
        result = census(args.root) if args.command == 'census' else scan(
            args.root.resolve(), args.mode, args.base, args.language)
        print(json.dumps(result, ensure_ascii=True, indent=2))
        if result.get('findings'):
            return 1
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError) as error:
        print(json.dumps({'schema': 'coding-standards-scan/v1', 'status': 'error',
                          'reason': str(error), 'finding_count': None,
                          'inspected_count': None, 'unexecuted_count': None}), file=sys.stderr)
        return 2
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
