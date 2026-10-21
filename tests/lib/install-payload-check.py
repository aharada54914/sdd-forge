#!/usr/bin/env python3
"""Black-box payload checks for the real installers (install-payload.txt), one runtime per run.

    install-payload-check.py --runtime bash|powershell [--repo-root DIR] [unittest options]

Runs install.sh (bash) or install.ps1 (pwsh) as exact-argv subprocesses, no shell, against a bounded
Git fixture in both source modes: local (--source-directory) and archive (the production remote
branch, fed by a synthetic tar.gz plus gh/curl or Invoke-WebRequest doubles). Nothing touches the
network, real accounts or CLI registrations: -Target FilesOnly, a private HOME, a scrubbed environment.

The fixture is the repository's runtime files (working-tree bytes of tracked and not-yet-committed
files; never the specs/reports/tests archive) plus FAKE development content. install-payload.txt is
carried only when the source has it, so a tree without the manifest still gets a real install and
fails on the leaked development content, not on the missing file. The manifest-required contract is
a separate test.

Env: PWSH  pwsh executable (default: pwsh from PATH).
"""

import argparse
import contextlib
import hashlib
import io
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import unittest
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]  # <repo>/tests/lib/<this file>
TIMEOUT = 900
MANIFEST = "install-payload.txt"
MCP = ["sdd-forge-mcp", "local-env-mcp", "ci-mcp"]
RUNTIME_DIRS = (".agents/", ".claude-plugin/", ".codex/agents/", "plugins/", "contracts/",
                "templates/cloud/", "skills/adversarial-review/")
EXCLUDED = frozenset([".git", "node_modules", "__pycache__", ".pytest_cache", ".mypy_cache",
                      ".ruff_cache", ".cache", ".venv", ".private", ".learnings", ".DS_Store"])

# Runtime closure the installed product needs, whatever the manifest says.
CLOSURE = [
    ".agents/plugins/marketplace.json", ".claude-plugin/marketplace.json",
    ".codex/agents/sdd-investigator.toml", ".codex/agents/sdd-evaluator.toml",
    "plugins/sdd-implementation/scripts/managed-model-entry.py",
    "plugins/sdd-implementation/scripts/model-policy.py",
    "plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py",
    "contracts/agent-model-capabilities.v2.json", "contracts/model-policy.v1.json",
    "contracts/model-launch-controls.schema.json",
]

# Tracked development content that must never be installed (every value is FAKE).
TRACKED_SEEDS = {
    "specs/fake/private.txt": "FAKE development spec\n",
    'docs/contributor/release-runbook.md': "FAKE repository-only development document\n",
    'docs/contributor/weekly-local-codex-audit.md': "FAKE repository-only development document\n",
    'docs/contributor/self-improvement-measurement-proposal.md': "FAKE repository-only development document\n",
    'docs/contributor/shared-file-mirrors.md': "FAKE repository-only development document\n",
    'docs/workflow-improvements/retention-checklist.md': "FAKE repository-only development document\n",
    'skills/adversarial-review/SKILL.md': "FAKE repository-only development document\n",

    "reports/review-context/identity-ledger.json": '{"reviewer": "FAKE-IDENTITY-LEDGER-VALUE"}\n',
    "tests/private.txt": "FAKE test data\n",
    ".github/workflows/private.yml": "name: FAKE\n",
    ".learnings/private.txt": "FAKE learning\n",
    "AGENTS.md": "FAKE root agent instructions\n",
    "unlisted-root-file.txt": "FAKE unlisted\n",
    "docs/unlisted-dev-note.md": "FAKE unlisted doc\n",
    "templates/other/unlisted.txt": "FAKE unlisted template\n",
    "skills/other-skill/SKILL.md": "FAKE unlisted skill\n",
    "scripts/dev-only.sh": "#!/bin/sh\necho FAKE\n",
}
UNTRACKED_SEEDS = {
    ".private/secret.txt": "FAKE secret\n",
    "plugins/sdd-bootstrap/untracked-private.txt": "FAKE untracked plugin file\n",
}
LEAK_PATHS = (list(TRACKED_SEEDS) + list(UNTRACKED_SEEDS) + ["tests/fixtures/dangling-link"]
              + [f"mcp/{n}/{rest}" for n in MCP for rest in ("src/index.ts", "tests/index.test.ts")])
# Junk a real archive (or an unclean tree) can carry below admitted directories.
ARCHIVE_JUNK = {
    ".git/config": "[core]\n",
    "plugins/sdd-bootstrap/.git/config": "[core]\n",
    "plugins/sdd-bootstrap/node_modules/dep/index.js": "FAKE\n",
    "plugins/sdd-bootstrap/__pycache__/x.cpython-312.pyc": "FAKE\n",
    "plugins/sdd-bootstrap/stray.pyc": "FAKE\n",
    "plugins/sdd-bootstrap/.private/secret.txt": "FAKE secret\n",
    ".private/secret.txt": "FAKE secret\n",
}
INVALID_ENTRIES = ["../escape.txt", "/etc/passwd", "docs\\THREAT-MODEL.md", "docs/*.md", "./README.md",
                   "plugins//x", "plugins/./x", "docs/..", "C:/x", "docs/a b.md"]

