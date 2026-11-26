import assert from 'node:assert/strict';
import fs from 'node:fs';

function requireFile(file) {
  assert.ok(fs.statSync(file, { throwIfNoEntry: false })?.isFile(), `Missing required file: ${file}`);
}

function readJson(file) {
  requireFile(file);
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

for (const file of [
  'tests/ci-dependency-cache.py',
  'contracts/verification-ci-plan.schema.json',
  'contracts/verification-ci-observations.schema.json',
]) {
  requireFile(file);
}

const resultFile = 'contracts/verification-ci-result.schema.json';
const result = readJson(resultFile);
assert.equal(result.$defs?.result?.properties?.schema?.const, 'verification-ci-result/v1',
  `Schema identity differs: ${resultFile}`);

const controlsFile = 'contracts/model-launch-controls.schema.json';
const controls = readJson(controlsFile);
assert.equal(controls.properties?.schema?.const, 'model-launch-controls/v1',
  `Schema identity differs: ${controlsFile}`);

const { roles } = readJson('contracts/model-policy.v1.json');
const { role_defaults: defaults } = readJson('contracts/agent-model-capabilities.v2.json');
const contract = readJson('contracts/model-policy.schema.json').properties.roles;
const isObject = value => value !== null && typeof value === 'object' && !Array.isArray(value);
assert.ok(isObject(roles) && Array.isArray(contract.required) && contract.required.length > 0,
  'Model policy roles differ from the policy contract.');
assert.deepEqual(Object.keys(roles).sort(), [...contract.required].sort(),
  'Model policy roles differ from the policy contract.');
assert.ok(isObject(defaults), 'Registry role defaults must be an object.');
for (const [role, policy] of Object.entries(roles)) {
  const capability = policy?.capability_role;
  assert.ok(isObject(policy) && Object.hasOwn(policy, 'capability_role'),
    `Model policy capability role differs from its contract: ${role}`);
  if (capability !== null) {
    assert.equal(typeof capability, 'string', `Model policy capability role differs from its contract: ${role}`);
    assert.ok(Object.hasOwn(defaults, capability),
      `Model policy role references an unknown registry role: ${role} -> ${capability}`);
  }
  assert.equal(capability, contract.properties[role].properties.capability_role.const,
    `Model policy capability role differs from its contract: ${role}`);
}
console.log('Release source contracts verified.');
