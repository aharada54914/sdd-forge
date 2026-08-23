#!/usr/bin/env bash
# installer-idempotency.tests.sh — WFI-041: re-running the installer on an
# already-installed machine must be a no-op or an upgrade, never a rollback.
#
# The installer's failure mode was invisible without external CLIs, so this
# suite supplies stubbed `claude`, `copilot` and `codex` executables on PATH
# that emit the messages the real CLIs emitted on 2026-08-22, with the exit
# codes they used. Each scenario asserts an installer outcome, not a stub
# behaviour.
#
# Scenario map (mirrors WFI-041's Verification Plan):
#  A. idempotent registration — "already registered"/"already exists" is
#     success, the install root is the new version, no backup is left behind
#  B. upgrade path — a stale plugin cache is converged and the transition is
#     reported; an already-current cache reports no change
#  C. narrowed rollback, both directions — a placement-phase failure still
#     reverts; a registration-phase failure does not
#  D. genuine failures stay fatal — an unrelated non-zero exit is not
#     swallowed by the idempotency matcher
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
INSTALLER="$ROOT/install.sh"

PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
bad()  { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

[ -f "$INSTALLER" ] || { echo "FAIL: installer not found at $INSTALLER"; exit 1; }

# ---------------------------------------------------------------------------
# Stub CLIs. STUB_MODE selects the behaviour under test; STUB_LOG records the
# invocations so the upgrade-path assertions can check what was called.
# ---------------------------------------------------------------------------
STUB_BIN="$WORK/bin"
mkdir -p "$STUB_BIN"

make_stub() {
    local name="$1"
    cat > "$STUB_BIN/$name" <<STUB
#!/usr/bin/env bash
printf '%s %s\n' "$name" "\$*" >> "\$STUB_LOG"
case "\$*" in
  *"plugin validate"*) exit 0 ;;
  *"marketplace add"*)
      if [ "\${STUB_MODE:-}" = "already" ] || [ "\${STUB_MODE:-}" = "stale-cache" ] || [ "\${STUB_MODE:-}" = "current-cache" ]; then
          echo 'Failed to add marketplace: Error: Marketplace "sdd-plugins" already registered' >&2
          exit 1
      fi
      exit 0 ;;
  *"mcp add"*)
      if [ "\${STUB_MODE:-}" = "already" ] || [ "\${STUB_MODE:-}" = "stale-cache" ] || [ "\${STUB_MODE:-}" = "current-cache" ]; then
          echo 'MCP server sdd-forge-mcp already exists in user config' >&2
          exit 1
      fi
      exit 0 ;;
  *"marketplace update"*) echo 'Updated marketplace sdd-plugins'; exit 0 ;;
  *"plugin update"*)
      if [ "\${STUB_MODE:-}" = "stale-cache" ]; then
          echo 'updated from 1.15.0 to 1.16.0'; exit 0
      fi
      echo 'Plugin is up to date'; exit 0 ;;
  *"plugin install"*|*"plugin add"*)
      if [ "\${STUB_MODE:-}" = "genuine-failure" ]; then
          echo 'Error: manifest is malformed at line 3' >&2
          exit 1
      fi
      if [ "\${STUB_MODE:-}" = "already" ] || [ "\${STUB_MODE:-}" = "stale-cache" ] || [ "\${STUB_MODE:-}" = "current-cache" ]; then
          echo 'Plugin "sdd-bootstrap" is already installed (scope: user)'; exit 0
      fi
      exit 0 ;;
esac
exit 0
STUB
    chmod +x "$STUB_BIN/$name"
}
make_stub claude
make_stub copilot
make_stub codex

# ---------------------------------------------------------------------------
# A source tree the installer accepts via --source-directory: a git repository
# whose root carries the plugin manifests the installer copies.
# ---------------------------------------------------------------------------
# The required-path list is read from the installer itself rather than
# duplicated here: a fixture that hard-codes it would silently stop covering a
# path the installer later adds.
SRC="$WORK/src"
mkdir -p "$SRC"
while IFS= read -r rel; do
    mkdir -p "$SRC/$(dirname "$rel")"
    case "$rel" in
        *.json) printf '{"name":"fixture","version":"9.9.9"}\n' > "$SRC/$rel" ;;
        # Codex agent role files are validated for content: name and
        # developer_instructions must both be present, and no BOM.
        *.toml) printf 'name = "fixture"\ndeveloper_instructions = "fixture"\n' > "$SRC/$rel" ;;
        *)      printf 'fixture\n' > "$SRC/$rel" ;;
    esac
