#!/usr/bin/env python3
"""Exercise the existing persisted exception and the raw pre-launch boundary."""
import hashlib
import json
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class TraceabilityFreezeTests(unittest.TestCase):
    def test_persisted_binding_twins(self):
        source = (ROOT / "tests/workflow-state.tests.sh").read_text()
        names = ("fail", "rule_id", "make_full_fixture", "expect_rule",
                 "expect_valid", "latest_task_round_dir", "wfi030_sha",
                 "wfi030_set_status", "wfi030_fixture")
        helpers = []
        for name in names:
            match = re.search(r"^" + name + r"\(\) \{[^\n]*\}\s*$", source, re.M)
            if match is None:
                match = re.search(r"^" + name + r"\(\) \{\n.*?^\}", source, re.M | re.S)
            self.assertIsNotNone(match, name)
            helper = match.group()
            if name == "wfi030_fixture":
                anchor = '  trace="$specs/traceability.md"\n'
                self.assertEqual(helper.count(anchor), 1)
                helper = helper.replace(anchor, anchor +
                    '  sed -i.bak "s/| Code Target |/| Evidence |/" "$trace"\n')
            helpers.append(helper)
        driver = "set -euo pipefail\nROOT=" + shlex.quote(str(ROOT)) + "\n"
        driver += 'CHECKER="$ROOT/plugins/sdd-quality-loop/scripts/check-workflow-state.sh"\n'
        driver += 'TMP="$(mktemp -d)"\ntrap \'rm -rf "$TMP"\' EXIT\n'
        driver += "\n".join(helpers) + "\n"
        driver += r'''
base="$(wfi030_fixture closed-statuses)"
trace="$base/specs/workflow-state-integrity/traceability.md"
cp "$trace" "$TMP/original"
for state in Planned 'In Progress' 'Implementation Complete' Done Blocked; do
  cp "$TMP/original" "$trace"
  wfi030_set_status "$trace" "$state"
  expect_valid "$base"
  printf 'ok: persisted twins %s\n' "$state"
done
for state in Delivered done 'Done (verified)'; do
  cp "$TMP/original" "$trace"
  wfi030_set_status "$trace" "$state"
  expect_rule "$base" stage-provenance
  printf 'ok: persisted twins reject %s\n' "$state"
done
cp "$TMP/original" "$trace"
printf '\nUnapproved body change\n' >> "$trace"
expect_rule "$base" stage-provenance
printf 'ok: persisted twins reject body change\n'
cp "$TMP/original" "$trace"
python3 - "$trace" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1])
lines = p.read_text().splitlines(keepends=True)
index = None
for line_no, line in enumerate(lines):
    cells = line.split('|')
    if 'Evidence' in [c.strip() for c in cells]:
        index = [c.strip() for c in cells].index('Evidence')
    elif index is not None and line.startswith('| REQ-'):
        cells[index] = ' unapproved-evidence '
        lines[line_no] = '|'.join(cells)
        p.write_text(''.join(lines))
        break
else:
    raise SystemExit('Evidence fixture cell not found')
PY
expect_rule "$base" stage-provenance
printf 'ok: persisted twins reject Evidence change\n'
'''
        result = subprocess.run(["bash"], input=driver, text=True, capture_output=True)
        print(result.stdout, end="")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_raw_prelaunch_binding_twins(self):
        with tempfile.TemporaryDirectory(prefix="traceability-raw-") as temporary:
            root = Path(temporary)
            feature = "raw-binding"
            spec = root / "specs" / feature
            spec.mkdir(parents=True)
            files = {name: "# REQ-001\n" for name in
                     ("tasks.md", "requirements.md", "acceptance-tests.md", "design.md")}
            layers = ("ux-spec.md", "frontend-spec.md", "infra-spec.md", "security-spec.md")
            files.update({name: "# fixture\n" for name in layers})
            files["traceability.md"] = ("| Requirement | Layer Spec | Evidence | Status |\n"
                                        "|---|---|---|---|\n"
                                        "| REQ-001 | ux-spec.md#fixture | baseline | Planned |\n")
            for name, content in files.items():
                (spec / name).write_text(content)
            digest = lambda name: hashlib.sha256((spec / name).read_bytes()).hexdigest()
            (root / "specs/workflow-state-registry.json").write_text(json.dumps(
                {"entries": [{"feature": feature, "profile": "full"}]}))
            report = root / "reports/task-review" / feature / "attempt-1/round-1"
            report.mkdir(parents=True)
            precheck = {"schema": "task-review-precheck/v1", "feature": feature,
                        "attempt": 1, "round": 1, "tasks_sha256_form": "raw",
                        "tasks_sha256": digest("tasks.md"),
                        "requirements_sha256": digest("requirements.md"),
                        "acceptance_sha256": digest("acceptance-tests.md"),
                        "design_sha256": digest("design.md"),
                        "traceability_sha256": digest("traceability.md"),
                        "layer_sha256": {name: digest(name) for name in layers}}
            (report / "precheck-result.json").write_text(json.dumps(precheck))
            scripts = ROOT / "plugins/sdd-review-loop/scripts"
            # PowerShell resolves its root from PSScriptRoot rather than cwd.
            isolated_scripts = root / "plugins/sdd-review-loop/scripts"
            shutil.copytree(scripts, isolated_scripts)
            for original in scripts.rglob("*"):
                if original.is_file():
                    self.assertEqual(original.read_bytes(),
                                     (isolated_scripts / original.relative_to(scripts)).read_bytes())
            commands = [["bash", str(scripts / "task-review-precheck.sh"), feature, "1", "1", "--verify-inputs"],
                        ["pwsh", "-NoProfile", "-File", str(isolated_scripts / "task-review-precheck.ps1"),
                         "-Feature", feature, "-Attempt", "1", "-Round", "1", "-VerifyInputs"]]
            for changed in (False, True):
                if changed:
                    (spec / "traceability.md").write_text(files["traceability.md"].replace("Planned", "Done"))
                for command in commands:
                    with self.subTest(runtime=command[0], changed=changed):
                        result = subprocess.run(command, cwd=root, text=True, capture_output=True)
                        output = result.stdout + result.stderr
                        if changed:
                            self.assertNotEqual(result.returncode, 0, output)
                            self.assertIn("traceability review input changed after precheck", output)
                        else:
                            self.assertEqual(result.returncode, 0, output)


if __name__ == "__main__":
    unittest.main(verbosity=2)
