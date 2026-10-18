"""Reproduce local T-005 native evidence. No cloud transport or credentials."""
from pathlib import Path
import hashlib
import json
import runpy
import shutil
import sys

ROOT = Path(__file__).resolve().parents[5]
HERE = Path(__file__).resolve().parent


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ns = runpy.run_path(str(ROOT / 'tests/cloud-orchestration-routing.tests.py'))
    test = ns['AwsNativePreparation']()
    test.setUp()
    try:
        result = test.invoke('plan')
        evidence = json.loads((test.root / result['evidence_manifest_path']).read_bytes())
        original = (test.root / 'request.json').read_bytes()
        test.req = test.contracts.read_artifact(test.root, evidence['locked_request'], 'cloud-run-request/v1')
        validated = test.invoke('validate', env_extra={'CLOUD_CDK_ROOT': '/not-used-for-validation'})
        assert validated['state'] == 'LOCAL_VALIDATED'
        (test.root / 'original-request.json').write_bytes(original)
        dest = HERE / 'native-workspace'
        assert not dest.exists(), 'Evidence is immutable: use a fresh output checkout.'
        shutil.copytree(test.root, dest)
        files = [{'path': str(p.relative_to(ROOT)), 'sha256': sha(p)}
                 for p in sorted(dest.rglob('*')) if p.is_file()]
        info = dict(classification='real-local-synthesis-with-synthetic-scope', cloud_validated=False,
                    run_id='01a14dcb-540f-74f1-ac06-0cb8ccbe95f8',
                    session_id='01a14dcb-540f-74f1-ac06-0cb8ccbe95f8',
                    model='openai/gpt-6-astra', effort='high', task_attempt_count=1,
                    command=['python3', '-B', str(Path(__file__).relative_to(ROOT))],
                    interpreter_executable=sys.executable,
                    harness_description='AwsNativePreparation fixture setup followed by actual plan/validate CLI subprocesses',
                    plan_result=result, validate_result=validated, files=files,
                    limits='Trusted authored app; environment stripping is not filesystem/network isolation; no live cloud acceptance.')
        (HERE / 'native-execution.json').write_text(json.dumps(info, indent=2) + '\n')
        print('Native plan/validate PASS; full assembly copied; synthetic scope, no live cloud acceptance')
    finally:
        test.doCleanups()


if __name__ == '__main__':
    # subprocess test helpers build controlled environments; do not run the app in this parent.
    main()
