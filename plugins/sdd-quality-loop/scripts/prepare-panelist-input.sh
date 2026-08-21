#!/bin/sh
# Collection layer: prepare sanitized panelist input bundle with consent gate.
# Usage:
#   prepare-panelist-input.sh --task T-NNN --feature <f> --input <path|dir>
#                             [--tasks-file specs/<f>/tasks.md]
#                             [--out <path>]
#                             [--spec-root <dir>]
#                             [--project-root <dir>]
#                             [--effort <low|medium|high|xhigh>]
#                             [--max-bytes <n>]
#
# --max-bytes (optional, no default — unset means unlimited): a fail-closed
# size guard on the FINAL sanitized bundle. A vendor caller with a known
# input cap (e.g. codex exec's 1,048,576-character limit) passes its own
# threshold here. If the sanitized bundle would exceed it, this script
# prints a per-section byte breakdown to stderr, writes NO output file, and
# exits 1 — it never truncates. A panelist who cannot tell their input was
# cut would report confident conclusions about material they never saw,
# which is worse than a failed run that says so plainly.
#
# Per-file elision (only when --max-bytes is set): a single file under the
# reviewed task's own verification/<task_id>/ evidence directory that
# exceeds one quarter of --max-bytes is included as its first/last 40
# lines plus a marker stating how many bytes were elided from the middle
# and from which path — never silently. Spec documents, the task's own
# contract/evidence.json, the implementation report, and every path the
# report's "## Outputs" table declares are never elided. If the bundle is
# still over --max-bytes after elision, this script still fails closed
# exactly as above.
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
max_bytes=""

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
        --max-bytes)    max_bytes="$2";     shift 2 ;;
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
# Task-scoped composition (replaces the earlier whole-directory `find
# "$input_path"` walk of --input). The old walk read every file under
# --input, which in real invocations was `specs/<feature>/` — every OTHER
# task's evidence logs, quality-gate transcripts, and mutation output, all
# concatenated into one bundle. Two panelists on epic-195 independently
# reported this: bundles that were mostly unrelated-task noise while
# containing "zero bytes of any of the five files [the task] actually
# changed" — the Outputs table names those files, but the old walk never
# read outside specs/. A directory walk is structurally the wrong shape for
# "what does a reviewer of ONE task need"; this composes that set instead of
# discovering it by traversal:
#   1. the feature's spec documents (fixed filenames, each only if present)
#   2. the reviewed task's own verification contract + evidence.json
#   3. the reviewed task's own verification/<task_id>/ evidence directory
#      (recursively, same panel-artifact exclusions the old walk applied)
#   4. the reviewed task's own implementation report
#   5. the CURRENT content of every path the report's "## Outputs" table
#      declares — appended below, after check_declared_outputs_completeness
#      resolves each row (see declared_content and _ppi_capture_declared_
#      output_content), reusing that single resolution rather than re-
#      reading paths a second, differently-behaved way.
# --input is unchanged for a literal FILE argument (still read verbatim —
# this is the shape PP-001..013's secret-sanitization fixtures use, and is
# orthogonal to feature/task composition). --input is retained as the
# completeness check's first-try resolution root (unchanged; see
# check_declared_outputs_completeness) even though real callers now get
# task-scoped content regardless of what --input points to.

if [ ! -e "$input_path" ]; then
    printf 'prepare-panelist-input: input not found: %s\n' "$input_path" >&2
    exit 1
fi

# Tracks project-root-relative paths already pulled in by steps 1-4 above, so
# step 5 (declared outputs) does not duplicate a file already present (e.g.
# tasks.md and CHANGELOG.md are commonly both a spec document/committed file
# AND a declared output; verification/<task_id>/*.log is commonly both the
# task's own evidence dir AND separately declared). Only meaningful for rows
# that resolve project-root-relative; rows resolved under --input have no
# comparable identity here and are never deduplicated against this set.
_ppi_seen_relpaths=""
_ppi_mark_seen() {
    _ppi_seen_relpaths="${_ppi_seen_relpaths}
$1"
}
_ppi_is_seen() {
    printf '%s\n' "$_ppi_seen_relpaths" | grep -qxF -- "$1"
}

