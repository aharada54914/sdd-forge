#!/bin/sh
# Generate a hash-verified evidence bundle for a quality-gate task.
# Usage: generate-evidence-bundle.sh <verification-contract.json> <quality-report.md> [repo-root] [output-path]
#
# Reads the contract JSON, computes SHA256 for all referenced artifacts, records
# the current git HEAD commit, and writes a bundle JSON that check-evidence-bundle
# can validate deterministically.
#
# repo-root  default: .
# output-path default: <dir-of-contract>/<task_id>.evidence.json

contract_file="$1"
quality_report_file="$2"
root="${3:-.}"
output_path_arg="$4"
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"

if [ -z "$contract_file" ] || [ -z "$quality_report_file" ]; then
  echo "Usage: generate-evidence-bundle.sh <verification-contract.json> <quality-report.md> [repo-root] [output-path]" >&2
  exit 1
fi

if [ ! -f "$contract_file" ]; then
  echo "generate-evidence-bundle: contract file not found: $contract_file" >&2
  exit 1
fi

if [ ! -f "$quality_report_file" ]; then
  echo "generate-evidence-bundle: quality report not found: $quality_report_file" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  CONTRACT="$contract_file" REPORT="$quality_report_file" ROOT="$root" OUT_ARG="$output_path_arg" \
    python3 - <<'PYEOF'
import hashlib
import hmac
import json
import os
import pathlib
import re
import subprocess
import sys

contract_path = os.environ["CONTRACT"]
report_path = os.environ["REPORT"]
root_arg = os.environ["ROOT"]
out_arg = os.environ.get("OUT_ARG", "")

abs_root = pathlib.Path(root_arg).resolve()

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

def sha256_file(path):
    hasher = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(8192), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def normalize_rel_path(abs_path, abs_root):
    """Return a normalized relative path from abs_root with forward slashes."""
    p = pathlib.Path(abs_path).resolve()
    try:
        rel = p.relative_to(abs_root)
    except ValueError:
        raise ValueError(f"Path {abs_path} is outside repo root {abs_root}")
    # Convert to forward-slash, no leading ./
    parts = rel.parts
    result = "/".join(parts)
    # Guard against empty or path traversal (should not happen after relative_to)
    if not result or ".." in result.split("/"):
        raise ValueError(f"Unsafe relative path: {result}")
    return result


# ------------------------------------------------------------------
# Parse contract
# ------------------------------------------------------------------

try:
    with open(contract_path, encoding="utf-8") as fh:
        contract = json.load(fh)
except Exception as exc:
    print(f"generate-evidence-bundle: cannot parse contract: {exc}", file=sys.stderr)
    sys.exit(1)

task_id = str(contract.get("task_id", "")).strip()
if not re.fullmatch(r"T-\d+", task_id):
    print(f"generate-evidence-bundle: invalid task_id in contract: {task_id}", file=sys.stderr)
    sys.exit(1)

feature = str(contract.get("feature", "")).strip()

# Extract risk and required_workflow from contract (may be absent for legacy bundles)
contract_risk = str(contract.get("risk", "")).strip()
contract_required_workflow = str(contract.get("required_workflow", "")).strip()

# ------------------------------------------------------------------
# Determine output path
# ------------------------------------------------------------------

if out_arg:
    output_path = pathlib.Path(out_arg)
else:
    contract_dir = pathlib.Path(contract_path).resolve().parent
    output_path = contract_dir / f"{task_id}.evidence.json"

# ------------------------------------------------------------------
# Build artifact list (deduplicated, relative paths)
# ------------------------------------------------------------------

seen_paths = {}  # normalized rel-path -> abs path

def add_artifact(abs_path, label):
    p = pathlib.Path(abs_path).resolve()
    if not p.exists():
        print(f"generate-evidence-bundle: {label} not found: {abs_path}", file=sys.stderr)
        sys.exit(1)
    if not p.is_file():
        print(f"generate-evidence-bundle: {label} is not a regular file: {abs_path}", file=sys.stderr)
        sys.exit(1)
    try:
        rel = normalize_rel_path(p, abs_root)
    except ValueError as exc:
        print(f"generate-evidence-bundle: {exc}", file=sys.stderr)
        sys.exit(1)
    if rel not in seen_paths:
        seen_paths[rel] = str(p)

add_artifact(pathlib.Path(contract_path).resolve(), "verification_contract")
add_artifact(pathlib.Path(report_path).resolve(), "quality_report")

for check in contract.get("checks", []):
    if bool(check.get("passes")):
        evidence = str(check.get("evidence", "")).strip()
        if evidence:
            # evidence paths in the contract are relative to repo root
            abs_ev = (abs_root / pathlib.Path(evidence)).resolve()
            add_artifact(abs_ev, f"passing evidence for check '{check.get('id', '?')}'")

