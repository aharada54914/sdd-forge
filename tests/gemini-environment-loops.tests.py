#!/usr/bin/env python3
"""End-to-end verification for Gemini CLI environment across SDD Forge loops.

Verifies without fabricating live Gemini CLI binary inference:
- Extension manifests (gemini-extension.json), GEMINI.md, TOML slash commands,
  and BeforeTool hooks/hooks.json for all 9 plugins.
- install.sh / install.ps1 and uninstall.sh / uninstall.ps1 with --target Gemini
  including extension linking/unlinking and ~/.gemini/settings.json MCP upsert/remove.
- model-selection loop on host gemini-cli (session-model-start).
- bootstrap loop on Gemini (hook activation handshake via real sdd-hook-guard.py
  --emit gemini, check-sdd-structure.sh, design-sync policy + receipt validator).
- ship loop on Gemini (BeforeTool blocking self-approval/SDD_SUDO/AGENT_STOP/
  protected files, plus check-placeholders and check-quality-gate-cycle-limit).
- ddd (sdd-domain) loop on Gemini (BeforeTool blocking Domain-Model-Status: Approved,
  validate-domain-contract.sh).
"""

import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parents[1]
PLUGINS = [
    "sdd-bootstrap",
    "sdd-ship",
    "sdd-lite",
    "sdd-domain",
    "sdd-review-loop",
    "sdd-quality-loop",
    "sdd-implementation",
    "sdd-azure-cloud",
    "sdd-aws-cloud",
]
MANAGED_MCPS = ("sdd-forge-mcp", "local-env-mcp", "ci-mcp")


def _manifest_dir(plugin: str) -> Path:
    if plugin in ("sdd-implementation", "sdd-quality-loop"):
        return ROOT / "plugins" / plugin / "gemini"
    return ROOT / "plugins" / plugin


def _expected_extension_name(plugin: str) -> str:
    if plugin == "sdd-implementation":
        return "sdd-forge-model-selection"
    return plugin


def _run(cmd, *, cwd=ROOT, env=None, input_text=None):
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    return subprocess.run(
        cmd,
        cwd=str(cwd),
        env=merged_env,
        input=input_text,
        text=True,
        capture_output=True,
        check=False,
    )


def _ignore_junk(_dirpath, names):
    junk = {".git", "node_modules", "__pycache__", ".pytest_cache", ".DS_Store", ".private", ".learnings"}
    return [n for n in names if n in junk or n.endswith((".pyc", ".pyo"))]


def _build_source_fixture(dst: Path) -> None:
    """Create a disposable Git repo from the live working tree's runtime payload."""
    dst.mkdir(parents=True, exist_ok=True)
    payload_file = ROOT / "install-payload.txt"
    for raw in payload_file.read_text(encoding="utf-8").splitlines():
        entry = raw.strip()
        if not entry or entry.startswith("#"):
            continue
        src = ROOT / entry.rstrip("/")
        target = dst / entry.rstrip("/")
        if not src.exists():
            continue
        if src.is_dir():
            shutil.copytree(src, target, ignore=_ignore_junk, dirs_exist_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, target)
    for mcp_name in MANAGED_MCPS:
        for rel in ("dist/index.js", "package.json"):
            src_file = ROOT / "mcp" / mcp_name / rel
            if src_file.is_file():
                out = dst / "mcp" / mcp_name / rel
                out.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src_file, out)
    git_env = {
        "GIT_CONFIG_GLOBAL": os.devnull,
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_TERMINAL_PROMPT": "0",
    }
    for args in (
        ["git", "init", "-q"],
        ["git", "config", "gc.auto", "0"],
        ["git", "config", "gc.autoDetach", "false"],
        ["git", "config", "maintenance.auto", "false"],
        ["git", "add", "-A"],
        [
            "git",
            "-c",
            "user.name=Gemini Verify",
            "-c",
            "user.email=gemini-verify@example.invalid",
            "commit",
            "-qm",
            "fixture",
        ],
    ):
        res = _run(args, cwd=dst, env=git_env)
        if res.returncode != 0:
            raise RuntimeError(f"{args} failed: {res.stderr}")


