"""Deterministic extraction shared by acquisition and original verification."""

from html.parser import HTMLParser
import base64
import hashlib
import importlib.util
import io
import json
import logging
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import sysconfig
import tempfile
from research_evidence import Invalid, require

MAX_EXTRACTED = 2 * 1024 * 1024
MAX_PDF = 32 * 1024 * 1024


def supervise(command, payload, timeout, *, prefix, output_limit, env=None):
    """Reuse the existing Linux subreaper; bounded output and owned descendants."""
    here = Path(__file__).resolve().parent
    candidates = (here / 'project-skill-process.py',
                  here.parents[1] / 'sdd-bootstrap/scripts/project-skill-process.py')
    controller = next((path for path in candidates if path.is_file() and not path.is_symlink()), None)
    require(sys.platform == 'linux' and controller is not None, prefix + '-supervisor-unavailable')
    read_fd, write_fd = os.pipe()
    try:
        with tempfile.TemporaryDirectory(prefix='research-process-') as directory, tempfile.TemporaryFile() as captured:
            environment = dict(os.environ if env is None else env)
            environment['TMPDIR'] = directory
            invocation = [sys.executable, '-I', '-B', str(controller), '--status-fd', str(write_fd),
                          '--timeout', str(timeout), '--inherit-stdin', '--output-limit-bytes', str(output_limit),
                          '--', *command]
            try:
                process = subprocess.Popen(invocation, stdin=subprocess.PIPE, stdout=captured,
                                           stderr=subprocess.DEVNULL, env=environment, pass_fds=(write_fd,))
            except OSError:
                raise Invalid(prefix + '-supervisor-unavailable') from None
            os.close(write_fd)
            write_fd = -1
            try:
                process.communicate(payload, timeout=timeout + 6)
            except BaseException as error:
                process.terminate()
                try:
                    process.communicate(timeout=6)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
                    raise Invalid(prefix + '-cleanup-failed') from None
                if isinstance(error, subprocess.TimeoutExpired):
                    raise Invalid(prefix + '-cleanup-failed') from None
                raise
            finally:
                if process.stdin is not None:
                    process.stdin.close()
            try:
                status = json.loads(os.read(read_fd, 4096))
                require(isinstance(status, dict) and set(status) == {'cleanup', 'reason', 'exit_code'}
                        and status['cleanup'] is True and type(status['exit_code']) is int
                        and process.returncode == (status['exit_code'] & 255), prefix + '-cleanup-failed')
                require(status['reason'] is None, prefix + ('-timeout' if status['reason'] == 'timeout' else '-cancelled'))
            except (ValueError, TypeError, KeyError) as error:
                if isinstance(error, Invalid):
                    raise
                raise Invalid(prefix + '-cleanup-failed') from None
            captured.seek(0)
            output = captured.read(output_limit + 1)
            require(len(output) <= output_limit, prefix + '-output-too-large')
            return status['exit_code'], output
    finally:
        os.close(read_fd)
        if write_fd >= 0:
            os.close(write_fd)


def _pdf_worker(package_digest):
    """Private entry inside the isolated runtime; no fetches or cache writes."""
    import resource

    def limit(kind, maximum):
        bound = min([maximum] + [value for value in resource.getrlimit(kind) if value >= 0])
        resource.setrlimit(kind, (bound, bound))

    limit(resource.RLIMIT_CPU, 5)
    limit(resource.RLIMIT_AS, 384 * 1024 * 1024)
    limit(resource.RLIMIT_FSIZE, 3 * 1024 * 1024)
    limit(resource.RLIMIT_NPROC, 1)
    limit(resource.RLIMIT_CORE, 0)
    limit(resource.RLIMIT_NOFILE, 32)
    logging.disable(logging.CRITICAL)
    try:
        import pypdf

        require(re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', pypdf.__version__) is not None,
                'pdf-parser-version-unsupported')
        body = sys.stdin.buffer.read(MAX_PDF + 1)
        require(0 < len(body) <= MAX_PDF, 'pdf-too-large')
        reader = pypdf.PdfReader(io.BytesIO(body), strict=True)
        require(not reader.is_encrypted, 'pdf-encrypted')
        require(0 < len(reader.pages) <= 500, 'pdf-page-limit')
        pages, size = [], 0
        for page in reader.pages:
            text = page.extract_text(extraction_mode='layout') if page.get_contents() is not None else ''
            raw = text.encode('utf-8')
            size += len(raw) + 1
            require(size <= MAX_EXTRACTED, 'extraction-too-large')
            pages.append(raw)
        extracted = b'\n'.join(pages)
        require(bool(extracted.strip()), 'pdf-text-unavailable')
        method = 'pypdf-' + pypdf.__version__.replace('.', '-') + '-' + package_digest + '-layout/v1'
        print(json.dumps(dict(text=base64.b64encode(extracted).decode('ascii'), method=method)))
        return 0
    except ImportError:
        error = 'pdf-extractor-unavailable'
    except Invalid as exc:
        error = exc.code
    except MemoryError:
        error = 'pdf-resource-limit'
    except Exception:
        error = 'pdf-invalid'
    print(json.dumps(dict(error=error)))
    return 1


