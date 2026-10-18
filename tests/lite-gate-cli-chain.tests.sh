#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
RUNNER="${REPO_ROOT}/plugins/sdd-lite/lib/run-lite-gate.py"
PYTHON="$(command -v python3 || command -v python)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "${WORK}/scripts"

cat > "${WORK}/capability-summary.json" <<'EOF'
{"schema":"sdd-capability-summary/v1","feature":"demo","track":"lite","capabilities":["cap-a"],"required_lite_checks":["emit-proof"],"full_upgrade_required":false}
EOF
cat > "${WORK}/scripts/emit-proof.sh" <<'EOF'
#!/bin/sh
printf 'child-stdout\n'
printf 'child-stderr\n' >&2
printf 'ran\n' > ran.txt
EOF
cat > "${WORK}/scripts/emit-proof.ps1" <<'EOF'
Write-Output 'child-stdout'
[Console]::Error.WriteLine('child-stderr')
[IO.File]::WriteAllText((Join-Path (Get-Location) 'ran.txt'), 'ran')
EOF

json_field() {
  "${PYTHON}" - "$1" "$2" <<'PY'
import json, sys
value = json.load(open(sys.argv[1], encoding="utf-8"))
for part in sys.argv[2].split('.'):
    value = value[int(part)] if isinstance(value, list) else value[part]
print(value)
PY
}

output="${WORK}/result.json"
if "${PYTHON}" "${RUNNER}" --summary "${WORK}/capability-summary.json" --enforcement required --repo-root "${WORK}" --runtime posix >"${output}"; then
  :
else
  echo "FAIL: successful child was reported as failed"; exit 1
fi
[ -f "${WORK}/ran.txt" ]
[ "$(json_field "${output}" checks.0.exit_code)" = 0 ]
[ "$(json_field "${output}" checks.0.stdout)" = child-stdout ]
[ "$(json_field "${output}" checks.0.stderr)" = child-stderr ]
echo "ok: POSIX child execution captures output and exit status"

cat > "${WORK}/scripts/fail-proof.sh" <<'EOF'
#!/bin/sh
printf 'failure\n' >&2
exit 7
EOF
cat > "${WORK}/scripts/fail-proof.ps1" <<'EOF'
[Console]::Error.WriteLine('failure')
exit 7
EOF
"${PYTHON}" - <<'PY' "${WORK}/capability-summary.json"
import json, sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["required_lite_checks"] = ["fail-proof"]
json.dump(data, open(path, "w", encoding="utf-8"))
PY
if "${PYTHON}" "${RUNNER}" --summary "${WORK}/capability-summary.json" --enforcement required --repo-root "${WORK}" --runtime posix >"${output}"; then
  echo "FAIL: nonzero child was reported as passed"; exit 1
fi
[ "$(json_field "${output}" checks.0.exit_code)" = 7 ]
echo "ok: nonzero child exit fails the gate"

cat > "${WORK}/scripts/slow-proof.sh" <<'EOF'
#!/bin/sh
sleep 2
EOF
cat > "${WORK}/scripts/slow-proof.ps1" <<'EOF'
Start-Sleep -Seconds 2
EOF
"${PYTHON}" - <<'PY' "${WORK}/capability-summary.json"
import json, sys
path = sys.argv[1]
data = json.load(open(path, encoding="utf-8"))
data["required_lite_checks"] = ["slow-proof"]
json.dump(data, open(path, "w", encoding="utf-8"))
PY
if "${PYTHON}" "${RUNNER}" --summary "${WORK}/capability-summary.json" --enforcement required --repo-root "${WORK}" --runtime posix --timeout 0.1 >"${output}"; then
  echo "FAIL: timed-out child was reported as passed"; exit 1
fi
[ "$(json_field "${output}" checks.0.timed_out)" = True ]
echo "ok: timed-out child fails closed"

cat > "${WORK}/capability-summary.json" <<'EOF'
{"schema":"sdd-capability-summary/v1","feature":"demo","track":"lite","capabilities":["cap-a"],"required_lite_checks":["emit-proof"],"full_upgrade_required":true}
EOF
rm -f "${WORK}/ran.txt"
if "${PYTHON}" "${RUNNER}" --summary "${WORK}/capability-summary.json" --enforcement required --repo-root "${WORK}" --runtime posix >"${output}"; then
  echo "FAIL: full upgrade was reported as passed"; exit 1
