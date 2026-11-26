"""Offline contracts for the release, version bump, and scheduled catalog check."""
from functools import cached_property
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SUITES = [
    f"tests/v2-{name}.test.mjs" for name in (
        "soft-guard", "spec-drift", "sdd-core-flow", "hooks-and-ci", "real-flows-e2e",
        "sdd-doctor", "software-factory", "prompts-and-delegation", "mcp-server",
        "antigravity-and-factory",
    )
]
DOCTOR = "plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs"


def workflow_jobs(filename):
    # Ubuntu ships Ruby's standard YAML parser. Inspect executable step values,
    # so a comment mentioning a test cannot satisfy its registration.
    raw = subprocess.check_output(
        ["ruby", "-ryaml", "-rjson", "-e", "print YAML.safe_load(STDIN.read).to_json"],
        input=(ROOT / ".github/workflows" / filename).read_bytes(),
    )
    return json.loads(raw)["jobs"]


def write(root, path, value):
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(value.encode("utf-8"))
    return target


class ReleaseReadiness(unittest.TestCase):
    @cached_property
    def jobs(self):
        return workflow_jobs("release.yml")

    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.env = dict(os.environ)
        for name in ("GH_TOKEN", "GITHUB_TOKEN", "GOOGLE_FIXTURE_SOURCE"):
            self.env.pop(name, None)

    def run_cli(self, command, success=True):
        result = subprocess.run(command, cwd=self.root, env=self.env, encoding="utf-8",
                                errors="replace", capture_output=True, timeout=45)
        output = result.stdout + result.stderr
        self.assertEqual(result.returncode == 0, success, output)
        return output

    def step(self, job, name):
        return next(step for step in self.jobs[job]["steps"] if step.get("name") == name)

    def run_step(self, job, name, success=True):
        return self.run_cli(["bash", "-eo", "pipefail", "-c", self.step(job, name)["run"]], success)

    def test_config_and_model_catalog(self):
        self.run_cli(["bash", str(ROOT / "tests/release-config-lock.tests.sh"), "--release-config-only"])
        job = workflow_jobs("model-freshness-check.yml")["freshness-check"]
        self.assertIn("bash .github/scripts/check-model-freshness.sh",
                      [step.get("run") for step in job["steps"]])
        self.run_cli(["bash", str(ROOT / "tests/model-freshness-check.tests.sh"), "--release-catalog"])

    def test_release_prerequisites(self):
        self.check_release_prerequisites()
        self.jobs["release"]["needs"].remove("loop-gate")
        with self.assertRaisesRegex(AssertionError, "loop-gate"):
            self.check_release_prerequisites()

    def check_release_prerequisites(self):
        gate, release = self.jobs["loop-gate"], self.jobs["release"]
        self.assertEqual(gate["needs"], "ci-green")
        for output in ("tag", "sha", "pkg"):
            self.assertEqual(self.jobs["ci-green"]["outputs"][output], "${{ steps.source.outputs." + output + " }}")
        for key, output in (("TAG", "tag"), ("RELEASE_SHA", "sha"), ("PKG", "pkg")):
            self.assertEqual(release["env"][key], "${{ needs.ci-green.outputs." + output + " }}")
        self.assertCountEqual(release["needs"], ["ci-green", "loop-gate"])
        self.assertEqual(gate["runs-on"], "ubuntu-latest")
        self.assertNotIn("strategy", gate)
        self.assertEqual(gate["permissions"], {"contents": "read"})
        for job in (gate, release):
            self.assertNotIn("if", job)
            self.assertNotIn("continue-on-error", job)
            checkouts = [s for s in job["steps"] if s.get("uses", "").startswith("actions/checkout@")]
            self.assertEqual(len(checkouts), 1)
            self.assertEqual(checkouts[0]["with"]["ref"], "${{ needs.ci-green.outputs.sha }}")
            self.assertIs(checkouts[0]["with"]["persist-credentials"], False)
            if job is gate:
                self.assertEqual(checkouts[0]["with"]["fetch-depth"], 0)
        for step in release["steps"]:
            self.assertNotIn("continue-on-error", step)
            if step.get("name") != "Release-only real host smoke":
                self.assertNotIn("if", step)
        for step in gate["steps"]:
            self.assertNotIn("if", step)
            self.assertNotIn("continue-on-error", step)
        self.assertEqual(self.step("loop-gate", "Run SDD Forge v2 deterministic release suites")["run"].split(),
                         ["node", "--test", *SUITES])
        health = self.step("loop-gate", "Run sdd-doctor health check and POSIX installer checks")
        self.assertEqual(health["run"].splitlines(), [
            f"node {DOCTOR} --root . --quiet-info", "bash scripts/check-sdd-structure.sh",
            "bash -n install.sh && bash -n uninstall.sh",
        ])

    def test_admission_uses_ci_for_the_tagged_commit(self):
        restriction = "Restrict manual dispatch to main or a tag ref"
        for ref, allowed in [("refs/heads/main", True), ("refs/tags/v1.0.0", True),
                             ("refs/heads/topic", False)]:
            self.env["GITHUB_REF"] = ref
            self.run_step("ci-green", restriction, allowed)
        sha = "1" * 40
        write(self.root, "tag.json", json.dumps({"object": {"type": "commit", "sha": sha}}))
        gh = write(self.root, "gh", """#!/bin/sh
case "$1 $2" in
  "api repos/fixture/repo/git/refs/tags/v1.0.0") cat tag.json ;;
  "api repos/fixture/repo/actions/workflows/test.yml/runs?head_sha=$SHA&status=success&per_page=100")
    test "$3" = --paginate && cat runs.json ;;
  *) exit 6 ;;
esac
""")
        gh.chmod(0o755)
        self.env.update(PATH=f"{self.root}:{self.env['PATH']}", SHA=sha, INPUT_TAG="v1.0.0",
                        GITHUB_OUTPUT=str(self.root / "outputs"), GITHUB_REPOSITORY="fixture/repo")
        repository = {"full_name": "fixture/repo"}
        run = dict(head_sha=sha, status="completed", conclusion="success", event="push",
                   head_branch="main", path=".github/workflows/test.yml",
                   repository=repository, head_repository=repository)
        for changes in ({}, {"head_sha": "2" * 40}, {"conclusion": "failure"}, {"event": "pull_request"}):
            with self.subTest(changes=changes):
                output = write(self.root, "outputs", "")
                write(self.root, "runs.json", json.dumps({"workflow_runs": [dict(run, **changes)]}))
                self.run_step("ci-green", "Verify CI success for the release commit", not changes)
                wanted = ["tag=v1.0.0", f"sha={sha}", "pkg=sdd-forge-v1.0.0.tar.gz"]
                self.assertEqual(output.read_text().splitlines(), [] if changes else wanted)

    def test_source_archive_sbom_checksums_and_provenance(self):
        self.run_cli(["git", "init", "-q"])
        source = write(self.root, ".github/workflows/build.yml", "      - uses: demo/build@v1\n")
        self.run_cli(["git", "add", "."])
        self.run_cli(["git", "-c", "user.name=fixture", "-c", "user.email=fixture@example.invalid",
                      "-c", "commit.gpgsign=false", "commit", "-qm", "release"])
        sha = self.run_cli(["git", "rev-parse", "HEAD"]).strip()
        tag = "v1.0.0"
        pkg = f"sdd-forge-{tag}.tar.gz"
        self.env.update(TAG=tag, RELEASE_SHA=sha, PKG=pkg, RUNNER_TEMP=str(self.root),
                        GITHUB_SERVER_URL="https://example.invalid", GITHUB_REPOSITORY="fixture/repo",
                        GITHUB_WORKFLOW_REF="fixture/repo/.github/workflows/release.yml@refs/heads/main",
                        GITHUB_WORKFLOW_SHA="2" * 40, GITHUB_EVENT_NAME="workflow_dispatch",
                        GITHUB_REPOSITORY_ID="1", GITHUB_REPOSITORY_OWNER_ID="2",
                        RUNNER_ENVIRONMENT="github-hosted", GITHUB_RUN_ID="1", GITHUB_RUN_ATTEMPT="1")
        # A different working copy must never supply the SBOM components.
        source.write_text("      - uses: demo/local@v2\n")
        scripts = self.root / ".github/scripts"
        scripts.mkdir()
        shutil.copy(ROOT / ".github/scripts/generate-sbom.py", scripts)
        self.env["RELEASE_SHA"] = "3" * 40
        self.run_step("loop-gate", "Verify loop checkout", False)
        self.run_step("release", "Build reproducible source tarball", False)
        self.assertFalse((self.root / pkg).exists())
        self.env["RELEASE_SHA"] = sha
        self.run_step("loop-gate", "Verify loop checkout")
        self.run_step("release", "Build reproducible source tarball")
        with tarfile.open(self.root / pkg) as archive:
            member = archive.extractfile(f"sdd-forge-{tag}/.github/workflows/build.yml")
            self.assertIn(b"demo/build@v1", member.read())
        self.run_step("release", "Generate CycloneDX SBOM")
        sbom = json.loads((self.root / "sdd-forge-sbom.cdx.json").read_text())
        self.assertEqual([(c["name"], c["version"]) for c in sbom["components"]], [("demo/build", "v1")])
        self.run_step("release", "Publish SHA-256 checksums")
        checksums = (self.root / "SHA256SUMS").read_text().splitlines()
        self.assertEqual(checksums, [f"{hashlib.sha256((self.root / path).read_bytes()).hexdigest()}  {path}"
                                     for path in (pkg, "sdd-forge-sbom.cdx.json")])
        self.run_step("release", "Record immutable build inputs")
        provenance = json.loads((self.root / "release-provenance.json").read_text())
        deps = provenance["buildDefinition"]["resolvedDependencies"]
        self.assertEqual([(d["uri"].split("@")[-1], d["digest"]["gitCommit"]) for d in deps],
                         [("refs/heads/main", "2" * 40), (f"refs/tags/{tag}", sha)])
        attest = self.step("release", "Attest build provenance (sigstore keyless)")["with"]
        self.assertEqual(attest["predicate-path"], "release-provenance.json")
        self.assertEqual(attest["subject-path"].splitlines(), ["${{ needs.ci-green.outputs.pkg }}", "sdd-forge-sbom.cdx.json"])

    def test_upload_rechecks_tag_before_selecting_files(self):
        # No network: this executable only reads a fixture and records filenames.
        gh = write(self.root, "gh", """#!/bin/sh
case "$1 $2" in
  "api repos/fixture/repo/git/refs/tags/v1.0.0") cat tag.json ;;
  "release upload") printf '%s\\n' "$@" > upload-arguments ;;
  *) exit 6 ;;
esac
""")
        gh.chmod(0o755)
        sha = "1" * 40
        self.env.update(PATH=f"{self.root}:{self.env['PATH']}", TAG="v1.0.0", RELEASE_SHA=sha,
                        PKG="sdd-forge-v1.0.0.tar.gz", GITHUB_REPOSITORY="fixture/repo")
        for current in ("2" * 40, sha):
            write(self.root, "tag.json", json.dumps({"object": {"type": "commit", "sha": current}}))
            self.run_step("release", "Upload release assets", current == sha)
            recorded = self.root / "upload-arguments"
            if current == sha:
                self.assertEqual(recorded.read_text().splitlines(), [
                    "release", "upload", "--clobber", "--", "v1.0.0", self.env["PKG"],
                    "sdd-forge-sbom.cdx.json", "SHA256SUMS",
                ])
            else:
                self.assertFalse(recorded.exists())

    def test_bump_stops_before_writing_or_synchronizes_all_files(self):
        target = self.root / "scripts"
        target.mkdir()
        shutil.copy(ROOT / "scripts/bump-version.sh", target)
        write(self.root, "CHANGELOG.md", "## v1.1.0 (fixture)\n")
        surfaces = ["README.md", "mcp/sdd-forge-mcp/src/server.ts"]
        surfaces += [f"plugins/sdd-ship/{name}" for name in (
            ".antigravity-plugin/plugin.json", ".claude-plugin/plugin.json", ".codex-plugin/plugin.json",
            ".plugin/plugin.json", "gemini-extension.json", "gemini/gemini-extension.json")]
        surfaces += [".claude-plugin/marketplace.json", ".agents/plugins/marketplace.json",
                     "mcp/sdd-forge-mcp/package.json"]
        before = {p: '{"version": "1.0.0"}\n' for p in surfaces}
        before.update({"README.md": "v1.0.0 — release\n", "mcp/sdd-forge-mcp/src/server.ts": 'version: "1.0.0"\n'})
        for path, content in before.items():
            write(self.root, path, content)
        for path in SUITES:
            write(self.root, path, f'import fs from "node:fs";\nfs.writeFileSync("{path}.ran", "yes");\n'
                  f'if (process.env.FAIL_AT === "{path}") throw Error("fixture suite failed");\n')
        write(self.root, DOCTOR, 'import fs from "node:fs";\n'
              'if (process.argv.slice(2).join(" ") !== "--root . --quiet-info") process.exit(2);\n'
              'fs.writeFileSync("doctor.ran", "yes");\n'
              'if (process.env.FAIL_AT === "doctor") throw Error("fixture doctor failed");\n')
        for fail_at in (SUITES[0], SUITES[-1], "doctor", ""):
            with self.subTest(fail_at=fail_at):
                self.env["FAIL_AT"] = fail_at
                (self.root / "doctor.ran").unlink(missing_ok=True)
                for suite in SUITES:
                    (self.root / (suite + ".ran")).unlink(missing_ok=True)
                out = self.run_cli(["bash", "scripts/bump-version.sh", "1.1.0"], not fail_at)
                if fail_at:
                    cause = "doctor" if fail_at == "doctor" else "suite"
                    self.assertIn(f"fixture {cause} failed", out)
                self.assertEqual((self.root / "doctor.ran").exists(), fail_at in ("", "doctor"))
                if not fail_at:
                    self.assertTrue(all((self.root / (p + ".ran")).is_file() for p in SUITES))
                for path, old in before.items():
                    expected = old if fail_at else old.replace("1.0.0", "1.1.0")
                    self.assertEqual((self.root / path).read_bytes(), expected.encode("utf-8"), path)


if __name__ == "__main__":
    unittest.main(verbosity=2)
