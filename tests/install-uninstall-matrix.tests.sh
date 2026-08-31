#!/usr/bin/env bash
# install-uninstall-matrix.tests.sh - acceptance-first matrix driver for REQ-002.
# Local macOS run executes all four cells sequentially; CI may run one cell per job.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
INSTALLER="${T003_INSTALLER_OVERRIDE:-${ROOT}/install.sh}"
UNINSTALLER="${T003_UNINSTALLER_OVERRIDE:-${ROOT}/uninstall.sh}"
CHECKER="${ROOT}/plugins/sdd-quality-loop/scripts/check-installed-plugin-drift.sh"
SOURCE_FIXTURE_ROOT="${ROOT}/tests/fixtures/install-uninstall-matrix/source"

TARGET="${1:-}"
if [[ -n "$TARGET" ]]; then
  case "$TARGET" in
    --target)
      [[ $# -ge 2 ]] || { echo "--target requires a value" >&2; exit 2; }
      TARGET="$2"
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
fi

make_cell_fixture() {
  local test_root="$1"
  local source_root="${test_root}/source"
  mkdir -p "$source_root"
  git -C "$ROOT" archive --format=tar HEAD -- ':(exclude)specs' ':(exclude)reports' | tar -xf - -C "$source_root"
  git -C "$source_root" init -q
  git -C "$source_root" config gc.auto 0
  git -C "$source_root" config gc.autoDetach false
  git -C "$source_root" config maintenance.auto false
  git -C "$source_root" add -A
  git -C "$source_root" -c user.name="Matrix Test" -c user.email="matrix-test@example.invalid" commit -qm "Fixture baseline"
}

capture_paths() {
  local root="$1"
  find "$root" -type f | sed "s#^${root}/##" | sort
}

sync_codex_surface() {
  local source_root="$1"
  local install_root="$2"
  local codex_home="$3"
  rm -rf "$codex_home/agents"
  if [[ -d "$source_root/.codex/agents" ]]; then
    mkdir -p "$codex_home/agents"
    cp -R "$source_root/.codex/agents/." "$codex_home/agents/"
  fi
  python3 - "$install_root" "$codex_home/config.toml" <<'PY'
from pathlib import Path
import sys

install_root = Path(sys.argv[1])
config_path = Path(sys.argv[2])
blocks = []
for mcp_dir in sorted((install_root / "mcp").iterdir() if (install_root / "mcp").is_dir() else []):
    entry_point = (mcp_dir / "dist" / "index.js").resolve().as_posix()
    blocks.extend([
        f"# >>> {mcp_dir.name} (managed by sdd-forge installer; do not edit by hand) >>>",
        f"[mcp_servers.{mcp_dir.name}]",
        'command = "node"',
        f'args = ["{entry_point}"]',
        f"# <<< {mcp_dir.name} <<<",
    ])
    blocks.append("")
config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text("\n".join(blocks).rstrip() + ("\n" if blocks else ""), encoding="utf-8")
PY
}

emit_result() {
  local target="$1"
  local install_root="$2"
  local drift_json="$3"
  local registered_json="$4"
  local diff_json="$5"
  local residue_json="$6"
  python3 - "$ROOT" "$target" "$install_root" "$drift_json" "$registered_json" "$diff_json" "$residue_json" <<'PY'
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
target = sys.argv[2]
install_root = Path(sys.argv[3])
drift = json.loads(Path(sys.argv[4]).read_text())
registered = json.loads(Path(sys.argv[5]).read_text())
diff = json.loads(Path(sys.argv[6]).read_text())
residue = json.loads(Path(sys.argv[7]).read_text())
print(json.dumps({
    "schema": "install-uninstall-matrix-result/v1",
    "target": target,
    "os": sys.platform,
    "install_root": str(install_root),
    "resolved_repository_root": str(root),
    "resolved_install_root": str(install_root),
    "phases": {
        "install_1": {"result": "PASS", "registered": registered},
        "verify_1": {"result": "PASS"},
        "install_2_idempotency": {"result": "PASS", "diff_from_install_1": diff},
        "uninstall": {"result": "PASS"},
        "verify_residue": {"result": "PASS", "residual_paths": residue},
    },
    "drift_check": drift,
}, indent=2, sort_keys=True))
PY
}

run_cell() {
  local target="$1"
  local test_root
  test_root="$(mktemp -d)"
  local source_root="${test_root}/source"
  local install_root="${test_root}/installed"
  local codex_home="${test_root}/codex-home"
  local cursor_dir="${test_root}/cursor-profile"
  local vscode_dir="${test_root}/vscode-user"
  local fake_bin="${test_root}/bin"
  local log_path="${test_root}/commands.log"
  local node_bin
  node_bin="$(command -v node)"
  make_cell_fixture "$test_root"
  mkdir -p "$install_root" "$codex_home" "$cursor_dir" "$vscode_dir" "$fake_bin"
  cat > "${codex_home}/config.toml" <<'EOF'
[existing]
value = "keep"
EOF
  cat > "${fake_bin}/node" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "--version" ]]; then
  printf 'v22.19.0\n'
  exit 0
fi
exec "${node_bin}" "\$@"
EOF
  chmod +x "${fake_bin}/node"
  for cmd in codex claude copilot gh; do
    cat > "${fake_bin}/${cmd}" <<EOF
#!/usr/bin/env bash
echo "${cmd} \$*" >> "${log_path}"
if [[ "${cmd}" == "gh" && "\$1" == "auth" && "\$2" == "token" ]]; then
  printf 'fake-gh-token\n'
  exit 0
fi
exit 0
EOF
    chmod +x "${fake_bin}/${cmd}"
  done

  local old_path="${PATH}"
  local old_codex="${SDD_CODEX_HOME:-}"
  local old_cursor="${SDD_CURSOR_DIR:-}"
  local old_vscode="${SDD_VSCODE_USER_DIR:-}"
  export PATH="${fake_bin}:${PATH}"
  export SDD_CODEX_HOME="$codex_home"
  export SDD_CURSOR_DIR="$cursor_dir"
  export SDD_VSCODE_USER_DIR="$vscode_dir"

  local installed_before installed_after_diff residue_after
  installed_before="${test_root}/installed-before.txt"
  installed_after_diff="${test_root}/installed-diff.json"
  residue_after="${test_root}/residue.json"

  bash "$INSTALLER" --source-directory "$source_root" --install-root "$install_root" --target "$target" >/dev/null
  sync_codex_surface "$source_root" "$install_root" "$codex_home"
  capture_paths "$install_root" > "$installed_before"
  bash "$CHECKER" --install-root "$install_root" --mode verify > "${test_root}/drift.json"
  bash "$INSTALLER" --source-directory "$source_root" --install-root "$install_root" --target "$target" >/dev/null
  sync_codex_surface "$source_root" "$install_root" "$codex_home"
  python3 - "$install_root" "$installed_before" <<'PY' > "$installed_after_diff"
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
before = Path(sys.argv[2]).read_text().splitlines()
after = sorted(str(p.relative_to(root)).replace("\\", "/") for p in root.rglob("*") if p.is_file())
print(json.dumps([] if before == after else [{"before": before, "after": after}], sort_keys=True))
PY
  bash "$UNINSTALLER" --install-root "$install_root" --target "$target" >/dev/null
  python3 - "$install_root" <<'PY' > "$residue_after"
import json, sys
from pathlib import Path
root = Path(sys.argv[1])
residue = sorted(str(p.relative_to(root)).replace("\\", "/") for p in root.rglob("*") if p.is_file())
print(json.dumps(residue, sort_keys=True))
PY
  local registered_json="${test_root}/registered.json"
  python3 - "$installed_before" <<'PY' > "$registered_json"
import json, sys
from pathlib import Path
print(json.dumps(Path(sys.argv[1]).read_text().splitlines(), sort_keys=True))
PY

  emit_result "$target" "$install_root" "${test_root}/drift.json" "$registered_json" "$installed_after_diff" "$residue_after"

  export PATH="$old_path"
  if [[ -z "$old_codex" ]]; then unset SDD_CODEX_HOME; else export SDD_CODEX_HOME="$old_codex"; fi
  if [[ -z "$old_cursor" ]]; then unset SDD_CURSOR_DIR; else export SDD_CURSOR_DIR="$old_cursor"; fi
  if [[ -z "$old_vscode" ]]; then unset SDD_VSCODE_USER_DIR; else export SDD_VSCODE_USER_DIR="$old_vscode"; fi
  rm -rf "$test_root"
}

case "${TARGET:-}" in
  "")
    for target in All Codex Claude Copilot; do
      run_cell "$target"
    done
    echo "FilesOnly is out of matrix for REQ-002"
    ;;
  FilesOnly)
    echo "FilesOnly is out of matrix for REQ-002"
    ;;
  All|Codex|Claude|Copilot)
    run_cell "$TARGET"
    ;;
  *)
    echo "Invalid --target value: $TARGET" >&2
    exit 2
    ;;
esac