# Build artifacts array in deterministic order (contract first, report second, rest sorted)
contract_rel = normalize_rel_path(pathlib.Path(contract_path).resolve(), abs_root)
report_rel = normalize_rel_path(pathlib.Path(report_path).resolve(), abs_root)
ordered_paths = []
if contract_rel in seen_paths:
    ordered_paths.append(contract_rel)
if report_rel in seen_paths and report_rel not in ordered_paths:
    ordered_paths.append(report_rel)
for rel in sorted(seen_paths.keys()):
    if rel not in ordered_paths:
        ordered_paths.append(rel)

artifacts = []
for rel in ordered_paths:
    abs_p = seen_paths[rel]
    sha = sha256_file(abs_p)
    artifacts.append({"path": rel, "sha256": sha})

# ------------------------------------------------------------------
# git binding
# ------------------------------------------------------------------

git_cmd = ["git", "-C", str(abs_root)]

try:
    r = subprocess.run(git_cmd + ["rev-parse", "HEAD"], capture_output=True, text=True)
except FileNotFoundError:
    print("generate-evidence-bundle: git is not available", file=sys.stderr)
    sys.exit(1)

if r.returncode != 0:
    print(f"generate-evidence-bundle: not a git repository or git error: {r.stderr.strip()}", file=sys.stderr)
    sys.exit(1)

git_commit = r.stdout.strip()
if not re.fullmatch(r"[0-9a-f]{40}", git_commit):
    print(f"generate-evidence-bundle: unexpected git HEAD format: {git_commit}", file=sys.stderr)
    sys.exit(1)

try:
    status_r = subprocess.run(git_cmd + ["status", "--porcelain"], capture_output=True, text=True)
except Exception as exc:
    print(f"generate-evidence-bundle: git status failed: {exc}", file=sys.stderr)
    sys.exit(1)

git_generated_dirty = bool(status_r.stdout.strip())

# ------------------------------------------------------------------
# Compute quality_report and verification_contract relative paths
# ------------------------------------------------------------------

quality_report_rel = normalize_rel_path(pathlib.Path(report_path).resolve(), abs_root)
verification_contract_rel = normalize_rel_path(pathlib.Path(contract_path).resolve(), abs_root)

# ------------------------------------------------------------------
# Compute spec_revision (sha256 over spec files)
# ------------------------------------------------------------------

def compute_spec_revision(feature_slug, abs_root):
    """
    Compute SHA256 over the concatenated bytes of:
    specs/<feature>/requirements.md, design.md, acceptance-tests.md
    (in that order, files that exist).
    Returns 64-char hex string, or "" if no files found.
    """
    spec_files = [
        abs_root / "specs" / feature_slug / "requirements.md",
        abs_root / "specs" / feature_slug / "design.md",
        abs_root / "specs" / feature_slug / "acceptance-tests.md",
    ]
    hasher = hashlib.sha256()
    found_any = False
    for spec_file in spec_files:
        if spec_file.exists() and spec_file.is_file():
            with open(spec_file, "rb") as fh:
                hasher.update(fh.read())
            found_any = True
    return hasher.hexdigest() if found_any else ""


spec_revision = compute_spec_revision(feature, abs_root)

# ------------------------------------------------------------------
# Parse review_verdict from quality report
# ------------------------------------------------------------------

def parse_review_verdict(report_path):
    """
    Parse quality report markdown for:
    - VERDICT: <verdict> line
    - Critical: <N>, Major: <N>, Minor: <N> lines
    Returns dict { "verdict": "...", "critical": N, "major": N, "minor": N, "reviewer": "sdd-evaluator" }
    """
    verdict = ""
    critical = 0
    major = 0
    minor = 0
    try:
        with open(report_path, encoding="utf-8") as fh:
            content = fh.read()
        # Match VERDICT line
        m = re.search(r"(?m)^VERDICT:\s*(\S+)", content)
        if m:
            verdict = m.group(1)
        # Match Critical/Major/Minor lines
        for line in content.split("\n"):
            if m := re.search(r"^Critical:\s*(\d+)", line):
                critical = int(m.group(1))
            if m := re.search(r"^Major:\s*(\d+)", line):
                major = int(m.group(1))
            if m := re.search(r"^Minor:\s*(\d+)", line):
                minor = int(m.group(1))
    except Exception:
        pass
    return {
        "verdict": verdict,
        "critical": critical,
        "major": major,
        "minor": minor,
        "reviewer": "sdd-evaluator",
    }


review_verdict = parse_review_verdict(report_path)

# ------------------------------------------------------------------
# Build build_env
# ------------------------------------------------------------------

import platform
import subprocess as sp_import

build_env = {
    "os": platform.system().lower(),
    "python": f"{platform.python_version()}",
    "git": "",
    "lockfile_sha256": None,
}

try:
    git_version_r = subprocess.run(["git", "--version"], capture_output=True, text=True)
    if git_version_r.returncode == 0:
        build_env["git"] = git_version_r.stdout.strip()
except Exception:
    pass

# ------------------------------------------------------------------
# Build builder
# ------------------------------------------------------------------

