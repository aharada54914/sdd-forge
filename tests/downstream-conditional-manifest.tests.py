#!/usr/bin/env python3
"""Exercise saved-manifest predicates without mutating historical evidence."""
import copy
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / 'plugins/sdd-review-loop/scripts'
HASH = 'a' * 64
DOMAIN = ['domain/context-map.md', 'domain/domain-contract.json']
DS = ['design-system/design-tokens.json', 'design-system/design-system.md', 'design-system/ui-patterns.md']


def contract(stage, extra=()):
    paths = ['specs/fixture/requirements.md', 'specs/fixture/acceptance-tests.md',
             'plugins/sdd-review-loop/references/calibration.md']
    if stage == 'impl':
        paths.append('specs/fixture/design.md')
    return dict(schema=stage + '-review-contract/v1', feature='fixture', stage=stage,
                attempt=1, round=1, run_id='integrated', verdict='PASS', reviewers=[
                    dict(role=stage + '-reviewer-' + role, host_session_id=role, run_id=role,
                         allowed_input_manifest=[dict(path=p, sha256=HASH) for p in paths + list(extra)])
                    for role in ('a', 'b')])


def cases():
    result = []
    for stage in ('spec', 'impl', 'task'):
        result.append((stage + '-legacy', contract(stage), True))
        result.append((stage + '-domain', contract(stage, DOMAIN), stage != 'task'))
        result.append((stage + '-design-system', contract(stage, DS), stage == 'impl'))
    for stage in ('spec', 'impl'):
        paths = DOMAIN + (DS if stage == 'impl' else [])
        result.append((stage + '-historical-absolute', contract(stage, ['/old/checkout/' + p for p in paths]), True))
        for label, path in [('unknown', 'domain/extra.md'), ('aggregate', 'domain/aggregates/Order.md'),
                            ('case', 'Domain/context-map.md'), ('traversal', 'domain/../domain/context-map.md')]:
            result.append((stage + '-' + label, contract(stage, [path]), False))
        for mutation in ('one-sided', 'different-hash', 'duplicate', 'invalid-hash'):
            value = contract(stage, paths)
            entries = value['reviewers'][1]['allowed_input_manifest']
            if mutation == 'one-sided':
                entries.pop()
            elif mutation == 'duplicate':
                entries.append(copy.deepcopy(entries[-1]))
            else:
                entries[-1]['sha256'] = 'b' * 64 if mutation == 'different-hash' else 'A' * 64
            result.append((stage + '-' + mutation, value, False))
    return result


class SavedManifestTests(unittest.TestCase):
    def test_bash_actual_jq_predicate(self):
        source = (SCRIPTS / 'lib/review-precheck-common.sh').read_text()
        program = source.split('--argjson verified_adrs "$verified_adr_paths" \'', 1)[1].split("\n  ' \"$contract\"", 1)[0]
        for label, value, expected in cases():
            with self.subTest(label=label):
                args = ['jq', '-e']
                for key, val in dict(feature='fixture', stage=value['stage'], req=HASH,
                                     req_current=HASH, accept=HASH, design=HASH, design_current=HASH,
                                     repo='/nonexistent/current/', calibration='plugins/sdd-review-loop/references/calibration.md',
                                     calibration_hash=HASH).items():
                    args += ['--arg', key, val]
                run = subprocess.run(args + ['--argjson', 'verified_adrs', '[]', program],
                                     input=json.dumps(value), text=True, capture_output=True)
                self.assertEqual(run.returncode == 0, expected, run.stderr)

    def test_powershell_actual_manifest_blocks(self):
        for filename in ('impl-review-precheck.ps1', 'task-review-precheck.ps1'):
            source = (SCRIPTS / filename).read_text()
            functions = source[source.index('function Test-OrdinalEqual'):source.index('function Require-Pass')]
            block = source[source.index('  $invalidManifest ='):source.index('  function Test-ManifestEntry')]
            with tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                (root / 'cases.json').write_text(json.dumps(cases()))
                harness = "param($Cases)\n$ErrorActionPreference='Stop'\nfunction Fail($Message) { throw $Message }\n" + functions
                harness += '\nforeach ($case in (Get-Content -Raw $Cases | ConvertFrom-Json)) {\n'
                harness += "$contract=$case[1]; $Stage=$contract.stage; $FeatureName='fixture'; $repoRoot='/nonexistent/current'; $calibrationPath='plugins/sdd-review-loop/references/calibration.md'; $reviewers=@($contract.reviewers); $manifest=@($reviewers.allowed_input_manifest)\n"
                harness += 'try {\n' + block + '\n$actual=$true\n} catch { $actual=$false }\n'
                harness += 'if ($actual -ne $case[2]) { throw "Mismatch: $($case[0])" }\n}\n'
                (root / 'test.ps1').write_text(harness)
                run = subprocess.run(['pwsh', '-NoProfile', '-File', str(root / 'test.ps1'), str(root / 'cases.json')], text=True, capture_output=True)
                self.assertEqual(run.returncode, 0, filename + run.stdout + run.stderr)


if __name__ == '__main__':
    unittest.main()
