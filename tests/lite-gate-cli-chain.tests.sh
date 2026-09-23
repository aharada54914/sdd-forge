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

echo "Results: 4 passed, 0 failed"
