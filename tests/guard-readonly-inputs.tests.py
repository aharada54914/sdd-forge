#!/usr/bin/env python3
"""Actual-runtime decisions for shipped Python reader inputs and trust failures."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'plugins/sdd-quality-loop'
PARSER = argparse.ArgumentParser()
PARSER.add_argument('--runtime', action='append', choices=('python', 'node', 'powershell'))
PARSER.add_argument('--powershell', default='pwsh')
OPTIONS, REMAINING = PARSER.parse_known_args()
RUNTIMES = OPTIONS.runtime or ['python', 'node', 'powershell']


class ReaderInputs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='sdd-reader-inputs-')
        cls.root = Path(cls.temp.name)
        cls.package = cls.root / 'plugins/sdd-quality-loop'
        cls.scripts = cls.package / 'scripts'
        cls.scripts.mkdir(parents=True)
        (cls.package / 'references').mkdir()
        for filename in ('sdd-hook-guard.py', 'sdd-hook-guard.js', 'sdd-hook-guard.ps1',
                         'classify-readonly-inputs.py', 'validate-approval-sidecar.py',
                         'canonicalize-sdd-yaml.py', 'validate-capability-registry.py'):
            shutil.copyfile(SOURCE / 'scripts' / filename, cls.scripts / filename)
        shutil.copytree(SOURCE / 'scripts/generated', cls.scripts / 'generated')
        shutil.copyfile(SOURCE / 'references/readonly-input-contracts.json', cls.package / 'references/readonly-input-contracts.json')
        cls.environ = {k: v for k, v in os.environ.items() if k not in ('PAYLOAD', 'SDD_SUDO')}
        cls.environ['CLAUDE_PROJECT_DIR'] = str(cls.root)
        cls.commands = {
            'python': [shutil.which('python3') or 'python', str(cls.scripts / 'sdd-hook-guard.py')],
            'node': ['node', str(cls.scripts / 'sdd-hook-guard.js')],
            'powershell': [OPTIONS.powershell, '-NoProfile', '-File', str(cls.scripts / 'sdd-hook-guard.ps1')],
        }
        cls.approval = 'python3 plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py --content sdd/project-context.yaml --sidecar sdd/project-context.approval.json --approver-registry sdd/approver-registry.yaml'

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def decision(self, command, expected, *, cwd=None, metadata=None):
        payload = {'sessionId': 'synthetic', 'timestamp': 1, 'cwd': str(cwd or self.root),
                   'toolName': 'bash', 'toolArgs': {'command': command}}
        if metadata:
            payload.update(metadata)
        for runtime in RUNTIMES:
            with self.subTest(runtime=runtime, command=command):
                result = subprocess.run(self.commands[runtime] + ['--emit', 'copilot'], input=json.dumps(payload),
                                        text=True, capture_output=True, cwd=self.root, env=self.environ, timeout=15)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout).get('permissionDecision'), expected)

    def unknown_shell_denies(self, command):
        # Bash quoting/assignment semantics cannot be inferred for generic exec.
        for tool in ('shell', 'exec_command', 'exec'):
            self.canonical_decision(command, 2, tool=tool)

    def canonical_decision(self, command, expected, *, tool='Bash'):
        payload = {'tool_name': tool, 'tool_input': {'command': command}}
        for runtime in RUNTIMES:
            with self.subTest(runtime=runtime, tool=tool):
                result = subprocess.run(self.commands[runtime] + ['--emit', 'exit'], input=json.dumps(payload),
                                        text=True, capture_output=True, cwd=self.root, env=self.environ, timeout=15)
                self.assertEqual(result.returncode, expected, result.stderr)

    def test_public_reader_contracts(self):
        for command in (
            self.approval,
            self.approval + ' > result.json && cat result.json',
            'python plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py --sidecar=sdd/project-context.approval.json --content=sdd/project-context.yaml',
            'python3 plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py --verify-provenance --sidecar sdd/project-context.approval.json',
            'python3 plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py --hash-only --input-format yaml sdd/approver-registry.yaml',
            'python3 plugins/sdd-quality-loop/scripts/validate-capability-registry.py --registry contracts/capability-registry.json --repo-root .',
        ):
            self.decision(command, 'allow')

    def test_unknown_and_mutating_argv(self):
        for command in (
            self.approval + ' --apply', self.approval + ' --reserve',
            self.approval + ' --sidecar sdd/project-context.approval.json',
            self.approval.replace('--sidecar', '--unknown'),
            self.approval.replace('--content sdd/project-context.yaml ', ''),
            self.approval + ' --verify-provenance',
            self.approval + ' sdd/approver-registry.yaml',
            'python3 plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py --input-format unknown sdd/approver-registry.yaml',
            'python3 plugins/sdd-quality-loop/scripts/validate-capability-registry.py --repo-root sdd/approver-registry.yaml',
        ):
            self.decision(command, 'deny')

    def test_write_targets_and_shell_context(self):
        for command in (
            self.approval + ' > sdd/approver-registry.yaml',
            self.approval + ' 2>>sdd/project-context.approval.json',
            self.approval + ' | tee sdd/approver-registry.yaml',
            self.approval + ' && rm sdd/approver-registry.yaml',
            'echo ok; ' + self.approval,
            'alias python3=rm\n' + self.approval,
            'hash -p /bin/rm python3\n' + self.approval,
            'PATH=/tmp ' + self.approval,
            self.approval.replace('python3 ', '/tmp/python3 ', 1),
            self.approval.replace('--content sdd/project-context.yaml', '--content "$INPUT"'),
            self.approval + ' && cd elsewhere',
            self.approval + ' < sdd/approver-registry.yaml',
        ):
            self.decision(command, 'deny')

    def test_execution_directory_binding(self):
        other = self.root / 'other'
        other.mkdir(exist_ok=True)
        self.decision(self.approval, 'deny', cwd=other)
        for value in ('.', '', None, 1):
            self.decision(self.approval, 'deny', metadata={'cwd': value})
        self.decision(self.approval, 'deny', metadata={'workdir': str(other)})
        self.decision(self.approval, 'allow', metadata={'workdir': str(self.root)})
        canonical = {'cwd': str(self.root), 'tool_name': 'bash', 'tool_input': {'command': self.approval, 'workdir': str(other)}}
        for runtime in RUNTIMES:
            with self.subTest(runtime=runtime):
                result = subprocess.run(self.commands[runtime] + ['--emit', 'copilot'], input=json.dumps(canonical), text=True,
                                        capture_output=True, cwd=self.root, env=self.environ, timeout=15)
                self.assertEqual(json.loads(result.stdout)['permissionDecision'], 'deny')

    def test_script_identity(self):
        outside = self.root / 'other/scripts'
        outside.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(self.scripts / 'validate-approval-sidecar.py', outside / 'validate-approval-sidecar.py')
        command = self.approval.replace('plugins/sdd-quality-loop/scripts/', 'other/scripts/')
        self.decision(command, 'deny')
        self.decision(self.approval.replace('scripts/', 'scripts-spoof/'), 'deny')
        script = self.scripts / 'validate-approval-sidecar.py'
        original = script.read_bytes()
        script.unlink()
        try:
            try:
                script.symlink_to(outside / script.name)
            except OSError:
                self.skipTest('symlink creation is unavailable')
            self.decision(self.approval, 'deny')
        finally:
            if script.is_symlink():
                script.unlink()
            script.write_bytes(original)

    def test_dependency_failures(self):
        helper = self.scripts / 'classify-readonly-inputs.py'
        catalog = self.package / 'references/readonly-input-contracts.json'
        for path, replacement in ((helper, None), (catalog, None), (catalog, b'not json'),
                                  (helper, b'raise SystemExit(3)\n'),
                                  (helper, b'print("not json")\n'),
                                  (helper, b'print("[true]")\n'),
                                  (helper, b'import time; time.sleep(10)\n')):
            saved = path.read_bytes()
            try:
                if replacement is None:
                    path.unlink()
                else:
                    path.write_bytes(replacement)
                self.decision(self.approval, 'deny')
            finally:
                path.write_bytes(saved)

    def test_classifier_and_catalog_protection(self):
        for target in ('tests/guard-readonly-inputs.tests.py',
                       'plugins/sdd-quality-loop/scripts/classify-readonly-inputs.py',
                       'plugins/sdd-quality-loop/references/readonly-input-contracts.json'):
            self.decision('cat ' + target, 'allow')
            self.decision('printf changed > ' + target, 'deny')
            payload = {'tool_name': 'write', 'tool_input': {'file_path': target, 'content': 'changed'}}
            for runtime in RUNTIMES:
                with self.subTest(runtime=runtime, target=target):
                    result = subprocess.run(self.commands[runtime] + ['--emit', 'copilot'], input=json.dumps(payload),
                                            text=True, capture_output=True, cwd=self.root, env=self.environ, timeout=15)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(json.loads(result.stdout)['permissionDecision'], 'deny')

    def test_literal_backup_copy_and_filesystem_boundaries(self):
        fixture = self.root.resolve() / 'backup-fixture'
        source_dir = fixture / '.claude'
        destination_dir = fixture / 'backup space'
        source_dir.mkdir(parents=True)
        destination_dir.mkdir()
        source = source_dir / 'settings.json'
        original = b'{"fixture": "protected settings"}\n'
        source.write_bytes(original)
        self.environ = {**self.environ, 'HOME': fixture.as_posix()}
        prefix = 'BK="' + destination_dir.as_posix() + '"; cp -a ~/.claude/settings.json '
        allowed = (
            prefix + '"$BK/claude-settings.json.bak"',
            prefix + '"${BK}/claude-settings.json.bak"',
            'cp -- ~/.claude/settings.json "$HOME/backup space/claude-settings.json.bak"',
        )
        for command in allowed:
            self.decision(command, 'allow')
        self.unknown_shell_denies(allowed[0])
        self.canonical_decision(allowed[0], 0)
        existing = destination_dir / 'existing.bak'
        existing.write_text('keep')
        (destination_dir / 'directory.bak').mkdir()
        for command in (
            'cp ~/.claude/settings.json "$UNBOUND/backup.bak"',
            prefix + "'$BK/claude-settings.json.bak'",
            prefix + '"$BK/existing.bak"',
            prefix + '"$BK/directory.bak"',
            prefix + '"$BK"',
            prefix + '"$BK/tasks.md"',
            prefix + '"$BK/SDD_SUDO"',
            prefix + '"$BK/active-config.json"',
            prefix + '"$BK/../.claude/settings.json"',
            prefix + '"${BK:-/tmp}/new.bak"',
            prefix + '"$(printf /tmp)/new.bak"',
            prefix + '"$BK/new.bak"; rm ~/.claude/settings.json',
            prefix.replace('cp -a', 'cp -t') + '"$BK/new.bak"',
            prefix.replace('BK=', 'PATH=') + '"$PATH/new.bak"',
            'BK="' + destination_dir.as_posix() + '\\"; cp -a ~/.claude/settings.json "$BK/new.bak"',
            prefix + '"$BK/new.bak\\"',
        ):
            self.decision(command, 'deny')
        source.unlink()
        source.mkdir()
        try:
            self.decision(prefix + '"$BK/directory.bak"', 'deny')
        finally:
            source.rmdir()
            source.write_bytes(original)
        known_home = self.environ
        self.environ = {key: value for key, value in known_home.items() if key != 'HOME'}
        try:
            self.decision(prefix + '"$BK/no-home.bak"', 'deny')
            self.decision(prefix.replace('~/.claude/settings.json', '"' + source.as_posix() + '"') + '"$BK/absolute.bak"', 'allow')
        finally:
            self.environ = known_home
        if os.name != 'nt':
            # Exercise actual admitted argv and effects, not just the classifier.
            result = subprocess.run(['bash', '-c', allowed[0]], cwd=fixture, env=self.environ,
                                    text=True, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((destination_dir / 'claude-settings.json.bak').read_bytes(), original)
            self.assertEqual(source.read_bytes(), original)
            os.link(source, destination_dir / 'linked.bak')
            self.decision(prefix + '"$BK/linked.bak"', 'deny')
            (destination_dir / 'symlink.bak').symlink_to(source)
            self.decision(prefix + '"$BK/symlink.bak"', 'deny')
            (destination_dir / 'dangling.bak').symlink_to(source_dir / 'absent.json')
            self.decision(prefix + '"$BK/dangling.bak"', 'deny')
            (fixture / 'alias').symlink_to(destination_dir, target_is_directory=True)
            self.decision(prefix.replace(destination_dir.as_posix(), (fixture / 'alias').as_posix()) + '"$BK/new.bak"', 'deny')
            # Bash collapses a double-quoted escaped backslash. Never inspect
            # the two-backslash path while cp writes into the one-backslash dir.
            modeled = fixture / 'two\\\\slashes'
            actual = fixture / 'two\\slashes'
            modeled.mkdir()
            (actual / '.claude').mkdir(parents=True)
            victim = actual / '.claude/settings.json'
            victim.write_text('unchanged')
            escaped_assignment = 'BK="' + modeled.as_posix() + '"; cp -a ~/.claude/settings.json "$BK/.claude"'
            self.decision(escaped_assignment, 'deny')
            self.assertEqual(victim.read_text(), 'unchanged')
            subprocess.run(['bash', '-c', escaped_assignment], cwd=fixture, env=self.environ,
                           text=True, capture_output=True, check=True, timeout=10)
            self.assertEqual(victim.read_bytes(), original, 'fixture must reproduce Bash path decoding')
        if os.name == 'nt':
            # Native drive spelling and Git Bash's /c/... spelling share policy.
            native = str(destination_dir)
            self.decision('BK="' + native + '"; cp -a ~/.claude/settings.json "$BK/native.bak"', 'allow')
            self.decision("BK='" + native + "'; cp -a ~/.claude/settings.json \"$BK/single-quote.bak\"", 'allow')
            msys = '/' + destination_dir.drive[0].lower() + destination_dir.as_posix()[2:]
            self.decision('BK="' + msys + '"; cp -a ~/.claude/settings.json "$BK/msys.bak"', 'allow')
            for suffix in ('stream.bak:settings.json', 'trailing.bak.', 'trailing.bak '):
                self.decision(prefix + '"$BK/' + suffix + '"', 'deny')
            self.decision('BK=/tmp; cp -a ~/.claude/settings.json "$BK/unmapped.bak"', 'deny')
            junction = fixture / 'junction'
            subprocess.run(['cmd', '/c', 'mklink', '/J', str(junction), str(destination_dir)],
                           text=True, capture_output=True, check=True, timeout=10)
            try:
                self.decision(prefix.replace(destination_dir.as_posix(), junction.as_posix()) + '"$BK/junction.bak"', 'deny')
            finally:
                junction.rmdir()

    def test_read_only_glob_loop_with_line_continuations(self):
        command = 'for item in ./*.md; do \\\n cat -- "$item"; head -n 1 -- "${item}"; wc -l -- "$item"; done'
        self.decision(command, 'allow')
        self.unknown_shell_denies(command)
        self.canonical_decision(command, 0)
        for mutation in (
            command.replace('cat --', 'cat'),
            command.replace('cat -- "$item"', 'eval "$item"'),
            command.replace('cat -- "$item"', 'cat -- "$item" > ~/.claude/settings.json'),
            command.replace('cat -- "$item"', 'rg --pre=evil "$item"'),
            command.replace('./*.md', '$(touch ~/.claude/settings.json)'),
            command.replace('item', 'PATH'),
            command.replace('item', 'SECONDS'),
            command.replace('item', 'RANDOM'),
            command.replace('item', 'BASH_ALIASES'),
            command.replace('done', 'done; rm ~/.claude/settings.json'),
            'for item in ./*.md; do cat -- \\\r\n"$item"; done',
        ):
            self.decision(mutation, 'deny')
        if os.name != 'nt':
            fixture = self.root / 'loop-fixture'
            fixture.mkdir()
            (fixture / 'one.md').write_text('one\ntwo\n')
            (fixture / '--pre=evil.md').write_text('option-looking name\n')
            before = {file.name: file.read_bytes() for file in fixture.iterdir()}
            result = subprocess.run(['bash', '-c', command], cwd=fixture, env=self.environ,
                                    text=True, capture_output=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('option-looking name', result.stdout)
            self.assertEqual({file.name: file.read_bytes() for file in fixture.iterdir()}, before)

    @unittest.skipIf(os.name == 'nt', 'Bash effect fixtures run once on POSIX, not on both PowerShell hosts')
    def test_loop_special_variables_and_crlf_have_real_write_effects(self):
        fixture = self.root / 'loop-special-variable-fixture'
        protected = fixture / '.claude'
        protected.mkdir(parents=True)
        victim = protected / 'settings.json'
        victim.write_text('unchanged')
        (protected / 'a[$(printf HACKED > settings.json)]').write_text('')
        integer_loop = 'for SECONDS in *; \\\n do cat -- "$SECONDS"; done'
        self.decision(integer_loop, 'deny', cwd=protected)
        self.assertEqual(victim.read_text(), 'unchanged')
        subprocess.run(['bash', '-c', integer_loop], cwd=protected, env=self.environ,
                       text=True, capture_output=True, timeout=10)
        self.assertEqual(victim.read_text(), 'HACKED', 'fixture must exercise implicit Bash arithmetic')
        victim.write_text('unchanged')
        executable = fixture / 'run.md'
        executable.write_text('#!/usr/bin/env bash\nprintf CRLF > .claude/settings.json\n')
        executable.chmod(0o755)
        crlf_loop = 'for item in ./*.md; do cat -- \\\r\n"$item"; done'
        self.decision(crlf_loop, 'deny', cwd=fixture)
        subprocess.run(['bash', '-c', crlf_loop], cwd=fixture, env=self.environ,
                       text=True, capture_output=True, timeout=10)
        self.assertEqual(victim.read_text(), 'CRLF', 'CRLF is not a Bash line continuation')


if __name__ == '__main__':
    unittest.main(argv=[__file__] + REMAINING)
