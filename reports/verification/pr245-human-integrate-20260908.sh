#!/usr/bin/env bash
# Human-only integration candidate preparation. No commit, push or merge to main.
set -euo pipefail
umask 077
source_repo=/Users/jrmag/.local/share/sdd-forge-pr245-recovery-20260908
main_ref=4366438f3b243210a4ece5a17f873ca2d920600a
pr_ref=54b1ff247081971e0560cf20d45f4369e01b5c0d
stop() { printf 'STOP: %s\n' "$*" >&2; exit 1; }
for tool in rtk git node; do command -v "$tool" >/dev/null || stop "Missing $tool"; done
[[ "$(rtk proxy git -C "$source_repo" rev-parse HEAD)" == "$pr_ref" ]] || stop 'Source HEAD changed'
remote_main=$(rtk proxy git ls-remote https://github.com/aharada54914/sdd-forge.git refs/heads/main)
[[ "$remote_main" == "$main_ref"$'\trefs/heads/main' ]] || stop 'Remote main changed; re-audit required'
remote_pr=$(rtk proxy git ls-remote https://github.com/aharada54914/sdd-forge.git refs/pull/245/head)
[[ "$remote_pr" == "$pr_ref"$'\trefs/pull/245/head' ]] || stop 'PR245 head changed; re-audit required'
rtk proxy git -C "$source_repo" cat-file -e "$main_ref^{commit}"
candidate_root=$(rtk proxy mktemp -d /tmp/sdd-pr245-integration.XXXXXX)
printf 'Candidate and audit backup: %s\n' "$candidate_root"
rtk proxy git clone --no-hardlinks "$source_repo" "$candidate_root/repo"
rtk proxy git -C "$candidate_root/repo" switch -c codex/pr245-integrate-main-20260908 "$pr_ref"
rtk proxy git -C "$candidate_root/repo" remote set-url origin https://github.com/aharada54914/sdd-forge.git
cd "$candidate_root/repo"
# Command-scoped identity is only needed to start an uncommitted merge.
merge_code=0
rtk proxy git -c user.name='SDD Integration Preparation' -c user.email='sdd-integration@example.invalid' merge --no-commit --no-ff "$main_ref" || merge_code=$?
[[ "$merge_code" == 1 ]] || stop "Expected the audited conflicted merge, got $merge_code"
rtk proxy node - "$candidate_root" "$source_repo" "$main_ref" "$pr_ref" <<'NODE'
const fs = require('fs');
const cp = require('child_process');
const crypto = require('crypto');
const path = require('path');
const [backup, source, main, pr] = process.argv.slice(2);
const assert = (ok, message) => { if (!ok) throw new Error(message); };
const git = (...args) => cp.execFileSync('git', args, {encoding: 'utf8', maxBuffer: 32 * 1024 * 1024});
const blob = (ref, file) => git('show', `${ref}:${file}`);
const hash = data => crypto.createHash('sha256').update(data).digest('hex');
const replaceOnce = (text, old, replacement) => {
  assert(text.split(old).length === 2, `Non-unique/missing insertion anchor: ${old}`);
  return text.replace(old, replacement);
};
const mirror = 'specs/epic-191-a3-path-ownership/human-copy';
const keepMain = [
  ...['check-workflow-state.sh', 'check-workflow-state.ps1', 'prepare-panelist-input.sh',
    'prepare-panelist-input.ps1', 'run-panelist-gemini.sh', 'run-panelist-gpt.sh',
    'run-panelist-gpt.ps1'].map(f => `plugins/sdd-quality-loop/scripts/${f}`),
  ...['impl-review-precheck.sh', 'impl-review-precheck.ps1', 'task-review-precheck.sh',
    'task-review-precheck.ps1'].map(f => `plugins/sdd-review-loop/scripts/${f}`),
  ...['downstream-review-precheck.tests.ps1', 'prepare-panelist.tests.sh',
    'prepare-panelist.tests.ps1', 'run-panelist-effort.tests.sh',
    'run-panelist-effort.tests.ps1', 'workflow-state.tests.sh'].map(f => `tests/${f}`),
  `${mirror}/MANIFEST.sha256`
];
const ledgerPath = 'reports/review-context/identity-ledger.json';
const expected = [...keepMain, 'AGENTS.md', 'tests/run-all.sh', 'tests/run-all.ps1',
  'specs/workflow-state-registry.json', ledgerPath].sort();
const actual = git('diff', '--name-only', '--diff-filter=U').trim().split('\n').sort();
assert(expected.length === 23 && JSON.stringify(actual) === JSON.stringify(expected), 'Unexpected conflict set');
assert(git('rev-parse', 'MERGE_HEAD').trim() === main, 'Unexpected merge parent');
const outputs = new Map(keepMain.map(f => [f, blob(main, f)]));
const feature = 'epic-193-a5-capability-resolver';
const agentLine = `- \`specs/${feature}/\``;
const mainAgents = blob(main, 'AGENTS.md');
assert(!mainAgents.includes(agentLine) && blob(pr, 'AGENTS.md').includes(agentLine), 'Unexpected A5 registration');
outputs.set('AGENTS.md', replaceOnce(mainAgents, '## Source Artifact Locations', `${agentLine}\n\n## Source Artifact Locations`));
const registryPath = 'specs/workflow-state-registry.json';
const registry = JSON.parse(blob(main, registryPath));
const branchRegistry = JSON.parse(blob(pr, registryPath));
const additions = branchRegistry.entries.filter(e => e.feature === feature);
assert(additions.length === 1 && additions[0].profile === 'full', 'Unexpected branch registration');
assert(!registry.entries.some(e => e.feature === feature), 'Main already registers A5');
registry.entries.push(additions[0]);
outputs.set(registryPath, JSON.stringify(registry, null, 2) + '\n');
const suites = ['resolver-evidence-schema', 'resolve-project-context-block',
  'resolve-project-context-match', 'resolve-project-context-cli', 'resolve-project-context-discovery',
  'resolve-project-context-lite', 'validate-resolver-evidence',
  'resolve-project-context-parity', 'resolve-project-context-metamorphic'];
for (const ext of ['sh', 'ps1']) {
  const file = `tests/run-all.${ext}`;
  const original = blob(main, file);
  const names = suites.map(s => `tests/${s}.tests.${ext}`);
  for (const name of names) {
    assert(!original.includes(name), `Duplicate registration ${name}`);
    assert(fs.statSync(name).isFile() && blob(pr, file).includes(name), `Missing suite ${name}`);
  }
  const anchor = ext === 'sh' ? 'tests=(\n' : '$tests = @(\n';
  const entries = names.map(n => ext === 'sh' ? `  ${n}\n` : `    '${n}',\n`).join('');
  outputs.set(file, replaceOnce(original, anchor, anchor + entries));
}
const mainLedgerText = blob(main, ledgerPath), prLedgerText = blob(pr, ledgerPath);
const mainLedger = JSON.parse(mainLedgerText), prLedger = JSON.parse(prLedgerText);
function validateLedger(ledger) {
  let previous = ''; const runs = new Set(), sessions = new Set();
  ledger.records.forEach((r, i) => {
    assert(r.sequence === i + 1 && r.previous_record_sha256 === previous, 'Invalid ledger chain');
    assert(!runs.has(r.run_id) && !sessions.has(r.host_session_id), 'Duplicate ledger identity');
    runs.add(r.run_id); sessions.add(r.host_session_id);
    assert(hash([r.sequence, r.stage, r.role, r.run_id, r.host_session_id, previous].join('|')) === r.record_sha256, 'Invalid record digest');
    previous = r.record_sha256;
  });
}
validateLedger(mainLedger); validateLedger(prLedger);
assert(mainLedger.records.length === 959 && prLedger.records.length === 884, 'Ledger counts changed');
assert(JSON.stringify(mainLedger.records.slice(0, 764)) === JSON.stringify(prLedger.records.slice(0, 764)), 'Ledger prefix changed');
const runIds = new Set(mainLedger.records.map(r => r.run_id));
const tail = prLedger.records.filter(r => !runIds.has(r.run_id));
assert(tail.length === 120, 'Expected 120 archival records');
const merged = structuredClone(mainLedger);
for (const record of tail) {
  const r = {...record, sequence: merged.records.length + 1,
    previous_record_sha256: merged.records.at(-1).record_sha256};
  r.record_sha256 = hash([r.sequence, r.stage, r.role, r.run_id, r.host_session_id, r.previous_record_sha256].join('|'));
  merged.records.push(r);
}
validateLedger(merged);
assert(merged.records.length === 1079, 'Incorrect merged count');
outputs.set(ledgerPath, JSON.stringify(merged, null, 2) + '\n');
// Preserve the reviewed local fix without overwriting auto-merged main tests.
const repairPath = 'tests/review-agent-isolation.tests.sh';
const repair = fs.readFileSync(path.join(source, repairPath));
assert(hash(repair) === '5d80ed124b212bf0e1845be653f5845372b490d614bb5ff84ba1c88364cec95a', 'Source repair changed');
const old = 'git -C "$SOURCE_GIT_ROOT" archive 7df7318 "${baseline_paths[@]}" | tar -x -C "$rollback_baseline"';
const replacement = [
  'archive_file="$tmp/rollback-baseline.tar"',
  'git -C "$SOURCE_GIT_ROOT" archive -o "$archive_file" 7df7318 "${baseline_paths[@]}"',
  '[[ -s "$archive_file" ]] || fail \'rollback archive export produced an empty tarball\'',
  'tar -tf "$archive_file" >/dev/null',
  'tar -x -f "$archive_file" -C "$rollback_baseline"'
].join('\n');
assert(repair.toString().includes(replacement), 'Repair contents differ');
outputs.set(repairPath, replaceOnce(fs.readFileSync(repairPath, 'utf8'), old, replacement));
// Finish all calculations before any conflict resolution is written.
fs.writeFileSync(path.join(backup, 'main-identity-ledger.json'), mainLedgerText, {flag: 'wx'});
fs.writeFileSync(path.join(backup, 'pr245-identity-ledger.json'), prLedgerText, {flag: 'wx'});
for (const [file, text] of outputs) {
  assert(!fs.lstatSync(file).isSymbolicLink(), `Refusing symlink ${file}`);
  fs.writeFileSync(file, text);
}
const rows = outputs.get(`${mirror}/MANIFEST.sha256`).trim().split('\n');
assert(rows.length === 12, 'Manifest row count changed');
for (const row of rows) {
  const match = /^([a-f0-9]{64})  ([A-Za-z0-9_./-]+)$/.exec(row);
  assert(match && !match[2].split('/').includes('..'), 'Invalid manifest row');
  for (const file of [match[2], `${mirror}/${match[2]}`]) {
    assert(hash(fs.readFileSync(file)) === match[1], `Manifest mismatch ${file}`);
  }
}
git('add', '--', ...outputs.keys());
assert(git('diff', '--name-only', '--diff-filter=U').trim() === '', 'Unresolved conflicts remain');
fs.writeFileSync(path.join(backup, 'candidate-files.sha256'), [...outputs].map(([f, t]) => `${hash(t)}  ${f}\n`).join(''), {flag: 'wx'});
console.log('23 conflicts resolved; archive repair preserved; 24 mirror hashes verified.');
console.log('Historical invocation pins are archival, not replayable against the re-chained ledger.');
NODE
rtk proxy git diff --cached --check
rtk proxy git diff --cached --stat
rtk proxy git status --short
printf '\nCandidate prepared: %s/repo\n' "$candidate_root"
printf 'No tests, commit, push, or main merge have been performed. Send this output to Codex.\n'
