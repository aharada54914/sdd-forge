# Shared helpers for the panelist collection-layer runners
# (run-panelist-gpt.sh, run-panelist-gemini.sh). Sourced, not executed —
# the same convention sdd-hook-guard.sh uses for its generated invariants.
#
# Contract: every function runs in the caller's shell (no subshell), so
# `exit` terminates the runner itself — that is intentional for the
# fail-closed validation helpers. _sdd_run_bounded additionally requires
# the caller to have set $_scratch (the runner's mktemp -d scratch dir).

# sdd_panelist_validate_timeout <tool-name> <value>
# Rejects a non-numeric or non-positive SDD_PANELIST_TIMEOUT (exit 2).
sdd_panelist_validate_timeout() {
    case "$2" in
        '' | *[!0-9]*)
            printf '%s: SDD_PANELIST_TIMEOUT must be a positive whole number of seconds (got: %s)\n' \
                "$1" "$2" >&2
            exit 2
            ;;
    esac
    if [ "$2" -le 0 ]; then
        printf '%s: SDD_PANELIST_TIMEOUT must be positive (got: %s)\n' "$1" "$2" >&2
        exit 2
    fi
}

# sdd_panelist_require_args <tool-name> <task_id> <feature> <input_path>
# Fail-closed argument validation shared by both runners: missing flags are
# usage errors (exit 2); a named-but-absent input file is a runtime failure
# (exit 1), matching the runners' documented exit-code contract.
sdd_panelist_require_args() {
    if [ -z "$2" ]; then
        printf '%s: --task is required\n' "$1" >&2; exit 2
    fi
    if [ -z "$3" ]; then
        printf '%s: --feature is required\n' "$1" >&2; exit 2
    fi
    if [ -z "$4" ]; then
        printf '%s: --input is required\n' "$1" >&2; exit 2
    fi
    if [ ! -f "$4" ]; then
        printf '%s: input file not found: %s\n' "$1" "$4" >&2; exit 1
    fi
}

# Run the vendor CLI in a dedicated process group. Python's os.setsid() is the
# portable equivalent of the setsid utility, which is absent on macOS. A
# completion marker closes the polling race: it is written before the process-
# group leader exits, so a child finishing at the deadline keeps its real code.
#
# Stdin hazard (invocation-fix hardening): POSIX shells default an
# asynchronous command's stdin to /dev/null unless THAT command carries its
# own explicit redirect -- a redirect on the enclosing function call (as
# used at every call site, `_sdd_run_bounded ... < "$_combined"`)
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
