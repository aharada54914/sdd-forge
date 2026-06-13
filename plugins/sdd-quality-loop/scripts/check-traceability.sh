#!/bin/sh
# Deterministic gate: verify requirement traceability (REQ → AC → TEST → evidence).
# Usage: check-traceability.sh <traceability.json> [repo-root] [require-evidence]
# Exit 1 if traceability chain is incomplete or evidence files are missing/invalid.
# This gate fails closed (exit 1) if neither python3 nor PowerShell is available.
# Additional rules enforced:
#  - Every link must have req (non-empty string), acs (array with ≥1 entry), tests (array with ≥1 entry)
#  - If evidence key is present, each entry must be path-safe (reject absolute POSIX "/",
#    Windows drive "X:", UNC "\\\\", and ".." traversal escaping repo-root)
#  - Evidence files must exist, be regular files, and be non-empty
#  - require-evidence mode: every link MUST have evidence array with ≥1 entry

traceability="$1"
root="${2:-.}"
require_evidence="${3:-}"

if [ -z "$traceability" ] || [ ! -f "$traceability" ]; then
  echo "check-traceability: file not found: $traceability" >&2
  exit 1
fi

if command -v python3 >/dev/null 2>&1; then
  TRACEABILITY="$traceability" ROOT="$root" REQUIRE_EVIDENCE="$require_evidence" python3 - <<'PYEOF'
import json, os, sys, pathlib

traceability_path = os.environ["TRACEABILITY"]
root = os.environ["ROOT"]
require_evidence = os.environ.get("REQUIRE_EVIDENCE", "") == "require-evidence"

try:
    with open(traceability_path, encoding="utf-8") as f:
        traceability = json.load(f)
except json.JSONDecodeError:
    print("check-traceability: invalid JSON", file=sys.stderr)
    sys.exit(1)

failures = []

# Validate structure
feature = (traceability.get("feature") or "").strip()
if not feature:
    failures.append("missing feature")

links = traceability.get("links", [])
if not isinstance(links, list) or len(links) == 0:
    failures.append("traceability has no links")
    if failures:
        print(f"Traceability check FAILED:")
        for failure in failures:
            print(f" - {failure}")
        sys.exit(1)

# Validate each link
for i, link in enumerate(links):
    req = (link.get("req") or "").strip()
    if not req:
        req = f"link {i}"

    # Check acs
    acs = link.get("acs", [])
    if not isinstance(acs, list) or len(acs) == 0 or not any((str(ac or "").strip()) for ac in acs):
        failures.append(f"{req} has no acceptance criteria (acs)")
        continue

    # Check tests
    tests = link.get("tests", [])
    if not isinstance(tests, list) or len(tests) == 0 or not any((str(t or "").strip()) for t in tests):
        failures.append(f"{req} has no tests")
        continue

    # Check evidence if present
    evidence = link.get("evidence")

    # require-evidence mode: link must list >=1 non-empty evidence entry
    # (an absent key OR an empty/whitespace-only array fails closed).
    if require_evidence:
        nonempty_ev = [e for e in evidence if str(e or "").strip()] if isinstance(evidence, list) else []
        if not nonempty_ev:
            failures.append(f"{req} requires evidence but none listed")
            continue

    if evidence is not None:
        if not isinstance(evidence, list):
            failures.append(f"{req} evidence must be an array")
            continue

        for ev_file in evidence:
            ev_path = (ev_file or "").strip()
            if not ev_path:
                continue

            # Path safety checks (same as check-contract)
            if ev_path.startswith("/"):
                failures.append(f"{req} evidence {ev_path} is an absolute path")
                continue
            if (len(ev_path) >= 2 and ev_path[1] == ":") or ev_path.startswith("\\\\"):
                failures.append(f"{req} evidence {ev_path} is an absolute path")
                continue

            # Resolve and check for traversal outside root
            abs_root = str(pathlib.Path(root).resolve())
            try:
                resolved = str(pathlib.Path(root).joinpath(ev_path).resolve())
            except Exception:
                failures.append(f"{req} evidence {ev_path} path could not be resolved")
                continue

            if not resolved.startswith(abs_root + os.sep) and resolved != abs_root:
                failures.append(f"{req} evidence {ev_path} path escapes repo root")
                continue

            # Evidence must exist, be a regular file, and have size > 0
            if not os.path.exists(resolved):
                failures.append(f"{req} evidence {ev_path} file missing")
            elif not os.path.isfile(resolved):
                failures.append(f"{req} evidence {ev_path} is not a regular file")
            elif os.path.getsize(resolved) == 0:
                failures.append(f"{req} evidence {ev_path} file is empty")

if failures:
    print(f"Traceability check FAILED:")
    for failure in failures:
        print(f" - {failure}")
    sys.exit(1)

print(f"Traceability check passed for {feature}: {len(links)} link(s).")
sys.exit(0)
PYEOF
  exit $?
fi

dir="$(dirname "$0")"
for ps in pwsh powershell.exe powershell; do
  if command -v "$ps" >/dev/null 2>&1; then
    if [ "$require_evidence" = "require-evidence" ]; then
      "$ps" -NoProfile -ExecutionPolicy Bypass -File "$dir/check-traceability.ps1" -TracePath "$traceability" -RepoRoot "$root" -RequireEvidence
    else
      "$ps" -NoProfile -ExecutionPolicy Bypass -File "$dir/check-traceability.ps1" -TracePath "$traceability" -RepoRoot "$root"
    fi
    exit $?
  fi
done

echo "check-traceability: needs python3 or PowerShell. Install one, or run check-traceability.ps1 directly." >&2
exit 1
