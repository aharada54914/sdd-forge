#!/bin/sh
# Collection layer: run Google Gemini panelist via gemini CLI in isolated scratch.
# Usage:
#   run-panelist-gemini.sh --task T-NNN --feature <f> --input <bundle-path>
#                          [--spec-root <dir>] [--model <model-id>]
#                          [--digest <64-hex>] [--consent <kind>]
#
# Writes verdict JSON to:
#   specs/<feature>/verification/T-NNN.panelist-google.verdict.json
#
# Graceful degrade (fusion-fable run_gemini.sh pattern):
#   - gemini CLI absent → exit 1 (graceful degrade, not exit 2)
#   - gemini CLI errors → exit 1 with message to stderr
#   - Scratch dir always cleaned up via trap
#
# Security (design.md §6):
#   - SDD_EVIDENCE_KEY / SDD_SUDO_KEY are never passed to the panelist
#   - Input bundle must be pre-sanitized by prepare-panelist-input
#
# Exit codes: 0=success  1=CLI absent or panelist failure  2=bad args

task_id=""
feature=""
input_path=""
spec_root="specs"
model="gemini-2.0-flash"
input_digest=""
consent_kind="human-flag"

while [ $# -gt 0 ]; do
    case "$1" in
        --task)      task_id="$2";      shift 2 ;;
        --feature)   feature="$2";      shift 2 ;;
        --input)     input_path="$2";   shift 2 ;;
        --spec-root) spec_root="$2";    shift 2 ;;
        --model)     model="$2";        shift 2 ;;
        --digest)    input_digest="$2"; shift 2 ;;
        --consent)   consent_kind="$2"; shift 2 ;;
        *) printf 'run-panelist-gemini: unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done

# ── Validate required arguments ──────────────────────────────────────────────

if [ -z "$task_id" ]; then
    printf 'run-panelist-gemini: --task is required\n' >&2; exit 2
fi
if [ -z "$feature" ]; then
    printf 'run-panelist-gemini: --feature is required\n' >&2; exit 2
fi
if [ -z "$input_path" ]; then
    printf 'run-panelist-gemini: --input is required\n' >&2; exit 2
fi
if [ ! -f "$input_path" ]; then
    printf 'run-panelist-gemini: input file not found: %s\n' "$input_path" >&2; exit 1
fi

# ── Check CLI availability ───────────────────────────────────────────────────

if ! command -v gemini >/dev/null 2>&1; then
    printf 'run-panelist-gemini: gemini CLI not found in PATH — skipping Gemini panelist (graceful degrade)\n' >&2
    exit 1
fi

# ── Prepare scratch and output paths ────────────────────────────────────────

_scratch="$(mktemp -d)"
trap 'rm -rf "$_scratch"' EXIT

out_dir="${spec_root}/${feature}/verification"
mkdir -p "$out_dir" || {
    printf 'run-panelist-gemini: cannot create output directory: %s\n' "$out_dir" >&2; exit 2
}
out_path="${out_dir}/${task_id}.panelist-google.verdict.json"

# ── Key isolation ────────────────────────────────────────────────────────────
unset SDD_EVIDENCE_KEY SDD_SUDO_KEY SDD_SUDO_KEY_FILE

# ── Build the panelist prompt ────────────────────────────────────────────────

_prompt_file="${_scratch}/prompt.txt"
cat > "$_prompt_file" << 'PROMPT_EOF'
You are an independent panelist reviewing a software implementation. You are
running BLIND: you have not seen any other panelist's verdict, the primary
evaluator's verdict, or any prior review feedback on this task.

Your role is READ-ONLY. You must not suggest, write, or edit code. You must
not approve or set any task status. Return a structured verdict JSON only.

## Input

The sanitized input bundle follows this message. Review it for correctness,
completeness, and adherence to the stated requirements and design.

## Output Format

Return ONLY a JSON object in this exact schema (no markdown, no prose):

