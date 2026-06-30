#!/usr/bin/env bash
set -euo pipefail

manifest=""
snapshot_root=""
expected_task=""
evidence_root=""
batch=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      manifest="${2:-}"
      shift 2
      ;;
    --snapshot-root)
      snapshot_root="${2:-}"
      shift 2
      ;;
    --expected-task)
      expected_task="${2:-}"
      shift 2
      ;;
    --evidence-root)
      evidence_root="${2:-}"
      shift 2
      ;;
    --batch)
      shift
      while [[ $# -gt 0 ]]; do
        batch+=("$1")
        shift
      done
      ;;
    *)
      printf 'TASK_INPUT_JSON: unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

python3 - "$manifest" "$snapshot_root" "$expected_task" "$evidence_root" "${batch[@]}" <<'PY'
import hashlib
import json
import datetime
import os
import re
import stat
import sys

manifest, snapshot_root, expected_task, evidence_root, *batch = sys.argv[1:]
REQUIRED = (
    "schema", "task_id", "run_id", "session_id", "agent_instance_id",
    "model_tier", "provider", "model", "estimated_cost_per_attempt_usd",
    "cost_estimate_source", "cost_estimate_timestamp", "isolation_mode",
    "fallback_reason", "handoff_reload_evidence_hash", "allowed_inputs",
    "allowed_outputs",
)
IDENTITY = {"task_id", "run_id", "session_id", "agent_instance_id"}
MODEL = {"model_tier", "provider", "model"}
COST = {"estimated_cost_per_attempt_usd", "cost_estimate_source", "cost_estimate_timestamp"}
SHA = re.compile(r"^[a-f0-9]{64}$")
DECIMAL = re.compile(r"^(0|[1-9][0-9]*)(\.[0-9]+)?$")
TIMESTAMP = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
TASK = re.compile(r"^T-\d{3}$")
ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]*$")
FALLBACK_REASON = "host-does-not-support-implementation-subagents"
EVIDENCE_PATH = "handoffs/reload-evidence.txt"

def fail(code, message):
    print(f"TASK_INPUT_{code}: {message}", file=sys.stderr)
    sys.exit(1)

def load(path):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            value = json.load(handle)
    except Exception as exc:
        fail("JSON", str(exc))
    if not isinstance(value, dict):
        fail("JSON", "manifest must be an object")
    return value

def path_ok(path, output=False):
    if not isinstance(path, str) or not path:
        return False
    if path.startswith("/") or "\\" in path:
        return False
    parts = path.rstrip("/").split("/")
    if any(part in ("", ".", "..") for part in parts):
        return False
    return re.match(r"^[A-Za-z0-9][A-Za-z0-9._/-]*$", path) is not None

def timestamp_ok(value):
    if not isinstance(value, str) or not TIMESTAMP.match(value):
        return False
    try:
        parsed = datetime.datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        return False
    canonical = (
        f"{parsed.year:04d}-{parsed.month:02d}-{parsed.day:02d}T"
        f"{parsed.hour:02d}:{parsed.minute:02d}:{parsed.second:02d}Z"
    )
    return value == canonical

def paths_overlap(first, second):
    first = first.rstrip("/")
    second = second.rstrip("/")
    return (
        first == second
        or first.startswith(second + "/")
        or second.startswith(first + "/")
    )

def open_snapshot_input(root, rel):
    try:
        root_info = os.lstat(root)
        if stat.S_ISLNK(root_info.st_mode) or not stat.S_ISDIR(root_info.st_mode):
            fail("PATH", "snapshot root is missing or unsafe")
        current_fd = os.open(
            root,
            os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0),
        )
        parts = rel.split("/")
        for part in parts[:-1]:
            next_fd = os.open(
                part,
                os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0),
                dir_fd=current_fd,
            )
            os.close(current_fd)
            current_fd = next_fd
        file_fd = os.open(
            parts[-1],
            os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0),
            dir_fd=current_fd,
        )
        os.close(current_fd)
        info = os.fstat(file_fd)
        if not stat.S_ISREG(info.st_mode):
            os.close(file_fd)
            fail("PATH", f"snapshot input missing or unsafe: {rel}")
        return file_fd
    except OSError:
        try:
            os.close(current_fd)
        except (NameError, OSError):
            pass
        fail("PATH", f"snapshot input missing or unsafe: {rel}")