# Per-file elision (Part 2, design.md §6 follow-up): a single oversized
# evidence log (e.g. a whole-repo run-all capture), or several moderate
# ones together, can push a bundle over --max-bytes even though every byte
# is legitimate evidence, not noise. Truncating silently would let a
# reviewer draw confident conclusions about material they never saw — the
# same reasoning that made --max-bytes fail closed instead of truncating
# the whole bundle (see the file header). The fix here is the same shape
# at file granularity: keep a file's own first/last lines, and replace the
# middle with a marker stating, in plain words, how many bytes were
# removed and from which path.
#
# Budget-driven, not threshold-driven. An earlier version of this elided
# any single file over one quarter of --max-bytes, which got two things
# wrong in practice: a bundle with one file just over that fraction and
# another just under it treated two near-identical artifacts oppositely
# for no benefit when the bundle was refused anyway, and a bundle whose
# overage was spread across many moderate files (none individually over
# the fraction) got no elision help at all. This version composes the
# bundle WHOLE first and measures it. If it already fits --max-bytes,
# nothing is elided — every such bundle is byte-for-byte what it would be
# with no elision logic in this script at all. Only when the whole bundle
# is over cap does it elide, one file at a time, LARGEST FIRST, from the
# elidable set only, recomputing the actual sanitized bundle size after
# each elision (never estimated — eliding one file changes the total, so
# each step re-measures) until it fits or the elidable set is exhausted.
# Exhausted-and-still-over fails closed, unchanged in shape from before
# Part 2. This is also the honest answer to the degenerate case where even
# every elidable file's own head+tail+marker floor, summed with the
# content that is never elided, still exceeds --max-bytes: no amount of
# elision can fix that, so refusing to write is correct — identical in
# spirit to failing closed when there were no elidable candidates at all.
#
# Scope: elision applies ONLY to files pulled in by step 3 below (the
# reviewed task's own verification/<task_id>/ evidence directory). Spec
# documents (step 1), the task's own contract/evidence.json (step 2), the
# implementation report (step 4), and every declared-outputs row (step 5
# — this is precisely "a source file named in the Outputs table") are
# never elided: those are the bundle's actual claims and their supporting
# source, not raw log noise, and truncating any of them would gut the
# bundle's whole purpose. Head/tail size stays a fixed line count (not
# proportional to the cap) — this exists purely for reviewer legibility
# (show a log's setup and its final summary), never as a byte dial; the
# byte-target job stays entirely with --max-bytes and the budget loop.
_ppi_elide_lines=40
_ppi_tab="$(printf '\t')"

# One file's content, elided to its first/last $_ppi_elide_lines lines
# plus a marker. Callers only invoke this for a file the budget loop below
# has already decided to elide — it is not itself threshold-gated.
_ppi_elide_content() {
    _pec_file="$1"
    _pec_label="$2"
    _pec_total=$(wc -c < "$_pec_file" | tr -d ' ')
    _pec_head=$(head -n "$_ppi_elide_lines" "$_pec_file")
    _pec_tail=$(tail -n "$_ppi_elide_lines" "$_pec_file")
    _pec_head_bytes=$(printf '%s\n' "$_pec_head" | wc -c | tr -d ' ')
    _pec_tail_bytes=$(printf '%s\n' "$_pec_tail" | wc -c | tr -d ' ')
    _pec_elided=$((_pec_total - _pec_head_bytes - _pec_tail_bytes))
    [ "$_pec_elided" -lt 0 ] && _pec_elided=0
    printf '%s\n' "$_pec_head"
    printf '[... %s bytes elided from the middle of %s (original size %s bytes; showing first/last %s lines) ...]\n' \
        "$_pec_elided" "$_pec_label" "$_pec_total" "$_ppi_elide_lines"
    printf '%s\n' "$_pec_tail"
}

