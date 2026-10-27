#!/usr/bin/env python3
"""Bounded full-workflow batches; only this process's sealed executions are reusable."""

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import re
import stat
import subprocess
import sys
import time
import uuid

if sys.platform == 'linux':
    import fcntl
    import resource

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
GATE = HERE / 'check-workflow-state.sh'
AUDITED_GATE_SHA256 = 'b8944ffe8612e32b8d85db8c4c0aca2cc741acdc1b43124c001a0571c2e823aa'
TOOLS = ('bash', 'jq', 'awk', 'find', 'iconv', 'sha256sum', 'cat', 'dirname', 'basename',
         'head', 'sed', 'grep', 'tr', 'sort', 'mktemp', 'rm', 'rmdir', 'cmp', 'cut', 'wc', 'tail', 'uniq')
ENVIRONMENT = {'PATH': '/usr/bin', 'LC_ALL': 'C', 'LANG': 'C', 'TZ': 'UTC', 'HOME': '/nonexistent', 'TMPDIR': '/tmp'}
MAX_FILES, MAX_BYTES = 4096, 256 * 1024 * 1024


class Ineligible(ValueError):
    pass


def digest(value):
    return hashlib.sha256(value).hexdigest()


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('batch-request-duplicate-key')
        result[key] = value
    return result


