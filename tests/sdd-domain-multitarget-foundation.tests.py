#!/usr/bin/env python3
"""Current #423 inventory and boundary checks; historical snapshots stay intact."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path, PurePosixPath
import re
import tempfile
import os
import shutil
import stat
import subprocess
import unittest
from unittest.mock import patch


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
            try:
                mode = path.stat().st_mode
            except FileNotFoundError:
                # The inventory validator reports the missing file against its entry.
                continue
            if not stat.S_ISREG(mode) or root not in path.resolve().parents:
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
        job = "v2-guardrails"
        self.assertIn(job, catalog["_suites"][path]["ci_jobs"])
        self.assertIn(job, data["jobs"]["required-checks"]["needs"])
        native = data["jobs"][job]
        admitted_hosts = set()
        # The Linux registration check must still run if both foundation commands disappear.
        checker = "verification-ci.tests.py"
        checker_catalog = {"suites": [{"path": checker, "runtime": "python", "args": [
            "CurrentV2WorkflowTests.test_hosts_and_workloads_on_each_v2_job_route"]}]}
        defaults = {**data.get("defaults", {}).get("run", {}), **native.get("defaults", {}).get("run", {})}
        for row in workflow.matrix_rows(native):
            one = copy.deepcopy(data)
            one["jobs"][job]["strategy"]["matrix"] = {"include": [row]}
            host = workflow.expand_matrix(native["runs-on"], row)
            if path in workflow.workflow_coverage(one, catalog)[job]:
                admitted_hosts.add(host)
            if host == "ubuntu-latest":
                eligible = ({**defaults, **step} for step in native["steps"]
                            if workflow.enabled(step.get("if"), row, "Linux")
                            and step.get("continue-on-error", False) is False)
                self.assertTrue(any(step.get("working-directory", ".") == "tests"
                                    and checker in workflow.step_suites(step, checker_catalog, row, step.get("shell", "bash"))
                                    for step in eligible), "Linux must run the independent CI registration check")
        self.assertEqual(admitted_hosts, {"windows-latest", "macos-latest", "ubuntu-latest"})
        # The real YAML consumer must detect removed execution, not find prose.
        missing = copy.deepcopy(data)
        for step in missing["jobs"][job]["steps"]:
            if path in step.get("run", ""):
                step["run"] = "# " + path
        self.assertNotIn(path, workflow.workflow_coverage(missing, catalog)[job])

    def test_five_archived_inventory_rows_match_v126(self):
        inventory = json.loads((VERIFICATION / "T-001/current-consumer-inventory.json").read_text(encoding="utf-8"))
        rows = {entry["id"]: entry for entry in inventory["entries"] if entry["id"] in ARCHIVED_IDS}
        # The tag's maintained inventory uses section anchors for three of these five rows.
        encoded = json.dumps(rows, sort_keys=True, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self.assertEqual(hashlib.sha256(encoded).hexdigest(),
                         "2bf6aafdbccc842e830b5b042b5e50f03e90969f34de9885325eb1799b964c92")

    def test_archive_cannot_supply_current_evidence_or_replace_a_retired_source(self):
        source = {"path": "tests/fixtures/bootstrap-v1.26.0/interviewer.md", "line_start": 203,
                  "line_end": 238, "keyword": "interview-question-bank.md"}
        self.assertEqual(ORIGINAL_VALIDATE_SOURCE("example", source, ROOT), [])
        for entry in ("risk-tier-verifier-contract", "bootstrap-question-bank"):
            with self.subTest(entry=entry):
                self.assertTrue(validate_inventory_source(entry, source, ROOT))

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

    def test_missing_section_source_does_not_hide_other_entries(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "present.md").write_text("## Scope\ncurrent evidence\n", encoding="utf-8")
            inventory = {"entries": [
                {"id": name, "source": [{"path": name + ".md", "section": "## Scope", "keyword": "current evidence"}]}
                for name in ("missing", "present")]}
            resolved = resolve_inventory(inventory, root)
            failures = [issue for entry in resolved["entries"]
                        for issue in INVENTORY._validate_source(entry["id"], entry["source"][0], root)]
            self.assertEqual(failures, ["entry 'missing' source file does not exist under repo-root: missing.md"])

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


# v1.26.0, b193c75be2a6f2e6c7074bb65401f514268a65fb. The other seven
# classifications continue to read their maintained source from the checkout.
ARCHIVED_IDS = {"bootstrap-question-bank", "bootstrap-seven-layer-output", "layer-template-fixed-rows",
                "endpoint-contract-checklist", "host-adapters"}
INTERVIEWER = "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/"
ARCHIVED_FILES = {
    INTERVIEWER + "SKILL.md":
        ("interviewer.md", "1b4b384d575c829ee941901f44fcff01a71b19d456059b174d7ec23577bab134"),
    INTERVIEWER + "templates/design.template.md":
        ("design.template.md", "17c69864fd42ca609fc604699abbe7f4c5860483f844a0cd37bcd63bb6838da5"),
    INTERVIEWER + "references/architecture-review-checklist.md":
        ("architecture-review-checklist.md", "fff699c1d03fa41f016b3abdb543e3df0f4c85691e0211e1d01b60093f75c20e"),
}


ORIGINAL_VALIDATE_SOURCE = INVENTORY._validate_source


def validate_inventory_source(entry_id, source, repo_root):
    if not isinstance(source, dict) or not isinstance(source.get("path"), str):
        return ORIGINAL_VALIDATE_SOURCE(entry_id, source, repo_root)
    root = Path(repo_root).resolve()
    fixtures = root / "tests/fixtures"
    source = source.copy()
    try:
        if entry_id in ARCHIVED_IDS:
            name, digest = ARCHIVED_FILES[source["path"]]
            path = fixtures / "bootstrap-v1.26.0" / name
            if path.resolve() != path or hashlib.sha256(path.read_bytes()).hexdigest() != digest:
                raise ValueError("v1.26.0 inventory source mismatch: " + source["path"])
            source["path"] = path.relative_to(root).as_posix()
        else:
            target = (root / source["path"]).resolve()
            if not target.is_relative_to(root) or target.is_relative_to(fixtures):
                raise ValueError("expected a current checkout source: " + source["path"])
        if "section" in source:
            projected = resolve_inventory({"entries": [{"source": [source]}]}, root)
            source = projected["entries"][0]["source"][0]
    except (KeyError, OSError, ValueError) as error:
        return [f"entry '{entry_id}' source verification failed: {error}"]
    return ORIGINAL_VALIDATE_SOURCE(entry_id, source, repo_root)


class CurrentConsumerInventoryTests(INVENTORY.ConsumerInventoryTests):
    repo_root = str(ROOT)

    @classmethod
    def setUpClass(cls):
        path = VERIFICATION / "T-001/current-consumer-inventory.json"
        cls.inventory = json.loads(path.read_text(encoding="utf-8"))
        scoped = patch.object(INVENTORY, "_validate_source", validate_inventory_source)
        scoped.start()
        cls.addClassCleanup(scoped.stop)


def current_ci_mcp_violations(server_text, client_text):
    # The shared transport replaced the two historical sibling fetches. All
    # other historical tool, method and import checks still apply to real bytes.
    violations = [item for item in BOUNDARIES._scan_ci_mcp_read_only(server_text, client_text)
                  if item != "fetch-call-count-mismatch"]
    methods = BOUNDARIES._METHOD_RE.findall(client_text)
    shared = re.search(r"(?ms)^async function requestGithub<.*?(?=^const defaultFetch:)", client_text)
    if len(methods) != 1 or shared is None or BOUNDARIES._METHOD_RE.findall(shared[0]) != ["GET"]:
        violations.append("fetch-call-count-mismatch")
    declarations = list(re.finditer(r"(?m)^export async function ([A-Za-z]+)\(", client_text))
    for name, accept in (("githubGet", "application/vnd.github+json"), ("githubGetText", "application/vnd.github+json")):
        bodies = [client_text[match.start():declarations[index + 1].start() if index + 1 < len(declarations) else len(client_text)]
                  for index, match in enumerate(declarations) if match[1] == name]
        call = 'await requestGithub(request, "' + accept + '", fetchImpl)'
        if len(bodies) != 1 or bodies[0].count(call) != 1:
            violations.append("shared-transport-delegate-mismatch:" + name)
    return violations


class CurrentCiMcpReadOnlyBoundaryTests(BOUNDARIES.CiMcpReadOnlyBoundaryTests):
    def test_actual_tools_are_exactly_the_five_read_only_tools(self):
        self.assertEqual(current_ci_mcp_violations(self.server_text, self.client_text), [])

    def test_current_shared_transport_negative_controls(self):
        for original, replacement, diagnostic in (
            ('await fetchImpl(url, { method: "GET"', 'await fetchImpl(url, { method: "POST"', 'non-get-method:POST'),
            ('await fetchImpl(', 'await anotherClient(', 'fetch-call-count-mismatch'),
            ('await requestGithub(request, "application/vnd.github+json", fetchImpl)',
             'await anotherClient(request, "application/vnd.github+json", fetchImpl)',
             'shared-transport-delegate-mismatch:githubGet'),
            ('await requestGithub(request, "application/vnd.github+json", fetchImpl)',
             'await anotherClient(request, "application/vnd.github+json", fetchImpl)',
             'shared-transport-delegate-mismatch:githubGetText'),
        ):
            with self.subTest(diagnostic=diagnostic):
                changed = (replacement.join(self.client_text.rsplit(original, 1))
                           if diagnostic.endswith(":githubGetText")
                           else self.client_text.replace(original, replacement, 1))
                self.assertNotEqual(changed, self.client_text)
                self.assertIn(diagnostic, current_ci_mcp_violations(self.server_text, changed))
        wrong_media = '"text/plain"'.join(self.client_text.rsplit('"application/vnd.github+json"', 1))
        self.assertIn('shared-transport-delegate-mismatch:githubGetText',
                      current_ci_mcp_violations(self.server_text, wrong_media))
        duplicate = self.client_text + '\nawait fetchImpl(url, { method: "GET", headers, signal });\n'
        self.assertIn('fetch-call-count-mismatch', current_ci_mcp_violations(self.server_text, duplicate))


def current_boundary_tests():
    # Preserve the frozen module and all its negative controls. Only its actual
    # two-fetch assertion is replaced by the maintained shared-transport check.
    return unittest.TestSuite(
        unittest.defaultTestLoader.loadTestsFromTestCase(
            CurrentCiMcpReadOnlyBoundaryTests if case is BOUNDARIES.CiMcpReadOnlyBoundaryTests else case)
        for case in vars(BOUNDARIES).values()
        if isinstance(case, type) and issubclass(case, unittest.TestCase)
        and case.__module__ == BOUNDARIES.__name__)


if __name__ == "__main__":
    BOUNDARIES.REPO_ROOT = ROOT
    suite = unittest.TestSuite([
        unittest.defaultTestLoader.loadTestsFromTestCase(CurrentAnchorTests),
        unittest.defaultTestLoader.loadTestsFromTestCase(CurrentConsumerInventoryTests),
        current_boundary_tests(),
    ])
    raise SystemExit(not unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful())
