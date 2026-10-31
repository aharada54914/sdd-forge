#!/usr/bin/env bash
# schema-engine-identity.tests.sh — audit "blocked on a recorded design
# constraint" item, resolved without amending the design.
#
# design.md records "four standalone validator scripts, none of which import
# from a sibling script", so the draft-07 subset engine is deliberately
# COPIED into validate-facet-manifest.py, validate-capability-summary.py and
# validate-context-projection.py rather than shared. Copies honor the
# recorded constraint; what was missing is the executable assertion that the
# copies stay identical — without it, a fix landing in one engine and not
# the others is invisible until an input disagrees (the WFI-038 class).
#
# This suite extracts each engine function by AST (not line numbers, so
# surrounding edits never break it) and requires the three copies to be
# byte-identical per function.
#
# Deliberately NOT in the identity set:
#   - validate-approval-sidecar.py: its header records an intentional
#     independence rationale and its engine was hardened separately.
#   - resolve-component-paths.py: a structurally different bounded-subset
#     engine whose parity partner is its own PowerShell twin (INV-008),
#     asserted by the component-path parity suites in CI.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
PASS=0
FAIL=0
ok()  { printf 'ok: %s\n' "$1"; PASS=$((PASS + 1)); }
bad() { printf 'not ok: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip - schema-engine-identity.tests.sh requires python3 (not found)"
    exit 0
fi

REPORT="$(python3 - "$ROOT" <<'PYEOF'
import ast
import hashlib
import sys

root = sys.argv[1]
files = [
    "plugins/sdd-quality-loop/scripts/validate-facet-manifest.py",
    "plugins/sdd-quality-loop/scripts/validate-capability-summary.py",
    "plugins/sdd-quality-loop/scripts/validate-context-projection.py",
]
ENGINE = [
    "_escape_pointer_token",
    "_ecma_anchor",
    "_compile_pattern",
    "_type_matches",
    "_resolve_ref",
    "_schema_matches",
    "_validate",
]

def segments(path):
    src = open(f"{root}/{path}", encoding="utf-8").read()
    lines = src.splitlines(keepends=True)
    tree = ast.parse(src)
    out = {}
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name in ENGINE:
            out[node.name] = "".join(lines[node.lineno - 1:node.end_lineno])
    return out

per_file = {p: segments(p) for p in files}
for fn in ENGINE:
    digests = {}
    for path, segs in per_file.items():
        if fn not in segs:
            print(f"MISSING\t{fn}\t{path}")
            continue
        digests[path] = hashlib.sha256(segs[fn].encode()).hexdigest()
    if len(set(digests.values())) == 1 and len(digests) == len(files):
        print(f"IDENTICAL\t{fn}\t{next(iter(digests.values()))[:12]}")
    elif digests:
        for path, digest in digests.items():
            print(f"DIVERGED\t{fn}\t{path}\t{digest[:12]}")
PYEOF
)" || { bad "engine extraction failed to run"; printf '\n%s: %d passed, %d failed\n' "$(basename "$0")" "$PASS" "$FAIL"; exit 1; }

for fn in _escape_pointer_token _ecma_anchor _compile_pattern _type_matches \
          _resolve_ref _schema_matches _validate; do
    line="$(printf '%s\n' "$REPORT" | awk -F'\t' -v fn="$fn" '$2 == fn')"
    case "$line" in
        IDENTICAL*) ok "engine function $fn is byte-identical across all three validators" ;;
        "") bad "engine function $fn was not found by the extractor in any validator" ;;
        *)  bad "engine function $fn diverged or is missing: $(printf '%s' "$line" | tr '\n' ' ')" ;;
    esac
done

# Non-vacuity: mutate one engine copy in a scratch tree and assert the same
# extractor reports divergence — otherwise an extractor bug that never finds
# the functions would read as "all identical".
WORK="$(mktemp -d "${TMPDIR:-/tmp}/schema-engine-identity.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT INT TERM
mkdir -p "$WORK/plugins/sdd-quality-loop/scripts"
for p in validate-facet-manifest.py validate-capability-summary.py validate-context-projection.py; do
    cp "$ROOT/plugins/sdd-quality-loop/scripts/$p" "$WORK/plugins/sdd-quality-loop/scripts/$p"
done
python3 - "$WORK" <<'PYEOF'
import ast
import sys
p = f"{sys.argv[1]}/plugins/sdd-quality-loop/scripts/validate-context-projection.py"
src = open(p, encoding="utf-8").read()
lines = src.splitlines(keepends=True)
node = next(n for n in ast.parse(src).body
            if isinstance(n, ast.FunctionDef) and n.name == "_ecma_anchor")
lines.insert(node.lineno, "    # mutated by the non-vacuity check\n")
open(p, "w", encoding="utf-8").write("".join(lines))
PYEOF
MUT="$(python3 - "$WORK" <<'PYEOF'
import ast, hashlib, sys
root = sys.argv[1]
files = [
    "plugins/sdd-quality-loop/scripts/validate-facet-manifest.py",
    "plugins/sdd-quality-loop/scripts/validate-capability-summary.py",
    "plugins/sdd-quality-loop/scripts/validate-context-projection.py",
]
digests = set()
for path in files:
    src = open(f"{root}/{path}", encoding="utf-8").read()
    lines = src.splitlines(keepends=True)
    for node in ast.parse(src).body:
        if isinstance(node, ast.FunctionDef) and node.name == "_ecma_anchor":
            digests.add(hashlib.sha256("".join(lines[node.lineno - 1:node.end_lineno]).encode()).hexdigest())
print("DIVERGED" if len(digests) > 1 else "IDENTICAL")
PYEOF
)"
if [ "$MUT" = "DIVERGED" ]; then
    ok "non-vacuity: a mutated engine copy is reported as diverged"
else
    bad "non-vacuity: the extractor failed to notice a deliberate mutation"
fi

printf '\n%s: %d passed, %d failed\n' "$(basename "$0")" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
