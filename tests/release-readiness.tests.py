"""Offline contracts for the release, version bump, and scheduled catalog check."""
from functools import cached_property
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import shlex
import shutil
import subprocess
import sys
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
CHANGELOG_SOURCES = (".github/scripts/changelog-version.mjs", ".github/scripts/vendor/marked/marked.mjs")


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
        self.root = Path(temp.name).resolve()
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
        self.run_cli(["bash", str(ROOT / "tests/release-config-lock.tests.sh")])
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
        self.assertEqual(self.jobs["ci-green"]["permissions"], {"contents": "read", "actions": "read"})
        self.assertEqual(gate["permissions"], {"contents": "read"})
        self.assertEqual(release["permissions"], {
            "contents": "write", "id-token": "write", "attestations": "write",
        })
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

    def version_check_commands(self):
        version = "1.2.3"
        self.env["RELEASE_TAG"] = f"v{version}"
        suite = "tests/v2-hooks-and-ci.test.mjs"
        # Node 20 initializes the Shadow suite even when the filter selects only the version check.
        for path in (suite, ".github/workflows/sdd-guardrails.yml", *CHANGELOG_SOURCES):
            (self.root / path).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / path, self.root / path)
        for path in ("plugins/sdd-ship/.claude-plugin/plugin.json", "mcp/sdd-forge-mcp/package.json"):
            write(self.root, path, json.dumps({"version": version}))
        for path in (".claude-plugin/marketplace.json", ".agents/plugins/marketplace.json"):
            write(self.root, path, json.dumps({"plugins": [{"name": "sdd-ship", "version": version}]}))
        for path in ("mcp/sdd-forge-mcp/src/server.ts", "mcp/sdd-forge-mcp/dist/index.js"):
            write(self.root, path, f'const release = {{version: "{version}"}};\n')
        ci_case = "all plugin manifests, marketplaces, README, and CHANGELOG agree on one release version"
        ci = ["node", "--test", "--test-reporter=tap", f"--test-name-pattern={ci_case}", suite]
        release = self.step("loop-gate", "Verify release tag matches all plugin manifests and CHANGELOG")["run"]
        return (("CI", ci), ("release", ["bash", "-eo", "pipefail", "-c", release]))

    def check_version_case(self, commands, case, failure=None):
        for name, command in commands:
            with self.subTest(case=case, entry=name):
                output = self.run_cli(command, failure is None)
                if failure is not None:
                    self.assertIn(failure, output)
                elif name == "CI":
                    self.assertRegex(output, r"(?m)^# pass 1$")
                else:
                    self.assertIn("Release version consistency verified for v1.2.3", output)

    def test_ci_and_release_verify_the_first_readme_version_heading(self):
        commands = self.version_check_commands()
        write(self.root, "CHANGELOG.md", "## v1.2.3\n")
        for case, readme, valid in (
            ("current", "# Project\n\nRelease notes\n\nv1.2.3 — Current\nv1.2.2 — History\n", True),
            ("history only", "# Project\n\nv1.2.2 — Current\nv1.2.3 — History\n", False),
            ("prerelease", "# Project\n\nv1.2.3-rc.1 — Candidate\n", False),
            ("after line five", "# Project\n\nRelease notes\n\n\nv1.2.3 — History\n", False),
        ):
            write(self.root, "README.md", readme)
            self.check_version_case(commands, case, None if valid else "README.md current release must be v1.2.3")

    def test_ci_and_release_require_one_changelog_heading_for_the_candidate(self):
        commands = self.version_check_commands()
        write(self.root, "README.md", "v1.2.3 — Current\n")
        for case, changelog, count in (
            ("one", "## v1.2.3\n", 1),
            ("missing", "## Unreleased\n", 0),
            ("duplicate", "## v1.2.3 (new)\n## v1.2.2\n## v1.2.3\n", 2),
            ("indented duplicate", "## v1.2.3\n  ## v1.2.3\n", 2),
            ("heading with tabs", "##\tv1.2.3\t(date)\n", 1),
            ("setext example", "v1.2.3\n-------\n", 0),
            ("similar versions", "## v1.2.30\n## v1.2.3-rc.1\n## v1x2x3\n", 0),
            ("history only", "## v1.2.2\nSee v1.2.3 for the new release.\n", 0),
            ("HTML comment only", "<!-- proposed entry\n## v1.2.3\n-->\n", 0),
            ("heading and HTML comment", "## v1.2.3\n<!-- example\n## v1.2.3\n-->\n", 1),
            ("preformatted HTML example", "<pre>\n## v1.2.3\n</pre>\n", 0),
            ("fenced example only", "````md\n## v1.2.3\n```\n## v1.2.3\n````\n", 0),
            ("heading and tilde example", "## v1.2.3\r\n~~~md\r\n## v1.2.3\r\n~~~\r\n", 1),
            ("heading after example", "```md\n## v1.2.3\n```\n## v1.2.3\n", 1),
            ("with history", "## Unreleased\n## v1.2.3 (dated release)\n## v1.2.2\n## v1.2.1\n", 1),
        ):
            write(self.root, "CHANGELOG.md", changelog)
            diagnostic = f"CHANGELOG.md must contain exactly one ## v1.2.3 heading (found {count})"
            self.check_version_case(commands, case, None if count == 1 else diagnostic)

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
    test "$#" -eq 3 && test "$3" = --paginate && cat runs.json && exit "$RUNS_EXIT" ;;
  *) exit 6 ;;
