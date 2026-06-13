#!/bin/sh
# Deterministic gate: validate a Done evidence bundle.
# Usage: check-evidence-bundle.sh <path-to-evidence-bundle.json> [repo-root]
# The bundle must name a quality report, verification contract, and include
# all passing evidence artifacts from the contract with matching SHA256.

bundle="$1"
root="${2:-.}"
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

if [ -z "$bundle" ] || [ ! -f "$bundle" ]; then
  echo "check-evidence-bundle: evidence bundle not found: $bundle" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  BUNDLE="$bundle" ROOT="$root" SCRIPT_DIR="$script_dir" python3 - <<'PYEOF'
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys

bundle_path = os.environ["BUNDLE"]
root = os.environ["ROOT"]
script_dir = os.environ["SCRIPT_DIR"]
failures = []


def fail(msg):
    failures.append(msg)


def normalize_rel_path(raw, label):
    if raw is None:
        fail(f"{label} is missing")
        return None
    path = str(raw).strip().replace("\\", "/")
    if not path:
        fail(f"{label} is empty")
        return None
    if path.startswith("/") or path.startswith("//") or re.match(r"^[A-Za-z]:", path):
        fail(f"{label} is an absolute path: {raw}")
        return None
    if re.search(r"(^|/)\.\.(/|$)", path):
        fail(f"{label} escapes repo root: {raw}")
        return None
    while path.startswith("./"):
        path = path[2:]
    if not path:
        fail(f"{label} is empty after normalization")
        return None
    return path


def resolve_repo_path(rel_path, label):
    norm = normalize_rel_path(rel_path, label)
    if norm is None:
        return None, None
    abs_root = pathlib.Path(root).resolve()
    resolved = (abs_root / pathlib.Path(norm)).resolve()
    try:
        resolved.relative_to(abs_root)
    except ValueError:
        fail(f"{label} escapes repo root: {rel_path}")
        return None, None
    if not resolved.exists():
        fail(f"{label} missing: {rel_path}")
        return None, None
    if not resolved.is_file():
        fail(f"{label} is not a regular file: {rel_path}")
        return None, None
    return norm, resolved


def sha256_file(path):
    hasher = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(8192), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


with open(bundle_path, encoding="utf-8") as handle:
    bundle = json.load(handle)

task_id = str(bundle.get("task_id", "")).strip()
quality_report = bundle.get("quality_report")
verification_contract = bundle.get("verification_contract")
artifacts = bundle.get("artifacts", [])
git_commit = bundle.get("git_commit")
git_generated_dirty = bundle.get("git_generated_dirty")

if not re.fullmatch(r"T-\d+", task_id):
    fail(f"task_id is invalid: {task_id}")

if not isinstance(artifacts, list):
    fail("artifacts must be an array")
    artifacts = []
elif len(artifacts) == 0:
    fail("artifacts must not be empty")

if pathlib.Path(bundle_path).name != f"{task_id}.evidence.json":
    fail(f"bundle filename does not match task_id: {pathlib.Path(bundle_path).name} vs {task_id}")

quality_norm, quality_abs = resolve_repo_path(quality_report, "quality_report")
contract_norm, contract_abs = resolve_repo_path(verification_contract, "verification_contract")

if quality_abs is not None and not pathlib.Path(quality_abs).name.endswith(".md"):
    fail(f"quality_report must point to a markdown report: {quality_report}")
if contract_abs is not None and not pathlib.Path(contract_abs).name.endswith(".contract.json"):
    fail(f"verification_contract must point to a contract JSON file: {verification_contract}")

contract = None
if quality_abs is not None:
    try:
        quality_text = pathlib.Path(quality_abs).read_text(encoding="utf-8")
    except Exception as exc:
        fail(f"quality_report could not be read: {quality_report} ({exc})")
    else:
        if not re.search(rf"(?m)^Task ID:\s*{re.escape(task_id)}\s*$", quality_text):
            fail(f"quality_report missing Task ID: {task_id}")
        if not re.search(r"(?m)^VERDICT:\s*PASS\s*$", quality_text):
            fail("quality_report missing VERDICT: PASS")

if contract_abs is not None:
    try:
        contract = json.loads(pathlib.Path(contract_abs).read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"verification_contract could not be parsed as JSON: {verification_contract} ({exc})")
    else:
        contract_task = str(contract.get("task_id", "")).strip()
        if contract_task != task_id:
            fail(f"verification_contract task_id mismatch: {contract_task} != {task_id}")

if contract_abs is not None:
    check_script = pathlib.Path(script_dir) / "check-contract.sh"
    if not check_script.exists():
        fail(f"check-contract script not found: {check_script}")
    else:
        result = subprocess.run(["sh", str(check_script), contract_norm, root], cwd=root)
        if result.returncode != 0:
            fail(f"verification_contract failed check-contract validation: {verification_contract}")

required_artifacts = {}
if quality_norm:
    required_artifacts[quality_norm] = "quality_report"
if contract_norm:
    required_artifacts[contract_norm] = "verification_contract"