builder_kind = "ci" if os.environ.get("CI") or os.environ.get("GITHUB_ACTIONS") else "local"
builder_id = os.environ.get("GITHUB_RUN_ID") or os.environ.get("USER", "unknown")
builder_runtime = os.environ.get("SDD_RUNTIME", "unknown")

builder = {
    "kind": builder_kind,
    "id": builder_id,
    "runtime": builder_runtime,
}

# ------------------------------------------------------------------
# Signing helpers (T-007a)
# ------------------------------------------------------------------

def _strip_key_bytes(raw):
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    return raw.rstrip(b" \t\r\n")

def resolve_evidence_key():
    env_key = os.environ.get("SDD_EVIDENCE_KEY")
    if env_key:
        return env_key.encode("utf-8"), "env:SDD_EVIDENCE_KEY"
    env_file = os.environ.get("SDD_EVIDENCE_KEY_FILE")
    if env_file:
        try:
            with open(env_file, "rb") as f:
                raw = _strip_key_bytes(f.read())
            if raw:
                return raw, "file:" + env_file
        except OSError:
            pass
        return None, None
    home = os.environ.get("HOME") or os.environ.get("USERPROFILE", "")
    if home:
        key_path = os.path.join(home, ".sdd", "evidence-key")
        try:
            with open(key_path, "rb") as f:
                raw = _strip_key_bytes(f.read())
            if raw:
                return raw, "file:~/.sdd/evidence-key"
        except OSError:
            pass
    return None, None

def evidence_canonical(bundle):
    def s(v):
        return str(v if v is not None else "").strip()
    artifacts = bundle.get("artifacts") or []
    pairs = []
    for a in artifacts:
        p = str((a or {}).get("path", "")).strip()
        sh = str((a or {}).get("sha256", "")).strip().lower()
        pairs.append(p + "\x00" + sh)
    pairs.sort()
    artifacts_digest = hashlib.sha256("\n".join(pairs).encode("utf-8")).hexdigest()
    dirty = bundle.get("git_generated_dirty")
    dirty_str = "true" if dirty is True else "false"
    rv = bundle.get("review_verdict")
    verdict = str(rv.get("verdict", "")).strip() if isinstance(rv, dict) else ""
    lines = [
        "sdd-evidence-v1",
        s(bundle.get("task_id")),
        s(bundle.get("feature")),
        s(bundle.get("risk")),
        s(bundle.get("required_workflow")),
        s(bundle.get("spec_revision")),
        s(bundle.get("git_commit")),
        dirty_str,
        verdict,
        artifacts_digest,
    ]
    return "\n".join(lines)

# ------------------------------------------------------------------
# Write bundle
# ------------------------------------------------------------------

bundle = {
    "task_id": task_id,
    "feature": feature,
    "risk": contract_risk,
    "required_workflow": contract_required_workflow,
    "spec_revision": spec_revision,
    "quality_report": quality_report_rel,
    "verification_contract": verification_contract_rel,
    "git_commit": git_commit,
    "git_generated_dirty": git_generated_dirty,
    "build_env": build_env,
    "builder": builder,
    "review_verdict": review_verdict,
    "artifacts": artifacts,
}

# Sign critical bundles (T-007a)
if contract_risk == "critical":
    key_bytes, key_ref = resolve_evidence_key()
    if key_bytes is None:
        print("generate-evidence-bundle: risk=critical requires an evidence signing key "
              "(SDD_EVIDENCE_KEY / SDD_EVIDENCE_KEY_FILE / ~/.sdd/evidence-key); none found",
              file=sys.stderr)
        sys.exit(1)
    canonical = evidence_canonical(bundle)
    value = hmac.new(key_bytes, canonical.encode("utf-8"), hashlib.sha256).hexdigest()
    bundle["signature"] = {"alg": "hmac-sha256", "value": value, "key_ref": key_ref}

output_path.parent.mkdir(parents=True, exist_ok=True)
with open(output_path, "w", encoding="utf-8") as fh:
    json.dump(bundle, fh, indent=2)
    fh.write("\n")

artifact_count = len(artifacts)
print(str(output_path))
print(f"Generated evidence bundle for {task_id}: {artifact_count} artifact(s), commit {git_commit[:12]}{'  [dirty]' if git_generated_dirty else ''}")
PYEOF
  exit $?
fi

dir="$(dirname "$0")"
for ps in pwsh powershell.exe powershell; do
  if command -v "$ps" >/dev/null 2>&1; then
    "$ps" -NoProfile -ExecutionPolicy Bypass -File "$dir/generate-evidence-bundle.ps1" \
      -ContractPath "$contract_file" -QualityReport "$quality_report_file" \
      -RepoRoot "$root" ${output_path_arg:+-OutputPath "$output_path_arg"}
    exit $?
  fi
done

echo "generate-evidence-bundle: needs python3 or PowerShell. Install one, or run generate-evidence-bundle.ps1 directly." >&2
exit 1
