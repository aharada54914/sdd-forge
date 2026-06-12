#!/usr/bin/env node
/**
 * Unified cross-runtime PreToolUse guard for the SDD quality loop (Node.js twin).
 *
 * This is the Node.js twin of sdd-hook-guard.py, used by Claude Code exec-form
 * hooks (hooks/claude-hooks.json) so the gates run identically on Windows (no
 * Git Bash needed), macOS, and Linux.
 *
 * Runs the same two checks for Claude Code:
 *
 *   1. Kill switch: if an AGENT_STOP file exists at $CLAUDE_PROJECT_DIR
 *      (fallback: cwd), deny every tool call until a human deletes it.
 *   2. Approval guard: deny any tool call that would INCREASE the number of
 *      "Approval: Approved" occurrences in a file whose path ends with
 *      tasks.md. Only a human may approve a task.
 *
 * Payload formats handled:
 *   - Claude / Copilot Edit/Write: tool_input.file_path plus
 *     old_string/new_string, edits[], or content (the latter is compared
 *     against the file currently on disk read as utf-8).
 *   - Codex apply_patch: tool_input.command holds the raw patch envelope.
 *     For each *** Update File:/*** Add File: section targeting a tasks.md,
 *     count Approval: Approved on + lines vs - lines and deny if net positive.
 *   - Codex Bash/shell (tool_name bash/shell/exec_command/exec): a conservative
 *     heuristic - if the shell command string mentions tasks.md AND contains
 *     Approval: Approved, deny.
 *
 * Output modes:
 *   --emit exit     (default) allow = exit 0; deny = reason on stderr, exit 2.
 *   --emit copilot  always print {"permissionDecision": ...} to stdout, exit 0.
 *
 * Malformed/unknown payloads are ALWAYS allowed. The guard never crashes.
 * Plain Node.js, no dependencies, works on Node 14+.
 */

'use strict';

const fs = require('fs');
const path = require('path');

const APPROVAL_RE = /Approval:\s*Approved/g;

const APPROVAL_MSG =
  "SDD deterministic gate: agents must not set 'Approval: Approved' in " +
  "tasks.md. Only a human may approve a task by editing the file directly. " +
  "Leave the task as Draft and ask the human to approve it.";

const KILL_MSG =
  "SDD kill switch: AGENT_STOP exists at the project root. All tool use is " +
  "suspended until a human deletes the file.";

function countApprovals(text) {
  if (!text) return 0;
  const matches = text.match(APPROVAL_RE);
  return matches ? matches.length : 0;
}

function isTasksMd(filePath) {
  // Case-insensitive match (intentional: Windows FS is case-insensitive; matches py/ps1 behavior).
  if (!filePath) return false;
  return String(filePath).replace(/\\/g, '/').toLowerCase().endsWith('tasks.md');
}

function emitDecision(decision, reason, mode) {
  if (mode === 'copilot') {
    const out = { permissionDecision: decision };
    if (decision === 'deny' && reason) {
      out.permissionDecisionReason = reason;
    }
    process.stdout.write(JSON.stringify(out));
    process.exit(0);
  }
  // exit mode
  if (decision === 'deny') {
    if (reason) {
      process.stderr.write(reason + '\n');
    }
    process.exit(2);
  }
  process.exit(0);
}

function killSwitchTripped() {
  const root = process.env.CLAUDE_PROJECT_DIR || '.';
  for (const base of [root, '.']) {
    try {
      const candidate = path.join(base, 'AGENT_STOP');
      const stat = fs.statSync(candidate);
      if (stat.isFile()) return true;
    } catch (e) {
      // not found or inaccessible — continue
    }
  }
  return false;
}

function looksLikePatch(command) {
  return typeof command === 'string' && command.includes('*** Begin Patch');
}

