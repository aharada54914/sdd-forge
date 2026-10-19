"""Read GitHub workflow YAML and prove bounded, explicit suite invocations.

Unknown shell syntax contributes no execution evidence. This is an admission
check for the repository's small command grammar, not a shell interpreter.
"""
import hashlib
import importlib.util
import itertools
import json
from pathlib import Path
import re
import shlex
import subprocess
from typing import Any

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
        options: dict[str, Any] = {}
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
    lines = [line for line in expand_matrix(body, row).splitlines()
             if line.strip() and not line.lstrip().startswith('#')]
    # GitHub pwsh propagates only the final native exit code. Multiple suites
    # must use the runner, which aggregates every result, or separate steps.
    if shell == 'pwsh' and len(lines) != 1:
        return set()
    found = set()
    for line in lines:
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
    errors = [f'{row["path"]}: no admitted execution in {job}'
            for row in catalog['suites'] for job in row.get('ci_jobs', [])
            if row['path'] not in actual.get(job, set())]
    if 'ci-posix-fallback' in catalog['profiles']:
        errors.extend(shard_errors(workflow))
    return errors


def shard_errors(workflow):
    """The complete fallback partition must run and feed the aggregate gate."""
    jobs = workflow['jobs']
    job = jobs.get('posix-unwired-sharded', {})
    needs = jobs.get('required-checks', {}).get('needs', [])
    if isinstance(needs, str):
        needs = [needs]
    if ('posix-unwired-sharded' not in needs or job.get('runs-on') != 'ubuntu-latest'
            or not enabled(job.get('if'), {}, None)
            or job.get('continue-on-error', False) is not False):
        return ['fallback shard job must be unconditional and required']
    rows = matrix_rows(job)
    invocations = []
    for row in rows:
        admitted = []
        for step in job.get('steps', []):
            if (not enabled(step.get('if'), {}, None) or step.get('continue-on-error', False) is not False
                    or step.get('shell') != 'bash' or step.get('working-directory', '.') != '.'):
                continue
            body = expand_matrix(step.get('run', ''), row)
            lines = [line.strip() for line in body.splitlines() if line.strip() and not line.lstrip().startswith('#')]
            if len(lines) != 1 or any(char in body for char in ';|&<>`') or '$(' in body:
                continue
            try:
                tokens = shlex.split(lines[0])
            except ValueError:
                continue
            if len(tokens) < 2 or tokens[0] != 'bash' or tokens[1].removeprefix('./') != 'tests/run-ci-unwired.sh':
                continue
            tokens = tokens[2:]
            options: dict[str, Any] = {}
            while tokens:
                key = tokens.pop(0)
                if key not in ('--shard-index', '--shard-count', '--receipt') or key in options or not tokens:
                    break
                options[key] = tokens.pop(0)
            else:
                index, count = options.get('--shard-index', ''), options.get('--shard-count', '')
                if re.fullmatch(r'[0-9]+', index) and re.fullmatch(r'[1-9][0-9]*', count):
                    admitted.append((int(index), int(count)))
        if len(admitted) != 1:
            return ['each fallback matrix row needs exactly one unconditional shard execution']
        invocations.extend(admitted)
    counts = {count for _, count in invocations}
    indices = [index for index, _ in invocations]
    if len(counts) != 1 or next(iter(counts)) != len(indices) or sorted(indices) != list(range(len(indices))):
        return ['fallback shard indices must cover 0..count-1 exactly once']
    return []



def condition_supported(condition):
    if condition is None or type(condition) is bool:
        return True
    if not isinstance(condition, str):
        return False
    expression = condition.strip()
    if expression.startswith('${{') and expression.endswith('}}'):
        expression = expression[3:-2].strip()
    return all(term.strip() in ('true', 'false') or re.fullmatch(
        r"(runner\.os|matrix\.[a-zA-Z_]+)\s*(==|!=)\s*(['\"])([^'\"]+)\3", term.strip())
        for alternative in expression.split('||') for term in alternative.split('&&'))



