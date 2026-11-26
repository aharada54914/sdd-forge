"""Local replay of CI inputs from e2110862fef5af5a2c4c9a1d25f2e0ec429791c4."""
import hashlib
from pathlib import Path
import tempfile
from typing import NamedTuple
import zipfile


# The six source hashes are SHA-256 of "git show <commit>:<path>" bytes.
# suite-paths.txt comes independently from "git ls-tree -r --name-only <commit> tests":
# all *.tests.{py,ps1,sh} (case insensitive), plus the four registered entry points
# cli-hook-enforcement.ps1, release-host-smoke.sh, validate-repository.ps1 and
# validate-repository.sh, in tree order, with LF after each name.
HASHES = {
    '.github/workflows/test.yml': '885fdc2cc5e91661d7b15a0fced7e5fb782f9d354a6209e9fbc7e5b8accefa38',
    'tests/verification-catalog.json': 'de424f789403261f495b73a9e58c1599ff651c828fe14c6419de64fa6350d65e',
    'tests/verification-timings.json': 'dc20362834826bd087a00b42243d4436a8266e67d7616346fcde3649952a33fd',
    'mcp/ci-mcp/package.json': 'ce016b9ec7a8c33a4b8b5f6dfac6d6ef83d83033cb8ac541f1a42b76074806d4',
    'mcp/local-env-mcp/package.json': '855838614c9f0870095337a8795513174614542fed522736259bfb018e50ff9c',
    'mcp/sdd-forge-mcp/package.json': '434a81b283ac12a7b20620ce5c554049369dc7bc08e7293b062921492bc39e87',
    'suite-paths.txt': '58c01ddcc6d1944689f6030380e9765724b4c2e6282c62d0b48c8e98d30f0570',
}


class ReleasedInputs(NamedTuple):
    root: Path
    workflow: dict
    catalog: dict
    weights: dict


def load(test, workflow):
    directory = tempfile.TemporaryDirectory()
    test.addCleanup(directory.cleanup)
    root = Path(directory.name)
    with zipfile.ZipFile(Path(__file__).with_name('e2110862f-inputs.zip')) as archive:
        test.assertCountEqual(archive.namelist(), HASHES.keys())
        for name, digest in HASHES.items():
            data = archive.read(name)
            test.assertEqual(hashlib.sha256(data).hexdigest(), digest, name)
            if name == 'suite-paths.txt':
                # Inventory only. These archived suite bodies are never executed.
                for relative in data.decode().splitlines():
                    path = root / relative
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.touch()
            else:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
    runner = workflow.runner_module()
    return ReleasedInputs(root, workflow.load_workflow(root / '.github/workflows/test.yml'),
                          runner.load_catalog(root / 'tests/verification-catalog.json', root),
                          runner.load_weights(root / 'tests/verification-timings.json'))
