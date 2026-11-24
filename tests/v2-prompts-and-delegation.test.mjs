import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, '..');
const PY = process.platform === 'win32' ? 'python' : 'python3';

function collectFiles(rootDir, predicate, results = []) {
  if (!fs.existsSync(rootDir)) return results;
  for (const entry of fs.readdirSync(rootDir, { withFileTypes: true })) {
    if (entry.name === 'upstream' || entry.name === 'node_modules' || entry.name === '.git') continue;
    const full = path.join(rootDir, entry.name);
    if (entry.isDirectory()) {
      collectFiles(full, predicate, results);
    } else if (predicate(full, entry.name)) {
      results.push(full);
    }
  }
  return results;
}

describe('SDD Forge v2 Prompts, DDD, Perspective Parity, Frontier Models & Delegation Graph', () => {
  it('zero dead v1 references across all active skills, agents, TOML commands, and plugin manifests', () => {
    const targets = [
      ...collectFiles(path.join(REPO_ROOT, 'plugins'), (full, name) =>
        name === 'SKILL.md' ||
        full.includes(`${path.sep}agents${path.sep}`) ||
        full.includes(`${path.sep}copilot-agents${path.sep}`) ||
        name.endsWith('.toml') ||
        name === 'plugin.json' ||
        name === 'gemini-extension.json',
      ),
      ...collectFiles(path.join(REPO_ROOT, '.codex', 'agents'), (_full, name) => name.endsWith('.toml')),
    ];
    assert.ok(targets.length >= 50, `Expected >= 50 active prompt/agent/manifest files, found ${targets.length}`);

    const forbidden = [
      /validate-review-context-set/,
      /REVIEW_CONTEXT_OK/,
      /sdd-bootstrap-interviewer/,
      /\blite-spec\b/,
      /\blite-gate\b/,
      /\bspec-review-loop\b/,
      /\bimpl-review-loop\b/,
      /\btask-review-loop\b/,
      /\bSDD_SUDO\b/,
      /\brun-panelist-gpt\b/,
      /\brun-panelist-gemini\b/,
      /generate-approval-sidecar\.\{sh,ps1\}/,
      /## Managed allocation boundary/,
      /\bC4 container\b/,
      /pre-existing CDK bootstrap.*Missing/s,
    ];

    const violations = [];
    for (const filePath of targets) {
      const rel = path.relative(REPO_ROOT, filePath).replace(/\\/g, '/');
      const content = fs.readFileSync(filePath, 'utf8');
      for (const re of forbidden) {
        if (re.test(content)) {
          // Allow AWS orchestrate skill to mention AWS CDK bootstrap; Azure must not.
          if (re.source.includes('CDK bootstrap') && rel.includes('sdd-aws-cloud')) continue;
          violations.push(`${rel} matched forbidden v1 pattern ${re}`);
        }
      }
      // Check standalone `quality-gate` command/skill refs (ignoring `reports/quality-gate/` paths).
      const withoutReportPaths = content.replace(/reports\/quality-gate\/?/g, '');
      if (/\bquality-gate\b/.test(withoutReportPaths)) {
        violations.push(`${rel} contains retired 'quality-gate' reference outside reports/quality-gate/`);
      }
    }
    assert.deepEqual(violations, []);
  });

  it('all active Claude agents use model: inherit (no silent downgrade) and orphaned v1 agents are removed', () => {
    const claudeAgents = collectFiles(
      path.join(REPO_ROOT, 'plugins'),
      (full, name) => full.includes(`${path.sep}agents${path.sep}`) && name.endsWith('.md'),
    );
    assert.ok(claudeAgents.length >= 7);
    for (const agentFile of claudeAgents) {
      const rel = path.relative(REPO_ROOT, agentFile).replace(/\\/g, '/');
      const content = fs.readFileSync(agentFile, 'utf8');
      assert.match(content, /^model:\s*inherit\s*$/m, `${rel} must use 'model: inherit'`);
      assert.doesNotMatch(content, /^model:\s*(sonnet|haiku)\s*$/m, `${rel} must not hardcode sonnet/haiku`);
    }

    const codexAgents = collectFiles(path.join(REPO_ROOT, '.codex', 'agents'), (_f, n) => n.endsWith('.toml'));
    for (const tomlFile of codexAgents) {
      const rel = path.relative(REPO_ROOT, tomlFile).replace(/\\/g, '/');
      const content = fs.readFileSync(tomlFile, 'utf8');
      assert.doesNotMatch(content, /x-sdd-model:\s*openai\/gpt-5/, `${rel} must not pin legacy gpt-5`);
    }

    const removed = [
      'plugins/sdd-review-loop/agents/impl-reviewer-a.md',
      'plugins/sdd-review-loop/agents/impl-reviewer-b.md',
      'plugins/sdd-review-loop/agents/task-reviewer-a.md',
      'plugins/sdd-review-loop/agents/task-reviewer-b.md',
      'plugins/sdd-quality-loop/agents/panelist-gemini.md',
      'plugins/sdd-quality-loop/agents/panelist-gpt.md',
      '.codex/agents/sdd-panelist-gemini.toml',
      '.codex/agents/sdd-panelist-gpt.toml',
      'plugins/sdd-implementation/scripts/session-panelist.py',
    ];
    for (const rel of removed) {
      assert.equal(fs.existsSync(path.join(REPO_ROOT, rel)), false, `${rel} should be removed`);
    }
  });

  it('delegation graph has zero unreachable user-invocable: false skills', () => {
    const skillFiles = collectFiles(path.join(REPO_ROOT, 'plugins'), (_full, name) => name === 'SKILL.md');
    const skillContents = new Map();
    const internalSkills = [];

    for (const filePath of skillFiles) {
      const content = fs.readFileSync(filePath, 'utf8');
      const nameMatch = content.match(/^name:\s*([a-z0-9-]+)\s*$/m);
      if (!nameMatch) continue;
      const skillName = nameMatch[1];
      skillContents.set(skillName, content);
      if (/^user-invocable:\s*false\s*$/m.test(content)) {
        internalSkills.push(skillName);
      }
    }

    const unreachable = [];
    for (const internal of internalSkills) {
      let called = false;
      for (const [callerName, body] of skillContents.entries()) {
        if (callerName === internal) continue;
        if (body.includes(internal)) {
          called = true;
          break;
        }
      }
      if (!called) unreachable.push(internal);
    }
    assert.deepEqual(unreachable, [], `Unreachable internal skills found: ${unreachable.join(', ')}`);

    // Specifically verify DDD review mode and ship --retro wiring
    assert.match(skillContents.get('domain-model'), /review.*domain-review-loop/s);
    assert.match(skillContents.get('ship'), /workflow-retrospective/);
    assert.match(skillContents.get('workflow-retrospective'), /wfi-audit-cycle/);
    assert.match(skillContents.get('model-selection'), /^user-invocable:\s*true\s*$/m);
    assert.match(skillContents.get('create-project-skill'), /^user-invocable:\s*true\s*$/m);
    assert.match(skillContents.get('maintain-project-skill'), /^user-invocable:\s*true\s*$/m);
  });

  it('enforces strict perspective parity in spec-check (P1-P6) and sdd-gate (G1-G5)', () => {
    const specCheck = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-review-loop/skills/spec-check/SKILL.md'),
      'utf8',
    );
    for (const id of ['P1', 'P2', 'P3', 'P4', 'P5', 'P6']) {
      assert.match(specCheck, new RegExp(`\\*\\*${id}\\*\\*`), `spec-check missing canonical perspective ${id}`);
    }
    assert.match(specCheck, /P1〜P6 全 6 観点/);
    assert.match(specCheck, /A: P1\/P3\/P6, B: P2\/P4\/P5/);

    const sddGate = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-quality-loop/skills/sdd-gate/SKILL.md'),
      'utf8',
    );
    for (const id of ['G1', 'G2', 'G3', 'G4', 'G5']) {
      assert.match(sddGate, new RegExp(`\\*\\*${id}\\*\\*`), `sdd-gate missing canonical perspective ${id}`);
    }
    assert.match(sddGate, /Evaluator A/);
    assert.match(sddGate, /Evaluator B/);
  });

  it('dynamic frontier models (Opus 5.5, Fable, Gemini Neon, Astra) pass through session-models with inherit defaults', () => {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-frontier-models-'));
    const projectDir = path.join(tmp, 'proj');
    const configHome = path.join(tmp, 'cfg');
    fs.mkdirSync(projectDir, { recursive: true });
    fs.mkdirSync(configHome, { recursive: true });

    const pyCode = `
import importlib.util, json, sys
from pathlib import Path
from unittest.mock import patch

root = Path(${JSON.stringify(REPO_ROOT)})
spec = importlib.util.spec_from_file_location('sm', root / 'plugins/sdd-implementation/scripts/session-models.py')
sm = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sm)

start_spec = importlib.util.spec_from_file_location('sms', root / 'plugins/sdd-implementation/scripts/session-model-start.py')
sms = importlib.util.module_from_spec(start_spec)
start_spec.loader.exec_module(sms)

ctx = sms.context('claude-code', {'source': 'startup'})
assert 'model: inherit' in ctx and '停止・ブロックしないでください' in ctx

live_catalog = {
    'observed_at': sm.now(),
    'providers': {h: {'installed': True, 'status': 'listed', 'reason': 'ok', 'auth_mode': 'oauth'} for h in sm.HOSTS},
    'models': [
        {'host': 'claude-code', 'model': 'claude-opus-5-5[1m]', 'efforts': ['medium', 'high', 'max'], 'source': 'live', 'verification': 'listed', 'selectable': True},
        {'host': 'claude-code', 'model': 'claude-fable', 'efforts': ['high', 'xhigh'], 'source': 'live', 'verification': 'listed', 'selectable': True},
        {'host': 'codex-cli', 'model': 'gpt-6-astra', 'efforts': ['low', 'medium', 'high', 'xhigh'], 'source': 'live', 'verification': 'listed', 'selectable': True},
        {'host': 'gemini-cli', 'model': 'gemini-4-neon', 'efforts': ['high', 'xhigh'], 'source': 'live', 'verification': 'listed', 'selectable': True},
    ]
}

store = sm.Store(${JSON.stringify(projectDir)}, ${JSON.stringify(configHome)})
with patch.object(sm, 'discover', return_value=live_catalog):
    sm.begin(store, 'claude-code', 'sess-1')
    # Only set main and one role override; all other roles default to inherit on confirm!
    sm.set_choice(store, 'sess-1', 'main', 'claude-code', 'claude-opus-5-5[1m]', 'max')
    sm.set_choice(store, 'sess-1', 'evaluator', 'gemini-cli', 'gemini-4-neon', 'xhigh')
    confirmed = sm.confirm(store, 'sess-1', True)
    assert confirmed['status'] == 'confirmed'
    assert confirmed['roles']['implementer'] == {'inherit': True}

    imp = sm.selection(store, 'sess-1', 'implementer')
    assert imp['model'] == 'claude-opus-5-5[1m]' and imp['effort'] == 'max' and imp['inherited'] is True

    ev = sm.selection(store, 'sess-1', 'evaluator')
    assert ev['host'] == 'gemini-cli' and ev['model'] == 'gemini-4-neon' and ev['effort'] == 'xhigh' and ev['inherited'] is False

    # Verify policy_request dynamic passthrough for newly listed frontier model without static allowlist entry
    policy_req = {
        'schema': 'model-policy-request/v1',
        'role': 'evaluator',
        'risk': 'standard',
        'host': 'gemini-cli',
        'policy_path': 'contracts/model-policy.v1.json',
        'observation_path': 'contracts/model-policy.v1.json',
        'project_config_path': None,
        'cli': {'model_id': None, 'policy': None},
        'budget': None,
        'requested_effort': None,
        'resume_selection_path': None,
    }
    import os
    os.chdir(root)
    updated = sm.policy_request(store, 'sess-1', 'evaluator', policy_req)
    assert updated['cli'] == {'model_id': 'google/gemini-4-neon', 'policy': 'pinned'}
    assert updated['requested_effort'] == 'xhigh'

    # Brand-new unlisted-in-policy model (e.g. claude-opus-5-5[1m]) also passes through dynamically!
    sm.begin(store, 'claude-code', 'sess-2')
    sm.set_choice(store, 'sess-2', 'main', 'claude-code', 'claude-opus-5-5[1m]', 'max')
    sm.confirm(store, 'sess-2', True)
    req2 = {**policy_req, 'role': 'implementer', 'host': 'claude-code'}
    updated2 = sm.policy_request(store, 'sess-2', 'implementer', req2)
    assert updated2['cli'] == {'model_id': 'claude-opus-5-5[1m]', 'policy': 'pinned'}
    assert updated2['requested_effort'] == 'max'
print('OK')
`;
    const res = spawnSync(PY, ['-c', pyCode], { encoding: 'utf8' });
    assert.equal(res.status, 0, `Python frontier model check failed:\n${res.stdout}\n${res.stderr}`);
    assert.match(res.stdout, /OK/);
  });

  it('sdd-soft-guard confirm mode unblocks Spec Amendments edits and sdd-doctor counts ev.action accurately', () => {
    const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-amend-confirm-'));
    fs.mkdirSync(path.join(repo, '.git'));
    fs.mkdirSync(path.join(repo, 'specs', 'demo'), { recursive: true });
    fs.writeFileSync(path.join(repo, 'AGENTS.md'), '# Agents\n', 'utf8');
    fs.writeFileSync(
      path.join(repo, 'specs', 'demo', 'requirements.md'),
      '# Feature: demo\n\n- REQ-001: Auth returns 200.\n- AC-001: Returns 200.\n\n## Spec Amendments\n- None\n',
      'utf8',
    );
    fs.writeFileSync(
      path.join(repo, 'specs', 'demo', 'design.md'),
      '# Design: demo\n\n## 方針\n- Keep simple\n\n## Spec Amendments\n- None\n',
      'utf8',
    );
    fs.writeFileSync(
      path.join(repo, 'specs', 'demo', 'tasks.md'),
      '# Tasks: demo\n\n## T-001 Task\nApproval: Approved\nStatus: In Progress\nRisk: standard\n\n### Scope\n- src/a.js\n\n### Done When\n- AC-001 passes\n\n## Spec Amendments\n- None\n',
      'utf8',
    );

    const guard = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sdd-soft-guard.mjs');
    const doctor = path.join(REPO_ROOT, 'plugins/sdd-quality-loop/scripts/v2/sdd-doctor.mjs');

    // 1) Unamended body edit in confirm mode -> soft deny (exit 2)
    const denyRes = spawnSync(process.execPath, [guard, '--root', repo, '--emit', 'exit'], {
      input: JSON.stringify({
        tool_name: 'Edit',
        tool_input: {
          file_path: path.join(repo, 'specs', 'demo', 'requirements.md'),
          old_string: 'Returns 200.',
          new_string: 'Returns 204.',
        },
      }),
      encoding: 'utf8',
    });
    assert.equal(denyRes.status, 2);

    // 2) Body edit WITH documented Spec Amendments entry in confirm mode -> allowed (exit 0) + logged
    const allowRes = spawnSync(process.execPath, [guard, '--root', repo, '--emit', 'exit'], {
      input: JSON.stringify({
        tool_name: 'Write',
        tool_input: {
          file_path: path.join(repo, 'specs', 'demo', 'requirements.md'),
          content:
            '# Feature: demo\n\n- REQ-001: Auth returns 204.\n- AC-001: Returns 204.\n\n## Spec Amendments\n- 2026-11-21: Agreed with user to return 204 No Content.\n',
        },
      }),
      encoding: 'utf8',
    });
    assert.equal(allowRes.status, 0, allowRes.stderr);
    assert.match(allowRes.stderr, /confirm\/amended/);

    // 3) sdd-doctor.mjs accurately tallies deny=1 and warn/confirm=1 from .sdd/drift-events.jsonl
    const docRes = spawnSync(process.execPath, [doctor, '--root', repo, '--json'], { encoding: 'utf8' });
    assert.equal(docRes.status, 0, docRes.stderr);
    const report = JSON.parse(docRes.stdout);
    const evFinding = report.findings.find((f) => f.category === 'events');
    assert.ok(evFinding, 'Expected events finding in sdd-doctor output');
    assert.match(evFinding.message, /deny=1, warn\/confirm=1/);
  });

  it(
    'check-sdd-structure.sh accepts 3-file SDD Core v2 feature directories',
    { skip: process.platform === 'win32' },
    () => {
      const repo = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-struct-v2-'));
      for (const d of ['specs/demo', 'reports/implementation', 'reports/quality-gate', 'docs/adr', 'docs/review-tickets']) {
        fs.mkdirSync(path.join(repo, d), { recursive: true });
      }
      fs.writeFileSync(path.join(repo, 'AGENTS.md'), '# Agents\n', 'utf8');
      fs.writeFileSync(path.join(repo, 'specs/demo/requirements.md'), '# Requirements\n', 'utf8');
      fs.writeFileSync(path.join(repo, 'specs/demo/design.md'), '# Design\n', 'utf8');
      fs.writeFileSync(path.join(repo, 'specs/demo/tasks.md'), '# Tasks\n', 'utf8');

      for (const relScript of ['scripts/check-sdd-structure.sh', 'plugins/sdd-bootstrap/scripts/check-sdd-structure.sh']) {
        const res = spawnSync('bash', [path.join(REPO_ROOT, relScript), repo, 'demo'], { encoding: 'utf8' });
        assert.equal(res.status, 0, `${relScript} failed on 3-file v2 feature:\n${res.stdout}\n${res.stderr}`);
      }
    },
  );

  it('Issues #795-#798: Gemini installer --consent, quoted reviewer frontmatter, separated Gemini manifests, and ADR-0052 MCP v2 schema', () => {
    // #795: install.sh and install.ps1 pass --consent to gemini extensions link and point bootstrap/review-loop to gemini/ subdirs
    const installSh = fs.readFileSync(path.join(REPO_ROOT, 'install.sh'), 'utf8');
    const installPs1 = fs.readFileSync(path.join(REPO_ROOT, 'install.ps1'), 'utf8');
    assert.match(installSh, /gemini extensions link --consent "\$ext_dir"/);
    assert.match(installPs1, /'extensions',\s*'link',\s*'--consent',\s*\$extDir/);
    assert.match(installSh, /plugins\/sdd-bootstrap\/gemini/);
    assert.match(installSh, /plugins\/sdd-review-loop\/gemini/);

    for (const rel of [
      'plugins/sdd-bootstrap/gemini/gemini-extension.json',
      'plugins/sdd-bootstrap/gemini/GEMINI.md',
      'plugins/sdd-review-loop/gemini/gemini-extension.json',
      'plugins/sdd-review-loop/gemini/GEMINI.md',
    ]) {
      assert.ok(fs.existsSync(path.join(REPO_ROOT, rel)), `Missing Gemini extension artifact: ${rel}`);
    }

    // #795: spec-reviewer-{a,b}.md quote description containing 'Risk:' colons for strict YAML parsers
    for (const agentFile of [
      'plugins/sdd-review-loop/agents/spec-reviewer-a.md',
      'plugins/sdd-review-loop/agents/spec-reviewer-b.md',
    ]) {
      const text = fs.readFileSync(path.join(REPO_ROOT, agentFile), 'utf8');
      assert.match(text, /^description:\s*"[^"\n]+Risk:\s*(?:standard|high)[^"\n]*"$/m, `${agentFile} description must be YAML-quoted`);
    }

    // #798: ADR-0052, MCP v2 spec, and JSON schema contract exist and parse cleanly
    assert.ok(fs.existsSync(path.join(REPO_ROOT, 'docs/adr/0052-mcp-architecture-and-v2-consolidation.md')));
    assert.ok(fs.existsSync(path.join(REPO_ROOT, 'docs/architecture/mcp-v2-spec.md')));
    const schema = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, 'contracts/sdd-mcp.v2.schema.json'), 'utf8'));
    for (const def of ['sdd_project_overview_data', 'sdd_feature_state_data', 'sdd_gate_audit_data', 'toolAnnotations']) {
      assert.ok(schema.$defs?.[def], `Missing $defs.${def} in contracts/sdd-mcp.v2.schema.json`);
    }
  });
});

