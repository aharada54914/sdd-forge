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
#   - gemini CLI exceeds SDD_PANELIST_TIMEOUT → process group terminated, exit 1
#   - Scratch dir always cleaned up via trap
#
# Security (design.md §6):
#   - SDD_EVIDENCE_KEY / SDD_SUDO_KEY are never passed to the panelist
#   - Input bundle must be pre-sanitized by prepare-panelist-input
#
# CLI contract: the installed `gemini` CLI only runs non-interactively via
# `-p/--prompt` ("Run in non-interactive (headless) mode with the given
# prompt. Appended to input on stdin (if any)."). Bare `gemini --model
# <m> < bundle` with no `-p` is NOT headless and can print
# "No input provided via stdin..." or otherwise fail to produce a verdict.
# This script therefore supplies the panelist instructions via `-p` and
# pipes the sanitized bundle on stdin, per the CLI's own documented
# contract (checked live against the installed gemini binary, not assumed).
#
# Exit codes: 0=success  1=CLI absent or panelist failure (CLI non-zero
#             exit, timeout, or output that does not parse into a valid
#             cross-model-verdict/v1 JSON object)  2=bad args. A run that
#             fails for any reason writes NO verdict file (graceful degrade
#             never means a false success).

# Shared collection-layer helpers (timeout/arg validation, bounded runner).
_script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# Probe before sourcing: POSIX shells (dash among them) treat a failed `.`
# special builtin as fatal, so an if-guard around the dot itself can never
# run its else branch -- the readability test is what keeps this documented
# diagnostic and exit code reachable on a partial or damaged installation.
if [ ! -r "$_script_dir/lib/panelist-common.sh" ]; then
    printf 'run-panelist-gemini: lib/panelist-common.sh unavailable beside this script\n' >&2
    exit 2
fi
. "$_script_dir/lib/panelist-common.sh"

task_id=""
feature=""
input_path=""
spec_root="specs"
model="gemini-2.0-flash"
input_digest=""
consent_kind="human-flag"
_panelist_timeout="${SDD_PANELIST_TIMEOUT:-600}"

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

sdd_panelist_validate_timeout "run-panelist-gemini" "$_panelist_timeout"

# ── Validate required arguments ──────────────────────────────────────────────

sdd_panelist_require_args "run-panelist-gemini" "$task_id" "$feature" "$input_path"

# ── Check CLI availability ───────────────────────────────────────────────────

if ! command -v gemini >/dev/null 2>&1; then
    printf 'run-panelist-gemini: gemini CLI not found in PATH — skipping Gemini panelist (graceful degrade)\n' >&2
    exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
    printf 'run-panelist-gemini: python3 is required to supervise the panelist process group\n' >&2
    exit 2
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

# _sdd_run_bounded comes from lib/panelist-common.sh (process-group,
# completion-marker, and stdin `<&0` rationale documented there). It reads
# $_scratch, which is set above.

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
# The panelist instructions go through `-p/--prompt` (the CLI's documented
# non-interactive entry point); the sanitized bundle is piped on stdin,
# which the CLI appends after the -p prompt. No prompt/bundle concatenation
# is needed here (unlike the codex twin, which has no dedicated instruction
# flag and stays with a single combined stdin blob).

_stdin_bundle="${_scratch}/stdin-bundle.txt"
{
    printf '## Sanitized Input Bundle\n\n'
    cat "$input_path"
} > "$_stdin_bundle"
_prompt_text="$(cat "$_prompt_file")"

printf 'run-panelist-gemini: invoking gemini --model %s -p <prompt> (task=%s feature=%s)\n' \
    "$model" "$task_id" "$feature" >&2

_raw_output="${_scratch}/raw-output.txt"
_sdd_run_bounded "$_panelist_timeout" gemini --model "$model" -p "$_prompt_text" \
    < "$_stdin_bundle" > "$_raw_output" 2>&1
_rc=$?
if [ "$_rc" -ne 0 ]; then
    if [ "$_rc" -eq 124 ]; then
        printf 'run-panelist-gemini: gemini CLI exceeded SDD_PANELIST_TIMEOUT=%ss; terminated\n' \
            "$_panelist_timeout" >&2
    else
        printf 'run-panelist-gemini: gemini CLI exited %d\n' "$_rc" >&2
    fi
    cat "$_raw_output" >&2
    exit 1
fi

# ── Extract and validate JSON from output ────────────────────────────────────

python3 - "$_raw_output" "$out_path" "$task_id" "$feature" "$model" "$input_digest" "$consent_kind" << 'PYEOF'
import json, re, sys

raw_file, out_path, task_id, feature, model, expected_digest, consent_kind = sys.argv[1:]

with open(raw_file, encoding="utf-8", errors="replace") as f:
    raw = f.read()

TARGET_SCHEMA = "cross-model-verdict/v1"


def strip_code_fences(text):
    # Models wrap replies in ```json fences constantly, regardless of what
    # the prompt asks for. The brace-balancer below does not depend on
    # this (it only tracks '{'..matching '}'), but stripping fence lines
    # first keeps diagnostics free of fence noise.
    return re.sub(r'```[ \t]*[A-Za-z0-9_-]*[ \t]*\r?\n|```', '', text)


def find_json_object_candidates(text):
    """Return each top-level brace-balanced '{...}' substring of `text`,
    in order of appearance. String literals (and their backslash escapes)
    are tracked so a '}' inside a JSON string does not close a candidate
    early. Nested objects are not yielded separately -- only the outermost
    '{' of each candidate starts a new scan."""
    candidates = []
    n = len(text)
    i = 0
    while i < n:
        if text[i] != '{':
            i += 1
            continue
        start = i
        depth = 0
        in_string = False
        escape = False
        j = i
        closed_at = -1
        while j < n:
            c = text[j]
            if in_string:
                if escape:
                    escape = False
                elif c == '\\':
                    escape = True
                elif c == '"':
                    in_string = False
            else:
                if c == '"':
                    in_string = True
                elif c == '{':
                    depth += 1
                elif c == '}':
                    depth -= 1
                    if depth == 0:
                        closed_at = j
                        break
            j += 1
        if closed_at >= 0:
            candidates.append(text[start:closed_at + 1])
            i = closed_at + 1
        else:
            # Unterminated from this '{' (e.g. a truncated echo) -- advance
            # past it and keep scanning for the next candidate.
            i = start + 1
    return candidates


cleaned = strip_code_fences(raw)
candidates = find_json_object_candidates(cleaned)

verdict = None
rejections = []
for idx, candidate in enumerate(candidates, start=1):
    try:
        parsed = json.loads(candidate)
    except json.JSONDecodeError as e:
        rejections.append(f"candidate {idx}: parse error: {e}")
        continue
    if not isinstance(parsed, dict):
        rejections.append(f"candidate {idx}: parsed but is not a JSON object")
        continue
    schema = parsed.get("schema")
    if schema != TARGET_SCHEMA:
        rejections.append(f"candidate {idx}: parsed but schema is {schema!r} (expected {TARGET_SCHEMA!r})")
        continue
    verdict = parsed  # keep scanning -- the LAST matching candidate wins

if verdict is None:
    if not candidates:
        print("run-panelist-gemini: no JSON object found in gemini output", file=sys.stderr)
    else:
        print(
            f"run-panelist-gemini: no {TARGET_SCHEMA} verdict found among "
            f"{len(candidates)} candidate JSON object(s) in gemini output",
            file=sys.stderr,
        )
        for reason in rejections:
            print(f"  {reason}", file=sys.stderr)
    print(f"raw output: {raw[:500]}", file=sys.stderr)
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
