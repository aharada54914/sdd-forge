#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  printf 'Usage: %s <run-all.sh>\n' "$0" >&2
  exit 2
fi

SOURCE_RUNNER="$(cd "$(dirname "$1")" && pwd -P)/$(basename "$1")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mkdir -p "$WORK/tests"
cp "$SOURCE_RUNNER" "$WORK/tests/run-all.sh"

python3 - "$WORK/tests/run-all.sh" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
source = path.read_text(encoding="utf-8")
source, replacements = re.subn(
    r"tests=\(\n.*?\n\)",
    "tests=(\n  tests/mutate-runner.tests.sh\n)",
    source,
    count=1,
    flags=re.DOTALL,
)
if replacements != 1:
    raise SystemExit("runner test-array replacement failed")
path.write_text(source, encoding="utf-8")
PY

printf '%s\n' '#!/usr/bin/env bash' 'printf '\''"\\n'\'' >>"$RUNNER_UNDER_TEST"' \
  >"$WORK/tests/mutate-runner.tests.sh"
printf '%s\n' 'exit 0' >"$WORK/tests/guard-r10-port.tests.ps1"

output="$WORK/output.log"
exit_code=0
RUNNER_UNDER_TEST="$WORK/tests/run-all.sh" bash "$WORK/tests/run-all.sh" \
  >"$output" 2>&1 || exit_code=$?
cat "$output"

if [[ $exit_code -ne 0 ]] || grep -Fq 'unexpected EOF' "$output"; then
  printf 'FAIL: runner reparsed a child-mutated tail (exit=%d)\n' "$exit_code"
  exit 1
fi

if ! grep -Fq 'All POSIX regression tests passed.' "$output"; then
  printf 'FAIL: runner did not reach its clean completion marker\n'
  exit 1
fi

printf 'PASS: runner parsed fully before executing child suites\n'
