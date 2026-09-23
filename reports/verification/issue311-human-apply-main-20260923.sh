#!/usr/bin/env bash
set -euo pipefail

# Human-authorized application for WFI-034/#311 on a fresh origin/main
# worktree. It applies only the missing new-reservation guard; it does not
# replace the current validators with an older candidate snapshot.
TARGET_ROOT="${ISSUE311_TARGET_ROOT:-$(cd "$(dirname "$0")/../.." && pwd -P)}"
SOURCE_ROOT="${ISSUE311_SOURCE_ROOT:-/Users/jrmag/.codex/worktrees/issue311-scratch-audit}"
if [[ "${ISSUE311_APPLY:-}" != 1 ]]; then
  printf '%s\n' 'Refusing protected-file writes. Re-run with ISSUE311_APPLY=1.' >&2
  exit 2
fi

target_head=$(git -C "$TARGET_ROOT" rev-parse HEAD)
origin_main=$(git -C "$TARGET_ROOT" rev-parse origin/main)
[[ "$target_head" == "$origin_main" ]] || {
  printf 'target must be a clean origin/main checkout (HEAD=%s origin/main=%s)\n' "$target_head" "$origin_main" >&2
  exit 1
}
[[ -z "$(git -C "$TARGET_ROOT" status --short)" ]] || {
  printf '%s\n' 'target worktree must be clean before protected-file application' >&2
  exit 1
}
command -v pwsh >/dev/null 2>&1 || { printf '%s\n' 'pwsh is required' >&2; exit 1; }

candidate_test="$SOURCE_ROOT/tests/issue311-scratch-isolation-candidate.tests.py"
[[ -f "$candidate_test" ]] || { printf 'missing candidate test: %s\n' "$candidate_test" >&2; exit 1; }
candidate_test_hash=$(if command -v sha256sum >/dev/null 2>&1; then sha256sum "$candidate_test" | awk '{print $1}'; else shasum -a 256 "$candidate_test" | awk '{print $1}'; fi)
[[ "$candidate_test_hash" == 0683027ed0251a71fccdeb28cdfa823108d33a8b68477a4ae88c83087cf4b4ac ]] || {
  printf '%s\n' 'candidate regression test hash mismatch' >&2
  exit 1
}

backup=$(mktemp -d "${TMPDIR:-/tmp}/sdd-issue311-main-apply.XXXXXX")
printf 'Backup: %s\nTarget: %s\nOrigin main: %s\n' "$backup" "$TARGET_ROOT" "$origin_main"
for path in \
  plugins/sdd-quality-loop/scripts/validate-review-context-set.sh \
  plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1 \
  tests/issue311-scratch-isolation.tests.py \
  tests/review-agent-isolation.tests.sh; do
  if [[ -e "$TARGET_ROOT/$path" ]]; then
    mkdir -p "$backup/$(dirname "$path")"
    cp -p "$TARGET_ROOT/$path" "$backup/$path"
  else
    printf 'Backup note: %s did not exist before application\n' "$path"
  fi
done

candidate_alias_sh="$TARGET_ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.issue311-candidate.sh"
candidate_alias_ps="$TARGET_ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.issue311-candidate.ps1"

export TARGET_ROOT
python3 - <<'PY'
from pathlib import Path
import os

root = Path(os.environ["TARGET_ROOT"])
sh = root / "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
ps = root / "plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"

def replace_once(path, old, new, marker, label):
    text = path.read_text()
    if marker in text:
        return
    if text.count(old) != 1:
        raise SystemExit(f"{label} anchor count is not exactly one")
    path.write_text(text.replace(old, new, 1))

if "scratch_root=''" not in sh.read_text():
    text = sh.read_text()
    anchor = "gate_report_declaration_path=''\n"
    state = "scratch_binding=''\nscratch_root=''\nif [[ \"$stage\" == quality ]] && jq -e 'has(\"scratch_root\")' \"$manifest\" >/dev/null 2>&1; then\n  scratch_root=$(jq -r '.scratch_root' \"$manifest\" | tr -d '\\r')\n  scratch_binding=$(printf '%s\\n%s' \"$feature\" \"$scratch_root\" | sha256_text)\nfi\n"
    if text.count(anchor) != 1:
        raise SystemExit("Bash scratch-state anchor count is not exactly one")
    sh.write_text(text.replace(anchor, state + anchor, 1))

sh_old = """  if jq -e --arg run \"$run_id\" --arg session \"$host_session_id\" '\n    any(.records[]; .host_session_id == $session and .run_id != $run)\n  ' \"$ledger\" >/dev/null 2>&1; then\n    fail IDENTITY 'host-session ID matches a persisted identity-ledger record but run ID does not: two launches are colliding on one identity'\n  fi\n\n  # Reservation of a new identity: today's behaviour, unchanged.\n"""
sh_new = sh_old.replace(
    "  # Reservation of a new identity: today's behaviour, unchanged.\n",
    """  # WFI-034/#311: a new evaluator reservation must declare its isolated
  # scratch root. Historical ledger records remain compatible because they
  # are handled by the persisted branch above.
  if $reserve && [[ \"$stage:$role\" == quality:sdd-evaluator && -z \"$scratch_root\" ]]; then
    fail PATH 'new sdd-evaluator reservation requires scratch_root'
  fi

  # Reservation of a new identity: today's behaviour, unchanged.
""",
)
replace_once(
    sh, sh_old, sh_new,
    "WFI-034/#311: a new evaluator reservation must declare its isolated",
    "Bash",
)

