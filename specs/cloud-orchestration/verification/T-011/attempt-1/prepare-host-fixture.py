"""Prepare installed bytes and requests; DOES NOT launch a model or cloud API."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[5]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', required=True, type=Path)
    args = parser.parse_args()
    destination = args.destination
    if not destination.is_absolute() or destination.resolve() != destination:
        parser.error('destination must be a new physical absolute directory')
    destination.mkdir()
    spec = importlib.util.spec_from_file_location('install_cloud_fixture', ROOT / 'tests/install-cloud.tests.py')
    assert spec and spec.loader
    packaging = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(packaging)
    source = destination / 'source'
    source.mkdir()
    packaging.fixture(source)
    installed = destination / 'installed'
    subprocess.run(['bash', str(ROOT / 'install.sh'), '--source-directory', str(source),
                    '--install-root', str(installed), '--target', 'FilesOnly', '--plugins',
                    'sdd-bootstrap,sdd-azure-cloud,sdd-aws-cloud', '--skip-agent-install', '--skip-mcp'], check=True)
    fixtures = []
    for provider in ('azure', 'aws'):
        for variant in ('supported', 'mixed-owner'):
            workspace = destination / (provider + '-' + variant)
            workspace.mkdir()
            request = packaging.local_request(workspace, provider)
            evidence = 'specs/cloud-orchestration/verification/T-011/cloud/synthetic-run/synthetic-unit'
            request['local_context'].update(task_id='T-011', evidence_directory=evidence)
            (workspace / evidence).mkdir(parents=True)
            if variant == 'mixed-owner':
                (workspace / 'bundle/unit/main.tf').write_text('# synthetic conflicting owner\n')
            path = workspace / 'request.json'
            raw = (json.dumps(request, sort_keys=True) + '\n').encode()
            path.write_bytes(raw)
            fixtures.append(dict(provider=provider, variant=variant, workspace=str(workspace), request=str(path),
                                 request_sha256=hashlib.sha256(raw).hexdigest(), evidence_directory=evidence,
                                 provider_root=str(installed / ('plugins/sdd-' + provider + '-cloud'))))
    (destination / 'fixture.json').write_text(json.dumps(dict(classification='offline installed fixture; NOT native host delivery',
                                                            bootstrap_root=str(installed / 'plugins/sdd-bootstrap'), fixtures=fixtures), indent=2) + '\n')
    print(destination / 'fixture.json')


if __name__ == '__main__':
    main()