done < <(sed -n '/^REQUIRED_PATHS=(/,/^)/p' "$INSTALLER" | sed -n 's/^[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p')
if [ ! -s "$SRC/.agents/plugins/marketplace.json" ]; then
    echo "FAIL: could not derive REQUIRED_PATHS from the installer"; exit 1
fi
printf 'marker\n' > "$SRC/VERSION"
git -C "$SRC" init -q 2>/dev/null
git -C "$SRC" -c user.email=t@t -c user.name=t add -A >/dev/null 2>&1
git -C "$SRC" -c user.email=t@t -c user.name=t commit -qm init >/dev/null 2>&1

# run_installer <mode> <install-root>
# Sets LAST_RC (exit code) and LAST_OUT (captured output path). Deliberately
# NOT called through a command substitution: a subshell would discard both
# globals, leaving later greps reading a stale file.
LAST_OUT=""
LAST_RC=0
run_installer() {
    local mode="$1" install_root="$2"; shift 2
    LAST_RC=0
    LAST_OUT="$WORK/out-$RANDOM$RANDOM.txt"
    STUB_MODE="$mode" STUB_LOG="$WORK/stub.log" \
        PATH="$STUB_BIN:$PATH" \
        bash "$INSTALLER" \
            --source-directory "$SRC" \
            --install-root "$install_root" \
            --target Claude \
            --plugins sdd-bootstrap \
            > "$LAST_OUT" 2>&1 || LAST_RC=$?
}

installed_marker() {
    # The installer places the source tree; VERSION is our version marker.
    [ -f "$1/VERSION" ] && cat "$1/VERSION" 2>/dev/null || echo "ABSENT"
}

# ---------------------------------------------------------------------------
# A — idempotent registration on an already-installed machine
# ---------------------------------------------------------------------------
: > "$WORK/stub.log"
ROOT_A="$WORK/root-a"
run_installer clean "$ROOT_A"; rc=$LAST_RC
if [ "$rc" != "0" ]; then
    bad "A setup: first install should succeed (rc=$rc): $(tail -3 "$LAST_OUT")"
else
    ok "A setup: first install succeeds on a clean machine"
fi

# Second run: every registration reports "already ..." and exits non-zero.
printf 'OLD\n' > "$ROOT_A/VERSION"   # make a revert detectable
printf 'marker-v2\n' > "$SRC/VERSION"
git -C "$SRC" -c user.email=t@t -c user.name=t commit -aqm v2 >/dev/null 2>&1
: > "$WORK/stub.log"
run_installer already "$ROOT_A"; rc=$LAST_RC
if [ "$rc" != "0" ]; then
    bad "A: re-run against an already-registered machine should exit 0 (rc=$rc): $(grep -iE 'error|failed' "$LAST_OUT" | head -2)"
else
    ok "A: re-run exits 0 when every registration reports already-present"
fi
if [ "$(installed_marker "$ROOT_A")" = "marker-v2" ]; then
    ok "A: install root holds the NEW version after the re-run (no rollback)"
else
    bad "A: install root was reverted — holds '$(installed_marker "$ROOT_A")', expected marker-v2"
fi
if compgen -G "$(dirname "$ROOT_A")/sdd-plugins-backup-*" > /dev/null 2>&1; then
    bad "A: a backup directory was left behind after a successful run"
else
    ok "A: no backup directory remains after a successful run"
fi

# ---------------------------------------------------------------------------
# B — upgrade path
# ---------------------------------------------------------------------------
: > "$WORK/stub.log"
ROOT_B="$WORK/root-b"
run_installer clean "$ROOT_B"
: > "$WORK/stub.log"
run_installer stale-cache "$ROOT_B"; rc=$LAST_RC
if [ "$rc" != "0" ]; then
    bad "B: run against a stale cache should exit 0 (rc=$rc)"
else
    ok "B: run against a stale cache exits 0"
