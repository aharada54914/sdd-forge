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
 * T-006: also guards "Domain-Model-Status: Approved" in domain/context-map.md
 * using the SAME net-increase counting logic and SAME sudo-bypass behavior as
 * the tasks.md Approval guard above (check 2b-2) -- this is a different class
 * of control than the never-sudo-bypassable WFI/Second-Approval guards.
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

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const APPROVAL_RE = /Approval:\s*Approved/g;
const SECOND_APPROVAL_RE = /Second Approval:\s*Approved/g;
const WFI_APPROVAL_RE = /Status:\s*Approved/g;
const DOMAIN_MODEL_APPROVAL_RE = /Domain-Model-Status:\s*Approved/g;
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
  "SDD決定論ゲート: エージェントは tasks.md に 'Approval: Approved' を設定できません。タスクの承認は、ファイルを直接編集する人間のみが行えます。タスクは Draft のままにし、人間に承認を依頼してください。" +
  "\n[EN] SDD deterministic gate: agents must not set 'Approval: Approved' in " +
  "tasks.md. Only a human may approve a task by editing the file directly. " +
  "Leave the task as Draft and ask the human to approve it.";

const WFI_APPROVAL_MSG =
  "SDD決定論ゲート: エージェントは docs/workflow-improvements/WFI-*.md ファイルに 'Status: Approved' を設定できません。Workflow Improvement の承認は人間のみが行え、sudo でもバイパスされません。Draft のままにし、人間に承認を依頼してください。" +
  "\n[EN] SDD deterministic gate: agents must not set 'Status: Approved' in a " +
  "docs/workflow-improvements/WFI-*.md file. Only a human may approve a " +
  "Workflow Improvement; this is never bypassed by sudo. Leave it as Draft " +
  "and ask the human to approve it.";

const SECOND_APPROVAL_MSG =
  "SDD決定論ゲート: エージェントは tasks.md に 'Second Approval: Approved' を設定できません。第二承認は（Workflow Improvement と同様に）独立した人間の判断であり、sudo でもバイパスされません。第二の人間の承認者が記録するまで残してください。" +
  "\n[EN] SDD deterministic gate: agents must not set 'Second Approval: Approved' in " +
  "tasks.md. A second approval is an independent human judgment (like a Workflow " +
  "Improvement) and is never bypassed by sudo. Leave it for a second human " +
  "approver to record.";

const DOMAIN_MODEL_APPROVAL_MSG =
  "SDD決定論ゲート: エージェントは domain/context-map.md に 'Domain-Model-Status: Approved' を設定できません。ドメインモデルの承認は、ファイルを直接編集する人間のみが行えます。ステータスは Pending/Reviewed のままにし、人間に承認を依頼してください。" +
  "\n[EN] SDD deterministic gate: agents must not set 'Domain-Model-Status: Approved' in " +
  "domain/context-map.md. Only a human may approve the domain model by editing the " +
  "file directly. Leave the status as Pending/Reviewed and ask the human to approve it.";

const SDD_SUDO_WRITE_MSG =
  "SDD決定論ゲート: エージェントは SDD_SUDO フラグファイルの作成・編集・削除を行えません。sudo モードの管理は人間のみが行えます。" +
  "\n[EN] SDD deterministic gate: agents must not create, edit, or delete the " +
  "SDD_SUDO flag file. Only a human may manage sudo mode.";

const KILL_MSG =
  "SDDキルスイッチ: プロジェクトルートに AGENT_STOP が存在します。人間がこのファイルを削除するまで、すべてのツール使用が停止されます。" +
  "\n[EN] SDD kill switch: AGENT_STOP exists at the project root. All tool use is " +
  "suspended until a human deletes the file.";

const AGENT_ROLE_MSG =
  "SDD決定論ゲート: developer_instructions の無い Codex エージェントロールファイルの書き込みを拒否しました。.codex/agents/ 配下のファイルは developer_instructions を定義する必要があり、無い場合 Codex は起動時にこれを無視します（'Ignoring malformed agent role definition'）。新規作成せず、同梱の sdd-investigator / sdd-evaluator ロールを使用してください。" +
  "\n[EN] SDD deterministic gate: refusing to write a Codex agent role file without " +
  "developer_instructions. Files under .codex/agents/ must define " +
  "developer_instructions or Codex ignores them at startup " +
  "('Ignoring malformed agent role definition'). Use the shipped " +
  "sdd-investigator/sdd-evaluator roles instead of creating new ones.";

// R-10: Enforcement-chain file protection (never bypassed by sudo).
// NOTE: Bash tool path-substring scan is best-effort — agents using python3 -c / node -e
// inline may bypass verb detection. Edit/Write/MultiEdit path is primary enforcement.

// impl-review gate: deny writing 'Impl-Review-Status: Passed' in design.md
// unless a valid integrated-verdict.json with PASS|PASS-with-warnings exists for the feature.
const IMPL_REVIEW_STATUS_PASSED_RE = /Impl-Review-Status:\s*Passed/;
const IMPL_REVIEW_STATUS_MSG =
  "SDD決定論ゲート: エージェントは impl-review-loop の PASS 判定なしに design.md に 'Impl-Review-Status: Passed' を書き込めません。impl-review-loop を実行し、integrated-verdict.json が PASS または PASS-with-warnings を返すまで待ってください。" +
  "\n[EN] SDD deterministic gate: agents must not write 'Impl-Review-Status: Passed' in " +
  "design.md without a valid integrated-verdict.json with verdict PASS or PASS-with-warnings " +
  "for the feature. Run impl-review-loop and await its verdict.";

