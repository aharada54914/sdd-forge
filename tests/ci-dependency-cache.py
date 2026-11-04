#!/usr/bin/env python3
"""Pinned CI dependency cache and Pester module install; dependency bytes are never executed."""
import argparse
import contextlib
import hashlib
import http.client
import io
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile
import urllib.request
import zipfile
import zlib

PESTER_VERSION = '4.10.1'
PESTER_URL = 'https://www.powershellgallery.com/api/v2/package/Pester/4.10.1'
PESTER_SHA256 = '898210e1a30c52cd46ba317c2278a9324345214213aa2f7d6b7dfa7b98f37ac9'
PESTER_MANIFEST_SHA256 = '05bf87f45bf2b6604073a6851d0803917adfa87c134b9dd5867ba93b2e872663'
DOWNLOAD_TIMEOUT_SECONDS = 60


def sha256_hex(raw):
    return hashlib.sha256(raw).hexdigest()


def refuse_links(path):
    for component in (path, *path.parents):
        if component.is_symlink() or getattr(component, 'is_junction', lambda: False)():
            raise ValueError(f'refusing symlink or junction in dependency path: {component}')


def publish(path, raw):
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(dir=path.parent, prefix=f'.{path.name}.', suffix='.partial')
    try:
        with os.fdopen(descriptor, 'wb') as handle:
            handle.write(raw)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(temporary)


def acquire(path, url, sha256, attempts=3):
    """Return path holding bytes with the pinned digest, rehashing every cache hit."""
    path = Path(path).absolute()
    refuse_links(path)
    if path.exists():
        if not path.is_file():
            raise ValueError(f'dependency cache entry is not a regular file: {path}')
        if sha256_hex(path.read_bytes()) == sha256:
            return path
        path.unlink()
    for attempt in range(1, attempts + 1):
        try:
            with urllib.request.urlopen(url, timeout=DOWNLOAD_TIMEOUT_SECONDS) as response:
                raw = response.read()
        except (OSError, http.client.HTTPException) as error:
            print(f'dependency acquisition attempt {attempt}/{attempts} failed: {type(error).__name__}: {error}', file=sys.stderr)
            continue
        if sha256_hex(raw) != sha256:
            print(f'dependency acquisition attempt {attempt}/{attempts} failed: SHA-256 mismatch', file=sys.stderr)
            continue
        publish(path, raw)
        return path
    raise ValueError(f'dependency acquisition failed after {attempts} attempts: {url}')


def member_parts(info):
    name = info.filename[:-1] if info.is_dir() else info.filename
    parts = tuple(name.split('/'))
    kind = stat.S_IFMT(info.external_attr >> 16)
    if ('\\' in name or ':' in name or any(part in ('', '.', '..') for part in parts)
            or kind not in (0, stat.S_IFREG, stat.S_IFDIR)):
        raise ValueError(f'unsafe Pester package member: {info.filename!r}')
    return parts


def read_package(raw):
    """Validate every member before returning file bytes and explicit directories; nothing is written."""
    try:
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            members = [(member_parts(info), info) for info in archive.infolist()]
            keys = [tuple(part.casefold() for part in parts) for parts, _ in members]
            file_keys = {key for key, (_, info) in zip(keys, members) if not info.is_dir()}
            parent_keys = {key[:index] for key in keys for index in range(1, len(key))}
            if len(set(keys)) != len(keys) or file_keys & parent_keys:
                raise ValueError('Pester package has duplicate or colliding member paths')
            files = {parts: archive.read(info) for parts, info in members if not info.is_dir()}
    except (zipfile.BadZipFile, zlib.error, EOFError) as error:
        raise ValueError(f'Pester package is not a valid ZIP archive: {error}') from error
    return files, [parts for parts, info in members if info.is_dir()]


def extract(staging, files, directories):
    for parts in directories:
        staging.joinpath(*parts).mkdir(parents=True, exist_ok=True)
    for parts, data in files.items():
        target = staging.joinpath(*parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        with open(target, 'xb') as handle:
            handle.write(data)
    written = {path.relative_to(staging).parts: path.read_bytes() for path in staging.rglob('*') if not path.is_dir()}
    if written != files:
        raise ValueError('extracted Pester files differ from the validated package')


def install_pester(cache_dir, module_root):
    """Install a fresh validated Pester tree and return module_root/Pester/<version>."""
    version_dir = Path(module_root).absolute() / 'Pester' / PESTER_VERSION
    refuse_links(version_dir)
    archive = acquire(Path(cache_dir).absolute() / f'Pester.{PESTER_VERSION}.nupkg', PESTER_URL, PESTER_SHA256)
    raw = archive.read_bytes()
    if sha256_hex(raw) != PESTER_SHA256:
        raise ValueError('cached Pester package changed after validation')
    files, directories = read_package(raw)
    if sha256_hex(files.get(('Pester.psd1',), b'')) != PESTER_MANIFEST_SHA256:
        raise ValueError('Pester package root manifest does not match the pinned digest')
    version_dir.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(dir=version_dir.parent, prefix='.staging-'))
    try:
        extract(staging, files, directories)
        if version_dir.exists():
            shutil.rmtree(version_dir)  # rmtree unlinks planted links instead of following them
        os.replace(staging, version_dir)
    finally:
        if staging.exists():
            shutil.rmtree(staging)
    if sha256_hex((version_dir / 'Pester.psd1').read_bytes()) != PESTER_MANIFEST_SHA256:
        raise ValueError('installed Pester manifest does not match the pinned digest')
    return version_dir


def main(argv=None):
    parser = argparse.ArgumentParser(description='Acquire pinned CI dependencies without executing them.')
    commands = parser.add_subparsers(dest='command', required=True)
    pester = commands.add_parser('pester', help='install the pinned Pester module from the dependency cache')
    pester.add_argument('--cache-dir', type=Path, required=True)
    pester.add_argument('--module-root', type=Path, required=True)
    arguments = parser.parse_args(argv)
    try:
        print(install_pester(arguments.cache_dir, arguments.module_root))
    except (OSError, ValueError) as error:
        print(f'ci-dependency-cache: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
