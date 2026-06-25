#!/usr/bin/env bash
# release-host-smoke.sh — opt-in, isolated release verification for real hosts.
#
# This is deliberately separate from deterministic CI. It may contact a local
# host CLI and therefore needs an authenticated release-operator session. Its
# only stdout is a JSON result so a release job can archive or evaluate it.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="${REPO_ROOT}/install.sh"
HOSTS="codex,claude,copilot"
RESULT_PATH=""

usage() {
    cat >&2 <<'EOF'
Usage: SDD_RELEASE_HOST_SMOKE=1 ./tests/release-host-smoke.sh [options]

Options:
  --hosts <codex,claude,copilot>  Hosts to verify (default: all)
  --result <path>                 Also write the JSON result to this path

Every host receives an isolated HOME, config, cache, and plugin installation
root. Missing CLIs and authentication-only registration failures are reported
as explicit skipped outcomes and exit 3, so a skipped smoke can never be
mistaken for a green release check. Other failures exit 1.
EOF
    exit 2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --hosts) [[ $# -gt 1 ]] || usage; HOSTS="$2"; shift 2 ;;
        --result) [[ $# -gt 1 ]] || usage; RESULT_PATH="$2"; shift 2 ;;
        *) usage ;;
    esac
done

if [[ "${SDD_RELEASE_HOST_SMOKE:-}" != "1" ]]; then
    echo "Refusing to run real host smoke: set SDD_RELEASE_HOST_SMOKE=1." >&2
    exit 2
fi

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "$value"
}

json_string() {
    printf '"%s"' "$(json_escape "$1")"
}

is_credential_failure() {
    local log_file="$1"
    grep -Eqi 'auth(entication|orization)?|credential|login|log in|api[ -]?key|unauthori[sz]ed|permission denied' "$log_file"
}

SMOKE_ROOT="$(mktemp -d)"
CONFIG_ROOT="${SDD_HOST_SMOKE_CONFIG_ROOT:-${SMOKE_ROOT}/config}"
if [[ -e "$CONFIG_ROOT" ]]; then
    echo "SDD_HOST_SMOKE_CONFIG_ROOT must not already exist: $CONFIG_ROOT" >&2
    exit 2
fi
trap 'rm -rf "$SMOKE_ROOT" "$CONFIG_ROOT"' EXIT

# Do not let the real CLIs read or write an operator's ordinary configuration,
# session cache, or installed plugins. SDD_CODEX_HOME is separate because the
# installer places its independent Codex reviewer-agent TOML files there.
export HOME="${CONFIG_ROOT}/home"
export CODEX_HOME="${CONFIG_ROOT}/codex"
export CLAUDE_CONFIG_DIR="${CONFIG_ROOT}/claude"
export XDG_CONFIG_HOME="${CONFIG_ROOT}/xdg-config"
export XDG_CACHE_HOME="${CONFIG_ROOT}/xdg-cache"
export SDD_CODEX_HOME="${CONFIG_ROOT}/sdd-codex"
mkdir -p "$HOME" "$CODEX_HOME" "$CLAUDE_CONFIG_DIR" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$SDD_CODEX_HOME"

IFS=',' read -r -a selected_hosts <<< "$HOSTS"
[[ ${#selected_hosts[@]} -gt 0 ]] || usage

records=()
failed=0
passed=0
skipped=0

for host in "${selected_hosts[@]}"; do
    case "$host" in
        codex) target="Codex" ;;
        claude) target="Claude" ;;
        copilot) target="Copilot" ;;
        *) echo "Unknown host: $host" >&2; exit 2 ;;
    esac

    install_root="${SMOKE_ROOT}/${host}-install"
    plugin_version="$(jq -r '.version' "${REPO_ROOT}/plugins/sdd-bootstrap/.plugin/plugin.json")"

    if ! command -v "$host" >/dev/null 2>&1; then
        records+=("{\"host\":$(json_string "$host"),\"outcome\":\"skipped\",\"skip_reason\":\"CLI not found in PATH\",\"cli_version\":null,\"plugin_version\":$(json_string "$plugin_version"),\"install_root\":$(json_string "$install_root"),\"reload\":{\"outcome\":\"not-run\"},\"discovery\":{\"outcome\":\"not-proven\"}}")
        skipped=$((skipped + 1))
        continue
    fi

    cli_version="$($host --version 2>/dev/null | head -n 1 || true)"
    install_log="${SMOKE_ROOT}/${host}-install.log"
    echo "Running isolated ${host} release registration smoke." >&2
    if ! "$INSTALLER" \
        --source-directory "$REPO_ROOT" \
        --install-root "$install_root" \
        --target "$target" \
        --plugins sdd-bootstrap,sdd-ship >"$install_log" 2>&1; then
        cat "$install_log" >&2
        if is_credential_failure "$install_log"; then
            records+=("{\"host\":$(json_string "$host"),\"outcome\":\"skipped\",\"skip_reason\":\"CLI registration requires credentials or an interactive login\",\"cli_version\":$(json_string "$cli_version"),\"plugin_version\":$(json_string "$plugin_version"),\"install_root\":$(json_string "$install_root"),\"reload\":{\"outcome\":\"not-run\"},\"discovery\":{\"outcome\":\"not-proven\"}}")
            skipped=$((skipped + 1))
            continue
        fi
        records+=("{\"host\":$(json_string "$host"),\"outcome\":\"failed\",\"failure\":\"plugin registration failed; see stderr\",\"cli_version\":$(json_string "$cli_version"),\"plugin_version\":$(json_string "$plugin_version"),\"install_root\":$(json_string "$install_root"),\"reload\":{\"outcome\":\"not-run\"},\"discovery\":{\"outcome\":\"not-proven\"}}")
        failed=1
        continue
    fi

    # Check all staged workflow surfaces, not merely the bootstrap manifest.
    host_failed=0
    required_surfaces=(
        "${install_root}/plugins/sdd-bootstrap/skills/run/SKILL.md" \
        "${install_root}/plugins/sdd-ship/skills/run/SKILL.md" \
        "${install_root}/plugins/sdd-review-loop/skills/spec-review-loop/SKILL.md" \
        "${install_root}/plugins/sdd-review-loop/agents/spec-reviewer-a.md" \
        "${install_root}/plugins/sdd-review-loop/agents/task-reviewer-a.md"
    )
    # The installer intentionally installs the Codex TOML role definitions
    # only for the Codex target; Claude and Copilot discover reviewer agents
    # from the staged plugin directories above.
    if [[ "$host" == "codex" ]]; then
        required_surfaces+=("${SDD_CODEX_HOME}/agents/sdd-evaluator.toml")
    fi
    for required in "${required_surfaces[@]}"; do
        if [[ ! -f "$required" ]]; then
            echo "Release smoke did not stage required workflow surface: $required" >&2
            host_failed=1
        fi
    done

    reload_outcome="fresh-process"
    discovery_output="${SMOKE_ROOT}/${host}-discovery.log"
    case "$host" in
        codex)
            # A fresh Codex process is the supported reload boundary.
            codex plugin list >"$discovery_output" 2>&1 || host_failed=1
            grep -Fq 'sdd-bootstrap' "$discovery_output" || host_failed=1
            grep -Fq 'sdd-ship' "$discovery_output" || host_failed=1
            ;;
        claude)
            # Claude Code applies plugin updates at the next session boundary.
            # Running update followed by a new details process proves the
            # registration/reload path without sending a model prompt.
            if ! claude plugin update sdd-bootstrap@sdd-plugins >"${SMOKE_ROOT}/${host}-reload.log" 2>&1; then
                cat "${SMOKE_ROOT}/${host}-reload.log" >&2
                host_failed=1
            fi
            reload_outcome="restart-requested"
            claude plugin details sdd-bootstrap@sdd-plugins >"$discovery_output" 2>&1 || host_failed=1
            grep -Fq 'Skills' "$discovery_output" || host_failed=1
            grep -Fq 'run' "$discovery_output" || host_failed=1
            ship_details="${SMOKE_ROOT}/${host}-ship-details.log"
            claude plugin details sdd-ship@sdd-plugins >"$ship_details" 2>&1 || host_failed=1
            cat "$ship_details" >>"$discovery_output"
            grep -Fq 'sdd-ship' "$ship_details" || host_failed=1
            grep -Fq 'Skills' "$ship_details" || host_failed=1
            grep -Eq '(^|[[:space:],])run([[:space:],]|$)' "$ship_details" || host_failed=1
            claude plugin details sdd-review-loop@sdd-plugins >>"$discovery_output" 2>&1 || host_failed=1
            grep -Fq 'spec-review-loop' "$discovery_output" || host_failed=1
            grep -Fq 'spec-reviewer-a' "$discovery_output" || host_failed=1
            grep -Fq 'task-reviewer-a' "$discovery_output" || host_failed=1
            ;;
        copilot)
            copilot plugin list >"$discovery_output" 2>&1 || host_failed=1
            grep -Fq 'sdd-bootstrap' "$discovery_output" || host_failed=1
            ;;
    esac

    if [[ $host_failed -eq 1 ]]; then
        records+=("{\"host\":$(json_string "$host"),\"outcome\":\"failed\",\"failure\":\"staged workflow surface, reload, or runtime discovery check failed; see stderr\",\"cli_version\":$(json_string "$cli_version"),\"plugin_version\":$(json_string "$plugin_version"),\"install_root\":$(json_string "$install_root"),\"reload\":{\"outcome\":$(json_string "$reload_outcome")},\"discovery\":{\"outcome\":\"failed\",\"commands\":[\"sdd-bootstrap:run\",\"sdd-ship:run\",\"sdd-review-loop:spec-review-loop\"],\"reviewer_agents\":[\"spec-reviewer-a\",\"task-reviewer-a\"]}}")
        failed=1
    else
        records+=("{\"host\":$(json_string "$host"),\"outcome\":\"passed\",\"cli_version\":$(json_string "$cli_version"),\"plugin_version\":$(json_string "$plugin_version"),\"install_root\":$(json_string "$install_root"),\"reload\":{\"outcome\":$(json_string "$reload_outcome")},\"discovery\":{\"outcome\":\"registered-and-inspected\",\"commands\":[\"sdd-bootstrap:run\",\"sdd-ship:run\",\"sdd-review-loop:spec-review-loop\"],\"reviewer_agents\":[\"spec-reviewer-a\",\"task-reviewer-a\"]}}")
        passed=$((passed + 1))
    fi
done

if [[ $failed -ne 0 ]]; then
    overall="failed"
elif [[ $passed -eq 0 ]]; then
    overall="skipped"
elif [[ $skipped -eq 0 ]]; then
    overall="passed"
else
    overall="passed-with-skips"
fi

result="{\"schema_version\":1,\"outcome\":\"${overall}\",\"isolated_roots\":{\"home\":$(json_string "$HOME"),\"config\":$(json_string "$CONFIG_ROOT"),\"cache\":$(json_string "$XDG_CACHE_HOME")},\"hosts\":["
for index in "${!records[@]}"; do
    if [[ $index -ne 0 ]]; then
        result+=","
    fi
    result+="${records[$index]}"
done
result+="]}"

if [[ -n "$RESULT_PATH" ]]; then
    mkdir -p "$(dirname "$RESULT_PATH")"
    printf '%s\n' "$result" >"$RESULT_PATH"
fi
printf '%s\n' "$result"

if [[ $failed -ne 0 ]]; then
    exit 1
fi
if [[ $skipped -ne 0 ]]; then
    exit 3
fi