const GATE_PROTECT_MSG =
  "SDD決定論ゲート: エージェントはゲートスクリプト・フック設定・テストファイルを書き換えられません。これらのファイルは強制チェーンの一部です。sudo でもバイパスできません。" +
  "\n[EN] SDD deterministic gate: agents must not modify gate scripts, hook " +
  "configuration, or critical test files. These are part of the enforcement chain " +
  "and cannot be bypassed by sudo.";

const PROTECTED_GATE_SUFFIXES = [
  'plugins/sdd-quality-loop/scripts/sdd-hook-guard.js',
  'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py',
  'plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1',
  'plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh',
  'plugins/sdd-quality-loop/scripts/kill-switch.js',
  'plugins/sdd-quality-loop/scripts/kill-switch.sh',
  'plugins/sdd-quality-loop/scripts/kill-switch.ps1',
  'plugins/sdd-quality-loop/hooks/claude-hooks.json',
  'plugins/sdd-quality-loop/hooks/hooks.json',
  'plugins/sdd-quality-loop/hooks/copilot-hooks.json',
  'plugins/sdd-quality-loop/scripts/check-contract.sh',
  'plugins/sdd-quality-loop/scripts/check-contract.ps1',
  'plugins/sdd-quality-loop/scripts/check-contract.py',
  'plugins/sdd-quality-loop/scripts/check-evidence-bundle.sh',
  'plugins/sdd-quality-loop/scripts/check-evidence-bundle.ps1',
  'plugins/sdd-quality-loop/scripts/check-evidence-bundle.py',
  'plugins/sdd-quality-loop/scripts/validate_path.py',
  '.claude/settings.json',
  '.claude/settings.local.json',
  'tests/gates.tests.sh',
  'tests/eval.tests.sh',
  'tests/guard-parity.tests.sh',
  'tests/constant-parity.tests.sh',
  '/.plugin/plugin.json',
  '/.claude-plugin/plugin.json',
  '/.codex-plugin/plugin.json',
  // R-10: task-review and impl-review gate files (enforcement chain)
  // R-10 NEW: sdd-review-loop gate files (T-002 Phase 1)
  'plugins/sdd-review-loop/agents/impl-reviewer-a.md',
  'plugins/sdd-review-loop/agents/impl-reviewer-b.md',
  'plugins/sdd-review-loop/agents/task-reviewer-a.md',
  'plugins/sdd-review-loop/agents/task-reviewer-b.md',
  'plugins/sdd-review-loop/skills/impl-review-loop/SKILL.md',
  'plugins/sdd-review-loop/skills/task-review-loop/SKILL.md',
  // R-10: sdd-ship orchestrator (self-protection of the second public command)
  'plugins/sdd-ship/skills/ship/SKILL.md',
];

const SHELL_COMPOUND_RE = /&&|\|\||;|\|/;

// Issue #62: write-target analysis for shell commands that mention a protected
// gate file. Verb sets and token patterns are kept identical to the Python twin
// (guard-parity.tests.sh verifies exit-code parity).
const SHELL_WRITE_ARG_CMDS = ['tee', 'touch', 'rm'];
const SHELL_WRITE_DEST_CMDS = ['cp', 'mv'];
const SHELL_PS_WRITE_CMDS = ['set-content', 'out-file', 'new-item', 'remove-item'];
const SHELL_INDIRECT_CMDS = ['eval', 'xargs', 'source', 'sh', 'bash', 'zsh', 'dash', 'ksh'];
const SHELL_UNSAFE_TOKEN_CHARS = ['$', '`', '(', ')', '{', '}', '*', '?', '[', ']'];
const SHELL_REDIRECT_TOKEN_RE = /^(?:\d*|&)(>>?)([\s\S]*)$/;
const SHELL_FD_DUP_RE = /^&(?:\d+|-)$/;
// REQ-002 (issue #110): basenames of every protected suffix. The
// working-directory-aware write-target analysis falls back to a basename match
// only when a cd/pushd transition cannot be resolved but a write verb still
// targets a protected basename — fail closed.
const PROTECTED_BASENAMES = new Set(
  PROTECTED_GATE_SUFFIXES.map(s => {
    const parts = s.toLowerCase().replace(/\\/g, '/').split('/');
    return parts[parts.length - 1];
  })
);
// REQ-002: shell verbs that change the working directory across segments.
const SHELL_CD_CMDS = ['cd', 'pushd'];

function isProtectedGateFile(filePath) {
  if (!filePath) return false;
  // posix.normalize collapses .. segments so ../../tests/gates.tests.sh is caught.
  const normalized = path.posix.normalize(String(filePath).replace(/\\/g, '/')).toLowerCase();
  return PROTECTED_GATE_SUFFIXES.some(s => {
    const sl = s.toLowerCase();
    // Match absolute paths and relative paths for suffixes that start with /.
    return normalized.endsWith(sl) || (sl.startsWith('/') && normalized.endsWith(sl.slice(1)));
  });
}

