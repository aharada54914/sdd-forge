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
#   - codex CLI exceeds SDD_PANELIST_TIMEOUT → process group terminated, exit 1
#   - Scratch dir always cleaned up via trap
#
# Security (design.md §6):
#   - SDD_EVIDENCE_KEY / SDD_SUDO_KEY are never passed to the panelist
#   - Input bundle must be pre-sanitized by prepare-panelist-input
#   - Panelist runs `codex exec --sandbox read-only --skip-git-repo-check`
#     rooted at an isolated scratch dir (`-C`) so it can neither read
#     repository files beyond the piped bundle nor write anything (codex-cli
#     0.147.0: bare top-level flags like the old `--no-project-doc` are
#     rejected by `codex exec`'s clap parser -- there is no direct
#     replacement flag; the read-only sandbox + isolated cwd achieve the
#     same "no extra context bleed" intent by construction instead)
#   - --effort (epic-159-pillar-c T-006, REQ-006/AC-035): optional, forwarded
#     to the `codex exec` invocation as `-c model_reasoning_effort=<effort>`
#     (codex-cli 0.147.0 has no `--effort` flag; reasoning effort is a
#     config override). Omitted entirely omits the `-c` override too.
#   - codex resolution (invocation-contract hardening): `codex` may resolve
#     via a shell alias/wrapper (e.g. `codex-sync`) that performs unrelated
#     side effects (git sync, banner) and must never be invoked as the
#     panelist CLI. `SDD_PANELIST_CODEX_CMD` overrides resolution outright;
#     otherwise `command -v codex` is resolved to its real target and
#     rejected if that target names `codex-sync`.
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
# Exit codes: 0=success  1=CLI absent/unreachable or panelist failure (CLI
#             non-zero exit, timeout, or output that does not parse into a
#             valid cross-model-verdict/v1 JSON object)  2=bad args/rejected
#             value. A run that fails for any reason writes NO verdict file
#             (graceful degrade never means a false success).

task_id=""
feature=""
input_path=""
spec_root="specs"
model="gpt-4o"
effort=""
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
        --effort)    effort="$2";       shift 2 ;;
        --digest)    input_digest="$2"; shift 2 ;;
        --consent)   consent_kind="$2"; shift 2 ;;
        *) printf 'run-panelist-gpt: unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done

case "$_panelist_timeout" in
    '' | *[!0-9]*)
        printf 'run-panelist-gpt: SDD_PANELIST_TIMEOUT must be a positive whole number of seconds (got: %s)\n' \
            "$_panelist_timeout" >&2
        exit 2
        ;;
esac
if [ "$_panelist_timeout" -le 0 ]; then
    printf 'run-panelist-gpt: SDD_PANELIST_TIMEOUT must be positive (got: %s)\n' \
        "$_panelist_timeout" >&2
    exit 2
fi

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

# ── Resolve and check CLI availability ──────────────────────────────────────
# Never invoke a `codex` that resolves to the `codex-sync` wrapper (git sync
# + banner side effects, not the panelist CLI). SDD_PANELIST_CODEX_CMD is an
# explicit override; otherwise the resolved real target of `command -v
# codex` is inspected and rejected if it names codex-sync.

_codex_cmd=""
if [ -n "${SDD_PANELIST_CODEX_CMD:-}" ]; then
    _codex_cmd="$SDD_PANELIST_CODEX_CMD"
else
    _candidate="$(command -v codex 2>/dev/null || true)"
    if [ -n "$_candidate" ]; then
        _resolved="$_candidate"
        if command -v readlink >/dev/null 2>&1; then
            _resolved="$(readlink -f "$_candidate" 2>/dev/null || printf '%s' "$_candidate")"
        fi
        case "$_resolved" in
            *codex-sync*) _candidate="" ;;
        esac
    fi
    if [ -n "$_candidate" ]; then
        _codex_cmd="$_candidate"
    elif command -v openai >/dev/null 2>&1; then
        _codex_cmd="openai"
    fi
fi
if [ -z "$_codex_cmd" ]; then
    printf 'run-panelist-gpt: codex CLI not found in PATH (or only resolves to codex-sync) — skipping GPT panelist (graceful degrade)\n' >&2
    exit 1
fi
if ! command -v "$_codex_cmd" >/dev/null 2>&1 && [ ! -x "$_codex_cmd" ]; then
    printf 'run-panelist-gpt: SDD_PANELIST_CODEX_CMD=%s is not executable — skipping GPT panelist (graceful degrade)\n' \
        "$_codex_cmd" >&2
    exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
    printf 'run-panelist-gpt: python3 is required to supervise the panelist process group\n' >&2
    exit 2
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

