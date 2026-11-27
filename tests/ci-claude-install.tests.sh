#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import hashlib
from itertools import groupby
import json
from pathlib import Path
import re
import runpy
import shlex
import shutil
import subprocess
import sys
import tempfile
import zipfile

root = Path(sys.argv[1])
workflow_path = '.github/workflows/test.yml'
fixtures = root / 'tests/fixtures/verification-ci'
package = '@anthropic-ai/claude-code'
released_steps = {
    ('installers', 'Install recorded Claude Code CLI'),
    ('cli-hook-enforcement', 'Install Claude Code CLI'),
}
install_names = {name for _, name in released_steps}
install_verbs = set('install add i in ins inst insta instal isnt isnta isntal isntall'.split())
variable = re.compile(r'\$(?:\{([A-Za-z_]\w*)\}|([A-Za-z_]\w*))')
expression = re.compile(r'\$\{\{\s*(.*?)\s*\}\}')
unknown = '$__UNKNOWN_NPM_INPUT'


def resolve_word(word, settings):
    return variable.sub(lambda m: settings.get(m[1] or m[2], unknown), word)


def workflow_value(value, settings):
    def replace(match):
        key = re.fullmatch(r'env\.([A-Za-z_]\w*)', match[1])
        return settings.get(key[1], unknown) if key else unknown
    return expression.sub(replace, str(value))


def unresolved_install_input(word):
    # A dynamic version leaves the name of a foreign npm package unambiguous.
    spec = re.fullmatch(r'((?:@[a-z0-9][a-z0-9._-]*/)?[a-z0-9][a-z0-9._-]*)@(.+)', word)
    if spec and spec[1] != package:
        return False
    return bool(re.search(r'[$\x60*?\[\]]', word))


def installs_npm_package(command, settings, label):
    if 'npm' not in command:
        return False
    has_install_word = install_verbs.intersection(re.findall(r'\b[a-z]+\b', command))
    if not has_install_word and not re.search(r"""\bnpm\s+(?:-[\w=-]+\s+)*["']?\$""", command):
        return False
    values = dict(settings)
    unconditional = True
    for line in command.replace('\\\n', ' ').splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        lexer = shlex.shlex(line, posix=True, punctuation_chars=';&|()')
        lexer.whitespace_split = True
        for operator, part in groupby(lexer, lambda word: bool(re.fullmatch(r'[;&|()]+', word))):
            words = list(part)
            if operator:
                if words != [';']:
                    unconditional = False
                continue
            assignments = words[1:] if words[:1] == ['export'] else words
            if assignments and all(re.match(r'^[A-Za-z_]\w*=', word) for word in assignments):
                for word in assignments:
                    name, value = word.split('=', 1)
                    values[name] = resolve_word(value, values) if unconditional else unknown
                continue
            if 'npm' not in words:
                if words[:1] == ['set'] and all(re.fullmatch(r'-[eufxo]+|pipefail', word) for word in words[1:]):
                    continue
                unconditional = False
                # An unsupported shell statement can change variables used by a later npm call.
                values.clear()
                continue
            pos = words.index('npm')
            prefixes = words[:pos]
            if prefixes[:1] in (['echo'], ['printf']):
                continue
            args = [resolve_word(word, values) for word in words[pos + 1:]]
            if not install_verbs.intersection(args):
                subcommand = next((word for word in args if not word.startswith('-')), '')
                assert not re.search(r'[$\x60*?\[\]]', subcommand), (
                    f'{label}: cannot resolve npm subcommand from static workflow inputs')
                continue
            assert all(re.match(r'[A-Za-z_]\w*=', word) or word in
                       ('!', 'if', 'then', 'else', 'do', 'command', 'env', 'sudo') for word in prefixes), (
                f'{label}: unsupported npm install command prefix')
            if any(word == package or word.startswith(package + '@') or word == '--allow-scripts=' + package
                   for word in args):
                return True
            assert not any(unresolved_install_input(word) for word in args), (
                f'{label}: cannot resolve npm install target from static workflow inputs')
    return False


def bash_options(job, shell, label):
    if shell == 'bash':
        return ['-eo', 'pipefail']
    if shell is None:
        runner = job.get('runs-on', '')
        labels = [runner] if isinstance(runner, str) else runner
        if isinstance(labels, list):
            if any(re.fullmatch(r'windows(?:-[\w.-]+)?', str(x), re.I) for x in labels):
                shell = 'pwsh'
            elif any(re.fullmatch(r'(?:ubuntu|macos)-[\w.-]+|linux|macOS', str(x), re.I) for x in labels):
                # The implicit POSIX shell uses -e, whereas explicit Bash enables pipefail.
                return ['-e']
    raise AssertionError(f'{label}: cannot verify effective shell {shell!r} for runs-on {job.get("runs-on")!r}')


