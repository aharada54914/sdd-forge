#!/usr/bin/env python3
"""Capability Resolver, implementation stage T-002 (steps 0-3).

This staged candidate validates CLI input, derives Resolver state, obtains a
single canonical Project Context snapshot, and assembles/canonicalizes the
Context Projection in memory. Later task stages extend the same Python master
with affected-component resolution, evaluation, assembly, and publication.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile


EXIT_BLOCK = 1
EXIT_USAGE = 2
FEATURE_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
EVIDENCE_SCHEMA = "sdd-resolver-evidence/v1"


class CanonicalizerFailed(Exception):
    pass


class CanonicalizerOutputMalformed(Exception):
    pass


def _reject_json_constant(token):
    raise ValueError(f"non-standard JSON constant {token}")


def _parse_args(argv):
    parser = argparse.ArgumentParser(prog="resolve-project-context.py")
    parser.add_argument("--config", required=True)
    parser.add_argument("--source-rev", default="HEAD")
    parser.add_argument("--target-rev", required=True)
    parser.add_argument("--include-untracked", action="store_true")
    parser.add_argument("--feature", required=True)
    args = parser.parse_args(argv)
    if not FEATURE_RE.fullmatch(args.feature):
        parser.error("--feature must match ^[a-z0-9][a-z0-9-]*$")
    return args


def _find_repo_root(config_path):
    candidate = config_path if config_path.is_absolute() else Path.cwd() / config_path
    for parent in (candidate.parent, *candidate.parent.parents):
        if (parent / ".git").exists():
            return parent
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=Path.cwd(), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            check=False,
        )
    except OSError:
        result = None
    if result is not None and result.returncode == 0:
        return Path(result.stdout.decode("utf-8").strip())
    return Path.cwd()


def _canonicalizer_argv(input_path, input_format):
    script_dir = Path(__file__).resolve().parent
    python_master = script_dir / "canonicalize-sdd-yaml.py"
    shell_wrapper = script_dir / "canonicalize-sdd-yaml.sh"
    if python_master.is_file():
        return [sys.executable, str(python_master), str(input_path), "--input-format", input_format]
    if shell_wrapper.is_file():
        return [str(shell_wrapper), str(input_path), "--input-format", input_format]
    return ["canonicalize-sdd-yaml", str(input_path), "--input-format", input_format]


def _canonicalize(input_path, input_format):
    try:
        result = subprocess.run(
            _canonicalizer_argv(input_path, input_format),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
    except OSError as exc:
        raise CanonicalizerFailed(str(exc)) from exc
    if result.returncode != 0:
        raise CanonicalizerFailed(f"exit {result.returncode}")
    try:
        text = result.stdout.decode("utf-8")
        parsed = json.loads(text, parse_constant=_reject_json_constant)
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        raise CanonicalizerOutputMalformed(str(exc)) from exc
    return result.stdout, parsed


def _json_type_matches(value, expected):
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    return True


def _schema_errors(value, schema, pointer="$"):
    errors = []
    if "const" in schema and value != schema["const"]:
        errors.append(f"{pointer}: const mismatch")
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{pointer}: enum mismatch")
    expected_type = schema.get("type")
    if expected_type and not _json_type_matches(value, expected_type):
        return errors + [f"{pointer}: type mismatch"]
    if isinstance(value, str) and len(value) < schema.get("minLength", 0):
        errors.append(f"{pointer}: minLength mismatch")
    if isinstance(value, dict):
        properties = schema.get("properties", {})
        for required in schema.get("required", []):
            if required not in value:
                errors.append(f"{pointer}: missing {required}")
        if schema.get("additionalProperties") is False:
            for key in value:
                if key not in properties:
                    errors.append(f"{pointer}: additional property {key}")
        for key, child in value.items():
            if key in properties:
                errors.extend(_schema_errors(child, properties[key], f"{pointer}/{key}"))
    if isinstance(value, list) and "items" in schema:
        for index, child in enumerate(value):
            errors.extend(_schema_errors(child, schema["items"], f"{pointer}/{index}"))
    if "oneOf" in schema:
        matches = sum(not _schema_errors(value, branch, pointer) for branch in schema["oneOf"])
        if matches != 1:
            errors.append(f"{pointer}: oneOf mismatch")
    return errors


def _project_context_valid(document, repo_root):
    schema_path = repo_root / "contracts/project-context.schema.json"
    try:
        with schema_path.open("r", encoding="utf-8") as handle:
            schema = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return False
    return not _schema_errors(document, schema)


def _write_evidence(repo_root, feature, diagnostic_id, detail, state_marker):
    evidence = {
        "schema": EVIDENCE_SCHEMA,
        "feature": feature,
        "capability_evaluations": [],
        "diagnostics": [{"id": diagnostic_id, "detail": detail, "severity": "block"}],
    }
    if state_marker is not None:
        evidence["state"] = state_marker
    target = repo_root / "specs" / feature / "resolver-evidence.yaml"
    target.parent.mkdir(parents=True, exist_ok=True)
    payload = (json.dumps(evidence, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    fd, temp_name = tempfile.mkstemp(prefix=".resolver-evidence-", dir=str(target.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temp_name, target)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def _block(repo_root, feature, diagnostic_id, detail, state_marker):
    _write_evidence(repo_root, feature, diagnostic_id, detail, state_marker)
    sys.stderr.write(f"capability-resolver: {diagnostic_id}: {detail}\n")
    return EXIT_BLOCK


def _projection(document, source_sha256):
    components = {}
    for component in document.get("components", []):
        components[component["id"]] = {key: value for key, value in component.items() if key != "id"}
    return {
        "schema": "sdd-context-projection/v1",
        "source_sha256": source_sha256,
        "workflow": document["workflow"],
        "components": components,
        "shared_paths": document.get("shared_paths", []),
    }


def main(argv=None):
    args = _parse_args(argv)
    config_path = Path(args.config)
    absolute_config = config_path if config_path.is_absolute() else Path.cwd() / config_path
    repo_root = _find_repo_root(absolute_config)

    if not absolute_config.is_file():
        return _block(repo_root, args.feature, "disabled-legacy-invocation", args.config, "disabled-legacy")

    try:
        canonical_context, document = _canonicalize(absolute_config, "yaml")
    except CanonicalizerFailed:
        return _block(
            repo_root, args.feature, "canonicalizer-invocation-failed",
            "canonicalize-sdd-yaml failed while canonicalizing project context", None,
        )
    except CanonicalizerOutputMalformed:
        return _block(
            repo_root, args.feature, "dependency-output-malformed",
            "canonicalize-sdd-yaml returned malformed JSON while canonicalizing project context", None,
        )

    if not _project_context_valid(document, repo_root):
        return _block(
            repo_root, args.feature, "project-context-validation-failed",
            "project context does not conform to contracts/project-context.schema.json", None,
        )

    workflow = document["workflow"]
    state = workflow["capability_enforcement"]
    invalid = (
        workflow["spec_profile"] == "lite" and workflow["artifact_layout"] != "lite-three-file"
    ) or (
        workflow["spec_profile"] == "full" and workflow["artifact_layout"] == "lite-three-file"
    )
    if invalid:
        return _block(
            repo_root, args.feature, "workflow-combination-invalid",
            "workflow spec_profile/artifact_layout combination is invalid", state,
        )

    source_sha256 = "sha256:" + hashlib.sha256(canonical_context).hexdigest()
    projection = _projection(document, source_sha256)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".json", delete=False, newline="\n") as handle:
        json.dump(projection, handle, ensure_ascii=False, separators=(",", ":"))
        projection_input = Path(handle.name)
    try:
        try:
            canonical_projection, parsed_projection = _canonicalize(projection_input, "json")
        except CanonicalizerFailed:
            return _block(
                repo_root, args.feature, "canonicalizer-invocation-failed",
                "canonicalize-sdd-yaml failed while canonicalizing context projection", state,
            )
        except CanonicalizerOutputMalformed:
            return _block(
                repo_root, args.feature, "dependency-output-malformed",
                "canonicalize-sdd-yaml returned malformed JSON while canonicalizing context projection", state,
            )
    finally:
        projection_input.unlink(missing_ok=True)

    # T-002 owns staging only. These values are deliberately retained in
    # memory for the next implementation stage and never written live here.
    _staged_context_snapshot = canonical_context
    _staged_projection = canonical_projection
    _staged_projection_document = parsed_projection
    _projection_sha256 = "sha256:" + hashlib.sha256(canonical_projection).hexdigest()
    del _staged_context_snapshot, _staged_projection, _staged_projection_document, _projection_sha256
    return 0


if __name__ == "__main__":
    sys.exit(main())
