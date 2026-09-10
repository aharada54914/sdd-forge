// Execute actual registration loop/self-check, without modifying repository files.
const fs = require('node:fs');
const {spawnSync} = require('node:child_process');
const root = process.argv[2];
if (!root) throw new Error('checkout required');
const source = fs.readFileSync(`${root}/tests/facet-manifest-parity.tests.sh`, 'utf8');
const loops = [...source.matchAll(/^SIX_SUITES=.*\nfor suite in \$SIX_SUITES; do\n[\s\S]*?^done$/gm)];
const selfs = [...source.matchAll(/^if registered_suites=.*\n[\s\S]*?^fi$/gm)];
if (loops.length !== 1 || selfs.length !== 1) throw new Error('ambiguous actual blocks');
const names = loops[0][0].match(/^SIX_SUITES="([^"]+)"/)[1].split(' ');
if (names.length !== 6 || new Set(names).size !== 6) throw new Error('expected six distinct suites');
const cases = [{mode: 'real'}, {mode: 'exact'}, {mode: 'failed-list'}];
for (const target of names) for (const mode of ['missing', 'near', 'ps1-missing']) cases.push({mode, target});
let failed = 0;
for (const test of cases) {
  const mock = test.mode === 'real' ? '' : `
bash() {
  [[ "$2" == --list ]] || return 99
  for member in $CONTROL_MEMBERS; do
    if [[ "$member" == "$CONTROL_TARGET" && "$CONTROL_MODE" == missing ]]; then continue; fi
    suffix=''
    if [[ "$member" == "$CONTROL_TARGET" && "$CONTROL_MODE" == near ]]; then suffix='.bak'; fi
    printf 'tests/%s.tests.sh%s\\n' "$member" "$suffix"
  done
  [[ "$CONTROL_MODE" != failed-list ]] || return 7
}
grep() {
  if [[ "$CONTROL_MODE" == ps1-missing && "\${!#}" == */tests/run-all.ps1 && "$2" == "tests/$CONTROL_TARGET.tests.ps1" ]]; then return 1; fi
  command grep "$@"
}
`;
  const result = spawnSync('/bin/bash', ['-s'], {
    encoding: 'utf8',
    env: {...process.env, REPO_ROOT: root, CONTROL_MODE: test.mode, CONTROL_TARGET: test.target || '', CONTROL_MEMBERS: names.join(' ')},
    input: `set -euo pipefail\nfail() { exit 1; }\nok() { :; }\n${mock}\n${loops[0][0]}\n${selfs[0][0]}\n`,
  });
  const expected = ['real', 'exact'].includes(test.mode) ? 0 : 1;
  const pass = !result.error && !result.signal && result.status === expected;
  if (!pass) failed++;
  console.log(`${pass ? 'PASS' : 'FAIL'} ${test.mode} ${test.target || ''}: expected=${expected} actual=${result.status}`);
  if (!pass) console.error(result.error || result.stderr);
}
console.log(`controls: ${cases.length - failed} passed, ${failed} failed`);
process.exitCode = failed ? 1 : 0;