def _extract_pdf(body):
    require(len(body) <= MAX_PDF, 'pdf-too-large')
    require(sys.platform == 'linux', 'pdf-sandbox-unavailable')
    sandbox = shutil.which('bwrap')
    require(sandbox is not None, 'pdf-sandbox-unavailable')
    parser = importlib.util.find_spec('pypdf')
    require(parser is not None and parser.origin is not None, 'pdf-extractor-unavailable')
    package = Path(parser.origin).resolve().parent
    executable = Path(sys.executable).resolve()
    stdlib = Path(sysconfig.get_path('stdlib')).resolve()
    here = Path(__file__).resolve().parent
    with tempfile.TemporaryDirectory(prefix='research-pdf-') as directory:
        # Only source files enter the private package: never imported bytecode,
        # package symlinks, repository data or ambient site customizations.
        copied = Path(directory) / 'pypdf'
        copied.mkdir()
        fingerprint, size = hashlib.sha256(), 0
        for path in sorted(package.rglob('*')):
            if '__pycache__' in path.parts:
                continue
            require(not path.is_symlink(), 'pdf-parser-path-invalid')
            if not path.is_file() or path.suffix != '.py':
                continue
            raw = path.read_bytes()
            size += len(raw)
            require(size <= 16 * 1024 * 1024, 'pdf-parser-too-large')
            relative = path.relative_to(package)
            fingerprint.update(relative.as_posix().encode() + b'\0' + raw + b'\0')
            target = copied / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(raw)
            target.chmod(0o444)
        for path in copied.rglob('*'):
            if path.is_dir():
                path.chmod(0o555)
        copied.chmod(0o555)
        package_digest = fingerprint.hexdigest()
        command = [str(Path(sandbox).resolve()), '--unshare-all', '--die-with-parent', '--new-session',
                   '--clearenv', '--setenv', 'LANG', 'C.UTF-8', '--dev', '/dev', '--tmpfs', '/tmp',
                   '--uid', str(os.getuid() or 65534), '--gid', str(os.getgid() or 65534), '--cap-drop', 'ALL']
        for library in ('/lib', '/lib64', '/usr/lib'):
            if Path(library).is_dir():
                command += ['--ro-bind', str(Path(library).resolve()), library]
        command += ['--ro-bind', str(executable), str(executable),
                    '--ro-bind', str(stdlib), str(stdlib)]
        libdir = Path(sysconfig.get_config_var('LIBDIR') or str(stdlib.parent))
        shared = sysconfig.get_config_var('LDLIBRARY') or ''
        if shared and '.so' in shared and (libdir / shared).is_file():
            resolved = (libdir / shared).resolve()
            command += ['--ro-bind', str(resolved), str(resolved),
                        '--ro-bind', str(resolved), str(libdir / shared)]
        command += ['--tmpfs', str(stdlib / 'site-packages'),
                    '--ro-bind', str(copied), str(stdlib / 'site-packages/pypdf')]
        for name in ('research_extraction.py', 'research_evidence.py'):
            command += ['--ro-bind', str(here / name), '/worker/' + name]
        command += ['--remount-ro', str(stdlib / 'site-packages'), '--remount-ro', '/tmp',
                    '--remount-ro', '/dev', '--remount-ro', '/',
                    '--chdir', '/tmp', str(executable), '-I', '-B', '-c',
                    "import sys; sys.path.insert(0,'/worker'); from research_extraction import _pdf_worker; "
                    "raise SystemExit(_pdf_worker(sys.argv[1]))", package_digest]
        code, output = supervise(command, body, 10, prefix='pdf', output_limit=3 * 1024 * 1024, env={})
        try:
            require(bool(output), 'pdf-sandbox-unavailable')
            require(len(output) <= 3 * 1024 * 1024, 'extraction-too-large')
            result = json.loads(output)
            if isinstance(result, dict) and set(result) == {'error'}:
                require(isinstance(result['error'], str) and
                        re.fullmatch(r'[a-z][a-z0-9-]{0,63}', result['error']), 'pdf-worker-invalid')
                raise Invalid(result['error'])
            require(code == 0 and isinstance(result, dict)
                    and set(result) == {'text', 'method'}, 'pdf-worker-invalid')
            require(isinstance(result['method'], str) and re.fullmatch(
                r'pypdf-[0-9]+-[0-9]+-[0-9]+-' + package_digest + r'-layout/v1', result['method']),
                'pdf-worker-invalid')
            raw = base64.b64decode(result['text'], validate=True)
            require(len(raw) <= MAX_EXTRACTED and raw.decode('utf-8').strip(), 'pdf-worker-invalid')
            return raw, result['method']
        except Invalid:
            raise
        except (ValueError, TypeError, UnicodeError, KeyError):
            raise Invalid('pdf-worker-invalid') from None


