// Check commands in the actual required job as well as the catalog route.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const [root, workflowPath] = process.argv.slice(2);
const yaml = require(path.join(root, 'mcp/sdd-forge-mcp/node_modules/js-yaml'));
const { jobs } = yaml.load(fs.readFileSync(workflowPath, 'utf8'));
const jobId = 'v2-guardrails';
const job = jobs[jobId];
assert.ok(jobs['required-checks'].needs.includes(jobId));
assert.deepEqual([...job.strategy.matrix.os].sort(), ['macos-latest', 'ubuntu-latest', 'windows-latest']);
const catalog = JSON.parse(fs.readFileSync(path.join(root, 'tests/verification-catalog.json'), 'utf8'));
for (const [extension, shell, prefix] of [['sh', 'bash', 'bash '], ['ps1', 'pwsh', '']]) {
  const suite = 'tests/ownership-digest.tests.' + extension;
  assert.ok(catalog.suites.find(entry => entry.path === suite)?.ci_jobs.includes(jobId), suite);
  const step = job.steps.find(step => step.run?.trim() === prefix + './' + suite);
  assert.equal(step?.shell, shell, suite);
  assert.equal(step.if, "runner.os != 'Windows'", suite);
  assert.ok(!step['continue-on-error'], suite);
}