def load_reload_evidence(data, bind_manifest=True):
    try:
        file_fd = open_snapshot_input(evidence_root, EVIDENCE_PATH)
        with os.fdopen(file_fd, "rb") as handle:
            payload = handle.read()
    except SystemExit:
        raise
    if hashlib.sha256(payload).hexdigest() != data["handoff_reload_evidence_hash"]:
        fail("HANDOFF", "fallback evidence artifact hash mismatch")
    try:
        evidence = json.loads(payload.decode("utf-8"))
    except Exception:
        fail("HANDOFF", "fallback evidence artifact is not valid UTF-8 JSON")
    expected_keys = {
        "schema", "implementation_subagents_available", "fallback_reason",
        "session_id", "agent_instance_id", "task_runs",
    }
    if not isinstance(evidence, dict) or set(evidence) != expected_keys:
        fail("HANDOFF", "fallback evidence artifact has invalid fields")
    if (
        evidence["schema"] != "implementation-host-capability/v1"
        or evidence["implementation_subagents_available"] is not False
        or evidence["fallback_reason"] != FALLBACK_REASON
        or evidence["session_id"] != data["session_id"]
        or evidence["agent_instance_id"] != data["agent_instance_id"]
    ):
        fail("HANDOFF", "fallback evidence does not prove incapable-host identity")
    task_runs = evidence["task_runs"]
    if not isinstance(task_runs, list) or not task_runs:
        fail("HANDOFF", "fallback evidence task_runs must be non-empty")
    pairs = []
    for entry in task_runs:
        if (
            not isinstance(entry, dict)
            or set(entry) != {"task_id", "run_id"}
            or not isinstance(entry["task_id"], str)
            or not TASK.match(entry["task_id"])
            or not isinstance(entry["run_id"], str)
            or not ID.match(entry["run_id"])
        ):
            fail("HANDOFF", "fallback evidence contains invalid task/run identity")
        pair = (entry["task_id"], entry["run_id"])
        if pair in pairs:
            fail("HANDOFF", "fallback evidence contains duplicate task/run identity")
        pairs.append(pair)
    if bind_manifest and (data["task_id"], data["run_id"]) not in pairs:
        fail("HANDOFF", "fallback evidence does not bind manifest task/run identity")
    return evidence

