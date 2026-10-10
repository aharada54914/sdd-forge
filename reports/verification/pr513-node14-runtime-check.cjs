'use strict';
const assert = require('assert');
const { spawnSync } = require('child_process');
const path = require('path');
const root = path.resolve(__dirname, '../..');
const guard = path.join(root, 'plugins/sdd-quality-loop/scripts/sdd-hook-guard.js');
assert.strictEqual(process.versions.node, '14.21.3');
assert.strictEqual(typeof Object.hasOwn, 'undefined');
const native = (toolName, toolArgs, extra = {}) => ({
  sessionId: 'synthetic', timestamp: 1, cwd: '/tmp', toolName, toolArgs, ...extra,
});
const cases = [
  ['view object', native('view', {path: 'README.md'}), 'allow'],
  ['view JSON', native('view', JSON.stringify({path: 'README.md'})), 'allow'],
  ['view range', native('view', {path: 'README.md', view_range: [1, 2]}), 'allow'],
  ['bad range', native('view', {path: 'README.md', view_range: ['1', 2]}), 'deny'],
  ['safe create', native('create', {path: 'src/example.txt', file_text: 'example'}), 'allow'],
  ['protected create', native('create', {path: 'plugins/sdd-quality-loop/scripts/sdd-hook-guard.js', file_text: ''}), 'deny'],
  ['approval create', native('create', {path: 'tasks.md', file_text: 'Approval: Approved\n'}), 'deny'],
  ['missing text', native('create', {path: 'example.txt'}), 'deny'],
  ['wrong text', native('create', {path: 'example.txt', file_text: 1}), 'deny'],
  ['unknown args', native('view', {path: 'README.md', extra: true}), 'deny'],
  ['batch', {toolCalls: []}, 'deny'],
  ['legacy plus batch', {tool_name: 'read', tool_input: {file_path: 'README.md'}, toolCalls: []}, 'deny'],
  ['mixed envelope', native('view', {path: 'README.md'}, {tool_name: 'read'}), 'deny'],
  ['missing envelope field', {toolName: 'view', toolArgs: {path: 'README.md'}}, 'deny'],
  ['bad JSON', native('view', '{'), 'deny'],
  ['array args', native('view', []), 'deny'],
  ['unknown tool', native('unknown', {path: 'README.md'}), 'deny'],
  ['legacy read', {tool_name: 'read', tool_input: {file_path: 'README.md'}}, 'allow'],
];
for (const [name, payload, expected] of cases) {
  const result = spawnSync(process.execPath, [guard, '--emit', 'copilot'], {
    cwd: '/tmp', encoding: 'utf8', timeout: 10000,
    env: {...process.env, CLAUDE_PROJECT_DIR: '/tmp', PAYLOAD: JSON.stringify(payload)},
  });
  assert.ifError(result.error);
  assert.strictEqual(result.status, 0, name + ': ' + result.stderr);
  assert.strictEqual(JSON.parse(result.stdout).permissionDecision, expected, name);
  console.log('PASS: ' + name);
}
console.log('Node ' + process.versions.node + ': ' + cases.length + ' passed, 0 failed');
