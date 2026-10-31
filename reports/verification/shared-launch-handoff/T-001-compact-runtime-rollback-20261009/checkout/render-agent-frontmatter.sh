#!/usr/bin/env bash
# render-agent-frontmatter.sh (T-003, epic-159-pillar-c, #151) — REQ-003 /
# AC-014..AC-020.
#
# Renders `model:`/`x-sdd-effort:` frontmatter into unprotected Claude `.md`
# agent files and `# x-sdd-model:`/`# x-sdd-effort:` reference comments into
# Codex `.toml` agent files, sourced from `contracts/agent-model-capabilities.v2.json`'s
# `role_defaults`. The four R-10 protected review-loop reviewer `.md` files
# (`plugins/sdd-review-loop/agents/{impl,task}-reviewer-{a,b}.md`) are NEVER
# opened for write by this script: corrected content for those four targets
# is staged under `specs/epic-159-pillar-c/human-copy/<repo-relative-path>`
# plus a `MANIFEST.sha256` entry, for a human maintainer to `cp` into place
# (security-spec.md B2; requirements.md REQ-003 Protected-reviewer
# procedure). `--check` performs the identical read-and-compute step but
# never writes anywhere -- it only compares computed content against
# on-disk content (including, read-only, the four protected targets' real
# paths) and exits non-zero on any drift.
#
# Usage:
#   render-agent-frontmatter.sh [--check] [--registry PATH] [--root PATH] [--targets-file PATH]
#   render-agent-frontmatter.sh --resolve-target-raw RELPATH 0|1
#   render-agent-frontmatter.sh --resolve-target ROLE KIND RELPATH
#
# `--resolve-target-raw`/`--resolve-target` are the write-target resolution
# self-check surface AC-019/TEST-019 exercises directly (not a
# reimplementation in the test suite): `--resolve-target-raw` invokes the
# raw protected/unprotected branch directly (RelPath, Protected flag as
# explicit inputs, independent of the built-in target table);
# `--resolve-target` looks the target up in the built-in (or
# `--targets-file`-supplied) table and applies the same branch. Both print
# the resolved path and exit 0, or exit 1 with a diagnostic if the target is
# not found.
#
# CI-resilience (requirements.md Edge Cases; design.md Constraint
# Compliance): no possibly-empty bash array is expanded under `set -u`; the
# script performs no jq consumption (JSON parsing goes through python3,
# already a repository dependency per select-agent-model.sh's own heredoc
# usage), so the Windows jq.exe CRLF hazard does not apply; no real
# validator gate is driven; SCRIPT_ROOT is normalized with `pwd -P`.
set -euo pipefail

SCRIPT_ROOT="$(cd "$(dirname "$0")" && pwd -P)"

python3 - "$SCRIPT_ROOT" "$@" <<'PY'
import hashlib
import json
import os
import re
import sys

HUMAN_COPY_RELDIR = "specs/epic-159-pillar-c/human-copy"

DEFAULT_TARGETS = [
    {"role": "sdd-evaluator", "kind": "claude", "path": "plugins/sdd-quality-loop/agents/evaluator.md", "protected": False},
    {"role": "sdd-evaluator", "kind": "codex", "path": ".codex/agents/sdd-evaluator.toml", "protected": False},
    {"role": "sdd-investigator", "kind": "claude", "path": "plugins/sdd-bootstrap/agents/investigator.md", "protected": False},
    {"role": "sdd-investigator", "kind": "codex", "path": ".codex/agents/sdd-investigator.toml", "protected": False},
    {"role": "spec-reviewer", "kind": "claude", "path": "plugins/sdd-review-loop/agents/spec-reviewer-a.md", "protected": False},
    {"role": "spec-reviewer", "kind": "claude", "path": "plugins/sdd-review-loop/agents/spec-reviewer-b.md", "protected": False},
    {"role": "impl-reviewer", "kind": "claude", "path": "plugins/sdd-review-loop/agents/impl-reviewer-a.md", "protected": True},
    {"role": "impl-reviewer", "kind": "claude", "path": "plugins/sdd-review-loop/agents/impl-reviewer-b.md", "protected": True},
    {"role": "task-reviewer", "kind": "claude", "path": "plugins/sdd-review-loop/agents/task-reviewer-a.md", "protected": True},
    {"role": "task-reviewer", "kind": "claude", "path": "plugins/sdd-review-loop/agents/task-reviewer-b.md", "protected": True},
]

MODEL_LINE_RE = re.compile(r'^model:\s*(\S+)\s*$')
EFFORT_COMMENT_RE = re.compile(r'^<!-- x-sdd-effort: (\S+) -->$')
CODEX_MODEL_RE = re.compile(r'^# x-sdd-model: \S+$')
CODEX_EFFORT_RE = re.compile(r'^# x-sdd-effort: \S+$')


