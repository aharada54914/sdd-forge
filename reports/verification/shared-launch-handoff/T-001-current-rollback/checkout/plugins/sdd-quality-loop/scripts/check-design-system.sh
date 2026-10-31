#!/bin/sh
# Deterministic gate: design-system conformance (warn-phase).
# Usage: check-design-system.sh <project-root> [<design-md>] [<changed-file>...]
#
# Checks (all skipped with exit 0 when <project-root>/design-system is absent):
#  1. design-system/design-tokens.json carries the contract meta envelope
#     (schema design-system-contract/v1, semver version, generated_by) and the
#     required token groups (color, typography, spacing).
#  2. Each <changed-file> contains no raw style values (#hex colors, rgb(,
#     hsl() calls). Excluded from the scan: design-system/, build/, tests/
#     paths and *.md / *.svg files.
#  3. When <design-md> is given: it contains a "## Design System Compliance"
#     section and does not record ds_profile: none while design-system/ exists.
#
# Warn-phase: findings print as WARN and exit 0. Set
# SDD_DESIGN_SYSTEM_ENFORCE=error to fail (exit 1) on findings instead.
# Bad invocation always exits 1.
root="${1:-}"
if [ -z "$root" ] || [ ! -d "$root" ]; then
  echo "check-design-system: project root not found: $root" >&2
  exit 1
fi
if [ ! -d "$root/design-system" ]; then
  echo "check-design-system skipped: no design-system/ directory."
  exit 0
fi
design_md="${2:-}"
[ $# -ge 1 ] && shift
[ $# -ge 1 ] && shift

_f="$(mktemp)"
trap 'rm -f "$_f"' EXIT

tokens="$root/design-system/design-tokens.json"
if [ ! -f "$tokens" ]; then
  echo "design-tokens.json missing" >> "$_f"
else
  grep -q '"schema": *"design-system-contract/v1"' "$tokens" || echo "design-tokens.json: meta.schema is not design-system-contract/v1" >> "$_f"
  grep -Eq '"version": *"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"' "$tokens" || echo "design-tokens.json: meta.version is not semver" >> "$_f"
  grep -Eq '"generated_by": *"[^"]+"' "$tokens" || echo "design-tokens.json: meta.generated_by missing" >> "$_f"
  for group in color typography spacing; do
    grep -q "\"$group\"" "$tokens" || echo "design-tokens.json: token group $group missing" >> "$_f"
  done
fi

for f in "$@"; do
  case "$f" in
    design-system/*|*/design-system/*|*.md|*.svg|tests/*|*/tests/*|build/*|*/build/*) continue ;;
  esac
  target="$f"
  [ -f "$target" ] || target="$root/$f"
  [ -f "$target" ] || continue
  grep -nE '#[0-9a-fA-F]{6}([^0-9a-fA-F]|$)|#[0-9a-fA-F]{3}([^0-9a-fA-F]|$)|rgb\(|hsl\(' "$target" | head -20 | while IFS= read -r line; do
    echo "raw style value: $f: $line"
  done >> "$_f"
done

if [ -n "$design_md" ]; then
  if [ -f "$design_md" ]; then
    if ! grep -q '^## Design System Compliance$' "$design_md"; then
      echo "design.md: missing '## Design System Compliance' section" >> "$_f"
    elif grep -q 'ds_profile: none' "$design_md"; then
      echo "design.md: records ds_profile: none while design-system/ exists" >> "$_f"
    fi
  else
    echo "design.md not found: $design_md" >> "$_f"
  fi
fi

count=$(grep -c . "$_f")
if [ "$count" -gt 0 ]; then
  if [ "${SDD_DESIGN_SYSTEM_ENFORCE:-warn}" = "error" ]; then
    echo "check-design-system FAILED ($count finding(s)):"
    sed 's/^/ - /' "$_f"
    exit 1
  fi
  echo "check-design-system WARN ($count finding(s)):"
  sed 's/^/ - /' "$_f"
  echo "Warn-phase: findings do not block; record them in the quality-gate report. Set SDD_DESIGN_SYSTEM_ENFORCE=error to enforce."
  exit 0
fi
echo "check-design-system passed."
exit 0
