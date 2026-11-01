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

_f="$(mktemp)" || exit 1
_scan="$(mktemp)" || { rm -f "$_f"; exit 1; }
trap 'rm -f "$_f" "$_scan"' EXIT

tokens="$root/design-system/design-tokens.json"
if [ ! -f "$tokens" ]; then
  echo "design-tokens.json missing" >> "$_f"
else
  if ! command -v jq >/dev/null 2>&1; then
    echo "check-design-system: jq is required to validate design-tokens.json" >&2
    exit 1
  fi
  if jq -sr '
    if length != 1 or (.[0] | type) != "object" then
      ["design-tokens.json: not valid JSON object"]
    else
      .[0] as $document |
      ($document.meta | if type == "object" then . else {} end) as $meta |
      [
        (if $meta.schema != "design-system-contract/v1" then "design-tokens.json: meta.schema is not design-system-contract/v1" else empty end),
        (if ($meta.version | if type == "string" then test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$") else false end) then empty else "design-tokens.json: meta.version is not semver" end),
        (if ($meta.generated_by | if type == "string" then length > 0 else false end) then empty else "design-tokens.json: meta.generated_by missing" end),
        ("color", "typography", "spacing" | select($document[.] == null) | "design-tokens.json: token group " + . + " missing")
      ]
    end | .[]
  ' "$tokens" >> "$_f" 2>/dev/null; then
    :
  else
    jq_status=$?
    if [ "$jq_status" -eq 4 ]; then
      echo "design-tokens.json: not valid JSON" >> "$_f"
    else
      echo "check-design-system: cannot read or validate design-tokens.json" >&2
      exit 1
    fi
  fi
fi

for f in "$@"; do
  case "$f" in
    design-system/*|*/design-system/*|*.md|*.svg|tests/*|*/tests/*|build/*|*/build/*) continue ;;
  esac
  target="$f"
  [ -f "$target" ] || target="$root/$f"
  [ -f "$target" ] || continue
  grep -nE '#[0-9a-fA-F]{6}([^0-9a-fA-F]|$)|#[0-9a-fA-F]{3}([^0-9a-fA-F]|$)|rgb\(|hsl\(' -- "$target" >"$_scan"
  scan_status=$?
  if [ "$scan_status" -gt 1 ]; then
    echo "check-design-system: cannot scan changed file: $target" >&2
    exit 1
  fi
  shown=0
  while IFS= read -r line; do
    [ "$shown" -lt 20 ] || break
    printf 'raw style value: %s: %s\n' "$f" "$line" >>"$_f" || exit 1
    shown=$((shown + 1))
  done <"$_scan"
done

if [ -n "$design_md" ]; then
  if [ -f "$design_md" ]; then
    grep '^## Design System Compliance$' -- "$design_md" >"$_scan"
    scan_status=$?
    if [ "$scan_status" -gt 1 ]; then
      echo "check-design-system: cannot read design document: $design_md" >&2
      exit 1
    elif [ "$scan_status" -eq 1 ]; then
      echo "design.md: missing '## Design System Compliance' section" >> "$_f"
    else
      grep 'ds_profile: none' -- "$design_md" >"$_scan"
      scan_status=$?
      if [ "$scan_status" -gt 1 ]; then
        echo "check-design-system: cannot read design document: $design_md" >&2
        exit 1
      elif [ "$scan_status" -eq 0 ]; then
        echo "design.md: records ds_profile: none while design-system/ exists" >> "$_f"
      fi
    fi
  else
    echo "design.md not found: $design_md" >> "$_f"
  fi
fi

count=$(grep -c . "$_f")
[ "$?" -le 1 ] || exit 1
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