class TextHTML(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.skip = 0
        self.parts = []
        self.login = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ("script", "style", "noscript"):
            self.skip += 1
        if tag == "input" and attrs.get("type", "").lower() == "password":
            self.login = True
        if tag in ("p", "div", "br", "h1", "h2", "h3", "li"):
            self.parts.append("\n")

    def handle_endtag(self, tag):
        if tag in ("script", "style", "noscript") and self.skip:
            self.skip -= 1

    def handle_data(self, data):
        if not self.skip:
            self.parts.append(data)


def extract(body, content_type):
    require(bool(body), "empty-response")
    media = content_type.split(";", 1)[0].strip().lower()
    if media == "application/pdf" or body.startswith(b"%PDF"):
        require(
            media == "application/pdf" and body.startswith(b"%PDF-"), "media-mismatch"
        )
        extracted, method = _extract_pdf(body)
        return extracted, method, content_type
    require(
        media
        in (
            "text/plain",
            "text/html",
            "application/xhtml+xml",
            "application/xml",
            "text/xml",
            "application/rss+xml",
            "application/atom+xml",
        ),
        "media-unsupported",
    )
    charset = "utf-8"
    for item in content_type.split(";")[1:]:
        if item.strip().lower().startswith("charset="):
            charset = item.split("=", 1)[1].strip(' "').lower()
    require(
        charset
        in (
            "utf-8",
            "utf8",
            "us-ascii",
            "iso-8859-1",
            "windows-1252",
            "shift_jis",
            "cp932",
        ),
        "encoding-unsupported",
    )
    try:
        text = body.decode("utf-8-sig" if charset in ("utf-8", "utf8") else charset)
    except (UnicodeError, LookupError):
        raise Invalid("encoding-invalid") from None
    if media in ("text/html", "application/xhtml+xml"):
        parser = TextHTML()
        parser.feed(text)
        require(
            not parser.login
            and not any(
                term in text.lower()
                for term in (
                    "cf-chl-",
                    "verify you are human",
                    "checking your browser",
                    "captcha",
                )
            ),
            "access-wall",
        )
        text = "".join(parser.parts)
        method = "html-text/v1"
    else:
        require(
            not text.lstrip().lower().startswith(("<!doctype html", "<html")),
            "media-mismatch",
        )
        method = "plain/v1"
    raw = text.encode("utf-8")
    require(len(raw) <= MAX_EXTRACTED, "extraction-too-large")
    return raw, method, content_type