# Append one file's content to $raw_content with a path header, so a
# reviewer (and these tests) can tell which bytes came from which file —
# the old walk concatenated files with no such marker at all. Third
# argument "1" reads the file through _ppi_elide_content instead of cat;
# only the step-3 rebuild function below ever passes it.
_ppi_append_content() {
    if [ "${3:-0}" = "1" ]; then
        raw_content="${raw_content}# ---- ${2} ----
$(_ppi_elide_content "$1" "$2")
"
    else
        raw_content="${raw_content}# ---- ${2} ----
$(cat "$1")
"
    fi
}

raw_content=""

if [ -d "$input_path" ]; then
    _ppi_spec_dir="${project_root}/${spec_root}/${feature}"

    # 1. Spec documents (fixed order; only those that exist).
    for _ppi_doc in requirements.md design.md acceptance-tests.md tasks.md \
        traceability.md investigation.md \
        ux-spec.md frontend-spec.md infra-spec.md security-spec.md; do
        _ppi_doc_path="${_ppi_spec_dir}/${_ppi_doc}"
        if [ -f "$_ppi_doc_path" ] && [ ! -L "$_ppi_doc_path" ]; then
            _ppi_doc_rel="${spec_root}/${feature}/${_ppi_doc}"
            _ppi_append_content "$_ppi_doc_path" "$_ppi_doc_rel"
            _ppi_mark_seen "$_ppi_doc_rel"
        fi
    done

    # 2. The reviewed task's own verification contract + evidence.json.
    _ppi_verif_dir="${_ppi_spec_dir}/verification"
    for _ppi_vf in "${task_id}.contract.json" "${task_id}.evidence.json"; do
        _ppi_vf_path="${_ppi_verif_dir}/${_ppi_vf}"
        if [ -f "$_ppi_vf_path" ] && [ ! -L "$_ppi_vf_path" ]; then
            _ppi_vf_rel="${spec_root}/${feature}/verification/${_ppi_vf}"
            _ppi_append_content "$_ppi_vf_path" "$_ppi_vf_rel"
            _ppi_mark_seen "$_ppi_vf_rel"
        fi
    done

    # steps 1+2 are never elided — freeze them as the fixed prefix, then
    # reset raw_content so step 4 (also never elided) can be assembled
    # separately. Step 3 sits BETWEEN these two in the final bundle but is
    # composed by _ppi_build_step3_content below, possibly more than once,
    # so it is never accumulated directly into raw_content at all.
    _ppi_content_prefix="$raw_content"
    raw_content=""

    # 3. The reviewed task's own verification/<task_id>/ evidence
    # directory, recursively, sorted for determinism — same panel-artifact
    # exclusions the old whole-directory walk applied, now scoped to just
    # this task's own subdirectory instead of the whole feature. This pass
    # only INVENTORIES the elidable candidates (size, absolute path,
    # relative path, one per line in $_ppi_elidable_index) and marks each
    # file seen — seen-ness and dedup against step 5 do not depend on
    # whether a file ends up elided, only on whether it is present at all.
    # Actual content composition happens in _ppi_build_step3_content,
    # below, invoked by the budget loop after declared_content is ready.
    _ppi_task_verif_dir="${_ppi_verif_dir}/${task_id}"
    _ppi_elidable_index=""
    if [ -d "$_ppi_task_verif_dir" ] && [ ! -L "$_ppi_task_verif_dir" ]; then
        while IFS= read -r _ppi_tf; do
            _ppi_tf_rel="${spec_root}/${feature}/verification/${task_id}/${_ppi_tf#"${_ppi_task_verif_dir}"/}"
            _ppi_tf_bytes=$(wc -c < "$_ppi_tf" | tr -d ' ')
            _ppi_elidable_index="${_ppi_elidable_index}${_ppi_tf_bytes}${_ppi_tab}${_ppi_tf}${_ppi_tab}${_ppi_tf_rel}
