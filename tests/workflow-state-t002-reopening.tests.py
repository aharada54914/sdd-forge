"""Exercise the real workflow-state entry points; only fixture data are written."""
import copy
import json
import pathlib
import shutil
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"
FEATURE = "sdd-forge-mcp"
OVERRIDE = {"T-002": ["Implementation Complete", "Done"]}


def task(identity, status="Done", approval="Approved"):
    return f"## {identity} fixture\n\nApproval: {approval}\nStatus: {status}\n\n"


class ReopeningTests(unittest.TestCase):
    def test_runtime_matrix(self):
        registry = json.loads((ROOT / "specs/workflow-state-registry.json").read_text())
        entry = next(e for e in registry["entries"] if e["feature"] == FEATURE)
        cases = [
            ("done", task("T-001") + task("T-002"), True, None),
            ("reopened", task("T-001") + task("T-002", "Implementation Complete"), True, None),
            ("other-task", task("T-001", "Implementation Complete") + task("T-002"), False, None),
            ("duplicate", task("T-002") + task("T-002", "Implementation Complete"), False, None),
            ("malformed-heading", task("T-002") + task("T-002x", "Implementation Complete"), False, None),
            ("indented-heading", "## T-002\n  " + task("T-003", "Implementation Complete"), False, None),
            ("tab-heading", "## T-002\n\t" + task("T-003", "Implementation Complete"), False, None),
            ("missing-heading-space", "## T-002\n" + task("T-003", "Implementation Complete").replace("## T-003", "##T-003"), False, None),
            ("absent-target", task("T-001"), False, None),
            ("orphan", "Status: Implementation Complete\n" + task("T-002"), False, None),
            ("missing-approval", task("T-002", "Implementation Complete").replace("Approval: Approved\n", ""), False, None),
            ("duplicate-status", task("T-002") + "Status: Implementation Complete\n", False, None),
            ("duplicate-approval", task("T-002", "Implementation Complete") + "Approval: Approved\n", False, None),
            ("missing-status", task("T-002").replace("Status: Done\n", ""), False, None),
            ("wrong-registry-task", task("T-002", "Implementation Complete"), False, {"T-003": OVERRIDE["T-002"]}),
            ("wildcard", task("T-002", "Implementation Complete"), False, {"*": OVERRIDE["T-002"]}),
            ("broader-registry", task("T-002", "Implementation Complete"), False, {"T-002": ["Implementation Complete", "Done", "Blocked"]}),
        ]
        for state in ("Planned", "In Progress", "Blocked", "implementation complete", "Implementation Complete\u00a0"):
            cases.append(("state-" + state, task("T-002", state), False, None))
        for approval in ("Draft", "approved"):
            cases.append(("approval-" + approval, task("T-002", "Implementation Complete", approval), False, None))
        for runtime in ("bash", "pwsh"):
            self.assertIsNotNone(shutil.which(runtime), f"required runtime unavailable: {runtime}")
            for newline in ("\n", "\r\n"):
                for name, body, accepted, override in cases:
                    with self.subTest(runtime=runtime, newline=repr(newline), case=name):
                        with tempfile.TemporaryDirectory(prefix="sdd-t002-reopen-") as temporary:
                            fixture = pathlib.Path(temporary)
                            specs = fixture / "specs"
                            feature = specs / FEATURE
                            feature.mkdir(parents=True)
                            for filename, header in (("requirements.md", "Spec"), ("design.md", "Impl")):
                                (feature / filename).write_bytes(f"{header}-Review-Status: Passed{newline}".encode())
                            (feature / "tasks.md").write_bytes(("Task-Review-Status: Passed\n\n" + body).replace("\n", newline).encode())
                            data = copy.deepcopy(registry)
                            data["entries"] = [copy.deepcopy(entry)]
                            data["entries"][0]["legacy"]["task_status_overrides"] = OVERRIDE if override is None else override
                            path = specs / "workflow-state-registry.json"
                            path.write_text(json.dumps(data))
                            suffix = "sh" if runtime == "bash" else "ps1"
                            command = [runtime]
                            if runtime == "pwsh":
                                command += ["-NoProfile", "-File"]
                            command += [str(SCRIPTS / ("check-workflow-state." + suffix)), "--registry", str(path), "--feature", FEATURE]
                            result = subprocess.run(command, text=True, capture_output=True, timeout=30)
                            output = result.stdout + result.stderr
                            self.assertEqual(result.returncode, 0 if accepted else 1, output)
                            if accepted:
                                self.assertIn("workflow-state: ok", output)
                            else:
                                expected = "registry-schema" if override is not None else "legacy-state"
                                self.assertIn(expected, output)


if __name__ == "__main__":
    unittest.main(verbosity=2)
