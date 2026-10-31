#!/bin/sh
# Deterministic preflight: verify the SDD project directory structure.
# Usage: check-sdd-structure.sh [project-root] [feature]
# Default project-root is the current directory.
#
# Required items (missing → "missing: <path>", counted toward exit code):
#   AGENTS.md, specs/, reports/implementation/, reports/quality-gate/,
#   docs/adr/, docs/review-tickets/
#
# Advisory items (missing → "advisory: <path>", do not affect exit code):
#   CLAUDE.md, contracts/, docs/architecture/
#
# Drift check (advisory, does not affect exit code):
#   Any directory matching specs/*/adr prints:
#   "drift: <path> (ADRs belong in docs/adr/)"
#
# Host detection:
#   "host: gitlab"  if .gitlab-ci.yml or .gitlab/ exists
#   "host: github"  if .github/ exists
#   "host: local"   if neither
#
# Final line:
#   "check-sdd-structure: OK"         (exit 0) when no missing items
#   "check-sdd-structure: FAIL (N missing)"  to stderr and exit 1 otherwise

root="${1:-.}"
feature_selected=0
feature="${2-}"

if [ "$#" -ge 2 ]; then
  feature_selected=1
  case "$feature" in
    ""|-*|*[!a-z0-9-]*)
      echo "invalid feature: $feature" >&2
      exit 1
      ;;
  esac
fi

if [ ! -d "$root" ]; then
  echo "check-sdd-structure: project root not found: $root" >&2
  exit 1
fi

missing=0

# --- required items ---
_check_required() {
  path="$1"
  kind="$2"   # "f" for file, "d" for directory
  if [ "$kind" = "f" ]; then
    [ -f "$root/$path" ] || { echo "missing: $path"; missing=$((missing + 1)); }
  else
    [ -d "$root/$path" ] || { echo "missing: $path"; missing=$((missing + 1)); }
  fi
}

_check_required "AGENTS.md"               f
_check_required "specs"                   d
_check_required "reports/implementation"  d
_check_required "reports/quality-gate"    d
_check_required "docs/adr"               d
_check_required "docs/review-tickets"    d

# --- selected full-profile feature ---
if [ "$feature_selected" -eq 1 ]; then
  if [ -L "$root/specs" ] || [ -L "$root/specs/$feature" ]; then
    echo "invalid feature: $feature" >&2
    exit 1
  fi
  for name in requirements.md design.md ux-spec.md frontend-spec.md \
    infra-spec.md security-spec.md acceptance-tests.md tasks.md traceability.md; do
    if [ -L "$root/specs/$feature/$name" ]; then
      echo "invalid feature: $feature" >&2
      exit 1
    fi
    _check_required "specs/$feature/$name" f
  done
fi

# --- advisory items ---
_check_advisory() {
  path="$1"
  kind="$2"
  if [ "$kind" = "f" ]; then
    [ -f "$root/$path" ] || echo "advisory: $path"
  else
    [ -d "$root/$path" ] || echo "advisory: $path"
  fi
}

_check_advisory "CLAUDE.md"           f
_check_advisory "contracts"           d
_check_advisory "docs/architecture"   d

# --- drift check: specs/*/adr directories ---
if [ -d "$root/specs" ]; then
  for adr_dir in "$root/specs"/*/adr; do
    [ -d "$adr_dir" ] || continue
    # Produce a relative path from project root
    rel="${adr_dir#$root/}"
    echo "drift: $rel (ADRs belong in docs/adr/)"
  done
fi

# --- host detection ---
detected_host=0
if [ -f "$root/.gitlab-ci.yml" ] || [ -d "$root/.gitlab" ]; then
  echo "host: gitlab"
  detected_host=1
fi
if [ -d "$root/.github" ]; then
  echo "host: github"
  detected_host=1
fi
if [ "$detected_host" -eq 0 ]; then
  echo "host: local"
fi

# --- final result ---
if [ "$missing" -eq 0 ]; then
  echo "check-sdd-structure: OK"
  exit 0
else
  echo "check-sdd-structure: FAIL ($missing missing)" >&2
  exit 1
fi
