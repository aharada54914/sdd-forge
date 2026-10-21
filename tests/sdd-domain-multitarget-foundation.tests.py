#!/usr/bin/env python3
"""Current #423 inventory and boundary checks; historical snapshots stay intact."""
import copy
import importlib.util
import json
from pathlib import Path, PurePosixPath
import re
import tempfile
import os
import shutil
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
VERIFICATION = ROOT / "specs/sdd-domain-multitarget/verification"


def load_module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"Cannot load verification module: {path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def section_range(text, heading):
    """Find one real ATX section, excluding fenced examples and peer sections."""
    if not isinstance(heading, str) or not re.fullmatch(r"#{1,6} .+", heading):
        raise ValueError("invalid section heading")
    headings = []
    fence = None
    lines = text.splitlines()
    for index, line in enumerate(lines):
        marker = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", line)
        if fence:
            if (marker and marker[1][0] == fence[0]
                    and len(marker[1]) >= len(fence)
                    and not marker[2].strip()):
                fence = None
            continue
        if marker:
            fence = marker[1]
            continue
        match = re.match(r"^ {0,3}(#{1,6}) (.+?)\s*$", line)
        if match:
            title = re.sub(r"\s+#+$", "", match[2])
            headings.append((index, len(match[1]), match[1] + " " + title))
    matches = [item for item in headings if item[2] == heading]
    if len(matches) != 1:
        raise ValueError("section heading is missing or ambiguous: " + heading)
    start, level, _ = matches[0]
    end = next((i for i, depth, _ in headings if i > start and depth <= level), len(lines))
    return start + 1, end


def resolve_inventory(inventory, root):
    """Project maintained section references into the original validator contract."""
    resolved = copy.deepcopy(inventory)
    root = root.resolve()
    for entry in resolved["entries"]:
        for source in entry["source"]:
            if "section" not in source:
                continue
            if "line_start" in source or "line_end" in source:
                raise ValueError("section and line references must not be mixed")
            relative = source["path"]
            parts = PurePosixPath(relative).parts
            if (not parts or PurePosixPath(relative).is_absolute()
                    or ".." in parts or "\\" in relative
                    or str(PurePosixPath(relative)) != relative):
                raise ValueError("noncanonical source path")
            path = root
            for part in parts:
                path = path / part
                if path.is_symlink():
                    raise ValueError("source path traverses a symlink")
            if not path.is_file() or root not in path.resolve().parents:
                raise ValueError("source is not a contained regular file")
            start, end = section_range(path.read_text(encoding="utf-8"), source.pop("section"))
            source.update(line_start=start, line_end=end)
    return resolved


