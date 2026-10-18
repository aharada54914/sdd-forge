"""Coverage experiment: mutate only disposable installed helpers, never source."""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch

ROOT_GUARD = 'if not root.is_absolute() or root.resolve() != root:'
RUNTIME_GUARD = 'if not path.is_file() or path.resolve() != path:'


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('--repo', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    repo = args.repo.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    source = repo / 'tests/cloud-orchestration-routing.tests.py'
    helper = repo / 'plugins/sdd-bootstrap/scripts/cloud-routing.py'
    original = helper.read_bytes()
    records: list[dict] = []
    for variant in ('control', 'physical-path-policy', 'runtime-presence'):
        spec = importlib.util.spec_from_file_location('routing_sensitivity', source)
        assert spec and spec.loader
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        cls = module.BootstrapInstalled
        setup = cls.setUpClass
        mutations: list[dict[str, str]] = []

        def installed_setup() -> None:
            setup()
            seam = cls.install / 'plugins/sdd-bootstrap/scripts/cloud-routing.py'
            before = seam.read_bytes()
            text = before.decode()
            assert text.count(ROOT_GUARD) == text.count(RUNTIME_GUARD) == 1
            if variant == 'physical-path-policy':
                text = text.replace(ROOT_GUARD, 'if False:')
                text = text.replace(RUNTIME_GUARD, 'if not path.is_file():')
            elif variant == 'runtime-presence':
                text = text.replace(RUNTIME_GUARD, 'if path.resolve() != path:')
            seam.write_text(text)
            record = dict(before_sha256=digest(before), mutant_sha256=digest(seam.read_bytes()))
            mutations.append(record)

            def restore() -> None:
                seam.write_bytes(before)
                record['restored_sha256'] = digest(seam.read_bytes())
                assert record['restored_sha256'] == record['before_sha256']

            cls.addClassCleanup(restore)

        stream = io.StringIO()
        with patch.object(cls, 'setUpClass', side_effect=installed_setup):
            result = unittest.TextTestRunner(stream=stream, verbosity=2).run(
                unittest.defaultTestLoader.loadTestsFromTestCase(cls))
        log = stream.getvalue()
        (args.output / (variant + '.log')).write_text(log)
        semantic = sum('delegated subprocess reached for rejected installed path' in trace
                       for _, trace in result.failures)
        records.append(dict(variant=variant, tests=result.testsRun, failures=len(result.failures),
                            errors=len(result.errors), skips=len(result.skipped),
                            semantic_delegation_failures=semantic, mutations=mutations,
                            fixture_removed=not Path(cls.temp.name).exists()))
        assert helper.read_bytes() == original, 'Repository production helper changed'
    record_path = args.output / 'results.json'
    record_path.write_text(json.dumps(dict(test_sha256=digest(source.read_bytes()),
        helper_sha256=digest(original), records=records), indent=2) + '\n')
    print(record_path.read_text(), end='')
    assert records[0]['errors'] == records[0]['failures'] == 0, 'Healthy production control failed'
    for record in records[1:]:
        assert record['errors'] == 0, 'Setup/import errors are not semantic sensitivity'
        assert record['semantic_delegation_failures'] > 0, (
            f"Selected BootstrapInstalled suite let {record['variant']} survive without a delegation assertion")


if __name__ == '__main__':
    main()
