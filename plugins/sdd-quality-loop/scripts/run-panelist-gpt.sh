#!/bin/sh
# Collection layer: run OpenAI GPT panelist via codex CLI in isolated scratch.
# Usage:
#   run-panelist-gpt.sh --task T-NNN --feature <f> --input <bundle-path>
#                       [--spec-root <dir>] [--model <model-id>]
#                       [--effort <low|medium|high|xhigh>]
#                       [--digest <64-hex>] [--consent <kind>]
#
# Writes verdict JSON to:
#   specs/<feature>/verification/T-NNN.panelist-openai.verdict.json
#
# Graceful degrade (fusion-fable run_codex.sh pattern):
#   - codex CLI absent → exit 1 (non-zero, not exit 2; not a tool error)
#   - codex CLI errors → exit 1 with message to stderr
#   - Scratch dir always cleaned up via trap
#
# Security (design.md §6):
#   - SDD_EVIDENCE_KEY / SDD_SUDO_KEY are never passed to the panelist
#   - Input bundle must be pre-sanitized by prepare-panelist-input
#   - Panelist runs with --no-project-doc to prevent extra context bleed
#   - --effort (epic-159-pillar-c T-006, REQ-006/AC-035): optional, forwarded
#     verbatim to the `codex` invocation alongside --model. Omitted entirely
#     preserves today's exact invocation (design.md API/Contract Plan;
#     Breaking API: no).
#   - Injection rejection (REQ-006 AC-052; security-spec.md B3): --model and
#     --effort are validated BEFORE the `codex` invocation is assembled.
#     Values containing whitespace, a leading `-`/`--` (flag-injection
#     shape), or a `;` (command-separator shape) are rejected fail-closed
#     (non-zero exit, diagnostic, zero `codex` invocations); --effort is
#     additionally rejected when it is not one of the registry's enumerated
#     `{low, medium, high, xhigh}` values. This script has no `--registry`
#     of its own, so the deeper "member of the registry's enumerated MODEL
#     names" check is the caller's responsibility (the caller is expected to
#     source --model/--effort only from `select-agent-model --host
#     codex-cli` output, never from unsanitized task/spec text) — this
#     script's own layer catches the shape-based attack classes directly.
#
# Exit codes: 0=success  1=CLI absent or panelist failure  2=bad args/rejected value

task_id=""
feature=""
input_path=""
spec_root="specs"
model="gpt-4o"
effort=""
input_digest=""
consent_kind="human-flag"

while [ $# -gt 0 ]; do
    case "$1" in
        --task)      task_id="$2";      shift 2 ;;
        --feature)   feature="$2";      shift 2 ;;
        --input)     input_path="$2";   shift 2 ;;
        --spec-root) spec_root="$2";    shift 2 ;;
        --model)     model="$2";        shift 2 ;;
        --effort)    effort="$2";       shift 2 ;;
        --digest)    input_digest="$2"; shift 2 ;;
        --consent)   consent_kind="$2"; shift 2 ;;
        *) printf 'run-panelist-gpt: unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done

# ── Reject argv-injection-shaped --model/--effort values (AC-052) ───────────
# Runs BEFORE any other validation or the codex invocation is assembled, so
# a rejected value never reaches the codex command line.

_reject_shape() {
    # $1=flag label, $2=value. Exits 2 (does not return) on a shape violation.
    _rs_label="$1"
    _rs_val="$2"
    case "$_rs_val" in
        *[[:space:]]*)
            printf 'run-panelist-gpt: %s contains whitespace (rejected, argv-injection shape): %s\n' \
                "$_rs_label" "$_rs_val" >&2
            exit 2
            ;;
    esac
    case "$_rs_val" in
        -*)
            printf 'run-panelist-gpt: %s has a leading "-" (rejected, flag-injection shape): %s\n' \
                "$_rs_label" "$_rs_val" >&2
            exit 2
            ;;
    esac
    case "$_rs_val" in
        *';'*)
            printf 'run-panelist-gpt: %s contains ";" (rejected, command-separator shape): %s\n' \
                "$_rs_label" "$_rs_val" >&2
            exit 2
            ;;
    esac
}

[ -n "$model" ] && _reject_shape "--model" "$model"
if [ -n "$effort" ]; then
    _reject_shape "--effort" "$effort"
    case "$effort" in
        low | medium | high | xhigh) : ;;
        *)
            printf 'run-panelist-gpt: --effort must be one of low|medium|high|xhigh (got: %s)\n' \
                "$effort" >&2
            exit 2
            ;;
    esac
fi

# ── Validate required arguments ──────────────────────────────────────────────

if [ -z "$task_id" ]; then
    printf 'run-panelist-gpt: --task is required\n' >&2; exit 2
fi
if [ -z "$feature" ]; then
    printf 'run-panelist-gpt: --feature is required\n' >&2; exit 2
fi
if [ -z "$input_path" ]; then
    printf 'run-panelist-gpt: --input is required\n' >&2; exit 2
fi
if [ ! -f "$input_path" ]; then
    printf 'run-panelist-gpt: input file not found: %s\n' "$input_path" >&2; exit 1
fi

# ── Check CLI availability ───────────────────────────────────────────────────

_codex_cmd=""
if command -v codex >/dev/null 2>&1; then
    _codex_cmd="codex"
