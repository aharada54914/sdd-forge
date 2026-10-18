"""Read GitHub workflow YAML and prove bounded, explicit suite invocations.

Unknown shell syntax contributes no execution evidence. This is an admission
check for the repository's small command grammar, not a shell interpreter.
"""
import itertools
import json
from pathlib import Path
import re
import shlex
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def load_workflow(path, root=ROOT):
    script = """const fs = require('fs');
const yaml = require(process.argv[1]);
process.stdout.write(JSON.stringify(yaml.load(fs.readFileSync(process.argv[2], 'utf8'))));"""
    result = subprocess.run(['node', '-e', script,
                             str(root / 'mcp/sdd-forge-mcp/node_modules/js-yaml'), str(path)],
                            capture_output=True, text=True, timeout=20)
    if result.returncode:
        raise ValueError('workflow YAML parser failed; install the pinned sdd-forge-mcp dependencies')
    value = json.loads(result.stdout)
    if not isinstance(value, dict) or not isinstance(value.get('jobs'), dict):
        raise ValueError('workflow must contain a jobs mapping')
    return value


def matrix_rows(job):
    matrix = job.get('strategy', {}).get('matrix', {})
    if not isinstance(matrix, dict):
        return []
    axes = {k: v for k, v in matrix.items() if k not in ('include', 'exclude')}
    if any(not isinstance(v, list) or not v for v in axes.values()):
        return []
    # The live workflow uses either Cartesian axes or include-only rows.
    # Mixed include/axes is deliberately not inferred.
    if axes and 'include' in matrix:
        return []
    rows = ([dict(zip(axes, values)) for values in itertools.product(*axes.values())]
            if axes else matrix.get('include', [{}]))
    if not isinstance(rows, list) or any(not isinstance(row, dict) for row in rows):
        return []
    excluded = matrix.get('exclude', [])
    return [row for row in rows if not any(all(row.get(k) == v for k, v in skip.items())
                                          for skip in excluded)]


def expand_matrix(value, row):
    return re.sub(r'\$\{\{\s*matrix\.([a-zA-Z_]+)\s*\}\}',
                  lambda m: str(row.get(m[1], '${{ unknown }}')), value)


def enabled(condition, row, runner):
    if condition is None or condition is True:
        return True
    if condition is False or not isinstance(condition, str):
        return False
    expression = condition.strip()
    if expression.startswith('${{') and expression.endswith('}}'):
        expression = expression[3:-2].strip()
    terms = []
    for alternative in expression.split('||'):
        values = []
        for term in alternative.split('&&'):
            term = term.strip()
            if term in ('true', 'false'):
                values.append(term == 'true')
                continue
            match = re.fullmatch(r"(runner\.os|matrix\.([a-zA-Z_]+))\s*(==|!=)\s*(['\"])([^'\"]+)\4", term)
            if not match:
                return False
            actual = runner if match[1] == 'runner.os' else row.get(match[2])
            if actual is None:
                return False
            values.append((actual == match[5]) if match[3] == '==' else (actual != match[5]))
        terms.append(all(values))
    return any(terms)


def command_suites(command, catalog, shell='bash'):
    """Return a set for one recognized command, None for unsupported syntax."""
    command = command.strip()
    if not command or command.startswith('#'):
        return set()
    if command == 'set -euo pipefail':
        return set()
    # Existing Bash logs use this exact pipe shape; no other shell operators
    # establish execution. The workflow's Bash shell supplies pipefail.
    pipe = re.fullmatch(r'(.*?) 2>&1 \| tee "\$\{\{ runner\.temp \}\}/[A-Za-z0-9._-]+\.log"', command)
    if pipe:
        command = pipe[1]
    if any(char in command for char in ';|&<>`') or '$(' in command:
        return None
    # Quotes are arguments, never a way to turn a quoted prose command into code.
    if not re.match(r'(?:python3?|bash|\./tests/|tests/)', command):
        return None
    try:
        args = shlex.split(command)
    except ValueError:
        return None
    if not args:
        return set()
    interpreter = None
    if args[0] in ('python', 'python3', 'bash'):
        interpreter = args.pop(0)
        if args and interpreter.startswith('python') and args[0] == '-B':
            args.pop(0)
        if interpreter == 'bash' and args[:1] == ['-n']:
            return set() if len(args) == 2 else None
    if not args:
        return None
    path = args.pop(0).removeprefix('./')
    if path == 'tests/verification.py' and interpreter in ('python', 'python3'):
        options = {}
        while args:
            key = args.pop(0)
            if key in options:
                return None
            if key == '--run':
                options[key] = True
            elif key in ('--profile', '--suite', '--receipt') and args:
                options[key] = args.pop(0)
            else:
                return None
        if not options.get('--run') or ('--profile' in options) == ('--suite' in options):
            return None
        if '--profile' in options:
            members = catalog['profiles'].get(options['--profile'])
            return set(members) if isinstance(members, list) else None
        return {options['--suite']} if options['--suite'] in {r['path'] for r in catalog['suites']} else None
    rows = {r['path']: r for r in catalog['suites']}
    if path not in rows:
        return None
    runtime = rows[path]['runtime']
    if runtime == 'python' and interpreter not in ('python', 'python3'):
        return None
    if runtime == 'powershell' and (interpreter is not None or shell != 'pwsh'):
        return None
    if runtime == 'bash' and (interpreter not in ('bash', None) or (interpreter is None and shell != 'bash')):
        return None
    expected = rows[path].get('args', [])
    if args == expected:
        return {path}
    if path == 'tests/issue311-scratch-isolation.tests.py' and args == ['--repo', '$GITHUB_WORKSPACE']:
        return {path}
    if path == 'tests/install.tests.ps1' and len(args) == 2 and args[0] == '-Lane' and args[1] in ('all', 'core', 'clients', 'context', 'mcp'):
        return {path}
    return None


def step_suites(step, catalog, row, shell):
    body = step.get('run')
    if not isinstance(body, str) or shell not in ('bash', 'pwsh'):
        return set()
    found = set()
    for line in expand_matrix(body, row).splitlines():
        result = command_suites(line, catalog, shell)
        if result is None:
            return set()
        found.update(result)
    return found


def workflow_coverage(workflow, catalog):
    coverage = {}
    for name, job in workflow['jobs'].items():
        found = set()
        for row in matrix_rows(job):
            target = expand_matrix(job.get('runs-on', ''), row)
            runner = {'ubuntu-latest': 'Linux', 'windows-latest': 'Windows', 'macos-latest': 'macOS'}.get(target)
            if not runner or not enabled(job.get('if'), row, runner) or job.get('continue-on-error', False) is not False:
                continue
            defaults = dict(workflow.get('defaults', {}).get('run', {}))
            defaults.update(job.get('defaults', {}).get('run', {}))
            for step in job.get('steps', []):
                if not enabled(step.get('if'), row, runner) or step.get('continue-on-error', False) is not False:
                    continue
                if step.get('working-directory', defaults.get('working-directory', '.')) != '.':
                    continue
                shell = step.get('shell', defaults.get('shell', 'pwsh' if runner == 'Windows' else 'bash'))
                found.update(step_suites(step, catalog, row, shell))
        coverage[name] = found
    return coverage


def coverage_errors(workflow, catalog):
    actual = workflow_coverage(workflow, catalog)
    return [f'{row["path"]}: no admitted execution in {job}'
            for row in catalog['suites'] for job in row.get('ci_jobs', [])
            if row['path'] not in actual.get(job, set())]
