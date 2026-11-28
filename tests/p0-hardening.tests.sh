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

# 2026-11-28 owner decision (T-010): v2 rewrote ship and implement-tasks. The
# v1 wording checks are retargeted to the same requirements as v2 states them.
# The escalation itself is proved by the GateLifecycle model
# (SELF-REQ-002, tests/v2-formal-gate.test.mjs), not by this wording check.
echo "== REQ-002: sdd-ship auto-fix limit escalates to a human =="
if has "$RUN" "limits.max_auto_fix_rounds" && has "$RUN" "OQ-NNN" && has "$RUN" "人間判断へエスカレーション"; then
  pass "REQ-002 configured auto-fix limit escalates to OQ-NNN"
else
  die "REQ-002 auto-fix limit escalation absent"
fi
if absent "$RUN" "invoked 3 times"; then pass "REQ-002 stale invocation-count phrasing removed"; else die "REQ-002 stale 'invoked 3 times' remains"; fi

echo "== REQ-003: implement-tasks parallel independent set =="
for m in "独立集合" "互いに重複しない最大集合" "並列実行"; do
  if has "$IMP" "$m"; then pass "REQ-003 mentions $m"; else die "REQ-003 missing $m"; fi
done
if absent "$IMP" "Select the task that appears"; then pass "REQ-003 earliest-only selection replaced"; else die "REQ-003 stale earliest-only selection remains"; fi

echo "---"
if [ "$fail" -eq 0 ]; then echo "VERDICT: PASS"; else echo "VERDICT: FAIL (see above)"; fi
exit "$fail"
