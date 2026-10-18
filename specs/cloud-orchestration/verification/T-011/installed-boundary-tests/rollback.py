"""Restore/reapply only routing-test coverage in a disposable committed checkout."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo', required=True, type=Path)
    parser.add_argument('--scratch-root', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    repo = args.repo.resolve()
    evidence = Path(__file__).resolve().parent
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    checkout = args.scratch_root.resolve() / 'coverage-rollback'
    assert not checkout.exists(), 'Refuse to reuse an existing checkout'
    rel = 'tests/cloud-orchestration-routing.tests.py'
    production = 'plugins/sdd-bootstrap/scripts/cloud-routing.py'
    baseline = evidence / 'baseline-routing.py.txt'
    current = (repo / rel).read_bytes()
    helper_hash = digest(repo / production)
    base = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=repo, text=True).strip()
    commands: list[dict] = []
    overlays = []
    try:
        subprocess.run(['git', 'worktree', 'add', '--detach', str(checkout), base], cwd=repo, check=True)
        # Preserve current pending production candidate bytes; none are edited by this repair.
        pending = subprocess.check_output(['git', 'diff', 'HEAD', '--name-only', '--', 'plugins'],
                                          cwd=repo, text=True).splitlines()
        for name in pending:
            shutil.copy2(repo / name, checkout / name)
            overlays.append(dict(path=name, sha256=digest(repo / name)))
        for phase, payload, expected in [('restored', baseline.read_bytes(), 1), ('reapplied', current, 0)]:
            (checkout / rel).write_bytes(payload)
            assert digest(checkout / production) == helper_hash
            command = [sys.executable, '-B', str(evidence / 'sensitivity.py'), '--repo', str(checkout),
                       '--output', str(output / phase)]
            result = subprocess.run(command, cwd=checkout, text=True, capture_output=True, timeout=180)
            (output / (phase + '.log')).write_text(result.stdout + result.stderr)
            commands.append(dict(phase=phase, command=command, exit_code=result.returncode,
                                 test_sha256=digest(checkout / rel), helper_sha256=digest(checkout / production)))
            assert result.returncode == expected, f'{phase} did not reproduce expected sensitivity'
            record = json.loads((output / phase / 'results.json').read_text())
            if phase == 'restored':
                assert all(r['failures'] == r['errors'] == 0 for r in record['records'])
            assert (repo / rel).read_bytes() == current
            assert digest(repo / production) == helper_hash
    finally:
        if checkout.exists():
            subprocess.run(['git', 'worktree', 'remove', '--force', str(checkout)], cwd=repo, check=True)
        (output / 'rollback.json').write_text(json.dumps(dict(base_revision=base,
            coverage_only=True, baseline_sha256=digest(baseline), final_sha256=digest(repo / rel),
            production_sha256=helper_hash, pending_production_overlays=overlays,
            commands=commands, checkout_removed=not checkout.exists()), indent=2) + '\n')


if __name__ == '__main__':
    main()
