#!/bin/sh
# PreToolUse hook (Claude Code): suspend all tool use while AGENT_STOP exists.
# A human creates AGENT_STOP at the project root to stop the agent immediately
# and deletes it to resume. Exit 2 blocks the tool call.
root="${CLAUDE_PROJECT_DIR:-.}"
if [ -f "$root/AGENT_STOP" ]; then
  echo "SDD kill switch: AGENT_STOP exists at the project root. All tool use is suspended until a human deletes the file." >&2
  exit 2
fi
exit 0
