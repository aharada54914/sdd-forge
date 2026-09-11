const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const root = process.argv[2];
if (!root) throw new Error('checkout required');
const source = fs.readFileSync(`${root}/tests/generate-registry-digest.tests.sh`, 'utf8');
const matches = [...source.matchAll(/^if (?:grep -q 'tests\/generate-registry-digest.tests.sh'|registered_suites=)[\s\S]*?^fi$/gm)];
if (matches.length !== 1) throw new Error('expected actual registration assertion');
const suites = ['validate-capability-registry', 'generate-registry-digest', 'generate-gate-capabilities'].map(s => `tests/${s}.tests.sh`);
const cases = [{ name: 'real', entries: suites, expected: 0 }, { name: 'exact', entries: suites, expected: 0 },
  { name: 'failed-list', entries: suites, expected: 1 },
  { name: 'reverse-before', entries: [suites[1], suites[0], suites[2]], expected: 1 },
  { name: 'reverse-after', entries: [suites[0], suites[2], suites[1]], expected: 1 }];
for (let i = 0; i < suites.length; i++) {
  cases.push({ name: `missing-${i}`, entries: suites.filter((_, j) => i !== j), expected: 1 });
  cases.push({ name: `near-${i}`, entries: suites.map((s, j) => i === j ? `${s}.bak` : s), expected: 1 });
  cases.push({ name: `duplicate-${i}`, entries: [...suites, suites[i]], expected: 1 });
}
let failures = 0;
for (const c of cases) {
  const input = `set -euo pipefail
ok() { :; }
fail() { exit 1; }
bash() {
  [[ "$2" == --list ]] || return 99
  if [[ "$MODE" == real ]]; then command bash "$@"; return $?; fi
  printf '%s\\n' "$LISTING"
  [[ "$MODE" != failed-list ]]
}
${matches[0][0]}
`;
  const run = spawnSync('/bin/bash', ['-s'], { input, encoding: 'utf8', env: { ...process.env, ROOT: root, MODE: c.name, LISTING: c.entries.join('\n') } });
  const ok = !run.error && !run.signal && run.status === c.expected;
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'} ${c.name}: expected=${c.expected} actual=${run.status}`);
  if (run.error || run.stderr) console.error(run.error || run.stderr);
}
console.log(`controls: ${cases.length - failures} passed, ${failures} failed`);
process.exitCode = failures ? 1 : 0;
