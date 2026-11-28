import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');

function runNode(scriptRel, args = [], opts = {}) {
  const scriptAbs = path.isAbsolute(scriptRel) ? scriptRel : path.join(REPO_ROOT, scriptRel);
  return spawnSync(process.execPath, [scriptAbs, ...args], {
    cwd: opts.cwd || REPO_ROOT,
    encoding: 'utf8',
    env: { ...process.env, ...(opts.env || {}) },
  });
}

function runGit(args, cwd) {
  const res = spawnSync('git', args, { cwd, encoding: 'utf8' });
  assert.equal(res.status, 0, `git ${args.join(' ')} failed:\n${res.stdout}\n${res.stderr}`);
  return res.stdout.trim();
}

function copyTree(src, dst) {
  fs.cpSync(src, dst, {
    recursive: true,
    filter: (p) => {
      const base = path.basename(p);
      return base !== '.git' && base !== 'node_modules' && base !== 'dist-test' && base !== '.worktrees';
    },
  });
}

describe('SSOT Unification v2.2 — Phase 1: Unified CLI & Contracts Sync (AC-001, AC-002)', () => {
  it('AC-001: sync-ssot.mjs --check is CLEAN across all targets on live repo', () => {
    const res = runNode('scripts/sync-ssot.mjs', ['--check']);
    assert.equal(res.status, 0, `sync-ssot --check failed:\n${res.stdout}\n${res.stderr}`);
    assert.match(res.stdout, /CLEAN/);
  });

  it('AC-001: sync-ssot.mjs is idempotent on a copy of the repo', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-ssot-idemp-'));
    try {
      for (const rel of [
        'contracts',
        'plugins',
        '.agents',
        '.claude-plugin',
        '.codex',
        'docs',
        'mcp',
        'install.sh',
        'install.ps1',
        'README.md',
        'AGENTS.md',
        'PLUGIN-CONTRACTS.md',
        '.github/workflows',
      ]) {
        const src = path.join(REPO_ROOT, rel);
        if (fs.existsSync(src)) {
          fs.mkdirSync(path.dirname(path.join(tmp, rel)), { recursive: true });
          copyTree(src, path.join(tmp, rel));
        }
      }
      const res = runNode('scripts/sync-ssot.mjs', ['--root', tmp, '--json']);
      assert.equal(res.status, 0, res.stderr || res.stdout);
      const report = JSON.parse(res.stdout);
      assert.equal(report.exitCode, 0);
      assert.deepEqual(report.updated, [], `Expected 0 updates on clean tree, got: ${JSON.stringify(report.updated)}`);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  it('AC-002: detects contract drift (exit 1 + remediation + --json) and fails closed on broken JSON/markers (exit 2)', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-ssot-neg-'));
    try {
      copyTree(path.join(REPO_ROOT, 'contracts'), path.join(tmp, 'contracts'));
      copyTree(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/contracts'), path.join(tmp, 'plugins/sdd-quality-loop/contracts'));
      copyTree(path.join(REPO_ROOT, 'docs/agent-capability-matrix.md'), path.join(tmp, 'docs/agent-capability-matrix.md'));

      // 1. Synthetic contract drift -> exit 1 with remediation command
      const copyFile = path.join(tmp, 'plugins/sdd-quality-loop/contracts/capability-registry.json');
      fs.appendFileSync(copyFile, '\n// drift\n', 'utf8');
      const driftRes = runNode('scripts/sync-ssot.mjs', ['--root', tmp, '--target', 'contracts', '--check']);
      assert.equal(driftRes.status, 1);
      assert.match(driftRes.stderr, /node scripts\/sync-ssot\.mjs --target contracts/);

      const driftJson = runNode('scripts/sync-ssot.mjs', ['--root', tmp, '--target', 'contracts', '--check', '--json']);
      assert.equal(driftJson.status, 1);
      const parsed = JSON.parse(driftJson.stdout);
      assert.ok(parsed.violations.some((v) => v.file === 'plugins/sdd-quality-loop/contracts/capability-registry.json'));

      // 2. Broken marker -> exit 2 (Fail-Closed)
      fs.writeFileSync(
        path.join(tmp, 'docs/agent-capability-matrix.md'),
        '# Broken\n<!-- BEGIN GENERATED:capability-matrix-tiers -->\nno closing marker\n',
        'utf8',
      );
      const brokenMarker = runNode('scripts/sync-ssot.mjs', ['--root', tmp, '--target', 'contracts', '--check']);
      assert.equal(brokenMarker.status, 2);

      // 3. Malformed JSON in release-manifest.json -> exit 2 (Fail-Closed)
      fs.writeFileSync(path.join(tmp, 'contracts/release-manifest.json'), '{not-valid-json', 'utf8');
      const malformed = runNode('scripts/sync-ssot.mjs', ['--root', tmp, '--target', 'release', '--check']);
      assert.equal(malformed.status, 2);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe('SSOT Unification v2.2 — Phase 2: Multi-CLI Manifests & Agents SSOT (AC-003, AC-004, AC-005)', () => {
  it('AC-003 & AC-004: all 8 plugin.manifest.json exist, Gemini name is unified, .gitattributes marks generated files, unregistered plugin fails closed', () => {
    const plugins = [
      'sdd-bootstrap',
      'sdd-ship',
      'sdd-implementation',
      'sdd-quality-loop',
      'sdd-review-loop',
      'sdd-domain',
      'sdd-azure-cloud',
      'sdd-aws-cloud',
    ];
    for (const p of plugins) {
      assert.equal(fs.existsSync(path.join(REPO_ROOT, 'plugins', p, 'plugin.manifest.json')), true, `Missing plugin.manifest.json for ${p}`);
      const claude = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'plugins', p, '.claude-plugin/plugin.json'), 'utf8'));
      assert.ok(Array.isArray(claude.skills), `${p} Claude skills must be normalized to array`);
    }

    const implGemini = JSON.parse(
      fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-implementation/gemini/gemini-extension.json'), 'utf8'),
    );
    assert.equal(implGemini.name, 'sdd-implementation');

    const uninstallSh = fs.readFileSync(path.join(REPO_ROOT, 'uninstall.sh'), 'utf8');
    const uninstallPs = fs.readFileSync(path.join(REPO_ROOT, 'uninstall.ps1'), 'utf8');
    assert.doesNotMatch(uninstallSh, /sdd-forge-model-selection/);
    assert.doesNotMatch(uninstallPs, /sdd-forge-model-selection/);

    const gitattrs = fs.readFileSync(path.join(REPO_ROOT, '.gitattributes'), 'utf8');
    assert.match(gitattrs, /linguist-generated=true/);
    assert.match(gitattrs, /\.codex\/agents\/\*\.toml\s+linguist-generated=true/);

    // Negative test: unregistered plugin dir without plugin.manifest.json -> exit 2
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-ssot-unreg-'));
    try {
      copyTree(path.join(REPO_ROOT, 'contracts'), path.join(tmp, 'contracts'));
      copyTree(path.join(REPO_ROOT, 'plugins'), path.join(tmp, 'plugins'));
      copyTree(path.join(REPO_ROOT, '.agents'), path.join(tmp, '.agents'));
      copyTree(path.join(REPO_ROOT, '.claude-plugin'), path.join(tmp, '.claude-plugin'));
      fs.mkdirSync(path.join(tmp, 'plugins/sdd-rogue-plugin'), { recursive: true });
      const res = runNode('scripts/sync-ssot.mjs', ['--root', tmp, '--target', 'manifests', '--check']);
      assert.equal(res.status, 2);
      assert.match(res.stderr, /sdd-rogue-plugin/);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  it('AC-005: all 8 agent.yaml render cleanly with Codex tool parity, model comments, 6 canonical blocks, and retired frontmatter scripts removed', () => {
    const roles = [
      'sdd-investigator',
      'sdd-evaluator',
      'spec-reviewer-a',
      'spec-reviewer-b',
      'domain-reviewer-a',
      'domain-reviewer-b',
      'wfi-auditor-a',
      'wfi-auditor-b',
    ];
    for (const r of roles) {
      assert.equal(fs.existsSync(path.join(REPO_ROOT, 'contracts/agents', `${r}.agent.yaml`)), true, `Missing ${r}.agent.yaml`);
    }

    for (const tomlName of fs.readdirSync(path.join(REPO_ROOT, '.codex/agents')).filter((f) => f.endsWith('.toml'))) {
      const content = fs.readFileSync(path.join(REPO_ROOT, '.codex/agents', tomlName), 'utf8');
      assert.doesNotMatch(content, /Read, Grep, or Glob/, `${tomlName} must not contain Claude-only tool names`);
      assert.match(content, /^# x-sdd-model:/m, `${tomlName} must preserve # x-sdd-model comment`);
      assert.match(content, /^# x-sdd-effort:/m, `${tomlName} must preserve # x-sdd-effort comment`);
      assert.match(content, /STATUS: COMPLETE \| PARTIAL \| NOT_FOUND \| BLOCKED/);
    }

    assert.equal(fs.existsSync(path.join(REPO_ROOT, 'plugins/sdd-implementation/scripts/render-agent-frontmatter.sh')), false);
    assert.equal(fs.existsSync(path.join(REPO_ROOT, 'plugins/sdd-implementation/scripts/render-agent-frontmatter.ps1')), false);
  });
});

describe('SSOT Unification v2.2 — Phase 3: Release, Node 26.13+, CI & Conventions (AC-006, AC-007, AC-008, AC-009)', () => {
  it('AC-006 & AC-008: release-manifest.json drives MCP packages (26.13.0), installers, bump-version.sh, and detects unregistered MCP version drift', () => {
    const manifest = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'contracts/release-manifest.json'), 'utf8'));
    assert.equal(manifest.minNodeVersion, '26.13.0');
    assert.equal(manifest.nodeCiVersion, '26.13.0');

    for (const mcpName of ['sdd-forge-mcp', 'ci-mcp', 'local-env-mcp']) {
      const pkg = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'mcp', mcpName, 'package.json'), 'utf8'));
      assert.equal(pkg.version, manifest.version, `${mcpName} version mismatch`);
      assert.equal(pkg.engines?.node, `>=${manifest.minNodeVersion}`, `${mcpName} engines.node mismatch`);
    }

    const bump = fs.readFileSync(path.join(REPO_ROOT, 'scripts/bump-version.sh'), 'utf8');
    assert.match(bump, /sync-ssot\.mjs/);
    assert.doesNotMatch(bump, /\bsed\s+-i/);

    const installSh = fs.readFileSync(path.join(REPO_ROOT, 'install.sh'), 'utf8');
    const installPs = fs.readFileSync(path.join(REPO_ROOT, 'install.ps1'), 'utf8');
    assert.match(installSh, /min_node_display="26\.13\.0"/);
    assert.match(installPs, /\$script:MinNodeVersion = "26\.13\.0"/);

    // Negative test: new MCP package with stale version triggers exit 1
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-ssot-mcp-'));
    try {
      copyTree(path.join(REPO_ROOT, 'contracts'), path.join(tmp, 'contracts'));
      copyTree(path.join(REPO_ROOT, 'mcp'), path.join(tmp, 'mcp'));
      fs.mkdirSync(path.join(tmp, 'mcp/new-mcp'), { recursive: true });
      fs.writeFileSync(
        path.join(tmp, 'mcp/new-mcp/package.json'),
        JSON.stringify({ name: 'new-mcp', version: '0.0.1', engines: { node: '>=20.0.0' } }, null, 2) + '\n',
        'utf8',
      );
      const res = runNode('scripts/sync-ssot.mjs', ['--root', tmp, '--target', 'release', '--check']);
      assert.equal(res.status, 1);
      assert.match(res.stderr, /mcp\/new-mcp\/package\.json/);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  it('AC-007: test.yml enforces ssot-sync-check & test-lifecycle-check with no paths filter, Node 26.13.0, and fail-closed pwsh parity', () => {
    const wf = fs.readFileSync(path.join(REPO_ROOT, '.github/workflows/test.yml'), 'utf8');
    assert.doesNotMatch(wf, /^\s+paths:/m, 'test.yml must not skip required checks via paths filters');
    assert.match(wf, /\n  ssot-sync-check:\n/);
    assert.match(wf, /\n  test-lifecycle-check:\n/);
    assert.match(wf, /sync-ssot\.mjs --check/);
    assert.match(wf, /ssot-unification-v22\.test\.mjs/);
    assert.match(wf, /SDD_REQUIRE_PWSH:\s*"1"/);
    assert.match(wf, /node-version:\s*"26\.13\.0"/);
    assert.doesNotMatch(wf, /node-version:\s*"?20"?/);
    const agg = wf.slice(wf.indexOf('\n  required-checks:'));
    assert.match(agg, /ssot-sync-check/);
    assert.match(agg, /test-lifecycle-check/);
  });

  it('AC-009: root AGENTS.md <= 100 lines, zero CLAUDE.md, pitfalls synced to 5 language docs, R-01..R-05 documented, CODEOWNERS protects SSOT', () => {
    const agentsText = fs.readFileSync(path.join(REPO_ROOT, 'AGENTS.md'), 'utf8');
    const lines = agentsText.trimEnd().split('\n').length;
    assert.ok(lines <= 100, `Root AGENTS.md has ${lines} lines; must be <= 100`);
    assert.match(agentsText, /^## Required Workflow$/m);
    assert.match(agentsText, /^## Active Spec Directories$/m);

    for (const sub of ['mcp/AGENTS.md', 'plugins/AGENTS.md', 'tests/AGENTS.md', 'docs/coding-conventions.md']) {
      assert.equal(fs.existsSync(path.join(REPO_ROOT, sub)), true, `Missing ${sub}`);
    }
    const conv = fs.readFileSync(path.join(REPO_ROOT, 'docs/coding-conventions.md'), 'utf8');
    for (const rule of ['R-01', 'R-02', 'R-03', 'R-04', 'R-05']) {
      assert.match(conv, new RegExp(`\\b${rule}\\b`), `docs/coding-conventions.md missing ${rule}`);
    }

    const owners = fs.readFileSync(path.join(REPO_ROOT, 'CODEOWNERS'), 'utf8');
    for (const protectedPath of [
      '/contracts/',
      '/scripts/sync-ssot.mjs',
      '/sdd/approved-test-retirements.json',
      '/docs/coding-conventions.md',
    ]) {
      assert.ok(owners.includes(protectedPath), `CODEOWNERS must protect ${protectedPath}`);
    }

    // Negative test: creating a CLAUDE.md fails conventions check
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-ssot-claude-'));
    try {
      copyTree(path.join(REPO_ROOT, 'contracts'), path.join(tmp, 'contracts'));
      copyTree(path.join(REPO_ROOT, 'docs/contributor/coding-standards'), path.join(tmp, 'docs/contributor/coding-standards'));
      fs.copyFileSync(path.join(REPO_ROOT, 'AGENTS.md'), path.join(tmp, 'AGENTS.md'));
      fs.writeFileSync(path.join(tmp, 'CLAUDE.md'), '# Forbidden duplicate\n', 'utf8');
      const res = runNode('scripts/sync-ssot.mjs', ['--root', tmp, '--target', 'conventions', '--check']);
      assert.equal(res.status, 1);
      assert.match(res.stderr, /CLAUDE\.md/);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe('SSOT Unification v2.2 — Phase 4: Dynamic TIA, Safe Test Retirement & Pitfalls Harvesting (AC-010, AC-011)', () => {
  it('AC-010: verification-catalog-status --check passes on live repo and check-ecosystem-impact enforces safe retirement + ghost test detection', () => {
    const vc = runNode('tests/verification-catalog-status.mjs', ['--check']);
    assert.equal(vc.status, 0, vc.stderr || vc.stdout);

    // Build disposable git repo to test unapproved delete, ghost test, and approved delete
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-tia-'));
    try {
      runGit(['init', '-b', 'main'], tmp);
      runGit(['config', 'user.email', 'test@example.com'], tmp);
      runGit(['config', 'user.name', 'Test'], tmp);
      fs.mkdirSync(path.join(tmp, 'scripts'), { recursive: true });
      fs.mkdirSync(path.join(tmp, 'tests'), { recursive: true });
      fs.mkdirSync(path.join(tmp, 'sdd'), { recursive: true });

      fs.writeFileSync(path.join(tmp, 'scripts/foo.mjs'), 'export const x = 1;\n', 'utf8');
      fs.writeFileSync(path.join(tmp, 'tests/foo.test.mjs'), '// tests scripts/foo.mjs\n', 'utf8');
      fs.writeFileSync(path.join(tmp, 'tests/bar.test.mjs'), '// standalone\n', 'utf8');
      fs.writeFileSync(
        path.join(tmp, 'tests/verification-catalog.json'),
        JSON.stringify({ schema: 'verification-catalog/v1', suites: [{ path: 'tests/foo.test.mjs', runtime: 'node' }, { path: 'tests/bar.test.mjs', runtime: 'node' }] }, null, 2) + '\n',
        'utf8',
      );
      fs.writeFileSync(
        path.join(tmp, 'sdd/approved-test-retirements.json'),
        JSON.stringify({ schema: 'approved-test-retirements/v1', retirements: [] }, null, 2) + '\n',
        'utf8',
      );
      runGit(['add', '.'], tmp);
      runGit(['commit', '-m', 'base'], tmp);
      const baseSha = runGit(['rev-parse', 'HEAD'], tmp);
      const barBlobSha = runGit(['rev-parse', 'HEAD:tests/bar.test.mjs'], tmp);

      // Case 1: unapproved deletion of tests/bar.test.mjs -> exit 1
      fs.unlinkSync(path.join(tmp, 'tests/bar.test.mjs'));
      runGit(['add', '-A'], tmp);
      runGit(['commit', '-m', 'delete bar without approval'], tmp);
      const unapproved = runNode('scripts/check-ecosystem-impact.mjs', ['--root', tmp, '--base', baseSha, '--head', 'HEAD', '--json']);
      assert.equal(unapproved.status, 1);
      assert.ok(JSON.parse(unapproved.stdout).violations.some((v) => v.event === 'D' && v.file === 'tests/bar.test.mjs'));

      // Case 2: approve deletion with matching git_blob_sha + negative_parity_verified: true -> exit 0
      fs.writeFileSync(
        path.join(tmp, 'sdd/approved-test-retirements.json'),
        JSON.stringify({
          schema: 'approved-test-retirements/v1',
          retirements: [
            {
              test_path: 'tests/bar.test.mjs',
              git_blob_sha: barBlobSha,
              reason: 'Superseded by unified test',
              replaced_by_or_retired_feature: 'tests/ssot-unification-v22.test.mjs',
              negative_parity_verified: true,
              approved_by: '@maintainer',
            },
          ],
        }, null, 2) + '\n',
        'utf8',
      );
      runGit(['add', '-A'], tmp);
      runGit(['commit', '-m', 'approve bar retirement'], tmp);
      const approved = runNode('scripts/check-ecosystem-impact.mjs', ['--root', tmp, '--base', baseSha, '--head', 'HEAD', '--json']);
      assert.equal(approved.status, 0, approved.stdout + approved.stderr);

      // Case 3: delete scripts/foo.mjs while tests/foo.test.mjs still references it -> ghost test exit 1
      fs.unlinkSync(path.join(tmp, 'scripts/foo.mjs'));
      runGit(['add', '-A'], tmp);
      runGit(['commit', '-m', 'delete foo script leaving ghost test'], tmp);
      const ghost = runNode('scripts/check-ecosystem-impact.mjs', ['--root', tmp, '--base', baseSha, '--head', 'HEAD', '--json']);
      assert.equal(ghost.status, 1);
      assert.ok(JSON.parse(ghost.stdout).violations.some((v) => /Ghost test/i.test(v.reason)));
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });

  it('AC-011: harvest-pitfalls --check passes on live repo and blocks unescalated 2x occurrences; docs markers are synced', () => {
    const live = runNode('scripts/harvest-pitfalls.mjs', ['--check']);
    assert.equal(live.status, 0, live.stderr || live.stdout);

    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-harvest-'));
    try {
      fs.mkdirSync(path.join(tmp, 'contracts'), { recursive: true });
      fs.writeFileSync(
        path.join(tmp, 'contracts/pitfalls-catalog.json'),
        JSON.stringify({
          schema: 'pitfalls-catalog/v1',
          pitfalls: [
            {
              id: 'PIT-TEST-001',
              languages: ['common'],
              severity: 'high',
              symptom: 'Repeated bug',
              good_pattern: 'Fix it',
              detection_layer: 'review',
              status: 'active',
              occurrences: 2,
            },
          ],
        }, null, 2) + '\n',
        'utf8',
      );
      const neg = runNode('scripts/harvest-pitfalls.mjs', ['--root', tmp, '--check']);
      assert.equal(neg.status, 1);
      assert.match(neg.stderr, /PIT-TEST-001/);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }

    const pluginContracts = fs.readFileSync(path.join(REPO_ROOT, 'PLUGIN-CONTRACTS.md'), 'utf8');
    const skillRef = fs.readFileSync(path.join(REPO_ROOT, 'docs/skill-reference.md'), 'utf8');
    assert.match(pluginContracts, /BEGIN GENERATED:plugin-contracts-summary/);
    assert.match(skillRef, /BEGIN GENERATED:skill-reference-summary/);
  });
});

describe('SSOT Unification v2.2 — Phase 5: User-Project Governance Productization E2E (AC-012)', () => {
  it('AC-012: init-project-governance -> inject-pitfalls -> check-architecture-fitness -> compound-pitfalls full lifecycle', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-user-proj-'));
    try {
      // Simulate a TypeScript + Python project
      fs.writeFileSync(path.join(tmp, 'package.json'), JSON.stringify({ name: 'sample-app', version: '1.0.0' }), 'utf8');
      fs.writeFileSync(path.join(tmp, 'pyproject.toml'), '[project]\nname = "sample"\n', 'utf8');

      // 1. init-project-governance (standard tier)
      const initRes = runNode('plugins/sdd-bootstrap/scripts/init-project-governance.mjs', ['--root', tmp, '--tier', 'standard', '--json']);
      assert.equal(initRes.status, 0, initRes.stderr || initRes.stdout);
      const initJson = JSON.parse(initRes.stdout);
      assert.equal(initJson.dddTier, 'standard');
      assert.ok(initJson.languages.includes('ts-js'));
      assert.ok(initJson.languages.includes('python'));

      const agentsLines = fs.readFileSync(path.join(tmp, 'AGENTS.md'), 'utf8').trimEnd().split('\n').length;
      assert.ok(agentsLines <= 100, `Scaffolded AGENTS.md must be <= 100 lines, got ${agentsLines}`);
      assert.equal(fs.existsSync(path.join(tmp, 'CLAUDE.md')), false, 'Must not scaffold CLAUDE.md');
      for (const expected of [
        'sdd/glossary.json',
        'sdd/context-map.json',
        'sdd/pitfalls-catalog.json',
        'sdd/verification-catalog.json',
        'sdd/approved-test-retirements.json',
        '.gitattributes',
      ]) {
        assert.equal(fs.existsSync(path.join(tmp, expected)), true, `Missing scaffolded file: ${expected}`);
      }

      // 2. compound-pitfalls: record 1st occurrence (active) then 2nd occurrence (escalateToMechanical: true)
      const c1 = runNode('plugins/sdd-review-loop/scripts/compound-pitfalls.mjs', [
        '--root', tmp,
        '--id', 'PIT-APP-001',
        '--language', 'ts-js',
        '--severity', 'high',
        '--symptom', 'Unhandled promise rejection in API handler',
        '--good-pattern', 'Wrap async routes in error middleware',
        '--source', 'PR-101',
        '--apply',
        '--json',
      ]);
      assert.equal(c1.status, 0, c1.stderr);
      assert.equal(JSON.parse(c1.stdout).escalateToMechanical, false);

      const c2 = runNode('plugins/sdd-review-loop/scripts/compound-pitfalls.mjs', [
        '--root', tmp,
        '--id', 'PIT-APP-001',
        '--language', 'ts-js',
        '--severity', 'high',
        '--symptom', 'Unhandled promise rejection in API handler',
        '--good-pattern', 'Wrap async routes in error middleware',
        '--apply',
        '--json',
      ]);
      assert.equal(c2.status, 0, c2.stderr);
      const c2Json = JSON.parse(c2.stdout);
      assert.equal(c2Json.entry.occurrences, 2);
      assert.equal(c2Json.escalateToMechanical, true);

      // 3. inject-pitfalls (Progressive Disclosure): ts file gets ts-js pitfall, py file does not get ts-js-only pitfall
      const injTs = runNode('plugins/sdd-implementation/scripts/inject-pitfalls.mjs', ['--root', tmp, '--files', 'src/core/app.ts', '--json']);
      assert.equal(injTs.status, 0, injTs.stderr);
      assert.ok(JSON.parse(injTs.stdout).pitfalls.some((p) => p.id === 'PIT-APP-001'));

      const injPy = runNode('plugins/sdd-implementation/scripts/inject-pitfalls.mjs', ['--root', tmp, '--files', 'scripts/job.py', '--json']);
      assert.equal(injPy.status, 0, injPy.stderr);
      assert.equal(JSON.parse(injPy.stdout).pitfalls.some((p) => p.id === 'PIT-APP-001'), false);

      // 4. check-architecture-fitness: PASS on clean DDD layout
      fs.writeFileSync(
        path.join(tmp, 'sdd/context-map.json'),
        JSON.stringify({
          schema: 'context-map/v1',
          tier: 'standard',
          fitnessRules: { domainIsolated: true, contextViaApi: true },
          contexts: [
            {
              name: 'ordering',
              rootDir: 'src/ordering',
              domainDir: 'src/ordering/domain',
              publicApi: 'src/ordering/index.ts',
              allowedDependencies: ['billing'],
            },
            {
              name: 'billing',
              rootDir: 'src/billing',
              domainDir: 'src/billing/domain',
              publicApi: 'src/billing/index.ts',
              allowedDependencies: [],
            },
          ],
        }, null, 2) + '\n',
        'utf8',
      );
      fs.writeFileSync(
        path.join(tmp, 'sdd/glossary.json'),
        JSON.stringify({
          schema: 'glossary/v1',
          terms: [
            { canonical: 'AccountHolder', forbiddenSynonyms: ['CustomerUser'], boundedContext: 'ordering' },
          ],
        }, null, 2) + '\n',
        'utf8',
      );
      fs.mkdirSync(path.join(tmp, 'src/ordering/domain'), { recursive: true });
      fs.mkdirSync(path.join(tmp, 'src/billing/internal'), { recursive: true });
      fs.writeFileSync(path.join(tmp, 'src/ordering/domain/order.ts'), 'export interface Order { holder: string; }\n', 'utf8');
      fs.writeFileSync(path.join(tmp, 'src/billing/internal/ledger.ts'), 'export const ledger = [];\n', 'utf8');
      fs.writeFileSync(path.join(tmp, 'src/billing/index.ts'), 'export { ledger } from "./internal/ledger.js";\n', 'utf8');

      const fitPass = runNode('plugins/sdd-quality-loop/scripts/v2/check-architecture-fitness.mjs', ['--root', tmp, '--json']);
      assert.equal(fitPass.status, 0, fitPass.stdout + fitPass.stderr);

      // 5. Introduce all 4 violations -> FAIL with all 4 rules detected
      fs.writeFileSync(
        path.join(tmp, 'src/ordering/domain/bad-order.ts'),
        'import { db } from "../../infrastructure/db.js";\nimport { ledger } from "../../billing/internal/ledger.js";\nexport const CustomerUser = { db, ledger };\n',
        'utf8',
      );
      fs.writeFileSync(path.join(tmp, 'CLAUDE.md'), '# Bad duplicate\n', 'utf8');

      const fitFail = runNode('plugins/sdd-quality-loop/scripts/v2/check-architecture-fitness.mjs', ['--root', tmp, '--json']);
      assert.equal(fitFail.status, 1);
      const rules = new Set(JSON.parse(fitFail.stdout).violations.map((v) => v.rule));
      assert.ok(rules.has('domain-isolated'), `Expected domain-isolated, got ${[...rules]}`);
      assert.ok(rules.has('context-via-api'), `Expected context-via-api, got ${[...rules]}`);
      assert.ok(rules.has('ubiquitous-language'), `Expected ubiquitous-language, got ${[...rules]}`);
      assert.ok(rules.has('context-hygiene-r04'), `Expected context-hygiene-r04, got ${[...rules]}`);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });
});
