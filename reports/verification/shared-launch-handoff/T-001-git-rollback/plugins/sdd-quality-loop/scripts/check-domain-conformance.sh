#!/bin/sh
# Deterministic gate: domain conformance (warn-phase).
# Usage: check-domain-conformance.sh <project-root> [<requirements-md>] [<design-md>]
#
# Checks (all skipped with exit 0 when <project-root>/domain is absent):
#  1. requirements.md's Bounded-Context: field (when present) names only
#     context(s) that exist in domain/domain-contract.json.
#  2. Every canonical term used in requirements.md/design.md structured
#     fields (Bounded-Context: values and heading-level term usage) matches
#     an exact canonical term from the matched context(s) -- v1 term-matching
#     scope is exact canonical-term matching on structured fields only (no
#     lexical-variant/synonym matching), per design.md Assumptions / OQ-R1.
#  3. Every aggregate name referenced in design.md (an inline Markdown link
#     whose text is a PascalCase aggregate name) exists in
#     domain/aggregates/<name>.md.
#  4. When Bounded-Context: lists exactly two contexts, the context map
#     (domain/domain-contract.json relations[]) must declare a relation
#     between them (AC-015); otherwise a warn finding is recorded.
#
# Warn-phase: findings print as WARN and exit 0. Set
# SDD_DOMAIN_ENFORCE=error to fail (exit 1) on findings instead.
# Bad invocation always exits 1.
root="${1:-}"
if [ -z "$root" ] || [ ! -d "$root" ]; then
  echo "check-domain-conformance: project root not found: $root" >&2
  exit 1
fi
if [ ! -d "$root/domain" ]; then
  echo "check-domain-conformance skipped: no domain/ directory."
  exit 0
fi
requirements_md="${2:-}"
design_md="${3:-}"

contract="$root/domain/domain-contract.json"
if [ ! -f "$contract" ]; then
  echo "check-domain-conformance skipped: no domain/domain-contract.json found."
  exit 0
fi

_f="$(mktemp)"
trap 'rm -f "$_f"' EXIT

# --- Extract known context names, canonical terms, and aggregate names from
#     domain-contract.json using a lightweight line-based scan (no jq
#     dependency, matching check-design-system.sh's grep-only approach). ---
context_names=$(grep -oE '"name": *"[a-z][a-z0-9-]*"' "$contract" | sed -E 's/"name": *"([^"]+)"/\1/')
canonical_terms=$(grep -oE '"canonical": *"[^"]+"' "$contract" | sed -E 's/"canonical": *"([^"]+)"/\1/')
aggregate_names=$(grep -oE '"name": *"[A-Z][A-Za-z0-9]*"' "$contract" | sed -E 's/"name": *"([^"]+)"/\1/')

context_exists() {
  ctx="$1"
  printf '%s\n' "$context_names" | grep -Fxq -- "$ctx"
}

relation_declared() {
  a="$1"
  b="$2"
  grep -A2 '"from"' "$contract" | tr -d '\n' | grep -Eq "\"from\": *\"$a\"[^}]*\"to\": *\"$b\"|\"from\": *\"$b\"[^}]*\"to\": *\"$a\""
}

# --- Check 1 + 4: Bounded-Context: field in requirements.md -------------
if [ -n "$requirements_md" ]; then
  if [ -f "$requirements_md" ]; then
    bc_line=$(grep -E '^Bounded-Context:' "$requirements_md" | head -1)
    if [ -n "$bc_line" ]; then
      # Strip the "Bounded-Context:" label and any trailing relation
      # parenthetical, then split on comma to get one or two context names.
      bc_value=$(echo "$bc_line" | sed -E 's/^Bounded-Context: *//; s/\(.*\)$//' | sed 's/[[:space:]]*$//')
      old_ifs="$IFS"
      IFS=','
      set -- $bc_value
      IFS="$old_ifs"
      count=0
      for raw_ctx in "$@"; do
        ctx=$(echo "$raw_ctx" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
        [ -z "$ctx" ] && continue
        count=$((count + 1))
        if ! context_exists "$ctx"; then
          echo "requirements.md: Bounded-Context '$ctx' not found in domain-contract.json" >> "$_f"
        fi
        eval "ctx_$count=\"\$ctx\""
      done
      if [ "$count" -eq 2 ]; then
        c1="$ctx_1"
        c2="$ctx_2"
        if context_exists "$c1" && context_exists "$c2"; then
          if ! relation_declared "$c1" "$c2"; then
            echo "requirements.md: Bounded-Context lists two contexts ('$c1', '$c2') with no declared relation in context map" >> "$_f"
          fi
        fi
      fi
    fi
  else
    echo "requirements.md not found: $requirements_md" >> "$_f"
  fi
fi

# --- Check 2: canonical-term structured-field usage (requirements.md headings) ---
if [ -n "$requirements_md" ] && [ -f "$requirements_md" ]; then
  grep -nE '^#{1,6}[[:space:]]' "$requirements_md" | while IFS= read -r heading; do
    lineno=$(echo "$heading" | cut -d: -f1)
    text=$(echo "$heading" | cut -d: -f2-)
    echo "$text" | grep -oE '\[\[term:[^]]+\]\]' | sed -E 's/\[\[term:([^]]+)\]\]/\1/' | while IFS= read -r used_term; do
      [ -z "$used_term" ] && continue
      if ! printf '%s\n' "$canonical_terms" | grep -Fxq -- "$used_term"; then
        echo "requirements.md:$lineno: unrecognized term '$used_term' (not a canonical term in domain-contract.json)" >> "$_f"
      fi
    done
  done
fi

# --- Check 3: aggregate references in design.md ---------------------------
if [ -n "$design_md" ]; then
  if [ -f "$design_md" ]; then
    grep -oE '\[[A-Z][A-Za-z0-9]*\]\([^)]*aggregates/[^)]*\)' "$design_md" | sed -E 's/^\[([A-Za-z0-9]+)\].*/\1/' | while IFS= read -r agg; do
      [ -z "$agg" ] && continue
      if ! printf '%s\n' "$aggregate_names" | grep -Fxq -- "$agg"; then
        echo "design.md: aggregate reference '$agg' not found in domain-contract.json aggregates" >> "$_f"
      fi
      card="$root/domain/aggregates/$agg.md"
      if [ ! -f "$card" ]; then
        echo "design.md: aggregate reference '$agg' has no domain/aggregates/$agg.md card" >> "$_f"
      fi
    done
  else
    echo "design.md not found: $design_md" >> "$_f"
  fi
fi

count=$(grep -c . "$_f")
if [ "$count" -gt 0 ]; then
  if [ "${SDD_DOMAIN_ENFORCE:-warn}" = "error" ]; then
    echo "check-domain-conformance FAILED ($count finding(s)):"
    sed 's/^/ - /' "$_f"
    exit 1
  fi
  echo "check-domain-conformance WARN ($count finding(s)):"
  sed 's/^/ - /' "$_f"
  echo "Warn-phase: findings do not block; record them in the quality-gate report. Set SDD_DOMAIN_ENFORCE=error to enforce."
  exit 0
fi
echo "check-domain-conformance passed."
exit 0