describe('#841 WFI category contract is one vocabulary', () => {
  it('both auditors accept exactly the four categories the template defines', () => {
    const root = path.join(REPO_ROOT, 'plugins/sdd-quality-loop');
    const template = fs.readFileSync(path.join(root, 'templates/workflow-improvement.template.md'), 'utf8');
    const allowed = /Allowed values: ([a-z-]+(?: \| [a-z-]+)+)/.exec(template)[1].split(' | ').sort();
    assert.deepEqual(allowed, ['app-dev-efficiency', 'human-process', 'measurement', 'plugin-improvement']);
    for (const agent of ['wfi-auditor-a.md', 'wfi-auditor-b.md']) {
      const text = fs.readFileSync(path.join(root, 'agents', agent), 'utf8');
      const enumMatch = /"category": "([a-z|-]+)"/.exec(text);
      assert.ok(enumMatch, `${agent} declares the category output enum`);
      assert.deepEqual(enumMatch[1].split('|').sort(), allowed, `${agent} output enum`);
      assert.doesNotMatch(text, /Must be\s+plugin-improvement or app-dev-efficiency/, `${agent} rejects a valid category`);
    }
  });
});

describe('#846 WFI audit states are representable in the canonical template', () => {
  it('every Audit-Status the audit cycle writes is an allowed template value, with its counters', () => {
    const root = path.join(REPO_ROOT, 'plugins/sdd-quality-loop');
    const template = fs.readFileSync(path.join(root, 'templates/workflow-improvement.template.md'), 'utf8');
    const allowed = /Allowed values: (Not-Started[^\n]*?) -->/.exec(template)[1].split(' | ').map((v) => v.trim());
    const skill = fs.readFileSync(path.join(root, 'skills/wfi-audit-cycle/SKILL.md'), 'utf8');
    const written = [...new Set([...skill.matchAll(/Audit-Status: ([A-Za-z0-9-]+)/g)].map((m) => m[1]))];
    assert.ok(written.includes('Human-Blocked'));
    for (const state of written) assert.ok(allowed.includes(state), `Audit-Status ${state} is not an allowed template value`);
    assert.match(template, /^Audit-Attempt: /m);
    assert.match(template, /^Audit-Content-Hash: /m);
  });

  it('Needs-Followup is recorded in Result, never as a Status value', () => {
    const root = path.join(REPO_ROOT, 'plugins/sdd-quality-loop');
    const retro = fs.readFileSync(path.join(root, 'skills/workflow-retrospective/SKILL.md'), 'utf8');
    const line = retro.split('\n').find((l) => l.includes('Needs-Followup'));
    assert.ok(line);
    assert.match(line, /## Result/);
    assert.match(line, /Status: Applied/);
  });
});