function patchIncreases(patch) {
  let currentIsTasks = false;
  let added = 0;
  let removed = 0;
  for (const raw of patch.split('\n')) {
    const line = raw.replace(/\r$/, '');
    const m = line.match(/^\*\*\* (Update|Add|Delete) File: (.+)$/);
    if (m) {
      currentIsTasks = isTasksMd(m[2].trim());
      continue;
    }
    if (line.startsWith('*** End Patch') || line.startsWith('*** Begin Patch')) {
      continue;
    }
    if (!currentIsTasks) continue;
    if (line.startsWith('+') && !line.startsWith('+++')) {
      added += countApprovals(line.slice(1));
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      removed += countApprovals(line.slice(1));
    }
  }
  return (added - removed) > 0;
}

function approvalIncreases(payload) {
  const toolInput = payload.tool_input || {};
  const toolName = String(payload.tool_name || '').toLowerCase();

  // --- Codex apply_patch: raw patch envelope in tool_input.command ---
  const command = toolInput.command;
  if (toolName === 'apply_patch' || looksLikePatch(command)) {
    return patchIncreases(command || '');
  }

  // --- Codex Bash/shell: conservative heuristic ---
  if (['bash', 'shell', 'exec_command', 'exec'].includes(toolName) && typeof command === 'string') {
    // Use countApprovals (which uses String.prototype.match, always searching from 0)
    // rather than APPROVAL_RE.test() to avoid leaving lastIndex in a non-zero state
    // on a true return (APPROVAL_RE is a global regex).
    if (command.toLowerCase().includes('tasks.md') && countApprovals(command) > 0) {
      return true;
    }
    return false;
  }

  // --- Claude / Copilot Edit / Write ---
  const filePath = toolInput.file_path || '';
  if (!isTasksMd(filePath)) return false;

  let oldCount = 0;
  let newCount = 0;

  if (Array.isArray(toolInput.edits)) {
    for (const edit of toolInput.edits) {
      const e = edit || {};
      oldCount += countApprovals(e.old_string);
      newCount += countApprovals(e.new_string);
    }
  } else if ('new_string' in toolInput) {
    oldCount = countApprovals(toolInput.old_string);
    newCount = countApprovals(toolInput.new_string);
  } else if ('content' in toolInput) {
    try {
      const diskContent = fs.readFileSync(filePath, 'utf8');
      oldCount = countApprovals(diskContent);
    } catch (e) {
      oldCount = 0;
    }
    newCount = countApprovals(toolInput.content);
  } else {
    return false;
  }

  return newCount > oldCount;
}

function parseArgs(argv) {
  let mode = 'exit';
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--emit' && i + 1 < argv.length) {
      mode = argv[i + 1];
      i++;
    } else if (argv[i].startsWith('--emit=')) {
      mode = argv[i].slice('--emit='.length);
    }
  }
  return (mode === 'exit' || mode === 'copilot') ? mode : 'exit';
}

function readStdin() {
  // If stdin is a TTY, treat as empty (don't hang waiting for input).
  if (process.stdin.isTTY) return Promise.resolve('');
  return new Promise((resolve) => {
    const chunks = [];
    process.stdin.setEncoding('utf8');
    process.stdin.on('data', (chunk) => chunks.push(chunk));
    process.stdin.on('end', () => resolve(chunks.join('')));
    process.stdin.on('error', () => resolve(''));
  });
}

async function main() {
  const mode = parseArgs(process.argv.slice(2));

  // Check 1: kill switch runs regardless of payload validity.
  if (killSwitchTripped()) {
    emitDecision('deny', KILL_MSG, mode);
  }

  let raw = process.env.PAYLOAD;
  if (raw === undefined || raw === null) {
    try {
      raw = await readStdin();
    } catch (e) {
      raw = '';
    }
  }

  let payload;
  try {
    payload = raw ? JSON.parse(raw) : {};
    if (typeof payload !== 'object' || payload === null || Array.isArray(payload)) {
      payload = {};
    }
  } catch (e) {
    emitDecision('allow', null, mode);
    return;
  }

  try {
    // Reset global regex state before use.
    APPROVAL_RE.lastIndex = 0;
    if (approvalIncreases(payload)) {
      emitDecision('deny', APPROVAL_MSG, mode);
    }
  } catch (e) {
    // Never crash; fail open on the approval check.
    emitDecision('allow', null, mode);
    return;
  }

  emitDecision('allow', null, mode);
}

main();