if contract:
    for check in contract.get("checks", []):
        if bool(check.get("passes")):
            evidence_norm, _ = resolve_repo_path(
                check.get("evidence"),
                f"passing evidence for check '{check.get('id', '?')}'",
            )
            if evidence_norm:
                required_artifacts[evidence_norm] = f"passing evidence for check '{check.get('id', '?')}'"

artifact_index = {}
for artifact in artifacts:
    path_value = artifact.get("path")
    sha_value = str(artifact.get("sha256", "")).strip().lower()
    artifact_norm, artifact_abs = resolve_repo_path(path_value, "artifact path")
    if artifact_norm is None or artifact_abs is None:
        continue
    if not re.fullmatch(r"[a-f0-9]{64}", sha_value):
        fail(f"artifact sha256 is invalid for {path_value}: {artifact.get('sha256')}")
        continue
    if artifact_norm in artifact_index:
        fail(f"duplicate artifact path in manifest: {artifact_norm}")
        continue
    artifact_index[artifact_norm] = sha_value
    if sha256_file(artifact_abs) != sha_value:
        fail(f"artifact sha256 mismatch for {artifact_norm}")

for required_path, label in required_artifacts.items():
    if required_path not in artifact_index:
        fail(f"manifest is missing {label}: {required_path}")

# --- git_commit binding ---
if git_commit is None:
    fail("git_commit is required but missing")
elif not re.fullmatch(r"[0-9a-f]{40}", str(git_commit)):
    fail(f"git_commit is invalid (must be 40 lowercase hex): {git_commit}")
else:
    git_commit_str = str(git_commit)
    import shutil
    if shutil.which("git") is None:
        fail("git is not available; cannot verify git_commit binding")
    else:
        abs_root = str(pathlib.Path(root).resolve())
        # Verify commit exists
        try:
            r1 = subprocess.run(
                ["git", "-C", abs_root, "cat-file", "-e", f"{git_commit_str}^{{commit}}"],
                capture_output=True,
            )
            if r1.returncode != 0:
                fail(f"git_commit does not exist in repository: {git_commit_str}")
            else:
                # Verify commit is HEAD or an ancestor of HEAD
                r2 = subprocess.run(
                    ["git", "-C", abs_root, "merge-base", "--is-ancestor", git_commit_str, "HEAD"],
                    capture_output=True,
                )
                if r2.returncode != 0:
                    fail(f"git_commit is not an ancestor of HEAD (foreign or future commit): {git_commit_str}")
        except Exception as exc:
            fail(f"git verification failed unexpectedly: {exc}")

# --- provenance validation (gated on risk) ---
bundle_risk = str(bundle.get("risk", "")).strip()

# The contract is hash-validated and re-checked, so it is the trusted source of
# the risk tier. The bundle's own risk must agree with it; a stripped or forged
# bundle risk must NOT be able to dodge the provenance requirements.
contract_risk = ""
if isinstance(contract, dict):
    contract_risk = str(contract.get("risk", "")).strip()
if contract_risk and contract_risk != bundle_risk:
    fail(f"bundle risk '{bundle_risk or '(empty)'}' != contract risk '{contract_risk}'")

# Gate provenance on the trusted contract risk; fall back to the bundle risk only
# when the contract carries none (legacy).
effective_risk = contract_risk or bundle_risk

# High/critical tier provenance requirements
if effective_risk in {"high", "critical"}:
    spec_revision = str(bundle.get("spec_revision", "")).strip()
    if not re.fullmatch(r"[a-f0-9]{64}", spec_revision):
        fail(f"high/critical bundle requires spec_revision (64-hex), got: {spec_revision or '(empty)'}")

    build_env = bundle.get("build_env")
    if not isinstance(build_env, dict) or not str(build_env.get("os", "")).strip():
        fail("high/critical bundle requires build_env.os")

    review_verdict = bundle.get("review_verdict")
    if not isinstance(review_verdict, dict):
        fail("high/critical bundle requires review_verdict object")
    elif str(review_verdict.get("verdict", "")).strip() != "PASS":
        fail(f"high/critical bundle requires review_verdict.verdict == PASS, got: {review_verdict.get('verdict', '(empty)')}")

if git_generated_dirty is True:
    print(f"WARNING: evidence bundle for task {task_id} was generated with a dirty working tree")

if failures:
    print(f"Evidence bundle FAILED for task {task_id}:")
    for failure in failures:
        print(f" - {failure}")
    sys.exit(1)

print(f"Evidence bundle passed for task {task_id}.")
PYEOF
  exit $?
fi

dir="$(dirname "$0")"
for ps in pwsh powershell.exe powershell; do
  if command -v "$ps" >/dev/null 2>&1; then
    "$ps" -NoProfile -ExecutionPolicy Bypass -File "$dir/check-evidence-bundle.ps1" -BundlePath "$bundle" -RepoRoot "$root"
    exit $?
  fi
done

echo "check-evidence-bundle: needs python3 or PowerShell. Install one, or run check-evidence-bundle.ps1 directly." >&2
exit 1
