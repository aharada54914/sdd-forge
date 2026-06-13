#!/usr/bin/env node
/**
 * Unified cross-runtime PreToolUse guard for the SDD quality loop (Node.js twin).
 *
 * This is the Node.js twin of sdd-hook-guard.py, used by Claude Code exec-form
 * hooks (hooks/claude-hooks.json) so the gates run identically on Windows (no
 * Git Bash needed), macOS, and Linux.
 *
 * Runs the same three checks for Claude Code:
 *
 *   1. Kill switch: if an AGENT_STOP file exists at $CLAUDE_PROJECT_DIR
 *      (fallback: cwd), deny every tool call until a human deletes it.
 *   2. Approval guard: deny any tool call that would INCREASE the number of
 *      "Approval: Approved" occurrences in a file whose path ends with
 *      tasks.md. Only a human may approve a task. Bypassed while a human-enabled
 *      SDD_SUDO flag file with an unexpired 'expires-epoch: <unix-seconds>' line
 *      exists at the project root (sudo mode). Checks 1 and 3 are never bypassed.
 *   3. Agent-role guard: deny any tool call that would write a Codex agent role
 *      file (path matching .codex/agents/[^/]+.toml) without a
 *      developer_instructions field. Such files are ignored by Codex at startup.
 *
 * Payload formats handled:
 *   - Claude / Copilot Edit/Write: tool_input.file_path plus
 *     old_string/new_string, edits[], or content (the latter is compared
 *     against the file currently on disk read as utf-8).
 *   - Codex apply_patch: tool_input.command holds the raw patch envelope.
 *     For each *** Update File:/*** Add File: section targeting a tasks.md,
 *     count Approval: Approved on + lines vs - lines and deny if net positive.
 *   - Codex Bash/shell (tool_name bash/shell/exec_command/exec): deny shell
 *     commands that write to a Codex agent role path; read-only commands are
 *     allowed. Shell approval edits still follow the approval guard.
 *
 * Output modes:
 *   --emit exit     (default) allow = exit 0; deny = reason on stderr, exit 2.
 *   --emit copilot  always print {"permissionDecision": ...} to stdout, exit 0.
 *
 * Malformed/unknown payloads are denied. The guard never crashes.
 * Plain Node.js, no dependencies, works on Node 14+.
 */

'use strict';

const fs = require('fs');
const path = require('path');

const APPROVAL_RE = /Approval:\s*Approved/g;
const WFI_APPROVAL_RE = /Status:\s*Approved/g;
const AGENT_ROLE_PATH_RE = /\.codex\/agents\/[^/]+\.toml$/i;
const DEVELOPER_INSTRUCTIONS_RE = /(^|\n)[ \t]*developer_instructions[ \t]*=/;
const SUDO_EPOCH_RE = /(^|\n)[ \t]*expires-epoch:[ \t]*(\d+)/;
const SUDO_ISSUED_RE = /(^|\n)[ \t]*issued-epoch:[ \t]*(\d+)/;
const SHELL_AGENT_ROLE_READ_ONLY_RE = /^\s*(?:cat|ls|stat|head|tail|grep|rg)\b[^;&|><]*\.codex\/agents(?:\/|\b)/is;
// C-02: shell write patterns that indicate SDD_SUDO manipulation
const SHELL_SUDO_WRITE_RE = /(?:>|>>|\btee\b|\btouch\b|\bcp\b|\bmv\b|\brm\b|\bSet-Content\b|\bOut-File\b|\bNew-Item\b|\bRemove-Item\b)/i;
const SHELL_SUDO_READ_ONLY_RE = /^\s*(?:cat|ls|test|grep|stat|head|tail|rg)\b/i;
const TARGETED_COMMAND_TOOLS = new Set(['apply_patch', 'bash', 'shell', 'exec_command', 'exec']);
const TARGETED_FILE_TOOLS = new Set(['edit', 'write', 'multiedit']);

const SDD_SUDO_NAME = 'SDD_SUDO';

const APPROVAL_MSG =
  "SDD deterministic gate: agents must not set 'Approval: Approved' in " +
  "tasks.md. Only a human may approve a task by editing the file directly. " +
  "Leave the task as Draft and ask the human to approve it.";