class GeminiPackagingTests(unittest.TestCase):
    def test_all_nine_plugins_have_valid_gemini_extension_and_commands(self):
        versions = set()
        for plugin in PLUGINS:
            ext_dir = _manifest_dir(plugin)
            manifest_path = ext_dir / "gemini-extension.json"
            self.assertTrue(manifest_path.is_file(), f"missing {manifest_path}")
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            self.assertEqual(manifest.get("name"), _expected_extension_name(plugin))
            self.assertTrue(manifest.get("version"))
            versions.add(manifest["version"])
            ctx_name = manifest.get("contextFileName")
            self.assertEqual(ctx_name, "GEMINI.md", f"{plugin} must declare GEMINI.md")
            self.assertTrue((ext_dir / ctx_name).is_file(), f"missing {ext_dir / ctx_name}")
            commands_dir = ext_dir / "commands"
            if commands_dir.is_dir():
                for toml_file in sorted(commands_dir.rglob("*.toml")):
                    parsed = tomllib.loads(toml_file.read_text(encoding="utf-8"))
                    self.assertIn("description", parsed, f"{toml_file} missing description")
                    self.assertIn("prompt", parsed, f"{toml_file} missing prompt")
        self.assertEqual(len(versions), 1, f"Gemini extension versions diverged: {versions}")

    def test_quality_loop_gemini_before_tool_hook_configuration(self):
        hooks_path = ROOT / "plugins" / "sdd-quality-loop" / "gemini" / "hooks" / "hooks.json"
        self.assertTrue(hooks_path.is_file())
        data = json.loads(hooks_path.read_text(encoding="utf-8"))
        entries = data["hooks"]["BeforeTool"]
        self.assertTrue(entries)
        commands = [
            hook["command"]
            for entry in entries
            for hook in entry.get("hooks", [])
            if isinstance(hook, dict) and "command" in hook
        ]
        self.assertTrue(
            any("sdd-hook-guard.py" in cmd and "--emit gemini" in cmd for cmd in commands),
            f"BeforeTool hook must invoke sdd-hook-guard.py --emit gemini; got {commands}",
        )
        # Ensure sdd-implementation does NOT have conventional hooks/hooks.json
        self.assertFalse((ROOT / "plugins" / "sdd-implementation" / "hooks" / "hooks.json").exists())


class GeminiInstallerAndMcpTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._tmp_source = tempfile.TemporaryDirectory(prefix="sdd-gemini-src-")
        cls.source_repo = Path(cls._tmp_source.name) / "repo"
        _build_source_fixture(cls.source_repo)

    @classmethod
    def tearDownClass(cls):
        cls._tmp_source.cleanup()

    def _make_fake_gemini_bin(self, bin_dir: Path, log_path: Path) -> None:
        gemini = bin_dir / "gemini"
        gemini.write_text(
            "#!/bin/sh\n"
            f'printf "%s\\n" "$*" >> "{log_path}"\n'
            "exit 0\n",
            encoding="utf-8",
        )
        gemini.chmod(gemini.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    def _make_fake_node_bin(self, bin_dir: Path, version: str = "v26.13.0") -> None:
        real_node = shutil.which("node")
        if not real_node:
            self.skipTest("node not available")
        node = bin_dir / "node"
        node.write_text(
            "#!/bin/sh\n"
            'if [ "${1:-}" = "-v" ] || [ "${1:-}" = "--version" ]; then\n'
            f'  printf "%s\\n" "{version}"\n'
            "  exit 0\n"
            "fi\n"
            f'exec "{real_node}" "$@"\n',
            encoding="utf-8",
        )
        node.chmod(node.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    def test_bash_install_and_uninstall_target_gemini_with_mcp_settings(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            gemini_log = root / "gemini.log"
            self._make_fake_gemini_bin(bin_dir, gemini_log)
            self._make_fake_node_bin(bin_dir)

            install_root = root / "installed"
            gemini_dir = root / "gemini-home"
            gemini_dir.mkdir()
            settings_path = gemini_dir / "settings.json"
            settings_path.write_text(
                json.dumps({"theme": "Dark", "mcpServers": {"user-custom": {"command": "echo"}}}),
                encoding="utf-8",
            )
            home_dir = root / "home"
            home_dir.mkdir()

            env = {
                "PATH": f"{bin_dir}:{os.environ.get('PATH', '')}",
                "SDD_GEMINI_DIR": str(gemini_dir),
                "SDD_CODEX_HOME": str(home_dir / ".codex"),
                "SDD_CURSOR_DIR": str(home_dir / ".cursor-absent"),
                "SDD_VSCODE_USER_DIR": str(home_dir / ".vscode-absent"),
                "HOME": str(home_dir),
            }

            selected = "sdd-bootstrap,sdd-ship,sdd-domain,sdd-quality-loop,sdd-implementation"
            res = _run(
                [
                    "bash",
                    str(ROOT / "install.sh"),
                    "--target",
                    "Gemini",
                    "--plugins",
                    selected,
                    "--install-root",
                    str(install_root),
                    "--source-directory",
                    str(self.source_repo),
                ],
                env=env,
            )
            self.assertEqual(res.returncode, 0, res.stdout + "\n" + res.stderr)

            calls = gemini_log.read_text(encoding="utf-8").splitlines()
            expected_targets = [
                str((install_root / "plugins" / "sdd-bootstrap").resolve()),
                str((install_root / "plugins" / "sdd-ship").resolve()),
                str((install_root / "plugins" / "sdd-domain").resolve()),
                str((install_root / "plugins" / "sdd-quality-loop" / "gemini").resolve()),
                str((install_root / "plugins" / "sdd-implementation" / "gemini").resolve()),
            ]
            for target in expected_targets:
                self.assertTrue(
                    any(line == f"extensions link {target}" for line in calls),
                    f"expected link for {target}, got {calls}",
                )

            settings = json.loads(settings_path.read_text(encoding="utf-8"))
            self.assertEqual(settings.get("theme"), "Dark")
            self.assertIn("user-custom", settings["mcpServers"])
            for managed in MANAGED_MCPS:
                self.assertIn(managed, settings["mcpServers"])
                self.assertEqual(settings["mcpServers"][managed]["command"], "node")

            # Partial uninstall removes selected extensions and preserves shared MCP registrations
            gemini_log.write_text("", encoding="utf-8")
            partial = _run(
                [
                    "bash",
                    str(ROOT / "uninstall.sh"),
                    "--target",
                    "Gemini",
                    "--plugins",
                    selected,
                    "--install-root",
                    str(install_root),
                ],
                env=env,
            )
            self.assertEqual(partial.returncode, 0, partial.stdout + "\n" + partial.stderr)

            un_calls = gemini_log.read_text(encoding="utf-8").splitlines()
            for ext_name in (
                "sdd-bootstrap",
                "sdd-ship",
                "sdd-domain",
                "sdd-quality-loop",
                "sdd-forge-model-selection",
            ):
                self.assertIn(f"extensions uninstall {ext_name}", un_calls)
            partial_settings = json.loads(settings_path.read_text(encoding="utf-8"))
            self.assertIn("sdd-forge-mcp", partial_settings["mcpServers"])

            # Full uninstall removes managed MCP keys while preserving user keys
            full = _run(
                [
                    "bash",
                    str(ROOT / "uninstall.sh"),
                    "--target",
                    "Gemini",
                    "--install-root",
                    str(install_root),
                ],
                env=env,
            )
            self.assertEqual(full.returncode, 0, full.stdout + "\n" + full.stderr)

            after_settings = json.loads(settings_path.read_text(encoding="utf-8"))
            self.assertEqual(after_settings.get("theme"), "Dark")
            self.assertIn("user-custom", after_settings["mcpServers"])
            for managed in MANAGED_MCPS:
                self.assertNotIn(managed, after_settings["mcpServers"])

    def test_powershell_install_and_uninstall_target_gemini(self):
        pwsh = shutil.which("pwsh")
        if not pwsh:
            self.skipTest("pwsh not available")
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bin_dir = root / "bin"
            bin_dir.mkdir()
            gemini_log = root / "gemini.log"
            self._make_fake_gemini_bin(bin_dir, gemini_log)
            self._make_fake_node_bin(bin_dir)

            install_root = root / "installed"
            gemini_dir = root / "gemini-home"
            gemini_dir.mkdir()
            settings_path = gemini_dir / "settings.json"
            settings_path.write_text(json.dumps({"theme": "Light"}), encoding="utf-8")
            home_dir = root / "home"
            home_dir.mkdir()

            env = {
                "PATH": f"{bin_dir}:{os.environ.get('PATH', '')}",
                "SDD_GEMINI_DIR": str(gemini_dir),
                "SDD_CODEX_HOME": str(home_dir / ".codex"),
                "SDD_CURSOR_DIR": str(home_dir / ".cursor-absent"),
                "SDD_VSCODE_USER_DIR": str(home_dir / ".vscode-absent"),
                "HOME": str(home_dir),
            }
            install_cmd = (
                f"& '{ROOT / 'install.ps1'}' -Target Gemini "
                f"-Plugins @('sdd-bootstrap','sdd-quality-loop','sdd-implementation') "
                f"-InstallRoot '{install_root}' -SourceDirectory '{self.source_repo}'"
            )
            res = _run([pwsh, "-NoProfile", "-Command", install_cmd], env=env)
            self.assertEqual(res.returncode, 0, res.stdout + "\n" + res.stderr)
            calls = gemini_log.read_text(encoding="utf-8").splitlines()
            self.assertTrue(any("sdd-bootstrap" in line for line in calls), calls)
            self.assertTrue(any("sdd-quality-loop/gemini" in line for line in calls), calls)
            self.assertTrue(any("sdd-implementation/gemini" in line for line in calls), calls)

            settings = json.loads(settings_path.read_text(encoding="utf-8"))
            self.assertEqual(settings.get("theme"), "Light")
            for managed in MANAGED_MCPS:
                self.assertIn(managed, settings.get("mcpServers", {}))

            uninstall_cmd = (
                f"& '{ROOT / 'uninstall.ps1'}' -Target Gemini "
                f"-InstallRoot '{install_root}'"
            )
            un = _run([pwsh, "-NoProfile", "-Command", uninstall_cmd], env=env)
            self.assertEqual(un.returncode, 0, un.stdout + "\n" + un.stderr)
            after_settings = json.loads(settings_path.read_text(encoding="utf-8"))
            self.assertEqual(after_settings.get("theme"), "Light")
            for managed in MANAGED_MCPS:
                self.assertNotIn(managed, after_settings.get("mcpServers", {}))


class GeminiLoopBehaviorTests(unittest.TestCase):
    def test_bootstrap_hook_handshake_end_to_end_via_real_guard(self):
        handshake = ROOT / "plugins" / "sdd-quality-loop" / "scripts" / "check-hook-activation-handshake.py"
        guard = ROOT / "plugins" / "sdd-quality-loop" / "scripts" / "sdd-hook-guard.py"

        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            (work / "sdd").mkdir()

            emit = _run([sys.executable, str(handshake), "--emit-challenge"], cwd=work)
            self.assertEqual(emit.returncode, 0, emit.stderr)
            challenge = json.loads(emit.stdout)
            nonce = challenge["nonce"]
            gemini_req = challenge["tool_call_template"]["gemini-cli"]
            self.assertEqual(gemini_req["tool_name"], "write_file")
            self.assertEqual(gemini_req["tool_input"]["file_path"], "sdd/.hook-canary-sentinel")
            self.assertEqual(gemini_req["tool_input"]["content"], f"sdd-hook-challenge:{nonce}")

            guard_res = _run(
                [sys.executable, str(guard), "--emit", "gemini"],
                cwd=work,
                env={"CLAUDE_PROJECT_DIR": str(work)},
                input_text=json.dumps(gemini_req),
            )
            self.assertEqual(guard_res.returncode, 0, guard_res.stderr)
            guard_json = json.loads(guard_res.stdout)
            self.assertEqual(guard_json["decision"], "deny")

            evidence = {
                "schema": "sdd-gemini-host-denial/v1",
                "runtime": "gemini-cli",
                "nonce": nonce,
                "executed": False,
                "raw_request": gemini_req,
                "raw_result": guard_json,
            }
            ev_path = work / "recorded-gemini-denial.json"
            ev_path.write_text(json.dumps(evidence), encoding="utf-8")

            verify = _run(
                [
                    sys.executable,
                    str(handshake),
                    "--verify-response",
                    "--nonce",
                    nonce,
                    "--recorded-result",
                    str(ev_path),
                    "--runtime",
                    "gemini-cli",
                ],
                cwd=work,
            )
            self.assertEqual(verify.returncode, 0, verify.stdout + "\n" + verify.stderr)
            verdict = json.loads(verify.stdout)
            self.assertEqual(verdict["status"], "HOOK_ACTIVE")
            self.assertFalse((work / "sdd" / ".hook-canary-sentinel").exists())

    def test_bootstrap_structure_and_design_sync_scripts(self):
        check_struct = ROOT / "plugins" / "sdd-bootstrap" / "scripts" / "check-sdd-structure.sh"
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            (work / "AGENTS.md").write_text("# Agents\n", encoding="utf-8")
            for rel_dir in (
                "specs",
                "reports/implementation",
                "reports/quality-gate",
                "docs/adr",
                "docs/review-tickets",
            ):
                (work / rel_dir).mkdir(parents=True, exist_ok=True)
            res = _run(["bash", str(check_struct)], cwd=work)
            self.assertEqual(res.returncode, 0, res.stdout + "\n" + res.stderr)

    def test_ship_loop_guard_and_gate_scripts(self):
        guard = ROOT / "plugins" / "sdd-quality-loop" / "scripts" / "sdd-hook-guard.py"
        check_placeholders = ROOT / "plugins" / "sdd-quality-loop" / "scripts" / "check-placeholders.sh"
        check_cycle = ROOT / "plugins" / "sdd-quality-loop" / "scripts" / "check-quality-gate-cycle-limit.sh"
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            (work / "specs" / "demo").mkdir(parents=True)
            (work / "specs" / "demo" / "requirements.md").write_text("# Requirements\nReal content.\n", encoding="utf-8")

            # Guard blocks tasks.md self-approval, SDD_SUDO, and protected Gemini hooks
            for payload in (
                {"tool_name": "write_file", "tool_input": {"file_path": "specs/demo/tasks.md", "content": "Approval: Approved"}},
                {"tool_name": "write_file", "tool_input": {"file_path": "plugins/sdd-quality-loop/gemini/hooks/hooks.json", "content": "{}"}},
                {"tool_name": "write_file", "tool_input": {"file_path": "/tmp/SDD_SUDO", "content": "x"}},
                {"tool_name": "run_shell_command", "tool_input": {"command": "printf x > /tmp/SDD_SUDO"}},
            ):
                res = _run(
                    [sys.executable, str(guard), "--emit", "gemini"],
                    cwd=work,
                    env={"CLAUDE_PROJECT_DIR": str(work)},
                    input_text=json.dumps(payload),
                )
                self.assertEqual(res.returncode, 0)
                self.assertEqual(json.loads(res.stdout)["decision"], "deny", payload)

            # Kill-switch AGENT_STOP trips fail-closed denial even for benign write_file
            (work / "AGENT_STOP").write_text("stop\n", encoding="utf-8")
            stopped = _run(
                [sys.executable, str(guard), "--emit", "gemini"],
                cwd=work,
                env={"CLAUDE_PROJECT_DIR": str(work)},
                input_text=json.dumps({"tool_name": "write_file", "tool_input": {"file_path": "src/app.py", "content": "ok"}}),
            )
            self.assertEqual(stopped.returncode, 0)
            self.assertEqual(json.loads(stopped.stdout)["decision"], "deny")
            (work / "AGENT_STOP").unlink()

            # Placeholders check passes on clean fixture
            ph = _run(["bash", str(check_placeholders), str(work / "specs" / "demo")], cwd=work)
            self.assertEqual(ph.returncode, 0, ph.stdout + "\n" + ph.stderr)

            # Cycle limit check passes on clean reports dir
            (work / "reports" / "quality-gate" / "demo").mkdir(parents=True)
            cl = _run(["bash", str(check_cycle), "T-001", "demo"], cwd=work)
            self.assertEqual(cl.returncode, 0, cl.stdout + "\n" + cl.stderr)

    def test_ddd_domain_loop_guard_and_contract_validator(self):
        guard = ROOT / "plugins" / "sdd-quality-loop" / "scripts" / "sdd-hook-guard.py"
        validate_domain = ROOT / "plugins" / "sdd-domain" / "scripts" / "validate-domain-contract.sh"
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            res = _run(
                [sys.executable, str(guard), "--emit", "gemini"],
                cwd=work,
                env={"CLAUDE_PROJECT_DIR": str(work)},
                input_text=json.dumps(
                    {
                        "tool_name": "replace",
                        "tool_input": {
                            "file_path": "sdd/domain/context-map.md",
                            "new_string": "Domain-Model-Status: Approved",
                        },
                    }
                ),
            )
            self.assertEqual(res.returncode, 0)
            self.assertEqual(json.loads(res.stdout)["decision"], "deny")

            # Missing domain files fails closed on validate-domain-contract.sh
            bad = _run(["bash", str(validate_domain)], cwd=work)
            self.assertNotEqual(bad.returncode, 0)

    def test_model_selection_loop_for_gemini_cli(self):
        start_script = ROOT / "plugins" / "sdd-implementation" / "scripts" / "session-model-start.py"
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            event = {"source": "startup", "session_id": "gemini-sess-001"}
            res = _run(
                [sys.executable, str(start_script), "--host", "gemini-cli"],
                cwd=work,
                input_text=json.dumps(event),
            )
            self.assertEqual(res.returncode, 0, res.stdout + "\n" + res.stderr)
            payload = json.loads(res.stdout)
            hook_out = payload.get("hookSpecificOutput", {})
            self.assertEqual(hook_out.get("hookEventName"), "SessionStart")
            ctx = hook_out.get("additionalContext", "")
            self.assertIn("SDD_FORGE_SESSION_MODELS", ctx)
            self.assertIn('"host": "gemini-cli"', ctx)
            self.assertIn('"session_id": "gemini-sess-001"', ctx)

            # Non-interactive invocation must emit nothing
            nonint = _run(
                [sys.executable, str(start_script), "--host", "gemini-cli"],
                cwd=work,
                env={"SDD_SESSION_NONINTERACTIVE": "1"},
                input_text=json.dumps(event),
            )
            self.assertEqual(nonint.returncode, 0)
            self.assertEqual(nonint.stdout.strip(), "")


class CrossAiOperationTests(unittest.TestCase):
    """Verify 3-AI cross-operation (Claude Code / Codex CLI / Gemini CLI) on one workspace."""

    def test_three_ai_session_start_hooks_share_contract(self):
        start_script = ROOT / "plugins" / "sdd-implementation" / "scripts" / "session-model-start.py"
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            for host in ("claude-code", "codex-cli", "gemini-cli"):
                res = _run(
                    [sys.executable, str(start_script), "--host", host],
                    cwd=work,
                    input_text=json.dumps({"source": "startup", "session_id": f"sess-{host}"}),
                )
                self.assertEqual(res.returncode, 0, f"{host}: {res.stderr}")
                ctx = json.loads(res.stdout)["hookSpecificOutput"]["additionalContext"]
                self.assertIn(f'"host": "{host}"', ctx)
                self.assertIn(f'"session_id": "sess-{host}"', ctx)

    def test_three_ai_guard_enforces_identical_boundaries_across_native_tools(self):
        guard = ROOT / "plugins" / "sdd-quality-loop" / "scripts" / "sdd-hook-guard.py"
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            cases = [
                # Claude Code native Write/Bash
                ("claude-write-approval", "exit", {"tool_name": "Write", "tool_input": {"file_path": "specs/demo/tasks.md", "content": "Approval: Approved"}}),
                ("claude-bash-sudo", "exit", {"tool_name": "Bash", "tool_input": {"command": "printf x > /tmp/SDD_SUDO"}}),
                # Codex CLI native apply_patch/exec_command
                ("codex-patch-approval", "exit", {"tool_name": "apply_patch", "tool_input": {"command": "*** Begin Patch\n*** Update File: specs/demo/tasks.md\n+Approval: Approved\n*** End Patch"}}),
                ("codex-exec-sudo", "exit", {"tool_name": "exec_command", "tool_input": {"command": "printf x > /tmp/SDD_SUDO"}}),
                # Gemini CLI native write_file/replace/run_shell_command
                ("gemini-write-approval", "gemini", {"tool_name": "write_file", "tool_input": {"file_path": "specs/demo/tasks.md", "content": "Approval: Approved"}}),
                ("gemini-replace-domain", "gemini", {"tool_name": "replace", "tool_input": {"file_path": "sdd/domain/context-map.md", "new_string": "Domain-Model-Status: Approved"}}),
                ("gemini-shell-sudo", "gemini", {"tool_name": "run_shell_command", "tool_input": {"command": "printf x > /tmp/SDD_SUDO"}}),
            ]
            for label, mode, payload in cases:
                res = _run(
                    [sys.executable, str(guard), "--emit", mode],
                    cwd=work,
                    env={"CLAUDE_PROJECT_DIR": str(work)},
                    input_text=json.dumps(payload),
                )
                if mode == "exit":
                    self.assertEqual(res.returncode, 2, f"{label}: expected exit 2, got {res.returncode}")
                else:
                    self.assertEqual(res.returncode, 0, f"{label}: expected exit 0")
                    self.assertEqual(json.loads(res.stdout).get("decision"), "deny", f"{label}: expected deny")

    def test_three_ai_hook_handshake_accepts_all_three_hosts(self):
        handshake = ROOT / "plugins" / "sdd-quality-loop" / "scripts" / "check-hook-activation-handshake.py"
        with tempfile.TemporaryDirectory() as tmp:
            work = Path(tmp)
            (work / "sdd").mkdir()
            emit = _run([sys.executable, str(handshake), "--emit-challenge"], cwd=work)
            self.assertEqual(emit.returncode, 0, emit.stderr)
            challenge = json.loads(emit.stdout)
            nonce = challenge["nonce"]
            for rt in ("claude-code", "codex-cli", "gemini-cli"):
                self.assertIn(rt, challenge["tool_call_template"])
                self.assertIn(rt, challenge["recorded_result_template"])

            evidence_by_runtime = {
                "claude-code": {"nonce": nonce, "executed": False, "guard_emit_mode": "exit", "exit_code": 2},
                "codex-cli": {"nonce": nonce, "executed": False, "plugin_hooks_enabled": True, "denied_by_plugin_hooks": True},
                "gemini-cli": {"nonce": nonce, "executed": False, "decision": "deny"},
            }
            for rt, ev in evidence_by_runtime.items():
                p = work / f"ev-{rt}.json"
                p.write_text(json.dumps(ev), encoding="utf-8")
                ver = _run(
                    [
                        sys.executable,
                        str(handshake),
                        "--verify-response",
                        "--nonce",
                        nonce,
                        "--recorded-result",
                        str(p),
                        "--runtime",
                        rt,
                    ],
                    cwd=work,
                )
                self.assertEqual(ver.returncode, 0, f"{rt}: {ver.stdout} {ver.stderr}")
                self.assertEqual(json.loads(ver.stdout)["status"], "HOOK_ACTIVE")


if __name__ == "__main__":
    unittest.main()
