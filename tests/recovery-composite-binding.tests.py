#!/usr/bin/env python3
"""Verify exact composite and historical source bindings without editing live files."""
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

def module(path, name):
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

research = module('tests/lib/research-consumer-publication.py', 'composite_research_binding')
prior = module('tests/lib/component-coverage-successors.py', 'prior_a9_binding')

class CompositeBindingTests(unittest.TestCase):
    def test_composite_rejects_modified_live_or_frozen_predecessor(self):
        data=json.loads((ROOT/'tests/fixtures/research-consumer-current-publication.json').read_text())
        with tempfile.TemporaryDirectory(prefix='recovery-composite-') as d:
            root=Path(d)
            files={research.STAGE+'MANIFEST.sha256'}
            files.update(e[k] for e in data['successors'] for k in ('live','staged'))
            for name in files:
                target=root/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,target)
            self.assertEqual(research.validate(root,data),list(research.PATHS))
            for name in [data['successors'][2]['live'],data['successors'][2]['staged']]:
                target=root/name;original=target.read_bytes();target.write_bytes(original+b'\n')
                with self.assertRaises(ValueError):research.validate(root,data)
                target.write_bytes(original)

    def test_prior_reviewed_snapshot_rejects_changes(self):
        source=ROOT/'tests/fixtures/a9-reviewed-successor'
        with tempfile.TemporaryDirectory(prefix='recovery-prior-') as d:
            root=Path(d)
            for name in prior.SUCCESSORS:
                target=root/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source/name,target)
            prior.validate(root)
            target=root/next(iter(prior.SUCCESSORS));target.write_bytes(target.read_bytes()+b'\n')
            with self.assertRaises(ValueError):prior.validate(root)

if __name__=='__main__':
    unittest.main()