GIT_ENV = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1", GIT_TERMINAL_PROMPT="0")
GIT_ID = ["-c", "user.name=Installer Payload Test", "-c", "user.email=installer-payload@example.invalid"]
SCRUBBED_ENV = ("GH_TOKEN", "GITHUB_TOKEN", "GH_READONLY_TOKEN", "CI_MCP_GITHUB_TOKEN", "PYTHONPATH")
TEST_TOKEN = "payload-test-token"  # literal test value, not a credential
ARCHIVE_URL = "https://api.github.com/repos/aharada54914/sdd-forge/tarball/main"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def rmtree(path):
    def onerror(func, p, _exc):
        with contextlib.suppress(OSError):
            os.chmod(p, stat.S_IRWXU)
            func(p)

    shutil.rmtree(path, onerror=onerror)


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(argv, *, cwd=None, env=None):
    return subprocess.run(argv, cwd=cwd, env=env, capture_output=True, text=True, errors="replace",
                          timeout=TIMEOUT)


def git(cwd, *args):
    result = run(["git", *args], cwd=cwd, env=GIT_ENV)
    if result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed in {cwd}: {result.stderr!r}")
    return result


def describe(result):
    return (f"argv: {result.args}\nexit: {result.returncode}\n"
            f"stdout:\n{result.stdout[-3000:]}\nstderr:\n{result.stderr[-3000:]}")


def clean(rel):
    return not (set(rel.split("/")) & EXCLUDED) and not rel.endswith((".pyc", ".pyo"))


def admitted(rel, entries):
    return clean(rel) and any(rel == e or (e.endswith("/") and rel.startswith(e)) for e in entries)


def installed_files(root):
    """posix path -> sha256, or 'SYMLINK'. Directories are not listed."""
    found = {}
    for dirpath, dirnames, filenames in os.walk(root):
        for name in dirnames + filenames:
            full = os.path.join(dirpath, name)
            rel = Path(full).relative_to(root).as_posix()
            if os.path.islink(full):
                found[rel] = "SYMLINK"
            elif os.path.isfile(full):
                found[rel] = sha256(full)
    return found


def scenario_env(tmp):
    home = tmp / "home"
    home.mkdir(exist_ok=True)
    env = {k: v for k, v in os.environ.items() if k not in SCRUBBED_ENV}
    env.update(HOME=str(home), XDG_DATA_HOME=str(tmp / "xdg-data"), SDD_CODEX_HOME=str(home / ".codex"),
               SDD_CURSOR_DIR=str(home / "cursor-not-installed"),
               SDD_VSCODE_USER_DIR=str(home / "vscode-not-installed"), SDD_INSTALL_LOCK_TIMEOUT="60",
               PYTHONDONTWRITEBYTECODE="1", GIT_TERMINAL_PROMPT="0")
    return env


def node_ok():
    try:
        out = run(["node", "--version"]).stdout.strip()
    except OSError:
        return False
    match = re.fullmatch(r"v?(\d+)\.(\d+)\.(\d+)", out)
    return bool(match) and tuple(map(int, match.groups())) >= (22, 19, 0)


def symlinks_ok():
    with tempfile.TemporaryDirectory(prefix="sdd-payload-probe-") as probe:
        try:
            os.symlink("target", os.path.join(probe, "link"))
            return True
        except (OSError, NotImplementedError):
            return False


