"""Verify A2 applied archives against strictly additive current protections."""
import argparse
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import sys

sys.dont_write_bytecode = True


def validate_archive(archive, live, mutations=False):
    suffix = ".candidate" if (archive / "MANIFEST.sha256.candidate").is_file() else ""
    manifest = archive / ("MANIFEST.sha256" + suffix)
    # Only these seven A2 files may enter the temporary authenticated bundle.
    relatives = [".github/workflows/test.yml", "plugins/sdd-quality-loop/references/guard-invariants.json",
                 "plugins/sdd-quality-loop/scripts/generate-guard-invariants.py"]
    relatives += ["plugins/sdd-quality-loop/scripts/generated/" + name for name in (
        "guard_invariants.py", "guard-invariants.generated.js", "guard-invariants.generated.ps1",
        "guard-invariants.generated.sh")]
    rows = [line.split("  ", 1) for line in manifest.read_text(encoding="utf-8").splitlines() if line]
    if (len(rows) != len(relatives) or any(len(row) != 2 for row in rows)
            or {row[1] for row in rows} != set(relatives)):
        raise ValueError("archive manifest must identify exactly the seven A2 files")
    hashes = {relative: digest for digest, relative in rows}
    with tempfile.TemporaryDirectory(prefix="a2-guard-evolution-") as directory:
        bundle = Path(directory)
        (bundle / "MANIFEST.sha256").write_bytes(manifest.read_bytes())
        for relative in relatives:
            content = (archive / (relative + suffix)).read_bytes()
            if hashlib.sha256(content).hexdigest() != hashes[relative]:
                raise ValueError("archive file differs from its recorded manifest: " + relative)
            target = bundle / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
        path = Path(__file__).with_name("guard-invariants-evolution.py")
        spec = importlib.util.spec_from_file_location("guard_evolution", path)
        evolution = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(evolution)
        staged = bundle / "plugins/sdd-quality-loop"
        (evolution.self_test if mutations else evolution.validate)(staged, live)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("live", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    try:
        validate_archive(args.archive, args.live, args.self_test)
    except (ValueError, OSError, AssertionError) as error:
        parser.exit(1, str(error) + "\n")