function tokenizeShellCommand(cmd) {
  // Issue #62: simple shell tokenizer (same algorithm as the Python twin).
  // Splits on unquoted spaces/tabs; ';', '|', '&' and newlines become separator
  // tokens; single/double quotes group text (quote marks removed); '>&'/'&>'
  // stay attached to their redirect token. Returns an array of [kind, text]
  // pairs with kind 'word' or 'sep', or null when the command uses constructs
  // the tokenizer does not model (backslash escapes, unclosed quotes) —
  // callers must fail closed on null.
  const tokens = [];
  let cur = '';
  let pending = false;
  let inSingle = false;
  let inDouble = false;
  const n = cmd.length;
  for (let i = 0; i < n; i++) {
    const ch = cmd[i];
    if (inSingle) {
      if (ch === "'") inSingle = false;
      else cur += ch;
      continue;
    }
    if (inDouble) {
      if (ch === '"') inDouble = false;
      else if (ch === '\\') return null;
      else cur += ch;
      continue;
    }
    if (ch === "'") {
      inSingle = true;
      pending = true;
    } else if (ch === '"') {
      inDouble = true;
      pending = true;
    } else if (ch === '\\') {
      return null;
    } else if (ch === '\n' || ch === '\r' || ch === ';' || ch === '|') {
      if (pending) {
        tokens.push(['word', cur]);
        cur = '';
        pending = false;
      }
      tokens.push(['sep', ch]);
    } else if (ch === '&') {
      if (pending && cur.endsWith('>')) {
        // 2>&1-style fd duplication stays inside the redirect token.
        cur += ch;
      } else if (i + 1 < n && cmd[i + 1] === '>') {
        // &>-style redirect starts a new token.
        if (pending) tokens.push(['word', cur]);
        cur = '&';
        pending = true;
      } else {
        if (pending) {
          tokens.push(['word', cur]);
          cur = '';
        }
        pending = false;
        tokens.push(['sep', ch]);
      }
    } else if (ch === ' ' || ch === '\t') {
      if (pending) {
        tokens.push(['word', cur]);
        cur = '';
        pending = false;
      }
    } else {
      cur += ch;
      pending = true;
    }
  }
  if (inSingle || inDouble) return null;
  if (pending) tokens.push(['word', cur]);
  return tokens;
}

function shellTokenBasename(tok) {
  // Issue #62: lowercased final path component of a token (verb matching).
  const t = tok.toLowerCase().replace(/\\/g, '/');
  const idx = t.lastIndexOf('/');
  return idx === -1 ? t : t.slice(idx + 1);
}

function simpleShellCommandIsSafe(words) {
  // Issue #62: check one separator-free simple command. Returns false when a
  // redirect or write verb in it targets (or may target) a protected gate file.
  const plain = [];
  const n = words.length;
  let k = 0;
  while (k < n) {
    const w = words[k];
    if (w.includes('>')) {
      const m = w.match(SHELL_REDIRECT_TOKEN_RE);
      if (!m) return false;
      const rest = m[2];
      if (rest === '') {
        // Detached target (`> file`): consume and check the next token.
        k += 1;
        if (k >= n || words[k].includes('>')) return false;
        if (isProtectedGateFile(words[k])) return false;
      } else if (rest.startsWith('&')) {
        // fd duplication (2>&1, >&2, >&-) is harmless; anything else
        // (e.g. >&file) is not modeled — fail closed.
        if (!SHELL_FD_DUP_RE.test(rest)) return false;
      } else {
        if (isProtectedGateFile(rest)) return false;
      }
    } else {
      plain.push(w);
    }
    k += 1;
  }
  let writeAt = -1;
  let writeBase = '';
  for (let idx = 0; idx < plain.length; idx++) {
    const base = shellTokenBasename(plain[idx]);
    if (SHELL_WRITE_ARG_CMDS.includes(base) || SHELL_WRITE_DEST_CMDS.includes(base)) {
      writeAt = idx;
      writeBase = base;
      break;
    }
  }
  if (writeAt < 0) return true;
  const args = plain.slice(writeAt + 1);
  const nonFlags = args.filter(a => !a.startsWith('-'));
  if (SHELL_WRITE_DEST_CMDS.includes(writeBase)) {
    // cp/mv: only the final non-flag argument (the destination) is
    // written; sources are reads. Fewer than two path arguments cannot
    // be judged — fail closed.
    if (nonFlags.length < 2) return false;
    return !isProtectedGateFile(nonFlags[nonFlags.length - 1]);
  }
  // tee/touch/rm: every non-flag argument is written (or deleted).
  for (const a of nonFlags) {
    if (isProtectedGateFile(a)) return false;
  }
  return true;
}

function shellWriteTargetsAreSafe(cmd) {
  // Issue #62: true only when every write verb/redirect in cmd provably
  // targets a non-protected path. Constructs the analysis cannot model
  // (escapes, expansions, globs, subshells, eval/xargs/shell interpreters,
  // PowerShell write verbs) return false (fail-close).
  const tokens = tokenizeShellCommand(cmd);
  if (tokens === null) return false;
  const commands = [];
  let words = [];
  for (const [kind, text] of tokens) {
    if (kind === 'sep') {
      if (words.length > 0) {
        commands.push(words);
        words = [];
      }
    } else {
      words.push(text);
    }
  }
  if (words.length > 0) commands.push(words);
  for (const command of commands) {
    for (const w of command) {
      if (SHELL_UNSAFE_TOKEN_CHARS.some(c => w.includes(c))) return false;
      const base = shellTokenBasename(w);
      if (SHELL_INDIRECT_CMDS.includes(base) || SHELL_PS_WRITE_CMDS.includes(base)) return false;
    }
    if (!simpleShellCommandIsSafe(command)) return false;
  }
  return true;
}

