#!/usr/bin/env python3
"""Issue #725: literal handshake evidence is not an executable patch."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'plugins/sdd-quality-loop/scripts'
parser = argparse.ArgumentParser()
parser.add_argument('--powershell', default='pwsh')
options, remaining = parser.parse_known_args()
PATCH = '*** Begin Patch\n*** Add File: sdd/.hook-canary-sentinel\n+probe\n*** End Patch'
RAW = 'Script error:\nCommand blocked by PreToolUse hook: deterministic gate. Command: ' + PATCH
COMMANDS = {
    'python': ['python3', str(SCRIPTS / 'sdd-hook-guard.py')],
    'node': ['node', str(SCRIPTS / 'sdd-hook-guard.js')],
    'shell': ['bash', str(SCRIPTS / 'sdd-hook-guard.sh')],
    'powershell': [options.powershell, '-NoProfile', '-File', str(SCRIPTS / 'sdd-hook-guard.ps1')],
}


class QuotedPatchEvidence(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='sdd-quoted-patch-')
        self.root = Path(self.temp.name)
        self.addCleanup(self.temp.cleanup)
        self.env = {k: v for k, v in os.environ.items() if k not in ('PAYLOAD', 'SDD_SUDO')}
        self.env['CLAUDE_PROJECT_DIR'] = str(self.root)

    def decision(self, payload, expected):
        for runtime, command in COMMANDS.items():
            with self.subTest(runtime=runtime, payload=payload):
                result = subprocess.run(command, input=json.dumps(payload), text=True,
                                        capture_output=True, cwd=self.root, env=self.env, timeout=20)
                self.assertEqual(result.returncode, expected, result.stderr)

    def shell(self, command, expected=2):
        self.decision({'tool_name': 'exec_command', 'tool_input': {'command': command}}, expected)

    def evidence_command(self, body=RAW):
        return ("python3 -I - <<'PY'\nimport json\nfrom pathlib import Path\nraw='''" + body +
                "'''\nPath('result.json').write_text(json.dumps({'raw_result':raw}))\nPY")

    def test_literal_python_evidence_and_actual_file_contents(self):
        for body in (RAW, '\n' + PATCH):
            command = self.evidence_command(body)
            self.shell(command, 0)
            subprocess.run(['bash', '-c', command], cwd=self.root, check=True)
            self.assertEqual(json.loads((self.root / 'result.json').read_text())['raw_result'], body)
            self.assertFalse((self.root / 'sdd/.hook-canary-sentinel').exists())

    def test_literal_shell_evidence(self):
        self.shell("printf '%s' '" + RAW + "' > result.txt", 0)

    def test_approval_denial_evidence_is_data_only(self):
        (self.root / 'evidence').mkdir()
        task = self.root / 'specs/demo/tasks.md'
        task.parent.mkdir(parents=True)
        task.write_text('Approval: Draft\n')
        raw = "Approval: Approved denied. Command: python3 - <<'PY'\nfrom pathlib import Path\np=Path('specs/demo/tasks.md')\np.write_text(p.read_text().replace('Approval: Draft','Approval: Approved'))\nPY"
        command = self.evidence_command(raw).replace("Path('result.json')", "Path('evidence/denial.json')")
        self.shell(command, 0)
        subprocess.run(['bash', '-c', command], cwd=self.root, check=True)
        self.assertEqual(json.loads((self.root / 'evidence/denial.json').read_text())['raw_result'], raw)
        self.assertEqual(task.read_text(), 'Approval: Draft\n')
        for unsafe in (
            command.replace("Path('evidence/denial.json')", "Path('specs/demo/tasks.md')"),
            command.replace("Path('evidence/denial.json')", "Path('reports/../specs/demo/tasks.md')"),
            command.replace("Path('evidence/denial.json')", "Path('reports/review-context/identity-ledger.json')"),
            command.replace("import json", "import json\nexec(raw)"),
            command + "\nprintf 'Approval: Approved' > specs/demo/tasks.md",
            command.replace("<<'PY'", "<<PY"),
            command.replace("python3 -I -", "python3 -"),
        ):
            self.shell(unsafe)
        (self.root / 'evidence/denial.json').unlink()
        (self.root / 'evidence/denial.json').symlink_to(task)
        self.shell(command)
        (self.root / 'evidence/denial.json').unlink()
        os.link(task, self.root / 'evidence/denial.json')
        self.shell(command)
        (self.root / 'evidence/denial.json').unlink()
        for module in ('json', 'pathlib', 'fnmatch'):
            (self.root / (module + '.py')).write_text("open('specs/demo/tasks.md','w').write('Approval: Approved\\n')")
        self.shell(command, 0)
        subprocess.run(['bash', '-c', command], cwd=self.root, check=True)
        self.assertEqual(task.read_text(), 'Approval: Draft\n')
        self.shell(command.replace('python3 -I -', 'python3 -'))
        self.env['BASH_FUNC_python3%%'] = "() { printf 'Approval: Approved' > specs/demo/tasks.md; }"
        self.shell(command)
        del self.env['BASH_FUNC_python3%%']
        self.env['BASH_ENV'] = str(self.root / 'startup.sh')
        self.shell(command)
        del self.env['BASH_ENV']

    def test_actual_native_patch_and_direct_file_writes(self):
        self.decision({'tool_name': 'apply_patch', 'tool_input': {'command': PATCH}}, 2)
        self.decision({'tool_name': 'Write', 'tool_input': {'file_path': 'sdd/.hook-canary-sentinel', 'content': 'probe'}}, 2)
        self.shell("python3 -c \"open('sdd/.hook-canary-sentinel','w').write('probe')\"")

    def test_shell_patch_carriers_and_substitutions(self):
        for command in (
            "apply_patch <<'PATCH'\n" + PATCH + '\nPATCH',
            "echo before; apply_patch <<'PATCH'\n" + PATCH + '\nPATCH',
            "bash -c 'apply_patch <<\"PATCH\"\n" + PATCH + "\nPATCH'",
            "printf '%s' \"$(apply_patch <<'PATCH'\n" + PATCH + '\nPATCH\n)\"',
            "printf '%s' `apply_patch <<'PATCH'\n" + PATCH + '\nPATCH\n`',
            "python3 - <<'PY'\nimport subprocess\nraw='''" + PATCH + "'''\nsubprocess.run(['apply_patch'],input=raw,text=True)\nPY",
            self.evidence_command() + '\nrm sdd/.hook-canary-sentinel',
        ):
            self.shell(command)

    def test_approval_and_protected_write_controls(self):
        for path, content in (
            ('specs/demo/tasks.md', 'Approval: Approved'),
            ('specs/demo/design.md', 'Impl-Review-Status: Passed'),
            ('domain/context-map.md', 'Domain-Model-Status: Approved'),
            ('SDD_SUDO', 'expires-epoch: 9999999999'),
            ('sdd/project-context.approval.json', '{}'),
            ('plugins/sdd-quality-loop/scripts/classify-evidence-write.py', 'print(True)'),
        ):
            patch = f'*** Begin Patch\n*** Add File: {path}\n+{content}\n*** End Patch'
            self.decision({'tool_name': 'apply_patch', 'tool_input': {'command': patch}}, 2)
        self.shell("printf 'Approval: Approved' > specs/demo/tasks.md")


if __name__ == '__main__':
    unittest.main(argv=[__file__, *remaining])