"
            _ppi_mark_seen "$_ppi_tf_rel"
        done < <(find "$_ppi_task_verif_dir" -type f \
            ! -name '*.panelist-input.txt' \
            ! -name '*.verdict.json' \
            ! -name '*.cross-model.json' | sort)
    fi

    # 4. The reviewed task's own implementation report.
    _ppi_impl_report_path="${project_root}/reports/implementation/${feature}/${task_id}.md"
    if [ -f "$_ppi_impl_report_path" ] && [ ! -L "$_ppi_impl_report_path" ]; then
        _ppi_impl_report_rel="reports/implementation/${feature}/${task_id}.md"
        _ppi_append_content "$_ppi_impl_report_path" "$_ppi_impl_report_rel"
        _ppi_mark_seen "$_ppi_impl_report_rel"
    fi
    _ppi_content_suffix="$raw_content"
    raw_content=""
else
    _ppi_content_prefix="$(cat "$input_path")"
    _ppi_content_suffix=""
    _ppi_elidable_index=""
fi

# Rebuilds step 3's content from scratch given a set of relpaths (newline
# list, $1) that should be elided THIS attempt; every other elidable file
# is included whole. Sets global $_ppi_step3_content. Called once with an
# empty elide-set (the "as if elision never existed" bundle) and, only if
# that is over --max-bytes, again with one more relpath added each time —
# largest-candidate-first, decided by the budget loop below.
_ppi_build_step3_content() {
    _pbs_elide_set="$1"
    _ppi_step3_content=""
    [ -n "$_ppi_elidable_index" ] || return 0
    while IFS="$_ppi_tab" read -r _pbs_bytes _pbs_abspath _pbs_relpath; do
        [ -n "$_pbs_relpath" ] || continue
        if printf '%s\n' "$_pbs_elide_set" | grep -qxF -- "$_pbs_relpath"; then
            _ppi_step3_content="${_ppi_step3_content}# ---- ${_pbs_relpath} ----
$(_ppi_elide_content "$_pbs_abspath" "$_pbs_relpath")
"
        else
            _ppi_step3_content="${_ppi_step3_content}# ---- ${_pbs_relpath} ----
$(cat "$_pbs_abspath")
"
        fi
    done < <(printf '%s\n' "$_ppi_elidable_index")
}

# Accumulates the CURRENT content of every "## Outputs" row
# check_declared_outputs_completeness resolves (step 5 above); folded into
# every budget-loop attempt below. Populated in both --input modes: a
# literal-file --input can still name a task with its own implementation
# report and Outputs table. Computed once — it never depends on the
# elision decision (declared-outputs rows are never elided).declared_content=""

# ── Declared-outputs completeness check (REQ-003/AC-014..017/AC-032) ────────
# Security Boundary B1 (security-spec.md): verifies every path the
# implementation report's own "## Outputs" table declares is present, with
# a matching SHA-256, under the --input root OR the --project-root, BEFORE
# sanitization/digest computation ever runs — a completeness gap means no
# digest line can ever print (a structural property: the sanitize/write/
# print code below is simply never reached on a gap, not a conditional
# guard around it).
#
# Reuses the "## Outputs" heading + "| `path` | `hash` |" row shape
# validate-review-context-set.sh:63-74's evaluator_output_is_declared already
# establishes, applied in the OPPOSITE direction: instead of checking one
# caller-supplied path against the table, this iterates every row and
# containment-checks each declared path against a candidate root FIRST —
# reusing that same site's path_is_authorized containment discipline — a
# path that would resolve outside the root being tried is never read
# (never opened, never hashed), before existence/hash is verified for paths
# that pass containment. Real implementation reports declare rows relative
# to project_root (the same convention generate-evidence-bundle/
# check-evidence-bundle use); this script's own pre-existing fixtures
# declare rows relative to input_path. Both are tried — input_path first
# (preserving today's exact behavior for existing callers), project_root
# only on a miss — and whichever root actually resolves a row must
# independently pass containment under that root; a row never escapes the
# root it resolved under.
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
#
# Declaration-commit fallback (staleness of shared, living files): a row
# that is absent, or hash-mismatched, under project_root after both roots
# have been tried is not necessarily a lie — CHANGELOG.md and a feature's
# own tasks.md are declared as whole-file hashes but are shared files every
# sibling task edits after this report was written, so an accurate
# declaration goes stale the moment the next task commits. Rather than
# recording a commit in the report schema, the "declaration commit" (the
# commit that last modified the implementation report ITSELF) is derived
# with git and the row is re-checked against the tree as of that commit —
# same pattern, same rationale as check-workflow-state.sh's
# plugins_pin_commit/plugins_hash_at_pin for plugins/ reference docs. Only
# rows that resolved (or were validly attempted, never escaped) under
# project_root qualify: that root IS the repo root git commands run from,
# so row_path is already a repository-relative git-show argument with no
# translation. A row that only matched under --input has no such form and
# is never retried this way — see check_declared_outputs_completeness. Every
# acceptance via this path prints a distinct stderr notice (never silent);
# it must never become a way for a check to quietly stop verifying content
# it claims to verify.

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

