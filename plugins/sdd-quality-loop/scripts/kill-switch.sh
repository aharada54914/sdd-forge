#!/bin/sh
# PreToolUse hook (Claude Code): suspend all tool use while AGENT_STOP exists.
# A human creates AGENT_STOP at the project root to stop the agent immediately
# and deletes it to resume. Exit 2 blocks the tool call.
# C-08: walk parents up to git root checking for AGENT_STOP.

deny_inspection() {
  echo "SDD kill switch: cannot inspect stop-marker path; tool use denied." >&2
  exit 2
}

# test -f hides EACCES. Enumerate only this directory, then follow only the
# marker link: unrelated dangling/cyclic links must not block tool use.
check_agent_stop() {
  base=$1
  case "$base" in /*|./*|../*) ;; *) base="./$base" ;; esac
  ancestor=$base
  while [ ! -e "$ancestor" ] && [ ! -L "$ancestor" ]; do
    parent=$(dirname -- "$ancestor") || deny_inspection
    [ "$parent" != "$ancestor" ] || deny_inspection
    ancestor=$parent
  done
  # A missing optional root is allowed only after its nearest existing parent
  # can actually be inspected. -H follows this argument, never its children.
  find -H "$ancestor" -maxdepth 0 >/dev/null 2>&1 || deny_inspection
  if [ -d "$ancestor" ]; then
    [ -x "$ancestor" ] || deny_inspection
  else
    return
  fi
  [ "$ancestor" = "$base" ] || return
  marker=$(find -H "$base" -mindepth 1 -maxdepth 1 -name AGENT_STOP -exec printf present \; 2>/dev/null) || deny_inspection
  [ -n "$marker" ] || return
  marker=$(find -L "$base/AGENT_STOP" -maxdepth 0 -type f -exec printf present \; 2>/dev/null) || deny_inspection
  if [ -n "$marker" ]; then
    echo "SDDキルスイッチ: プロジェクトルートに AGENT_STOP が存在します。人間がこのファイルを削除するまで、すべてのツール使用が停止されます。" >&2
    echo "[EN] SDD kill switch: AGENT_STOP exists at the project root. All tool use is suspended until a human deletes the file." >&2
    exit 2
  fi
}

# Check for AGENT_STOP, handling spaces in paths safely.
if [ -n "$CLAUDE_PROJECT_DIR" ]; then
  check_agent_stop "$CLAUDE_PROJECT_DIR"
  check_agent_stop "."
else
  # Walk up to 20 levels from cwd to git root.
  dir=$(pwd)
  i=0
  while [ "$i" -le 20 ]; do
    check_agent_stop "$dir"
    # Stop at git root (both .git directory and .git file for worktrees).
    if [ -e "$dir/.git" ]; then
      break
    fi
    parent=$(dirname -- "$dir")
    [ "$parent" = "$dir" ] && break
    dir="$parent"
    i=$((i+1))
  done
fi
exit 0
