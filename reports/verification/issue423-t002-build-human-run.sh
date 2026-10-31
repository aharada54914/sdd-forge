#!/usr/bin/env bash
# Human-run T-002 current-byte distribution assembly check. Do not run as an agent.
set -euo pipefail

repo_root=/Users/jrmag/.codex/worktrees/issue423-approved-recovery/sdd-forge
validator_rel=plugins/sdd-quality-loop/scripts/validate-capability-registry.py
helper_rel=plugins/sdd-quality-loop/scripts/registry_discovery.py
validator_sha=843f473f1234572426d1a4b23e6a4cd03515dc214ae3b9b16590df7ed9f819c5
helper_sha=ea08dbd141b24f4685fd9211b4454d782e5ea80e081e0a59d89ee7f7fe5282ea
installer_sha=87bcebfeb53f6521f03cc62f2bc760902bd7af2d28ea24ffb2d29662b71bad50

if [[ ! -d "$repo_root/reports/verification" ]]; then
    printf 'Missing expected report directory: %s\n' "$repo_root/reports/verification" >&2
    exit 2
fi

log_file="$(mktemp "$repo_root/reports/verification/issue423-t002-build-human.log.XXXXXXXX")"
stage_root="$(mktemp -d "${TMPDIR:-/tmp}/sdd-t002-build.XXXXXXXX")"

finish() {
    result=$?
    trap - EXIT
    if [[ "$result" -eq 0 ]]; then
        printf 'BUILD=PASS; installed validator=PASS; log=%s; staged tree=%s\n' "$log_file" "$stage_root"
    else
        printf 'BUILD=FAIL (exit %s); log=%s; staged tree=%s\n' "$result" "$log_file" "$stage_root" >&2
    fi
    printf '%s\n' '--- test output ---'
    cat "$log_file"
    exit "$result"
}
trap finish EXIT

verify_sha() {
    local source_file="$1"
    local expected="$2"
    local actual
    actual="$(shasum -a 256 "$source_file")"
    actual="${actual%% *}"
    if [[ "$actual" != "$expected" ]]; then
        printf 'SHA-256 mismatch: %s (expected %s, found %s)\n' \
            "$source_file" "$expected" "$actual" >&2
        return 1
    fi
    printf 'SHA-256 verified: %s %s\n' "$actual" "$source_file"
}

run_check() {
    cd "$repo_root"
    verify_sha "$validator_rel" "$validator_sha"
    verify_sha "$helper_rel" "$helper_sha"
    verify_sha install.sh "$installer_sha"

    # FilesOnly/skip flags and the isolated install root prevent registration
    # or mutation of the user's actual plugin, MCP, and agent configuration.
    ./install.sh \
        --source-directory "$repo_root" \
        --install-root "$stage_root/installed" \
        --target FilesOnly \
        --skip-plugin-install \
        --skip-agent-install \
        --skip-mcp

    cmp "$validator_rel" "$stage_root/installed/$validator_rel"
    cmp "$helper_rel" "$stage_root/installed/$helper_rel"
    verify_sha "$stage_root/installed/$validator_rel" "$validator_sha"
    verify_sha "$stage_root/installed/$helper_rel" "$helper_sha"

    python3 -B "$stage_root/installed/$validator_rel" \
        --registry "$stage_root/installed/contracts/capability-registry.json" \
        --repo-root "$stage_root/installed"
    printf 'T-002 installed payload assembly, byte parity, and validator execution: PASS\n'
}

run_check >"$log_file" 2>&1