class CurrentAnchorTests(unittest.TestCase):
    def test_current_suite_remains_on_catalog_normal_and_native_ci_paths(self):
        runner = load_module("verification", ROOT / "tests/verification.py")
        workflow = load_module("verification_workflow", ROOT / "tests/verification-workflow.py")
        path = "tests/sdd-domain-multitarget-foundation.tests.py"
        catalog = runner.load_catalog(ROOT / "tests/verification-catalog.json", ROOT)
        for profile in ("local-posix", "local-powershell"):
            self.assertIn(path, catalog["profiles"][profile])
        commands = []
        if os.name != "nt":
            commands.append(["bash", str(ROOT / "tests/run-all.sh"), "--list"])
        pwsh = os.environ.get("SDD_TEST_PWSH") or shutil.which("pwsh")
        if pwsh:
            commands.append([pwsh, "-NoProfile", "-File", str(ROOT / "tests/run-all.ps1"), "-List"])
        else:
            print("Native PowerShell launcher unavailable: its execution remains pending")
        for command in commands:
            result = subprocess.run(command, text=True, capture_output=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(path, result.stdout.splitlines())
        data = workflow.load_workflow(ROOT / ".github/workflows/test.yml")
        job = "cloud-native"  # the catalog's ci-cloud profile runs this suite
        for os_name in ("windows-latest", "macos-latest", "ubuntu-latest"):
            one = copy.deepcopy(data)
            one["jobs"] = {name: one["jobs"][name] for name in ("ci-plan", job)}
            # The planner must declare exactly the retained groups' outputs.
            keep = {"run_ci_plan", "run_" + job.replace("-", "_"), "plan_artifact_name"}
            outputs = one["jobs"]["ci-plan"]["outputs"]
            one["jobs"]["ci-plan"]["outputs"] = {key: value for key, value in outputs.items() if key in keep}
            one["jobs"][job]["strategy"]["matrix"]["os"] = [os_name]
            self.assertIn(path, workflow.workflow_coverage(one, catalog)[job])
        # The real YAML consumer must detect removed execution, not find prose.
        missing = copy.deepcopy(data)
        missing["jobs"][job]["steps"] = []
        self.assertNotIn(path, workflow.workflow_coverage(missing, catalog)[job])

    def test_line_insertion_preserves_meaning(self):
        text = "# Skill\n\n## Required Outputs\nseven Markdown files\n## Next\nother\n"
        self.assertEqual(section_range(text, "## Required Outputs"), (3, 4))
        self.assertEqual(section_range("intro\n" * 50 + text, "## Required Outputs"), (53, 54))

    def test_missing_or_duplicate_heading_is_rejected(self):
        for text in ["# Other\n", "## Required Outputs\na\n## Required Outputs\nb\n"]:
            with self.subTest(text=text), self.assertRaises(ValueError):
                section_range(text, "## Required Outputs")

    def test_fenced_heading_is_not_an_anchor(self):
        for fence in ["```", "~~~~"]:
            with self.subTest(fence=fence), self.assertRaises(ValueError):
                section_range(fence + "\n## Required Outputs\n" + fence, "## Required Outputs")

    def test_requirement_in_another_section_does_not_satisfy_source(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "skill.md"
            path.write_text("## Required Outputs\nremoved\n## Other\nseven Markdown files\n", encoding="utf-8")
            inventory = {"entries": [{"source": [{"path": "skill.md", "section": "## Required Outputs", "keyword": "seven Markdown files"}]}]}
            source = resolve_inventory(inventory, root)["entries"][0]["source"][0]
            failures = INVENTORY._validate_source("example", source, str(root))
            self.assertTrue(any("stale source evidence" in item for item in failures))
            self.assertIn("section", inventory["entries"][0]["source"][0])

    def test_source_path_escape_is_rejected(self):
        for path in ["../skill.md", "/skill.md", "a/../skill.md", "a\\skill.md", "./skill.md"]:
            with self.subTest(path=path), self.assertRaises(ValueError):
                resolve_inventory({"entries": [{"source": [{"path": path, "section": "## Required Outputs"}]}]}, ROOT)

    def test_mixed_section_and_line_evidence_is_rejected(self):
        with self.assertRaises(ValueError):
            resolve_inventory({"entries": [{"source": [{"path": "README.md", "section": "# SDD Forge", "line_start": 1}]}]}, ROOT)

    def test_symlinked_source_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "actual.md"
            target.write_text("## Required Outputs\nseven Markdown files\n", encoding="utf-8")
            try:
                (root / "link.md").symlink_to(target)
            except (OSError, NotImplementedError):
                self.skipTest("host cannot create real symlinks")
            with self.assertRaises(ValueError):
                resolve_inventory({"entries": [{"source": [{"path": "link.md", "section": "## Required Outputs"}]}]}, root)


INVENTORY = load_module("historical_consumer_inventory", VERIFICATION / "T-001/consumer-inventory.tests.py")
BOUNDARIES = load_module("foundation_contract_boundaries", VERIFICATION / "T-002/contract-boundaries.tests.py")


if __name__ == "__main__":
    inventory = json.loads((VERIFICATION / "T-001/current-consumer-inventory.json").read_text(encoding="utf-8"))
    INVENTORY.ConsumerInventoryTests.repo_root = str(ROOT)
    INVENTORY.ConsumerInventoryTests.inventory = resolve_inventory(inventory, ROOT)
    BOUNDARIES.REPO_ROOT = ROOT
    suite = unittest.TestSuite([
        unittest.defaultTestLoader.loadTestsFromTestCase(CurrentAnchorTests),
        unittest.defaultTestLoader.loadTestsFromModule(INVENTORY),
        unittest.defaultTestLoader.loadTestsFromModule(BOUNDARIES),
    ])
    raise SystemExit(not unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful())
