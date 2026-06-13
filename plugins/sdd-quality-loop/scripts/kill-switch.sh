#!/bin/sh
# PreToolUse hook (Claude Code): suspend all tool use while AGENT_STOP exists.
# A human creates AGENT_STOP at the project root to stop the agent immediately
# and deletes it to resume. Exit 2 blocks the tool call.
# C-08: walk parents up to git root checking for AGENT_STOP.

# Helper: check for AGENT_STOP at the given directory.
check_agent_stop() {
  if [ -f "$1/AGENT_STOP" ]; then
    echo "SDD kill switch: AGENT_STOP exists at the project root. All tool use is suspended until a human deletes the file." >&2
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
