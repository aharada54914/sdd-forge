#!/usr/bin/env python3
"""Reproduce the bundled pure-Python runtime from a hash-locked PyPI wheel."""
from email.parser import BytesParser
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

destination = pathlib.Path(__file__).resolve().with_name('_schema_vendor')
with tempfile.TemporaryDirectory() as temporary:
    subprocess.run([sys.executable, '-m', 'pip', 'download', '--require-hashes',
                    '--no-deps', '--only-binary=:all:', '-r', str(destination / 'requirements.txt'),
                    '--dest', temporary], check=True)
    wheel, = pathlib.Path(temporary).glob('*.whl')
    if not wheel.name.endswith('-py3-none-any.whl'):
        raise ValueError('schema runtime must remain a platform-independent Python wheel')
    files = {}
    with zipfile.ZipFile(wheel) as archive:
        metadata_name, = (name for name in archive.namelist() if name.endswith('.dist-info/METADATA'))
        metadata = BytesParser().parsebytes(archive.read(metadata_name))
        optional_extra = r"""[^;]+;\s*extra\s*==\s*["'][A-Za-z0-9_-]+["']"""
        if any(re.fullmatch(optional_extra, requirement) is None
               for requirement in metadata.get_all('Requires-Dist', [])):
            raise ValueError('new transitive dependencies require an explicit distribution review')
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
    shutil.copyfile(wheel, destination / "fastjsonschema.whl")
    (destination / 'LICENSE.fastjsonschema').write_bytes(files['LICENSE.fastjsonschema'])
    manifest = {'wheel': wheel.name, 'sha256': hashlib.sha256(wheel.read_bytes()).hexdigest(),
                'files': {name: hashlib.sha256(data).hexdigest() for name, data in sorted(files.items())}}
    (destination / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