# Same digest, read from stdin — used for hashing a `git show` blob without
# a temp file. If the upstream `git show` in the pipe failed (bad ref, path
# absent at that commit), stdin is empty and this simply hashes the empty
# string, which will not equal any real declared hash — the caller's plain
# string comparison is enough to fail closed; a POSIX sh pipeline cannot
# observe git's own exit code past the pipe, so this is deliberate, not an
# oversight (same acceptance already made by check-workflow-state.sh's
# plugins_hash_at_pin for the identical git-show-into-hash shape).
_ppi_sha256_stream() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 | awk '{print $1}'
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

# Resolve one declared-output row under a single candidate root, applying
# the same containment discipline (component-walk symlink guard) whichever
# root is being tried — a row must never escape the root it resolved under.
# POSIX sh has no return-by-value, so the result is communicated via the
# globals _ppi_row_state ("matched"|"escaped"|"absent") and, only when
# matched, _ppi_row_candidate (the resolved file path).
_ppi_resolve_row_under_root() {
    _rr_row_path="$1"
    _rr_root="$2"

    # Component-walk containment: no symbolic link anywhere between the
    # candidate root and the candidate may be followed (mirrors
    # validate-review-context-set.sh's own symlink-component-walk).
    _rr_current="${_rr_root%/}"
    _rr_escaped=0
    _rr_old_ifs="$IFS"
    IFS='/'
    set -- $_rr_row_path
    IFS="$_rr_old_ifs"
    for _rr_component in "$@"; do
        _rr_current="${_rr_current}/${_rr_component}"
        if [ -L "$_rr_current" ]; then
            _rr_escaped=1
        fi
    done

    if [ "$_rr_escaped" = "1" ]; then
        _ppi_row_state="escaped"
        return
    fi

    _rr_candidate="${_rr_root%/}/${_rr_row_path}"
    if [ ! -L "$_rr_candidate" ] && [ -f "$_rr_candidate" ]; then
        _ppi_row_state="matched"
        _ppi_row_candidate="$_rr_candidate"
    else
        _ppi_row_state="absent"
    fi
}

# Lazily derive & cache the "declaration commit" — the commit that last
# modified the implementation report itself. Computed at most once per
# invocation (a report with no git history, or no git binary at all, still
# only pays for one failed lookup, not one per row that needs it). Sets the
# globals _ppi_decl_commit_checked/_ppi_decl_commit and returns success only
# when a commit was found.
_ppi_decl_commit_checked=0
_ppi_decl_commit=""

_ppi_declaration_commit() {
    if [ "$_ppi_decl_commit_checked" = "1" ]; then
        [ -n "$_ppi_decl_commit" ]
        return
    fi
    _ppi_decl_commit_checked=1
    if command -v git >/dev/null 2>&1 && \
       git -C "$project_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        _ppi_decl_commit="$(git -C "$project_root" log -1 --format='%H' -- \
            "reports/implementation/${feature}/${task_id}.md" 2>/dev/null)"
    fi
    [ -n "$_ppi_decl_commit" ]
}

