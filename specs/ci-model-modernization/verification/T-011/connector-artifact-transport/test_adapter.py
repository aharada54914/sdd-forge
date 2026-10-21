"""Synthetic controller contract checks only; never CI proof or network access."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('adapter', Path(__file__).with_name('collect_with_connector_zips.py'))
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)


class PrepareTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir='/workspace/ci-artifact-transport')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.zip = self.root / 'receipt.zip'
        self.zip.write_bytes(b'synthetic ZIP bytes; preparation does not extract')
        self.digest = hashlib.sha256(self.zip.read_bytes()).hexdigest()
        self.metadata = dict(id=42, name='verification-receipts-123-1-fixture', expired=False,
                             digest='sha256:' + self.digest, workflow_run=dict(id=123, head_sha='a' * 40))
        self.meta = self.root / 'metadata.json'
        self.meta.write_text(json.dumps(self.metadata))
        self.row = dict(artifact_id=42, name=self.metadata['name'], endpoint='/repos/a/b/actions/artifacts/42/zip',
                        zip_path=str(self.zip), sha256=self.digest, size_bytes=self.zip.stat().st_size,
                        metadata_path=str(self.meta), metadata_sha256=A.sha(self.meta.read_bytes()))
        self.manifest = dict(schema='connector-artifact-transport/v1', repository='a/b', run_id='123',
                             head_sha='a' * 40, artifacts=[self.row])
        self.run = dict(id=123, head_sha='a' * 40, repository=dict(full_name='a/b'))
        self.calls = []
        outer = self
        class Collector:
            MAX_RESPONSE_BYTES = 4096
            repository_identity = staticmethod(lambda v: v == 'a/b')
            run_identity = staticmethod(lambda v: v == '123')
            @staticmethod
            def api_get(endpoint):
                outer.calls.append(endpoint)
                if endpoint == '/repos/a/b/actions/runs/123':
                    return copy.deepcopy(outer.run), {}
                if endpoint == '/repos/a/b/actions/artifacts/42':
                    return copy.deepcopy(outer.metadata), {}
                raise AssertionError('unexpected metadata endpoint')
        self.collector = Collector()

    def test_valid_binding_and_only_original_metadata_endpoints(self):
        cache, receipts = A.prepare(self.manifest, self.collector)
        self.assertEqual(cache[self.row['endpoint']], self.zip.read_bytes())
        self.assertFalse(receipts[0]['zip_response_headers_observed'])
        self.assertEqual(self.calls, ['/repos/a/b/actions/runs/123', '/repos/a/b/actions/artifacts/42'])

    def test_reject_wrong_or_duplicate_endpoint(self):
        for mutate in ('wrong', 'duplicate'):
            with self.subTest(mutate=mutate):
                doc = copy.deepcopy(self.manifest)
                if mutate == 'wrong':
                    doc['artifacts'][0]['endpoint'] += '?other=1'
                else:
                    doc['artifacts'].append(copy.deepcopy(self.row))
                with self.assertRaises(ValueError): A.prepare(doc, self.collector)

    def test_reject_modified_local_zip(self):
        self.zip.write_bytes(self.zip.read_bytes() + b'x')
        with self.assertRaises(ValueError): A.prepare(self.manifest, self.collector)

    def test_reject_saved_metadata_tamper(self):
        self.meta.write_text('{}')
        with self.assertRaises(ValueError): A.prepare(self.manifest, self.collector)

    def test_reject_fresh_metadata_mismatch(self):
        for key, value in [('id', 43), ('name', 'other'), ('expired', True), ('digest', 'sha256:' + 'b' * 64),
                           ('workflow_run', dict(id=124, head_sha='a' * 40)),
                           ('workflow_run', dict(id=123, head_sha='b' * 40))]:
            with self.subTest(key=key, value=value):
                saved = copy.deepcopy(self.metadata)
                self.metadata[key] = value
                with self.assertRaises(ValueError): A.prepare(self.manifest, self.collector)
                self.metadata = saved

    def test_reject_run_head_mismatch(self):
        self.run['head_sha'] = 'b' * 40
        with self.assertRaises(ValueError): A.prepare(self.manifest, self.collector)

    def test_reject_oversize_or_symlink_zip(self):
        self.row['size_bytes'] = 4097
        with self.assertRaises(ValueError): A.prepare(self.manifest, self.collector)
        self.row['size_bytes'] = self.zip.stat().st_size
        alias = self.root / 'alias.zip'; alias.symlink_to(self.zip)
        self.row['zip_path'] = str(alias)
        with self.assertRaises(ValueError): A.prepare(self.manifest, self.collector)

    def test_reject_duplicate_json_keys(self):
        with self.assertRaises(ValueError): A.strict_json('{"id":1,"id":2}')


if __name__ == '__main__': unittest.main()
