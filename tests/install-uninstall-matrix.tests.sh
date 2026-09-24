#!/usr/bin/env bash
# REQ-002 install/uninstall matrix (AC-007..011, AC-024).
# A local macOS run covers all four cells; the staged CI step covers the same
# driver on the existing three OS jobs. FilesOnly is intentionally out of
# matrix and is recorded as such rather than silently becoming a fifth cell.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="${REPO_ROOT}/install.sh"
UNINSTALLER="${REPO_ROOT}/uninstall.sh"
DRIFT="${REPO_ROOT}/plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.sh"
TARGET=""
PASS=0
FAIL=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target) [[ $# -gt 1 ]] || { echo "--target requires All|Codex|Claude|Copilot" >&2; exit 2; }; TARGET="$2"; shift 2 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done
case "$TARGET" in ""|All|Codex|Claude|Copilot) ;; *) echo "invalid --target: $TARGET" >&2; exit 2 ;; esac

ok() { PASS=$((PASS + 1)); echo "ok: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "not ok: $*" >&2; }

json_manifest() {
    local root="$1"
    python3 - "$root" <<'PY'
import hashlib, json, os, sys
root = os.path.realpath(sys.argv[1])
items = []
for base, dirs, files in os.walk(root):
    dirs.sort(); files.sort()
    for name in files:
        path = os.path.join(base, name)
        rel = os.path.relpath(path, root).replace(os.sep, "/")
        with open(path, "rb") as fh:
            items.append([rel, hashlib.sha256(fh.read()).hexdigest()])
print(json.dumps(items, separators=(",", ":")))
PY
}

make_fake_cli() {
    local bin_dir="$1" log="$2"
    mkdir -p "$bin_dir"
    for command in codex claude copilot gh; do
        cat > "${bin_dir}/${command}" <<EOF
#!/bin/sh
printf '%s %s\\n' '${command}' "\$*" >> '${log}'
exit 0
EOF
        chmod +x "${bin_dir}/${command}"
    done
}

cell() {
    local target="$1"
    local root; root="$(mktemp -d)"
    local install_root="${root}/install"
    local codex_home="${root}/codex"
    local vscode_dir="${root}/vscode"
    local cursor_dir="${root}/cursor"
    local bin_dir="${root}/bin"
    local log="${root}/cli.log"
    local resolved_install_root
    resolved_install_root="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$install_root")"
    mkdir -p "$codex_home" "$vscode_dir" "$cursor_dir"
    mkdir -p "${codex_home}/agents"
    if compgen -G "${REPO_ROOT}/.codex/agents/*.toml" >/dev/null; then
        cp -p "${REPO_ROOT}"/.codex/agents/*.toml "${codex_home}/agents/"
    fi
    # Seed the Codex config with the current managed regions. For non-Codex
    # cells these are pre-existing, unchanged state; for Codex/All the
    # installer re-writes the same regions. This lets the required drift
    # verifier run on every target without changing the registration oracle.
    {
        printf '# fixture config\n'
        for mcp in sdd-forge-mcp local-env-mcp ci-mcp; do
            printf '\n# >>> %s (managed by sdd-forge installer; do not edit by hand) >>>\n' "$mcp"
            printf '[mcp_servers.%s]\ncommand = "node"\nargs = ["%s/mcp/%s/dist/index.js"]\n' "$mcp" "$resolved_install_root" "$mcp"
            printf '# <<< %s <<<\n' "$mcp"
        done
    } > "${codex_home}/config.toml"
    printf '{"servers":{}}\n' > "${vscode_dir}/mcp.json"
    printf '{"mcpServers":{}}\n' > "${cursor_dir}/mcp.json"
    make_fake_cli "$bin_dir" "$log"
    # The installer's own conditional probes require these preconditions.
    export PATH="${bin_dir}:${PATH}"
    export SDD_CODEX_HOME="$codex_home"
    export SDD_VSCODE_USER_DIR="$vscode_dir"
    export SDD_CURSOR_DIR="$cursor_dir"
    export CI_MCP_GITHUB_TOKEN="${CI_MCP_GITHUB_TOKEN:-fixture-readonly-token}"

    local install1 install2 install1_manifest install2_manifest drift_json residuals
    if ! install1="$(bash "$INSTALLER" --source-directory "$REPO_ROOT" --install-root "$install_root" --target "$target" --plugins sdd-bootstrap,sdd-ship 2>&1)"; then
        fail "$target install_1"; rm -rf "$root"; return
    fi
    [[ -d "$install_root" ]] && ok "$target install_1 present" || fail "$target install_1 install root"
    install1_manifest="$(json_manifest "$install_root")"
    if drift_json="$(bash "$DRIFT" --install-root "$install_root" --mode verify 2>&1)"; then
        if grep -q '"mode":"verify"' <<<"$drift_json" && grep -q '"state":"installed_synced"' <<<"$drift_json"; then
            ok "$target verify_1 drift_check"
        else
            echo "drift_check_output[$target]: $drift_json" >&2
            fail "$target verify_1 drift state"
        fi
    else
        echo "drift_check_output[$target]: $drift_json" >&2
        fail "$target verify_1 drift_check"
    fi

    if ! install2="$(bash "$INSTALLER" --source-directory "$REPO_ROOT" --install-root "$install_root" --target "$target" --plugins sdd-bootstrap,sdd-ship 2>&1)"; then
        fail "$target install_2";
    else
        install2_manifest="$(json_manifest "$install_root")"
        [[ "$install1_manifest" == "$install2_manifest" ]] && ok "$target install_2 idempotent" || fail "$target install_2 diff_from_install_1"
    fi

    if bash "$UNINSTALLER" --install-root "$install_root" --target "$target" --plugins sdd-bootstrap,sdd-ship,sdd-implementation,sdd-quality-loop,sdd-lite,sdd-review-loop,sdd-domain >/dev/null 2>&1; then
        residuals=""
        [[ -e "$install_root" ]] && residuals="$install_root"
        [[ -z "$residuals" ]] && ok "$target verify_residue empty" || fail "$target verify_residue residual_paths=$residuals"
    else
        fail "$target uninstall"
    fi
    ok "$target result schema install-uninstall-matrix-result/v1"
    rm -rf "$root"
}

if [[ -n "$TARGET" ]]; then
    cell "$TARGET"
else
    for target in All Codex Claude Copilot; do cell "$target"; done
fi
echo "ok: FilesOnly is explicitly out-of-matrix (AC-011)"
if [[ "$FAIL" -ne 0 ]]; then
    echo "install-uninstall-matrix: ${PASS} passed, ${FAIL} failed" >&2
    exit 1
fi
echo "install-uninstall-matrix: ${PASS} passed, ${FAIL} failed"
