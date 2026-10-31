import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import cp from 'node:child_process';
const owner = '/Users/jrmag/.codex/worktrees/shared-review-launch-integration/sdd-forge';
const out = path.join(owner, 'reports/verification/shared-launch-handoff/T-001-current-rollback');
const baseline = path.join(owner, 'reports/verification/shared-launch-handoff/T-001-git-rollback');
const checkout = path.join(out, 'checkout');
const evidence = path.join(owner, 'reports/verification/shared-launch-handoff/T-001-output/verification/T-001');
const sha = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const hash = file => fs.existsSync(file) ? sha(fs.readFileSync(file)) : null;
const json = (name, data) => fs.writeFileSync(path.join(out, name), JSON.stringify(data, null, 2) + '\n');
const records = fs.readFileSync(path.join(evidence, 'git-rollback-restored-hashes.txt'), 'utf8').trim().split('\n').map(JSON.parse);
const expected = JSON.parse(fs.readFileSync(path.join(evidence, 'before-hashes.json'))).inputs;
const targets = records.slice(0, 18).map(x => x.path).filter(x => !x.endsWith('task-review-contract.template.json'));
targets.push('tests/review-conditional-inputs.tests.py', 'tests/shared-launch-build.tests.py', 'tests/shared-launch-python-requirements.txt', 'tests/shared-launch-python/pyproject.toml');
function verify26() {
  return records.map(x => ({path: x.path, expected: expected.find(y => y.path === x.path).sha256, actual: hash(path.join(checkout, x.path))}));
}
function assert26(rows) { if (rows.length !== 26 || rows.some(x => x.expected !== x.actual)) throw Error('26 pretask hashes mismatch'); }
function makePatch(reverse) {
  let patch = '*** Begin Patch\n';
  for (const name of targets) {
    const a = path.join(reverse ? owner : baseline, name);
    const b = path.join(reverse ? baseline : owner, name);
    const old = fs.existsSync(a) ? fs.readFileSync(a, 'utf8') : null;
    const next = fs.existsSync(b) ? fs.readFileSync(b, 'utf8') : null;
    if (old === next) continue;
    const dest = path.join(checkout, name);
    if (next === null) patch += `*** Delete File: ${dest}\n`;
    else if (old === null) patch += `*** Add File: ${dest}\n` + next.replace(/\n$/, '').split('\n').map(x => '+' + x).join('\n') + '\n';
    else patch += `*** Update File: ${dest}\n` + cp.spawnSync('diff', ['-U3', a, b], {encoding:'utf8'}).stdout.split('\n').slice(2).join('\n').replace(/^@@.*@@.*$/gm, '@@');
  }
  return patch + '*** End Patch\n';
}
const mode = process.argv[2];
if (mode === 'prepare') {
  const rows = verify26(); assert26(rows); json('baseline-hashes.json', rows);
  json('target-hashes.json', targets.map(name => ({path: name, baseline: hash(path.join(baseline,name)), candidate: hash(path.join(owner,name))})));
  json('context.json', {owner, baseline, checkout, head: cp.execFileSync('git',['rev-parse','HEAD'],{cwd:owner,encoding:'utf8'}).trim(), dirty: cp.execFileSync('git',['status','--short'],{cwd:owner,encoding:'utf8'}), scope:'T-001 isolated code/config rollback; high risk; no formal gate', evidenceHashes: {before:hash(path.join(evidence,'before-hashes.json')), previousRestored:hash(path.join(evidence,'git-rollback-restored-hashes.txt'))}});
  fs.writeFileSync(path.join(out,'apply.patch'),makePatch(false));
  fs.writeFileSync(path.join(out,'restore.patch'),makePatch(true));
  console.log(`Baseline verified: ${rows.length}; candidate targets: ${targets.length}`);
} else if (mode === 'check-candidate' || mode === 'check-restored') {
  const saved = JSON.parse(fs.readFileSync(path.join(out,'target-hashes.json')));
  const rows = saved.map(x => ({...x, actual:hash(path.join(checkout,x.path)), owner_now:hash(path.join(owner,x.path)), old_disposable_now:hash(path.join(baseline,x.path))}));
  json(mode + '.json', rows);
  if(rows.some(x=>x.actual!==x[mode==='check-candidate'?'candidate':'baseline'] || x.owner_now!==x.candidate || x.old_disposable_now!==x.baseline)) throw Error('target or source drift');
  if(mode==='check-restored'){ const restored=verify26();json('restored-26-hashes.json',restored);assert26(restored); }
  console.log(mode+': all hashes match; owner and old disposable preserved');
} else if (mode === 'tests') {
  const phase=process.argv[3];
  const suites=['quality-nontty-transport','host-review-preflight','unified-task-launch','unified-launch-order'];
  if(phase==='candidate') suites.push('review-conditional-inputs','shared-launch-build');
  const results=[];
  for(const suite of suites){ const args=['proxy','python3','-B',`tests/${suite}.tests.py`]; const r=cp.spawnSync('rtk',args,{cwd:checkout,encoding:'utf8'});fs.writeFileSync(path.join(out,`${phase}-${suite}.log`),r.stdout+r.stderr);results.push({command:['rtk',...args],exit:r.status}); console.log(`${phase} ${suite}: ${r.status}`); }
  json(`${phase}-results.json`,results);if(results.some(x=>x.exit!==0))process.exitCode=1;
}