function normDir(p) {
  // REQ-002: normalize a tracked directory (forward slashes, collapse ..).
  return path.posix.normalize(p.replace(/\\/g, '/'));
}

function applyCdTransition(currentDir, cwdKnown, words) {
  // REQ-002: update the tracked working directory for a cd/pushd segment.
  // Unresolvable transitions taint the state (cwdKnown=false): bare cd (home),
  // `cd -`, a `~` argument, or an argument with shell metacharacters. An
  // absolute argument re-anchors even from a tainted state.
  const args = words.slice(1).filter(w => !w.startsWith('-'));
  if (args.length === 0) return [currentDir, false];
  const arg = args[0];
  if (arg.startsWith('~') || SHELL_UNSAFE_TOKEN_CHARS.some(c => arg.includes(c))) {
    return [currentDir, false];
  }
  if (arg.startsWith('/')) return [normDir(arg), true];
  if (!cwdKnown) return [currentDir, false];
  const joined = currentDir ? currentDir + '/' + arg : arg;
  return [normDir(joined), true];
}

function cwdWriteTargetIsProtected(currentDir, cwdKnown, target) {
  // REQ-002: true when a write target resolves to a protected gate file.
  // Absolute targets resolve directly; relative targets resolve against the
  // tracked directory when known, else fail closed on a protected basename.
  // Targets carrying shell metacharacters are left to the substring/issue-#62
  // analysis (return false here).
  if (SHELL_UNSAFE_TOKEN_CHARS.some(c => target.includes(c))) return false;
  if (target.startsWith('/')) return isProtectedGateFile(target);
  if (cwdKnown) {
    const resolved = currentDir ? currentDir + '/' + target : target;
    return isProtectedGateFile(resolved);
  }
  return PROTECTED_BASENAMES.has(shellTokenBasename(target));
}

function segmentWriteHitsProtected(words, currentDir, cwdKnown) {
  // REQ-002: true when a write verb/redirect in one simple command targets a
  // protected gate file, resolved against the tracked working directory.
  // Mirrors the read/write argument semantics of simpleShellCommandIsSafe.
  const plain = [];
  let k = 0;
  const n = words.length;
  while (k < n) {
    const w = words[k];
    if (w.includes('>')) {
      const m = w.match(SHELL_REDIRECT_TOKEN_RE);
      if (!m) { k += 1; continue; }
      const rest = m[2];
      if (rest === '') {
        k += 1;
        if (k < n && !words[k].includes('>')) {
          if (cwdWriteTargetIsProtected(currentDir, cwdKnown, words[k])) return true;
        }
      } else if (!rest.startsWith('&')) {
        if (cwdWriteTargetIsProtected(currentDir, cwdKnown, rest)) return true;
      }
    } else {
      plain.push(w);
    }
    k += 1;
  }
  let writeAt = -1;
  let writeBase = '';
  for (let idx = 0; idx < plain.length; idx++) {
    const base = shellTokenBasename(plain[idx]);
    if (SHELL_WRITE_ARG_CMDS.includes(base) || SHELL_WRITE_DEST_CMDS.includes(base)) {
      writeAt = idx;
      writeBase = base;
      break;
    }
  }
  if (writeAt < 0) return false;
  const nonFlags = plain.slice(writeAt + 1).filter(a => !a.startsWith('-'));
  if (SHELL_WRITE_DEST_CMDS.includes(writeBase)) {
    if (nonFlags.length > 0) {
      return cwdWriteTargetIsProtected(currentDir, cwdKnown, nonFlags[nonFlags.length - 1]);
    }
    return false;
  }
  for (const a of nonFlags) {
    if (cwdWriteTargetIsProtected(currentDir, cwdKnown, a)) return true;
  }
  return false;
}

function shellCwdWriteHitsProtected(cmd) {
  // REQ-002 (issue #110): Working-directory-aware R-10 detection. Tracks
  // cd/pushd transitions across compound-command segments (&&, ||, ;, |) and
  // denies when a write verb or redirect resolves to a protected gate file —
  // closing the `cd <protected-dir> && rm <basename>` bypass of the substring
  // scan. A read-only segment (no write verb/redirect) never produces a hit, so
  // the read-only short-circuit is preserved. Unparseable commands (tokenizer
  // returns null) yield no hit here; the substring + issue-#62 analysis retains
  // its fail-closed behavior for those.
  const tokens = tokenizeShellCommand(cmd);
  if (tokens === null) return false;
  const segments = [];
  let words = [];
  for (const [kind, text] of tokens) {
    if (kind === 'sep') {
      if (words.length > 0) { segments.push(words); words = []; }
    } else {
      words.push(text);
    }
  }
  if (words.length > 0) segments.push(words);
  let currentDir = '';
  let cwdKnown = true;
  for (const seg of segments) {
    if (seg.length === 0) continue;
    const verb = shellTokenBasename(seg[0]);
    if (SHELL_CD_CMDS.includes(verb)) {
      [currentDir, cwdKnown] = applyCdTransition(currentDir, cwdKnown, seg);
      continue;
    }
    if (verb === 'popd') { cwdKnown = false; continue; }
    if (segmentWriteHitsProtected(seg, currentDir, cwdKnown)) return true;
  }
  return false;
}

