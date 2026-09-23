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
  tests/issue311-scratch-isolation.tests.py; do
  mkdir -p "$backup/$(dirname "$path")"
  cp -p "$TARGET_ROOT/$path" "$backup/$path"
done

export TARGET_ROOT
python3 - <<'PY'
from pathlib import Path
import os

root = Path(os.environ["TARGET_ROOT"])
sh = root / "plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
ps = root / "plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"

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
sh_text = sh.read_text()
if sh_text.count(sh_old) != 1:
    raise SystemExit("Bash anchor count is not exactly one")
sh.write_text(sh_text.replace(sh_old, sh_new, 1))

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
ps_text = ps.read_text()
if ps_text.count(ps_old) != 1:
    raise SystemExit("PowerShell anchor count is not exactly one")
ps.write_text(ps_text.replace(ps_old, ps_new, 1))
PY

cp "$candidate_test" "$TARGET_ROOT/tests/issue311-scratch-isolation.tests.py"
chmod +x "$TARGET_ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
bash -n "$TARGET_ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
pwsh -NoProfile -Command "[System.Management.Automation.Language.Parser]::ParseFile('$TARGET_ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1',[ref]\$null,[ref]\$null) | Out-Null"
python3 "$TARGET_ROOT/tests/issue311-scratch-isolation.tests.py" --repo "$TARGET_ROOT"
bash "$TARGET_ROOT/tests/review-agent-isolation.tests.sh"
printf '%s\n' 'Issue #311 targeted main-baseline repair and regression checks passed.'
