"""Run unchanged scratch-history driver against isolated candidate copies."""
import pathlib
import shutil
import subprocess
import tempfile

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[2]
with tempfile.TemporaryDirectory(prefix="sdd423-validator-candidate-") as directory:
    fixture = pathlib.Path(directory)
    scripts = fixture / "plugins/sdd-quality-loop/scripts"
    scripts.mkdir(parents=True)
    for source, target in (("validator-bash.candidate.txt", "validate-review-context-set.sh"),
                           ("validator-pwsh.candidate.txt", "validate-review-context-set.ps1")):
        shutil.copyfile(HERE / source, scripts / target)
    result = subprocess.run(["python3", "-B", str(ROOT / "tests/review-scratch-history.tests.py"),
                             "--repo", str(fixture)], check=False)
    raise SystemExit(result.returncode)
