// Executes the actual assertion blocks; never rewrites a protected runner.
const fs = require('node:fs');
const { spawnSync } = require('node:child_process');
const { createHash } = require('node:crypto');
const root = process.argv[2];
if (!root) throw new Error('usage: node <script> <checkout>');
let failures = 0;
let total = 0;
const names = process.argv.slice(3);
if (!names.length) names.push('agent-model-routing', 'agent-capabilities-v2', 'render-agent-frontmatter');
for (const name of names) {
  const suite = `tests/${name}.tests.sh`;
  const source = fs.readFileSync(`${root}/${suite}`, 'utf8');
  const expression = name === 'ownership-digest'
    ? /^if should_run TEST-041; then\n[\s\S]*?^fi$/gm
    : name === 'agent-model-routing'
    ? /^registered_suites=.*\n.*\n  fail "TEST-027 tests\/agent-model-routing[^\n]+/gm
    : /^ *if registered_suites=.*\n.*\n[\s\S]*?^ *fi$/gm;
  const blocks = [...source.matchAll(expression)];
  const expectedBlocks = name === 'model-freshness-check' ? 2 : 1;
  if (blocks.length !== expectedBlocks) throw new Error(`Expected ${expectedBlocks} assertions: ${suite}`);
  const block = blocks.map(match => match[0]).join('\n');
  console.log(`${suite} sha256=${createHash('sha256').update(source).digest('hex')}`);
  const modes = ['real', 'exact', 'missing', 'near', 'failed-list'];
  if (block.includes('run-all.ps1') || block.includes('$RUN_ALL_PS1')) modes.push('ps1-missing');
  if (block.includes('$TEST_YML') || block.includes('/.github/workflows/test.yml')) modes.push('ci-missing');
  if (name === 'ownership-digest') modes.push('design-missing');
  for (const mode of modes) {
    total++;
    const mock = mode === 'real' ? '' : `
bash() {
  [[ "$2" == --list ]] || return 99
  case "$CONTROL_MODE" in
    exact|ps1-missing|ci-missing|design-missing) printf '%s\\n' "$CONTROL_SUITE";;
    missing) printf '%s\\n' tests/unrelated.tests.sh;;
    near) printf '%s\\n' "$CONTROL_SUITE.bak";;
    failed-list) printf '%s\\n' "$CONTROL_SUITE"; return 7;;
  esac
}
grep() {
  if [[ "$CONTROL_MODE" == ps1-missing && "\${!#}" == */tests/run-all.ps1 ]]; then return 1; fi
  if [[ "$CONTROL_MODE" == ci-missing && "\${!#}" == */.github/workflows/test.yml ]]; then return 1; fi
  if [[ "$CONTROL_MODE" == design-missing && "\${!#}" == */specs/epic-191-a3-path-ownership/design.md ]]; then return 1; fi
  command grep "$@"
}
`;
    const run = spawnSync('/bin/bash', ['-s'], {
      encoding: 'utf8',
      env: { ...process.env, ROOT: root, REPO_ROOT: root, RUN_ALL_SH: `${root}/tests/run-all.sh`, RUN_ALL_PS1: `${root}/tests/run-all.ps1`, TEST_YML: `${root}/.github/workflows/test.yml`, CONTROL_MODE: mode, CONTROL_SUITE: suite },
      input: `set -euo pipefail\nfail() { exit 1; }\nbad() { exit 1; }\nok() { :; }\npass() { :; }\nshould_run() { return 0; }\nis_mutated() { return 1; }\ncheck() { [[ "$3" == 1 ]] || exit 1; }\n${mock}\n${block}\n`,
    });
    const expected = ['real', 'exact'].includes(mode) ? 0 : 1;
    if (run.error || run.signal || run.status !== expected) {
      failures++;
      console.error(`FAIL ${name} ${mode}: expected=${expected} actual=${run.status}`, run.error || run.stderr);
    } else console.log(`PASS ${name} ${mode}: exit=${run.status}`);
  }
}
console.log(`controls: ${total - failures} passed, ${failures} failed`);
process.exitCode = failures ? 1 : 0;