def die(msg):
    print(f"RENDER_ERROR: {msg}", file=sys.stderr)
    sys.exit(1)


def resolve_write_target_raw(root, relpath, protected):
    # The write-target resolution FUNCTION itself (AC-019/TEST-019): this
    # branch is the ENTIRE decision -- protected targets structurally never
    # resolve to `root/relpath`, regardless of registry content.
    if protected:
        return os.path.join(root, HUMAN_COPY_RELDIR, relpath)
    return os.path.join(root, relpath)


def resolve_write_target(root, targets, role, kind, relpath):
    for t in targets:
        if t["role"] == role and t["kind"] == kind and t["path"] == relpath:
            return resolve_write_target_raw(root, relpath, t["protected"])
    die(f"target not found in table: {role}/{kind}/{relpath}")


def split_lines(content):
    trailing_nl = content.endswith("\n")
    lines = content.split("\n")
    if trailing_nl:
        lines = lines[:-1]
    return lines, trailing_nl


def join_lines(lines, trailing_nl):
    text = "\n".join(lines)
    if trailing_nl:
        text += "\n"
    return text


def load_registry(path):
    if not os.path.isfile(path):
        die(f"registry not found: {path}")
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    if data.get("schema") != "agent-model-capabilities/v2":
        die(f"registry schema must be 'agent-model-capabilities/v2', got {data.get('schema')!r}")
    return data


def model_for_tier(registry, tier, kind):
    for m in registry.get("models", []):
        name = m.get("name")
        if not isinstance(name, str):
            continue
        if m.get("canonical_tier") != tier:
            continue
        if kind == "claude":
            if name.startswith("anthropic/"):
                return name.split("/", 1)[1]
        else:
            control = m.get("effort_control")
            if isinstance(control, dict) and control.get("codex-cli") == "flag":
                return name
    die(f"no {kind} model found for tier {tier!r}")


def role_values(registry, role):
    role_defaults = registry.get("role_defaults")
    if not isinstance(role_defaults, dict):
        die("registry role_defaults is missing or not an object")
    entry = None
    for key, value in role_defaults.items():
        # Case-sensitive key match (mirrors select-agent-model's ordinal
        # comparison discipline; T-002 implementation report): a mis-cased
        # role_defaults key (e.g. "Sdd-Evaluator") must never silently
        # satisfy a lookup for "sdd-evaluator".
        if key == role:
            entry = value
            break
    if not isinstance(entry, dict) or not entry.get("minimum_tier") or not entry.get("default_effort"):
        die(f"role_defaults missing or incomplete for role {role!r}")
    return entry["minimum_tier"], entry["default_effort"]


def transform_claude(content, model_name, effort):
    lines, trailing_nl = split_lines(content)
    if not lines or lines[0] != "---":
        die("claude target missing opening frontmatter delimiter")
    close_idx = None
    for i in range(1, len(lines)):
        if lines[i] == "---":
            close_idx = i
            break
    if close_idx is None:
        die("claude target missing closing frontmatter delimiter")

    model_idx = None
    for i in range(1, close_idx):
        if MODEL_LINE_RE.match(lines[i]):
            model_idx = i
            break

    changed = False
    if model_idx is not None:
        current_value = MODEL_LINE_RE.match(lines[model_idx]).group(1)
        if current_value == "inherit":
            # AC-018 exclusion: model: inherit agents are never rewritten.
            return content, False
        if current_value != model_name:
            lines[model_idx] = f"model: {model_name}"
            changed = True
    else:
        lines.insert(close_idx, f"model: {model_name}")
        close_idx += 1
        changed = True

    after_idx = close_idx + 1
    if after_idx < len(lines) and EFFORT_COMMENT_RE.match(lines[after_idx]):
        current_effort = EFFORT_COMMENT_RE.match(lines[after_idx]).group(1)
        if current_effort != effort:
            lines[after_idx] = f"<!-- x-sdd-effort: {effort} -->"
            changed = True
    else:
        lines.insert(after_idx, f"<!-- x-sdd-effort: {effort} -->")
        changed = True

    return join_lines(lines, trailing_nl), changed


def transform_codex(content, model_name, effort):
    lines, trailing_nl = split_lines(content)
    i = 0
    while i < len(lines) and (CODEX_MODEL_RE.match(lines[i]) or CODEX_EFFORT_RE.match(lines[i])):
        i += 1
    rest = lines[i:]
    new_lines = [f"# x-sdd-model: {model_name}", f"# x-sdd-effort: {effort}"] + rest
    new_content = join_lines(new_lines, trailing_nl or True)
    return new_content, (new_content != content)