# Verify a declared-outputs row against the tree AS OF the declaration
# commit. Caller contract: row_path must already be known project-root-
# relative (only called for rows resolved, or validly attempted and merely
# absent — never escaped — under project_root; see
# check_declared_outputs_completeness). Prints a distinct stderr notice and
# returns success ONLY on a verified match — never silently, per the
# WFI-017 regression this guards against (a strict matcher that skipped
# rows with no diagnostic and five files went missing from a manifest). Any
# other outcome (no declaration commit, path absent at that commit, content
# still mismatched) returns failure so the caller keeps the unchanged gap
# message.
_ppi_verify_at_declaration_commit() {
    _vdc_row_path="$1"
    _vdc_row_hash="$2"

    _ppi_declaration_commit || return 1

    # git show's own status must be consulted, not just its bytes. Piping it
    # straight into the hasher discards the status, and a failed show emits an
    # empty stream — which hashes to the sha256 of nothing. A task that
    # legitimately declares an empty output would then be accepted here for a
    # path that does not exist at the declaration commit at all, while the
    # PowerShell twin (which checks its own exit code) rejects it. Writing the
    # bytes out first keeps the two twins agreeing for the same reason rather
    # than by coincidence.
    _vdc_blob="${TMPDIR:-/tmp}/ppi-decl-$$"
    if ! git -C "$project_root" show "${_ppi_decl_commit}:${_vdc_row_path}" \
            >"$_vdc_blob" 2>/dev/null; then
        rm -f "$_vdc_blob"
        return 1
    fi
    _vdc_hash="$(_ppi_sha256_stream <"$_vdc_blob")"
    rm -f "$_vdc_blob"
    [ "$_vdc_hash" = "$_vdc_row_hash" ] || return 1

    printf 'prepare-panelist-input: declared output verified at declaration commit %s: %s (drifted since)\n' \
        "$(printf '%s' "$_ppi_decl_commit" | cut -c1-7)" "$_vdc_row_path" >&2
    return 0
}

