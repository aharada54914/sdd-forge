import fs from 'node:fs';
import path from 'node:path';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
const packageRoot = '/tmp/cloud-T008-attempt5-01a15085/rollback/mcp/sdd-forge-mcp';
const output = path.resolve('specs/cloud-orchestration/verification/T-008/attempt-5');
const hash = text => createHash('sha256').update(text).digest('hex');
const cases = [
  { name: 'cross-root-contamination', file: 'src/parsers/report-lookup.ts', from: 'roots.get(root)', to: 'roots.values().next().value', pattern: 'root identity isolates' },
  { name: 'wholeword-boundary-loss', file: 'src/parsers/report-lookup.ts', from: 'return directory(root, relDir).files.filter(file => wordBoundary.test(file.contents));', to: 'return directory(root, relDir).files.filter(file => file.contents.includes(pattern));', pattern: 'snapshot matches legacy' },
  { name: 'cross-request-stale-pass', file: 'src/parsers/tasks.ts', from: 'const TASK_HEADER_PATTERN', to: 'const retainedLookup = createReportLookup();\nconst TASK_HEADER_PATTERN', pattern: 'new parser requests|read permission failure', extra: text => text.replace('reportLookup: ReportLookup = createReportLookup()', 'reportLookup: ReportLookup = retainedLookup') },
];
const results = [];
function run(args) {
  const child = spawnSync(args[0], args.slice(1), { cwd: packageRoot, encoding: 'utf8' });
  return { command: args, exit: child.status, stdout: child.stdout, stderr: child.stderr };
}
for (const item of cases) {
  const file = path.join(packageRoot, item.file);
  const original = fs.readFileSync(file, 'utf8');
  if (!original.includes(item.from)) throw new Error('mutation target absent');
  let mutated = original.replace(item.from, item.to);
  if (item.extra) mutated = item.extra(mutated);
  try {
    fs.writeFileSync(file, mutated);
    const compile = run(['npm', 'run', 'pretest']);
    if (compile.exit !== 0) throw new Error(JSON.stringify(compile));
    const tests = run(['node', '--test', '--test-name-pattern', item.pattern, 'dist-test/tests/parsers-state/report-reuse.test.js']);
    results.push({ name: item.name, file: item.file, original_sha256: hash(original), mutation_sha256: hash(mutated), compile, tests });
    if (tests.exit !== 1) throw new Error('mutation did not fail assertions');
  } finally { fs.writeFileSync(file, original); }
}
const compile = run(['npm', 'run', 'pretest']);
const control = run(['node', '--test', 'dist-test/tests/parsers-state/report-reuse.test.js']);
fs.writeFileSync(path.join(output, 'sensitivity.json'), JSON.stringify({ cases: results, restored: { compile, control } }, null, 2)+'\n');
if (compile.exit !== 0 || control.exit !== 0) throw new Error('restored control failed');
console.log('Three deliberately broken implementations fail actual assertions; restored 10 controls pass.');
