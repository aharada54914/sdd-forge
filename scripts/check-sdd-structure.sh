#!/bin/sh
# Deterministic preflight for the repository's SDD structure.
# Usage: scripts/check-sdd-structure.sh [project-root]
root="${1:-.}"

if [ ! -d "$root" ]; then
  echo "check-sdd-structure: project root not found: $root" >&2
  exit 1
fi

missing=0
required_file() {
  [ -f "$root/$1" ] || { echo "missing: $1"; missing=$((missing + 1)); }
}
required_dir() {
  [ -d "$root/$1" ] || { echo "missing: $1"; missing=$((missing + 1)); }
}
advisory_file() { [ -f "$root/$1" ] || echo "advisory: $1"; }
advisory_dir() { [ -d "$root/$1" ] || echo "advisory: $1"; }

required_file AGENTS.md
required_dir specs
required_dir reports/implementation
required_dir reports/quality-gate
required_dir docs/adr
required_dir docs/review-tickets

advisory_file CLAUDE.md
advisory_dir contracts
advisory_dir docs/architecture

if [ -d "$root/specs" ]; then
  for adr_dir in "$root"/specs/*/adr; do
    [ -d "$adr_dir" ] || continue
    echo "drift: ${adr_dir#$root/} (ADRs belong in docs/adr/)"
  done
fi

host=0
if [ -f "$root/.gitlab-ci.yml" ] || [ -d "$root/.gitlab" ]; then
  echo "host: gitlab"
  host=1
fi
if [ -d "$root/.github" ]; then
  echo "host: github"
  host=1
fi
[ "$host" -eq 1 ] || echo "host: local"

if [ "$missing" -eq 0 ]; then
  echo "check-sdd-structure: OK"
  exit 0
fi
echo "check-sdd-structure: FAIL ($missing missing)" >&2
exit 1