# Run the vendor CLI in a dedicated process group. Python's os.setsid() is the
# portable equivalent of the setsid utility, which is absent on macOS. A
# completion marker closes the polling race: it is written before the process-
# group leader exits, so a child finishing at the deadline keeps its real code.
#
# Stdin hazard (invocation-fix hardening): POSIX shells default an
# asynchronous command's stdin to /dev/null unless THAT command carries its
# own explicit redirect -- a redirect on the enclosing function call (as
# used at every call site below, `_sdd_run_bounded ... < "$_combined"`)
# does not count. Without the `<&0` below, the vendor CLI silently received
# an empty stdin on every invocation regardless of how the prompt/bundle
# was built, independent of any argv/flag correctness.
_sdd_run_bounded() {
    _bw_limit="$1"
    shift
    _bw_status="${_scratch}/bounded-status"
    rm -f "$_bw_status"

    python3 -c '
import os
import subprocess
import sys

status_path = sys.argv[1]
os.setsid()
return_code = subprocess.call(sys.argv[2:])
tmp_path = status_path + ".tmp"
with open(tmp_path, "w", encoding="ascii") as status_file:
    status_file.write(str(return_code))
os.rename(tmp_path, status_path)
sys.exit(return_code if 0 <= return_code <= 255 else 1)
' "$_bw_status" "$@" <&0 &
    _bw_pid=$!
    # date +%s truncates the current second. Include the open fractional second
    # so a whole-second budget can never expire before its requested duration.
    _bw_deadline=$(( $(date +%s) + _bw_limit + 1 ))

    while kill -0 "$_bw_pid" 2>/dev/null; do
        if [ -s "$_bw_status" ]; then
            wait "$_bw_pid"
            return $?
        fi
        if [ "$(date +%s)" -ge "$_bw_deadline" ]; then
            # Completion and expiry are not atomic, and the integer-second
            # deadline can fire with sub-second slack depending on the
            # start phase. Wait a full second so any child that finished
            # within limit+1 real seconds has published its status before
            # the expiry is treated as authoritative (Edge Case 6).
            sleep 1
            if [ -s "$_bw_status" ]; then
                wait "$_bw_pid"
                return $?
            fi
            if ! kill -0 "$_bw_pid" 2>/dev/null; then
                wait "$_bw_pid"
                return $?
            fi

            # Negative PID targets the entire process group, including any
            # descendants the vendor CLI spawned.
            kill -TERM "-$_bw_pid" 2>/dev/null || true
            _bw_grace_deadline=$(( $(date +%s) + 2 ))
            while kill -0 "-$_bw_pid" 2>/dev/null && \
                    [ "$(date +%s)" -lt "$_bw_grace_deadline" ]; do
                sleep 1
            done
            if kill -0 "-$_bw_pid" 2>/dev/null; then
                kill -KILL "-$_bw_pid" 2>/dev/null || true
            fi
            wait "$_bw_pid" 2>/dev/null || true
            return 124
        fi
        sleep 1
    done

    wait "$_bw_pid"
}

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
# Pass the prompt and input bundle to codex via stdin concatenation, through
# the `exec` subcommand (codex-cli 0.147.0's non-interactive entry point --
# a bare `codex --model ... <prompt>` is rejected by this CLI version and/or
# silently forwarded to the interactive TUI). `--sandbox read-only
# --skip-git-repo-check -C "$_scratch"` roots the run at the isolated
# scratch dir with no write access, matching the panelist's READ-ONLY role
# (prompt rules below) at the tool-execution layer, not just by instruction.
# Trailing `-` makes the "read the prompt from stdin" contract explicit.

_combined="${_scratch}/combined.txt"
{
    cat "$_prompt_file"
    printf '\n\n## Sanitized Input Bundle\n\n'
    cat "$input_path"
} > "$_combined"

_codex_argv_log="exec --model $model"
if [ -n "$effort" ]; then
    _codex_argv_log="$_codex_argv_log -c model_reasoning_effort=$effort"
fi
_codex_argv_log="$_codex_argv_log --sandbox read-only --skip-git-repo-check -C $_scratch -"
printf 'run-panelist-gpt: invoking %s %s (task=%s feature=%s)\n' \
    "$_codex_cmd" "$_codex_argv_log" "$task_id" "$feature" >&2

_raw_output="${_scratch}/raw-output.txt"
if [ -n "$effort" ]; then
    # --effort supplied: forwarded as a codex config override (AC-035).
    _sdd_run_bounded "$_panelist_timeout" \
        "$_codex_cmd" exec --model "$model" -c "model_reasoning_effort=$effort" \
        --sandbox read-only --skip-git-repo-check -C "$_scratch" - \
        < "$_combined" > "$_raw_output" 2>&1
    _rc=$?
else
    # --effort omitted: no reasoning-effort override is applied.
    _sdd_run_bounded "$_panelist_timeout" \
        "$_codex_cmd" exec --model "$model" \
        --sandbox read-only --skip-git-repo-check -C "$_scratch" - \
        < "$_combined" > "$_raw_output" 2>&1
    _rc=$?
fi
if [ "$_rc" -ne 0 ]; then
    if [ "$_rc" -eq 124 ]; then
        printf 'run-panelist-gpt: codex CLI exceeded SDD_PANELIST_TIMEOUT=%ss; terminated\n' \
            "$_panelist_timeout" >&2
    else
        printf 'run-panelist-gpt: codex CLI exited %d\n' "$_rc" >&2
    fi
    cat "$_raw_output" >&2
    exit 1
fi

# ── Extract and validate JSON from output ────────────────────────────────────
# The output may contain prose + JSON; extract the first JSON object.

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