fi
if grep -q "marketplace update" "$WORK/stub.log" && grep -q "plugin update" "$WORK/stub.log"; then
    ok "B: the installer invoked marketplace-update and plugin-update"
else
    bad "B: the installer did not invoke the upgrade commands: $(grep claude "$WORK/stub.log" | head -3)"
fi
if grep -q "cache upgraded" "$LAST_OUT"; then
    ok "B: the version transition is reported"
else
    bad "B: no upgrade transition reported: $(tail -3 "$LAST_OUT")"
fi
# Non-vacuity: an already-current cache must report NO change, otherwise the
# check above would pass on a tool that always claims an upgrade.
: > "$WORK/stub.log"
run_installer current-cache "$ROOT_B"; rc=$LAST_RC
if grep -q "already at the installed version" "$LAST_OUT"; then
    ok "B: an already-current cache reports no change (non-vacuity)"
else
    bad "B: a current cache did not report 'no change': $(tail -3 "$LAST_OUT")"
fi

# ---------------------------------------------------------------------------
# C — narrowed rollback, both directions
# ---------------------------------------------------------------------------
# C1: registration-phase failure must NOT revert the tree. `genuine-failure`
# makes `plugin install` fail with an unrelated error, after placement.
ROOT_C="$WORK/root-c"
: > "$WORK/stub.log"
run_installer clean "$ROOT_C"
printf 'OLD\n' > "$ROOT_C/VERSION"
printf 'marker-v3\n' > "$SRC/VERSION"
git -C "$SRC" -c user.email=t@t -c user.name=t commit -aqm v3 >/dev/null 2>&1
: > "$WORK/stub.log"
run_installer genuine-failure "$ROOT_C"; rc=$LAST_RC
C1_OUT="$LAST_OUT"   # section D asserts on this run's diagnostics
if [ "$rc" = "0" ]; then
    bad "C1: an unrelated registration error must still fail the run (rc=0)"
else
    ok "C1: an unrelated registration error fails the run (rc=$rc)"
fi
if [ "$(installed_marker "$ROOT_C")" = "marker-v3" ]; then
    ok "C1: a registration-phase failure leaves the NEW tree in place (narrowed rollback)"
else
    bad "C1: the tree was reverted on a registration-phase failure — holds '$(installed_marker "$ROOT_C")'"
fi

# C2: a placement-phase failure must STILL revert. Point --source-directory at
# a path that fails before placement; the pre-existing install must survive.
ROOT_C2="$WORK/root-c2"
: > "$WORK/stub.log"
run_installer clean "$ROOT_C2"
printf 'PRESERVED\n' > "$ROOT_C2/VERSION"
rc=0
STUB_MODE=clean STUB_LOG="$WORK/stub.log" PATH="$STUB_BIN:$PATH" \
    bash "$INSTALLER" --source-directory "$WORK/does-not-exist" \
        --install-root "$ROOT_C2" --target Claude --plugins sdd-bootstrap \
        > "$WORK/out-c2.txt" 2>&1 || rc=$?
if [ "$rc" = "0" ]; then
    bad "C2: a missing source directory must fail the run"
else
    ok "C2: a placement-phase failure fails the run (rc=$rc)"
fi
if [ "$(installed_marker "$ROOT_C2")" = "PRESERVED" ]; then
    ok "C2: a placement-phase failure preserves the existing install (rollback still fires)"
else
    bad "C2: the existing install was lost on a placement-phase failure — holds '$(installed_marker "$ROOT_C2")'"
fi

# ---------------------------------------------------------------------------
# D — the idempotency matcher must not swallow genuine failures
# ---------------------------------------------------------------------------
# C1's run above failed on an unrelated `plugin install` error. The operator
# must see that error text, not a silent "already present" note, or the
# idempotency matcher would be indistinguishable from swallowing everything.
if grep -qiE "manifest is malformed|failed with exit code" "$C1_OUT"; then
    ok "D: a genuine registration error is reported, not swallowed"
else
    bad "D: the genuine error text did not reach the operator: $(tail -3 "$C1_OUT")"
fi
if grep -qi "already present; treating as success" "$C1_OUT"; then
    bad "D: a genuine failure was reported as already-present"
else
    ok "D: a genuine failure is not mislabelled as already-present"
fi

echo ""
echo "installer-idempotency.tests.sh: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
