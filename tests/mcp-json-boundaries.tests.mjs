import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync, chmodSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

for (const file of ['install.sh', 'install.ps1', 'uninstall.sh', 'uninstall.ps1']) {
  const text = readFileSync(new URL('../' + file, import.meta.url), 'utf8');
  const program = text.match(file.endsWith('.ps1') ? /\$nodeScript = @'\r?\n([\s\S]*?)\r?\n'@/ : /node -e '\n([\s\S]*?)\n' /)?.[1];
  assert.ok(program, `embedded Node program must be found in ${file}`);
  const installing = file.startsWith('install.');
  const args = config => installing ? [config, 'mcpServers', 'cursor', 'ci-mcp', '/fixture 日本語/entry.js'] : [config, 'mcpServers', 'ci-mcp'];
  const initial = JSON.stringify({ unknown: 'preserve 日本語', mcpServers: { other: { command: 'other' }, 'ci-mcp': { command: 'old' } } });

  test(`${file}: unreadable existing JSON is preserved and returns failure`, t => {
    if (process.platform === 'win32') return t.skip('POSIX mode fixture does not establish Windows ACL behavior');
    const root = mkdtempSync(join(tmpdir(), 'sdd-mcp-json-'));
    const config = join(root, 'mcp.json');
    writeFileSync(config, initial);
    chmodSync(root, 0o777); chmodSync(config, 0o000);
    try {
      const options = { encoding: 'utf8', timeout: 5000 };
      if (process.getuid?.() === 0) Object.assign(options, { uid: 65534, gid: 65534 });
      const result = spawnSync(process.execPath, ['-e', program, ...args(config)], options);
      assert.equal(result.status, 1, result.stderr);
      chmodSync(config, 0o600);
      assert.equal(readFileSync(config, 'utf8'), initial);
    } finally { chmodSync(config, 0o600); rmSync(root, { recursive: true, force: true }); }
  });

  test(`${file}: temporary-file collision cannot overwrite another file`, () => {
    const root = mkdtempSync(join(tmpdir(), 'sdd-mcp-json-collision-'));
    const config = join(root, 'mcp.json');
    writeFileSync(config, initial);
    writeFileSync(config + '.sdd-forge.tmp', 'unrelated existing bytes');
    try {
      const result = spawnSync(process.execPath, ['-e', program, ...args(config)], { encoding: 'utf8', timeout: 5000 });
      assert.notEqual(result.status, 0);
      assert.equal(readFileSync(config, 'utf8'), initial);
      assert.equal(readFileSync(config + '.sdd-forge.tmp', 'utf8'), 'unrelated existing bytes');
    } finally { rmSync(root, { recursive: true, force: true }); }
  });

  test(`${file}: normal JSON mutation preserves unrelated keys and private file permissions`, () => {
    const root = mkdtempSync(join(tmpdir(), 'sdd-mcp-json-normal-'));
    const config = join(root, 'mcp.json');
    writeFileSync(config, initial);
    try {
      const result = spawnSync(process.execPath, ['-e', 'process.umask(0o022);\n' + program, ...args(config)], { encoding: 'utf8', timeout: 5000 });
      assert.equal(result.status, 0, result.stderr);
      const data = JSON.parse(readFileSync(config, 'utf8'));
      assert.equal(data.unknown, 'preserve 日本語');
      assert.deepEqual(data.mcpServers.other, { command: 'other' });
      if (installing) assert.deepEqual(data.mcpServers['ci-mcp'].args, ['/fixture 日本語/entry.js']);
      else assert.equal(Object.hasOwn(data.mcpServers, 'ci-mcp'), false);
      if (process.platform !== 'win32') assert.equal(statSync(config).mode & 0o777, 0o600);
    } finally { rmSync(root, { recursive: true, force: true }); }
  });
}
