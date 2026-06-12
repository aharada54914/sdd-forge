#!/bin/sh
# PreToolUse hook (Claude Code): suspend all tool use while AGENT_STOP exists.
# A human creates AGENT_STOP at the project root to stop the agent immediately
# and deletes it to resume. Exit 2 blocks the tool call.
# Checks both CLAUDE_PROJECT_DIR (if set) and cwd, matching sdd-hook-guard.js semantics.
root="${CLAUDE_PROJECT_DIR:-.}"
for base in "$root" "."; do
  if [ -f "$base/AGENT_STOP" ]; then
    echo "SDD kill switch: AGENT_STOP exists at the project root. All tool use is suspended until a human deletes the file." >&2
    exit 2
  fi
done
exit 0
