#!/bin/sh
# Collection layer: prepare sanitized panelist input bundle with consent gate.
# Usage:
#   prepare-panelist-input.sh --task T-NNN --feature <f> --input <path|dir>
#                             [--tasks-file specs/<f>/tasks.md]
#                             [--out <path>]
#                             [--spec-root <dir>]
#                             [--project-root <dir>]
#                             [--effort <low|medium|high|xhigh>]
#
# Security (design.md §6):
#   • Fail-closed consent gate: exits non-zero without writing output unless
#     tasks.md contains "Cross-Model: enabled" for the task, OR a valid
#     SDD_SUDO token is present (see sudo-mode-policy.md).
#   • Sanitization: strips .env values, API keys/tokens, absolute paths, and
#     private/RFC-1918 URLs before writing the bundle.
#   • input_digest: sha256 of the sanitized bundle, printed to stdout.
#   • Key isolation: SDD_EVIDENCE_KEY / sudo key are never included in output.
#
# Exit codes: 0=success  1=consent denied / input error  2=tool error (bad args)
#
# --effort (epic-159-pillar-c T-006, REQ-006/AC-036): optional pass-through.
# This script prepares ONE shared sanitized bundle consumed by every
# panelist vendor (Claude/GPT/Gemini) — it never invokes a vendor CLI
# itself — so a selector-derived effort value cannot be "forwarded" via a
# direct function call here. Instead, when --effort is supplied, its value
# is threaded through by being ECHOED on a second stdout line
# ("effort=<e>", after the existing digest line), so the caller (the
# cross-model-verify skill / T-006's Codex-host startup wiring) can read it
# back out and pass it verbatim as `run-panelist-gpt --effort <e>` in its
# own next step. Omitted entirely preserves today's exact single-line
# stdout output (Breaking API: no).
#
# Simplification note (HMAC): Full HMAC-SHA256 verification of SDD_SUDO requires
# the key from ~/.sdd/sudo-key or SDD_SUDO_KEY env var. We perform complete
# HMAC verification when python3 is available and the key is resolvable. When
# SDD_SUDO_SKIP_SIG=1 is set (test scaffolding only), signature check is skipped.
# The policy doc (sudo-mode-policy.md §Validation) documents this residual risk.

task_id=""
feature=""
input_path=""
tasks_file=""
out_path=""
spec_root="specs"
project_root=""
effort=""

while [ $# -gt 0 ]; do
    case "$1" in
        --task)         task_id="$2";       shift 2 ;;
        --feature)      feature="$2";       shift 2 ;;
        --input)        input_path="$2";    shift 2 ;;
        --tasks-file)   tasks_file="$2";    shift 2 ;;
        --out)          out_path="$2";      shift 2 ;;
        --spec-root)    spec_root="$2";     shift 2 ;;
        --project-root) project_root="$2";  shift 2 ;;
        --effort)       effort="$2";        shift 2 ;;
        *) printf 'prepare-panelist-input: unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done

# ── Validate required arguments ──────────────────────────────────────────────

if [ -z "$task_id" ]; then
    printf 'prepare-panelist-input: --task is required\n' >&2
    exit 2
fi
if [ -z "$feature" ]; then
    printf 'prepare-panelist-input: --feature is required\n' >&2
    exit 2
fi
if [ -z "$input_path" ]; then
    printf 'prepare-panelist-input: --input is required\n' >&2
    exit 2
fi

# Resolve project root (default: directory containing this script's repo root)
if [ -z "$project_root" ]; then
    # Walk up from CWD to find the repo root (contains AGENTS.md or .git)
    _dir="$(pwd)"
    while [ "$_dir" != "/" ]; do
        if [ -f "$_dir/AGENTS.md" ] || [ -d "$_dir/.git" ]; then
            project_root="$_dir"
            break
        fi
        _dir="$(dirname "$_dir")"
    done
    if [ -z "$project_root" ]; then
        project_root="$(pwd)"
    fi
fi

# Default tasks file
if [ -z "$tasks_file" ]; then
    tasks_file="${spec_root}/${feature}/tasks.md"
fi

# Default output path
if [ -z "$out_path" ]; then
    out_path="${spec_root}/${feature}/verification/${task_id}.panelist-input.txt"
fi

# ── Consent gate (fail-closed) ───────────────────────────────────────────────
# Condition (a): tasks.md has "Cross-Model: enabled" line in the task section
# Condition (b): valid SDD_SUDO token exists

consent_kind=""