def sha256_of_text(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def upsert_manifest(manifest_path, relpath, sha):
    lines = []
    if os.path.isfile(manifest_path):
        with open(manifest_path, encoding="utf-8") as fh:
            lines = fh.readlines()
    new_lines = []
    replaced = False
    entry_re = re.compile(r'^(\S+)\s+(.+?)\s*$')
    for line in lines:
        m = entry_re.match(line)
        if m and m.group(2) == relpath:
            new_lines.append(f"{sha}  {relpath}\n")
            replaced = True
        else:
            new_lines.append(line if line.endswith("\n") else line + "\n")
    if not replaced:
        new_lines.append(f"{sha}  {relpath}\n")
    os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
    with open(manifest_path, "w", encoding="utf-8") as fh:
        fh.writelines(new_lines)


def render_target(root, registry, target, manifest_path, check_mode):
    role, kind, relpath, protected = target["role"], target["kind"], target["path"], target["protected"]
    tier, effort = role_values(registry, role)
    model_name = model_for_tier(registry, tier, kind)

    real_path = os.path.join(root, relpath)
    if not os.path.isfile(real_path):
        die(f"target file not found: {relpath}")
    with open(real_path, encoding="utf-8") as fh:
        current = fh.read()

    if kind == "claude":
        computed, changed = transform_claude(current, model_name, effort)
    else:
        computed, changed = transform_codex(current, model_name, effort)

    if check_mode:
        return {"relpath": relpath, "protected": protected, "drift": computed != current}

    if protected:
        staged_path = resolve_write_target_raw(root, relpath, True)
        os.makedirs(os.path.dirname(staged_path), exist_ok=True)
        with open(staged_path, "w", encoding="utf-8") as fh:
            fh.write(computed)
        upsert_manifest(manifest_path, relpath, sha256_of_text(computed))
        return {"relpath": relpath, "protected": True, "staged": staged_path, "changed": changed}

    if computed != current:
        with open(real_path, "w", encoding="utf-8") as fh:
            fh.write(computed)
    return {"relpath": relpath, "protected": False, "changed": changed}


def main():
    default_root = sys.argv[1]
    argv = sys.argv[2:]

    root = None
    registry_path = None
    targets_path = None
    check_mode = False
    resolve_raw_args = None
    resolve_args = None

    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--check":
            check_mode = True
            i += 1
        elif a == "--root":
            if i + 1 >= len(argv):
                die("--root requires a value")
            root = argv[i + 1]
            i += 2
        elif a == "--registry":
            if i + 1 >= len(argv):
                die("--registry requires a value")
            registry_path = argv[i + 1]
            i += 2
        elif a == "--targets-file":
            if i + 1 >= len(argv):
                die("--targets-file requires a value")
            targets_path = argv[i + 1]
            i += 2
        elif a == "--resolve-target-raw":
            if i + 2 >= len(argv):
                die("--resolve-target-raw requires RELPATH and 0|1")
            resolve_raw_args = (argv[i + 1], argv[i + 2])
            i += 3
        elif a == "--resolve-target":
            if i + 3 >= len(argv):
                die("--resolve-target requires ROLE KIND RELPATH")
            resolve_args = (argv[i + 1], argv[i + 2], argv[i + 3])
            i += 4
        else:
            die(f"unknown argument: {a}")

    if root is None:
        root = default_root
    root = os.path.realpath(root)

    if resolve_raw_args is not None:
        relpath, protected_flag = resolve_raw_args
        if protected_flag not in ("0", "1"):
            die("--resolve-target-raw's Protected flag must be 0 or 1")
        print(resolve_write_target_raw(root, relpath, protected_flag == "1"))
        return 0

    targets = DEFAULT_TARGETS
    if targets_path:
        with open(targets_path, encoding="utf-8") as fh:
            targets = json.load(fh)

    if resolve_args is not None:
        role, kind, relpath = resolve_args
        print(resolve_write_target(root, targets, role, kind, relpath))
        return 0

    if registry_path is None:
        registry_path = os.path.join(root, "contracts/agent-model-capabilities.v2.json")
    registry = load_registry(registry_path)
    manifest_path = os.path.join(root, HUMAN_COPY_RELDIR, "MANIFEST.sha256")

    results = [render_target(root, registry, t, manifest_path, check_mode) for t in targets]

    if check_mode:
        drift_count = 0
        for r in results:
            status = "DRIFT" if r["drift"] else "OK"
            tag = " (protected, read-only)" if r["protected"] else ""
            print(f"{status}: {r['relpath']}{tag}")
            if r["drift"]:
                drift_count += 1
        print(f"---- check summary: {len(results)} targets, {drift_count} drift ----")
        return 1 if drift_count > 0 else 0

    for r in results:
        if r["protected"]:
            tag = "(changed)" if r["changed"] else "(unchanged)"
            print(f"STAGED: {r['relpath']} -> {r['staged']} {tag}")
        else:
            tag = "(changed)" if r["changed"] else "(unchanged)"
            print(f"RENDERED: {r['relpath']} {tag}")
    return 0


sys.exit(main())
PY