# ---------------------------------------------------------------------------
# Source fixture
# ---------------------------------------------------------------------------
class Fixture:
    """Bounded runtime copy of the repository + FAKE development content, as a Git worktree."""

    def __init__(self, repo):
        self.base = Path(tempfile.mkdtemp(prefix="sdd-payload-fixture-"))
        self.path, self.outside = self.base / "source", self.base / "outside"
        self.symlinks = symlinks_ok()
        self._archives = {}
        self._build(repo)
        self.tracked = [rel for rel in self.git("ls-files", "-z").stdout.split("\0") if rel]
        self.has_manifest = (self.path / MANIFEST).is_file()
        entries = self.entries()
        self.expected = None if not self.has_manifest else {
            rel: sha256(self.path / rel) for rel in self.tracked
            if (self.path / rel).is_file() and not (self.path / rel).is_symlink() and admitted(rel, entries)}

    def close(self):
        rmtree(self.base)

    def git(self, *args):
        return git(self.path, *args)

    def write(self, rel, text):
        target = self.path / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")

    def entries(self):
        if not self.has_manifest:
            return []
        lines = (self.path / MANIFEST).read_text(encoding="utf-8").splitlines()
        return [line.strip() for line in lines if line.strip() and not line.strip().startswith("#")]

    def _build(self, repo):
        self.outside.mkdir(parents=True)
        (self.outside / "secret.txt").write_text("FAKE outside secret\n")
        self.path.mkdir()
        listing = git(repo, "ls-files", "-z", "--cached", "--others", "--exclude-standard").stdout.split("\0")
        for rel in sorted({r for r in listing if r}):
            src = repo / rel
            if ("/" not in rel or rel.startswith(RUNTIME_DIRS)) and clean(rel) \
                    and src.is_file() and not src.is_symlink():
                (self.path / rel).parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, self.path / rel)
        if (repo / MANIFEST).is_file():  # the candidate policy may precede the product commit
            shutil.copy2(repo / MANIFEST, self.path / MANIFEST)

        forced = list(TRACKED_SEEDS)
        for rel, text in TRACKED_SEEDS.items():
            self.write(rel, text)
        for name in MCP:
            for rest in ("src/index.ts", "tests/index.test.ts"):
                self.write(f"mcp/{name}/{rest}", "FAKE mcp source\n")
                forced.append(f"mcp/{name}/{rest}")
        if self.symlinks:
            link = self.path / "tests/fixtures/dangling-link"
            link.parent.mkdir(parents=True, exist_ok=True)
            os.symlink("../../../outside/nowhere", link)
            forced.append("tests/fixtures/dangling-link")
        self.git("init", "-q")
        for key, value in (("core.longpaths", "true"), ("gc.auto", "0"), ("gc.autoDetach", "false"),
                           ("maintenance.auto", "false"), ("core.autocrlf", "false"), ("commit.gpgsign", "false")):
            self.git("config", key, value)
        self.git("add", "-A")
        self.git("add", "-f", "--", *forced)
        self.git(*GIT_ID, "commit", "-q", "-m", "Payload fixture baseline")

        # Untracked noise, MCP bundles with a poisoned dist/, and an uncommitted edit to a tracked file.
        for rel, text in UNTRACKED_SEEDS.items():
            self.write(rel, text)
        for name in MCP:
            self.write(f"mcp/{name}/dist/index.js", f'#!/usr/bin/env node\nconsole.log("{name} fixture");\n')
            self.write(f"mcp/{name}/package.json", json.dumps({"name": name, "version": "0.0.0"}) + "\n")
            self.write(f"mcp/{name}/dist/debug.log", "arbitrary dist debug file\n")
            self.write(f"mcp/{name}/dist/nested/extra.js", "extra\n")
            self.write(f"mcp/{name}/node_modules/dep/index.js", "noise\n")
        if (self.path / "README.md").is_file():
            with open(self.path / "README.md", "a", encoding="utf-8") as handle:
                handle.write("\n<!-- uncommitted working-tree edit -->\n")

    def mcp_expected(self, name):
        return {f"mcp/{name}/{rest}": sha256(self.path / f"mcp/{name}/{rest}")
                for rest in ("dist/index.js", "package.json")}

    def archive(self, omit=(), symlinks=()):
        """Synthetic GitHub tar.gz: tracked bytes + mcp tree + junk + a stray symlink."""
        key = (tuple(sorted(omit)), tuple(symlinks))
        if key in self._archives:
            return self._archives[key]
        dest, top = self.base / f"archive-{len(self._archives)}.tar.gz", "aharada54914-sdd-forge-0123abc"

        def link(tar, rel, target):
            info = tarfile.TarInfo(f"{top}/{rel}")
            info.type, info.linkname = tarfile.SYMTYPE, target
            tar.addfile(info)

        with tarfile.open(dest, "w:gz") as tar:
            added = set()
            for rel in self.tracked:
                src = self.path / rel
                if rel not in omit and src.is_file() and not src.is_symlink():
                    tar.add(str(src), arcname=f"{top}/{rel}", recursive=False)
                    added.add(rel)
            for dirpath, _dirs, files in os.walk(self.path / "mcp"):
                for name in files:
                    full = Path(dirpath, name)
                    rel = full.relative_to(self.path).as_posix()
                    if rel not in omit and rel not in added:
                        tar.add(str(full), arcname=f"{top}/{rel}", recursive=False)
            for rel, text in ARCHIVE_JUNK.items():
                data, info = text.encode(), tarfile.TarInfo(f"{top}/{rel}")
                info.size = len(data)
                tar.addfile(info, io.BytesIO(data))
            for rel, target in symlinks:
                link(tar, rel, target)
        self._archives[key] = dest
        return dest