fi
[ ! -e "${WORK}/ran.txt" ]
echo "ok: full upgrade blocks child execution"

# Explicit baseline/acceptance/regression checks share the same executor.
# Repeated selection must not execute a costly project check twice.
cat > "${WORK}/scripts/test.sh" <<'EOF'
#!/bin/sh
printf 'run\n' >> count.txt
EOF
cp "${WORK}/scripts/emit-proof.ps1" "${WORK}/scripts/test.ps1"
"${PYTHON}" "${RUNNER}" --enforcement none --repo-root "${WORK}" --runtime posix --check test --check test --output "${output}" > "${WORK}/stdout.json"
[ "$(wc -l < "${WORK}/count.txt" | tr -d ' ')" = 1 ]
cmp "${output}" "${WORK}/stdout.json"
[ "$(json_field "${output}" checks.0.id)" = test ]
echo "ok: explicit checks execute once and evidence matches actual output"

if "${PYTHON}" "${RUNNER}" --enforcement none --repo-root "${WORK}" --runtime posix --check test --check missing --output "${output}" >/dev/null; then
  echo "FAIL: missing explicit check was waived"; exit 1
fi
[ "$(json_field "${output}" verdict)" = FAIL ]
[ "$(json_field "${output}" failed_check)" = missing ]
[ "$(json_field "${output}" checks.0.exit_code)" = 0 ]
echo "ok: discovery failure preserves prior execution evidence and fails closed"

if "${PYTHON}" "${RUNNER}" --enforcement none --repo-root "${WORK}" --runtime posix --check test --output "${WORK}/missing-parent/result.json" >/dev/null 2>&1; then
  echo "FAIL: evidence write failure was reported as success"; exit 1
fi
echo "ok: evidence write failure fails closed"
"${PYTHON}" - "${RUNNER}" <<'PYTEST'
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile

spec = importlib.util.spec_from_file_location("lite_runner", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
with tempfile.TemporaryDirectory() as temporary:
    repo = Path(temporary)
    assert module._source_snapshot(repo) == {"revision": None, "dirty": None}
    def git(*args):
        return subprocess.check_output(["git", "-C", str(repo), *args], stderr=subprocess.PIPE).decode().strip()
    git("init")
    git("config", "user.name", "Test Fixture")
    git("config", "user.email", "fixture@example.invalid")
    (repo / "tracked.txt").write_text("original")
    git("add", ".")
    git("commit", "-m", "fixture")
    head = git("rev-parse", "HEAD")
    assert module._source_snapshot(repo) == {"revision": head, "dirty": False}
    (repo / "tracked.txt").write_text("changed")
    assert module._source_snapshot(repo)["dirty"] is True
    git("checkout", "--", "tracked.txt")
    (repo / "untracked.txt").write_text("new")
    assert module._source_snapshot(repo)["dirty"] is True
    (repo / "untracked.txt").unlink()
    evidence = repo / "result.json"
    subprocess.run([sys.executable, sys.argv[1], "--enforcement", "none", "--repo-root", str(repo),
                    "--runtime", "posix", "--output", str(evidence)], check=True, stdout=subprocess.PIPE)
    source = json.loads(evidence.read_text())["source"]
    assert source["before"] == source["after"] == {"revision": head, "dirty": False}
    assert source["head_changed"] is False and source["reuse_allowed"] is False
    assert module._source_snapshot(repo)["dirty"] is True  # receipt written after snapshot
    evidence.unlink()
    (repo / "scripts").mkdir()
    (repo / "scripts/move-head.sh").write_text("git -c core.hooksPath=/dev/null commit --allow-empty -m during-check\n")
    (repo / "scripts/move-head.ps1").write_text("git commit --allow-empty -m during-check\n")
    git("add", ".")
    git("commit", "-m", "add check")
    result = subprocess.run([sys.executable, sys.argv[1], "--enforcement", "none", "--repo-root", str(repo),
                             "--runtime", "posix", "--check", "move-head"], check=True, stdout=subprocess.PIPE)
    source = json.loads(result.stdout)["source"]
    assert source["head_changed"] is True and source["reuse_allowed"] is False
print("ok: source observations distinguish clean, dirty, untracked and unknown; receipts are not reusable")
PYTEST
echo "Results: 8 passed, 0 failed"
