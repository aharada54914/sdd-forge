#!/usr/bin/env python3
"""Public address, redirect, decoding and no-persistence acquisition controls."""

import gzip
import io
import os
import shutil
import base64
import copy
import importlib.util
import json
from pathlib import Path
import socket
import subprocess
import struct
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "acquire", ROOT / "plugins/sdd-bootstrap/scripts/research-acquire.py"
)
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)


def resolver(host, port, **kwargs):
    return [(socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", port))]


def response(url, addresses, timeout):
    return (
        200,
        {"content-type": "text/plain; charset=utf-8"},
        b"This is a reproducible source text.",
    )


class Acquire(unittest.TestCase):
    @unittest.skipUnless(sys.platform == 'linux', 'Linux shared-store adapter')
    def test_shared_store_permissions_receipt_expiry_and_existing_snapshot(self):
        from research_evidence import shared_snapshot
        # The real store is outside the repository and system temp export roots.
        with tempfile.TemporaryDirectory(prefix='research-shared-', dir=Path.home()) as directory:
            root = Path(directory)
            cache = root / 'store'
            cache.mkdir(mode=0o750)
            cache.chmod(0o750)
            metadata, body, extracted = self.run_acquire()
            def save():
                return a.save_cache(metadata, body, extracted, cache, repository=ROOT,
                                    permission_basis='Synthetic fixture may be shared with the named OS group.',
                                    expires_at='2099-01-01T00:00:00Z', shared_gid=os.getegid())
            saved = save()
            source = a.source_record(saved, 'SRC-001', 'Synthetic shared source',
                                     'Synthetic fixture may be shared with the named OS group.')
            key = saved['cache_key']
            item = dict(original=f'{key}/original', extracted=f'{key}/extracted.txt')
            shared_snapshot(cache, item, source)
            self.assertEqual(source['storage_mode'], 'licensed_shared')
            entry = cache / key
            with self.assertRaisesRegex(a.Invalid, 'snapshot-exists'):
                save()
            self.assertEqual((entry / 'original').read_bytes(), body)
            original = entry / 'original'
            original.chmod(0o644)
            with self.assertRaisesRegex(a.Invalid, 'shared-permissions'):
                shared_snapshot(cache, item, source)
            original.chmod(0o640)
            alias = root / 'alias'
            os.link(original, alias)
            with self.assertRaisesRegex(a.Invalid, 'shared-permissions'):
                shared_snapshot(cache, item, source)
            alias.unlink()
            backup = root / 'original-backup'
            original.rename(backup)
            original.symlink_to(backup)
            with self.assertRaisesRegex(a.Invalid, 'shared-permissions'):
                shared_snapshot(cache, item, source)
            original.unlink()
            backup.rename(original)
            root.chmod(0o770)
            with self.assertRaisesRegex(a.Invalid, 'shared-parent-permissions'):
                shared_snapshot(cache, item, source)
            root.chmod(0o700)
            acl = struct.pack('<I', 2) + b''.join(struct.pack('<HHI', *entry) for entry in
                [(1, 6, 0xffffffff), (2, 4, 65534), (4, 4, 0xffffffff), (16, 4, 0xffffffff), (32, 0, 0xffffffff)])
            os.setxattr(original, 'system.posix_acl_access', acl)
            with self.assertRaisesRegex(a.Invalid, 'shared-acl-unsupported'):
                shared_snapshot(cache, item, source)
            os.removexattr(original, 'system.posix_acl_access')
            receipt = entry / 'receipt.json'
            raw = receipt.read_bytes()
            changed = json.loads(raw)
            changed['permission_basis'] = 'Different permission'
            receipt.write_text(json.dumps(changed))
            with self.assertRaisesRegex(a.Invalid, 'shared-receipt-mismatch'):
                shared_snapshot(cache, item, source)
            receipt.write_bytes(raw)
            self.assertEqual(a.purge_cache(cache, shared_gid=os.getegid(), now='2098-01-01T00:00:00Z')['deleted'], 0)
            self.assertEqual(a.purge_cache(cache, shared_gid=os.getegid(), now='2100-01-01T00:00:00Z')['deleted'], 1)
            self.assertFalse(entry.exists())
            save()
            self.assertEqual(a.purge_cache(cache, shared_gid=os.getegid(), revoke=[key])['deleted'], 1)

    @unittest.skipUnless(sys.platform == 'linux' and hasattr(os, 'geteuid') and os.geteuid() == 0,
                         'Distinct reader identities require isolated root-capable Linux CI')
    def test_shared_store_actual_allowed_and_denied_reader_identities(self):
        with tempfile.TemporaryDirectory(prefix='research-shared-', dir='/var/lib') as directory:
            root = Path(directory)
            root.chmod(0o755)
            cache = root / 'store'
            cache.mkdir(mode=0o750)
            cache.chmod(0o750)
            metadata, body, extracted = self.run_acquire()
            saved = a.save_cache(metadata, body, extracted, cache, repository=ROOT,
                                 permission_basis='Synthetic group-reader test permission',
                                 expires_at='2099-01-01T00:00:00Z', shared_gid=os.getegid())
            original = cache / saved['cache_key'] / 'original'
            fixture_spec = importlib.util.spec_from_file_location('shared_fixture', ROOT / 'tests/research-evidence.tests.py')
            fixture = importlib.util.module_from_spec(fixture_spec)
            fixture_spec.loader.exec_module(fixture)
            document = fixture.document()
            document['sources'] = [a.source_record(saved, 'SRC-001', 'Synthetic source',
                                                   'Synthetic group-reader test permission')]
            anchor = document['claims'][0]['citations'][0]['anchor']
            anchor.update(quote=extracted.decode(), quote_sha256=a.digest(extracted))
            snapshots = dict(schema='research-snapshots/v1', feature=document['feature'], snapshots=[dict(
                source_id='SRC-001', record_revision=1, original=f"{saved['cache_key']}/original",
                extracted=f"{saved['cache_key']}/extracted.txt")])
            script = '''import os,sys,pathlib,json
path=pathlib.Path(sys.argv[1]); result={}
for operation,mode in [('read','rb'),('write','ab')]:
 try:
  with path.open(mode) as stream:
   if operation=='read': stream.read()
  result[operation]=True
 except PermissionError: result[operation]=False
result['capabilities_zero']='CapEff:\\t0000000000000000' in pathlib.Path('/proc/self/status').read_text()
sys.path.insert(0,sys.argv[2])
from research_consumers import verify_originals
from research_evidence import Invalid
document,snapshots=json.loads(sys.argv[3])
try: result['verified']=verify_originals(document,snapshots,path.parent.parent)['complete']
except Invalid as error:
 if error.code!='shared-access-denied': raise
 result['verified']=False
try: verify_originals(document,snapshots,path.parent.parent,now='2100-01-01T00:00:00Z')
except Invalid as error: result['expired']=error.code=='rights-expired'
print(json.dumps(result))
'''
            for uid, gid, allowed in [(65534, os.getegid(), True), (65533, 65533, False)]:
                result = subprocess.run([sys.executable, '-c', script, str(original), str(a.QUALITY),
                                         json.dumps([document, snapshots])], user=uid, group=gid,
                                        extra_groups=[], capture_output=True, text=True, check=True)
                self.assertEqual(json.loads(result.stdout), dict(read=allowed, write=False, capabilities_zero=True,
                                                                verified=allowed, expired=True))
            self.assertEqual(a.purge_cache(cache, shared_gid=os.getegid(), now='2100-01-01T00:00:00Z')['deleted'], 1)
            self.assertFalse(original.exists())

    def test_subtitles_preserve_payload_and_normalize_only_cue_timing(self):
        for media, header, timing in [('text/vtt', 'WEBVTT\n\n', '00:01.200 --> 00:03.500'),
                                      ('application/x-subrip', '1\n', '00:00:01,200 --> 00:00:03,500')]:
            raw = (header + timing + '\nOriginal statement with context.\n').replace('\n', '\r\n').encode()
            expected = b'[cue 1200 3500 ms]\nOriginal statement with context.\n'
            def transport(*args):
                return 200, {'content-type': media}, raw
            metadata, body, extracted = a._acquire('https://example.org/captions', ['example.org'],
                                                   resolver=resolver, transport=transport)
            self.assertEqual(raw, body)
            self.assertEqual(expected, extracted)
            packet = json.dumps(dict(metadata=metadata, body=base64.b64encode(body).decode(),
                                     extracted=base64.b64encode(extracted).decode())).encode()
            with mock.patch.object(a, 'getproxies', return_value={}), mock.patch.object(a, '_run_bounded', return_value=(0, packet)):
                self.assertEqual(a.acquire('https://example.org/captions', ['example.org'])[0], metadata)

    def test_subtitle_unsupported_semantics_and_forged_headers_fail_closed(self):
        from research_extraction import extract
        bad = ['WEBVTT\nX-TIMESTAMP-MAP=LOCAL:00:00:00.000,MPEGTS:900000\n\n00:01.000 --> 00:02.000\ntext',
               'WEBVTT\n\n00:03.000 --> 00:02.000\ntext',
               'WEBVTT\n\n00:01.000 --> 00:02.000 align:start\ntext',
               'WEBVTT\n\n00:01.000 --> 00:02.000\n<00:01.500>text',
               'WEBVTT\n\n00:01.000 --> 00:02.000\n[cue 9000 9500 ms]',
               'WEBVTT\n\n00:01.000 --> 00:02.000\n<script>text</script>',
               'WEBVTT\n\n00:61.000 --> 00:62.000\ntext',
               'WEBVTT\n\n00:01.000 --> 00:02.000\ntext\n\nSTYLE\n::cue { color: red }',
               'WEBVTT\n\n00:03.000 --> 00:05.000\nfirst\n\n00:01.000 --> 00:02.000\nsecond']
        for value in bad:
            with self.subTest(value=value), self.assertRaises(a.Invalid):
                extract(value.encode(), 'text/vtt')

    def test_invalid_total_budget_never_launches_worker(self):
        for timeout in [float("nan"), float("inf"), -1, 0, 61, 10**1000, True, "1"]:
            with (
                self.subTest(timeout=timeout),
                mock.patch.object(a.subprocess, "Popen") as launch,
            ):
                with self.assertRaisesRegex(a.Invalid, "budget-invalid"):
                    a.acquire("https://example.org", ["example.org"], timeout=timeout)
                launch.assert_not_called()

    def test_public_proxy_refusal_never_launches_worker(self):
        with (
            mock.patch.object(
                a, "getproxies", return_value={"https": "http://proxy.invalid"}
            ),
            mock.patch.object(a.subprocess, "Popen") as launch,
        ):
            with self.assertRaisesRegex(a.Invalid, "proxy-adapter-required"):
                a.acquire("https://example.org", ["example.org"])
            launch.assert_not_called()

    def test_total_deadline_kills_and_reaps_blocked_dns_and_transport(self):
        # Actual subprocesses, with no network: block inside each acquisition stage.
        module = str(Path(a.__file__).resolve())
        for stage in ["dns", "transport"]:
            code = (
                "import runpy,time,socket; "
                f"m=runpy.run_path({module!r}); "
                "block=lambda *args,**kwargs: time.sleep(60); "
                "dns=lambda *args,**kwargs:[(socket.AF_INET,socket.SOCK_STREAM,6,'',('93.184.216.34',443))]; "
                "m['_acquire']('https://example.org',['example.org'],"
                f"resolver={'block' if stage == 'dns' else 'dns'},transport=block)"
            )
            real_launch = subprocess.Popen
            with (
                self.subTest(stage=stage),
                mock.patch.object(a.subprocess, "Popen", wraps=real_launch) as launch,
            ):
                with self.assertRaisesRegex(a.Invalid, "transport-timeout"):
                    a._run_bounded([sys.executable, "-I", "-B", "-c", code], b"", 0.2)
                # Track the real instance separately: wrapping Popen's return_value is a mock.
                self.assertEqual(1, launch.call_count)

    def test_deadline_reaps_exact_worker_and_closes_pipes(self):
        workers = []
        real_launch = subprocess.Popen

        def launch(*args, **kwargs):
            worker = real_launch(*args, **kwargs)
            workers.append(worker)
            return worker

        with mock.patch.object(a.subprocess, "Popen", side_effect=launch):
            with self.assertRaisesRegex(a.Invalid, "transport-timeout"):
                a._run_bounded(
                    [sys.executable, "-I", "-c", "import time; time.sleep(60)"],
                    b"",
                    0.1,
                )
        self.assertIsNotNone(workers[0].poll())
        self.assertTrue(
            all(
                stream is None or stream.closed
                for stream in (workers[0].stdin, workers[0].stdout, workers[0].stderr)
            )
        )

    def test_cleanup_failure_is_explicit(self):
        worker = mock.Mock()
        worker.poll.return_value = None
        worker.kill.side_effect = OSError("private operating system detail")
        with self.assertRaisesRegex(a.Invalid, "^transport-cleanup-failed$"):
            a._stop_worker(worker)

    def test_public_worker_protocol_binds_body_hash_and_preserves_budget(self):
        metadata, body, extracted = self.run_acquire()
        packet = dict(
            metadata=metadata,
            body=base64.b64encode(body).decode(),
            extracted=base64.b64encode(extracted).decode(),
        )
        with (
            mock.patch.object(a, "getproxies", return_value={}),
            mock.patch.object(
                a, "_run_bounded", return_value=(0, json.dumps(packet).encode())
            ) as run,
        ):
            self.assertEqual(
                (metadata, body, extracted),
                a.acquire(
                    "https://example.org/doc", ["example.org"], timeout=2, redirects=1
                ),
            )
            command, payload, timeout = run.call_args.args
            self.assertEqual(["-I", "-B"], command[1:3])
            self.assertEqual(2, timeout)
            self.assertEqual(1, json.loads(payload)["redirects"])
            packet["body"] = base64.b64encode(b"replacement").decode()
            run.return_value = (0, json.dumps(packet).encode())
            with self.assertRaisesRegex(a.Invalid, "transport-worker-invalid"):
                a.acquire("https://example.org/doc", ["example.org"])

    def test_malformed_worker_success_fails_closed(self):
        metadata, body, extracted = self.run_acquire()
        control = dict(
            metadata=metadata,
            body=base64.b64encode(body).decode(),
            extracted=base64.b64encode(extracted).decode(),
        )
        invalid = []
        missing = copy.deepcopy(control)
        missing["metadata"] = {
            "content_sha256": a.digest(b""),
            "extraction": {"extracted_sha256": a.digest(b"")},
        }
        missing.update(body="", extracted="")
        invalid.append(missing)
        for key, value in [
            ("url", "https://unrelated.invalid/doc"),
            ("final_url", "http://127.0.0.1/"),
            ("retrieved_at", "yesterday"),
            ("storage_mode", "local_cache"),
            ("media_type", "image/png"),
        ]:
            packet = copy.deepcopy(control)
            packet["metadata"][key] = value
            invalid.append(packet)
        for raw in [b"", b"short", b"\xff" * 30]:
            packet = copy.deepcopy(control)
            packet["extracted"] = base64.b64encode(raw).decode()
            packet["metadata"]["extraction"]["extracted_sha256"] = a.digest(raw)
            invalid.append(packet)
        with (
            mock.patch.object(a, "getproxies", return_value={}),
            mock.patch.object(a, "_run_bounded") as run,
        ):
            for packet in invalid:
                with self.subTest(packet=packet):
                    run.return_value = (0, json.dumps(packet).encode())
                    with self.assertRaises(a.Invalid):
                        a.acquire("https://example.org/doc", ["example.org"])

    def run_acquire(self, **kwargs):
        return a._acquire(
            "https://example.org/doc",
            ["example.org"],
            resolver=resolver,
            transport=response,
            **kwargs,
        )

    def test_default_is_metadata_only_with_exact_original_and_extracted_hashes(self):
        m, b, t = self.run_acquire()
        self.assertEqual("reference_only", m["storage_mode"])
        self.assertEqual(a.digest(b), m["content_sha256"])
        self.assertEqual(a.digest(t), m["extraction"]["extracted_sha256"])
        s = a.source_record(m, "SRC-001", "Example source")
        self.assertEqual("unverified", s["verification_status"])
        self.assertEqual("unknown", s["license_or_permission_basis"]["status"])

    def test_denies_every_private_dns_result(self):
        for ip in [
            "127.0.0.1",
            "10.0.0.1",
            "169.254.169.254",
            "192.168.1.1",
            "::1",
            "fc00::1",
            "0.0.0.0",
            "224.0.0.1",
        ]:

            def bad(*args, **kwargs):
                return resolver(*args, **kwargs) + [
                    (socket.AF_INET, socket.SOCK_STREAM, 6, "", (ip, 443))
                ]

            with self.subTest(ip=ip), self.assertRaises(a.Invalid):
                a._acquire(
                    "https://example.org",
                    ["example.org"],
                    resolver=bad,
                    transport=response,
                )

    def test_internal_redirect_and_unallowed_domain_never_connect(self):
        calls = []

        def redirect(url, *args):
            calls.append(url)
            return 302, {"location": "http://169.254.169.254/latest"}, b""

        with self.assertRaises(a.Invalid):
            a._acquire(
                "https://example.org",
                ["example.org"],
                resolver=resolver,
                transport=redirect,
            )
        self.assertEqual(1, len(calls))

    def test_public_ip_is_pinned_and_dns_not_requeried_by_transport(self):
        seen = []

        def transport(url, addresses, timeout):
            seen.extend(addresses)
            return response(url, addresses, timeout)

        a._acquire(
            "https://example.org",
            ["example.org"],
            resolver=resolver,
            transport=transport,
        )
        self.assertEqual(["93.184.216.34"], seen)

    def test_redirect_budget_and_allowlist_each_hop(self):
        def redirect(*args):
            return 302, {"location": "https://example.org/again"}, b""

        with self.assertRaisesRegex(a.Invalid, "redirect-limit"):
            a._acquire(
                "https://example.org",
                ["example.org"],
                resolver=resolver,
                transport=redirect,
                redirects=1,
            )

    def test_http_requires_explicit_exception(self):
        with self.assertRaisesRegex(a.Invalid, "scheme-not-allowed"):
            a._acquire(
                "http://example.org",
                ["example.org"],
                resolver=resolver,
                transport=response,
            )
        a._acquire(
            "http://example.org",
            ["example.org"],
            resolver=resolver,
            transport=response,
            allow_http=True,
        )

    def test_unsupported_scheme_credentials_ports_are_rejected(self):
        for url in [
            "file:///etc/passwd",
            "https://u:p@example.org",
            "https://example.org:22/",
            "https://example.org/?token=abc",
            "https://other.org",
        ]:
            with self.subTest(url=url), self.assertRaises(a.Invalid):
                a._acquire(url, ["example.org"], resolver=resolver, transport=response)

    def test_proxy_refuses_instead_of_bypassing(self):
        with (
            mock.patch.object(
                a, "getproxies", return_value={"https": "http://proxy:8080"}
            ),
            mock.patch.object(a.socket, "create_connection") as connect,
        ):
            with self.assertRaisesRegex(a.Invalid, "proxy-adapter-required"):
                a.request_pinned("https://example.org", ["93.184.216.34"], 1)
            connect.assert_not_called()

    def test_status_empty_and_disguised_media_are_distinct(self):
        cases = [
            (403, {"content-type": "text/plain"}, b"no", "access-restricted"),
            (404, {}, b"", "unreachable"),
            (200, {"content-type": "text/plain"}, b"", "empty-response"),
            (
                200,
                {"content-type": "application/pdf"},
                b"<html>not pdf</html>",
                "media-mismatch",
            ),
            (
                200,
                {"content-type": "text/plain"},
                b"<html>This is a login wall and not plaintext</html>",
                "media-mismatch",
            ),
        ]
        for status, headers, body, error in cases:
            with self.subTest(error=error), self.assertRaisesRegex(a.Invalid, error):
                a._acquire(
                    "https://example.org",
                    ["example.org"],
                    resolver=resolver,
                    transport=lambda *args: (status, headers, body),
                )

    def test_login_wall_and_pdf_are_not_success(self):
        for raw, ctype, error in [
            (
                b'<form><input type="password">Sign in to continue reading this text</form>',
                "text/html",
                "access-wall",
            ),
            (
                b"%PDF-1.5 many bytes but no sandboxed extractor",
                "application/pdf",
                "pdf-(extractor-unavailable|sandbox-unavailable|invalid)",
            ),
        ]:
            with self.assertRaisesRegex(a.Invalid, error):
                a.extract(raw, ctype)

    def test_gzip_bomb_and_oversized_response(self):
        compressed = gzip.compress(b"x" * (a.MAX_RESPONSE + 1))
        for body, encoding in [
            (compressed, "gzip"),
            (b"x" * (a.MAX_RESPONSE + 1), "identity"),
        ]:
            with self.assertRaisesRegex(a.Invalid, "response-too-large"):
                a._acquire(
                    "https://example.org",
                    ["example.org"],
                    resolver=resolver,
                    transport=lambda *args: (
                        200,
                        {"content-type": "text/plain", "content-encoding": encoding},
                        body,
                    ),
                )

    def test_decode_and_html_do_not_execute_instructions(self):
        text, method, media = a.extract(
            b"<p>This is the actual source text.</p><script>throw new Error()</script>",
            "text/html",
        )
        self.assertNotIn(b"throw", text)
        self.assertEqual("html-text/v1", method)
        text, _, _ = a.extract(
            ("日本語の取得本文を十分な長さで確認するための原文です。" * 2).encode(
                "cp932"
            ),
            "text/plain; charset=cp932",
        )
        self.assertIn("日本語", text.decode())

    def test_cache_inside_repository_or_temp_rejected_before_write(self):
        m, b, t = self.run_acquire()
        with tempfile.TemporaryDirectory() as td:
            cache = Path(td) / "cache"
            with self.assertRaisesRegex(a.Invalid, "cache-export-boundary"):
                a.save_cache(
                    m,
                    b,
                    t,
                    cache,
                    repository=td,
                    permission_basis="owner license",
                    expires_at="2099-01-01T00:00:00Z",
                )
            self.assertFalse(cache.exists())

    def test_cache_missing_permission_or_expiry_rejected(self):
        m, b, t = self.run_acquire()
        with self.assertRaisesRegex(a.Invalid, "permission-required"):
            a.save_cache(
                m,
                b,
                t,
                "/unused",
                repository=str(ROOT),
                permission_basis="",
                expires_at="2099-01-01T00:00:00Z",
            )
        with self.assertRaisesRegex(a.Invalid, "rights-expired"):
            a.save_cache(
                m,
                b,
                t,
                "/unused",
                repository=str(ROOT),
                permission_basis="owner license",
                expires_at="2020-01-01T00:00:00Z",
            )

    @unittest.skipUnless(
        a.os.name == "posix", "private cache requires POSIX ACL adapter"
    )
    def test_private_cache_retention_expiry_and_revocation(self):
        metadata, body, extracted = self.run_acquire()
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            # Model a private store outside both repository and runner temp roots.
            with (
                mock.patch.object(
                    a.tempfile, "gettempdir", return_value=str(root / "runner-temp")
                ),
                mock.patch.dict(a.os.environ, {}, clear=True),
            ):
                cache = root / "private-store"

                def save():
                    return a.save_cache(
                        metadata,
                        body,
                        extracted,
                        cache,
                        repository=root / "repo",
                        permission_basis="fixture permission",
                        expires_at="2099-01-01T00:00:00Z",
                    )

                saved = save()
                entry = cache / saved["cache_key"]
                self.assertEqual(body, (entry / "original").read_bytes())
                self.assertEqual(extracted, (entry / "extracted.txt").read_bytes())
                self.assertEqual(0o700, a.stat.S_IMODE(cache.stat().st_mode))
                self.assertTrue(
                    all(
                        a.stat.S_IMODE(p.stat().st_mode) == 0o600
                        for p in entry.iterdir()
                    )
                )
                self.assertEqual(
                    0, a.purge_cache(cache, now="2098-01-01T00:00:00Z")["deleted"]
                )
                self.assertEqual(
                    1, a.purge_cache(cache, now="2100-01-01T00:00:00Z")["deleted"]
                )
                self.assertFalse(entry.exists())
                save()
                self.assertEqual(
                    1,
                    a.purge_cache(
                        cache, revoke=[saved["cache_key"]], now="2098-01-01T00:00:00Z"
                    )["deleted"],
                )
                self.assertFalse(entry.exists())


class PDFExtraction(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if sys.platform != 'linux' or not shutil.which('bwrap') or importlib.util.find_spec('pypdf') is None:
            raise unittest.SkipTest('isolated PDF extraction requires Linux, bwrap and optional pypdf')
        try:
            a.extract(cls.pdf(), 'application/pdf')
        except a.Invalid as error:
            if error.code == 'pdf-sandbox-unavailable':
                raise unittest.SkipTest('kernel/runtime cannot establish PDF sandbox')
            raise

    @staticmethod
    def pdf(blank=False, encrypted=False):
        import pypdf
        from pypdf.generic import DictionaryObject, NameObject, DecodedStreamObject
        writer = pypdf.PdfWriter()
        page = writer.add_blank_page(width=612, height=792)
        if not blank:
            font = DictionaryObject({NameObject('/Type'): NameObject('/Font'),
                                     NameObject('/Subtype'): NameObject('/Type1'),
                                     NameObject('/BaseFont'): NameObject('/Helvetica')})
            page[NameObject('/Resources')] = DictionaryObject({NameObject('/Font'): DictionaryObject({
                NameObject('/F1'): writer._add_object(font)})})
            stream = DecodedStreamObject()
            stream.set_data(b'BT /F1 12 Tf 50 700 Td (Left column first statement.) Tj ET\n'
                            b'BT /F1 12 Tf 320 700 Td (Right column second statement.) Tj ET\n'
                            b'BT /F1 12 Tf 50 680 Td (Left column following context.) Tj ET')
            page[NameObject('/Contents')] = writer._add_object(stream)
        if encrypted:
            writer.encrypt('synthetic-password')
        buffer = io.BytesIO()
        writer.write(buffer)
        return buffer.getvalue()

    def test_actual_pdf_layout_and_version_are_reproducible(self):
        body = self.pdf()
        extracted, method, media = a.extract(body, 'application/pdf')
        self.assertEqual((extracted, method, media), a.extract(body, 'application/pdf'))
        self.assertRegex(method, r'^pypdf-[0-9]+-[0-9]+-[0-9]+-[0-9a-f]{64}-layout/v1$')
        first, second = [line for line in extracted.decode().splitlines() if line.strip()]
        self.assertLess(first.index('Left column first'), first.index('Right column second'))
        self.assertIn('Left column following context.', second)
        for body, expected in ((self.pdf(blank=True), 'pdf-text-unavailable'),
                               (self.pdf(encrypted=True), 'pdf-encrypted'),
                               (b'%PDF-1.7 invalid fixture', 'pdf-invalid')):
            with self.subTest(expected=expected), self.assertRaisesRegex(a.Invalid, expected):
                a.extract(body, 'application/pdf')
        with self.assertRaisesRegex(a.Invalid, 'media-mismatch'):
            a.extract(self.pdf(), 'text/html')

    def test_pdf_acquisition_metadata_binds_actual_parser_output(self):
        body = self.pdf()
        metadata, original, extracted = a._acquire(
            'https://example.org/paper.pdf', ['example.org'], resolver=resolver,
            transport=lambda *_: (200, {'content-type': 'application/pdf'}, body))
        self.assertEqual(body, original)
        self.assertEqual(a.digest(body), metadata['content_sha256'])
        self.assertEqual(a.digest(extracted), metadata['extraction']['extracted_sha256'])
        self.assertEqual('reference_only', metadata['storage_mode'])
        packet = dict(metadata=metadata, body=base64.b64encode(original).decode(),
                      extracted=base64.b64encode(extracted).decode())
        with mock.patch.object(a, 'getproxies', return_value={}), \
             mock.patch.object(a, '_run_bounded', return_value=(0, json.dumps(packet).encode())):
            self.assertEqual((metadata, original, extracted),
                             a.acquire('https://example.org/paper.pdf', ['example.org']))

    def test_pdf_original_verification_rejects_wrong_order_and_recipe(self):
        module_spec = importlib.util.spec_from_file_location('pdf_source_fixture', ROOT / 'tests/research-evidence.tests.py')
        fixture = importlib.util.module_from_spec(module_spec)
        module_spec.loader.exec_module(fixture)
        from research_consumers import verify_originals
        body = self.pdf()
        extracted, method, _ = a.extract(body, 'application/pdf')
        document = fixture.document()
        source = document['sources'][0]
        source.update(media_type='application/pdf', content_sha256=a.digest(body),
                      extraction=dict(method=method, extracted_sha256=a.digest(extracted)))
        first = extracted.decode().splitlines()[0]
        citation = document['claims'][0]['citations'][0]
        citation['anchor'].update(quote=first, quote_sha256=a.digest(first.encode()))
        snapshots = dict(schema='research-snapshots/v1', feature='sample', snapshots=[dict(
            source_id='SRC-001', record_revision=1, original='original', extracted='text')])
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'original').write_bytes(body)
            (root / 'text').write_bytes(extracted)
            self.assertTrue(verify_originals(document, snapshots, root)['complete'])
            forged = b'Right column second statement. Left column first statement.\n'
            (root / 'text').write_bytes(forged)
            source['extraction']['extracted_sha256'] = a.digest(forged)
            with self.assertRaisesRegex(a.Invalid, 'extraction-provenance-mismatch'):
                verify_originals(document, snapshots, root)
            (root / 'text').write_bytes(extracted)
            source['extraction'] = dict(method='pypdf-0-0-0-' + '0' * 64 + '-layout/v1',
                                        extracted_sha256=a.digest(extracted))
            with self.assertRaisesRegex(a.Invalid, 'extraction-provenance-mismatch'):
                verify_originals(document, snapshots, root)

    def test_actual_sandbox_hides_environment_files_and_host_network(self):
        import research_extraction as extraction
        with tempfile.TemporaryDirectory() as directory, socket.socket() as listener:
            root = Path(directory)
            private = root / 'private.txt'
            private.write_text('Synthetic private fixture; must stay outside parser')
            listener.bind(('127.0.0.1', 0))
            listener.listen()
            port = listener.getsockname()[1]
            package = root / 'pypdf'
            package.mkdir()
            # Trusted fault-injection parser tests the real namespace boundary;
            # ordinary PDF extraction above uses the actual installed pypdf.
            (package / '__init__.py').write_text("""import os, socket
__version__ = '0.0.0'
class Page:
    def get_contents(self): return True
    def extract_text(self, **kwargs):
        outcomes = ['env-hidden' if 'PDF_PROBE_SECRET' not in os.environ else 'env-exposed']
        try:
            open(%r).read()
            outcomes.append('file-exposed')
        except OSError:
            outcomes.append('file-hidden')
        connection = socket.socket()
        connection.settimeout(0.2)
        try:
            connection.connect(('127.0.0.1', %d))
            outcomes.append('network-exposed')
        except OSError:
            outcomes.append('network-hidden')
        finally:
            connection.close()
        try:
            open('/tmp/unexpected-write', 'w').write('x')
            outcomes.append('write-exposed')
        except OSError:
            outcomes.append('write-denied')
        try:
            child = os.fork()
            if child == 0: os._exit(0)
            os.waitpid(child, 0)
            outcomes.append('fork-exposed')
        except OSError:
            outcomes.append('fork-denied')
        return ' '.join(outcomes)
class PdfReader:
    is_encrypted = False
    pages = [Page()]
    def __init__(self, *args, **kwargs): pass
""" % (str(private), port))
            parser = importlib.util.spec_from_file_location('pypdf', package / '__init__.py')
            with mock.patch.object(extraction.importlib.util, 'find_spec', return_value=parser), \
                 mock.patch.dict(os.environ, {'PDF_PROBE_SECRET': 'synthetic-value'}):
                output, _, _ = a.extract(b'%PDF-test-isolation', 'application/pdf')
            self.assertEqual(b'env-hidden file-hidden network-hidden write-denied fork-denied', output)
            self.assertTrue(private.exists())


    def test_parser_stdout_cannot_expand_parent_communicate_buffer(self):
        import research_extraction as extraction
        observed = []
        actual_popen = subprocess.Popen
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory) / 'pypdf'
            package.mkdir()
            (package / '__init__.py').write_text(
                "import os\nfor _ in range(1024): os.write(1, b'x' * 65536)\nraise ImportError('probe')\n")
            parser = importlib.util.spec_from_file_location('pypdf', package / '__init__.py')
            def launch(*args, **kwargs):
                captured = kwargs['stdout']
                self.assertNotEqual(subprocess.PIPE, captured)
                process = actual_popen(*args, **kwargs)
                communicate = process.communicate
                def measured(*args, **kwargs):
                    result = communicate(*args, **kwargs)
                    observed.append((result[0], os.fstat(captured.fileno()).st_size, process.returncode))
                    return result
                process.communicate = measured
                return process
            with mock.patch.object(extraction.importlib.util, 'find_spec', return_value=parser), \
                 mock.patch.object(extraction.subprocess, 'Popen', side_effect=launch), \
                 self.assertRaisesRegex(a.Invalid, 'pdf-worker-invalid'):
                a.extract(b'%PDF-output-bound-probe', 'application/pdf')
        self.assertEqual(1, len(observed))
        self.assertIsNone(observed[0][0])
        self.assertEqual(3 * 1024 * 1024, observed[0][1])
        self.assertNotEqual(0, observed[0][2])


if __name__ == "__main__":
    unittest.main()