function shellTargetsProtectedGateFile(cmd) {
  // R-10: Deny shell commands that WRITE to protected gate files.
  // Substring scan (path appears literally in command) combined with
  // write-target analysis (issue #62): a write verb/redirect elsewhere in the
  // command no longer denies read-only access to a protected path.
  // REQ-002 (issue #110): a working-directory-aware pass additionally resolves
  // write targets across cd/pushd transitions, so `cd <protected-dir> && rm
  // <basename>` (and pushd equivalents) can no longer escape the comparison.
  if (typeof cmd !== 'string') return false;
  // REQ-002: cd/pushd-aware resolution catches protected writes that never
  // spell the full protected path literally. Read-only segments never hit,
  // so this is checked before the read-only short-circuit below.
  if (shellCwdWriteHitsProtected(cmd)) return true;
  const cmdLower = cmd.toLowerCase();
  const hasProtectedPath = PROTECTED_GATE_SUFFIXES.some(s => {
    const sl = s.toLowerCase();
    // Also match relative forms of suffixes that begin with / (e.g. .plugin/plugin.json).
    return cmdLower.includes(sl) || (sl.startsWith('/') && cmdLower.includes(sl.slice(1)));
  });
  if (!hasProtectedPath) return false;
  // Read-only short-circuit only when: no compound ops AND read-only verb AND no write verb/redirect.
  // Prevents `cat f && rm f` (compound) and `cat > f << EOF` (write verb despite read-only start).
  const hasWrite = SHELL_SUDO_WRITE_RE.test(cmd);
  if (!SHELL_COMPOUND_RE.test(cmd) && SHELL_SUDO_READ_ONLY_RE.test(cmd) && !hasWrite) return false;
  if (!hasWrite) return false;
  // Issue #62: deny only when a write target is (or cannot be proven not to
  // be) a protected gate file — fail-close on anything unmodeled.
  return !shellWriteTargetsAreSafe(cmd);
}

