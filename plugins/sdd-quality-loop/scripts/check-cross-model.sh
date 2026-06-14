#!/bin/sh
# Deterministic gate: cross-model consensus verification
# Usage: check-cross-model.sh --task T-NNN --feature <f> [--evaluator PASS|NEEDS_WORK]
#        [--expect-digest <64-hex>] [--spec-root <dir>]
#
# Reads all T-NNN.panelist-*.verdict.json under <spec-root>/<feature>/verification/
# Applies consensus policy (design.md §3), writes aggregate JSON, exits 0/1/2.
#
# Exit codes: 0=pass  1=fail  2=tool error (bad args / malformed verdict / no verdicts)

task_id=""
feature=""
evaluator=""
expect_digest=""
spec_root="specs"

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        --task)         task_id="$2";       shift 2 ;;
        --feature)      feature="$2";       shift 2 ;;
        --evaluator)    evaluator="$2";     shift 2 ;;
        --expect-digest) expect_digest="$2"; shift 2 ;;
        --spec-root)    spec_root="$2";     shift 2 ;;
        *) echo "check-cross-model: unknown argument: $1" >&2; exit 2 ;;
    esac
done

if [ -z "$task_id" ] || [ -z "$feature" ]; then
    echo "check-cross-model: --task and --feature are required" >&2
    exit 2
fi

verdict_dir="${spec_root}/${feature}/verification"
aggregate_path="${verdict_dir}/${task_id}.cross-model.json"

# Dispatch: python3 (preferred) or exit 2 if not available — JSON required
if ! command -v python3 >/dev/null 2>&1; then
    echo "check-cross-model: python3 is required but not found" >&2
    exit 2
fi

python3 - <<PYEOF
import json, os, re, sys

task_id      = "${task_id}"
feature      = "${feature}"
evaluator    = "${evaluator}"
expect_digest = "${expect_digest}"
verdict_dir  = "${verdict_dir}"
aggregate_path = "${aggregate_path}"

# ── helpers ────────────────────────────────────────────────────────────────

def write_aggregate(panelists, vendors_distinct, non_anthropic_count,
                    all_pass, any_critical, evaluator_verdict,
                    divergence, requires_human, result):
    agg = {
        "schema": "cross-model-aggregate/v1",
        "task_id": task_id,
        "feature": feature,
        "panelists": panelists,
        "vendors_distinct": vendors_distinct,
        "non_anthropic_count": non_anthropic_count,
        "all_pass": all_pass,
        "any_critical": any_critical,
        "evaluator_verdict": evaluator_verdict if evaluator_verdict else None,
        "divergence": divergence,
        "requires_human_decision": requires_human,
        "result": result,
    }
    os.makedirs(os.path.dirname(aggregate_path), exist_ok=True)
    with open(aggregate_path, "w", encoding="utf-8") as f:
        json.dump(agg, f, indent=2)
        f.write("\n")

HEX64 = re.compile(r'^[0-9a-fA-F]{64}$')
VALID_CONSENT_KINDS = {"human-flag", "sudo"}

# ── Step 0: discover verdict files ─────────────────────────────────────────

prefix = task_id + ".panelist-"
suffix = ".verdict.json"

if not os.path.isdir(verdict_dir):
    print(f"check-cross-model: verdict dir not found: {verdict_dir}", file=sys.stderr)
    sys.exit(2)

verdict_files = [
    os.path.join(verdict_dir, f)
    for f in sorted(os.listdir(verdict_dir))
    if f.startswith(prefix) and f.endswith(suffix)
]

if not verdict_files:
    print(f"check-cross-model: no verdict files found matching {prefix}*{suffix} in {verdict_dir}", file=sys.stderr)
    sys.exit(2)

# ── Step 1: parse + schema-validate each verdict ───────────────────────────

