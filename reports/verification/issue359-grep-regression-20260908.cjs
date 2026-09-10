// Exercise the current CL-021b condition, not a reimplementation of it.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const root = path.resolve(__dirname, '../..');
const source = fs.readFileSync(path.join(root, 'tests/collection-layer.tests.sh'), 'utf8');
const lines = source.split('\n');
const anchor = lines.findIndex(line => line.includes('ok "CL-021b:'));
if (anchor < 1) throw new Error('CL-021b anchor missing');
const line = lines[anchor - 1];
const allowed = [
  'if echo "${RUN_OUTPUT}" | grep -qi "candidate"; then',
  'if echo "${RUN_OUTPUT}" | grep -i "candidate" >/dev/null; then',
];
if (!allowed.includes(line)) throw new Error('Unrecognized assertion: inspect before executing');
const command = line.slice(3, -6);
const padding = 'unrelated diagnostic line\n'.repeat(100000);
const cases = [
  ['large prefix match', 'candidate\n' + padding, 0],
  ['large suffix match', padding + 'CANDIDATE\n', 0],
  ['large nonmatch', padding, 1],
  ['empty nonmatch', '', 1],
];
let failed = 0;
for (const [name, input, expected] of cases) {
  const result = spawnSync('/bin/bash', ['-c',
    'set -o pipefail\nRUN_OUTPUT=$(cat)\n' + command],
  { input, encoding: 'utf8', timeout: 30000, maxBuffer: 1024 * 1024 });
  const pass = !result.error && result.status === expected;
  if (!pass) failed++;
  console.log(`${pass ? 'PASS' : 'FAIL'} ${name}: expected=${expected}, actual=${result.status}, signal=${result.signal}`);
  if (result.error) console.log(result.error.message);
  if (result.stderr) process.stdout.write(result.stderr);
}
console.log(`Results: ${cases.length - failed} passed, ${failed} failed`);
process.exitCode = failed ? 1 : 0;