function countApprovals(text) {
  if (!text) return 0;
  // Subtract second approvals from primary count to avoid over-counting
  // (since "Second Approval: Approved" contains "Approval: Approved" as a substring)
  const approvalMatches = text.match(APPROVAL_RE);
  const secondMatches = text.match(SECOND_APPROVAL_RE);
  const approvalCount = approvalMatches ? approvalMatches.length : 0;
  const secondCount = secondMatches ? secondMatches.length : 0;
  return approvalCount - secondCount;
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

function isDomainContextMapPath(filePath) {
  // domain/context-map.md is the sdd-domain plugin's approval-line file.
  // Case-insensitive match (matches isTasksMd/isWfiPath convention).
  if (!filePath) return false;
  return String(filePath).replace(/\\/g, '/').toLowerCase().endsWith('domain/context-map.md');
}

function domainModelCount(text) {
  if (!text) return 0;
  const matches = text.match(DOMAIN_MODEL_APPROVAL_RE);
  return matches ? matches.length : 0;
}

function countSecondApprovals(text) {
  if (!text) return 0;
  const matches = text.match(SECOND_APPROVAL_RE);
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

function parseSudoFields(content) {
  // Parse key: value lines into a plain object (values stripped).
  const fields = {};
  for (const rawLine of content.split('\n')) {
    const line = rawLine.replace(/\r$/, '');
    const colonIdx = line.indexOf(':');
    if (colonIdx !== -1) {
      const key = line.slice(0, colonIdx).trim();
      const val = line.slice(colonIdx + 1).trim();
      fields[key] = val;
    }
  }
  return fields;
}

function resolveSudoKey() {
  // C-04: Resolve signing key per priority order. Returns Buffer or null.
  // 1. env SDD_SUDO_KEY
  const envKey = process.env.SDD_SUDO_KEY;
  if (envKey) {
    return Buffer.from(envKey, 'utf8');
  }
  // 2. env SDD_SUDO_KEY_FILE
  const envKeyFile = process.env.SDD_SUDO_KEY_FILE;
  if (envKeyFile) {
    try {
      const raw = fs.readFileSync(envKeyFile);
      const stripped = Buffer.from(raw.toString('utf8').replace(/^\uFEFF/, '').replace(/[\s\r\n]+$/, ''), 'utf8');
      if (stripped.length > 0) return stripped;
    } catch (e) { /* fall through */ }
    return null;
  }
  // 3. <HOME>/.sdd/sudo-key
  const home = process.env.HOME || process.env.USERPROFILE || '';
  if (home) {
    const keyPath = path.join(home, '.sdd', 'sudo-key');
    try {
      const raw = fs.readFileSync(keyPath);
      const stripped = Buffer.from(raw.toString('utf8').replace(/^\uFEFF/, '').replace(/[\s\r\n]+$/, ''), 'utf8');
      if (stripped.length > 0) return stripped;
    } catch (e) { /* fall through */ }
  }
  // 4. No key
  return null;
}

function sudoCanonical(fields) {
  // Canonical string to sign/verify: 5 values joined by LF (no trailing newline).
  const issuer = fields['issuer'] || '';
  const nonce = fields['nonce'] || '';
  const repo = fields['repo'] || '';
  const issuedStr = String(parseInt(fields['issued-epoch'] || '0', 10));
  const expiresStr = String(parseInt(fields['expires-epoch'] || '0', 10));
  return [issuer, nonce, repo, issuedStr, expiresStr].join('\n');
}

function sudoActive() {
  // C-02/C-04/C-08: True if valid, signed, unexpired SDD_SUDO flag at project root.
  // Validates: not a symlink, required fields present, nonce format, epoch ranges,
  // repo-binding, and HMAC-SHA256 signature.
  const proj = resolveProjectRoot();
  const sudoRoot = proj.sudoRoot;
  try {
    const flag = path.join(sudoRoot, SDD_SUDO_NAME);
    // R-11: Use O_NOFOLLOW to close lstat→open symlink-swap race at kernel level.
    // O_NOFOLLOW is present on Linux/macOS; falls back to 0 (no-op) on Windows.
    // On POSIX, if SDD_SUDO is a symlink, openSync throws ELOOP → caught below → false.
    // O_NONBLOCK prevents blocking on FIFOs masquerading as the flag file.
    let content;
    try {
      const oNoFollow = fs.constants.O_NOFOLLOW || 0;
      const oNonBlock = fs.constants.O_NONBLOCK || 0;
      if (oNoFollow === 0) {
        // Windows: no O_NOFOLLOW — use lstatSync to reject symlinks before open.
        try {
          const lst = fs.lstatSync(flag);
          if (lst.isSymbolicLink()) { return false; }
        } catch (e) {
          return false;
        }
      }
      const fd = fs.openSync(flag, fs.constants.O_RDONLY | oNoFollow | oNonBlock);
      try {
        const stat = fs.fstatSync(fd);
        if (!stat.isFile()) { fs.closeSync(fd); return false; }
        const buf = Buffer.alloc(stat.size || 65536);
        const bytesRead = fs.readSync(fd, buf, 0, buf.length, 0);
        content = buf.slice(0, bytesRead).toString('utf8');
      } finally {
        try { fs.closeSync(fd); } catch (_) { /* already closed */ }
      }
    } catch (e) {
      return false;
    }
    const fields = parseSudoFields(content);

    // Required fields
    for (const req of ['issuer', 'nonce', 'repo', 'issued-epoch', 'expires-epoch', 'sig']) {
      if (!fields[req]) return false;
    }

    // Nonce format: >= 32 hex chars
    if (!/^[0-9a-fA-F]{32,}$/.test(fields['nonce'])) {
      return false;
    }

    const expires = parseInt(fields['expires-epoch'], 10);
    const issued = parseInt(fields['issued-epoch'], 10);
    if (isNaN(expires) || isNaN(issued)) return false;

    const now = Math.floor(Date.now() / 1000);
    // C-02: issued-epoch <= now < expires-epoch AND TTL <= 86400
    if (issued > now) return false;
    if (expires <= now) return false;
    if (expires - issued > 86400) return false;

    // Repo-binding: compare the canonical realpath on BOTH sides so that
    // symlinked representations of the same directory (e.g. macOS /var vs
    // /private/var) compare equal. A token whose repo does not resolve to this
    // directory is rejected (fail-closed, blocks cross-repo replay).
    let actualRepo, storedRepo;
    try {
      actualRepo = fs.realpathSync(sudoRoot);
    } catch (e) {
      try {
        actualRepo = path.resolve(sudoRoot);
      } catch (e2) {
        return false;
      }
    }
    try {
      storedRepo = fs.realpathSync(fields['repo']);
    } catch (e) {
      storedRepo = fields['repo'];
    }
    if (storedRepo !== actualRepo) return false;

    // Key resolution and HMAC verification
    const keyBuf = resolveSudoKey();
    if (!keyBuf) return false;

    const canonical = sudoCanonical(fields);
    const expectedMac = crypto.createHmac('sha256', keyBuf).update(canonical, 'utf8').digest('hex');
    const sigField = (fields['sig'] || '').toLowerCase();

    // Constant-time comparison: guard against length mismatch
    if (expectedMac.length !== sigField.length) return false;
    const expectedBuf = Buffer.from(expectedMac, 'utf8');
    const sigBuf = Buffer.from(sigField, 'utf8');
    if (!crypto.timingSafeEqual(expectedBuf, sigBuf)) return false;

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

// T-006: domain-model approval guard. Mirrors the tasks.md Approval guard's
// net-increase counting logic EXACTLY (same sudo-bypass behavior) -- this is
// NOT the never-sudo-bypassable WFI-guard pattern. A valid SDD_SUDO token
// permits the write, exactly like the tasks.md guard (see main()'s Check 2b
// vs Check 2c for the bypass distinction).
function domainModelApprovalIncreases(payload) {
  const toolInput = payload.tool_input || {};
  const toolName = String(payload.tool_name || '').toLowerCase();
  const command = toolInput.command;

  if (toolName === 'apply_patch' || looksLikePatch(command)) {
    return domainModelPatchIncreases(command || '');
  }

  if (['bash', 'shell', 'exec_command', 'exec'].includes(toolName) && typeof command === 'string') {
    if (command.toLowerCase().includes('domain/context-map.md') && domainModelCount(command) > 0) {
      return true;
    }
    return false;
  }

  const filePath = toolInput.file_path || '';
  if (!isDomainContextMapPath(filePath)) return false;

  if (Array.isArray(toolInput.edits)) {
    for (const edit of toolInput.edits) {
      const e = edit || {};
      if (domainModelCount(e.new_string) > 0) {
        return true;
      }
    }
    return false;
  } else if ('new_string' in toolInput) {
    return domainModelCount(toolInput.new_string) > 0;
  } else if ('content' in toolInput) {
    return domainModelWriteContentIncreases(filePath, toolInput.content || '');
  } else {
    return false;
  }
}

function domainModelWriteContentIncreases(filePath, newContent) {
  let oldContent = '';
  try {
    oldContent = fs.readFileSync(filePath, 'utf8');
  } catch (e) {
    oldContent = '';
  }
  return domainModelCount(newContent) > domainModelCount(oldContent);
}

function domainModelPatchIncreases(patch) {
  let currentIsDomainContextMap = false;
  let added = 0;
  let removed = 0;
  for (const raw of patch.split('\n')) {
    const line = raw.replace(/\r$/, '');
    const m = line.match(/^\*\*\* (Update|Add|Delete) File: (.+)$/);
    if (m) {
      currentIsDomainContextMap = isDomainContextMapPath(m[2].trim());
      continue;
    }
    if (line.startsWith('*** End Patch') || line.startsWith('*** Begin Patch')) {
      continue;
    }
    if (!currentIsDomainContextMap) continue;
    if (line.startsWith('+') && !line.startsWith('+++')) {
      added += domainModelCount(line.slice(1));
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      removed += domainModelCount(line.slice(1));
    }
  }
  return (added - removed) > 0;
}

function secondApprovalIncreases(payload) {
  // Second Approval is human-only and NEVER bypassed by sudo. Mirrors the tasks.md
  // approval guard but keyed on 'Second Approval: Approved' and scoped to tasks.md.
  const toolInput = payload.tool_input || {};
  const toolName = String(payload.tool_name || '').toLowerCase();
  const command = toolInput.command;

  if (toolName === 'apply_patch' || looksLikePatch(command)) {
    return secondApprovalPatchIncreases(command || '');
  }

  if (['bash', 'shell', 'exec_command', 'exec'].includes(toolName) && typeof command === 'string') {
    if (command.toLowerCase().includes('tasks.md') && command.match(SECOND_APPROVAL_RE)) {
      return true;
    }
    return false;
  }

  const filePath = toolInput.file_path || '';
  if (!isTasksMd(filePath)) return false;

  if (Array.isArray(toolInput.edits)) {
    for (const edit of toolInput.edits) {
      const e = edit || {};
      if (countSecondApprovals(e.new_string) > 0) {
        return true;
      }
    }
    return false;
  } else if ('new_string' in toolInput) {
    return countSecondApprovals(toolInput.new_string) > 0;
  } else if ('content' in toolInput) {
    return secondApprovalWriteContentIncreases(filePath, toolInput.content || '');
  } else {
    return false;
  }
}

function secondApprovalWriteContentIncreases(filePath, newContent) {
  let oldContent = '';
  try {
    oldContent = fs.readFileSync(filePath, 'utf8');
  } catch (e) {
    oldContent = '';
  }
  return countSecondApprovals(newContent) > countSecondApprovals(oldContent);
}

function secondApprovalPatchIncreases(patch) {
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
      added += countSecondApprovals(line.slice(1));
    } else if (line.startsWith('-') && !line.startsWith('---')) {
      removed += countSecondApprovals(line.slice(1));
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

function isDesignMd(filePath) {
  // Match files named design.md (case-insensitive).
  if (!filePath) return false;
  return String(filePath).replace(/\\/g, '/').toLowerCase().endsWith('design.md');
}

function implReviewVerdictExists(filePath) {
  // Check whether a valid integrated-verdict.json with PASS or PASS-with-warnings
  // exists in reports/impl-review/<feature>/. Extract feature from the design.md path.
  // Path pattern: specs/<feature>/design.md
  if (!filePath) return false;
  const normalized = String(filePath).replace(/\\/g, '/');
  const specsMatch = normalized.match(/specs\/([^/]+)\/design\.md$/i);
  if (!specsMatch) return false;
  const feature = specsMatch[1];

  // Look for any integrated-verdict.json in reports/impl-review/<feature>/
  const reportsBase = 'reports/impl-review/' + feature;
  try {
    // Walk attempt dirs
    const attemptDirs = fs.readdirSync(reportsBase).filter(d => d.startsWith('attempt-'));
    for (const attemptDir of attemptDirs) {
      const roundBase = path.join(reportsBase, attemptDir);
      const roundDirs = fs.readdirSync(roundBase).filter(d => d.startsWith('round-'));
      for (const roundDir of roundDirs) {
        const verdictPath = path.join(roundBase, roundDir, 'integrated-verdict.json');
        try {
          const content = fs.readFileSync(verdictPath, 'utf8');
          const verdict = JSON.parse(content);
          if (verdict.verdict === 'PASS' || verdict.verdict === 'PASS-with-warnings') {
            return true;
          }
        } catch (e) {
          // continue
        }
      }
    }
  } catch (e) {
    // reports dir doesn't exist or can't be read
  }
  return false;
}

function implReviewStatusPassedIncreases(payload) {
  // Deny writing 'Impl-Review-Status: Passed' in design.md unless a valid
  // integrated-verdict.json with PASS|PASS-with-warnings exists for the feature.
  const toolInput = payload.tool_input || {};
  const toolName = String(payload.tool_name || '').toLowerCase();
  const filePath = toolInput.file_path || '';

  if (!TARGETED_FILE_TOOLS.has(toolName)) return false;
  if (!isDesignMd(filePath)) return false;

  // Determine what new content will contain
  let newContent = '';
  if (Array.isArray(toolInput.edits)) {
    for (const edit of toolInput.edits) {
      const e = edit || {};
      if (IMPL_REVIEW_STATUS_PASSED_RE.test(e.new_string || '')) {
        newContent = e.new_string || '';
        break;
      }
    }
  } else if ('new_string' in toolInput) {
    newContent = toolInput.new_string || '';
  } else if ('content' in toolInput) {
    newContent = toolInput.content || '';
  }

  if (!IMPL_REVIEW_STATUS_PASSED_RE.test(newContent)) return false;

  // Check if old content already had Impl-Review-Status: Passed
  let oldContent = '';
  try {
    oldContent = fs.readFileSync(filePath, 'utf8');
  } catch (e) {
    oldContent = '';
  }
  if (IMPL_REVIEW_STATUS_PASSED_RE.test(oldContent)) return false; // already set; not a new introduction

  // New introduction of Impl-Review-Status: Passed — require verdict file
  return !implReviewVerdictExists(filePath);
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
    emitDecision('deny', 'SDD決定論ゲート: フックのペイロードが不正です。\n[EN] SDD deterministic gate: malformed hook payload.', mode);
    return;
  }

  try {
    if (typeof payload.tool_name !== 'string' || typeof payload.tool_input !== 'object' || payload.tool_input === null || Array.isArray(payload.tool_input)) {
      emitDecision('deny', 'SDD決定論ゲート: フックのペイロードが不正です。\n[EN] SDD deterministic gate: malformed hook payload.', mode);
      return;
    }
    if (payloadIsMalformed(payload)) {
      emitDecision('deny', 'SDD決定論ゲート: フックのペイロードが不正です。\n[EN] SDD deterministic gate: malformed hook payload.', mode);
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

    // Check 2a-R10: Enforcement-chain file protection (never bypassed by sudo).
    if (['edit', 'write', 'multiedit'].includes(toolName)) {
      if (isProtectedGateFile(toolInput.file_path || '')) {
        emitDecision('deny', GATE_PROTECT_MSG, mode);
        return;
      }
    }

    if (['bash', 'shell', 'exec_command', 'exec'].includes(toolName) && typeof toolInput.command === 'string') {
      if (shellTargetsProtectedGateFile(toolInput.command)) {
        emitDecision('deny', GATE_PROTECT_MSG, mode);
        return;
      }
    }

    if (toolName === 'apply_patch' || looksLikePatch(toolInput.command)) {
      const patch = toolInput.command || '';
      const fileRegex2 = /^\*\*\* (Update|Add|Delete) File: (.+)$/gm;
      let fileMatch2;
      while ((fileMatch2 = fileRegex2.exec(patch))) {
        if (isProtectedGateFile(fileMatch2[2].trim())) {
          emitDecision('deny', GATE_PROTECT_MSG, mode);
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

    // Check 2b-2: Domain-model approval guard (bypassed by valid sudo, same
    // class as the tasks.md Approval guard above -- NOT the never-bypassable
    // WFI/Second-Approval pattern below).
    DOMAIN_MODEL_APPROVAL_RE.lastIndex = 0;
    if (domainModelApprovalIncreases(payload) && !sudoActive()) {
      emitDecision('deny', DOMAIN_MODEL_APPROVAL_MSG, mode);
    }

    // Check 2c: WFI approval guard (NEVER bypassed by sudo).
    WFI_APPROVAL_RE.lastIndex = 0;
    if (wfiApprovalIncreases(payload)) {
      emitDecision('deny', WFI_APPROVAL_MSG, mode);
    }

    // Check 2d: Second Approval guard (NEVER bypassed by sudo).
    SECOND_APPROVAL_RE.lastIndex = 0;
    if (secondApprovalIncreases(payload)) {
      emitDecision('deny', SECOND_APPROVAL_MSG, mode);
    }

    // Check 2e: Impl-Review-Status: Passed guard (NEVER bypassed by sudo).
    // Deny writing 'Impl-Review-Status: Passed' in design.md without a valid
    // integrated-verdict.json with PASS|PASS-with-warnings for the feature.
    IMPL_REVIEW_STATUS_PASSED_RE.lastIndex = 0;
    if (implReviewStatusPassedIncreases(payload)) {
      emitDecision('deny', IMPL_REVIEW_STATUS_MSG, mode);
    }
  } catch (e) {
    // Never crash; fail closed on the approval check.
    emitDecision('deny', 'SDD決定論ゲート: 承認ガードがフェイルクローズしました。\n[EN] SDD deterministic gate: approval guard failed closed.', mode);
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
    emitDecision('deny', 'SDD決定論ゲート: エージェントロールガードがフェイルクローズしました。\n[EN] SDD deterministic gate: agent-role guard failed closed.', mode);
    return;
  }

  emitDecision('allow', null, mode);
}

main();
