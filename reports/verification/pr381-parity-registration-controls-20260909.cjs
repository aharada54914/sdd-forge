// Exercise the real audit function without rewriting either protected runner.
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const root = process.argv[2];
if (!root) throw new Error('checkout required');
const source = fs.readFileSync(`${root}/tests/component-path-ownership-parity.tests.sh`, 'utf8');
const matches = [...source.matchAll(/^registration_audit\(\) \{\n[\s\S]*?^\}/gm)];
if (matches.length !== 1) throw new Error('expected exactly one actual audit function');
let failures = 0;
const modes = ['real', 'exact', 'missing', 'near', 'duplicate', 'failed-list', 'ps-missing', 'ci-missing'];
for (const mode of modes) {
  const input = `set -eu
${matches[0][0]}
bash() {
  [[ "$2" == --list ]] || return 99
  case "$MODE" in
    real) command bash "$@";;
    exact|ps-missing|ci-missing) printf '%s\\n' tests/component-path-resolver.tests.sh;;
    missing) printf '%s\\n' tests/unrelated.tests.sh;;
    near) printf '%s\\n' tests/component-path-resolver.tests.sh.bak;;
    duplicate) printf '%s\\n' tests/component-path-resolver.tests.sh tests/component-path-resolver.tests.sh;;
    failed-list) printf '%s\\n' tests/component-path-resolver.tests.sh; return 7;;
  esac
}
grep() {
  [[ "$MODE" != ps-missing || "\${!#}" != */tests/run-all.ps1 ]] || return 1
  [[ "$MODE" != ci-missing || "\${!#}" != */.github/workflows/test.yml ]] || return 1
  command grep "$@"
}
if registration_audit "$ROOT/tests/run-all.sh" "$ROOT/tests/run-all.ps1" "$ROOT/.github/workflows/test.yml" component-path-resolver; then exit 0; else exit 1; fi
`;
  const run = spawnSync('/bin/bash', ['-s'], { input, encoding: 'utf8', env: { ...process.env, ROOT: root, MODE: mode } });
  const expected = ['real', 'exact'].includes(mode) ? 0 : 1;
  const ok = !run.error && !run.signal && run.status === expected;
  if (!ok) failures++;
  console.log(`${ok ? 'PASS' : 'FAIL'} ${mode}: expected=${expected} actual=${run.status}`);
  if (run.error || run.stderr) console.error(run.error || run.stderr);
}
console.log(`controls: ${modes.length - failures} passed, ${failures} failed`);
process.exitCode = failures ? 1 : 0;
