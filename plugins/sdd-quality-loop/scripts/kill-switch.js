#!/usr/bin/env node
/**
 * PreToolUse hook (Node.js twin of kill-switch.sh): suspend all tool use while
 * AGENT_STOP exists. A human creates AGENT_STOP at the project root to stop
 * the agent immediately and deletes it to resume. Exit 2 blocks the tool call.
 *
 * Used by Claude Code exec-form hooks (hooks/claude-hooks.json) so the gate
 * runs identically on Windows (no Git Bash needed), macOS, and Linux.
 */

'use strict';

const fs = require('fs');
const path = require('path');

const root = process.env.CLAUDE_PROJECT_DIR || '.';
const candidate = path.join(root, 'AGENT_STOP');

let isFile = false;
try {
  isFile = fs.statSync(candidate).isFile();
} catch (e) {
  // not found or inaccessible
}

if (isFile) {
  process.stderr.write(
    "SDD kill switch: AGENT_STOP exists at the project root. All tool use is " +
    "suspended until a human deletes the file.\n"
  );
  process.exit(2);
}
process.exit(0);
