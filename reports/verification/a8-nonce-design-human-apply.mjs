// Human-only --apply. Agents may run --check only; never use this to bypass a refusal.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

const root = '/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge';
const head = '495c88d67af44530687ecea3ce9fb0a90a336539';
const patch = 'reports/verification/a8-nonce-design-revision-20261005.patch';
const adrInput = 'reports/verification/a8-nonce-adr0035-candidate-20261005.md';
const adrTarget = 'docs/adr/0035-a8-two-contribution-handoff-oracle.md';
const patchHash = '51283f7c22548b55a55b3e930e4670b6d03faf9d0e835f73c067cb48aeb35a45';
const adrHash = '50cf6c313940ccfa182cc8632d59215430183957e6e0ea02d6d064c934109923';
const targets = [
  ['specs/epic-196-a8-integration/design.md', '14862a80a6f44b49dbf7e1393af66c82c0434bf1109b248e7ff9b4b695fcd18c', '6485d5585fd37fe9ce298b295168ad2304d6dec6a1c7dc768bf76bbebf8c1aa3'],
  ['specs/epic-196-a8-integration/tasks.md', '8c17b0f6b2fa299d23ce6e892a8e80a841ac4ab68d613c84d6c36fe09bbcde66', '44b3658c28a1e216239b46a5bd80e58776099e1a4efd7e9e77b0728118634f6b'],
  ['docs/adr/README.md', '56d9d0197f1978f27724f506631b7a3f16d334bd2bee09adda594ad9264dd07f', '0d99d8f8215cbca6e7d92d218fec1e3a62364d5b581c90f891fec5d322018786'],
];
const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const run = args => execFileSync('rtk', ['proxy', ...args], {cwd: root, encoding: 'utf8'});
const requireTrue = (condition, message) => { if (!condition) throw Error(message); };
function readRegular(relative) {
  const p = path.join(root, relative);
  requireTrue(fs.lstatSync(p).isFile() && fs.realpathSync(p) === p, 'Noncanonical regular file: ' + relative);
  return fs.readFileSync(p);
}
function requireAbsent() {
  requireTrue(fs.realpathSync(path.join(root, 'docs/adr')) === path.join(root, 'docs/adr'), 'Noncanonical ADR directory');
  requireTrue(!fs.readdirSync(path.join(root, 'docs/adr')).some(n => /^0035(?:-|\.)/.test(n)), 'ADR 0035 namespace is occupied locally');
  try { fs.lstatSync(path.join(root, adrTarget)); throw Error('ADR target already exists'); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
}
function verifyBases() {
  requireTrue(fs.realpathSync(root) === root && fs.realpathSync(process.cwd()) === root, 'Run from the pinned owner checkout');
  requireTrue(run(['git', 'rev-parse', '--show-toplevel']).trim() === root, 'Git root mismatch');
  requireTrue(run(['git', 'rev-parse', 'HEAD']).trim() === head, 'HEAD changed; obtain a reviewed new package');
  requireTrue(digest(readRegular(patch)) === patchHash, 'Patch hash mismatch');
  requireTrue(digest(readRegular(adrInput)) === adrHash, 'ADR candidate hash mismatch');
  for (const [p, before] of targets) requireTrue(digest(readRegular(p)) === before, 'Before hash mismatch: ' + p);
  requireAbsent();
}
function verifyCandidateResults() {
  const sections = readRegular(patch).toString('utf8').split('diff --git ').slice(1);
  requireTrue(sections.length === targets.length, 'Wrong target count');
  for (let i = 0; i < sections.length; i++) {
    const [p, , expected] = targets[i];
    const section = sections[i];
    requireTrue(section.startsWith(`a/${p} b/${p}\n--- a/${p}\n+++ b/${p}\n`), 'Unexpected patch target/header');
    let text = readRegular(p).toString('utf8');
    const edits = [];
    for (const hunk of section.split('@@ -').slice(1)) {
      const newline = hunk.indexOf('\n');
      const match = hunk.slice(0, newline).match(/^(\d+),(\d+) \+(\d+),(\d+) @@$/);
      requireTrue(match, 'Invalid hunk header');
      const lines = hunk.slice(newline + 1).match(/[^\n]*\n/g) || [];
      requireTrue(lines.every(line => /^[ +\-]/.test(line)), 'Unsupported hunk content');
      const oldLines = lines.filter(line => /^[ -]/.test(line)).map(line => line.slice(1));
      const newLines = lines.filter(line => /^[ +]/.test(line)).map(line => line.slice(1));
      requireTrue(oldLines.length === Number(match[2]) && newLines.length === Number(match[4]), 'Hunk count mismatch');
      const oldText = oldLines.join('');
      const start = text.indexOf(oldText);
      requireTrue(oldText.length > 0 && start >= 0 && text.indexOf(oldText, start + 1) < 0, 'Old span must match exactly once');
      edits.push({start, oldText, replacement: newLines.join('')});
    }
    for (const e of edits.sort((a, b) => b.start - a.start)) text = text.slice(0, e.start) + e.replacement + text.slice(e.start + e.oldText.length);
    requireTrue(digest(Buffer.from(text)) === expected, 'Candidate after hash mismatch: ' + p);
    console.log('CHECKED ' + p + ' -> ' + expected);
  }
}

let backup;
try {
  requireTrue(process.argv.length === 3 && ['--check', '--apply'].includes(process.argv[2]), 'Usage: node reports/verification/a8-nonce-design-human-apply.mjs --check|--apply');
  verifyBases();
  const history = run(['git', 'log', '--all', '--format=', '--name-only', '--', 'docs/adr']);
  requireTrue(!/^docs\/adr\/0035(?:-|\.)/m.test(history), 'ADR 0035 exists in local shared refs; stop');
  verifyCandidateResults();
  run(['git', 'apply', '--check', '--unidiff-zero', patch]);
  console.log('CHECKED ' + adrTarget + ' ABSENT -> ' + adrHash);
  if (process.argv[2] === '--check') {
    console.log('CHECK ONLY: 4 design targets; no write, backup, candidate execution, review or approval change. Remote refs and other worktree proposals are not refreshed by this helper.');
    process.exit(0);
  }
  // --apply is an explicit human operation after authority/namespace verification.
  backup = fs.mkdtempSync(path.join(os.tmpdir(), 'a8-nonce-design-backup-'));
  console.log('BACKUP=' + backup);
  const saved = [...targets.map(([p, hash]) => [p, hash]), [patch, patchHash], [adrInput, adrHash]];
  for (const [p, hash] of saved) {
    const dst = path.join(backup, p);
    fs.mkdirSync(path.dirname(dst), {recursive: true});
    fs.copyFileSync(path.join(root, p), dst, fs.constants.COPYFILE_EXCL);
    requireTrue(digest(fs.readFileSync(dst)) === hash, 'Backup mismatch: ' + p);
  }
  fs.copyFileSync(fileURLToPath(import.meta.url), path.join(backup, 'human-apply.mjs'), fs.constants.COPYFILE_EXCL);
  const receipt = {root, head, targets, newTarget: {path: adrTarget, before: 'ABSENT', after: adrHash}, patchHash, adrHash, status: 'BACKUP VERIFIED; NOT APPLIED'};
  fs.writeFileSync(path.join(backup, 'receipt.json'), JSON.stringify(receipt, null, 2) + '\n', {flag: 'wx'});
  verifyBases();
  run(['git', 'apply', '--check', '--unidiff-zero', patch]);
  run(['git', 'apply', '--unidiff-zero', patch]);
  for (const [p, , after] of targets) requireTrue(digest(readRegular(p)) === after, 'Readback mismatch: ' + p);
  requireAbsent();
  requireTrue(digest(readRegular(adrInput)) === adrHash, 'ADR input changed during apply');
  fs.writeFileSync(path.join(root, adrTarget), readRegular(adrInput), {flag: 'wx'});
  requireTrue(digest(readRegular(adrTarget)) === adrHash, 'ADR readback mismatch');
  receipt.status = 'APPLIED AND READBACK VERIFIED; REVIEW AND BEHAVIORAL VERIFICATION NOT RUN';
  fs.writeFileSync(path.join(backup, 'receipt.json'), JSON.stringify(receipt, null, 2) + '\n');
  console.log(receipt.status);
} catch (error) {
  console.error('STOP: ' + error.message);
  if (backup) console.error('Backup retained: ' + backup + '. Application may be partial; inspect all four targets before any retry or scoped recovery.');
  process.exitCode = 1;
}