const WFI_APPROVAL_MSG =
  "SDD deterministic gate: agents must not set 'Status: Approved' in a " +
  "docs/workflow-improvements/WFI-*.md file. Only a human may approve a " +
  "Workflow Improvement; this is never bypassed by sudo. Leave it as Draft " +
  "and ask the human to approve it.";

const SDD_SUDO_WRITE_MSG =
  "SDD deterministic gate: agents must not create, edit, or delete the " +
  "SDD_SUDO flag file. Only a human may manage sudo mode.";

const KILL_MSG =
  "SDD kill switch: AGENT_STOP exists at the project root. All tool use is " +
  "suspended until a human deletes the file.";

const AGENT_ROLE_MSG =
  "SDD deterministic gate: refusing to write a Codex agent role file without " +
  "developer_instructions. Files under .codex/agents/ must define " +
  "developer_instructions or Codex ignores them at startup " +
  "('Ignoring malformed agent role definition'). Use the shipped " +
  "sdd-investigator/sdd-evaluator roles instead of creating new ones.";

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

function isWfiPath(filePath) {
  // WFI docs live under docs/workflow-improvements/ and end with .md.
  if (!filePath) return false;
  const normalized = String(filePath).replace(/\\/g, '/').toLowerCase();
  return normalized.includes('workflow-improvements/') && normalized.endsWith('.md');
}

function wfiCount(text) {
  if (!text) return 0;
  const matches = text.match(WFI_APPROVAL_RE);
  return matches ? matches.length : 0;
}

function isAgentRolePath(filePath) {
  if (!filePath) return false;
  const normalized = String(filePath).replace(/\\/g, '/').toLowerCase();
  return AGENT_ROLE_PATH_RE.test(normalized);
}

