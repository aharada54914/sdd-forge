// Unit-level simulation only: no git index or filesystem writes are performed.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const cp = require('node:child_process');
const vm = require('node:vm');
const path = require('node:path');
const crypto = require('node:crypto');
const repo = '/Users/jrmag/.local/share/sdd-forge-pr245-recovery-20260908';
const main = '4366438f3b243210a4ece5a17f873ca2d920600a';
const pr = '54b1ff247081971e0560cf20d45f4369e01b5c0d';
const run = args => cp.execFileSync('git', ['-C', repo, ...args], {encoding: 'utf8', maxBuffer: 32 * 1024 * 1024});
const merged = cp.spawnSync('git', ['-C', repo, 'merge-tree', '--write-tree', '--name-only', pr, main],
  {encoding: 'utf8', maxBuffer: 32 * 1024 * 1024});
assert.equal(merged.status, 1, 'Expected audited conflicts');
const [header] = merged.stdout.split('\n\n');
const [tree, ...conflicts] = header.trim().split('\n');
assert.match(tree, /^[0-9a-f]{40}$/);
assert.equal(conflicts.length, 23);
const cache = new Map();
function blob(ref, file) {
  const key = `${ref}:${file}`;
  if (!cache.has(key)) cache.set(key, run(['show', key]));
  return cache.get(key);
}
const script = fs.readFileSync(path.join(__dirname, 'pr245-human-integrate-20260908.sh'), 'utf8');
const code = script.split("<<'NODE'\n")[1].split('\nNODE\n')[0];
const compiled = new vm.Script(code);
const backup = '/virtual-audit-backup';
function simulate(fault = '') {
  const writes = new Map(); let staged = false;
  const virtualFs = {
    statSync(file) { blob(tree, file); return {isFile: () => true}; },
    lstatSync(file) { blob(tree, file); return {isSymbolicLink: () => fault === 'symlink' && file === 'AGENTS.md'}; },
    readFileSync(file, encoding) {
      let data;
      if (file.startsWith(repo + '/')) {
        data = fs.readFileSync(file);
        if (fault === 'repair') data = Buffer.concat([data, Buffer.from('\n')]);
      } else data = Buffer.from(writes.has(file) ? writes.get(file) : blob(tree, file));
      return encoding ? data.toString(encoding) : data;
    },
    writeFileSync(file, data, options) {
      if (options?.flag === 'wx') assert(!writes.has(file));
      writes.set(file, String(data));
    }
  };
  const virtualCp = {
    execFileSync(command, args) {
      assert.equal(command, 'git');
      if (args[0] === 'show') {
        const colon = args[1].indexOf(':');
        let text = blob(args[1].slice(0, colon), args[1].slice(colon + 1));
        if (fault === 'ledger' && args[1] === main + ':reports/review-context/identity-ledger.json') {
          const ledger = JSON.parse(text); ledger.records[0].record_sha256 = '0'.repeat(64);
          text = JSON.stringify(ledger);
        }
        return text;
      }
      if (args[0] === 'diff') return staged ? '' : [...conflicts, ...(fault === 'conflict' ? ['unexpected.txt'] : [])].join('\n');
      if (args[0] === 'rev-parse') return main + '\n';
      if (args[0] === 'add') { assert.equal(args.length, 26); staged = true; return ''; }
      throw new Error(`Unexpected subprocess: ${args.join(' ')}`);
    }
  };
  const context = vm.createContext({
    require(name) {
      if (name === 'fs') return virtualFs;
      if (name === 'child_process') return virtualCp;
      if (name === 'crypto') return crypto;
      if (name === 'path') return path;
      throw new Error(`Unexpected module: ${name}`);
    },
    process: {argv: ['node', '-', backup, repo, main, pr]},
    structuredClone, console: {log() {}}
  });
  compiled.runInContext(context, {timeout: 30000});
  assert(staged);
  assert.equal(writes.size, 27, '24 resolved/repaired files plus three audit backups');
  assert.equal(JSON.parse(writes.get('reports/review-context/identity-ledger.json')).records.length, 1079);
  for (const ext of ['sh', 'ps1']) {
    const content = writes.get(`tests/run-all.${ext}`);
    const names = ext === 'sh' ? content.match(/^  tests\/\S+$/gm) : content.match(/^    'tests\/[^']+'/gm);
    assert.equal(names.length, ext === 'sh' ? 145 : 100);
    assert.equal(new Set(names).size, names.length);
  }
}
simulate();
console.log('PASS: exact-blob candidate simulation, 23 resolutions, repair, 24 mirror comparisons, runner counts and ledger');
for (const [fault, expected] of [
  ['conflict', /Unexpected conflict set/], ['ledger', /Invalid record digest/],
  ['repair', /Source repair changed/], ['symlink', /Refusing symlink AGENTS.md/]
]) {
  assert.throws(() => simulate(fault), expected);
  console.log(`PASS: rejects ${fault}`);
}
console.log('No protected file, index, or working tree was modified. This is not end-to-end shell or product test evidence.');