# Check (a): tasks.md flag
if [ -f "$tasks_file" ]; then
    # Find the task section and check for Cross-Model: enabled within it
    # We scan from the task heading until the next ## heading or EOF
    in_section=0
    while IFS= read -r line; do
        # Strip CR for Windows line endings
        line="${line%$'\r'}"
        case "$line" in
            "## ${task_id} "* | "## ${task_id}")
                in_section=1 ;;
            "## "*)
                if [ "$in_section" = "1" ]; then
                    break
                fi ;;
            "Cross-Model: enabled")
                if [ "$in_section" = "1" ]; then
                    consent_kind="human-flag"
                    break
                fi ;;
        esac
    done < "$tasks_file"
fi

# Check (b): SDD_SUDO token
if [ -z "$consent_kind" ]; then
    sudo_file="${project_root}/SDD_SUDO"
    if [ -f "$sudo_file" ] && [ ! -L "$sudo_file" ]; then
        # Parse required fields
        _issuer=""       ; _nonce=""       ; _repo=""
        _issued_epoch="" ; _expires_epoch="" ; _sig=""

        while IFS= read -r _line; do
            _line="${_line%$'\r'}"
            case "$_line" in
                "issuer: "*)        _issuer="${_line#issuer: }" ;;
                "nonce: "*)         _nonce="${_line#nonce: }" ;;
                "repo: "*)          _repo="${_line#repo: }" ;;
                "issued-epoch: "*)  _issued_epoch="${_line#issued-epoch: }" ;;
                "expires-epoch: "*) _expires_epoch="${_line#expires-epoch: }" ;;
                "sig: "*)           _sig="${_line#sig: }" ;;
            esac
        done < "$sudo_file"

        # All required fields present?
        if [ -n "$_issuer" ] && [ -n "$_nonce" ] && [ -n "$_repo" ] && \
           [ -n "$_issued_epoch" ] && [ -n "$_expires_epoch" ] && [ -n "$_sig" ]; then

            # Nonce: must be >= 32 hex chars
            _nonce_ok=0
            if printf '%s' "$_nonce" | grep -qE '^[0-9a-fA-F]{32,}$'; then
                _nonce_ok=1
            fi

            # Time window: issued_epoch <= now < expires_epoch
            _now="$(date +%s)"
            _time_ok=0
            _max_ttl=86400  # 24 hours
            if [ "$_nonce_ok" = "1" ] && \
               [ "$_issued_epoch" -le "$_now" ] 2>/dev/null && \
               [ "$_now" -lt "$_expires_epoch" ] 2>/dev/null && \
               [ "$(( _expires_epoch - _issued_epoch ))" -le "$_max_ttl" ] 2>/dev/null; then
                _time_ok=1
            fi

            # Repo binding: repo field must equal canonical path of dir containing SDD_SUDO.
            # We resolve BOTH the expected path and the repo field to handle macOS symlinks
            # (/var/folders vs /private/var/folders) and other platform quirks.
            _repo_ok=0
            _expected_repo="$(cd "$(dirname "$sudo_file")" && pwd -P 2>/dev/null || dirname "$sudo_file")"
            # Also resolve the repo field itself (in case it used a non-canonical path)
            _repo_resolved=""
            if [ -d "$_repo" ]; then
                _repo_resolved="$(cd "$_repo" && pwd -P 2>/dev/null || printf '%s' "$_repo")"
            else
                _repo_resolved="$_repo"
            fi
            if [ "$_repo_resolved" = "$_expected_repo" ]; then
                _repo_ok=1
            fi

            # HMAC signature verification
            _sig_ok=0
            if [ "${SDD_SUDO_SKIP_SIG:-0}" = "1" ]; then
                # Test scaffolding only: skip HMAC check
                _sig_ok=1
            elif command -v python3 >/dev/null 2>&1; then
                # Attempt full HMAC verification via python3
                _key=""
                if [ -n "${SDD_SUDO_KEY:-}" ]; then
                    _key="$SDD_SUDO_KEY"
                elif [ -n "${SDD_SUDO_KEY_FILE:-}" ] && [ -f "$SDD_SUDO_KEY_FILE" ]; then
                    _key="$(cat "$SDD_SUDO_KEY_FILE" | tr -d '\n\r')"
                else
                    _key_file="${HOME:-$USERPROFILE}/.sdd/sudo-key"
                    if [ -f "$_key_file" ]; then
                        _key="$(cat "$_key_file" | tr -d '\n\r')"
                    fi
                fi

                if [ -n "$_key" ]; then
                    # Issue #108: token fields are attacker-controlled. Pass them
                    # as environment variables into a QUOTED heredoc so the shell
                    # never interpolates them into Python source. An unquoted
                    # heredoc (or literal interpolation) would let a field like
                    # issuer=`");import os;...#` execute arbitrary code before the
                    # HMAC comparison. os.environ carries the values as inert data.
                    _hmac_result=$(
                        SDD_HMAC_KEY="$_key" \
                        SDD_HMAC_ISSUER="$_issuer" \
                        SDD_HMAC_NONCE="$_nonce" \
                        SDD_HMAC_REPO="$_repo" \
                        SDD_HMAC_ISSUED="$_issued_epoch" \
                        SDD_HMAC_EXPIRES="$_expires_epoch" \
                        SDD_HMAC_SIG="$_sig" \
                        python3 - <<'PYEOF'
import hmac, hashlib, os
key = os.environ["SDD_HMAC_KEY"].encode()
msg = "\n".join([
    os.environ["SDD_HMAC_ISSUER"],
    os.environ["SDD_HMAC_NONCE"],
    os.environ["SDD_HMAC_REPO"],
    os.environ["SDD_HMAC_ISSUED"],
    os.environ["SDD_HMAC_EXPIRES"],
])
sig = os.environ["SDD_HMAC_SIG"].lower()
computed = hmac.new(key, msg.encode(), hashlib.sha256).hexdigest()
print("ok" if hmac.compare_digest(computed, sig) else "fail")
PYEOF
)
                    if [ "$_hmac_result" = "ok" ]; then
                        _sig_ok=1
                    fi
                fi
                # If no key is resolvable, token is inactive (fail-closed)
            fi
            # No python3 and no SKIP_SIG: token inactive, _sig_ok remains 0

            if [ "$_nonce_ok" = "1" ] && [ "$_time_ok" = "1" ] && \
               [ "$_repo_ok" = "1" ] && [ "$_sig_ok" = "1" ]; then
                consent_kind="sudo"
            fi
        fi
    fi