function hasDeveloperInstructions(content) {
  if (typeof content !== 'string' || !content) return false;
  return DEVELOPER_INSTRUCTIONS_RE.test(content);
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

function findGitRoot(start) {
  let current = path.resolve(start);
  for (let i = 0; i < 20; i++) {
    const gitCandidate = path.join(current, '.git');
    try {
      if (fs.existsSync(gitCandidate)) {
        return current;
      }
    } catch (e) {
      // continue
    }
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
  return null;
}

function resolveProjectRoot() {
  const envRoot = process.env.CLAUDE_PROJECT_DIR;
  if (envRoot) {
    return { sudoRoot: envRoot, bases: [envRoot, '.'] };
  }
  const gitRoot = findGitRoot('.');
  if (gitRoot) {
    return { sudoRoot: gitRoot, bases: [gitRoot, '.'] };
  }
  return { sudoRoot: '.', bases: ['.'] };
}

function killSwitchTripped() {
  // C-08: walk parents up to git root checking for AGENT_STOP.
  const envRoot = process.env.CLAUDE_PROJECT_DIR;
  let bases;
  if (envRoot) {
    bases = [envRoot, '.'];
  } else {
    // Walk up to 20 levels; check every directory up to and including git root.
    bases = [];
    let current = path.resolve('.');
    let gitRootFound = null;
    for (let i = 0; i < 21; i++) {
      bases.push(current);
      const gitCandidate = path.join(current, '.git');
      try {
        if (fs.existsSync(gitCandidate)) {
          gitRootFound = current;
          break;
        }
      } catch (e) {
        // continue
      }
      const parent = path.dirname(current);
      if (parent === current) break;
      current = parent;
    }
    if (!gitRootFound && !bases.includes('.')) {
      bases.push('.');
    }
  }
  for (const base of bases) {
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

function sudoActive() {
  // C-02/C-08: True if valid, unexpired SDD_SUDO flag exists at project root only.
  // Validates: not a symlink, has issued-epoch, expires-epoch in future, TTL <= 86400s.
  const proj = resolveProjectRoot();
  const sudoRoot = proj.sudoRoot;
  try {
    const flag = path.join(sudoRoot, SDD_SUDO_NAME);
    // C-02: symlink check — symlink SDD_SUDO is invalid.
    try {
      const stats = fs.lstatSync(flag);
      if (stats.isSymbolicLink()) {
        return false;
      }
      if (!stats.isFile()) {
        return false;
      }
    } catch (e) {
      return false;
    }
    const content = fs.readFileSync(flag, 'utf8');
    const mExp = content.match(SUDO_EPOCH_RE);
    const mIss = content.match(SUDO_ISSUED_RE);
    if (!mExp || !mIss) {
      return false;
    }
    const expires = parseInt(mExp[2], 10);
    const issued = parseInt(mIss[2], 10);
    const now = Math.floor(Date.now() / 1000);
    // C-02: issued-epoch <= now < expires-epoch AND TTL <= 86400
    if (issued > now) {
      return false;
    }
    if (expires <= now) {
      return false;
    }
    if (expires - issued > 86400) {
      return false;
    }
    return true;
  } catch (e) {
    // missing or unreadable — sudo stays inactive
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

function patchWritesInvalidAgentRole(patch) {
  let currentIsAgentRole = false;
  let bodyLines = [];
  let currentOp = null;
  for (const raw of patch.split('\n')) {
    const line = raw.replace(/\r$/, '');
    const m = line.match(/^\*\*\* (Update|Add|Delete) File: (.+)$/);
    if (m) {
      // Flush previous Add File section if it targeted an agent role.
      if (currentOp === 'Add' && currentIsAgentRole && !hasDeveloperInstructions(bodyLines.join('\n'))) {
        return true;
      }
      bodyLines = [];
      currentOp = m[1];
      const filePath = m[2].trim();
      currentIsAgentRole = isAgentRolePath(filePath);
      if (currentIsAgentRole && (currentOp === 'Update' || currentOp === 'Delete')) {
        return true;
      }
      continue;
    }
    if (line.startsWith('*** End Patch') || line.startsWith('*** Begin Patch')) {
      continue;
    }
    if (currentOp === 'Add' && currentIsAgentRole && line.startsWith('+') && !line.startsWith('+++')) {
      bodyLines.push(line.slice(1));
    }
  }
  // Flush final section.
  if (currentOp === 'Add' && currentIsAgentRole && !hasDeveloperInstructions(bodyLines.join('\n'))) {
    return true;
  }
  return false;
}

function shellWritesInvalidAgentRole(cmd) {
  if (typeof cmd !== 'string') return false;
  const normalizedCmd = cmd.replace(/\\/g, '/');
  if (!/\.codex\/agents(?:\/|\b)/i.test(normalizedCmd)) return false;
  return !SHELL_AGENT_ROLE_READ_ONLY_RE.test(normalizedCmd);
}

function targetPathIsSddSudo(filePath) {
  // C-02: Return True if file_path ends with 'SDD_SUDO' (case-insensitive).
  if (!filePath) return false;
  const normalized = String(filePath).replace(/\\/g, '/').toLowerCase();
  return normalized.endsWith(SDD_SUDO_NAME.toLowerCase());
}

function shellTargetsSddSudo(cmd) {
  // C-02: Return True if shell command targets SDD_SUDO file for write/delete.
  if (typeof cmd !== 'string') return false;
  // Check if SDD_SUDO appears in the command (case-insensitive).
  if (!cmd.toLowerCase().includes(SDD_SUDO_NAME.toLowerCase())) {
    return false;
  }
  // Check if there's a write operator or destructive verb.
  if (SHELL_SUDO_WRITE_RE.test(cmd)) {
    return true;
  }
  return false;
}

function payloadIsMalformed(payload) {
  const toolName = String(payload.tool_name || '').toLowerCase();
  const toolInput = payload.tool_input || {};
  if (TARGETED_COMMAND_TOOLS.has(toolName) && (typeof toolInput.command !== 'string' || toolInput.command.trim() === '')) {
    return true;
  }
  if (TARGETED_FILE_TOOLS.has(toolName)) {
    if (typeof toolInput.file_path !== 'string' || toolInput.file_path.trim() === '') return true;
    if (!('edits' in toolInput || 'new_string' in toolInput || 'content' in toolInput)) return true;
  }
  return false;
}

function writeContentIncreases(filePath, newContent) {
  // C-03 Write: deny any net increase in Approved markers.
  // True if newContent raises the file-wide Approved count (which also covers a
  // brand-new file and any 'Approval: Approved' written outside a recognized
  // ## T-NNN section), or if any individual task section goes from un-approved
  // to Approved while the file-wide total stays constant.
  let oldContent = '';
  try {
    oldContent = fs.readFileSync(filePath, 'utf8');
  } catch (e) {
    oldContent = '';
  }

  // File-wide guard: any net increase in total Approved markers is a deny.
  // Catches headerless approvals, brand-new files, and bulk additions.
  if (countApprovals(newContent) > countApprovals(oldContent)) {
    return true;
  }

  // Task-section guard: catch a per-task Draft->Approved swap that keeps the
  // file-wide total constant.
  // Extract task sections from old and new content.
  const taskRegex = /^##\s+(T-\S+)/gm;
  const oldTasks = {};
  const newTasks = {};

  let match;
  const oldSections = oldContent.split(taskRegex);
  for (let i = 1; i < oldSections.length; i += 2) {
    const taskId = oldSections[i];
    const section = oldSections[i + 1] || '';
    oldTasks[taskId] = countApprovals(section);
  }

  const newSections = newContent.split(taskRegex);
  for (let i = 1; i < newSections.length; i += 2) {
    const taskId = newSections[i];
    const section = newSections[i + 1] || '';
    newTasks[taskId] = countApprovals(section);
  }

  // Check for transitions: Draft → Approved or new Approved tasks.
  for (const taskId in newTasks) {
    const newCount = newTasks[taskId];
    if (newCount > 0) {
      const oldCount = oldTasks[taskId] || 0;
      // If Approved count increased, or if this is a new task with Approved.
      if (newCount > oldCount) {
        return true;
      }
    }
  }

  return false;
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

  if (Array.isArray(toolInput.edits)) {
    // C-03: any Approved added in any new_string is a deny, regardless of deletions.
    for (const edit of toolInput.edits) {
      const e = edit || {};
      if (countApprovals(e.new_string) > 0) {
        return true;
      }
    }
    return false;
  } else if ('new_string' in toolInput) {
    // C-03: any Approved in new_string is a deny (don't subtract old).
    return countApprovals(toolInput.new_string) > 0;
  } else if ('content' in toolInput) {
    // C-03 Write: task-section-level comparison.
    return writeContentIncreases(filePath, toolInput.content || '');
  } else {
    return false;
  }
}

function wfiApprovalIncreases(payload) {
  // WFI approval is human-only and NEVER bypassed by sudo. Mirrors the tasks.md
  // approval guard but keyed on 'Status: Approved' and scoped to
  // docs/workflow-improvements/*.md.
  const toolInput = payload.tool_input || {};
  const toolName = String(payload.tool_name || '').toLowerCase();
  const command = toolInput.command;

  if (toolName === 'apply_patch' || looksLikePatch(command)) {
    return wfiPatchIncreases(command || '');
  }

  if (['bash', 'shell', 'exec_command', 'exec'].includes(toolName) && typeof command === 'string') {
    if (command.toLowerCase().includes('workflow-improvements/') && wfiCount(command) > 0) {
      return true;
    }
    return false;
  }

  const filePath = toolInput.file_path || '';
  if (!isWfiPath(filePath)) return false;

  if (Array.isArray(toolInput.edits)) {
    for (const edit of toolInput.edits) {
      const e = edit || {};
      if (wfiCount(e.new_string) > 0) {
        return true;
      }
    }
    return false;
  } else if ('new_string' in toolInput) {
    return wfiCount(toolInput.new_string) > 0;
  } else if ('content' in toolInput) {
    return wfiWriteContentIncreases(filePath, toolInput.content || '');
  } else {
    return false;
  }
}

function wfiWriteContentIncreases(filePath, newContent) {
  let oldContent = '';
  try {
    oldContent = fs.readFileSync(filePath, 'utf8');
  } catch (e) {
    oldContent = '';
  }
  return wfiCount(newContent) > wfiCount(oldContent);
}

function wfiPatchIncreases(patch) {
  let currentIsWfi = false;
  let added = 0;
  let removed = 0;
  for (const raw of patch.split('\n')) {
    const line = raw.replace(/\r$/, '');
    const m = line.match(/^\*\*\* (Update|Add|Delete) File: (.+)$/);
    if (m) {
      currentIsWfi = isWfiPath(m[2].trim());
      continue;
    }
    if (line.startsWith('*** End Patch') || line.startsWith('*** Begin Patch')) {
      continue;
    }
    if (!currentIsWfi) continue;
    if (line.startsWith('+') && !line.startsWith('+++')) {
      added += wfiCount(line.slice(1));
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      removed += wfiCount(line.slice(1));
    }
  }
  return (added - removed) > 0;
}

function agentRoleInvalid(payload) {
  const toolInput = payload.tool_input || {};
  const toolName = String(payload.tool_name || '').toLowerCase();

  // --- Codex apply_patch: check Add File sections for agent role paths ---
  const command = toolInput.command;
  if (toolName === 'apply_patch' || looksLikePatch(command)) {
    return patchWritesInvalidAgentRole(command || '');
  }

  // --- Write-style tools: full-file writes with file_path ---
  const filePath = toolInput.file_path || '';
  if (isAgentRolePath(filePath) && 'content' in toolInput) {
    const content = toolInput.content;
    if (!hasDeveloperInstructions(content)) {
      return true;
    }
  }

  return false;
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
      throw new Error('payload must be a JSON object');
    }
  } catch (e) {
    emitDecision('deny', 'SDD deterministic gate: malformed hook payload.', mode);
    return;
  }

  try {
    if (typeof payload.tool_name !== 'string' || typeof payload.tool_input !== 'object' || payload.tool_input === null || Array.isArray(payload.tool_input)) {
      emitDecision('deny', 'SDD deterministic gate: malformed hook payload.', mode);
      return;
    }
    if (payloadIsMalformed(payload)) {
      emitDecision('deny', 'SDD deterministic gate: malformed hook payload.', mode);
      return;
    }

    // Check 2a: C-02 SDD_SUDO write/delete protection (never bypassed by sudo).
    const toolName = String(payload.tool_name || '').toLowerCase();
    const toolInput = payload.tool_input || {};
    const filePath = (toolInput.file_path || '').toLowerCase();

    // File tools: Edit, Write, MultiEdit targeting SDD_SUDO.
    if (['edit', 'write', 'multiedit'].includes(toolName)) {
      if (targetPathIsSddSudo(filePath)) {
        emitDecision('deny', SDD_SUDO_WRITE_MSG, mode);
        return;
      }
    }

    // Shell commands targeting SDD_SUDO.
    if (['bash', 'shell', 'exec_command', 'exec'].includes(toolName) && typeof toolInput.command === 'string') {
      if (shellTargetsSddSudo(toolInput.command)) {
        emitDecision('deny', SDD_SUDO_WRITE_MSG, mode);
        return;
      }
    }

    // apply_patch: check for SDD_SUDO targets.
    if (toolName === 'apply_patch' || looksLikePatch(toolInput.command)) {
      const patch = toolInput.command || '';
      const fileRegex = /^\*\*\* (Update|Add|Delete) File: (.+)$/gm;
      let fileMatch;
      while ((fileMatch = fileRegex.exec(patch))) {
        if (targetPathIsSddSudo(fileMatch[2].trim())) {
          emitDecision('deny', SDD_SUDO_WRITE_MSG, mode);
          return;
        }
      }
    }

    // Check 2b: Approval guard (bypassed by valid sudo).
    // Reset global regex state before use.
    APPROVAL_RE.lastIndex = 0;
    if (approvalIncreases(payload) && !sudoActive()) {
      emitDecision('deny', APPROVAL_MSG, mode);
    }

    // Check 2c: WFI approval guard (NEVER bypassed by sudo).
    WFI_APPROVAL_RE.lastIndex = 0;
    if (wfiApprovalIncreases(payload)) {
      emitDecision('deny', WFI_APPROVAL_MSG, mode);
    }
  } catch (e) {
    // Never crash; fail closed on the approval check.
    emitDecision('deny', 'SDD deterministic gate: approval guard failed closed.', mode);
    return;
  }

  // Check 3: agent-role guard.
  try {
    const toolInput = payload.tool_input || {};
    const toolName = String(payload.tool_name || '').toLowerCase();
    // Write-style tools and apply_patch.
    if (agentRoleInvalid(payload)) {
      emitDecision('deny', AGENT_ROLE_MSG, mode);
    }
    // Bash/shell tools.
    if (['bash', 'shell', 'exec_command', 'exec'].includes(toolName) && typeof toolInput.command === 'string') {
      if (shellWritesInvalidAgentRole(toolInput.command)) {
        emitDecision('deny', AGENT_ROLE_MSG, mode);
      }
    }
  } catch (e) {
    // Never crash; fail closed on the agent-role check.
    emitDecision('deny', 'SDD deterministic gate: agent-role guard failed closed.', mode);
    return;
  }

  emitDecision('allow', null, mode);
}

main();