verdicts = []
for vpath in verdict_files:
    try:
        with open(vpath, encoding="utf-8") as f:
            v = json.load(f)
    except Exception as e:
        print(f"check-cross-model: failed to parse {vpath}: {e}", file=sys.stderr)
        sys.exit(2)

    # blind must be exactly true (boolean)
    if v.get("blind") is not True:
        print(f"check-cross-model: {os.path.basename(vpath)}: blind must be true (got {v.get('blind')!r})", file=sys.stderr)
        sys.exit(2)

    # input_digest must be 64-hex
    digest = v.get("input_digest", "")
    if not HEX64.match(str(digest)):
        print(f"check-cross-model: {os.path.basename(vpath)}: input_digest must be 64-hex (got {digest!r})", file=sys.stderr)
        sys.exit(2)

    # vendor must be non-empty string
    vendor = v.get("vendor", "")
    if not vendor or not isinstance(vendor, str):
        print(f"check-cross-model: {os.path.basename(vpath)}: vendor must be non-empty string", file=sys.stderr)
        sys.exit(2)

    # consent.kind must be present
    consent = v.get("consent")
    if not isinstance(consent, dict) or not consent.get("kind"):
        print(f"check-cross-model: {os.path.basename(vpath)}: consent.kind is required", file=sys.stderr)
        sys.exit(2)

    verdicts.append(v)

# ── Step 2: compute vendor diversity metrics ────────────────────────────────

all_vendors = [v["vendor"] for v in verdicts]
distinct_vendors = set(v.lower() for v in all_vendors)
vendors_distinct = len(distinct_vendors)
non_anthropic_count = sum(1 for v in distinct_vendors if v != "anthropic")

# Build panelist list for aggregate
panelists = [
    {"vendor": v["vendor"], "model": v.get("model", ""), "verdict": v.get("verdict", "")}
    for v in verdicts
]

# ── Step 3: diversity check ─────────────────────────────────────────────────

if vendors_distinct < 2 or non_anthropic_count < 1:
    write_aggregate(panelists, vendors_distinct, non_anthropic_count,
                    False, False, evaluator or None,
                    False, False, "FAIL")
    print(f"check-cross-model: diversity check failed: vendors_distinct={vendors_distinct} non_anthropic_count={non_anthropic_count} (need >=2 distinct and >=1 non-anthropic)", file=sys.stderr)
    sys.exit(1)

# ── Step 4: consent check ───────────────────────────────────────────────────
# Already validated per-verdict in Step 1 (consent.kind present).
# Nothing more to do here — all verdicts carry consent.

# ── Step 5: digest check (if --expect-digest) ───────────────────────────────

if expect_digest:
    mismatches = [
        os.path.basename(vpath)
        for vpath, v in zip(verdict_files, verdicts)
        if v.get("input_digest", "").lower() != expect_digest.lower()
    ]
    if mismatches:
        write_aggregate(panelists, vendors_distinct, non_anthropic_count,
                        False, False, evaluator or None,
                        False, False, "FAIL")
        print(f"check-cross-model: input_digest mismatch in: {', '.join(mismatches)}", file=sys.stderr)
        sys.exit(1)

# ── Step 6: consensus check ─────────────────────────────────────────────────

all_pass = all(v.get("verdict") == "PASS" for v in verdicts)
any_critical = any(
    f.get("severity") == "Critical"
    for v in verdicts
    for f in (v.get("findings") or [])
)

if not all_pass or any_critical:
    write_aggregate(panelists, vendors_distinct, non_anthropic_count,
                    all_pass, any_critical, evaluator or None,
                    False, False, "FAIL")
    reason = []
    if not all_pass:
        reason.append("not all verdicts are PASS")
    if any_critical:
        reason.append("Critical finding(s) present")
    print(f"check-cross-model: consensus FAIL: {'; '.join(reason)}", file=sys.stderr)
    sys.exit(1)

# ── Step 7: evaluator divergence check ─────────────────────────────────────

if evaluator:
    # Panel consensus is PASS (we passed step 6).
    panel_consensus = "PASS"
    if evaluator != panel_consensus:
        write_aggregate(panelists, vendors_distinct, non_anthropic_count,
                        True, False, evaluator,
                        True, True, "NEEDS_HUMAN")
        print(f"check-cross-model: evaluator={evaluator} diverges from panel consensus={panel_consensus}; requires human decision", file=sys.stderr)
        sys.exit(1)

# ── Step 8: all checks passed → PASS ───────────────────────────────────────

write_aggregate(panelists, vendors_distinct, non_anthropic_count,
                True, False, evaluator if evaluator else None,
                False, False, "PASS")
print(f"check-cross-model: consensus PASS for {task_id} ({len(verdicts)} panelists, {vendors_distinct} distinct vendors)")
sys.exit(0)
PYEOF

rc=$?
exit $rc