elif command -v openai >/dev/null 2>&1; then
    _codex_cmd="openai"
else
    printf 'run-panelist-gpt: codex CLI not found in PATH — skipping GPT panelist (graceful degrade)\n' >&2
    exit 1
fi

# ── Prepare scratch and output paths ────────────────────────────────────────

_scratch="$(mktemp -d)"
trap 'rm -rf "$_scratch"' EXIT

out_dir="${spec_root}/${feature}/verification"
mkdir -p "$out_dir" || {
    printf 'run-panelist-gpt: cannot create output directory: %s\n' "$out_dir" >&2; exit 2
}
out_path="${out_dir}/${task_id}.panelist-openai.verdict.json"

# ── Key isolation: ensure keys are NOT in environment ──────────────────────
# Unset key material so the sub-process cannot observe it.
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
  "vendor": "openai",
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

# ── Invoke codex CLI in isolated scratch ─────────────────────────────────────
# Pass the prompt and input bundle to codex via stdin concatenation.
# Use --no-project-doc to prevent leaking additional project context.

_combined="${_scratch}/combined.txt"
{
    cat "$_prompt_file"
    printf '\n\n## Sanitized Input Bundle\n\n'
    cat "$input_path"
} > "$_combined"

if [ -n "$effort" ]; then
    printf 'run-panelist-gpt: invoking %s --model %s --effort %s (task=%s feature=%s)\n' \
        "$_codex_cmd" "$model" "$effort" "$task_id" "$feature" >&2
else
    printf 'run-panelist-gpt: invoking %s --model %s (task=%s feature=%s)\n' \
        "$_codex_cmd" "$model" "$task_id" "$feature" >&2
fi

_raw_output="${_scratch}/raw-output.txt"
if [ -n "$effort" ]; then
    # --effort supplied: forwarded to codex alongside --model (AC-035).
    if ! "$_codex_cmd" --model "$model" --effort "$effort" --no-project-doc < "$_combined" > "$_raw_output" 2>&1; then
        _rc=$?
        printf 'run-panelist-gpt: codex CLI exited %d\n' "$_rc" >&2
        cat "$_raw_output" >&2
        exit 1
    fi
else
    # --effort omitted: byte-identical to the pre-T-006 invocation
    # (Breaking API: no -- design.md API/Contract Plan).
    if ! "$_codex_cmd" --model "$model" --no-project-doc < "$_combined" > "$_raw_output" 2>&1; then
        _rc=$?
        printf 'run-panelist-gpt: codex CLI exited %d\n' "$_rc" >&2
        cat "$_raw_output" >&2
        exit 1
    fi
fi

# ── Extract and validate JSON from output ────────────────────────────────────
# The output may contain prose + JSON; extract the first JSON object.

if ! command -v python3 >/dev/null 2>&1; then
    printf 'run-panelist-gpt: python3 is required to extract and validate verdict JSON\n' >&2
    exit 2
fi

python3 - "$_raw_output" "$out_path" "$task_id" "$feature" "$model" "$input_digest" "$consent_kind" << 'PYEOF'
import json, re, sys

raw_file, out_path, task_id, feature, model, expected_digest, consent_kind = sys.argv[1:]

with open(raw_file, encoding="utf-8", errors="replace") as f:
    raw = f.read()

# Try to extract JSON object from output
match = re.search(r'\{[\s\S]*\}', raw)
if not match:
    print(f"run-panelist-gpt: no JSON object found in codex output", file=sys.stderr)
    print(f"raw output: {raw[:500]}", file=sys.stderr)
    sys.exit(1)

try:
    verdict = json.loads(match.group(0))
except json.JSONDecodeError as e:
    print(f"run-panelist-gpt: invalid JSON from codex: {e}", file=sys.stderr)
    sys.exit(1)

# Minimal schema validation
required_fields = ["schema","task_id","feature","vendor","model","verdict","findings","blind","input_digest","consent"]
missing = [f for f in required_fields if f not in verdict]
if missing:
    print(f"run-panelist-gpt: verdict missing fields: {missing}", file=sys.stderr)
    sys.exit(1)

if verdict.get("schema") != "cross-model-verdict/v1":
    print(f"run-panelist-gpt: wrong schema: {verdict.get('schema')}", file=sys.stderr)
    sys.exit(1)

if verdict.get("blind") is not True:
    print("run-panelist-gpt: blind must be true", file=sys.stderr)
    sys.exit(1)

digest = verdict.get("input_digest","")
if not re.match(r'^[0-9a-f]{64}$', digest):
    print(f"run-panelist-gpt: input_digest must be 64 lowercase hex, got: {digest!r}", file=sys.stderr)
    sys.exit(1)

if verdict.get("verdict") not in ("PASS","NEEDS_WORK"):
    print(f"run-panelist-gpt: verdict must be PASS or NEEDS_WORK, got: {verdict.get('verdict')!r}", file=sys.stderr)
    sys.exit(1)

# Normalize fields
verdict["task_id"] = task_id
verdict["feature"] = feature
verdict["vendor"] = "openai"

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(verdict, f, indent=2)
    f.write("\n")

print(f"run-panelist-gpt: verdict written to {out_path}", file=sys.stderr)
print(out_path)
PYEOF
_py_rc=$?

if [ "$_py_rc" -ne 0 ]; then
    exit 1
fi

exit 0