def condition_value(condition, row, runner):
    if not condition_supported(condition):
        return None
    if isinstance(condition, str) and any(key not in row for key in re.findall(r'matrix\.([a-zA-Z_]+)', condition)):
        return None
    return enabled(condition, row, runner)

def runner_module():
    spec = importlib.util.spec_from_file_location('verification_runner', Path(__file__).with_name('verification.py'))
    assert spec and spec.loader and spec.origin
    module = importlib.util.module_from_spec(spec)
    # Execute the verified source bytes, never a mutable bytecode cache.
    exec(compile(Path(spec.origin).read_bytes(), spec.origin, 'exec'), module.__dict__)
    return module


def shard_members(body, catalog, weights):
    try:
        tokens = shlex.split(body)
    except ValueError:
        return None
    if tokens[:2] != ['bash', './tests/run-ci-unwired.sh']:
        return None
    tokens = tokens[2:]
    options = {}
    while tokens:
        key = tokens.pop(0)
        if key not in ('--shard-index', '--shard-count', '--receipt') or key in options or not tokens:
            return None
        options[key] = tokens.pop(0)
    if (set(options) != {'--shard-index', '--shard-count', '--receipt'}
            or not re.fullmatch('[0-9]+', options['--shard-index'])
            or not re.fullmatch('[1-9][0-9]*', options['--shard-count'])):
        return None
    index, count = int(options['--shard-index']), int(options['--shard-count'])
    if not 0 <= index < count:
        raise ValueError('invalid fallback shard')
    runner = runner_module()
    if weights is None:
        weights = runner.load_weights(ROOT / 'tests/verification-timings.json')
    return set(runner.shard_suites(catalog['profiles']['ci-posix-fallback'], count, weights)[index])



# Exact baseline verifier command projection, rechecked against the live source
# in T-001. No other shell body obtains this control-only disposition by name.
LEGACY_VERIFIER_COMMAND = '6d256d00b814a57e078c113e5edea91380207aa7728e8b5bc07baefc9066f0e7'


def verifier_job(workflow):
    job = workflow['jobs'].get('required-checks')
    if job is None:
        return
    if (job.get('name') != 'required-checks' or job.get('runs-on') != 'ubuntu-latest'
            or job.get('if') not in ('always()', '${{ always() }}')
            or job.get('continue-on-error', False) is not False or 'strategy' in job
            or not isinstance(job.get('needs'), list)
            or len(job['needs']) != len(set(job['needs']))
            or set(job['needs']) != set(workflow['jobs']) - {'required-checks'}):
        raise ValueError('required-checks must remain the exact always-running orchestration verifier')
    run_steps = [step for step in job.get('steps', []) if 'run' in step]
    if len(run_steps) != 1:
        raise ValueError('workload or extra run step in orchestration verifier')
    step = run_steps[0]
    if (step.get('name') != 'Check all required tests passed' or step.get('if') is not None
            or step.get('continue-on-error', False) is not False):
        raise ValueError('unexpected verifier step identity or condition')
    for item in job['steps']:
        if item is not step and (not isinstance(item.get('uses'), str) or not re.fullmatch(
                'actions/checkout@[0-9a-f]{40}', item['uses'])):
            raise ValueError('only pinned checkout setup is admitted beside the verifier')


def aggregate_command(body):
    # A single argv invocation, not a shell program or arbitrary job exemption.
    if any(c in body.strip() for c in '\n;|&<>`') or '$(' in body:
        return False
    try:
        args = shlex.split(body)
    except ValueError:
        return False
    if args[:4] != ['python3', '-B', 'tests/verification-ci.py', 'aggregate']:
        return False
    args = args[4:]
    required = {'--root', '--plan', '--observations', '--run-id', '--api-head-sha'}
    options = {}
    while args:
        key = args.pop(0)
        if key not in required | {'--output'} or key in options or not args:
            return False
        value = args.pop(0)
        if not re.fullmatch(r'(?:[A-Za-z0-9_./-]+|\$[A-Z_][A-Z0-9_]*(?:/[A-Za-z0-9_./-]+)?)', value):
            return False
        options[key] = value
    return required.issubset(options)


