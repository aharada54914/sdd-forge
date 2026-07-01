#!/bin/sh
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEMPLATES="$ROOT/plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/templates"
PASS=0
FAIL=0

pass() {
  PASS=$((PASS + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf 'FAIL: %s\n' "$1"
}

assert_file() {
  path=$1
  label=$2
  if [ -f "$path" ]; then
    pass "$label"
  else
    fail "$label (missing: $path)"
  fi
}

assert_contains() {
  path=$1
  pattern=$2
  label=$3
  if [ -f "$path" ] && grep -Eq "$pattern" "$path"; then
    pass "$label"
  else
    fail "$label"
  fi
}

ux="$TEMPLATES/ux-spec.template.md"
frontend="$TEMPLATES/frontend-spec.template.md"
infra="$TEMPLATES/infra-spec.template.md"
security="$TEMPLATES/security-spec.template.md"

assert_file "$ux" "TEST-001 UX layer template exists"
assert_file "$frontend" "TEST-001 frontend layer template exists"
assert_file "$infra" "TEST-001 infrastructure layer template exists"
assert_file "$security" "TEST-001 security layer template exists"

assert_contains "$ux" '^## Target Views$' "TEST-002 UX target views"
assert_contains "$ux" 'Component.*State.*REQ-NNN.*AC-NNN' "TEST-002 UX state traceability"
assert_contains "$ux" '^```mermaid$' "TEST-002 UX Mermaid interaction sequence"
assert_contains "$ux" '^## Wireframe Attachments$' "TEST-002 UX wireframe placeholder"
assert_contains "$ux" '^## Navigation Map$' "TEST-002 UX navigation"
assert_contains "$ux" 'WCAG 2\.2 AA' "TEST-002 UX accessibility"
assert_contains "$ux" '^## Component States$' "TEST-002 UX failure states"
assert_contains "$ux" 'Breakpoint' "TEST-002 UX responsive breakpoints"
assert_contains "$ux" '^## Design Tokens$' "TEST-002 UX design tokens"

assert_contains "$frontend" '^## Technology Stack$' "TEST-003 frontend stack"
assert_contains "$frontend" 'flowchart|graph' "TEST-003 frontend component tree"
assert_contains "$frontend" '^## State Shape$' "TEST-003 frontend state plan"
assert_contains "$frontend" 'Route.*Component.*Auth.*Parameters' "TEST-003 frontend route contract"
assert_contains "$frontend" '^## API Client Strategy$' "TEST-003 frontend API client"
assert_contains "$frontend" 'Code Splitting.*Size Budget|Code-Splitting.*Size Budget' "TEST-003 frontend bundle budget"
assert_contains "$frontend" '^\| LCP \|' "TEST-003 frontend LCP budget"
assert_contains "$frontend" '^\| INP \|' "TEST-003 frontend INP budget"
assert_contains "$frontend" '^\| CLS \|' "TEST-003 frontend CLS budget"
assert_contains "$frontend" '^interface [A-Za-z][A-Za-z0-9]* \{' "TEST-003 concrete TypeScript interface"
assert_contains "$frontend" 'Dependency.*Version.*Purpose.*Alternative' "TEST-003 frontend dependencies"

assert_contains "$infra" '^## Deployment Topology$' "TEST-004 deployment topology"
assert_contains "$infra" '^## CI/CD Sequence$' "TEST-004 CI/CD sequence"
assert_contains "$infra" 'Environment.*URL.*Auth.*Trigger.*Classification' "TEST-004 environment matrix"
assert_contains "$infra" '^## Infrastructure as Code$' "TEST-004 IaC stub"
assert_contains "$infra" '^## Scaling Strategy$' "TEST-004 scaling"
assert_contains "$infra" 'Availability.*[0-9]+(\.[0-9]+)?%.*AC-NNN' "TEST-004 availability SLO"
assert_contains "$infra" 'p95.*[0-9]+ ?ms.*AC-NNN' "TEST-004 latency SLO"
assert_contains "$infra" 'Residency.*Retention' "TEST-004 residency and retention"
assert_contains "$infra" 'Logs.*Traces.*Metrics' "TEST-004 observability"
assert_contains "$infra" '^## Cost Estimate$' "TEST-004 cost estimate"
assert_contains "$infra" '^## Rollback$' "TEST-004 rollback"

assert_contains "$security" '^## Trust Boundaries$' "TEST-005 trust boundaries"
assert_contains "$security" '^## Authentication Flow$' "TEST-005 authentication flow"
assert_contains "$security" 'Boundary.*Threat.*STRIDE.*Mitigation.*REQ-NNN.*AC-NNN' "TEST-005 STRIDE matrix"
assert_contains "$security" '^## Authorization$' "TEST-005 authorization"
assert_contains "$security" 'Entity.*Classification.*At Rest.*In Transit.*Retention' "TEST-005 data controls"
assert_contains "$security" '^## OWASP Mapping$' "TEST-005 OWASP mapping"
assert_contains "$security" '^## Secrets Management$' "TEST-005 secrets"
assert_contains "$security" 'SBOM|Supply Chain' "TEST-005 supply chain"
assert_contains "$security" '^## Security Tests$' "TEST-005 security tests"

tmp=${TMPDIR:-/tmp}/sdd-layer-template-test-$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

validate_required_heading() {
  file=$1
  heading=$2
  if grep -Fqx "$heading" "$file"; then
    return 0
  fi
  printf 'missing heading: %s\n' "$heading"
  return 1
}

validate_required_pattern() {
  file=$1
  pattern=$2
  label=$3
  if grep -Eq "$pattern" "$file"; then
    return 0
  fi
  printf 'missing pattern: %s\n' "$label"
  return 1
}

while IFS='|' read -r template_name heading; do
  [ -n "$template_name" ] || continue
  template="$TEMPLATES/$template_name"
  malformed="$tmp/$template_name"
  grep -Fvx "$heading" "$template" > "$malformed"
  if diagnostic=$(validate_required_heading "$malformed" "$heading" 2>&1); then
    fail "malformed $template_name rejects removed $heading"
  elif [ "$diagnostic" = "missing heading: $heading" ]; then
    pass "malformed $template_name rejects removed $heading"
  else
    fail "malformed $template_name diagnostic for $heading"
  fi
done <<'EOF'
ux-spec.template.md|## Target Views
ux-spec.template.md|## Wireframe Attachments
ux-spec.template.md|## Navigation Map
ux-spec.template.md|## Component States
ux-spec.template.md|## Design Tokens
frontend-spec.template.md|## Technology Stack
frontend-spec.template.md|## State Shape
frontend-spec.template.md|## API Client Strategy
infra-spec.template.md|## Deployment Topology
infra-spec.template.md|## CI/CD Sequence
infra-spec.template.md|## Infrastructure as Code
infra-spec.template.md|## Scaling Strategy
infra-spec.template.md|## Cost Estimate
infra-spec.template.md|## Rollback
security-spec.template.md|## Trust Boundaries
security-spec.template.md|## Authentication Flow
security-spec.template.md|## Authorization
security-spec.template.md|## OWASP Mapping
security-spec.template.md|## Secrets Management
security-spec.template.md|## Security Tests
EOF

while IFS='~' read -r template_name pattern label; do
  [ -n "$template_name" ] || continue
  template="$TEMPLATES/$template_name"
  malformed="$tmp/$template_name"
  grep -Ev "$pattern" "$template" > "$malformed"
  if diagnostic=$(validate_required_pattern "$malformed" "$pattern" "$label" 2>&1); then
    fail "malformed $template_name rejects removed $label"
  elif [ "$diagnostic" = "missing pattern: $label" ]; then
    pass "malformed $template_name rejects removed $label"
  else
    fail "malformed $template_name diagnostic for $label"
  fi
done <<'EOF'
ux-spec.template.md~Component.*State.*REQ-NNN.*AC-NNN~state traceability
ux-spec.template.md~^```mermaid$~interaction sequence
ux-spec.template.md~WCAG 2\.2 AA~accessibility target
ux-spec.template.md~Breakpoint~responsive breakpoints
frontend-spec.template.md~flowchart|graph~component tree
frontend-spec.template.md~Route.*Component.*Auth.*Parameters~route contract
frontend-spec.template.md~Code Splitting.*Size Budget|Code-Splitting.*Size Budget~bundle budget
frontend-spec.template.md~^\| LCP \|~LCP budget
frontend-spec.template.md~^\| INP \|~INP budget
frontend-spec.template.md~^\| CLS \|~CLS budget
frontend-spec.template.md~^interface [A-Za-z][A-Za-z0-9]* \{~concrete TypeScript interface
frontend-spec.template.md~Dependency.*Version.*Purpose.*Alternative~dependency decision
infra-spec.template.md~Environment.*URL.*Auth.*Trigger.*Classification~environment matrix
infra-spec.template.md~Availability.*[0-9]+(\.[0-9]+)?%.*AC-NNN~availability SLO
infra-spec.template.md~p95.*[0-9]+ ?ms.*AC-NNN~latency SLO
infra-spec.template.md~Residency.*Retention~residency and retention
infra-spec.template.md~Logs.*Traces.*Metrics~observability plan
security-spec.template.md~Boundary.*Threat.*STRIDE.*Mitigation.*REQ-NNN.*AC-NNN~STRIDE matrix
security-spec.template.md~Entity.*Classification.*At Rest.*In Transit.*Retention~data controls
security-spec.template.md~SBOM|Supply Chain~supply-chain controls
EOF

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