ps_old = """        if ($records | Where-Object { $_.host_session_id -ceq $document.host_session_id -and $_.run_id -cne $document.run_id }) {\n            Fail-ReviewContext 'IDENTITY' 'host-session ID matches a persisted identity-ledger record but run ID does not: two launches are colliding on one identity'\n        }\n\n        # Reservation of a new identity: today's behaviour, unchanged.\n"""
ps_new = ps_old.replace(
    "        # Reservation of a new identity: today's behaviour, unchanged.\n",
    """        # WFI-034/#311: a new evaluator reservation must declare its isolated
        # scratch root. Historical ledger records remain compatible because
        # they are handled by the persisted branch above.
        if ($Reserve -and \"$($document.stage):$($document.role)\" -ceq 'quality:sdd-evaluator' -and
            -not $document.ContainsKey('scratch_root')) {
            Fail-ReviewContext 'PATH' 'new sdd-evaluator reservation requires scratch_root'
        }

        # Reservation of a new identity: today's behaviour, unchanged.
""",
)
replace_once(
    ps, ps_old, ps_new,
    "WFI-034/#311: a new evaluator reservation must declare its isolated",
    "PowerShell",
)
PY

cp "$candidate_test" "$TARGET_ROOT/tests/issue311-scratch-isolation.tests.py"
chmod +x "$TARGET_ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"

# The existing isolation suite creates the chronological evaluator manifests
# through make_manifest().  Keep that suite green under WFI-034 by binding its
# fixture to the same scratch-root contract; do not weaken the validator.
export TARGET_ROOT
python3 - <<'PY'
from hashlib import sha256
from pathlib import Path
import os

path = Path(os.environ["TARGET_ROOT"]) / "tests/review-agent-isolation.tests.sh"
text = path.read_text()
marker = 'scratch_root:"/tmp/quality-f"'
if marker not in text:
    baseline = "4c790340d1b7b51cbdb07414555ffe94c75d0575208f3e5dfbe3913dd05739f4"
    if sha256(text.encode()).hexdigest() != baseline:
        raise SystemExit("review-agent-isolation.tests.sh baseline hash mismatch")
    old_manifest = '} + (if $role == "sdd-evaluator" then {task_id:"T-001"} else {} end))\' > "$output"'
    new_manifest = '} + (if $role == "sdd-evaluator" then {task_id:"T-001", scratch_root:"/tmp/quality-f"} else {} end))\' > "$output"'
    if text.count(old_manifest) != 1:
        raise SystemExit("review-agent isolation manifest anchor count is not exactly one")
    old_anchor = '  ledger_hash="$(sha256 "$ledger")"\n'
    new_anchor = '''  if [[ "$role" == "sdd-evaluator" ]]; then
    local implementation_report="$repository/reports/implementation/f/T-001.md"
    if ! grep -Fq '**Scratch Root**:' "$implementation_report"; then
      printf '%s\\n' '- **Scratch Root**: /tmp/implementation-f' >> "$implementation_report"
    fi
  fi
  ledger_hash="$(sha256 "$ledger")"\n'''
    if text.count(old_anchor) != 1:
        raise SystemExit("review-agent isolation ledger anchor count is not exactly one")
    old_isolation = "printf '\\n## Isolation Evidence\\n\\n- **Scratch Root**: /tmp/wfi034/implementation/task\\n' >> \"$implementation_report\""
    new_isolation = '''awk '{
  if ($0 == "- **Scratch Root**: /tmp/implementation-f") {
    print "- **Scratch Root**: /tmp/wfi034/implementation/task"
    next
  }
  print
}' "$implementation_report" > "$tmp/wfi034-report.md"
mv "$tmp/wfi034-report.md" "$implementation_report"'''
    if text.count(old_isolation) != 1:
        raise SystemExit("review-agent isolation root anchor count is not exactly one")
    text = text.replace(old_manifest, new_manifest, 1)
    text = text.replace(old_anchor, new_anchor, 1)
    path.write_text(text.replace(old_isolation, new_isolation, 1))
PY

# The candidate regression fixture invokes stable candidate basenames. Point
# those names at the freshly patched current-main validators for the duration
# of the run; never install the stale candidate validator snapshots.
ln -s validate-review-context-set.sh "$candidate_alias_sh"
ln -s validate-review-context-set.ps1 "$candidate_alias_ps"
cleanup_aliases() {
  rm -f "$candidate_alias_sh" "$candidate_alias_ps"
}
trap cleanup_aliases EXIT

bash -n "$TARGET_ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('$TARGET_ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1',[ref]\$null,[ref]\$null) | Out-Null"
python3 "$TARGET_ROOT/tests/issue311-scratch-isolation.tests.py" --repo "$TARGET_ROOT"
bash "$TARGET_ROOT/tests/review-agent-isolation.tests.sh"
printf '%s\n' 'Issue #311 targeted main-baseline repair and regression checks passed.'