def plan_obligations(workflow, catalog, weights=None):
    return plan_inventory(workflow, catalog, weights)[0]


def control_dispositions(workflow, catalog, weights=None):
    return plan_inventory(workflow, catalog, weights)[1]

def plan_inventory(workflow, catalog, weights=None):
    """Inventory direct run steps without executing them or inferring unknown shell.

    Unknown commands remain indivisible non-suite obligations, never permission
    to omit work. A9 activation is separately interpreted by the aggregate.
    """
    verifier_job(workflow)
    obligations, controls = [], []
    seen = set()
    targets = {'ubuntu-latest': 'Linux', 'macos-latest': 'macOS', 'windows-latest': 'Windows'}
    for job_id, job in workflow['jobs'].items():
        rows = matrix_rows(job)
        if not rows:
            raise ValueError('unsupported or empty workflow matrix')
        for row in rows:
            if any(not isinstance(k, str) or type(v) not in (str, int, float, bool)
                   for k, v in row.items()):
                raise ValueError('invalid matrix scalar')
            target = expand_matrix(job.get('runs-on', ''), row)
            if target not in targets:
                raise ValueError('unsupported workflow runner')
            runner = targets[target]
            if condition_value(job.get('if'), row, runner) is False:
                continue
            defaults = dict(workflow.get('defaults', {}).get('run', {}))
            defaults.update(job.get('defaults', {}).get('run', {}))
            names = set()
            for step in job.get('steps', []):
                if 'run' not in step:
                    continue
                name = step.get('name')
                if not isinstance(name, str) or not name.strip() or name in names:
                    raise ValueError('run step needs a unique nonempty name')
                names.add(name)
                best_effort = (job.get('continue-on-error', False), step.get('continue-on-error', False))
                if any(type(value) is not bool for value in best_effort):
                    raise ValueError('unsupported continue-on-error in workload inventory')
                # Only proven best-effort work is exempt from required success.
                if any(best_effort):
                    continue
                condition = step.get('if')
                if condition_value(condition, row, runner) is False:
                    continue
                shell = step.get('shell', defaults.get('shell', 'pwsh' if runner == 'Windows' else 'bash'))
                shell = expand_matrix(shell, row)
                name = expand_matrix(name, row)
                body = expand_matrix(step['run'], row).replace('\r\n', '\n')
                env = {}
                for source in (workflow, job, step):
                    for key, value in source.get('env', {}).items():
                        env[key] = expand_matrix(value, row) if isinstance(value, str) else value
                command = {'run': body, 'shell': shell, 'env': env}
                suites = (step_suites(step, catalog, row, shell)
                          if step.get('working-directory', defaults.get('working-directory', '.')) == '.' else set())
                shard = shard_members(body, catalog, weights) if shell == 'bash' else None
                if shard is not None:
                    suites = shard
                identity = {'job': job_id, 'matrix': row, 'step': name}
                def encode(value):
                    return json.dumps(value, sort_keys=True, separators=(',', ':'),
                                      ensure_ascii=False, allow_nan=False).encode('utf-8')
                oid = job_id + ':' + hashlib.sha256(encode(identity)).hexdigest()
                if oid in seen:
                    raise ValueError('duplicate expanded obligation identity')
                seen.add(oid)
                obligation = dict(id=oid, job=job_id, matrix=row, runner=target,
                                        step=name, command_sha256=hashlib.sha256(encode(command)).hexdigest(),
                                        suites=sorted(suites),
                                        receipt_required=shard is not None or (bool(suites) and 'tests/verification.py' in body))
                if job_id == 'required-checks':
                    if (shell != 'bash' or step.get('working-directory', defaults.get('working-directory', '.')) != '.'
                            or suites or not (obligation['command_sha256'] == LEGACY_VERIFIER_COMMAND or aggregate_command(body))):
                        raise ValueError('unrecognized work in orchestration verifier')
                    controls.append({**obligation, 'disposition': 'orchestration-verifier'})
                else:
                    obligations.append(obligation)
    if not obligations:
        raise ValueError('empty workflow obligation inventory')
    return obligations, controls
