#!/usr/bin/env bash
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
cd "$root"
candidate="reports/verification/ci-qcd-optimization-20260922.patch"
expected='36d8ff073ef8985196cb8645dba72ce3d5eb8442581aadc40d05cf087309f969'

actual="$(shasum -a 256 "$candidate" | awk '{print $1}')"
test "$actual" = "$expected" || {
  printf 'candidate hash mismatch: %s\n' "$actual" >&2
  exit 1
}

# The candidate is a historical, hash-bound patch.  A human may rerun this
# helper after the same change has already landed (for example via a prior
# PR), so detect the semantic target before asking git to apply it again.
workflow='.github/workflows/test.yml'
if grep -Eq '^        os: \[windows-latest, ubuntu-latest\]$' "$workflow" \
  && awk '/^  loops-routing:$/ { found=1 } found { print } found && /^  [A-Za-z0-9_-]+:/ && $0 !~ /^  loops-routing:$/ { exit }' "$workflow" \
    | grep -Fq 'os: [windows-latest, ubuntu-latest]'; then
  printf 'Candidate target already present; skipping git apply.\n'
else
  git apply --check "$candidate"
  backup="$(mktemp -d "${TMPDIR:-/tmp}/sdd-ci-qcd-XXXXXX")"
  mkdir -p "$backup/.github/workflows"
  cp -p "$workflow" "$backup/$workflow"
  git apply "$candidate"
fi

ruby -e 'require "yaml"; YAML.load_file(".github/workflows/test.yml")'
git diff --check
if [ -n "${backup:-}" ]; then
  printf 'Applied CI QCD candidate.\nBackup: %s\n' "$backup"
else
  printf 'CI QCD candidate was already applied; no files changed.\n'
fi
printf 'Run the full GitHub Actions workflow before commit/push/merge.\n'