def windows_zip_archive(archive, destination):
    """Keep fixture bytes and Unix link metadata in the Windows transport format."""
    with tarfile.open(archive) as source, zipfile.ZipFile(destination, "w") as target:
        for member in source:
            item = zipfile.ZipInfo(member.name + ("/" if member.isdir() else ""))
            item.create_system = 3
            kind = stat.S_IFLNK if member.issym() else (stat.S_IFDIR if member.isdir() else stat.S_IFREG)
            item.external_attr = (kind | member.mode) << 16
            if member.isdir():
                data = b""
            elif member.issym():
                data = member.linkname.encode("utf-8")
            elif member.isfile():
                with source.extractfile(member) as content:
                    data = content.read()
            else:
                raise ValueError("Unsupported fixture archive entry: " + member.name)
            target.writestr(item, data)
    return destination


@contextlib.contextmanager
def manifest_bytes(fixture, data):
    """Temporarily replace (None: remove) the fixture's working-tree manifest."""
    path = fixture.path / MANIFEST
    original = path.read_bytes() if path.exists() else None
    try:
        path.unlink(missing_ok=True) if data is None else path.write_bytes(data)
        yield original
    finally:
        path.unlink(missing_ok=True) if original is None else path.write_bytes(original)


# ---------------------------------------------------------------------------
# Runners: how each real installer is invoked
# ---------------------------------------------------------------------------
class Bash:
    def unavailable(self):
        return None if shutil.which("bash") else "bash was not found"

    def install(self, tmp, root, *, source=None, archive=None, skip_mcp=False, mcp=(), plugins=()):
        argv = [shutil.which("bash"), str(REPO / "install.sh"), "--install-root", str(root),
                "--target", "FilesOnly", "--skip-plugin-install", "--skip-agent-install"]
        argv += ["--source-directory", str(source)] if source else []
        argv += ["--skip-mcp"] if skip_mcp else []
        argv += ["--mcp", ",".join(mcp)] if mcp else []
        argv += ["--plugins", ",".join(plugins)] if plugins else []
        env = scenario_env(tmp)
        if archive:
            stubs = tmp / "stubs"
            stubs.mkdir(exist_ok=True)
            (stubs / "gh").write_text(
                "#!/bin/sh\n"
                'if [ "$1" = "auth" ] && [ "$2" = "token" ]; then printf \'%s\\n\' \'' + TEST_TOKEN + "'; exit 0; fi\n"
                'echo "unexpected gh invocation: $*" >&2; exit 2\n')
            (stubs / "curl").write_text(
                "#!/bin/sh\n"
                'out=""; url=""\n'
                "while [ $# -gt 0 ]; do\n"
                '  case "$1" in\n'
                '    -o) out="$2"; shift 2 ;;\n'
                "    --config) shift 2 ;;\n"
                "    -*) shift ;;\n"
                '    *) url="$1"; shift ;;\n'
                "  esac\n"
                "done\n"
                'config="$(cat)"\n'
                'case "$url" in ' + ARCHIVE_URL + ') ;; *) echo "unexpected url: $url" >&2; exit 22 ;; esac\n'
                'case "$config" in *"Bearer ' + TEST_TOKEN + '"*) ;; *) echo "unexpected auth config" >&2; exit 22 ;; esac\n'
                'cp "$PAYLOAD_TEST_ARCHIVE" "$out"\n')
            for stub in ("gh", "curl"):
                (stubs / stub).chmod(0o755)
            env["PATH"] = str(stubs) + os.pathsep + env.get("PATH", "")
            env["PAYLOAD_TEST_ARCHIVE"] = str(archive)
        return run(argv, cwd=str(tmp), env=env)


