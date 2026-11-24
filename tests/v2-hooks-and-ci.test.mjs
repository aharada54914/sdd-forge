import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');

describe('Phase 3-4: 4-host hooks, legacy removal, CI workflow, and installer', () => {
  it('all 4 host hook manifests parse as valid JSON and wire to v2/sdd-soft-guard.mjs', () => {
    const claude = JSON.parse(
      fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/hooks/claude-hooks.json'), 'utf8'),
    );
    const codex = JSON.parse(
      fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/hooks/codex-hooks.json'), 'utf8'),
    );
    const copilot = JSON.parse(
      fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/hooks/copilot-hooks.json'), 'utf8'),
    );
    const gemini = JSON.parse(
      fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/gemini/hooks/hooks.json'), 'utf8'),
    );

    assert.match(JSON.stringify(claude), /scripts\/v2\/sdd-soft-guard\.mjs/);
    assert.match(JSON.stringify(codex), /scripts\/v2\/sdd-soft-guard\.mjs/);
    assert.match(JSON.stringify(copilot), /scripts\/v2\/sdd-soft-guard\.mjs/);
    assert.match(JSON.stringify(gemini), /scripts\/v2\/sdd-soft-guard\.mjs/);

    assert.doesNotMatch(JSON.stringify(claude), /sdd-hook-guard|kill-switch/);
    assert.doesNotMatch(JSON.stringify(codex), /sdd-hook-guard|kill-switch/);
    assert.doesNotMatch(JSON.stringify(copilot), /sdd-hook-guard/);
    assert.doesNotMatch(JSON.stringify(gemini), /sdd-hook-guard/);
  });

  it('deprecated hard-lock scripts, 3-loop reviews, and sdd-lite plugin are removed', () => {
    const removedPaths = [
      'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py',
      'plugins/sdd-quality-loop/scripts/sdd-hook-guard.js',
      'plugins/sdd-quality-loop/scripts/sdd-hook-guard.ps1',
      'plugins/sdd-quality-loop/scripts/sdd-hook-guard.sh',
      'plugins/sdd-quality-loop/references/guard-invariants.json',
      'plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py',
      'plugins/sdd-quality-loop/skills/sdd-sudo',
      'plugins/sdd-quality-loop/skills/cross-model-verify',
      'plugins/sdd-review-loop/skills/spec-review-loop',
      'plugins/sdd-review-loop/skills/impl-review-loop',
      'plugins/sdd-review-loop/skills/task-review-loop',
      'plugins/sdd-lite',
    ];
    for (const rel of removedPaths) {
      assert.equal(fs.existsSync(path.join(REPO_ROOT, rel)), false, `${rel} should be removed`);
    }
  });

  it('CI workflow and CODEOWNERS cover Layer 3 guardrails boundary', () => {
    const ci = fs.readFileSync(path.join(REPO_ROOT, '.github/workflows/sdd-guardrails.yml'), 'utf8');
    assert.match(ci, /node --test tests\/v2-soft-guard\.test\.mjs/);
    assert.match(ci, /check-spec-drift\.mjs/);
    assert.match(ci, /--fail-on-undeclared/);

    const owners = fs.readFileSync(path.join(REPO_ROOT, 'CODEOWNERS'), 'utf8');
    assert.match(owners, /\/plugins\/sdd-quality-loop\/hooks\//);
    assert.match(owners, /\/specs\//);
    assert.match(owners, /\/contracts\/guardrails\.schema\.json/);
  });

  it(
    'install.sh --target FilesOnly succeeds end-to-end and installs v2 guardrail scripts',
    { skip: process.platform === 'win32' },
    () => {
      const installRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-v2-install-'));
      const res = spawnSync(
        'bash',
        [
          path.join(REPO_ROOT, 'install.sh'),
          '--source-directory',
          REPO_ROOT,
          '--install-root',
          installRoot,
          '--target',
          'FilesOnly',
          '--skip-mcp',
          '--skip-agent-install',
        ],
        { cwd: REPO_ROOT, encoding: 'utf8' },
      );
      assert.equal(res.status, 0, `install.sh failed:\nSTDOUT:\n${res.stdout}\nSTDERR:\n${res.stderr}`);
      assert.equal(
        fs.existsSync(path.join(installRoot, 'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs')),
        true,
      );
      assert.equal(
        fs.existsSync(path.join(installRoot, 'plugins/sdd-quality-loop/scripts/v2/check-spec-drift.mjs')),
        true,
      );
      assert.equal(
        fs.existsSync(path.join(installRoot, 'plugins/sdd-quality-loop/scripts/v2/run-sdd-gate.mjs')),
        true,
      );
      assert.equal(
        fs.existsSync(path.join(installRoot, 'plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs')),
        true,
      );
      assert.equal(
        fs.existsSync(path.join(installRoot, 'plugins/sdd-quality-loop/scripts/v2/render-decision-view.mjs')),
        true,
      );
      assert.equal(
        fs.existsSync(path.join(installRoot, 'plugins/sdd-quality-loop/scripts/v2/check-traceability.mjs')),
        true,
      );
      assert.equal(fs.existsSync(path.join(installRoot, 'plugins/sdd-lite')), false);
    },
  );

  it('v1.26.1 (#789): session-model-start.py emits valid UTF-8 JSON under ASCII stdout across 3 AI hosts', () => {
    const py = process.platform === 'win32' ? 'python' : 'python3';
    const script = path.join(REPO_ROOT, 'plugins/sdd-implementation/scripts/session-model-start.py');
    const tmpProject = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-session-utf8-'));
    fs.mkdirSync(path.join(tmpProject, 'specs', 'demo'), { recursive: true });
    fs.writeFileSync(path.join(tmpProject, 'specs', 'demo', 'tasks.md'), '# Tasks\n', 'utf8');

    for (const host of ['claude-code', 'codex-cli', 'gemini-cli']) {
      const res = spawnSync(py, [script, '--host', host], {
        cwd: tmpProject,
        input: JSON.stringify({ cwd: tmpProject }),
        env: { ...process.env, PYTHONIOENCODING: 'ascii' },
      });
      assert.equal(res.status, 0, `${host} failed: ${res.stderr?.toString('utf8')}`);
      const outText = res.stdout.toString('utf8').trim();
      if (outText.length > 0) {
        const parsed = JSON.parse(outText);
        assert.equal(parsed.hookSpecificOutput.hookEventName, 'SessionStart');
        assert.ok(typeof parsed.hookSpecificOutput.additionalContext === 'string' && parsed.hookSpecificOutput.additionalContext.length > 0);
      }
    }
  });

  it('#852: Spec Drift CI reports its coverage and lists approved features without a baseline', () => {
    const wf = fs.readFileSync(path.join(REPO_ROOT, '.github/workflows/sdd-guardrails.yml'), 'utf8');
    assert.match(wf, /Spec Drift coverage: \$\{checked\} baselined feature/);
    assert.match(wf, /unbaselined\.push\(entry\.name\)/);
    assert.match(wf, /::warning title=Spec Drift not covered::/);
    const threat = fs.readFileSync(path.join(REPO_ROOT, 'docs/THREAT-MODEL.md'), 'utf8');
    assert.doesNotMatch(threat, /100% 捕捉/);
    const readme = fs.readFileSync(path.join(REPO_ROOT, 'README.md'), 'utf8');
    assert.doesNotMatch(readme, /PR\/CI で確実に抑止/);
  });

  it('#861: Bash and PowerShell installers require the same Cloud entry files', () => {
    const sh = fs.readFileSync(path.join(REPO_ROOT, 'install.sh'), 'utf8');
    const ps = fs.readFileSync(path.join(REPO_ROOT, 'install.ps1'), 'utf8');
    const shList = /^CLOUD_ENTRY_FILES=\(([^)]*)\)/m.exec(sh);
    const psList = /^\$cloudEntryFiles = @\(([^)]*)\)/m.exec(ps);
    assert.ok(shList && psList, 'both installers must declare a Cloud entry file list');
    const norm = (raw) => raw.split(/[\s,]+/).map((x) => x.replace(/"/g, '')).filter(Boolean).sort();
    assert.deepEqual(norm(psList[1]), norm(shList[1]));
    assert.ok(norm(shList[1]).includes('.antigravity-plugin/plugin.json'));
  });

  it('publish-release cuts a tag only by manual dispatch on main, never moving an existing tag', () => {
    const wf = fs.readFileSync(path.join(REPO_ROOT, '.github/workflows/publish-release.yml'), 'utf8');
    const on = wf.slice(wf.indexOf('\non:'), wf.indexOf('\npermissions:'));
    assert.match(on, /workflow_dispatch:/);
    assert.doesNotMatch(on, /\b(push|pull_request|pull_request_target|schedule|release):/, 'only a manual dispatch may cut a release');
    assert.match(wf, /if: \$\{\{ github\.ref == 'refs\/heads\/main' \}\}/);
    assert.match(wf, /\^\[0-9\]\+\\\.\[0-9\]\+\\\.\[0-9\]\+\$/, 'version must be strictly X.Y.Z');
    assert.match(wf, /\^\[0-9a-f\]\{40\}\$/, 'commit must be a full SHA that no tag can shadow');
    assert.match(wf, /rev-list --first-parent "\$GITHUB_SHA" \| grep -x "\$TARGET" >\/dev\/null/, 'release commit must be on main\'s first-parent line');
    assert.doesNotMatch(wf, /\| grep -q/, 'grep -q under pipefail can SIGPIPE the producer');
    assert.match(wf, /git\/ref\/tags\/\$\{TAG\}/, 'exact-match tag lookup');
    assert.match(wf, /HTTP 404/, 'only a 404 means the tag is absent');
    assert.match(wf, /already exists; refusing to move it/);
    assert.match(wf, /workflows\/test\.yml\/runs\?head_sha=\$\{TARGET\}&status=success/, 'publish only after CI passed on the commit');
    assert.match(wf, /--method POST "repos\/\$\{GITHUB_REPOSITORY\}\/git\/refs"/, 'atomic tag creation');
    assert.match(wf, /gh release create "\$TAG" [^\n]*--verify-tag/);
    assert.match(wf, /gh workflow run release\.yml/, 'release.yml still runs every release gate');
    // Inputs reach shell only through env, never interpolated into run: scripts.
    for (const block of wf.split(/\n\s+run: /).slice(1)) {
      assert.doesNotMatch(block.split(/\n\s+- (?:name|uses):/)[0], /\$\{\{\s*inputs\./);
    }
  });

  it('no node_modules entry (directory or symlink) is ever tracked', () => {
    const tracked = spawnSync('git', ['ls-files', '-z'], { cwd: REPO_ROOT, encoding: 'utf8' });
    if (tracked.status !== 0) return; // not a git checkout (e.g. an extracted archive)
    const offenders = tracked.stdout.split('\0').filter((p) => /(^|\/)node_modules(\/|$)/.test(p));
    assert.deepEqual(offenders, []);
    for (const mcp of ['sdd-forge-mcp', 'ci-mcp', 'local-env-mcp']) {
      const ignore = fs.readFileSync(path.join(REPO_ROOT, 'mcp', mcp, '.gitignore'), 'utf8');
      assert.match(ignore, /^node_modules$/m, `${mcp}/.gitignore must ignore a node_modules symlink too`);
    }
  });

  it('#858: every workflow and distributed CI template pins third-party actions to a commit SHA', () => {
    const files = [];
    const wfDir = path.join(REPO_ROOT, '.github/workflows');
    for (const f of fs.readdirSync(wfDir)) if (/\.ya?ml$/.test(f)) files.push(path.join(wfDir, f));
    const tplDir = path.join(REPO_ROOT, 'plugins/sdd-bootstrap/skills/sdd-adopt/templates');
    for (const f of fs.readdirSync(tplDir)) if (/\.ya?ml$/.test(f)) files.push(path.join(tplDir, f));
    let seen = 0;
    for (const file of files) {
      for (const m of fs.readFileSync(file, 'utf8').matchAll(/^\s*-?\s*uses:\s*(\S+)/gm)) {
        const ref = m[1];
        if (ref.startsWith('./')) continue;
        seen += 1;
        assert.match(ref, /^[\w.-]+\/[\w./-]+@[0-9a-f]{40}$/, `${path.relative(REPO_ROOT, file)}: ${ref} is not SHA-pinned`);
      }
    }
    assert.ok(seen > 0);
  });

  it('#855: Claude never auto-loads a second hooks/hooks.json next to a manifest-declared hooks file', () => {
    const pluginsDir = path.join(REPO_ROOT, 'plugins');
    for (const name of fs.readdirSync(pluginsDir)) {
      const manifestPath = path.join(pluginsDir, name, '.claude-plugin', 'plugin.json');
      if (!fs.existsSync(manifestPath)) continue;
      const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
      if (typeof manifest.hooks !== 'string') continue;
      const declared = path.normalize(manifest.hooks);
      if (declared === path.normalize('./hooks/hooks.json')) continue;
      assert.equal(
        fs.existsSync(path.join(pluginsDir, name, 'hooks', 'hooks.json')),
        false,
        `${name}: Claude loads hooks/hooks.json in addition to ${manifest.hooks}, registering the guard twice`,
      );
    }
    const codex = JSON.parse(
      fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/.codex-plugin/plugin.json'), 'utf8'),
    );
    assert.equal(codex.hooks, './hooks/codex-hooks.json');
    assert.ok(fs.existsSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop', codex.hooks)));
  });

  it('#851/#801: required-checks aggregates every dependency result and installers job runs install suites', () => {
    const wf = fs.readFileSync(path.join(REPO_ROOT, '.github/workflows/test.yml'), 'utf8');
    const agg = wf.slice(wf.indexOf('\n  required-checks:'));
    assert.ok(agg.length > 1, 'required-checks job must exist');
    const needs = /needs:\s*\[([^\]]+)\]/.exec(agg);
    assert.ok(needs, 'required-checks must declare needs');
    const deps = needs[1].split(',').map((x) => x.trim());
    for (const job of ['v2-guardrails', 'sdd-forge-mcp-v2', 'mcp-tests', 'cloud-and-ddd', 'installers']) {
      assert.ok(deps.includes(job), `required-checks must depend on ${job}`);
      assert.match(wf, new RegExp(`\\n  ${job}:\\n`), `job ${job} must exist`);
    }
    // A failed dependency must not turn the aggregate into a (merge-permitting) skip.
    assert.match(agg, /if:\s*\$\{\{\s*always\(\)\s*\}\}/);
    assert.match(agg, /toJSON\(needs\)/);
    assert.match(agg, /\.result != "success"/);
    const installers = wf.slice(wf.indexOf('\n  installers:'), wf.indexOf('\n  required-checks:'));
    assert.match(installers, /bash tests\/install\.tests\.sh/);
    assert.match(installers, /bash tests\/uninstall\.tests\.sh/);
  });

  it('all plugin manifests, marketplaces, README, and CHANGELOG agree on one release version', () => {
    const shipManifest = JSON.parse(
      fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-ship/.claude-plugin/plugin.json'), 'utf8'),
    );
    const expected = shipManifest.version;
    assert.match(expected, /^[0-9]+\.[0-9]+\.[0-9]+$/);

    const readme = fs.readFileSync(path.join(REPO_ROOT, 'README.md'), 'utf8');
    assert.match(readme, new RegExp(`^v${expected.replace(/\./g, '\\.')}[^0-9]`, 'm'));

    const changelog = fs.readFileSync(path.join(REPO_ROOT, 'CHANGELOG.md'), 'utf8');
    assert.match(changelog, new RegExp(`^## v${expected.replace(/\./g, '\\.')}( |$)`, 'm'));

    for (const entry of fs.readdirSync(path.join(REPO_ROOT, 'plugins'), { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      for (const suffix of [
        '.antigravity-plugin/plugin.json',
        '.claude-plugin/plugin.json',
        '.codex-plugin/plugin.json',
        '.plugin/plugin.json',
        'gemini-extension.json',
        'gemini/gemini-extension.json',
      ]) {
        const filePath = path.join(REPO_ROOT, 'plugins', entry.name, suffix);
        if (!fs.existsSync(filePath)) continue;
        const manifest = JSON.parse(fs.readFileSync(filePath, 'utf8'));
        assert.equal(manifest.version, expected, `${entry.name}/${suffix} version mismatch`);
      }
    }

    const mcpPkg = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'mcp/sdd-forge-mcp/package.json'), 'utf8'));
    assert.equal(mcpPkg.version, expected, 'mcp/sdd-forge-mcp/package.json version mismatch');
    const mcpServerSrc = fs.readFileSync(path.join(REPO_ROOT, 'mcp/sdd-forge-mcp/src/server.ts'), 'utf8');
    assert.match(mcpServerSrc, new RegExp(`version:\\s*"${expected.replace(/\./g, '\\.')}"`), 'mcp/sdd-forge-mcp/src/server.ts version mismatch');

    for (const rel of ['.claude-plugin/marketplace.json', '.agents/plugins/marketplace.json']) {
      const market = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8'));
      for (const plugin of market.plugins || []) {
        if (plugin.version !== undefined) {
          assert.equal(plugin.version, expected, `${rel} (${plugin.name}) version mismatch`);
        }
      }
    }
  });
});
