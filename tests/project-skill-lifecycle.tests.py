#!/usr/bin/env python3
"""Real CLI executions and ownership/conflict controls for project skills."""

import importlib.util
import json
import os
from pathlib import Path
import sys
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "author", ROOT / "plugins/sdd-bootstrap/scripts/project-skill.py"
)
A = importlib.util.module_from_spec(spec)
spec.loader.exec_module(A)


HTTP_FIXTURE = r"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import threading, time, urllib.request, urllib.error
ready_at=time.monotonic()+.08
class App(BaseHTTPRequestHandler):
    def log_message(self,*args):pass
    def do_GET(self):
        if time.monotonic()<ready_at:
            self.send_response(503);self.end_headers();return
        self.send_response(200);self.end_headers()
        if self.path=="/health":self.wfile.write(b'{"ready":true}')
        else:self.wfile.write(b'<html><body>'+Path("state.json").read_bytes()+b'</body></html>')
    def do_POST(self):
        data=self.rfile.read(int(self.headers['Content-Length']))
        Path("state.json").write_bytes(data)
        self.send_response(201);self.end_headers();self.wfile.write(b'created')
server=ThreadingHTTPServer(('127.0.0.1',0),App)
threading.Thread(target=server.serve_forever,daemon=True).start()
url='http://127.0.0.1:'+str(server.server_port)
try:
    assert not Path("state.json").exists()
    deadline=time.monotonic()+2
    while True:
        try:
            with urllib.request.urlopen(url+'/health',timeout=.2) as response:
                assert response.read()==b'{"ready":true}'
            break
        except urllib.error.HTTPError:
            assert time.monotonic()<deadline
            time.sleep(.02)
    request=urllib.request.Request(url+'/items',data=b'{"name":"first"}',method='POST')
    with urllib.request.urlopen(request,timeout=1) as response:assert response.status==201
    with urllib.request.urlopen(url+'/',timeout=1) as response:assert b'first' in response.read()
    assert Path("state.json").read_text()=='{"name":"first"}'
    print('HTTP and HTML user paths observed')
finally:
    server.shutdown();server.server_close()