class PowerShell:
    WRAPPER = (
        "$ErrorActionPreference = 'Stop'\n"
        "function global:Invoke-WebRequest {\n"
        "    param([string]$Uri, $Headers, [string]$OutFile)\n"
        f"    if ($Uri -ne '{ARCHIVE_URL.replace('/tarball/', '/zipball/') if os.name == 'nt' else ARCHIVE_URL}') {{ throw \"Unexpected download URI: $Uri\" }}\n"
        f"    if ($Headers['Authorization'] -ne 'Bearer {TEST_TOKEN}') {{ throw 'Unexpected authorization header' }}\n"
        "    Copy-Item -LiteralPath $env:PAYLOAD_TEST_ARCHIVE -Destination $OutFile -Force\n"
        "}\n"
        "$params = @{}\n"
        "foreach ($property in (ConvertFrom-Json $env:PAYLOAD_TEST_PARAMS).PSObject.Properties) { $params[$property.Name] = $property.Value }\n"
        "& $env:PAYLOAD_TEST_INSTALLER @params\n"
        "exit 0\n")

    def __init__(self):
        self.pwsh = os.environ.get("PWSH") or shutil.which("pwsh")

    def unavailable(self):
        return None if self.pwsh else "pwsh was not found (install PowerShell or set PWSH)"

    def install(self, tmp, root, *, source=None, archive=None, skip_mcp=False, mcp=(), plugins=()):
        base = [self.pwsh, "-NoLogo", "-NoProfile", "-NonInteractive", "-File"]
        installer, env = str(REPO / "install.ps1"), scenario_env(tmp)
        if archive:
            if os.name == "nt" and not zipfile.is_zipfile(archive):
                archive = windows_zip_archive(archive, tmp / "source.zip")
            params = {"InstallRoot": str(root), "Target": "FilesOnly", "SkipPluginInstall": True,
                      "SkipAgentInstall": True, **({"SkipMcp": True} if skip_mcp else {}),
                      **({"Mcp": list(mcp)} if mcp else {}), **({"Plugins": list(plugins)} if plugins else {})}
            wrapper = tmp / "archive-wrapper.ps1"
            wrapper.write_text(self.WRAPPER)
            env.update(GH_TOKEN=TEST_TOKEN, PAYLOAD_TEST_ARCHIVE=str(archive), PAYLOAD_TEST_INSTALLER=installer,
                       PAYLOAD_TEST_PARAMS=json.dumps(params))
            return run(base + [str(wrapper)], cwd=str(tmp), env=env)
        argv = base + [installer, "-InstallRoot", str(root), "-Target", "FilesOnly",
                       "-SkipPluginInstall", "-SkipAgentInstall"]
        argv += ["-SourceDirectory", str(source)] if source else []
        argv += ["-SkipMcp"] if skip_mcp else []
        for name in mcp:  # -File passes one value per use; tests select one MCP at a time
            argv += ["-Mcp", name]
        for name in plugins:
            argv += ["-Plugins", name]
        return run(argv, cwd=str(tmp), env=env)


