"""Final exact-commit Windows audit; diagnostic-branch artifact only, never product source."""
import argparse, hashlib, importlib.util, json, os, re, shutil, subprocess, tempfile, zipfile
from pathlib import Path

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

def digest(raw):
    return hashlib.sha256(raw).hexdigest()

p = argparse.ArgumentParser()
p.add_argument('--source', type=Path, required=True)
p.add_argument('--commit', required=True)
p.add_argument('--tag', required=True)
p.add_argument('--shell', choices=('pwsh', 'powershell'), required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
assert os.name == 'nt' and re.fullmatch('[0-9a-f]{40}', a.commit)
source, output = a.source.resolve(), a.output.resolve()
output.mkdir(parents=True, exist_ok=True)
def git(*args):
    return subprocess.check_output(['git', '-C', str(source), *args], text=True).strip()
assert git('rev-parse', 'HEAD') == a.commit
assert git('rev-parse', 'refs/tags/' + a.tag + '^{commit}') == a.commit
assert git('cat-file', '-t', 'refs/tags/' + a.tag) == 'tag', 'Annotated release tag required'
assert not git('status', '--porcelain', '--untracked-files=no')
node = subprocess.check_output(['node', '--version'], text=True).strip()
assert tuple(map(int, node.lstrip('v').split('.'))) >= (22, 19, 0)
os.environ['PWSH'] = shutil.which(a.shell) or a.shell
helper = load('payload', source / 'tests/lib/install-payload-check.py')
oracle = load('capture', source / 'tests/lib/current-byte-capture.py')
runner = helper.PowerShell()
assert not runner.unavailable()
records = {}
with tempfile.TemporaryDirectory(prefix='final-windows-payload-') as folder:
    scratch = Path(folder)
    archive = scratch / 'committed-source.zip'
    subprocess.run(['git', '-C', str(source), 'archive', '--format=zip', '--prefix=release-source/',
                    '--output', str(archive), a.commit], check=True)
    with zipfile.ZipFile(archive) as z:
        entries = {x.filename[len('release-source/'):]: x for x in z.infolist()
                   if x.filename.startswith('release-source/') and not x.is_dir()}
        assert any(x.startswith('specs/') for x in entries)
        assert any(x.startswith('reports/') for x in entries)
        assert any(x.startswith('tests/') for x in entries)
        # Select from immutable source declaration, not installer functions or output.
        names = {name: b'' for name in entries}
        names['install-payload.txt'] = z.read(entries['install-payload.txt'])
        selected = set(oracle.install_payload(names))
        mcp = {f'mcp/{server}/{leaf}' for server in ('sdd-forge-mcp','local-env-mcp','ci-mcp')
               for leaf in ('dist/index.js','package.json')}
        selected.update(mcp)
        expected = {name: {'bytes': entries[name].file_size, 'sha256': digest(z.read(entries[name]))}
                    for name in sorted(selected)}
        assert all(((entries[name].external_attr >> 16) & 0xF000) != 0xA000 for name in selected)
        archive_inputs = {'files': len(entries), 'symlink_entries': sum(
            ((x.external_attr >> 16) & 0xF000) == 0xA000 for x in entries.values()),
            'sha256': digest(archive.read_bytes())}
    (output / 'expected-inventory.json').write_text(json.dumps(expected, indent=2) + '\n')
    for mode in ('git', 'zip'):
        case = scratch / mode
        case.mkdir()
        target = case / 'installed'
        result = runner.install(case, target, **({'source': source} if mode == 'git' else {'archive': archive}))
        (output / (mode + '.log')).write_text(result.stdout + result.stderr, encoding='utf-8')
        assert result.returncode == 0, (mode, result.returncode)
        actual = {x.relative_to(target).as_posix(): {'bytes': x.stat().st_size, 'sha256': digest(x.read_bytes())}
                  for x in target.rglob('*') if x.is_file()}
        (output / (mode + '-inventory.json')).write_text(json.dumps(actual, indent=2) + '\n')
        assert actual == expected, (mode, 'source-byte/allowlist mismatch')
        records[mode] = {'exit': result.returncode, 'files': len(actual),
                         'bytes': sum(x['bytes'] for x in actual.values()), 'matches_independent_source': True}
summary = {'commit': a.commit, 'tag': a.tag, 'shell': a.shell, 'node': node,
           'archive_input': archive_inputs, 'scenarios': records,
           'transport': 'Real committed Git ZIP; authenticated Invoke-WebRequest boundary stubbed locally; no network or real token',
           'helper_sha256': digest((source / 'tests/lib/install-payload-check.py').read_bytes()),
           'oracle_sha256': digest((source / 'tests/lib/current-byte-capture.py').read_bytes()),
           'audit_script_sha256': digest(Path(__file__).read_bytes())}
(output / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n')
files = [{'path': x.name, 'bytes': x.stat().st_size, 'sha256': digest(x.read_bytes())}
         for x in sorted(output.iterdir()) if x.is_file() and x.name != 'evidence-manifest.json']
(output / 'evidence-manifest.json').write_text(json.dumps({'files': files}, indent=2) + '\n')
print(json.dumps(summary, indent=2))
