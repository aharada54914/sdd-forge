#!/usr/bin/env python3
"""T-003 pinned dependency cache fixtures; mocked downloads only, never native install proof."""
import contextlib
import hashlib
import importlib.util
import io
import os
from pathlib import Path
import socket
import stat
import tempfile
import unittest
import warnings
import zipfile
from unittest.mock import patch

HELPER = Path(__file__).resolve().parent / 'ci-dependency-cache.py'

# Observed real package (pester-package-observation.json); never satisfied by synthetic fixtures.
REAL_URL = 'https://www.powershellgallery.com/api/v2/package/Pester/4.10.1'
REAL_VERSION = '4.10.1'
REAL_ARCHIVE_SHA256 = '898210e1a30c52cd46ba317c2278a9324345214213aa2f7d6b7dfa7b98f37ac9'
REAL_MANIFEST_SHA256 = '05bf87f45bf2b6604073a6851d0803917adfa87c134b9dd5867ba93b2e872663'

MANIFEST = b"@{\r\n    ModuleVersion = '4.10.1'\r\n    RootModule = 'Pester.psm1'\r\n}\r\n"
MODULE_FILES = {
    'Pester.psd1': MANIFEST,
    'Pester.psm1': b'# fixture module body; never executed\r\n',
    'Functions/It.ps1': b'function It {}\r\n',
}
PACKAGING_FILES = {
    '[Content_Types].xml': b'<?xml version="1.0"?><Types/>',
    '_rels/.rels': b'<?xml version="1.0"?><Relationships/>',
    'Pester.nuspec': b'<?xml version="1.0"?><package/>',
    'package/services/metadata/core-properties/fixture.psmdcp': b'<?xml version="1.0"?><coreProperties/>',
}


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def symlink_entry(name, target='../../outside'):
    info = zipfile.ZipInfo(name)
    info.create_system = 3
    info.external_attr = (stat.S_IFLNK | 0o777) << 16
    return info, target.encode()


