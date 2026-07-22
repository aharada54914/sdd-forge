#!/usr/bin/env python3
"""Render checked-in, runtime-native guard invariant modules from v1 JSON."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
REQUIRED_TOP_LEVEL = {
    "schema_version",
    "protected_gate_suffixes",
    "protected_gate_plugin_json_suffixes",
    "shell",
    "sudo_signature_hex_length",
    "phase2_human_copy_targets",
}
REQUIRED_SHELL = {
    "compound_re",
    "write_arg_cmds",
    "write_dest_cmds",
    "ps_write_cmds",
    "indirect_cmds",
    "unsafe_token_chars",
    "redirect_token_re",
    "fd_dup_re",
    "cd_cmds",
    "sudo_write_re",
    "read_only_start_re",
}
PHASE2_TARGETS = (
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.py",
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.js",
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1",
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh",
    "plugins/sdd-quality-loop/scripts/check-contract.ps1",
    "plugins/sdd-lite/references/risk-upgrade-policy.md",
    "plugins/sdd-lite/scripts/check-risk-upgrade.sh",
    "plugins/sdd-lite/scripts/check-risk-upgrade.ps1",
    "plugins/sdd-lite/skills/lite-spec/SKILL.md",
    "plugins/sdd-ship/skills/ship/SKILL.md",
    "plugins/sdd-quality-loop/references/guard-invariants.json",
    "plugins/sdd-quality-loop/scripts/generate-guard-invariants.py",
    "plugins/sdd-quality-loop/scripts/generated/guard_invariants.py",
    "plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.js",
    "plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.ps1",
    "plugins/sdd-quality-loop/scripts/generated/guard-invariants.generated.sh",
    "tests/guard-parity.tests.sh",
    ".github/workflows/test.yml",
    "specs/epic-136-phase2-gates/human-copy/apply-protected-files.ps1",
)
BASELINE_SUFFIXES = (
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.js",
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.py",
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1",
    "plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh",
    "plugins/sdd-quality-loop/scripts/kill-switch.js",
    "plugins/sdd-quality-loop/scripts/kill-switch.sh",
    "plugins/sdd-quality-loop/scripts/kill-switch.ps1",
    "plugins/sdd-quality-loop/hooks/claude-hooks.json",
    "plugins/sdd-quality-loop/hooks/hooks.json",
    "plugins/sdd-quality-loop/hooks/copilot-hooks.json",
    "plugins/sdd-quality-loop/scripts/check-contract.sh",
    "plugins/sdd-quality-loop/scripts/check-contract.ps1",
    "plugins/sdd-quality-loop/scripts/check-contract.py",
    "plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh",
    "plugins/sdd-quality-loop/scripts/check-evidence-bundle.ps1",
    "plugins/sdd-quality-loop/scripts/check-evidence-bundle.py",
    "plugins/sdd-quality-loop/scripts/validate_path.py",
    ".claude/settings.json",
    ".claude/settings.local.json",
    "tests/gates.tests.sh",
    "tests/eval.tests.sh",
    "tests/guard-parity.tests.sh",
    "tests/constant-parity.tests.sh",
    "plugins/sdd-review-loop/agents/impl-reviewer-a.md",
    "plugins/sdd-review-loop/agents/impl-reviewer-b.md",
    "plugins/sdd-review-loop/agents/task-reviewer-a.md",
    "plugins/sdd-review-loop/agents/task-reviewer-b.md",
    "plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md",
    "plugins/sdd-review-loop/skills/task-review-loop/SKILL.md",
    "plugins/sdd-ship/skills/ship/SKILL.md",
)
PLUGIN_SUFFIXES = ("/.plugin/plugin.json", "/.claude-plugin/plugin.json", "/.codex-plugin/plugin.json")
ARRAY_SHELL_KEYS = {
    "write_arg_cmds", "write_dest_cmds", "ps_write_cmds", "indirect_cmds",
    "unsafe_token_chars", "cd_cmds",
}
REGEX_EXPORTS = {
    "compound_re": "SHELL_COMPOUND_RE",
    "redirect_token_re": "SHELL_REDIRECT_TOKEN_RE",
    "fd_dup_re": "SHELL_FD_DUP_RE",
    "sudo_write_re": "SHELL_SUDO_WRITE_RE",
    "read_only_start_re": "SHELL_READ_ONLY_START_RE",
}
ARRAY_EXPORTS = {
    "write_arg_cmds": "SHELL_WRITE_ARG_CMDS",
    "write_dest_cmds": "SHELL_WRITE_DEST_CMDS",
    "ps_write_cmds": "SHELL_PS_WRITE_CMDS",
    "indirect_cmds": "SHELL_INDIRECT_CMDS",
    "unsafe_token_chars": "SHELL_UNSAFE_TOKEN_CHARS",
    "cd_cmds": "SHELL_CD_CMDS",
}


def _is_string_list(value: Any, name: str, *, characters: bool = False) -> list[str]:
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValueError(f"{name} must be an array of strings")
    if len(value) != len(set(value)):
        raise ValueError(f"{name} must not contain duplicates")
    if characters and any(len(item) != 1 for item in value):
        raise ValueError(f"{name} must contain one-character strings")
    return value


def _validate_repo_path(path: str, name: str) -> None:
    if not path or path.startswith("/") or "\\" in path:
        raise ValueError(f"{name} contains an invalid repository-relative path")
    parts = path.split("/")
    if any(part in ("", ".", "..") for part in parts):
        raise ValueError(f"{name} contains an invalid repository-relative path")


def load_and_validate(canonical_path: Path) -> tuple[dict[str, Any], str]:
    raw = canonical_path.read_bytes()
    try:
        data = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError("canonical JSON is invalid") from exc
    if not isinstance(data, dict) or set(data) != REQUIRED_TOP_LEVEL:
        raise ValueError("canonical JSON has an invalid top-level key set")
    if type(data["schema_version"]) is not int or data["schema_version"] != SCHEMA_VERSION:
        raise ValueError("canonical schema_version is unsupported")
    if type(data["sudo_signature_hex_length"]) is not int or data["sudo_signature_hex_length"] != 64:
        raise ValueError("canonical sudo_signature_hex_length must equal 64")

    protected = _is_string_list(data["protected_gate_suffixes"], "protected_gate_suffixes")
    for value in protected:
        _validate_repo_path(value, "protected_gate_suffixes")
    expected_protected = tuple(BASELINE_SUFFIXES) + tuple(value for value in PHASE2_TARGETS if value not in BASELINE_SUFFIXES)
    if tuple(protected) != expected_protected:
        raise ValueError("protected_gate_suffixes must be the exact baseline/inventory union")

    plugins = _is_string_list(data["protected_gate_plugin_json_suffixes"], "protected_gate_plugin_json_suffixes")
    if tuple(plugins) != PLUGIN_SUFFIXES or any(not value.startswith("/") or ".." in value.split("/") for value in plugins):
        raise ValueError("protected_gate_plugin_json_suffixes is invalid")

    targets = _is_string_list(data["phase2_human_copy_targets"], "phase2_human_copy_targets")
    for value in targets:
        _validate_repo_path(value, "phase2_human_copy_targets")
    if tuple(targets) != PHASE2_TARGETS:
        raise ValueError("phase2_human_copy_targets must match the exact inventory")

    shell = data["shell"]
    if not isinstance(shell, dict) or set(shell) != REQUIRED_SHELL:
        raise ValueError("shell has an invalid key set")
    for key in ARRAY_SHELL_KEYS:
        _is_string_list(shell[key], f"shell.{key}", characters=(key == "unsafe_token_chars"))
    for key in REQUIRED_SHELL - ARRAY_SHELL_KEYS:
        if not isinstance(shell[key], str):
            raise ValueError(f"shell.{key} must be a regex source string")
    return data, hashlib.sha256(raw).hexdigest()


def _header(prefix: str, digest: str) -> str:
    return f"{prefix} Generated from guard-invariants.json; schema_version=1; sha256={digest}\n"


def _py_value(value: Any) -> str:
    if isinstance(value, list):
        if not value:
            return "()"
        return "(" + ", ".join(repr(item) for item in value) + ",)"
    return repr(value)


def render_python(data: dict[str, Any], digest: str) -> str:
    shell = data["shell"]
    lines = [_header("#", digest), "# This file is generated. Do not edit.\n"]
    lines.append("SCHEMA_VERSION = 1\n")
    lines.append(f"PROTECTED_GATE_SUFFIXES = {_py_value(data['protected_gate_suffixes'])}\n")
    lines.append(f"PROTECTED_GATE_PLUGIN_JSON_SUFFIXES = {_py_value(data['protected_gate_plugin_json_suffixes'])}\n")
    for key, export in REGEX_EXPORTS.items():
        lines.append(f"{export} = {_py_value(shell[key])}\n")
    for key, export in ARRAY_EXPORTS.items():
        lines.append(f"{export} = {_py_value(shell[key])}\n")
    lines.append(f"SUDO_SIGNATURE_HEX_LENGTH = {data['sudo_signature_hex_length']}\n")
    lines.append(f"PHASE2_HUMAN_COPY_TARGETS = {_py_value(data['phase2_human_copy_targets'])}\n")
    return "".join(lines)


def _js(value: Any) -> str:
    return json.dumps(value, ensure_ascii=True, separators=(",", ":"))


def render_javascript(data: dict[str, Any], digest: str) -> str:
    shell = data["shell"]
    lines = [_header("//", digest), "'use strict';\n", "module.exports = Object.freeze({\n"]
    values: list[tuple[str, Any]] = [
        ("SCHEMA_VERSION", 1),
        ("PROTECTED_GATE_SUFFIXES", data["protected_gate_suffixes"]),
        ("PROTECTED_GATE_PLUGIN_JSON_SUFFIXES", data["protected_gate_plugin_json_suffixes"]),
    ]
    values += [(export, shell[key]) for key, export in REGEX_EXPORTS.items()]
    values += [(export, shell[key]) for key, export in ARRAY_EXPORTS.items()]
    values += [("SUDO_SIGNATURE_HEX_LENGTH", 64), ("PHASE2_HUMAN_COPY_TARGETS", data["phase2_human_copy_targets"])]
    for name, value in values:
        rendered = f"Object.freeze({_js(value)})" if isinstance(value, list) else _js(value)
        lines.append(f"  {name}: {rendered},\n")
    lines.append("});\n")
    return "".join(lines)


def _ps(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def _ps_array(values: list[str]) -> str:
    return "@(" + ", ".join(_ps(value) for value in values) + ")"


def render_powershell(data: dict[str, Any], digest: str) -> str:
    shell = data["shell"]
    lines = [_header("#", digest), "# This file is generated. Do not edit.\n", "$GuardInvariants = [ordered]@{\n"]
    values: list[tuple[str, Any]] = [
        ("SCHEMA_VERSION", 1),
        ("PROTECTED_GATE_SUFFIXES", data["protected_gate_suffixes"]),
        ("PROTECTED_GATE_PLUGIN_JSON_SUFFIXES", data["protected_gate_plugin_json_suffixes"]),
    ]
    values += [(export, shell[key]) for key, export in REGEX_EXPORTS.items()]
    values += [(export, shell[key]) for key, export in ARRAY_EXPORTS.items()]
    values += [("SUDO_SIGNATURE_HEX_LENGTH", 64), ("PHASE2_HUMAN_COPY_TARGETS", data["phase2_human_copy_targets"])]
    for name, value in values:
        rendered = _ps_array(value) if isinstance(value, list) else (_ps(value) if isinstance(value, str) else str(value))
        lines.append(f"    {name} = {rendered}\n")
    lines.append("}\n")
    return "".join(lines)


def render_shell(digest: str) -> str:
    return (
        "#!/bin/sh\n"
        + _header("#", digest)
        + "# This dispatcher provenance module intentionally exposes no decision constants.\n"
        + "GUARD_INVARIANTS_SCHEMA_VERSION=1\n"
        + f"GUARD_INVARIANTS_SOURCE_SHA256={digest}\n"
    )


def expected_outputs(data: dict[str, Any], digest: str, generated_dir: Path) -> dict[Path, str]:
    return {
        generated_dir / "guard_invariants.py": render_python(data, digest),
        generated_dir / "guard-invariants.generated.js": render_javascript(data, digest),
        generated_dir / "guard-invariants.generated.ps1": render_powershell(data, digest),
        generated_dir / "guard-invariants.generated.sh": render_shell(digest),
    }


def write_atomic(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_bytes(text.encode("ascii"))
    os.replace(temporary, path)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="verify committed output without writing")
    args = parser.parse_args(argv)
    script_dir = Path(__file__).resolve().parent
    canonical = script_dir.parent / "references" / "guard-invariants.json"
    try:
        data, digest = load_and_validate(canonical)
        outputs = expected_outputs(data, digest, script_dir / "generated")
        stale = [path for path, text in outputs.items() if not path.is_file() or path.read_bytes() != text.encode("ascii")]
        if args.check:
            if stale:
                print("guard invariants are stale: " + ", ".join(str(path) for path in stale), file=sys.stderr)
                return 1
            return 0
        for path, text in outputs.items():
            write_atomic(path, text)
        return 0
    except (OSError, ValueError) as exc:
        print(f"generate-guard-invariants: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
