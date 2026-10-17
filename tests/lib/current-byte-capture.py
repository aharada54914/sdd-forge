#!/usr/bin/env python3
"""Execute current working-tree payload in the actual absent-Context fixture.

Historical captures remain immutable. Only machine contracts use their golden
bytes; data-copy contracts use independent indexed source bytes and the public
FilesOnly layout. There is intentionally no capture cache.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile

# Same bounded source fixture as installer acceptance tests: documentation
# archives are not product payload. Project AGENTS is supplied by F1/F2, not by
# the development repository. Root sdd/ is project-owned metadata as well.
# Exclude fixture symlinks on native Windows too.
SOURCE_EXCLUDED = ('specs/', 'reports/', 'tests/fixtures/', 'sdd/')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def manifest(files):
    return ''.join(f'{sha(data)}  {name}\n' for name, data in
                   sorted(files.items(), key=lambda row: tuple(row[0].split('/')))).encode()


def actual_manifest(root):
    return manifest({p.relative_to(root).as_posix(): p.read_bytes()
                     for p in root.rglob('*') if p.is_file()}) if root.exists() else b''


def remove_tree(path):
    # Git can create read-only object files on Windows. Retry only that error;
    # cleanup failures must not silently leave a reusable capture fixture.
    def retry_readonly(operation, target, error):
        if not isinstance(error[1], PermissionError):
            raise error[1]
        os.chmod(target, 0o700)
        operation(target)
    shutil.rmtree(path, onerror=retry_readonly)


def indexed_source(root):
    result = subprocess.run(['git', '-C', str(root), 'ls-files', '-z'],
                            capture_output=True, check=True)
    files = {}
    for name in result.stdout.decode('utf-8').split('\0'):
        if not name or name == 'AGENTS.md' or name.startswith(SOURCE_EXCLUDED):
            continue
        path = root / name
        if path.is_symlink():
            raise ValueError(f'unsupported product source symlink: {name}')
        files[name] = path.read_bytes()
    return files


def capture(product, fixture, destination, canonical, runtime):
    product, fixture = product.resolve(), fixture.resolve()
    if product == fixture or product in fixture.parents or fixture in product.parents:
        raise ValueError('fixture must be isolated from product source')
    if (fixture / 'sdd/project-context.yaml').exists():
        raise ValueError('F1/F2 must have no Project Context')
    marker = (fixture / 'AGENTS.md').read_bytes() if (fixture / 'AGENTS.md').exists() else None
    if set(p.name for p in fixture.iterdir()) - {'AGENTS.md'}:
        raise ValueError('expected fresh F1/F2 fixture')
    source = indexed_source(product)  # independent expected bytes BEFORE execution
    targets = json.loads((canonical / 'manifest.json').read_text(encoding='utf-8'))['targets']
    if len(targets) != 9 or len({row['name'] for row in targets}) != 9:
        raise ValueError('expected all nine canonical categories')
    destination.mkdir(parents=True)
    expected = destination / 'expected'
    expected.mkdir()
    for row in targets:
        raw = (canonical / row['path']).read_bytes()
        if sha(raw) != row['sha256']:
            raise ValueError('historical canonical bytes differ from manifest')
        path = expected / row['path']
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(raw)

    with tempfile.TemporaryDirectory(prefix='sdd-current-capture-') as temporary:
        workspace = Path(temporary)
        home = workspace / 'home'
        home.mkdir()
        env = {k: v for k, v in os.environ.items() if not k.upper().startswith('SDD_')}
        env.update(TZ='UTC', LC_ALL='C', HOME=str(home), USERPROFILE=str(home),
                   PYTHONDONTWRITEBYTECODE='1')

        def run(command):
            return subprocess.run(command, cwd=fixture, env=env, capture_output=True)

        def success(command, description):
            result = run(command)
            if result.returncode:
                raise ValueError(f'{description} failed: {result.stderr.decode("utf-8", "replace")}')
            return result

        def write(name, data, expectation=None):
            row = next(row for row in targets if row['name'] == name)
            path = destination / row['path']
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            if expectation is not None:
                (expected / row['path']).write_bytes(expectation)

        try:
            for name, data in source.items():
                path = fixture / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
                path.chmod((product / name).stat().st_mode & 0o777)
            for command in (['git', 'init', '-q'], ['git', 'config', 'core.autocrlf', 'false'],
                            ['git', 'config', 'core.hooksPath', str(workspace / 'no-hooks')]):
                success(command, 'fixture initialization')
            # Stage the declared source only, preserving the untracked F2 marker.
            # Git's stdin pathspec avoids shell parsing and platform command limits.
            staged = subprocess.run(['git', 'add', '-f', '--pathspec-from-file=-', '--pathspec-file-nul'],
                                    input=('\0'.join(source) + '\0').encode(), cwd=fixture,
                                    env=env, capture_output=True)
            if staged.returncode:
                raise ValueError('cannot index source fixture')
            generated = run([sys.executable, str(fixture / 'plugins/sdd-quality-loop/scripts/generate-guard-invariants.py'), '--check'])
            raw = struct.pack('>Q', len(generated.stdout)) + generated.stdout + struct.pack('>Q', len(generated.stderr)) + generated.stderr
            write('deterministic-script-output', raw)
            write('stdout-stderr', raw)
            write('exit-code', f'{generated.returncode}\n'.encode())

            templates = {name: data for name, data in source.items()
                         if name.startswith('plugins/') and '/templates/' in name}
            copied = workspace / 'templates'
            for directory in sorted(fixture.glob('plugins/**/templates')):
                shutil.copytree(directory, copied / directory.relative_to(fixture))
            write('template-copy-result', actual_manifest(copied), manifest(templates))

            contract = {'schema': 'domain-contract/v2',
                        'meta': {'version': '1.0.0', 'status': 'Pending', 'generated_from': ['domain/context-map.md']},
                        'contexts': [{'name': 'catalog', 'description': 'Catalog', 'terms': [], 'aggregates': []}],
                        'concepts': [{'id': 'CONCEPT-BOOK', 'name': 'Book', 'context': 'catalog',
                                      'definition': 'A publication', 'essence': 'Published content',
                                      'responsibilities': ['Identify publication'], 'evidence': ['domain/context-map.md']}]}
            valid, invalid = workspace / 'valid.json', workspace / 'invalid.json'
            valid.write_text(json.dumps(contract), encoding='utf-8')
            invalid.write_text('{}', encoding='utf-8')
            shell = shutil.which('pwsh') or shutil.which('powershell')
            if runtime == 'powershell' and not shell:
                raise ValueError('PowerShell is required for native twin capture')
            validator = fixture / 'plugins/sdd-domain/scripts/validate-domain-contract'
            command = ([shell, '-NoProfile', '-File', str(validator.with_suffix('.ps1'))]
                       if runtime == 'powershell' else ['bash', str(validator.with_suffix('.sh'))])
            accepted, rejected = run(command + [str(valid)]), run(command + [str(invalid)])
            if rejected.returncode != 1 or not rejected.stderr:
                raise ValueError('current schema validator did not reject invalid contract')
            write('schema-validator-result', f'{accepted.returncode}\n'.encode())

            install_root = workspace / 'install-root'
            if runtime == 'powershell':
                install = [shell, '-NoProfile', '-File', str(fixture / 'install.ps1'), '-SourceDirectory', str(fixture), '-InstallRoot', str(install_root), '-Target', 'FilesOnly', '-SkipAgentInstall', '-SkipMcp']
                uninstall = [shell, '-NoProfile', '-File', str(fixture / 'uninstall.ps1'), '-InstallRoot', str(install_root), '-Target', 'FilesOnly', '-SkipAgentUninstall', '-SkipMcpUninstall']
            else:
                install = ['bash', str(fixture / 'install.sh'), '--source-directory', str(fixture), '--install-root', str(install_root), '--target', 'FilesOnly', '--skip-agent-install', '--skip-mcp']
                uninstall = ['bash', str(fixture / 'uninstall.sh'), '--install-root', str(install_root), '--target', 'FilesOnly', '--skip-agent-uninstall', '--skip-mcp-uninstall']
            success(install, 'current install')
            # FilesOnly public layout: indexed release files at install root,
            # with MCP payload excluded by SkipMcp. Never read installer output
            # or invoke installer logic to construct this expected manifest.
            payload = {name: data for name, data in source.items() if not name.startswith('mcp/')}
            write('install-result', actual_manifest(install_root), manifest(payload))
            success(uninstall, 'current uninstall')
            write('uninstall-result', actual_manifest(install_root))
            directory = fixture / 'plugins/sdd-quality-loop/scripts/generated'
            listing = ''.join(p.relative_to(directory).as_posix() + ('/' if p.is_dir() else '') + '\n'
                              for p in sorted(directory.rglob('*'), key=lambda p: p.relative_to(directory).parts))
            prefix = 'plugins/sdd-quality-loop/scripts/generated/'
            generated_names = {name[len(prefix):] for name in source if name.startswith(prefix)}
            historical_names = set((canonical / 'targets/generated-directory-listing.txt').read_text().splitlines())
            if not historical_names.issubset(generated_names):
                raise ValueError('current source omits a required historical generated artifact')
            expected_listing = ''.join(name + '\n' for name in sorted(generated_names, key=lambda name: tuple(name.split('/'))))
            write('generated-directory-listing', listing.encode(), expected_listing.encode())
            manifests = {name: data for name, data in source.items()
                         if len(Path(name).parts) == 4 and name.startswith('plugins/')
                         and Path(name).parts[2].endswith('-plugin') and name.endswith('/plugin.json')}
            copied = workspace / 'manifests'
            for source_manifest in sorted(fixture.glob('plugins/*/*-plugin/plugin.json')):
                target = copied / source_manifest.relative_to(fixture)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source_manifest, target)
            write('plugin-manifest', actual_manifest(copied), manifest(manifests))
            if (fixture / 'sdd/project-context.yaml').exists() or ((fixture / 'AGENTS.md').read_bytes() if (fixture / 'AGENTS.md').exists() else None) != marker:
                raise ValueError('current execution changed absent-Context fixture inputs')
        finally:
            for path in fixture.iterdir():
                if path.name != 'AGENTS.md':
                    if path.is_dir() and not path.is_symlink():
                        remove_tree(path)
                    else:
                        path.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('product', 'fixture', 'destination', 'canonical'):
        parser.add_argument('--' + name, required=True, type=Path)
    parser.add_argument('--runtime', choices=('bash', 'powershell'), required=True)
    args = parser.parse_args()
    try:
        capture(**vars(args))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f'current byte capture: {error}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
