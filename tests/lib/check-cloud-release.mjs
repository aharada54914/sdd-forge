// Run from the release checkout or an isolated copy of it.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';

const { load: parseYaml } = createRequire(new URL('../../mcp/sdd-forge-mcp/package.json', import.meta.url))('js-yaml');

const cloud = ['sdd-azure-cloud', 'sdd-aws-cloud'];
const members = [
  'sdd-bootstrap', 'sdd-ship', 'sdd-implementation', 'sdd-quality-loop',
  'sdd-review-loop', 'sdd-domain', ...cloud,
];
const exportsByHost = {
  '.claude-plugin': ['./skills/'], '.codex-plugin': './skills/', '.plugin': 'skills/',
};
// With an install root, both explicitly selected providers must have a mirror.
const args = process.argv.slice(2);
assert.ok(!args.length || (args.length === 2 && args[0] === '--installed-root' && args[1]), 'expected [--installed-root PATH]');
const installedRoot = args[1];
const read = file => JSON.parse(fs.readFileSync(file, 'utf8'));
const release = read('plugins/sdd-ship/.claude-plugin/plugin.json').version;
assert.match(release, /^\d+\.\d+\.\d+$/u, 'sdd-ship release version');

const pluginDirs = fs.readdirSync('plugins', { withFileTypes: true }).filter(entry => entry.isDirectory());
assert.deepEqual(pluginDirs.map(entry => entry.name).sort(), [...members].sort(), 'plugins: release membership');

for (const name of members) {
  const gemini = ['sdd-implementation', 'sdd-quality-loop'].includes(name)
    ? 'gemini/gemini-extension.json' : 'gemini-extension.json';
  for (const host of [...Object.keys(exportsByHost), '.antigravity-plugin', 'gemini']) {
    const file = `plugins/${name}/${host === 'gemini' ? gemini : host + '/plugin.json'}`;
    const manifest = read(file);
    const expectedName = host === 'gemini' && name === 'sdd-implementation' ? 'sdd-forge-model-selection' : name;
    assert.equal(manifest.name, expectedName, `${file}: name`);
    assert.equal(manifest.version, release, `${file}: version`);
    if (cloud.includes(name) && Object.hasOwn(exportsByHost, host)) {
      assert.deepEqual(manifest.skills, exportsByHost[host], `${file}: skills`);
    }
  }
}

for (const file of ['.agents/plugins/marketplace.json', '.claude-plugin/marketplace.json']) {
  const entries = read(file).plugins;
  for (const name of members) {
    const matches = entries.filter(entry => entry.name === name);
    assert.equal(matches.length, 1, `${file}: ${name} membership`);
    const [entry] = matches;
    assert.equal(entry.version, release, `${file}: ${name} version`);
    if (!cloud.includes(name)) continue;
    const expectedPath = `./plugins/${name}`;
    if (file.startsWith('.agents/')) {
      assert.equal(entry.source?.source, 'local', `${file}: ${name} source kind`);
      assert.equal(entry.source?.path, expectedPath, `${file}: ${name} source path`);
      assert.equal(entry.policy?.installation, 'AVAILABLE', `${file}: ${name} policy.installation`);
      assert.equal(entry.policy?.authentication, 'ON_INSTALL', `${file}: ${name} policy.authentication`);
    } else {
      assert.equal(entry.source, expectedPath, `${file}: ${name} source`);
    }
  }
  assert.equal(entries.length, members.length, `${file}: release membership`);
}

// Installers materialize a mirror only for selected providers. Check the
// shared sources on every release, and the complete mirror whenever present.
const schemaFamilies = [
  'authorization-receipt', 'check-result', 'collection-context', 'dependency-lock', 'deployment-policy',
  'input-error', 'observation', 'observation-evidence', 'operation-result', 'ownership', 'preview',
  'run-request', 'verification', 'verification-profile', 'verification-registry',
];
const schemas = fs.readdirSync('contracts').filter(name => /^cloud-.*\.schema\.json$/.test(name));
for (const family of schemaFamilies) {
  const file = `cloud-${family}.schema.json`;
  assert.ok(schemas.includes(file), `contracts/${file}: canonical runtime`);
}
const quality = 'plugins/sdd-quality-loop';
const runtime = [
  ...['cloud_contracts.py', 'cloud_authorization.py', 'cloud_verification.py', 'cloud_dependencies.py']
    .map(name => [quality, `scripts/${name}`]),
  [quality, 'references/cloud-verification-registry.json'],
  ...['verification-contract-v3.schema.json', 'selected-verification-plan-v2.schema.json']
    .map(name => [quality, `contracts/${name}`]),
  ...schemas.map(name => ['.', `contracts/${name}`]),
];
for (const name of cloud) {
  const plugin = `plugins/${name}`;
  const skills = fs.readdirSync(`${plugin}/skills`, { recursive: true })
    .filter(file => path.basename(file) === 'SKILL.md').map(file => file.split(path.sep).join('/'));
  assert.deepEqual(skills, ['orchestrate/SKILL.md'], `${plugin}: exported skills`);
  const file = `${plugin}/skills/orchestrate/SKILL.md`;
  const frontmatter = /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/.exec(fs.readFileSync(file, 'utf8'))?.[1];
  assert.ok(frontmatter, `${file}: frontmatter`);
  let meta;
  try {
    meta = parseYaml(frontmatter);
  } catch (error) {
    assert.fail(`${file}: invalid frontmatter (${error.reason})`);
  }
  assert.ok(meta && typeof meta === 'object' && !Array.isArray(meta), `${file}: frontmatter mapping`);
  assert.equal(meta.name, 'orchestrate', `${file}: name`);
  assert.equal(meta['disable-model-invocation'], true, `${file}: disable-model-invocation`);
  assert.ok(!Object.hasOwn(meta, 'user-invocable') || meta['user-invocable'] === true, `${file}: user-invocable`);

  const mirror = `${plugin}/runtime`;
  const mirrorPath = path.join(installedRoot ?? '.', mirror);
  const mirrorStat = fs.lstatSync(mirrorPath, { throwIfNoEntry: false });
  if (installedRoot || mirrorStat) assert.ok(mirrorStat?.isDirectory(), `${mirror}: directory`);
  for (const [base, relative] of runtime) {
    const source = path.join(base, relative);
    assert.ok(fs.lstatSync(source, { throwIfNoEntry: false })?.isFile(), `${source}: canonical runtime`);
    if (!mirrorStat) continue;
    const target = path.join(mirrorPath, relative);
    assert.ok(fs.lstatSync(path.dirname(target), { throwIfNoEntry: false })?.isDirectory()
      && fs.lstatSync(target, { throwIfNoEntry: false })?.isFile()
      && fs.readFileSync(source).equals(fs.readFileSync(target)), `${mirror}/${relative}: runtime mirror`);
  }
}
