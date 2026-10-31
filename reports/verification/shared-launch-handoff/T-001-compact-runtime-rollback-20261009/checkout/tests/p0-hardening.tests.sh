#!/usr/bin/env bash
# p0-hardening deterministic doc-consistency checks (bash 3.2 compatible)
# Verifies REQ-001/002/003 of specs/p0-hardening are reflected in the SKILL docs.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
pass() { printf 'PASS: %s\n' "$1"; }
die()  { printf 'FAIL: %s\n' "$1"; fail=1; }
has()  { grep -q -F -- "$2" "$1"; }
absent() { ! grep -q -F -- "$2" "$1"; }

WFI="$ROOT/plugins/sdd-quality-loop/skills/wfi-audit-cycle/SKILL.md"
RUN="$ROOT/plugins/sdd-ship/skills/ship/SKILL.md"
IMP="$ROOT/plugins/sdd-implementation/skills/implement-tasks/SKILL.md"

echo "== REQ-001: wfi-audit-cycle convergence guard =="
for m in "Audit-Attempt" "Human-Blocked" "Audit-Content-Hash"; do
  if has "$WFI" "$m"; then pass "REQ-001 mentions $m"; else die "REQ-001 missing $m"; fi
done

echo "== REQ-002: sdd-ship disk-based gate limit =="
if has "$RUN" "reports/quality-gate/" && has "$RUN" "Escalate-Human"; then pass "REQ-002 disk-based limit present"; else die "REQ-002 disk-based limit absent"; fi
if absent "$RUN" "invoked 3 times"; then pass "REQ-002 stale invocation-count phrasing removed"; else die "REQ-002 stale 'invoked 3 times' remains"; fi

echo "== REQ-003: implement-tasks parallel independent set =="
for m in "independent set" "SCOPE-DISJOINT" "parallel"; do
  if has "$IMP" "$m"; then pass "REQ-003 mentions $m"; else die "REQ-003 missing $m"; fi
done
if absent "$IMP" "Select the task that appears"; then pass "REQ-003 earliest-only selection replaced"; else die "REQ-003 stale earliest-only selection remains"; fi

echo "---"
if [ "$fail" -eq 0 ]; then echo "VERDICT: PASS"; else echo "VERDICT: FAIL (see above)"; fi
exit "$fail"