fi

if [ -z "$consent_kind" ]; then
    printf 'prepare-panelist-input: consent denied for %s — no Cross-Model: enabled flag in %s and no valid SDD_SUDO token\n' \
        "$task_id" "$tasks_file" >&2
    exit 1
fi

# ── Collect input content ────────────────────────────────────────────────────
# find-based recursive traversal (replaces the single-level `for f in
# "$input_path"/*` glob) so subdirectories of --input are visited too
# (REQ-003/AC-013); sorted for determinism.

if [ ! -e "$input_path" ]; then
    printf 'prepare-panelist-input: input not found: %s\n' "$input_path" >&2
    exit 1
fi

if [ -d "$input_path" ]; then
    raw_content=""
    while IFS= read -r f; do
        raw_content="${raw_content}$(cat "$f")
"
    done < <(find "$input_path" -type f | sort)
else
    raw_content="$(cat "$input_path")"
fi

# ── Declared-outputs completeness check (REQ-003/AC-014..017/AC-032) ────────
# Security Boundary B1 (security-spec.md): verifies every path the
# implementation report's own "## Outputs" table declares is present in the
# bundle's --input root with a matching SHA-256, BEFORE sanitization/digest
# computation ever runs — a completeness gap means no digest line can ever
# print (a structural property: the sanitize/write/print code below is
# simply never reached on a gap, not a conditional guard around it).
#
# Reuses the "## Outputs" heading + "| `path` | `hash` |" row shape
# validate-review-context-set.sh:63-74's evaluator_output_is_declared already
# establishes, applied in the OPPOSITE direction: instead of checking one
# caller-supplied path against the table, this iterates every row and
# containment-checks each declared path against the bundle's OWN --input
# root FIRST — reusing that same site's path_is_authorized containment
# discipline — a path that would resolve outside is a gap, NEVER read
# (never opened, never hashed), before existence/hash is verified for paths
# that pass containment.
#
# Convention, not a new flag (Breaking API: no — CLI flags are unchanged):
# the implementation report path is derived from --task/--feature/
# --project-root as reports/implementation/<feature>/<task_id>.md, the same
# convention validate-review-context-set.sh:267-282 already uses to locate
# an sdd-evaluator's implementation report. If no report exists at that
# conventional path, there is no declared-outputs table to check against —
# the completeness check is a no-op (preserves BL-007/BL-008/BL-009 for
# every caller that predates this convention, e.g. this script's own
# existing test fixtures).