{
  "schema": "cross-model-verdict/v1",
  "task_id": "<task_id>",
  "feature": "<feature>",
  "vendor": "google",
  "model": "<model>",
  "verdict": "PASS" | "NEEDS_WORK",
  "findings": [
    { "severity": "Critical" | "Major" | "Minor", "ref": "<file:line or section>", "note": "<description>" }
  ],
  "blind": true,
  "input_digest": "<digest-from-bundle-header>",
  "consent": { "kind": "<consent-kind>", "ref": "<ref>" }
}

Rules:
- verdict MUST be "PASS" or "NEEDS_WORK".
- findings MUST be an array (empty [] if none).
- blind MUST be true (boolean, not string).
- input_digest: copy the value from the "# input_digest:" comment in the bundle header.
- consent.kind: copy from the "# consent:" comment in the bundle header.
- consent.ref: the tasks.md flag or SDD_SUDO reference from the bundle.
- Do not include any text outside the JSON object.
PROMPT_EOF

# ── Invoke gemini CLI in isolated scratch ────────────────────────────────────

_combined="${_scratch}/combined.txt"
{
    cat "$_prompt_file"
    printf '\n\n## Sanitized Input Bundle\n\n'
    cat "$input_path"
} > "$_combined"

printf 'run-panelist-gemini: invoking gemini --model %s (task=%s feature=%s)\n' \
    "$model" "$task_id" "$feature" >&2

_raw_output="${_scratch}/raw-output.txt"
if ! gemini --model "$model" < "$_combined" > "$_raw_output" 2>&1; then
    _rc=$?
    printf 'run-panelist-gemini: gemini CLI exited %d\n' "$_rc" >&2
    cat "$_raw_output" >&2
    exit 1
fi

# ── Extract and validate JSON from output ────────────────────────────────────

if ! command -v python3 >/dev/null 2>&1; then
    printf 'run-panelist-gemini: python3 is required to extract and validate verdict JSON\n' >&2
    exit 2
fi

python3 - "$_raw_output" "$out_path" "$task_id" "$feature" "$model" "$input_digest" "$consent_kind" << 'PYEOF'
import json, re, sys

raw_file, out_path, task_id, feature, model, expected_digest, consent_kind = sys.argv[1:]

with open(raw_file, encoding="utf-8", errors="replace") as f:
    raw = f.read()

match = re.search(r'\{[\s\S]*\}', raw)
if not match:
    print("run-panelist-gemini: no JSON object found in gemini output", file=sys.stderr)
    print(f"raw output: {raw[:500]}", file=sys.stderr)
    sys.exit(1)

try:
    verdict = json.loads(match.group(0))
except json.JSONDecodeError as e:
    print(f"run-panelist-gemini: invalid JSON from gemini: {e}", file=sys.stderr)
    sys.exit(1)

required_fields = ["schema","task_id","feature","vendor","model","verdict","findings","blind","input_digest","consent"]
missing = [f for f in required_fields if f not in verdict]
if missing:
    print(f"run-panelist-gemini: verdict missing fields: {missing}", file=sys.stderr)
    sys.exit(1)

if verdict.get("schema") != "cross-model-verdict/v1":
    print(f"run-panelist-gemini: wrong schema: {verdict.get('schema')}", file=sys.stderr)
    sys.exit(1)
if verdict.get("blind") is not True:
    print("run-panelist-gemini: blind must be true", file=sys.stderr)
    sys.exit(1)
if not re.match(r'^[0-9a-f]{64}$', verdict.get("input_digest","")):
    print(f"run-panelist-gemini: input_digest must be 64 lowercase hex", file=sys.stderr)
    sys.exit(1)
if verdict.get("verdict") not in ("PASS","NEEDS_WORK"):
    print(f"run-panelist-gemini: verdict must be PASS or NEEDS_WORK", file=sys.stderr)
    sys.exit(1)

verdict["task_id"] = task_id
verdict["feature"] = feature
verdict["vendor"]  = "google"

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(verdict, f, indent=2)
    f.write("\n")

print(f"run-panelist-gemini: verdict written to {out_path}", file=sys.stderr)
print(out_path)
PYEOF
_py_rc=$?

if [ "$_py_rc" -ne 0 ]; then
    exit 1
fi

exit 0