"""


class Lifecycle(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.skill = self.root / "sdd/skills/verify-app"
        self.skill.mkdir(parents=True)
        (self.skill / "SKILL.md").write_text(
            "---\nname: verify-app\ndescription: Verify the application.\n---\nUse public CLI.\n"
        )

    def seal(self, source):
        (self.skill / "run.py").write_text(source)
        return A.seal(
            self.root, "verify-app", Path(sys.executable).name, "run.py", ["smoke"], []
        )

    def run_skill(self, **kwargs):
        if os.name != "posix":
            self.skipTest(
                "runner explicitly reports unsupported owned process backend on this platform"
            )
        return A.run(self.root, "verify-app", "smoke", **kwargs)

    def test_changed_imported_runner_or_validator_is_not_readmitted(self):
        self.seal('print("ok")')
        with tempfile.TemporaryDirectory() as directory:
            installed = Path(directory)
            for relative in (
                "plugins/sdd-bootstrap/scripts/project-skill.py",
                "plugins/sdd-bootstrap/scripts/project-skill-process.py",
                "plugins/sdd-quality-loop/scripts/validate-project-skill.py",
                "plugins/sdd-quality-loop/scripts/validate-facet-manifest.py",
                "plugins/sdd-quality-loop/contracts/project-skill-manifest.schema.json",
                "plugins/sdd-quality-loop/contracts/project-verification-observation.schema.json",
            ):
                target = installed / relative
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes((ROOT / relative).read_bytes())
            runner_path = installed / "plugins/sdd-bootstrap/scripts/project-skill.py"
            copied_spec = importlib.util.spec_from_file_location("copied_runner", runner_path)
            copied = importlib.util.module_from_spec(copied_spec)
            copied_spec.loader.exec_module(copied)
            for path in (runner_path, Path(copied.V.__file__), Path(copied.V._schema.__file__)):
                original = path.read_bytes()
                path.write_bytes(original + b"\n# changed after import\n")
                with patch.object(copied, "execute") as execute:
                    with self.assertRaisesRegex(ValueError, "runtime-changed"):
                        copied.run(self.root, "verify-app", "smoke")
                    execute.assert_not_called()
                path.write_bytes(original)

    def test_generation_is_draft(self):
        self.assertEqual(self.seal('print("ok")')["status"], "draft")

    def test_actual_execution_cleanup_evidence(self):
        self.seal(
            'from pathlib import Path\nPath("owned.txt").write_text("data")\nprint("public CLI success")\n'
        )
        result = self.run_skill()
        self.assertEqual(result["outcome"], "passed")
        self.assertTrue(result["cleanup"])
        self.assertFalse((self.root / "owned.txt").exists())
        self.assertEqual(
            (self.root / result["stdout"]["path"]).read_text(), "public CLI success\n"
        )
        self.assertIn("owned.txt", result["observed_outputs"])
        self.assertTrue((self.root / result["receipt"]).is_file())

    def test_manifest_change_after_admission_cannot_pass(self):
        self.seal("import sys\nraise SystemExit(3 if len(sys.argv)>1 else 0)\n")
        original = A.V.discover

        def replaced(root, name, task=None):
            snapshot = original(root, name, task)
            if root == self.root:
                manifest = dict(snapshot[0], args=["fail"])
                A.save(self.skill / "skill-manifest.json", manifest)
            return snapshot

        with (
            patch.object(A.V, "discover", side_effect=replaced),
            patch.object(A, "execute") as execute,
        ):
            result = self.run_skill()
        execute.assert_not_called()
        self.assertFalse(result["observation_written"])
        self.assertEqual(result["outcome"], "failed")

    def test_admitted_file_copy_uses_the_verified_read(self):
        self.seal('print("ok")\n')
        seed = self.root / "seed.txt"
        seed.write_bytes(b"admitted")
        original = Path.read_bytes
        reads = 0
        copied = []

        def swapped(path):
            nonlocal reads
            data = original(path)
            if path == seed:
                reads += 1
                if reads == 2:
                    seed.write_bytes(b"replacement")
            return data

        def execute(argv, execution, timeout, limit, *, env):
            self.assertNotIn("SHLVL", env)
            self.assertNotIn("PWD", env)
            copied.append(original(execution / "seed.txt"))
            return 0, b"", b"", None, True

        with (
            patch.object(Path, "read_bytes", swapped),
            patch.object(A, "execute", execute),
        ):
            self.run_skill(inputs=["seed.txt"])
        self.assertEqual(copied, [b"admitted"])

    def test_observation_receipt_binds_published_bytes(self):
        self.seal("raise SystemExit(3)\n")
        result = self.run_skill()
        self.assertEqual(result["exit_code"], 3)
        self.assertEqual(
            result["observation_sha256"],
            A.V.digest((self.root / result["observation"]).read_bytes()),
        )

    def test_missing_seed_failure_not_success(self):
        self.seal(
            'from pathlib import Path\nassert Path("seed.json").exists(), "missing seed"\n'
        )
        result = self.run_skill()
        self.assertEqual(result["outcome"], "failed")
        self.assertTrue(result["cleanup"])

    def test_explicit_source_is_copied(self):
        self.seal(
            'from pathlib import Path\nassert Path("seed.json").read_text()=="empty"\n'
        )
        (self.root / "seed.json").write_text("empty")
        result = self.run_skill(inputs=["seed.json"])
        self.assertEqual(result["outcome"], "passed")
        self.assertEqual((self.root / "seed.json").read_text(), "empty")

    def test_input_mutation_retains_failed_evidence(self):
        self.seal('from pathlib import Path\nPath("seed.json").write_text("mutated")\n')
        (self.root / "seed.json").write_text("empty")
        result = self.run_skill(inputs=["seed.json"])
        self.assertEqual(result["outcome"], "failed")
        self.assertEqual(result["reason"], "runner-modified-input")
        self.assertEqual((self.root / "seed.json").read_text(), "empty")

    def test_timeout_and_retained_logs(self):
        self.seal('import time\nprint("started", flush=True)\ntime.sleep(20)\n')
        result = self.run_skill(timeout=0.15)
        self.assertEqual(result["reason"], "timeout")
        self.assertEqual(result["outcome"], "failed")
        self.assertEqual(
            (self.root / result["stdout"]["path"]).read_text(), "started\n"
        )

    def test_output_limit(self):
        self.seal('print("x"*100000)\n')
        result = self.run_skill(output_limit=128)
        self.assertEqual(result["reason"], "output-limit")
        self.assertLessEqual((self.root / result["stdout"]["path"]).stat().st_size, 128)

    def test_missing_runtime_observed(self):
        (self.skill / "run.py").write_text("unused")
        A.seal(
            self.root, "verify-app", "missing-runtime-fixture", "run.py", ["smoke"], []
        )
        result = A.run(self.root, "verify-app", "smoke")
        self.assertEqual(result["outcome"], "unavailable")

    def test_reseal_preserves_extensions(self):
        self.seal('print("ok")')
        before = (self.skill / "skill-manifest.json").read_bytes()
        with self.assertRaisesRegex(ValueError, "manifest-exists"):
            self.seal('print("edited")')
        self.assertEqual((self.skill / "skill-manifest.json").read_bytes(), before)

    def test_maintenance_reexecutes(self):
        self.seal('print("ok")')
        r = self.run_skill()
        m = A.maintain(self.root, "verify-app", self.root / r["receipt"], 1)
        self.assertEqual(m["status"], "clean")
        self.assertEqual(len(m["results"]), 1)

    def test_maintenance_source_drift(self):
        self.seal('from pathlib import Path\nprint(Path("input.txt").read_text())')
        (self.root / "input.txt").write_text("old")
        r = self.run_skill(inputs=["input.txt"])
        (self.root / "input.txt").write_text("new")
        m = A.maintain(self.root, "verify-app", self.root / r["receipt"], 1)
        self.assertEqual(m["status"], "changed")

    def test_host_projection_and_user_conflict(self):
        self.seal('print("ok")')
        for host in ("claude", "codex", "copilot"):
            result = A.project(self.root, "verify-app", host)
            self.assertEqual(result["native_host_verification"], "unverified")
            self.assertEqual(
                A.project(self.root, "verify-app", host, True)["status"], "checked"
            )
            target = self.root / result["path"]
            target.write_text("user customization")
            with self.assertRaisesRegex(ValueError, "user-edit-conflict"):
                A.project(self.root, "verify-app", host)
            self.assertEqual(target.read_text(), "user customization")

    def test_unreachable_frontmatter(self):
        (self.skill / "SKILL.md").write_text(
            "---\nname: verify-app\nuser-invocable: false\ndisable-model-invocation: true\n---\n"
        )
        self.seal('print("ok")')
        with self.assertRaisesRegex(ValueError, "unreachable"):
            A.project(self.root, "verify-app", "claude")

    def task_manifest(self):
        inputs = [
            {
                "path": p.relative_to(self.root).as_posix(),
                "sha256": A.V.digest(p.read_bytes()),
            }
            for p in self.skill.iterdir()
        ]
        task = {
            "schema": "task-input-manifest/v1",
            "task_id": "T-001",
            "run_id": "run1",
            "session_id": "s1",
            "agent_instance_id": "a1",
            "model_tier": "standard",
            "provider": "fixture",
            "model": "fixture",
            "estimated_cost_per_attempt_usd": "0",
            "cost_estimate_source": "fixture",
            "cost_estimate_timestamp": "2026-10-25T00:00:00Z",
            "isolation_mode": "fresh-agent",
            "fallback_reason": "",
            "handoff_reload_evidence_hash": "",
            "allowed_inputs": inputs,
            "allowed_outputs": [
                "output/",
                "reports/project-skill-observations/T-001/run1/",
            ],
        }
        path = self.root / "task-input.json"
        path.write_text(json.dumps(task))
        return path

    def test_task_output_publication(self):
        self.seal(
            'from pathlib import Path\nPath("output").mkdir()\nPath("output/result.txt").write_text("observed")\n'
        )
        task = self.task_manifest()
        result = self.run_skill(task_path=task)
        self.assertEqual(result["outcome"], "passed")
        self.assertTrue(result["observation_written"])
        self.assertEqual((self.root / "output/result.txt").read_text(), "observed")
        validated = A.V.validate(
            self.root, "verify-app", self.root / result["observation"], task
        )
        self.assertTrue(
            A.V.project_execution({"id": "smoke", "required": True}, validated)[
                "passes"
            ]
        )

    def test_task_unadmitted_write_is_failed_and_retained(self):
        self.seal(
            'from pathlib import Path\nPath("outside.txt").write_text("bad")\nprint("captured")\n'
        )
        task = self.task_manifest()
        result = self.run_skill(task_path=task)
        self.assertEqual(result["outcome"], "failed")
        self.assertEqual(result["reason"], "runner-output-unbound")
        self.assertFalse((self.root / "outside.txt").exists())
        self.assertTrue((self.root / result["stdout"]["path"]).exists())

    def test_task_missing_log_admission_writes_nothing(self):
        self.seal('print("ok")')
        task = self.task_manifest()
        doc = json.loads(task.read_text())
        doc["allowed_outputs"] = ["output/"]
        task.write_text(json.dumps(doc))
        with self.assertRaisesRegex(ValueError, "evidence-directory-unbound"):
            self.run_skill(task_path=task)
        self.assertFalse((self.root / "reports").exists())

    def test_actual_http_and_web_ready_state(self):
        self.seal(HTTP_FIXTURE)
        result = self.run_skill(timeout=5)
        self.assertEqual(
            result["outcome"],
            "passed",
            (self.root / result["stderr"]["path"]).read_text(),
        )
        self.assertIn("state.json", result["observed_outputs"])
        self.assertIn(
            "HTTP and HTML user paths observed",
            (self.root / result["stdout"]["path"]).read_text(),
        )

    def test_detached_descendant_is_reaped(self):
        self.seal(
            'import subprocess,sys\np=subprocess.Popen([sys.executable,"-c","import time; time.sleep(60)"],start_new_session=True,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)\nprint(p.pid)\n'
        )
        unrelated = subprocess.Popen(
            [sys.executable, "-c", "import time; time.sleep(60)"]
        )
        self.addCleanup(lambda: (unrelated.terminate(), unrelated.wait()))
        result = self.run_skill()
        pid = int((self.root / result["stdout"]["path"]).read_text())
        self.assertTrue(result["cleanup"])
        self.assertIsNone(unrelated.poll())
        with self.assertRaises(ProcessLookupError):
            os.kill(pid, 0)

    def test_exact_log_filename_does_not_authorize_siblings(self):
        self.seal('print("not executed")')
        task = self.task_manifest()
        doc = json.loads(task.read_text())
        base = "reports/project-skill-observations/T-001/run1/"
        doc["allowed_outputs"] = [base + "smoke.json", base + "runner.stdout"]
        task.write_text(json.dumps(doc))
        with self.assertRaisesRegex(ValueError, "evidence-directory-unbound"):
            self.run_skill(task_path=task)
        self.assertFalse((self.root / "reports").exists())

    def test_invocation_flags_preserved_or_blocked(self):
        (self.skill / "SKILL.md").write_text(
            "---\nname: verify-app\ndescription: Verify app.\ndisable-model-invocation:   true # human only\n---\n"
        )
        self.seal('print("ok")')
        result = A.project(self.root, "verify-app", "claude")
        self.assertIn(
            "disable-model-invocation:   true", (self.root / result["path"]).read_text()
        )
        for host in ("codex", "copilot"):
            with self.assertRaisesRegex(
                ValueError, "host-required-controls-unverified"
            ):
                A.project(self.root, "verify-app", host)

    def test_body_example_is_not_frontmatter_policy(self):
        (self.skill / "SKILL.md").write_text(
            "---\nname: verify-app\ndescription: Verify app.\n---\nExample: user-invocable: false and disable-model-invocation: true\n"
        )
        self.seal('print("ok")')
        self.assertEqual(
            A.project(self.root, "verify-app", "claude")["status"], "generated"
        )

    def test_api_limits(self):
        self.seal('print("not executed")')
        for value in (float("nan"), float("inf"), 0, -1, True):
            with (
                self.subTest(value=value),
                self.assertRaisesRegex(ValueError, "timeout"),
            ):
                A.run(self.root, "verify-app", "smoke", timeout=value)
        self.assertFalse((self.root / "reports").exists())

    def test_malformed_projection_ledger(self):
        self.seal('print("ok")')
        (self.root / "sdd/skill-projections.json").write_text(
            '{"schema":"project-skill-projections/v1","files":[]}'
        )
        with self.assertRaisesRegex(ValueError, "projection-ledger-invalid"):
            A.project(self.root, "verify-app", "claude")

    def test_unrelated_baseline_refused(self):
        self.seal('print("ok")')
        baseline = self.root / "baseline.json"
        baseline.write_text(
            '{"schema":"project-skill-trial/v1","skill":"other","inputs":{}}'
        )
        with self.assertRaisesRegex(ValueError, "baseline-identity-invalid"):
            A.maintain(self.root, "verify-app", baseline, 1)

    def test_projection_name_identity(self):
        for header in (
            "name: collision",
            "name: verify-app\nname: verify-app",
            "description: no name",
        ):
            with self.subTest(header=header):
                (self.skill / "SKILL.md").write_text("---\n" + header + "\n---\n")
                manifest = self.skill / "skill-manifest.json"
                if manifest.exists():
                    manifest.unlink()
                self.seal('print("ok")')
                with self.assertRaisesRegex(ValueError, "skill-frontmatter-name"):
                    A.project(self.root, "verify-app", "claude")
        self.assertFalse((self.root / ".claude").exists())

    def test_quoted_control_and_identity_keys_refused(self):
        for extra in (
            '"disable-model-invocation": true',
            '"name": collision',
            "<<: *defaults",
            "!!str disable-model-invocation: true",
            "? disable-model-invocation",
        ):
            with self.subTest(extra=extra):
                (self.skill / "SKILL.md").write_text(
                    "---\nname: verify-app\ndescription: test\n" + extra + "\n---\n"
                )
                manifest = self.skill / "skill-manifest.json"
                if manifest.exists():
                    manifest.unlink()
                self.seal('print("ok")')
                with self.assertRaisesRegex(ValueError, "key-dialect-unsupported"):
                    A.project(self.root, "verify-app", "codex")
        self.assertFalse((self.root / ".agents").exists())

    def test_maintenance_index_gap_is_blocked(self):
        features = self.skill / "features"
        features.mkdir()
        (features / "README.md").write_text("# Features\n")
        (features / "login.md").write_text("# Login\nCheck ID: smoke\n")
        self.seal('print("ok")')
        baseline = self.run_skill()
        result = A.maintain(self.root, "verify-app", self.root / baseline["receipt"], 1)
        self.assertEqual(result["status"], "blocked")
        self.assertEqual(result["classification"], "harness-gap")
        self.assertEqual(result["unexecuted"], ["login.md"])

    def test_diagnosis_profile_real_cli(self):
        self.seal(
            'from pathlib import Path\nprint("missing configuration" if not Path("config.json").exists() else "ready")\nraise SystemExit(1 if not Path("config.json").exists() else 0)\n'
        )
        result = self.run_skill()
        self.assertEqual(result["outcome"], "failed")
        self.assertIn(
            "missing configuration", (self.root / result["stdout"]["path"]).read_text()
        )
        self.assertTrue(result["cleanup"])

    def test_migration_dry_run_preserves_admitted_data(self):
        self.seal(
            'import subprocess,sys\nsubprocess.run([sys.executable,"migrate.py","--dry-run"],check=True)\n'
        )
        (self.root / "seed.json").write_text('{"version":1}')
        (self.root / "migrate.py").write_text(
            'import json,sys\nfrom pathlib import Path\nx=json.loads(Path("seed.json").read_text()); x["version"]=2\nassert sys.argv[1]=="--dry-run"\nprint(json.dumps(x))\n'
        )
        result = self.run_skill(inputs=["seed.json", "migrate.py"])
        self.assertEqual(result["outcome"], "passed")
        self.assertEqual(result["observed_outputs"], {})
        self.assertIn(
            '"version": 2', (self.root / result["stdout"]["path"]).read_text()
        )
        self.assertEqual((self.root / "seed.json").read_text(), '{"version":1}')

    def test_lying_dry_run_detected_by_actual_effect(self):
        self.seal(
            'from pathlib import Path\nPath("seed.json").write_text("mutated")\nprint("dry run made no changes")\n'
        )
        (self.root / "seed.json").write_text("original")
        result = self.run_skill(inputs=["seed.json"])
        self.assertEqual(result["outcome"], "failed")
        self.assertEqual(result["reason"], "runner-modified-input")
        self.assertEqual((self.root / "seed.json").read_text(), "original")

    def test_data_preparation_observes_owned_output(self):
        self.seal(
            'from pathlib import Path\nPath("prepared.json").write_text("[]")\nprint("prepared empty data")\n'
        )
        result = self.run_skill()
        self.assertEqual(result["outcome"], "passed")
        self.assertEqual(result["observed_outputs"]["prepared.json"], A.V.digest(b"[]"))
        self.assertFalse((self.root / "prepared.json").exists())

    def test_unresolved_reference(self):
        (self.skill / "run.py").write_text('print("ok")')
        with self.assertRaisesRegex(ValueError, "entry-not-in-closure"):
            A.seal(self.root, "verify-app", "python3", "missing.py", ["smoke"], [])
        self.assertFalse((self.skill / "skill-manifest.json").exists())


if __name__ == "__main__":
    unittest.main()