esac
""")
        gh.chmod(0o755)
        self.env.update(PATH=f"{self.root}:{self.env['PATH']}", SHA=sha, INPUT_TAG="v1.0.0", RUNS_EXIT="0",
                        GITHUB_OUTPUT=str(self.root / "outputs"), GITHUB_REPOSITORY="fixture/repo")
        repository = {"full_name": "fixture/repo"}
        run = dict(head_sha=sha, status="completed", conclusion="success", event="push",
                   head_branch="main", path=".github/workflows/test.yml",
                   repository=repository, head_repository=repository)
        def check_response(response, allowed):
            output = write(self.root, "outputs", "")
            write(self.root, "runs.json", response)
            self.run_step("ci-green", "Verify CI success for the release commit", allowed)
            wanted = ["tag=v1.0.0", f"sha={sha}", "pkg=sdd-forge-v1.0.0.tar.gz"]
            self.assertEqual(output.read_text().splitlines(), wanted if allowed else [])

        for changes, allowed in (
            ({}, True),
            ({"event": "workflow_dispatch"}, True),
            ({"event": "workflow_dispatch", "head_branch": "v1.0.0"}, True),
            ({"event": "pull_request"}, False),
            ({"event": "pull_request_target"}, False),
            ({"event": "merge_group"}, False),
            ({"head_branch": "topic"}, False),
            ({"head_sha": "2" * 40}, False),
            ({"status": "in_progress"}, False),
            ({"conclusion": "failure"}, False),
            ({"conclusion": "skipped"}, False),
            ({"path": ".github/workflows/other.yml"}, False),
            ({"repository": {"full_name": "other/repo"}}, False),
            ({"head_repository": {"full_name": "other/repo"}}, False),
            ({"head_repository": None}, False),
        ):
            with self.subTest(changes=changes):
                check_response(json.dumps({"total_count": 99, "workflow_runs": [dict(run, **changes)]}), allowed)

        for response in ("", "null", "not-json", "{}", '{"total_count":99,"workflow_runs":[]}',
                         '{"workflow_runs":{}}', '{"workflow_runs":[null]}'):
            with self.subTest(response=response):
                check_response(response, False)

        pr_runs = [dict(run, event="pull_request", id=n) for n in range(100)]
        pages = [json.dumps({"total_count": 101, "workflow_runs": rows}) for rows in (pr_runs, [run])]
        check_response("\n".join(pages), True)
        # An API error must win even if its partial output contains an otherwise eligible run.
        self.env["RUNS_EXIT"] = "7"
        check_response(pages[1], False)

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
        signing = self.step("release", "Attest build provenance (sigstore keyless)")
        self.assertRegex(signing["uses"], r"^actions/attest-build-provenance@[0-9a-f]{40}\Z")
        attest = signing["with"]
        self.assertEqual(attest["predicate-type"], "https://slsa.dev/provenance/v1")
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

    def prepare_bump(self):
        target = self.root / "scripts"
        target.mkdir(exist_ok=True)
        shutil.copy(ROOT / "scripts/bump-version.sh", target)
        for path in SUITES:
            (self.root / (path + ".ran")).unlink(missing_ok=True)
            write(self.root, path, f'import fs from "node:fs";\nfs.writeFileSync("{path}.ran", "yes");\n'
                  f'if (process.env.FAIL_AT === "{path}") throw Error("fixture failed: {path}");\n')
        (self.root / "doctor.ran").unlink(missing_ok=True)
        write(self.root, DOCTOR, 'import fs from "node:fs";\n'
              'if (process.argv.slice(2).join(" ") !== "--root . --quiet-info") throw Error("doctor arguments");\n'
              f'for (const suite of {json.dumps(SUITES)}) {{\n'
              '  if (!fs.existsSync(suite + ".ran")) throw Error("doctor ran before " + suite);\n'
              '}\nfs.writeFileSync("doctor.ran", "yes");\n'
              'if (process.env.FAIL_AT === "doctor") throw Error("fixture failed: doctor");\n')
        bash = self.env.get("SDD_TEST_BASH")
        if not bash and os.name == "nt":
            # The bash.exe on a native PowerShell PATH can be the WSL launcher.
            git_exe = shutil.which("git")
            self.assertIsNotNone(git_exe, "Git for Windows is required to locate Git Bash")
            git = Path(git_exe).parent
            bash = next((str(p) for p in (git / "bash.exe", git.parent / "bin/bash.exe")
                         if p.is_file()), None)
        elif not bash:
            bash = shutil.which("bash")
        self.assertIsNotNone(bash, "Bash is required to test the workstation version bump")
        return bash

    def check_shipped_bump(self, fail_at):
        bash = self.prepare_bump()
        markets = [".claude-plugin/marketplace.json", ".agents/plugins/marketplace.json"]
        source = "mcp/sdd-forge-mcp/src/server.ts"
        surfaces = [*markets, source, "mcp/sdd-forge-mcp/package.json", "README.md"]
        plugins = set()
        for market in markets:
            entries = json.loads((ROOT / market).read_bytes())["plugins"]
            self.assertTrue(entries, market)
            plugins.update(entry["name"] for entry in entries)
        # Discover manifests on disk independently of marketplace membership.
        # A plugin can ship a host manifest before its marketplace entry lands.
        manifests = set()
        host_dirs = (".antigravity-plugin", ".claude-plugin", ".codex-plugin", ".plugin")
        for root in (ROOT / "plugins").iterdir():
            if root.is_dir():
                manifests.update(path.relative_to(ROOT) for path in root.glob(".*/plugin.json")
                                 if path.parent.name in host_dirs and path.is_file())
                manifests.update(path.relative_to(ROOT) for path in
                                 (root / "gemini-extension.json", root / "gemini/gemini-extension.json")
                                 if path.is_file())
        for plugin in plugins:
            base = Path("plugins") / plugin
            for host in host_dirs:
                self.assertIn(base / host / "plugin.json", manifests)
            self.assertTrue({base / "gemini-extension.json", base / "gemini/gemini-extension.json"} & manifests,
                            f"missing Gemini manifest for {plugin}")
        surfaces.extend(sorted(path.as_posix() for path in manifests))

        before = {path: (ROOT / path).read_bytes() for path in surfaces}
        old = json.loads(before["plugins/sdd-ship/.claude-plugin/plugin.json"])["version"]
        major, minor, patch = old.split(".")
        new = f"{major}.{minor}.{int(patch) + 1}"
        for path, data in before.items():
            target = self.root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        write(self.root, "CHANGELOG.md", f"## v{new} (fixture)\n")

        original_files = {path: path.read_bytes() for path in self.root.rglob("*") if path.is_file()}
        self.env["FAIL_AT"] = fail_at
        output = self.run_cli([bash, "scripts/bump-version.sh", new], not fail_at)
        for suite in SUITES:
            self.assertTrue((self.root / (suite + ".ran")).is_file(), suite)
        self.assertEqual((self.root / "doctor.ran").is_file(), fail_at in ("", "doctor"))
        if fail_at:
            self.assertIn(f"fixture failed: {fail_at}", output)
            self.assertIn("v2 pre-release checks failed; no release surface was modified.", output)
            markers = {self.root / (suite + ".ran") for suite in SUITES} | {self.root / "doctor.ran"}
            self.assertEqual({path for path in self.root.rglob("*") if path.is_file()} - markers,
                             set(original_files))
            for path, data in original_files.items():
                self.assertEqual(path.read_bytes(), data, str(path.relative_to(self.root)))
            return

        for path, data in before.items():
            actual = (self.root / path).read_bytes()
            if path.endswith(".json"):
                expected = json.loads(data)
                entries = expected["plugins"] if path in markets else [expected]
                for entry in entries:
                    self.assertEqual(entry["version"], old, path)
                    entry["version"] = new
                self.assertEqual(json.loads(actual), expected, path)
            elif path == source:
                version = f'version: "{old}"'.encode()
                self.assertIn(version, data, path)
                self.assertEqual(actual, data.replace(version, f'version: "{new}"'.encode()), path)
            else:
                heading = f"v{old} — ".encode()
                self.assertTrue(any(line.startswith(heading) for line in data.splitlines()[:5]), path)
                self.assertEqual(actual, data.replace(heading, f"v{new} — ".encode(), 1), path)

    def check_bump_release_input(self, missing_helper):
        self.env.pop("FAIL_AT", None)
        bash = self.prepare_bump()
        suite = "tests/v2-hooks-and-ci.test.mjs"
        helper = "plugins/sdd-implementation/scripts/managed-model-entry.py"
        readme_case = "all plugin manifests, marketplaces, README, and CHANGELOG agree on one release version"
        helper_case = "keeps the installed managed model entry in the release source"
        # Exercise the published payload, optional MCP packages, and every bump target.
        entries = [line.strip() for line in (ROOT / "install-payload.txt").read_text().splitlines()
                   if line.strip() and not line.lstrip().startswith("#")]
        paths = subprocess.check_output(["git", "ls-files", "-z", "--", *entries, "mcp/",
                                         ".github/workflows/sdd-guardrails.yml"], cwd=ROOT)
        for raw in paths.split(b"\0"):
            if raw:
                path = Path(os.fsdecode(raw))
                (self.root / path).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / path, self.root / path)

        # Keep both real Node assertions intact. Their fixture runs at the point where
        # bump invokes this suite, with its unrelated cases filtered by node:test.
        for path in CHANGELOG_SOURCES:
            (self.root / path).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / path, self.root / path)
        real_suite = "tests/release-inputs.test.mjs"
        shutil.copy2(ROOT / suite, self.root / real_suite)
        arguments = ["--test", "--test-reporter=tap", f"--test-name-pattern={helper_case}|{readme_case}", real_suite]
        write(self.root, suite,
              'import { spawnSync } from "node:child_process";\n'
              'const env = { ...process.env }; delete env.NODE_TEST_CONTEXT;\n'
              f'const result = spawnSync(process.execPath, {json.dumps(arguments)}, {{ env, stdio: "inherit" }});\n'
              'if (result.error) throw result.error;\nprocess.exit(result.status ?? 1);\n')
        ship = self.root / "plugins/sdd-ship/.claude-plugin/plugin.json"
        current = json.loads(ship.read_bytes())["version"]
        major, minor, patch = current.split(".")
        new = f"{major}.{minor}.{int(patch) + 1}"
        with (self.root / "CHANGELOG.md").open("ab") as stream:
            stream.write(f"\n## v{new} (fixture)\n".encode())
        healthy = self.run_cli(["node", *arguments])
        self.assertRegex(healthy, r"(?m)^# pass 2$")

        if missing_helper:
            (self.root / helper).unlink()
            rejected, accepted = helper_case, readme_case
        else:
            readme = self.root / "README.md"
            heading = f"v{current} — ".encode()
            lines = readme.read_bytes().splitlines(keepends=True)
            indexes = [i for i, line in enumerate(lines[:5]) if line.startswith(heading)]
            self.assertEqual(len(indexes), 1)
            i = indexes[0]
            lines[i] = lines[i].replace(heading, f"v{new} — ".encode(), 1)
            readme.write_bytes(b"".join(lines))
            rejected, accepted = readme_case, helper_case

        before = {p: p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        output = self.run_cli([bash, "scripts/bump-version.sh", new], False)
        self.assertIn("v2 pre-release checks failed; no release surface was modified.", output)
        self.assertRegex(output, rf"(?m)not ok [0-9]+ - {rejected}$")
        self.assertRegex(output, rf"(?m)(?<!not )ok [0-9]+ - {accepted}$")
        if missing_helper:
            self.assertIn("ENOENT", output)
            self.assertIn("managed-model-entry.py", output)
        else:
            self.assertIn(f"README.md current release must be v{current}", output)
        markers = {self.root / (entry + ".ran") for entry in SUITES if entry != suite}
        after = {p for p in self.root.rglob("*") if p.is_file()}
        self.assertEqual(after, set(before) | markers)
        for path, data in before.items():
            self.assertEqual(path.read_bytes(), data, str(path.relative_to(self.root)))

    def check_bump_stale_readme(self):
        self.check_bump_release_input(missing_helper=False)

    def check_bump_missing_helper(self):
        self.check_bump_release_input(missing_helper=True)

    # Both shell drivers select individual cases. CI runs them through the public bump test.
    def check_bump_green(self):
        self.check_shipped_bump("")

    def check_bump_first_suite_failure(self):
        self.check_shipped_bump(SUITES[0])

    def check_bump_last_suite_failure(self):
        self.check_shipped_bump(SUITES[-1])

    def check_bump_doctor_failure(self):
        self.check_shipped_bump("doctor")

    def check_bump_gate_source(self):
        source = (ROOT / "scripts/bump-version.sh").read_text(encoding="utf-8")
        bash = self.env.get("SDD_TEST_BASH") or "bash"
        invocation = ('if ! (cd "${ROOT}" && node --test ' + " ".join(SUITES)
                      + f' && node {DOCTOR} --root . --quiet-info) >"${{gate_log}}" 2>&1; then')

        def parsed(script):
            # Bash parses the function definition and prints its canonical nesting.
            # Its body is never called. A trailing command stabilizes the final separator.
            program = "bump_source() {\n" + script + "\n:\n}\ndeclare -f bump_source\n"
            result = subprocess.run([bash, "--noprofile", "--norc"], input=program, capture_output=True,
                                    text=True, env=self.env, check=True, timeout=10)
            return result.stdout.splitlines()

        reference = parsed(invocation + "\nexit 1\nfi")
        gate_line, failure_exit, gate_end = reference[2:5]

        def assert_unconditional(script):
            lines = parsed(script)
            self.assertEqual(lines.count(gate_line), 1, "missing top-level suite and doctor gate")
            gate = lines.index(gate_line)
            end = lines.index(gate_end, gate + 1)
            self.assertEqual(lines[end - 1], failure_exit, "gate failure must exit nonzero")
            # Reject early successful or unknown exits before the gate or in its
            # failure arm, including inline conditionals rendered by the Bash parser.
            for line in lines[2:end - 1]:
                lexer = shlex.shlex(line, posix=True, punctuation_chars=";&|()")
                lexer.whitespace_split = True
                words = list(lexer)
                for index, word in enumerate(words):
                    if word not in ("exit", "return", "exec"):
                        continue
                    if index and words[index - 1] not in (";", "&&", "||", "|", "(", "then", "else", "!"):
                        continue
                    value = words[index + 1] if index + 1 < len(words) else ""
                    self.assertTrue(word != "exec" and value.isascii() and value.isdecimal()
                                    and 0 < int(value) < 256, "early successful or unknown exit: " + line)

        assert_unconditional(source)
        # Build source mutations from Bash's normalized output, so comments,
        # blank lines, quoting layout and source indentation are irrelevant.
        normal = parsed(source)[2:-2]
        index = normal.index(gate_line)
        end = normal.index(gate_end, index + 1)
        controls = {
            "conditional": [*normal[:index], 'if [[ -z "${OPTIONAL_GATE:-}" ]]; then',
                            *normal[index:end + 1], "fi", *normal[end + 1:]],
            "omitted": [*normal[:index], *normal[end + 1:]],
            "early success on failure": [*normal[:index + 1], '[[ -z "${OPTIONAL_GATE:-}" ]] && exit 0',
                                         *normal[index + 1:]],
        }
        for name, lines in controls.items():
            with self.subTest(control=name), self.assertRaisesRegex(AssertionError, "top-level|early successful"):
                assert_unconditional("\n".join(lines))
        harmless = [*normal[:index], 'extra_note="fixture"', "", *normal[index:]]
        assert_unconditional("\n".join(harmless).replace(" && node", " &&\nnode"))

    def test_bump_registration(self):
        suite = "tests/release-readiness.tests.py"
        catalog = json.loads((ROOT / "tests/verification-catalog.json").read_bytes())
        for suffix, profile in (("sh", "local-posix"), ("ps1", "local-powershell")):
            self.assertIn("tests/bump-version-gate.tests." + suffix, catalog["profiles"][profile])
        entries = {row["path"]: row for row in catalog["suites"]}
        self.assertIn("v2-guardrails", entries[suite]["ci_jobs"])
        parser = runpy.run_path(str(ROOT / "tests/verification-workflow.py"))
        workflow = parser["load_workflow"](ROOT / ".github/workflows/test.yml")
        jobs = workflow["jobs"]
        job = jobs["v2-guardrails"]
        self.assertIn("v2-guardrails", jobs["required-checks"]["needs"])
        self.assertEqual(job["runs-on"], "${{ matrix.os }}")
        self.assertCountEqual([row["os"] for row in parser["matrix_rows"](job)],
                              ["ubuntu-latest", "macos-latest", "windows-latest"])
        self.assertNotIn("if", job)
        self.assertNotIn("continue-on-error", job)
        defaults = dict(workflow.get("defaults", {}).get("run", {}))
        defaults.update(job.get("defaults", {}).get("run", {}))
        # Linux runs the whole public suite. The two workstation runners select its bump test.
        commands = {
            "runner.os == 'Linux'": [f"python3 {suite}"],
            "runner.os != 'Linux'": [
                'if [[ "$RUNNER_OS" == "Windows" ]]; then',
                'SDD_TEST_BASH=$(cygpath -am "${BASH%.exe}.exe")', "export SDD_TEST_BASH",
                'export PATH="${BASH%/*}:$PATH"', "python=python", "else", "python=python3", "fi",
                f'"$python" {suite} ReleaseReadiness.test_bump_stops_before_writing_or_synchronizes_all_files',
            ],
        }
        for condition, expected in commands.items():
            def matches(step):
                lines = [line.strip() for line in step.get("run", "").splitlines()
                         if line.strip() and not line.lstrip().startswith("#")]
                # Standalone diagnostics do not change which Python invocation runs.
                log = r"""(?:echo|printf)(?:\s+(?:'[^']*'|"[^"`]*"|[\w.%=:/-]+))+"""
                lines = [line for line in lines if "$(" in line or not re.fullmatch(log, line)]
                shell = step.get("shell", defaults.get("shell"))
                return (step.get("if") == condition and not step.get("continue-on-error")
                        and step.get("working-directory", defaults.get("working-directory", ".")) == "."
                        and (shell == "bash" or (shell is None and condition == "runner.os == 'Linux'"))
                        and lines == expected)

            active = [step for step in job["steps"] if matches(step)]
            self.assertTrue(active, condition)
            self.assertTrue(matches(dict(active[0], run="echo 'Starting release checks'\n" + active[0]["run"])))
            if condition == "runner.os != 'Linux'":
                literal = active[0]["run"].replace('"$python"', "'$python'")
                self.assertFalse(matches(dict(active[0], run=literal)))
            comment_only = [dict(step, run="# " + expected[-1]) if step in active else step
                            for step in job["steps"]]
            self.assertFalse(any(matches(step) for step in comment_only), condition)

    def check_bump_inventory(self, command, suite):
        self.test_bump_registration()

        def registered(runner):
            result = subprocess.run([*runner, command[-1]], cwd=ROOT, capture_output=True,
                                    text=True, timeout=45)
            return result.returncode == 0 and suite in result.stdout.splitlines()

        self.assertTrue(registered(command[:-1]), suite)
        # Only the executable list result counts, even when runner source mentions the suite.
        stub = write(self.root, "inventory.py",
                     f"# {suite}\nimport sys\nassert sys.argv[3] == {command[-1]!r}\n"
                     "print(sys.argv[2])\nsys.exit(int(sys.argv[1]))\n")
        self.assertTrue(registered([sys.executable, str(stub), "0", suite]))
        for code, output in ((0, ""), (0, suite + ".bak"), (7, suite), (0, "# " + suite)):
            with self.subTest(code=code, output=output):
                self.assertFalse(registered([sys.executable, str(stub), str(code), output]))

    def check_bump_bash_registration(self):
        self.check_bump_inventory([os.environ.get("SDD_TEST_BASH") or "bash", "tests/run-all.sh", "--list"],
                                  "tests/bump-version-gate.tests.sh")

    def check_bump_powershell_registration(self):
        self.check_bump_inventory([shutil.which("pwsh") or "powershell", "-NoProfile", "-File",
                                   "tests/run-all.ps1", "-List"], "tests/bump-version-gate.tests.ps1")

    def test_bump_stops_before_writing_or_synchronizes_all_files(self):
        self.check_bump_gate_source()
        for case in (self.check_bump_green, self.check_bump_first_suite_failure,
                     self.check_bump_last_suite_failure, self.check_bump_doctor_failure,
                     self.check_bump_stale_readme, self.check_bump_missing_helper):
            with self.subTest(case=case.__name__):
                case()

        self.env.pop("FAIL_AT", None)
        self.root = self.root / "readme-and-version-boundaries"
        self.root.mkdir()
        bash = self.prepare_bump()
        write(self.root, "CHANGELOG.md", "## v1.1.0 (fixture)\n")
        surfaces = ["README.md", "mcp/sdd-forge-mcp/src/server.ts"]
        surfaces += [f"plugins/sdd-ship/{name}" for name in (
            ".antigravity-plugin/plugin.json", ".claude-plugin/plugin.json", ".codex-plugin/plugin.json",
            ".plugin/plugin.json", "gemini-extension.json", "gemini/gemini-extension.json")]
        surfaces += [".claude-plugin/marketplace.json", ".agents/plugins/marketplace.json",
                     "mcp/sdd-forge-mcp/package.json"]
        preamble = "# Project\n\nDescription\n\n"
        history = "\n> **v1.0.0**: shipped changes\nv2.1.5 — archived release\nv0.8.0 — archived release\n"

        def release_surfaces(version):
            files = {path: json.dumps({"version": version}) + "\n" for path in surfaces}
            files["README.md"] = preamble + f"v{version} — release\n" + history
            files["mcp/sdd-forge-mcp/src/server.ts"] = f'version: "{version}"\n'
            return files

        before = release_surfaces("1.0.0")
        # An archived heading must never stand in for the current release.
        for heading in ("v0.9.0 — stale release", "v1.0.0-rc.1 — prerelease",
                        "v1.0.0+build.2 — build", "v1.0.0 - wrong separator",
                        preamble + "\nv1.0.0 — line six"):
            with self.subTest(heading=heading):
                stale_readme = heading + "\nv1.0.0 — archived release\n"
                fixture = {**before, "README.md": stale_readme}
                for path, content in fixture.items():
                    write(self.root, path, content)
                output = self.run_cli([bash, "scripts/bump-version.sh", "1.1.0"], False)
                self.assertIn("README.md current release does not match 1.0.0", output)
                for path, content in fixture.items():
                    self.assertEqual((self.root / path).read_bytes(), content.encode("utf-8"), path)
        # The replacement can contain the previous version's digits at either end.
        for new_version in ("2.1.50", "12.1.5"):
            with self.subTest(new_version=new_version):
                for path, content in release_surfaces("2.1.5").items():
                    write(self.root, path, content)
                write(self.root, "CHANGELOG.md", f"## v{new_version} (fixture)\n")
                self.run_cli([bash, "scripts/bump-version.sh", new_version])
                for path, content in release_surfaces(new_version).items():
                    self.assertEqual((self.root / path).read_bytes(), content.encode("utf-8"), path)

        # A separate full old-version reference on a release surface still fails verification.
        files = release_surfaces("2.1.5")
        source = "mcp/sdd-forge-mcp/src/server.ts"
        files[source] += 'const stale = "2.1.5";\n'
        for path, content in files.items():
            write(self.root, path, content)
        write(self.root, "CHANGELOG.md", "## v2.1.50 (fixture)\n")
        out = self.run_cli([bash, "scripts/bump-version.sh", "2.1.50"], False)
        self.assertEqual([line for line in out.splitlines() if line.startswith("WARNING:")],
                         [f"WARNING: stale 2.1.5 reference remains in: {source}"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
