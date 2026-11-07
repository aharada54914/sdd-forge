#!/usr/bin/env python3
"""Reproduce the bundled pure-Python runtime from a hash-locked PyPI wheel."""
import hashlib
import json
import pathlib
import shutil
import subprocess
import sys
import tempfile
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
destination = root / 'plugins/sdd-quality-loop/scripts/_schema_vendor'
with tempfile.TemporaryDirectory() as temporary:
    subprocess.run([sys.executable, '-m', 'pip', 'download', '--require-hashes',
                    '--no-deps', '--only-binary=:all:', '-r', str(destination / 'requirements.txt'),
                    '--dest', temporary], check=True)
    wheel, = pathlib.Path(temporary).glob('*.whl')
    files = {}
    with zipfile.ZipFile(wheel) as archive:
        for name in archive.namelist():
            path = pathlib.PurePosixPath(name)
            if name.startswith('fastjsonschema/') and not name.endswith('/'):
                target = destination / name
            elif name.endswith('/licenses/LICENSE'):
                target = destination / 'LICENSE.fastjsonschema'
            else:
                continue
            if '..' in path.parts or path.is_absolute():
                raise ValueError('unsafe wheel member')
            data = archive.read(name)
            if target.name == "LICENSE.fastjsonschema":
                data = data.replace(b"\r\n", b"\n")
            files[str(target.relative_to(destination))] = data
    for previous in destination.glob('fastjsonschema-*.whl'):
        previous.unlink()
    shutil.copyfile(wheel, destination / wheel.name)
    (destination / 'LICENSE.fastjsonschema').write_bytes(files['LICENSE.fastjsonschema'])
    manifest = {'wheel': wheel.name, 'sha256': hashlib.sha256(wheel.read_bytes()).hexdigest(),
                'files': {name: hashlib.sha256(data).hexdigest() for name, data in sorted(files.items())}}
    (destination / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