# Append the CURRENT content the completeness check just verified for one
# declared-outputs row into declared_content — reusing check_declared_
# outputs_completeness's own resolution (candidate worktree file, or the
# declaration-commit blob) rather than re-reading the row a second,
# differently-behaved way. Skips a row already pulled in by the spec-
# document/task-verification/implementation-report composition above (see
# _ppi_is_seen) — comparison is only meaningful for project-root-relative
# rows (row_project_relative = "1"); a row that only matched under --input
# has no comparable identity in that set and is never deduplicated.
_ppi_capture_declared_output_content() {
    _cdo_row_path="$1"
    _cdo_candidate="$2"          # resolved file path, or "" to use the
                                  # declaration commit
    _cdo_project_relative="$3"   # "1" or "0"

    if [ "$_cdo_project_relative" = "1" ] && _ppi_is_seen "$_cdo_row_path"; then
        return 0
    fi

    if [ -n "$_cdo_candidate" ]; then
        declared_content="${declared_content}# ---- ${_cdo_row_path} (declared output) ----
$(cat "$_cdo_candidate")
"
    else
        declared_content="${declared_content}# ---- ${_cdo_row_path} (declared output, at declaration commit ${_ppi_decl_commit}) ----
$(git -C "$project_root" show "${_ppi_decl_commit}:${_cdo_row_path}" 2>/dev/null)
"
    fi

    [ "$_cdo_project_relative" = "1" ] && _ppi_mark_seen "$_cdo_row_path"
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

        # Real implementation reports declare rows relative to project_root
        # (the same convention generate-evidence-bundle/check-evidence-bundle
        # use), while this script's own fixtures predate that convention and
        # declare rows relative to input_path. Try input_path first (today's
        # behavior, unchanged); only on a miss there, retry under
        # project_root. Whichever root actually resolves the row
        # independently passes the same containment guard above.
        _ppi_resolve_row_under_root "$_row_path" "$input_path"
        _row_escaped_input=0
        [ "$_ppi_row_state" = "escaped" ] && _row_escaped_input=1

        _row_project_relative=0
        if [ "$_ppi_row_state" = "matched" ]; then
            _candidate="$_ppi_row_candidate"
        else
            _ppi_resolve_row_under_root "$_row_path" "$project_root"

            if [ "$_ppi_row_state" = "matched" ]; then
                _candidate="$_ppi_row_candidate"
                _row_project_relative=1
            elif [ "$_row_escaped_input" = "1" ] || [ "$_ppi_row_state" = "escaped" ]; then
                _gaps="${_gaps}prepare-panelist-input: declared output resolves outside input root: ${_row_path}
"
                continue
            else
                # Absent under both roots. _row_path already passed the
                # canonical-path check above and did not escape under
                # project_root (only "absent" — never attempted-and-
                # escaped), so it is a valid repository-relative path to
                # re-check against the declaration commit before giving up
                # (see _ppi_verify_at_declaration_commit).
                if _ppi_verify_at_declaration_commit "$_row_path" "$_row_hash"; then
                    _ppi_capture_declared_output_content "$_row_path" "" "1"
                    continue
                fi
                _gaps="${_gaps}prepare-panelist-input: declared output missing from bundle: ${_row_path}
"
                continue
            fi
        fi

        _actual_hash="$(_ppi_sha256_file "$_candidate")"
        if [ "$_actual_hash" != "$_row_hash" ]; then
            if [ "$_row_project_relative" = "1" ] && \
               _ppi_verify_at_declaration_commit "$_row_path" "$_row_hash"; then
                _ppi_capture_declared_output_content "$_row_path" "" "1"
                continue
            fi
            _gaps="${_gaps}prepare-panelist-input: declared output hash mismatch: ${_row_path}
"
        else
            _ppi_capture_declared_output_content "$_row_path" "$_candidate" "$_row_project_relative"
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
# Uses python3 for reliable regex; required for sha256 as well. Wrapped as
# a function because the budget-driven size guard below may need to
# sanitize more than one candidate bundle (once per elision attempt) —
# content is still passed via a temp file to avoid shell interpolation of
# $ in Python heredocs.

if ! command -v python3 >/dev/null 2>&1; then
    printf 'prepare-panelist-input: python3 is required but not found\n' >&2
    exit 2
fi

# Sanitizes $1, setting globals $_ppi_sanitized_digest/$_ppi_sanitized_content.
_ppi_sanitize_content() {
    _psc_raw_tmp="$(mktemp)"
    _psc_py_tmp="${_psc_raw_tmp}.py"

    printf '%s' "$1" > "$_psc_raw_tmp"

    cat > "$_psc_py_tmp" << 'PYEOF'
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

    _psc_out=$(python3 "$_psc_py_tmp" "$_psc_raw_tmp")
    _psc_rc=$?
    rm -f "$_psc_raw_tmp" "$_psc_py_tmp"

    if [ "$_psc_rc" -ne 0 ]; then
        printf 'prepare-panelist-input: sanitization failed\n' >&2
        exit 2
    fi

    _ppi_sanitized_digest=$(printf '%s\n' "$_psc_out" | head -1)
    _ppi_sanitized_content=$(printf '%s\n' "$_psc_out" | tail -n +2)
}

# Measures the exact bytes a bundle built from the current
# $_ppi_sanitized_digest/$_ppi_sanitized_content would occupy on disk —
# header included, since that is what --max-bytes is measured against.
_ppi_measure_bundle_bytes() {
    _ppi_bundle_preview=$(
        printf '# Panelist Input Bundle\n'
        printf '# task_id: %s\n' "$task_id"
        printf '# feature: %s\n' "$feature"
        printf '# input_digest: %s\n' "$_ppi_sanitized_digest"
        printf '# consent: %s\n' "$consent_kind"
        printf '# WARNING: This file is sanitized for external LLM review.\n'
        printf '#          Do not include secrets, absolute paths, or private URLs.\n'
        printf '\n'
        printf '%s\n' "$_ppi_sanitized_content"
    )
    printf '%s' "$_ppi_bundle_preview" | wc -c | tr -d ' '
}

# ── Size guard (fail-closed, --max-bytes only) — budget-driven elision ──────
# Compose the bundle whole (empty elide-set) and measure it — the exact
# bytes that would be written and sent to a panelist, not an approximation.

_ppi_elide_set=""
_ppi_build_step3_content "$_ppi_elide_set"
_ppi_sanitize_content "${_ppi_content_prefix}${_ppi_step3_content}${_ppi_content_suffix}${declared_content}"
_ppi_bundle_bytes=$(_ppi_measure_bundle_bytes)

_ppi_elided_count=0
if [ -n "$max_bytes" ] && [ "$_ppi_bundle_bytes" -gt "$max_bytes" ] 2>/dev/null; then
    # Over cap with nothing elided yet. Elide elidable candidates one at a
    # time, LARGEST FIRST, recomputing the actual sanitized bundle size
    # after each (never estimated), stopping the moment it fits.
    if [ -n "$_ppi_elidable_index" ]; then
        while IFS="$_ppi_tab" read -r _ppi_cand_bytes _ppi_cand_abspath _ppi_cand_relpath; do
            [ -n "$_ppi_cand_relpath" ] || continue
            _ppi_elide_set="${_ppi_elide_set}
${_ppi_cand_relpath}"
            _ppi_elided_count=$((_ppi_elided_count + 1))
            _ppi_build_step3_content "$_ppi_elide_set"
            _ppi_sanitize_content "${_ppi_content_prefix}${_ppi_step3_content}${_ppi_content_suffix}${declared_content}"
            _ppi_bundle_bytes=$(_ppi_measure_bundle_bytes)
            [ "$_ppi_bundle_bytes" -gt "$max_bytes" ] 2>/dev/null || break
        done < <(printf '%s\n' "$_ppi_elidable_index" | sort -t "$_ppi_tab" -k1,1 -rn)
    fi

    if [ "$_ppi_bundle_bytes" -gt "$max_bytes" ] 2>/dev/null; then
        # Exhausted every elidable candidate (or there were none) and the
        # bundle is still over cap — the degenerate case where even every
        # elidable file's own head/tail/marker floor, summed with the
        # content that is never elided, still exceeds --max-bytes. No
        # further elision is possible; refusing to write is the only
        # honest outcome, identical in shape to the no-elidable-candidates
        # case this replaces.
        printf 'prepare-panelist-input: sanitized bundle exceeds --max-bytes for %s/%s even after eliding %s elidable file(s) (%s > %s bytes) — refusing to write a silently-truncated bundle.\n' \
            "$feature" "$task_id" "$_ppi_elided_count" "$_ppi_bundle_bytes" "$max_bytes" >&2
        printf '  spec documents + task verification + implementation report: %s bytes\n' \
            "$(printf '%s' "${_ppi_content_prefix}${_ppi_step3_content}${_ppi_content_suffix}" | wc -c | tr -d ' ')" >&2
        printf '  of which declared-outputs content:                          %s bytes\n' \
            "$(printf '%s' "$declared_content" | wc -c | tr -d ' ')" >&2
        printf '  sanitized bundle (header + content) that would have been written: %s bytes\n' \
            "$_ppi_bundle_bytes" >&2
        printf 'Every elidable verification-directory file is already cut to its head/tail; reduce input size further (e.g. split the report itself or a declared-outputs source) and retry, or omit --max-bytes to bypass the guard.\n' >&2
        exit 1
    fi
fi

input_digest="$_ppi_sanitized_digest"
sanitized_content="$_ppi_sanitized_content"

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