_ppi_sha256_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$1" | awk '{print $1}'
    else
        printf 'prepare-panelist-input: SHA-256 tool unavailable\n' >&2
        exit 2
    fi
}

# Reject any declared path that is not a plain, relative, forward-slash,
# no-`..`-segment path — containment check BEFORE any read is attempted.
_ppi_is_canonical_declared_path() {
    case "$1" in
        '') return 1 ;;
        /*) return 1 ;;
        [A-Za-z]:*) return 1 ;;
        *'\'*) return 1 ;;
        ..|../*|*/..|*/../*) return 1 ;;
        .|./*|*/.|*/./*) return 1 ;;
        *) return 0 ;;
    esac
}

check_declared_outputs_completeness() {
    _impl_report="${project_root}/reports/implementation/${feature}/${task_id}.md"
    [ -f "$_impl_report" ] || return 0

    _ppi_tab="$(printf '\t')"
    _gaps=""
    while IFS="$_ppi_tab" read -r _row_path _row_hash; do
        [ -n "$_row_path" ] || continue

        if ! _ppi_is_canonical_declared_path "$_row_path"; then
            _gaps="${_gaps}prepare-panelist-input: declared output resolves outside input root: ${_row_path}
"
            continue
        fi

        # Component-walk containment: no symbolic link anywhere between the
        # bundle root and the candidate may be followed (mirrors
        # validate-review-context-set.sh's own symlink-component-walk).
        _current="${input_path%/}"
        _outside_root=0
        _old_ifs="$IFS"
        IFS='/'
        set -- $_row_path
        IFS="$_old_ifs"
        for _component in "$@"; do
            _current="${_current}/${_component}"
            if [ -L "$_current" ]; then
                _outside_root=1
            fi
        done

        if [ "$_outside_root" = "1" ]; then
            _gaps="${_gaps}prepare-panelist-input: declared output resolves outside input root: ${_row_path}
"
            continue
        fi

        _candidate="${input_path%/}/${_row_path}"
        if [ ! -L "$_candidate" ] && [ -f "$_candidate" ]; then
            _actual_hash="$(_ppi_sha256_file "$_candidate")"
            if [ "$_actual_hash" != "$_row_hash" ]; then
                _gaps="${_gaps}prepare-panelist-input: declared output hash mismatch: ${_row_path}
"
            fi
        else
            _gaps="${_gaps}prepare-panelist-input: declared output missing from bundle: ${_row_path}
"
        fi
    done < <(awk '
        /^## Outputs[[:space:]]*$/ { in_outputs = 1; next }
        in_outputs && /^##[[:space:]]/ { exit }
        in_outputs {
            line = $0
            gsub(/\r$/, "", line)
            n = split(line, parts, "`")
            if (n == 5 && parts[1] ~ /^\| *$/ && parts[3] ~ /^ *\| *$/ && parts[5] ~ /^ *\|[[:space:]]*$/) {
                print parts[2] "\t" parts[4]
            }
        }
    ' "$_impl_report")

    if [ -n "$_gaps" ]; then
        printf '%s' "$_gaps" >&2
        exit 1
    fi
}

check_declared_outputs_completeness

# ── Sanitize via python3 ─────────────────────────────────────────────────────
# Uses python3 for reliable regex; required for sha256 as well.
# Content is passed via a temp file to avoid shell interpolation of $ in Python heredocs.

if ! command -v python3 >/dev/null 2>&1; then
    printf 'prepare-panelist-input: python3 is required but not found\n' >&2
    exit 2
fi

_raw_tmp="$(mktemp)"
_py_tmp="${_raw_tmp}.py"
trap 'rm -f "$_raw_tmp" "$_py_tmp"' EXIT

printf '%s' "$raw_content" > "$_raw_tmp"

cat > "$_py_tmp" << 'PYEOF'
import re, hashlib, sys

raw_file = sys.argv[1]
with open(raw_file, encoding="utf-8", errors="replace") as f:
    raw = f.read()

# ── Secret patterns (reusing check-ph patterns + common key detection) ──
#
# Pattern set:
#  1. KEY=VALUE lines: lines containing credential env-var assignments
#  2. AWS Access Key IDs (AKIA...)
#  3. GitHub/GitLab PATs (ghp_, ghs_, gho_, glpat-)
#  4. sk-prefixed tokens (OpenAI etc.)
#  5. Long random secrets on KEY= lines (catch-all >= 32 chars)
#  6. Absolute Unix paths (/home, /Users, /root, /var, /etc, /usr, /opt, /tmp, /private)
#  7. Windows absolute paths (C:\...)
#  8. Private/RFC-1918 IP URLs
#  9. Internal/corp hostnames in URLs

REDACTED      = "[REDACTED]"
PATH_REDACTED = "[PATH_REDACTED]"
URL_REDACTED  = "[URL_REDACTED]"

# 1. Credential assignment lines
cred_key_pat = re.compile(
    r'(?im)^[^\n=]*(?:api[_\-]?key|secret[_\-]?(?:access[_\-]?)?key|access[_\-]?key(?:[_\-]?id)?'
    r'|auth[_\-]?token|bearer|password|passwd|credential|private[_\-]?(?:key|token)|token)[^\n=]*=[^\n]+',
)
text = cred_key_pat.sub(lambda m: m.group(0).split('=')[0] + '=' + REDACTED, raw)

# 2. AWS Access Key IDs
text = re.sub(r'AKIA[0-9A-Z]{16}', REDACTED, text)

# 3. GitHub/GitLab PATs
text = re.sub(r'(?:ghp_|ghs_|gho_|glpat-)[A-Za-z0-9_\-]{20,}', REDACTED, text)

# 4. sk- prefixed tokens
text = re.sub(r'sk-[A-Za-z0-9_\-]{20,}', REDACTED, text)

# 5. Long random secrets catch-all
text = re.sub(
    r'(?im)((?:key|token|secret|password|passwd|credential)[^\n=]*=\s*)[A-Za-z0-9+/=]{32,}',
    lambda m: m.group(1) + REDACTED, text
)

# 6. Absolute Unix paths
text = re.sub(r'/(?:home|root|Users|var|etc|usr|opt|tmp|private)/[^\s\'")\]]*', PATH_REDACTED, text)

# 7. Windows absolute paths
text = re.sub(r'[A-Za-z]:\\[^\s\'")\]]*', PATH_REDACTED, text)

# 8. Private/RFC-1918 IP URLs
text = re.sub(
    r'https?://(?:192\.168\.\d{1,3}|10\.\d{1,3}\.\d{1,3}|172\.(?:1[6-9]|2[0-9]|3[01])\.\d{1,3})'
    r'(?::\d+)?[^\s\'")\]]*',
    URL_REDACTED, text
)

# 9. Internal/corp hostnames in URLs
text = re.sub(
    r'https?://[^\s\'")\]]*(?:internal|corp|intranet|private)[^\s\'")\]]*',
    URL_REDACTED, text
)

digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
# Output: digest on first line, then sanitized content
sys.stdout.write(digest + "\n")
sys.stdout.write(text)
PYEOF

sanitized_and_digest=$(python3 "$_py_tmp" "$_raw_tmp")
_py_rc=$?
rm -f "$_raw_tmp" "$_py_tmp"

if [ "$_py_rc" -ne 0 ]; then
    printf 'prepare-panelist-input: sanitization failed\n' >&2
    exit 2
fi

# Split: first line is digest, remainder is sanitized content
input_digest=$(printf '%s\n' "$sanitized_and_digest" | head -1)
sanitized_content=$(printf '%s\n' "$sanitized_and_digest" | tail -n +2)

# ── Write output bundle ──────────────────────────────────────────────────────

out_dir="$(dirname "$out_path")"
mkdir -p "$out_dir" || {
    printf 'prepare-panelist-input: cannot create output directory: %s\n' "$out_dir" >&2
    exit 2
}

# Write bundle header + sanitized content
{
    printf '# Panelist Input Bundle\n'
    printf '# task_id: %s\n' "$task_id"
    printf '# feature: %s\n' "$feature"
    printf '# input_digest: %s\n' "$input_digest"
    printf '# consent: %s\n' "$consent_kind"
    printf '# WARNING: This file is sanitized for external LLM review.\n'
    printf '#          Do not include secrets, absolute paths, or private URLs.\n'
    printf '\n'
    printf '%s\n' "$sanitized_content"
} > "$out_path"

# ── Emit digest (and threaded effort, if supplied) to stdout ────────────────
# AC-036: --effort is threaded through verbatim on a second stdout line, so
# the caller can lift it into `run-panelist-gpt --effort <e>` in its own
# next step. Omitted entirely preserves today's exact single-line output.

printf '%s\n' "$input_digest"
if [ -n "$effort" ]; then
    printf 'effort=%s\n' "$effort"
fi
exit 0
