#!/usr/bin/env bash
# resolver-evidence-schema suite (T-001, AC-017/018/019/020).
# Schema-conformance only: every fixture here is a hand-crafted Resolver
# Evidence instance validated directly against
# contracts/resolver-evidence.schema.json via the stdlib-only
# resolver-evidence-schema-check.py validator. No live Registry or
# resolve-project-context invocation is exercised by this suite (T-002/
# T-003/T-004's own scope).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCHEMA="$ROOT/contracts/resolver-evidence.schema.json"
CHECK="$ROOT/tests/resolver-evidence-schema-check.py"
FIXTURES="$ROOT/tests/fixtures/capability-resolver/resolver-evidence-schema"

PY() { if command -v python3 >/dev/null 2>&1; then python3 "$@"; else python "$@"; fi; }

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); printf 'PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1"; }

# TEST-017: contract existence + $id convention.
if [ -f "$SCHEMA" ]; then pass "TEST-017 schema file exists"; else fail "TEST-017 schema file exists"; fi

if PY -c "import json; json.load(open('$SCHEMA', encoding='utf-8'))" >/dev/null 2>&1; then
  pass "TEST-017 schema is valid JSON"
else
  fail "TEST-017 schema is valid JSON"
fi

SCHEMA_URI="$(PY -c "import json; print(json.load(open('$SCHEMA', encoding='utf-8')).get('\$schema',''))")"
if [ "$SCHEMA_URI" = "http://json-schema.org/draft-07/schema#" ]; then
  pass "TEST-017 \$schema is draft-07"
else
  fail "TEST-017 \$schema is draft-07 (got: $SCHEMA_URI)"
fi

SCHEMA_ID="$(PY -c "import json; print(json.load(open('$SCHEMA', encoding='utf-8')).get('\$id',''))")"
if [ "$SCHEMA_ID" = "https://github.com/aharada54914/sdd-forge/contracts/resolver-evidence.schema.json" ]; then
  pass "TEST-017 \$id matches contracts/*.schema.json convention"
else
  fail "TEST-017 \$id matches contracts/*.schema.json convention (got: $SCHEMA_ID)"
fi

# TEST-018/019/020: fixture-driven structural completeness.
for f in "$FIXTURES"/valid/*.json; do
  name="$(basename "$f")"
  if PY "$CHECK" "$SCHEMA" "$f" valid >/tmp/resolver-evidence-schema-check.$$.log 2>&1; then
    pass "valid fixture conforms: $name"
  else
    fail "valid fixture conforms: $name"
    cat /tmp/resolver-evidence-schema-check.$$.log >&2
  fi
  rm -f /tmp/resolver-evidence-schema-check.$$.log
done

for f in "$FIXTURES"/invalid/*.json; do
  name="$(basename "$f")"
  if PY "$CHECK" "$SCHEMA" "$f" invalid >/tmp/resolver-evidence-schema-check.$$.log 2>&1; then
    pass "invalid fixture rejected: $name"
  else
    fail "invalid fixture rejected: $name"
    cat /tmp/resolver-evidence-schema-check.$$.log >&2
  fi
  rm -f /tmp/resolver-evidence-schema-check.$$.log
done

# AC-020: always-emit-on-success — clean-success fixture carries diagnostics: [].
DIAG_LEN="$(PY -c "import json; print(len(json.load(open('$FIXTURES/valid/clean-success.json', encoding='utf-8'))['diagnostics']))")"
if [ "$DIAG_LEN" = "0" ]; then
  pass "TEST-020 clean-success fixture has diagnostics: []"
else
  fail "TEST-020 clean-success fixture has diagnostics: [] (got length $DIAG_LEN)"
fi

# AC-018: exact-set — one matched, one unmatched, exactly two capability_evaluations entries.
CAP_COUNTS="$(PY -c "
import json
d = json.load(open('$FIXTURES/valid/exact-set-two-capabilities.json', encoding='utf-8'))
caps = d['capability_evaluations']
matched = [c for c in caps if c['matched']]
unmatched = [c for c in caps if not c['matched']]
print(len(caps), len(matched), len(unmatched))
")"
if [ "$CAP_COUNTS" = "2 1 1" ]; then
  pass "TEST-018 exact-set fixture has exactly one matched and one unmatched entry"
else
  fail "TEST-018 exact-set fixture has exactly one matched and one unmatched entry (got: $CAP_COUNTS)"
fi

# AC-018 (M9): zero-affected-component fixture — every capability's trigger_evaluations is [].
ZERO_OK="$(PY -c "
import json
d = json.load(open('$FIXTURES/valid/zero-affected-components.json', encoding='utf-8'))
print(all(c['trigger_evaluations'] == [] for c in d['capability_evaluations']))
")"
if [ "$ZERO_OK" = "True" ]; then
  pass "TEST-018 zero-affected-component fixture: every trigger_evaluations is []"
else
  fail "TEST-018 zero-affected-component fixture: every trigger_evaluations is []"
fi

# AC-019: conditional-facet scoping — matched entry carries the key
# (declaration_index-keyed, two entries sharing one facet name), unmatched
# entry omits the key entirely.
FACET_OK="$(PY -c "
import json
d = json.load(open('$FIXTURES/valid/conditional-facet-scoping.json', encoding='utf-8'))
caps = {c['capability_id']: c for c in d['capability_evaluations']}
matched = caps['pii-handling']
unmatched = caps['payments']
facet_entries = matched.get('conditional_facet_evaluations', [])
idx = sorted(e['declaration_index'] for e in facet_entries)
same_facet = len({e['facet'] for e in facet_entries}) == 1
print(matched['matched'] is True and idx == [0, 1] and same_facet and 'conditional_facet_evaluations' not in unmatched)
")"
if [ "$FACET_OK" = "True" ]; then
  pass "TEST-019 conditional-facet scoping: declaration_index-keyed, unmatched entry omits key"
else
  fail "TEST-019 conditional-facet scoping: declaration_index-keyed, unmatched entry omits key"
fi

printf 'PASS: %s\n' "$PASS"
printf 'FAIL: %s\n' "$FAIL"
[ "$FAIL" -eq 0 ]