def validate_one(path, check_snapshot=False, batch_validation=False):
    data = load(path)
    keys = set(data)
    extra = keys - set(REQUIRED)
    if extra:
        fail("JSON", f"unexpected field: {sorted(extra)[0]}")
    missing = [field for field in REQUIRED if field not in keys]
    if missing:
        missing_field = missing[0]
        if missing_field in COST:
            fail("COST", f"missing field: {missing_field}")
        if missing_field in IDENTITY:
            fail("IDENTITY", f"missing field: {missing_field}")
        if missing_field in MODEL:
            fail("MODEL", f"missing field: {missing_field}")
        fail("JSON", f"missing field: {missing_field}")
    if data["schema"] != "task-input-manifest/v1":
        fail("JSON", "unsupported schema")
    if not isinstance(data["task_id"], str) or not TASK.match(data["task_id"]):
        fail("IDENTITY", "invalid task_id")
    if expected_task and data["task_id"] != expected_task:
        fail("IDENTITY", "task_id does not match expected task")
    for field in ("run_id", "session_id", "agent_instance_id"):
        if not isinstance(data[field], str) or not ID.match(data[field]):
            fail("IDENTITY", f"invalid {field}")
    if data["model_tier"] not in ("lightweight", "standard", "strong"):
        fail("MODEL", "invalid model_tier")
    for field in ("provider", "model"):
        if not isinstance(data[field], str) or not ID.match(data[field]):
            fail("MODEL", f"invalid {field}")
    if not isinstance(data["estimated_cost_per_attempt_usd"], str) or not DECIMAL.match(data["estimated_cost_per_attempt_usd"]):
        fail("COST", "invalid estimated_cost_per_attempt_usd")
    if not isinstance(data["cost_estimate_source"], str) or not data["cost_estimate_source"]:
        fail("COST", "missing cost_estimate_source")
    if not timestamp_ok(data["cost_estimate_timestamp"]):
        fail("COST", "invalid cost_estimate_timestamp")
    mode = data["isolation_mode"]
    if mode not in ("fresh-agent", "same-session-file-reload"):
        fail("ISOLATION", "invalid isolation_mode")
    if mode == "fresh-agent":
        if data["fallback_reason"] != "" or data["handoff_reload_evidence_hash"] != "":
            fail("ISOLATION", "fresh-agent forbids fallback fields")
    else:
        if data["fallback_reason"] != FALLBACK_REASON:
            fail("HANDOFF", "same-session fallback requires incapable-host reason")
        if not isinstance(data["handoff_reload_evidence_hash"], str) or not SHA.match(data["handoff_reload_evidence_hash"]):
            fail("HANDOFF", "same-session fallback requires handoff_reload_evidence_hash")
    if not isinstance(data["allowed_inputs"], list) or not data["allowed_inputs"]:
        fail("PATH", "allowed_inputs must be non-empty")
    if not isinstance(data["allowed_outputs"], list) or not data["allowed_outputs"]:
        fail("PATH", "allowed_outputs must be non-empty")
    seen_inputs = set()
    for entry in data["allowed_inputs"]:
        if not isinstance(entry, dict) or set(entry) != {"path", "sha256"}:
            fail("PATH", "invalid allowed_inputs entry")
        rel = entry["path"]
        if not path_ok(rel) or rel.endswith("/"):
            fail("PATH", f"invalid input path: {rel}")
        if rel in seen_inputs:
            fail("PATH", f"duplicate input path: {rel}")
        seen_inputs.add(rel)
        if not isinstance(entry["sha256"], str) or not SHA.match(entry["sha256"]):
            fail("HASH", f"invalid sha256 for {rel}")
        if check_snapshot:
            digest = hashlib.sha256()
            file_fd = open_snapshot_input(snapshot_root, rel)
            with os.fdopen(file_fd, "rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
            if digest.hexdigest() != entry["sha256"]:
                fail("HASH", f"snapshot hash mismatch: {rel}")
    if mode == "same-session-file-reload":
        evidence_entries = [
            entry for entry in data["allowed_inputs"]
            if entry["path"] == EVIDENCE_PATH
        ]
        if len(evidence_entries) != 1:
            fail("HANDOFF", f"fallback requires allowed input: {EVIDENCE_PATH}")
        if evidence_entries[0]["sha256"] != data["handoff_reload_evidence_hash"]:
            fail("HANDOFF", "fallback evidence hash does not match allowed input")
        if not evidence_root:
            fail("HANDOFF", "fallback evidence root is required")
        load_reload_evidence(data, not batch_validation)
    seen_outputs = set()
    for rel in data["allowed_outputs"]:
        if not path_ok(rel, output=True):
            fail("PATH", f"invalid output path: {rel}")
        if rel in seen_outputs:
            fail("PATH", f"duplicate output path: {rel}")
        if any(paths_overlap(rel, input_path) for input_path in seen_inputs):
            fail("PATH", f"output overlaps input path: {rel}")
        if any(paths_overlap(rel, output_path) for output_path in seen_outputs):
            fail("PATH", f"output overlaps output path: {rel}")
        seen_outputs.add(rel)
    return data

def validate_batch(paths):
    task_ids, run_ids, fresh_sessions, fresh_agents = set(), set(), set(), set()
    modes, fallback_reasons, fallback_hashes = set(), set(), set()
    fallback_sessions, fallback_agents = set(), set()
    expected_pairs = set()
    for path in paths:
        data = validate_one(path, False, True)
        modes.add(data["isolation_mode"])
        if len(modes) != 1:
            fail("ISOLATION", "batch cannot mix fresh-agent and same-session fallback")
        for field, seen in (("task_id", task_ids), ("run_id", run_ids)):
            if data[field] in seen:
                fail("IDENTITY", f"duplicate {field}: {data[field]}")
            seen.add(data[field])
        expected_pairs.add((data["task_id"], data["run_id"]))
        if data["isolation_mode"] == "fresh-agent":
            if data["session_id"] in fresh_sessions:
                fail("IDENTITY", f"duplicate session_id: {data['session_id']}")
            if data["agent_instance_id"] in fresh_agents:
                fail("IDENTITY", f"duplicate agent_instance_id: {data['agent_instance_id']}")
            fresh_sessions.add(data["session_id"])
            fresh_agents.add(data["agent_instance_id"])
        else:
            fallback_reasons.add(data["fallback_reason"])
            fallback_hashes.add(data["handoff_reload_evidence_hash"])
            fallback_sessions.add(data["session_id"])
            fallback_agents.add(data["agent_instance_id"])
    if modes == {"same-session-file-reload"}:
        if len(fallback_reasons) != 1 or len(fallback_hashes) != 1:
            fail("ISOLATION", "fallback batch must share one capability decision and evidence")
        if len(fallback_sessions) != 1 or len(fallback_agents) != 1:
            fail("IDENTITY", "fallback batch must reuse one physical session and agent")
        evidence = load_reload_evidence(data)
        actual_pairs = {
            (entry["task_id"], entry["run_id"]) for entry in evidence["task_runs"]
        }
        if actual_pairs != expected_pairs:
            fail("HANDOFF", "fallback evidence task_runs do not match complete batch")

if batch:
    validate_batch(batch)
elif manifest:
    validate_one(manifest, bool(snapshot_root))
else:
    fail("JSON", "missing --manifest or --batch")
print("TASK_INPUT_OK")
PY