def stamp(info):
    return (info.st_dev, info.st_ino, info.st_mode, info.st_nlink, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def stable_file(path, limit=MAX_BYTES):
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        before = os.fstat(descriptor)
        if not stat.S_ISREG(before.st_mode) or before.st_size > limit:
            raise Ineligible('unsupported-file-or-size')
        if any(name.startswith('system.posix_acl_') for name in os.listxattr(descriptor)):
            raise Ineligible('acl-unsupported')
        with os.fdopen(os.dup(descriptor), 'rb') as stream:
            data = stream.read(limit + 1)
        if len(data) > limit or stamp(before) != stamp(os.fstat(descriptor)):
            raise Ineligible('input-changed-during-read')
        return data, stamp(before)
    finally:
        os.close(descriptor)


class Snapshot:
    def __init__(self):
        self.files = {}
        self.directories = {}
        self.identities = {}
        self.total = 0
        self.descriptors = []

    def file(self, source, destination=None, *, trusted=False):
        source = Path(source).absolute()
        destination = Path(destination or source).absolute()
        if destination in self.files:
            return
        if len(self.files) >= MAX_FILES:
            raise Ineligible('snapshot-file-limit')
        data, identity = stable_file(source, MAX_BYTES - self.total)
        if trusted and (source.stat().st_uid != 0 or identity[2] & 0o022 or not data.startswith(b'\x7fELF')):
            raise Ineligible('runtime-not-system-elf')
        self.total += len(data)
        self.files[destination] = (stat.S_IMODE(identity[2]), data)
        self.identities[str(source)] = identity

    def tree(self, root):
        root = Path(root).absolute()
        def visit(directory):
            before = directory.lstat()
            if not stat.S_ISDIR(before.st_mode):
                raise Ineligible('linked-or-special-directory')
            if any(name.startswith('system.posix_acl_') for name in os.listxattr(directory, follow_symlinks=False)):
                raise Ineligible('acl-unsupported')
            self.directories[directory] = stat.S_IMODE(before.st_mode)
            names = sorted(directory.iterdir())
            for child in names:
                info = child.lstat()
                if stat.S_ISDIR(info.st_mode):
                    visit(child)
                elif stat.S_ISREG(info.st_mode):
                    self.file(child)
                else:
                    raise Ineligible('symlink-or-special-file')
            if stamp(before) != stamp(directory.stat()) or names != sorted(directory.iterdir()):
                raise Ineligible('directory-changed-during-read')
            self.identities[str(directory)] = stamp(before)
        visit(root)

    def runtime(self):
        if sys.platform != 'linux' or not hasattr(os, 'memfd_create'):
            raise Ineligible('sealed-runtime-unavailable')
        # Only fixed system tools are admitted. Caller PATH and loader variables are not executed.
        for name in TOOLS:
            alias = Path('/usr/bin') / name
            source = alias.resolve(strict=True)
            self.identities[str(alias) + ':link'] = (str(source), stamp(alias.lstat()))
            self.file(source, alias, trusted=True)
            result = subprocess.run(['/usr/bin/ldd', str(source)], env=ENVIRONMENT,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5)
            if result.returncode or b'not found' in result.stdout:
                raise Ineligible('runtime-dependency-unresolved')
            for value in re.findall(rb'(?:=>\s+)?(/[^\s()]+)', result.stdout):
                library = Path(os.fsdecode(value))
                self.file(library.resolve(strict=True), library, trusted=True)
        self.file(Path('/usr/bin/bwrap'), trusted=True)
        self.file(Path('/usr/bin/ldd'))
        # Capture the actual issuer implementation too; it is never loaded from a receipt.
        for path in (Path(__file__).resolve(), ROOT / 'plugins/sdd-bootstrap/scripts/project-skill.py',
                     ROOT / 'plugins/sdd-bootstrap/scripts/project-skill-process.py',
                     HERE / 'validate-project-skill.py'):
            self.file(path)

    def key(self, registry):
        value = {'files': [(str(path), mode, digest(data)) for path, (mode, data) in sorted(self.files.items())],
                 'directories': [(str(path), mode) for path, mode in sorted(self.directories.items())],
                 'identities': self.identities, 'registry': str(registry), 'gate': str(GATE),
                 'environment': ENVIRONMENT, 'caller_environment_sha256': digest(json.dumps(dict(os.environ), sort_keys=True).encode()),
                 'os': tuple(platform.uname()), 'python': (sys.executable, sys.version), 'cwd': os.getcwd()}
        return digest(json.dumps(value, sort_keys=True).encode())

    def seal(self):
        required = len(self.files) + 128
        soft, hard = resource.getrlimit(resource.RLIMIT_NOFILE)
        if soft < required:
            if hard < required:
                raise Ineligible('descriptor-limit')
            resource.setrlimit(resource.RLIMIT_NOFILE, (required, hard))
        for path, (mode, data) in sorted(self.files.items()):
            descriptor = os.memfd_create('workflow-input', os.MFD_CLOEXEC | os.MFD_ALLOW_SEALING)
            self.descriptors.append((path, mode, descriptor))
            with os.fdopen(os.dup(descriptor), 'wb') as stream:
                stream.write(data)
            os.lseek(descriptor, 0, os.SEEK_SET)
            # F_ADD_SEALS and WRITE|SHRINK|GROW|SEAL from the Linux UAPI.
            fcntl.fcntl(descriptor, 1033, 0x0f)

    def close(self):
        for _, _, descriptor in self.descriptors:
            os.close(descriptor)
        self.descriptors.clear()

    def command(self, registry, command=None):
        argv = ['/usr/bin/bwrap', '--unshare-all', '--die-with-parent', '--new-session', '--clearenv',
                '--cap-drop', 'ALL', '--tmpfs', '/', '--proc', '/proc', '--dev', '/dev',
                '--perms', '1777', '--tmpfs', '/tmp']
        for key, value in ENVIRONMENT.items():
            argv += ['--setenv', key, value]
        argv += ['--setenv', 'SDD_WORKFLOW_SNAPSHOT', '1']
        directories = set(self.directories)
        for path in self.files:
            directories.update(path.parents)
        for path in sorted(directories, key=lambda p: (len(p.parts), str(p))):
            if str(path) not in ('/', '/tmp', '/proc', '/dev'):
                argv += ['--perms', oct(self.directories.get(path, 0o755))[2:], '--dir', str(path)]
        for path, mode, descriptor in self.descriptors:
            argv += ['--perms', oct(mode)[2:], '--ro-bind-data', str(descriptor), str(path)]
        # Files are private readonly copies of sealed bytes; no host backing tree is mounted.
        argv += ['--remount-ro', '/', '--chdir', str(registry.parent.parent), '--']
        return argv + (command or ['/usr/bin/bash', str(GATE), '--registry', str(registry)])


def capture(registry):
    if sys.platform != 'linux':
        raise Ineligible('sealed-runtime-unavailable')
    if registry.resolve() != registry:
        raise Ineligible('noncanonical-registry-path')
    snapshot = Snapshot()
    snapshot.tree(registry.parent.parent)
    snapshot.file(GATE)
    # Audit the very bytes executed, including when tree() already admitted this file.
    if digest(snapshot.files[GATE][1]) != AUDITED_GATE_SHA256:
        raise Ineligible('gate-dependency-audit-required')
    snapshot.file(ROOT / 'contracts/workflow-state-registry.schema.json')
    snapshot.runtime()
    return snapshot


def runner():
    spec = importlib.util.spec_from_file_location('workflow_project_runner', ROOT / 'plugins/sdd-bootstrap/scripts/project-skill.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.execute


def execute_snapshot(snapshot, registry, execute, timeout):
    try:
        snapshot.seal()
        descriptors = [descriptor for _, _, descriptor in snapshot.descriptors]
        # UTF-8 validation and process substitution exercise required runtime/data boundaries.
        probe = "printf '\\303\\251' | iconv -f UTF-8 -t UTF-8 >/dev/null && ! printf '\\377' | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 && cmp <(printf ok) <(printf ok)"
        check = execute(snapshot.command(registry, ['/usr/bin/bash', '-c', probe]), '/', 10, 4096, input_fds=descriptors)
        if check[0] != 0 or check[3] or not check[4]:
            raise Ineligible('sealed-runtime-probe-failed')
        for descriptor in descriptors:
            os.lseek(descriptor, 0, os.SEEK_SET)
        return execute(snapshot.command(registry), '/', timeout, 1024 * 1024, input_fds=descriptors)
    finally:
        snapshot.close()


def batch(registry, requests, timeout=120):
    execute = runner()
    results, retained = [], None
    for request in requests:
        before = time.monotonic()
        snapshot = capture(registry)
        key = snapshot.key(registry)
        if retained is not None and retained['snapshot_sha256'] == key:
            result = dict(retained, request=request, executed=False, reuse_reason='same-process-identical-sealed-inputs')
        else:
            started_at = datetime.now(timezone.utc).isoformat()
            code, stdout, stderr, reason, cleanup = execute_snapshot(snapshot, registry, execute, timeout)
            finished_at = datetime.now(timezone.utc).isoformat()
            if code == 75:
                raise Ineligible('external-or-historical-dependency')
            if reason or not cleanup:
                raise Ineligible(reason or 'process-cleanup-unverified')
            result = dict(request=request, run_id=uuid.uuid4().hex, executed=True, reuse_reason=None,
                          snapshot_sha256=key, exit_code=code,
                          started_at=started_at, finished_at=finished_at, cleanup=cleanup,
                          stdout=base64.b64encode(stdout).decode(), stderr=base64.b64encode(stderr).decode(),
                          stdout_sha256=digest(stdout), stderr_sha256=digest(stderr))
            if code == 0:
                retained = result
        after = capture(registry)
        if after.key(registry) != key:
            raise Ineligible('input-changed-during-execution')
        result = dict(result, request_seconds=time.monotonic() - before)
        results.append(result)
    final_key = capture(registry).key(registry)
    if any(result['snapshot_sha256'] != final_key for result in results):
        raise Ineligible('batch-inputs-changed')
    return dict(schema='workflow-state-batch-result/v1', scope='repository', results=results,
                snapshot_sha256=final_key, complete=all(result['exit_code'] == 0 for result in results),
                authority='full-workflow-check-only; other required gates and approvals remain independent')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--requests', required=True, type=Path)
    parser.add_argument('--registry', required=True, type=Path)
    parser.add_argument('--timeout', type=int, default=120)
    args = parser.parse_args(argv)
    try:
        if sys.platform != 'linux':
            raise Ineligible('sealed-runtime-unavailable')
        data, _ = stable_file(args.requests, 64 * 1024)
        request = json.loads(data, object_pairs_hook=unique_object)
        if (not isinstance(request, dict) or set(request) != {'schema', 'requests'}
                or request['schema'] != 'workflow-state-batch/v1' or not isinstance(request['requests'], list)
                or not 1 <= len(request['requests']) <= 50
                or any(not isinstance(item, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}', item) for item in request['requests'])
                or len(set(request['requests'])) != len(request['requests']) or not 1 <= args.timeout <= 3600):
            raise ValueError('batch-request-invalid')
        registry = args.registry.absolute()
        if registry.name != 'workflow-state-registry.json' or registry.parent.name != 'specs':
            raise Ineligible('noncanonical-registry')
        result = batch(registry, request['requests'], args.timeout)
        print(json.dumps(result, sort_keys=True))
        return 0 if result['complete'] else 1
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        # No earlier request is published as PASS when final binding is unknown.
        print(json.dumps(dict(schema='workflow-state-batch-result/v1', complete=False,
                              status='cold-required', reason=str(error), results=[])))
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
