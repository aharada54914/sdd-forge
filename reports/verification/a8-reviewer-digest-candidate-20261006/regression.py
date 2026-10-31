"""Run existing shared suite on a disposable candidate overlay, never originals."""
from pathlib import Path
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]


with tempfile.TemporaryDirectory(prefix='a8-digest-regression-') as temp:
    root = Path(temp).resolve()
    for folder in ('plugins', 'tests'):
        shutil.copytree(ROOT / folder, root / folder, symlinks=True)
    for source in (HERE / 'candidate').rglob('*'):
        if source.is_file():
            target = root / source.relative_to(HERE / 'candidate')
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
    proc = subprocess.run(['rtk', 'proxy', 'bash', 'tests/review-context-boundary.tests.sh'],
                          cwd=root, capture_output=True, text=True)
    (HERE / 'shared-regression.stdout.txt').write_text(proc.stdout)
    (HERE / 'shared-regression.stderr.txt').write_text(proc.stderr)
    print(proc.stdout, end='')
    print(proc.stderr, end='')
    print('exit=' + str(proc.returncode))
    raise SystemExit(proc.returncode)