def install_steps(source, content):
    parsed = subprocess.run(
        ['ruby', '-ryaml', '-rjson', '-e', 'print YAML.safe_load(STDIN.read, aliases: true).to_json'],
        input=content, stdout=subprocess.PIPE, check=True)
    workflow = json.loads(parsed.stdout)
    for job_id, job in workflow['jobs'].items():
        for index, step in enumerate(job.get('steps', []), start=1):
            name = step.get('name', f'step {index}')
            command = step.get('run', '')
            label = f'{source} / {job_id} / {name}'
            settings, static, defaults = {}, {}, {}
            for scope in (workflow, job, step):
                settings.update({key: workflow_value(value, static) for key, value in scope.get('env', {}).items()})
                static = {k: v for k, v in settings.items() if re.fullmatch(r'[-A-Za-z0-9_@./:+]+', v)}
                defaults.update(scope.get('defaults', {}).get('run', {}))
            command = workflow_value(command, static)
            if name not in install_names and not installs_npm_package(command, static, label):
                continue
            assert command and unknown not in command, f'{label}: unresolved npm installation step'
            for scope_name, scope in (('job', job), ('step', step)):
                value = scope.get('continue-on-error', False)
                assert value is False or re.fullmatch(r'\$\{\{\s*false\s*\}\}', str(value)), (
                    f'{label}: {scope_name} continue-on-error must preserve failure')
            options = bash_options(job, step.get('shell', defaults.get('shell')), label)
            pin = settings.get('CLAUDE_CLI_VERSION')
            assert isinstance(pin, str) and re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', pin), (
                f'{label}: invalid CLAUDE_CLI_VERSION: {pin!r}')
            bindings = []
            for key in {m[1] or m[2] for m in variable.finditer(command)} & settings.keys():
                assert key in static and key not in ('PATH', 'HOME', 'CALLS', 'INSTALL_EXIT', 'STARTUP_EXIT',
                                                      'BASH_ENV', 'ENV', 'SHELLOPTS', 'BASHOPTS', 'IFS'), (
                    f'{label}: unsupported environment binding {key}')
                bindings.append(f'{key}={shlex.quote(static[key])}')
            yield job_id, name, label, '\n'.join([*bindings, command]), pin, options


def current_npm_args_match(args, pin):
    flags, operands = [], []
    words = iter(args)
    for word in words:
        if word in ('-g', '--global', '--global=true', '--location=global'):
            flags.append('global')
        elif word == '--location' and next(words, None) == 'global':
            flags.append('global')
        elif word == '--allow-scripts=' + package or (word == '--allow-scripts' and next(words, None) == package):
            flags.append('allow')
        else:
            operands.append(word)
    # The original contract also permits an explicitly unversioned package.
    return (sorted(flags) == ['allow', 'global'] and len(operands) == 2
            and operands[0] in install_verbs and operands[1] in (package, f'{package}@{pin}'))


def exercise(steps, scratch, *, historical=False):
    bash = shutil.which('bash')
    log = scratch / 'calls'
    for _, _, label, command, pin, options in steps:
        for install_exit, startup_exit in ((0, 0), (17, 0), (0, 19)):
            log.write_bytes(b'')
            env = dict(PATH=str(scratch), HOME=str(scratch), CALLS=str(log),
                       INSTALL_EXIT=str(install_exit), STARTUP_EXIT=str(startup_exit),
                       CLAUDE_CLI_VERSION=pin)
            result = subprocess.run([bash, '--noprofile', '--norc', *options, '-c', command],
                                    cwd=scratch, env=env, timeout=10)
            calls = log.read_text().splitlines()
            assert calls == (['npm'] if install_exit else ['npm', 'claude']), (label, install_exit, startup_exit, calls)
            npm_args = (scratch / 'calls.npm.args').read_bytes().decode().split('\0')[:-1]
            if historical:
                assert npm_args == ['install', '-g', '--allow-scripts=' + package, f'{package}@{pin}'], (label, npm_args)
            else:
                assert current_npm_args_match(npm_args, pin), (label, npm_args)
            if install_exit == 0:
                assert (scratch / 'calls.claude.args').read_bytes() == b'--version\0', label
            assert result.returncode == (install_exit or startup_exit), (
                label, install_exit, startup_exit, result.returncode)
            print(f'ok: {label}: install={install_exit}, startup={startup_exit}')


with zipfile.ZipFile(fixtures / 'e2110862f-inputs.zip') as archive:
    released = archive.read(workflow_path)
digest = runpy.run_path(str(fixtures / 'released_inputs.py'))['HASHES'][workflow_path]
assert hashlib.sha256(released).hexdigest() == digest, f'e2110862f: {workflow_path} SHA-256 mismatch'
historical = list(install_steps('e2110862f', released))
assert sorted((job, name) for job, name, *_ in historical) == sorted(released_steps)

with tempfile.TemporaryDirectory(prefix='ci-claude-install-') as directory:
    scratch = Path(directory)
    (scratch / 'env').symlink_to(shutil.which('env'))
    for name, exit_var in (('npm', 'INSTALL_EXIT'), ('claude', 'STARTUP_EXIT')):
        stub = scratch / name
        stub.write_text(f'#!/bin/sh\nprintf "%s\\n" {name} >> "$CALLS"\n'
                        f'printf "%s\\0" "$@" > "$CALLS.{name}.args"\nexit "${exit_var}"\n')
        stub.chmod(0o700)
    exercise(historical, scratch, historical=True)
    print(f'e2110862f Claude npm installation workflow: {len(historical) * 3} passed')
    assert (root / workflow_path).is_file(), workflow_path
    current_count = 0
    for workflow in sorted((root / '.github/workflows').iterdir()):
        if workflow.suffix not in ('.yml', '.yaml'):
            continue
        current = list(install_steps(str(workflow.relative_to(root)), workflow.read_bytes()))
        exercise(current, scratch)
        current_count += len(current)
    print(f'Current Claude npm installation workflow: {current_count} steps, {current_count * 3} passed')
PY