# ---------------------------------------------------------------------------
# Scenarios
# ---------------------------------------------------------------------------
class PayloadChecks(unittest.TestCase):
    runner = None  # set by main()

    @classmethod
    def setUpClass(cls):
        reason = cls.runner.unavailable()
        if reason:
            raise unittest.SkipTest(reason)
        cls.fx = Fixture(REPO)
        cls.addClassCleanup(cls.fx.close)
        cls.has_node = node_ok()

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="sdd-payload-run-"))
        self.addCleanup(rmtree, self.tmp)

    def root_for(self, label):
        return self.tmp / label / "sdd-plugins"

    def install(self, root, **kwargs):
        return self.runner.install(self.tmp, root, **kwargs)

    def install_ok(self, root, **kwargs):
        result = self.install(root, **kwargs)
        self.assertEqual(result.returncode, 0, describe(result))
        return result

    def install_fails(self, root, **kwargs):
        result = self.install(root, **kwargs)
        self.assertNotEqual(result.returncode, 0, "installer unexpectedly succeeded\n" + describe(result))
        return result

    def sources(self):
        return (("local", {"source": self.fx.path}), ("archive", {"archive": self.fx.archive()}))

    def assert_no_residue(self, root):
        leftover = set(os.listdir(root.parent)) - {root.name}
        self.assertEqual(leftover, set(), f"staging/backup/lock residue next to the install root: {leftover}")

    def assert_previous_intact(self, root):
        self.assertTrue((root / "previous-install-marker.txt").is_file(), "failed install must leave the previous install intact")
        self.assert_no_residue(root)

    def precreate_install(self, root):
        for rel, text in {
            "previous-install-marker.txt": "previous install\n",
            "specs/old-spec/spec.md": "formerly distributed spec\n",
            "reports/review-context/identity-ledger.json": '{"reviewer": "FAKE-OLD-LEDGER"}\n',
            "tests/old-test.txt": "formerly distributed test\n",
            ".github/workflows/old.yml": "name: FAKE-OLD\n",
            "mcp/sdd-forge-mcp/dist/debug.log": "formerly distributed debug file\n",
            "plugins/sdd-bootstrap/stale-only-in-old-install.txt": "stale\n",
        }.items():
            (root / rel).parent.mkdir(parents=True, exist_ok=True)
            (root / rel).write_text(text)

    def assert_payload(self, root, mcp=()):
        leaked = [rel for rel in LEAK_PATHS if os.path.lexists(root / rel)]
        self.assertEqual(leaked, [], "development payload leaked into the install")
        actual = installed_files(root)
        want_mcp = {k: v for name in mcp for k, v in self.fx.mcp_expected(name).items()}
        self.assertEqual({k: v for k, v in actual.items() if k.startswith("mcp/")}, want_mcp,
                         "mcp/ must hold exactly dist/index.js and package.json of the selected servers")
        rest = {k: v for k, v in actual.items() if not k.startswith("mcp/")}
        self.assertEqual([rel for rel in CLOSURE if rel not in rest], [], "runtime closure missing from the install")
        if self.fx.expected is None:  # no manifest in the source: installed bytes must still be source bytes
            changed = [k for k, v in rest.items() if not (self.fx.path / k).is_file() or sha256(self.fx.path / k) != v]
            self.assertEqual(changed, [], "installed files differ from the source")
        else:
            want = self.fx.expected
            diff = (sorted(set(rest) - set(want))[:10], sorted(set(want) - set(rest))[:10],
                    sorted(k for k in set(rest) & set(want) if rest[k] != want[k])[:10])
            self.assertEqual(diff, ([], [], []), "installed set differs from the manifest (unexpected, missing, changed)")

    def assert_entry_parses(self, root):
        # managed-model-entry.py has no --help: the unknown flag is a closed model-policy-error/v1 (exit 2).
        script = root / "plugins/sdd-implementation/scripts/managed-model-entry.py"
        result = run([sys.executable, "-I", str(script), "--help"], cwd=str(self.tmp), env=scenario_env(self.tmp))
        self.assertEqual(result.returncode, 2, describe(result))
        self.assertEqual(json.loads(result.stderr.strip().splitlines()[-1])["schema"], "model-policy-error/v1")

    def test_local_source_installs_only_the_payload(self):
        root = self.root_for("default")
        self.install_ok(root, source=self.fx.path, skip_mcp=True)
        self.assert_payload(root)
        self.assert_no_residue(root)
        self.assert_entry_parses(root)
        narrow = self.root_for("one-plugin")  # --plugins selects registration, never what is copied
        self.install_ok(narrow, source=self.fx.path, skip_mcp=True, plugins=["sdd-lite"])
        self.assert_payload(narrow)

    def test_archive_source_installs_the_same_payload(self):
        root = self.root_for("archive")
        self.install_ok(root, archive=self.fx.archive(), skip_mcp=True)
        self.assert_payload(root)
        self.assert_no_residue(root)
        self.assert_entry_parses(root)

    def test_mcp_placement_is_exactly_index_and_package(self):
        skipped = self.root_for("skip-mcp")
        self.install_ok(skipped, source=self.fx.path, skip_mcp=True)
        self.assertFalse((skipped / "mcp").exists(), "--skip-mcp must place nothing under mcp/")
        if not self.has_node:
            gated = self.root_for("no-node")
            self.install_ok(gated, source=self.fx.path)
            self.assertFalse((gated / "mcp").exists(), "the Node >= 22.19.0 gate must skip MCP placement")
            self.skipTest("Node.js >= 22.19.0 is required to exercise MCP placement")
        for label, kwargs in self.sources():
            with self.subTest(source=label):
                root = self.root_for(f"mcp-{label}")
                self.install_ok(root, **kwargs)
                self.assert_payload(root, mcp=MCP)
        selected = self.root_for("mcp-selected")
        self.install_ok(selected, source=self.fx.path, mcp=["local-env-mcp"])
        self.assert_payload(selected, mcp=["local-env-mcp"])

    def test_upgrade_removes_formerly_distributed_development_payload(self):
        for label, kwargs in self.sources():
            with self.subTest(source=label):
                root = self.root_for(f"upgrade-{label}")
                self.precreate_install(root)
                self.install_ok(root, skip_mcp=True, **kwargs)
                for rel in ("previous-install-marker.txt", "specs", "reports", "tests", ".github", "mcp",
                            "plugins/sdd-bootstrap/stale-only-in-old-install.txt"):
                    self.assertFalse(os.path.lexists(root / rel), f"upgrade kept formerly distributed content: {rel}")
                self.assert_payload(root)
                self.assert_no_residue(root)

    def test_symlink_in_admitted_path_is_refused_and_rolled_back(self):
        if not self.fx.symlinks:
            self.skipTest("this platform/user cannot create symlinks")
        rel, link = "plugins/sdd-bootstrap/escape-link.txt", self.fx.path / "plugins/sdd-bootstrap/escape-link.txt"
        os.symlink(self.fx.outside / "secret.txt", link)
        self.fx.git("add", "-f", "--", rel)
        try:
            root = self.root_for("symlink-local")
            self.precreate_install(root)
            result = self.install_fails(root, source=self.fx.path, skip_mcp=True)
            self.assertRegex(result.stdout + result.stderr, r"(?i)symlink")
            self.assertFalse((root / rel).exists())
            self.assert_previous_intact(root)
        finally:
            self.fx.git("rm", "--cached", "-q", "-f", "--", rel)
            link.unlink()
        root = self.root_for("symlink-archive")
        self.precreate_install(root)
        result = self.install_fails(root, archive=self.fx.archive(symlinks=[(rel, "../../../outside/secret.txt")]),
                                    skip_mcp=True)
        self.assertRegex(result.stdout + result.stderr, r"(?i)symlink")
        self.assert_previous_intact(root)

    def test_tracked_special_names_survive_local_and_archive(self):
        # A >100-byte basename also exercises the Git PAX boundary on tar platforms.
        names = ["日本語.txt", "日本語" * 12 + ".txt"]
        if os.name != "nt":
            names += ['quoted"name.txt', "tab\tname.txt"]
        paths = ["plugins/sdd-bootstrap/" + name for name in names]
        self.fx.git("config", "core.quotePath", "true")
        for rel in paths:
            (self.fx.path / rel).write_bytes(b"tracked UTF-8 payload\n")
        self.fx.git("add", "--", *paths)
        try:
            # Match the Git archive producer: Python PAX encodes even short Unicode
            # names differently, exercising native tar charset handling instead.
            archive_format = "zip" if os.name == "nt" and isinstance(self.runner, PowerShell) else "tar.gz"
            archive = self.fx.base / ("special-names." + archive_format)
            tree = self.fx.git("write-tree").stdout.strip()
            self.fx.git("archive", "--format=" + archive_format, "--prefix=aharada54914-sdd-forge-0123abc/",
                        "--output=" + str(archive), tree)
            for label, kwargs in (("local", {"source": self.fx.path}),
                                  ("archive", {"archive": archive})):
                root = self.root_for("names-" + label)
                self.install_ok(root, skip_mcp=True, **kwargs)
                for rel in paths:
                    with self.subTest(source=label, path=rel):
                        self.assertTrue((root / rel).is_file(),
                                        f"{rel}; installed siblings: {sorted(p.name for p in (root / rel).parent.iterdir())}")
                        self.assertEqual((root / rel).read_bytes(), (self.fx.path / rel).read_bytes())
        finally:
            self.fx.git("rm", "--cached", "-q", "--", *paths)
            for rel in paths:
                (self.fx.path / rel).unlink()

    def test_windows_zip_metadata_and_containment(self):
        if os.name != "nt" or not isinstance(self.runner, PowerShell):
            self.skipTest("Windows PowerShell ZIP transport")
        for label, rel in (("file", "plugins/sdd-bootstrap/link.txt"),
                           ("parent", "plugins/sdd-bootstrap/linked")):
            with self.subTest(link=label):
                root = self.root_for("zip-link-" + label)
                self.precreate_install(root)
                archive = self.fx.archive(symlinks=[(rel, "../../../outside/secret.txt")])
                result = self.install_fails(root, archive=archive, skip_mcp=True)
                self.assertRegex(result.stdout + result.stderr, r"(?i)symlink")
                self.assert_previous_intact(root)
        root = self.root_for("zip-ignored-link")
        self.install_ok(root, archive=self.fx.archive(symlinks=[("tests/ignored-link", "../../outside/secret.txt")]),
                        skip_mcp=True)
        self.assert_payload(root)
        if self.has_node:
            rel = "mcp/local-env-mcp/dist/index.js"
            root = self.root_for("zip-mcp-link")
            self.install_ok(root, archive=self.fx.archive(omit=[rel], symlinks=[(rel, "../../../outside/secret.txt")]),
                            mcp=["local-env-mcp"])
            self.assertFalse((root / "mcp/local-env-mcp").exists())
        archive = windows_zip_archive(self.fx.archive(), self.tmp / "linked-parent.zip")
        with zipfile.ZipFile(archive, "a") as target:
            parent = "aharada54914-sdd-forge-0123abc/plugins/sdd-bootstrap/linked"
            link = zipfile.ZipInfo(parent)
            link.create_system, link.external_attr = 3, (stat.S_IFLNK | 0o777) << 16
            target.writestr(link, "../../../outside")
            target.writestr(parent + "/child.txt", b"must not escape via link parent")
        root = self.root_for("zip-link-descendant")
        self.precreate_install(root)
        self.install_fails(root, archive=archive, skip_mcp=True)
        self.assert_previous_intact(root)
        for index, name in enumerate(("../escaped.txt", "/escaped.txt", "C:/escaped.txt",
                                      "top/plugins/sdd-bootstrap/ads.txt:stream", r"top\plugins\aliased.txt",
                                      "aharada54914-sdd-forge-0123abc/README.md",
                                      "aharada54914-sdd-forge-0123abc/readme.md")):
            with self.subTest(unsafe_name=name):
                archive = windows_zip_archive(self.fx.archive(), self.tmp / f"unsafe-{index}.zip")
                with zipfile.ZipFile(archive, "a") as target:
                    target.writestr(name, b"untrusted fixture bytes")
                root = self.root_for("zip-unsafe-" + str(index))
                self.precreate_install(root)
                self.install_fails(root, archive=archive, skip_mcp=True)
                self.assert_previous_intact(root)

    def test_windows_zip_directory_link_metadata(self):
        if os.name != "nt" or not isinstance(self.runner, PowerShell):
            self.skipTest("Windows PowerShell ZIP transport")
        top = "aharada54914-sdd-forge-0123abc/"
        for label, relative in (("admitted-parent", "plugins/sdd-bootstrap/linked/"), ("source-root", "")):
            with self.subTest(link=label):
                archive = windows_zip_archive(self.fx.archive(), self.tmp / (label + ".zip"))
                with zipfile.ZipFile(archive, "a") as target:
                    link = zipfile.ZipInfo(top + relative)
                    link.create_system, link.external_attr = 3, (stat.S_IFLNK | 0o777) << 16
                    target.writestr(link, b"")
                    if relative:
                        target.writestr(top + relative + "child.txt", b"must not admit link descendants")
                root = self.root_for("zip-dir-link-" + label)
                self.precreate_install(root)
                result = self.install_fails(root, archive=archive, skip_mcp=True)
                self.assertRegex(result.stdout + result.stderr, r"(?i)symlink")
                self.assert_previous_intact(root)
        if self.has_node:
            archive = windows_zip_archive(self.fx.archive(), self.tmp / "mcp-dir-link.zip")
            with zipfile.ZipFile(archive, "a") as target:
                link = zipfile.ZipInfo(top + "mcp/local-env-mcp/dist/")
                link.create_system, link.external_attr = 3, (stat.S_IFLNK | 0o777) << 16
                target.writestr(link, b"")
            root = self.root_for("zip-mcp-dir-link")
            self.install_ok(root, archive=archive, mcp=["local-env-mcp"])
            self.assertFalse((root / "mcp/local-env-mcp").exists())

    def test_core_required_files_fail_closed(self):
        paths = ["plugins/" + plugin + "/.claude-plugin/plugin.json"
                 for plugin in ("sdd-bootstrap", "sdd-implementation", "sdd-quality-loop", "sdd-lite")]
        paths += ["plugins/sdd-bootstrap/skills/bootstrap/SKILL.md", "plugins/sdd-ship/skills/ship/SKILL.md"]
        for index, rel in enumerate(paths):
            path = self.fx.path / rel
            original = path.read_bytes()
            archive = self.fx.archive(omit=[rel])
            try:
                path.unlink()
                for label, kwargs in (("local", {"source": self.fx.path}), ("archive", {"archive": archive})):
                    with self.subTest(path=rel, source=label):
                        root = self.root_for(f"required-{index}-{label}")
                        self.precreate_install(root)
                        self.install_fails(root, skip_mcp=True, **kwargs)
                        self.assert_previous_intact(root)
            finally:
                path.write_bytes(original)

    def test_manifest_is_required(self):
        # Separate contract: a tree without the manifest must fail the install and keep the old one.
        for label, kwargs in (("local-removed", {"source": self.fx.path}),
                              ("archive", {"archive": self.fx.archive(omit=[MANIFEST])})):
            with self.subTest(case=label), manifest_bytes(self.fx, None):
                root = self.root_for(f"no-manifest-{label}")
                self.precreate_install(root)
                self.install_fails(root, skip_mcp=True, **kwargs)
                self.assert_previous_intact(root)

    def test_manifest_entries_are_validated_and_crlf_accepted(self):
        if not self.fx.has_manifest:
            self.skipTest("source has no install-payload.txt")
        original = (self.fx.path / MANIFEST).read_bytes()
        for entry in INVALID_ENTRIES:
            with self.subTest(invalid_entry=entry), manifest_bytes(self.fx, original + b"\n" + entry.encode() + b"\n"):
                root = self.root_for("invalid-" + re.sub(r"\W", "_", entry))
                self.precreate_install(root)
                result = self.install_fails(root, source=self.fx.path, skip_mcp=True)
                self.assertIn(MANIFEST, result.stdout + result.stderr)
                self.assert_previous_intact(root)
        with self.subTest(case="manifest present but not Git-tracked"):
            root = self.root_for("untracked-manifest")
            self.precreate_install(root)
            self.fx.git("rm", "--cached", "-q", "--", MANIFEST)
            try:
                self.install_fails(root, source=self.fx.path, skip_mcp=True)
            finally:
                self.fx.git("add", "--", MANIFEST)
            self.assert_previous_intact(root)
        with self.subTest(case="CRLF manifest is accepted"):
            crlf = original.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
            root = self.root_for("crlf-manifest")
            with manifest_bytes(self.fx, crlf):
                self.install_ok(root, source=self.fx.path, skip_mcp=True)
            self.assertEqual(installed_files(root), {**self.fx.expected, MANIFEST: hashlib.sha256(crlf).hexdigest()})


def main():
    global REPO
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--runtime", required=True, choices=["bash", "powershell"])
    parser.add_argument("--repo-root", type=Path)
    args, rest = parser.parse_known_args()
    REPO = (args.repo_root or REPO).resolve()
    PayloadChecks.runner = Bash() if args.runtime == "bash" else PowerShell()
    unittest.main(argv=[sys.argv[0], *rest])


if __name__ == "__main__":
    main()