def package(*extra, omit=()):
    raw = io.BytesIO()
    with warnings.catch_warnings():
        warnings.simplefilter('ignore')  # duplicate-name fixtures are intentional
        with zipfile.ZipFile(raw, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
            archive.writestr('Functions/', b'')
            for name, data in {**MODULE_FILES, **PACKAGING_FILES}.items():
                if name not in omit:
                    archive.writestr(name, data)
            for name, data in extra:
                archive.writestr(name, data)
    return raw.getvalue()


def files(root):
    return {path.relative_to(root).as_posix(): path.read_bytes()
            for path in Path(root).rglob('*') if path.is_file() or path.is_symlink()}


def requested_url(call):
    target = call.args[0] if call.args else call.kwargs['url']
    return getattr(target, 'full_url', target)


class CacheFixture(unittest.TestCase):
    def setUp(self):
        self.assertTrue(HELPER.is_file(), f'pinned dependency acquisition/integrity helper is missing: {HELPER.name}')
        self.cache = module(HELPER, 't003_cache_helper')
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        # Resolved so host-level symlinked temp roots (e.g. macOS /var) are not fixture ancestors.
        self.directory = Path(self.temp.name).resolve()
        guards = [patch.object(socket.socket, 'connect', side_effect=AssertionError('network forbidden in fixtures')),
                  patch.object(self.cache.urllib.request, 'urlopen', side_effect=AssertionError('unmocked download')),
                  patch('subprocess.Popen', side_effect=AssertionError('dependency bytes must never execute')),
                  patch('os.system', side_effect=AssertionError('dependency bytes must never execute'))]
        self.connect, self.default_urlopen, self.popen, self.system = (guard.start() for guard in guards)
        for guard in guards:
            self.addCleanup(guard.stop)

    def symlink(self, link, target, directory=False):
        try:
            link.symlink_to(target, target_is_directory=directory)
        except OSError:
            self.skipTest('host cannot create symlinks')

    def assert_never_executed(self):
        self.popen.assert_not_called()
        self.system.assert_not_called()
        self.connect.assert_not_called()


class DependencyCacheAcquireTests(CacheFixture):
    """Same contract as parent DependencyCacheIntegrationTests, plus publication and ancestor checks."""
    def setUp(self):
        super().setUp()
        self.target = self.directory / 'pester.nupkg'
        self.payload = b'fixture dependency bytes; never executed'
        self.digest = sha(self.payload)
        self.url = 'https://fixture.invalid/pinned.nupkg'

    def acquire(self, target=None):
        return self.cache.acquire(target or self.target, self.url, self.digest, attempts=3)

    def test_T003_cache_hit_rehashes_bytes_without_network(self):
        self.target.write_bytes(self.payload)
        with patch.object(self.cache.urllib.request, 'urlopen') as request:
            self.assertEqual(self.acquire(), self.target)
        request.assert_not_called()
        self.assertEqual(sha(self.target.read_bytes()), self.digest)

    def test_T003_cache_corruption_is_reacquired_before_reuse(self):
        self.target.write_bytes(b'tampered')
        with patch.object(self.cache.urllib.request, 'urlopen', return_value=io.BytesIO(self.payload)) as request:
            self.acquire()
        self.assertEqual(request.call_count, 1)
        self.assertEqual(self.target.read_bytes(), self.payload)

    def test_T003_corrupt_download_never_publishes_a_valid_cache_file(self):
        with patch.object(self.cache.urllib.request, 'urlopen', side_effect=lambda *a, **k: io.BytesIO(b'wrong bytes')) as request:
            with self.assertRaises(ValueError):
                self.acquire()
        self.assertLessEqual(request.call_count, 3)
        self.assertFalse(self.target.exists())
        self.assertEqual(list(self.directory.iterdir()), [], 'rejected bytes or temporary files were left behind')

    def test_T003_acquisition_retries_are_bounded_and_failures_logged(self):
        errors = io.StringIO()
        responses = [OSError('temporary acquisition failure'), OSError('temporary acquisition failure'), io.BytesIO(self.payload)]
        with patch.object(self.cache.urllib.request, 'urlopen', side_effect=responses) as request, contextlib.redirect_stderr(errors):
            self.acquire()
        self.assertEqual(request.call_count, 3)
        self.assertIn('attempt 1', errors.getvalue())
        self.assertIn('attempt 2', errors.getvalue())
        self.target.unlink()
        errors = io.StringIO()
        with patch.object(self.cache.urllib.request, 'urlopen', side_effect=OSError('unavailable')) as request, contextlib.redirect_stderr(errors):
            with self.assertRaises((OSError, ValueError)):
                self.acquire()
        self.assertEqual(request.call_count, 3)
        self.assertIn('attempt 3', errors.getvalue())
        self.assertFalse(self.target.exists())

    def test_T003_cache_paths_never_follow_symlinks(self):
        outside = self.directory / 'outside'
        outside.write_bytes(b'untouched')
        self.symlink(self.target, outside)
        with patch.object(self.cache.urllib.request, 'urlopen') as request, self.assertRaises(ValueError):
            self.acquire()
        request.assert_not_called()
        self.assertEqual(outside.read_bytes(), b'untouched')

    def test_T003_pester_package_and_manifest_pins_match_observed_bytes(self):
        self.assertEqual(self.cache.PESTER_VERSION, REAL_VERSION)
        self.assertEqual(self.cache.PESTER_SHA256, REAL_ARCHIVE_SHA256)
        self.assertEqual(self.cache.PESTER_MANIFEST_SHA256, REAL_MANIFEST_SHA256)
        self.assertEqual(self.cache.PESTER_URL, REAL_URL)

    def test_symlinked_cache_ancestor_is_refused_without_network(self):
        real = self.directory / 'real-cache'
        real.mkdir()
        link = self.directory / 'linked-cache'
        self.symlink(link, real, directory=True)
        with patch.object(self.cache.urllib.request, 'urlopen', return_value=io.BytesIO(self.payload)) as request:
            with self.assertRaises(ValueError):
                self.acquire(link / 'pester.nupkg')
        request.assert_not_called()
        self.assertEqual(list(real.iterdir()), [])

    def test_every_cache_hit_rehashes_even_when_size_and_mtime_are_unchanged(self):
        self.target.write_bytes(self.payload)
        with patch.object(self.cache.urllib.request, 'urlopen') as request:
            self.acquire()
        request.assert_not_called()
        before = self.target.stat()
        self.target.write_bytes(b'X' * len(self.payload))
        os.utime(self.target, ns=(before.st_atime_ns, before.st_mtime_ns))
        with patch.object(self.cache.urllib.request, 'urlopen', return_value=io.BytesIO(self.payload)) as request:
            self.assertEqual(self.acquire(), self.target)
        self.assertEqual(request.call_count, 1)
        self.assertEqual(self.target.read_bytes(), self.payload)

    def test_download_is_published_atomically_from_unique_same_directory_temporary(self):
        decoys = [self.directory / name for name in ('pester.nupkg.tmp', 'pester.nupkg.part', '.pester.nupkg.tmp')]
        for decoy in decoys:
            decoy.write_bytes(b'decoy')
        with patch.object(self.cache.urllib.request, 'urlopen', return_value=io.BytesIO(self.payload)), \
                patch('os.replace', wraps=os.replace) as replace:
            self.acquire()
        publications = [call for call in replace.call_args_list if Path(call.args[1]) == self.target]
        self.assertEqual(len(publications), 1, 'cache file must be published by one atomic replace')
        source = Path(publications[0].args[0])
        self.assertEqual(source.parent, self.target.parent)
        self.assertNotIn(source, [self.target, *decoys])
        self.assertEqual({path.name for path in self.directory.iterdir()}, {'pester.nupkg', *(d.name for d in decoys)})
        for decoy in decoys:
            self.assertEqual(decoy.read_bytes(), b'decoy')
        self.assertEqual(self.target.read_bytes(), self.payload)
        self.assertFalse(self.target.stat().st_mode & 0o111, 'cached download must not be executable')
        self.assert_never_executed()


class PesterInstallFixture(CacheFixture):
    def setUp(self):
        super().setUp()
        self.cache_dir = self.directory / 'dependency-cache'
        self.module_root = self.directory / 'modules'
        self.version_dir = self.module_root / 'Pester' / REAL_VERSION

    @contextlib.contextmanager
    def pinned(self, raw, manifest_sha256=None):
        """Patch archive/manifest pins to the synthetic fixture; real pins are asserted separately."""
        with patch.object(self.cache, 'PESTER_SHA256', sha(raw)), \
                patch.object(self.cache, 'PESTER_MANIFEST_SHA256', manifest_sha256 or sha(MANIFEST)), \
                patch.object(self.cache.urllib.request, 'urlopen', side_effect=lambda *a, **k: io.BytesIO(raw)) as request:
            yield request

    def install(self, raw, **kwargs):
        with self.pinned(raw, **kwargs) as request:
            result = self.cache.install_pester(self.cache_dir, self.module_root)
        return result, request

    def assert_rejected(self, raw, **kwargs):
        with self.pinned(raw, **kwargs), self.assertRaises(ValueError):
            self.cache.install_pester(self.cache_dir, self.module_root)
        self.assertFalse(self.version_dir.exists(), 'validation must finish before publishing any module file')
        self.assert_never_executed()

    def assert_fresh_tree(self, version_dir):
        installed = files(version_dir)
        for name, data in MODULE_FILES.items():
            self.assertEqual(installed.get(name), data, name)
        self.assertLessEqual(set(installed), set(MODULE_FILES) | set(PACKAGING_FILES),
                             'only module files and inert NuGet packaging files may be installed')
        self.assertFalse(any(path.is_symlink() for path in Path(version_dir).rglob('*')))

    def assert_cache_holds_only_package(self, raw):
        entries = list(self.cache_dir.iterdir())
        self.assertEqual(len(entries), 1, 'dependency cache must hold only the package bytes')
        self.assertTrue(entries[0].name.endswith('.nupkg') and entries[0].is_file() and not entries[0].is_symlink())
        self.assertEqual(entries[0].read_bytes(), raw)
        return entries[0]


class PesterInstallTests(PesterInstallFixture):
    def test_install_extracts_validated_fresh_tree_and_caches_only_package(self):
        raw = package()
        result, request = self.install(raw)
        self.assertEqual(Path(result), self.version_dir)
        self.assertEqual(request.call_count, 1)
        self.assertEqual(requested_url(request.call_args), self.cache.PESTER_URL)
        self.assert_fresh_tree(self.version_dir)
        self.assertEqual([path.name for path in self.module_root.iterdir()], ['Pester'])
        self.assertEqual([path.name for path in (self.module_root / 'Pester').iterdir()], [REAL_VERSION])
        self.assert_cache_holds_only_package(raw)
        self.assert_never_executed()

    def test_cache_hit_installs_fresh_module_root_without_network(self):
        raw = package()
        self.install(raw)
        self.module_root = self.directory / 'second-job-modules'
        self.version_dir = self.module_root / 'Pester' / REAL_VERSION
        result, request = self.install(raw)
        request.assert_not_called()
        self.assertEqual(Path(result), self.version_dir)
        self.assert_fresh_tree(self.version_dir)

    def test_corrupt_cached_package_is_reacquired_before_extraction(self):
        raw = package()
        self.install(raw)
        cached = self.assert_cache_holds_only_package(raw)
        cached.write_bytes(raw[:-1] + bytes([raw[-1] ^ 1]))
        self.module_root = self.directory / 'after-corruption'
        self.version_dir = self.module_root / 'Pester' / REAL_VERSION
        _, request = self.install(raw)
        self.assertEqual(request.call_count, 1)
        self.assert_cache_holds_only_package(raw)
        self.assert_fresh_tree(self.version_dir)

    def test_symlinked_cache_dir_is_refused_without_network(self):
        real = self.directory / 'real-cache'
        real.mkdir()
        self.symlink(self.cache_dir, real, directory=True)
        with self.pinned(package()) as request, self.assertRaises(ValueError):
            self.cache.install_pester(self.cache_dir, self.module_root)
        request.assert_not_called()
        self.assertEqual(list(real.iterdir()), [])

    def test_unsafe_member_names_are_rejected_before_extraction(self):
        names = ['../escape.ps1', '/absolute.ps1', 'Functions/../../escape.ps1', 'C:/escape.ps1', 'C:escape.ps1',
                 'Functions\\escape.ps1', '\\\\server\\share\\escape.ps1', 'Functions//It2.ps1', './escape.ps1',
                 'Functions/../escape.ps1']
        for name in names:
            with self.subTest(name=name):
                raw = package((name, b'planted'))
                self.assertIn(name, zipfile.ZipFile(io.BytesIO(raw)).namelist(), 'fixture lost the unsafe name')
                self.assert_rejected(raw)
                self.assertFalse((self.directory / 'escape.ps1').exists())

    def test_symlink_duplicate_and_collision_members_are_rejected(self):
        cases = {
            'symlink': [symlink_entry('Functions/Link.ps1')],
            'duplicate': [('Pester.psm1', b'second copy')],
            'case-duplicate': [('functions/it.ps1', b'case variant')],
            'file-then-directory': [('Pester.psm1/inner.ps1', b'nested under file')],
            'directory-entry-over-file': [('Pester.psm1/', b'')],
            'directory-then-file': [('Functions', b'file over directory')],
        }
        for kind, extra in cases.items():
            with self.subTest(kind=kind):
                self.assert_rejected(package(*extra))

    def test_invalid_or_corrupt_archives_are_typed_errors_without_partial_tree(self):
        self.assert_rejected(b'pinned bytes that are not a zip archive')
        raw = bytearray(package())
        info = zipfile.ZipFile(io.BytesIO(bytes(raw))).getinfo('Pester.psm1')
        offset = info.header_offset
        offset += 30 + int.from_bytes(raw[offset+26:offset+28], 'little') + int.from_bytes(raw[offset+28:offset+30], 'little')
        raw[offset:offset+2] = b'\xff\xff'
        self.assert_rejected(bytes(raw))

    def test_root_manifest_bytes_are_validated_not_version_string(self):
        self.assert_rejected(package(omit={'Pester.psd1'}))
        self.assert_rejected(package(('Pester/Pester.psd1', MANIFEST), omit={'Pester.psd1'}))
        forged = MANIFEST + b"# ModuleVersion = '4.10.1' forged\r\n"
        self.assert_rejected(package(('Pester.psd1', forged), omit={'Pester.psd1'}))

    def test_tampered_installed_module_is_repaired_or_fails_closed(self):
        raw = package()
        self.install(raw)
        (self.version_dir / 'Pester.psd1').write_bytes(MANIFEST + b'# tampered, same ModuleVersion\r\n')
        (self.version_dir / 'Functions/It.ps1').write_bytes(b'function It { "tampered" }')
        (self.version_dir / 'planted.ps1').write_bytes(b'planted')
        try:
            result, request = self.install(raw)
        except ValueError:
            return  # fail-closed is acceptable; must not report success over tampered bytes
        request.assert_not_called()
        self.assertEqual(Path(result), self.version_dir)
        self.assert_fresh_tree(self.version_dir)

    def test_existing_symlinks_in_module_root_are_never_written_through(self):
        for relative in ('Pester', f'Pester/{REAL_VERSION}', f'Pester/{REAL_VERSION}/Functions'):
            with self.subTest(link=relative):
                self.module_root = self.directory / f'modules-{relative.count("/")}'
                self.version_dir = self.module_root / 'Pester' / REAL_VERSION
                link = self.module_root / relative
                link.parent.mkdir(parents=True)
                outside = self.directory / f'outside-{relative.count("/")}'
                outside.mkdir()
                self.symlink(link, outside, directory=True)
                try:
                    result, _ = self.install(package())
                except ValueError:
                    pass
                else:
                    self.assertFalse(Path(result).is_symlink())
                    self.assertFalse((self.module_root / 'Pester').is_symlink())
                    self.assert_fresh_tree(result)
                self.assertEqual(list(outside.iterdir()), [], 'install wrote through an existing symlink')


class PinnedPesterTests(PesterInstallFixture):
    """Real observed pins stay in force; synthetic bytes can never satisfy them."""
    def test_real_pins_reject_synthetic_package_without_publishing(self):
        self.assertEqual(self.cache.PESTER_SHA256, REAL_ARCHIVE_SHA256)
        self.assertEqual(self.cache.PESTER_MANIFEST_SHA256, REAL_MANIFEST_SHA256)
        raw = package()
        with patch.object(self.cache.urllib.request, 'urlopen', side_effect=lambda *a, **k: io.BytesIO(raw)) as request:
            with self.assertRaises(ValueError):
                self.cache.install_pester(self.cache_dir, self.module_root)
        self.assertGreaterEqual(request.call_count, 1)
        self.assertTrue(all(requested_url(call) == REAL_URL for call in request.call_args_list))
        self.assertFalse(self.version_dir.exists())
        self.assertFalse(self.cache_dir.exists() and any(self.cache_dir.iterdir()), 'mismatched bytes were cached')


class PesterCliTests(PesterInstallFixture):
    def run_cli(self, argv):
        stdout, stderr = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            try:
                code = self.cache.main(argv)
            except SystemExit as exit_:
                code = exit_.code
            except Exception as error:
                self.fail('typed CLI error boundary leaked ' + type(error).__name__)
        return code, stderr.getvalue()

    def argv(self):
        return ['pester', '--cache-dir', str(self.cache_dir), '--module-root', str(self.module_root)]

    def test_cli_installs_pinned_package(self):
        raw = package()
        with self.pinned(raw) as request:
            code, stderr = self.run_cli(self.argv())
        self.assertEqual(code, 0)
        self.assertNotIn('Traceback', stderr)
        self.assertEqual(requested_url(request.call_args), self.cache.PESTER_URL)
        self.assert_fresh_tree(self.version_dir)
        self.assert_cache_holds_only_package(raw)

    def test_cli_failures_return_typed_nonzero_without_traceback(self):
        unavailable = patch.object(self.cache.urllib.request, 'urlopen', side_effect=OSError('unavailable'))
        synthetic = patch.object(self.cache.urllib.request, 'urlopen', side_effect=lambda *a, **k: io.BytesIO(package()))
        for label, mock in (('unavailable', unavailable), ('real-pin-mismatch', synthetic)):
            with self.subTest(failure=label):
                with mock:
                    code, stderr = self.run_cli(self.argv())
                self.assertIsInstance(code, int)
                self.assertNotEqual(code, 0)
                self.assertNotIn('Traceback', stderr)
                self.assertFalse(self.version_dir.exists())
        for argv in (['unknown'], ['pester', '--cache-dir', str(self.cache_dir)]):
            with self.subTest(argv=argv):
                code, stderr = self.run_cli(argv)
                self.assertIsInstance(code, int)
                self.assertNotEqual(code, 0)
                self.assertNotIn('Traceback', stderr)


if __name__ == '__main__':
    unittest.main()
