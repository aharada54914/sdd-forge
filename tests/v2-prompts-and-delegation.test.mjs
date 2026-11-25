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

  it('H4/N21/G7/R3: sdd-adopt templates, bootstrap adopt guidance, ticket-scoped ship reentry, and feature-scoped retrospective metrics stay aligned with v2 public commands', () => {
    // H4: generated sdd-adopt templates use current public commands, accurate internal roles, human approvals, and task-scoped ticket retry
    for (const rel of [
      'plugins/sdd-bootstrap/skills/sdd-adopt/templates/AGENTS.template.md',
      'plugins/sdd-bootstrap/skills/sdd-adopt/templates/CLAUDE.template.md',
    ]) {
      const content = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
      const withoutReportPaths = content.replace(/reports\/quality-gate\/?/g, '');
      assert.doesNotMatch(
        withoutReportPaths,
        /\bsdd-bootstrap-interviewer\b|\bquality-gate\b|\blite-spec\b|\blite-gate\b|\bspec-review-loop\b|\bimpl-review-loop\b|\btask-review-loop\b|\/sdd-implementation:implement-task\b/,
        `${rel} must not reference retired v1 or non-public slash skills`,
      );
      assert.match(content, /\/sdd-bootstrap:bootstrap/, `${rel} must reference public /sdd-bootstrap:bootstrap`);
      assert.match(content, /\/sdd-ship:ship specs\/<feature>\/tasks\.md/, `${rel} must reference public /sdd-ship:ship`);
      assert.match(
        content,
        /\/sdd-quality-loop:fix-by-review-ticket/,
        `${rel} must reference public /sdd-quality-loop:fix-by-review-ticket`,
      );
      assert.match(content, /\bsdd-core-spec\b/, `${rel} must state internal sdd-core-spec responsibility`);
      assert.match(content, /\bspec-check\b/, `${rel} must state internal spec-check responsibility`);
      assert.match(content, /\bsdd-gate\b/, `${rel} must state internal sdd-gate Done responsibility`);
      assert.match(content, /Approval: Approved/, `${rel} must preserve human-only Approval: Approved gate`);

      const ticketLine = content.split(/\r?\n/).find((line) => line.includes('/sdd-quality-loop:fix-by-review-ticket'));
      assert.ok(ticketLine, `${rel} must contain a review-ticket workflow step`);
      const ticketShipCmds = [...ticketLine.matchAll(/\/sdd-ship:ship(?:\s+[^\s`）)。,;]+)*/g)].map((m) => m[0]);
      assert.ok(ticketShipCmds.length >= 1, `${rel} ticket step must specify a /sdd-ship:ship retry command`);
      for (const cmd of ticketShipCmds) {
        assert.match(
          cmd,
          /^\/sdd-ship:ship\s+specs\/<feature>\/tasks\.md#<task-id>$/,
          `${rel} ticket retry must include #<task-id> so unrelated Planned tasks are not started: ${cmd}`,
        );
      }
    }

    // N21: bootstrap and internal skills guide users to public /sdd-bootstrap:bootstrap adopt (never /sdd-bootstrap:sdd-adopt)
    for (const rel of [
      'plugins/sdd-bootstrap/skills/bootstrap/SKILL.md',
      'plugins/sdd-bootstrap/skills/sdd-core-spec/SKILL.md',
      'plugins/sdd-implementation/skills/implement-task/SKILL.md',
      'plugins/sdd-implementation/skills/implement-tasks/SKILL.md',
    ]) {
      const content = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
      assert.doesNotMatch(
        content,
        /\/sdd-bootstrap:sdd-adopt\b/,
        `${rel} must not guide users to non-user-invocable /sdd-bootstrap:sdd-adopt`,
      );
      assert.match(content, /\/sdd-bootstrap:bootstrap adopt\b/, `${rel} must guide users to public /sdd-bootstrap:bootstrap adopt`);
    }

    // G7: fix-by-review-ticket reentry ALWAYS includes #<task-id> from the ticket so a same-feature unrelated Planned task is never started
    const fixTicket = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-quality-loop/skills/fix-by-review-ticket/SKILL.md'),
      'utf8',
    );
    const reentryCmds = [...fixTicket.matchAll(/\/sdd-ship:ship(?:\s+[^\s`）)。,;]+)*/g)].map((m) => m[0]);
    assert.ok(reentryCmds.length >= 1, 'fix-by-review-ticket must specify a /sdd-ship:ship reentry command');
    for (const cmd of reentryCmds) {
      assert.match(
        cmd,
        /^\/sdd-ship:ship\s+specs\/<feature>\/tasks\.md#<task-id>$/,
        `fix-by-review-ticket reentry must always require both <feature> and #<task-id> fragment: ${cmd}`,
      );
    }

    // Concrete same-feature fixture: ticket targets T-001 (Implementation Complete) while T-002 is an unrelated Approved Planned task
    const sameFeatureTasks = [
      { id: 'T-001', approval: 'Approved', status: 'Implementation Complete' },
      { id: 'T-002', approval: 'Approved', status: 'Planned' },
    ];
    const resolvedTicket = { feature: 'payments', task: 'T-001' };
    for (const template of reentryCmds) {
      const invoked = template
        .replace('<feature>', resolvedTicket.feature)
        .replace('<task-id>', resolvedTicket.task);
      const match = invoked.match(/^\/sdd-ship:ship\s+specs\/([^/\s]+)\/tasks\.md#([^\s]+)$/);
      assert.ok(match, `Resolved ticket reentry must carry explicit feature and #task-id fragment: ${invoked}`);
      const [, targetFeature, targetTaskId] = match;
      assert.equal(targetFeature, 'payments');
      const selected = sameFeatureTasks.filter((t) => t.id === targetTaskId);
      assert.deepEqual(
        selected.map((t) => t.id),
        ['T-001'],
        'Reentry fragment must isolate the ticket task and exclude same-feature unrelated Planned task T-002',
      );
    }
    assert.match(fixTicket, /手順\s*2/, 'fix-by-review-ticket must defer to step 2 when ticket lacks an unambiguous task ID');
    assert.match(fixTicket, /Status: Implementation Complete/);
    assert.match(fixTicket, /Approval:/);
    assert.match(fixTicket, /Status: Done/);

    // R3: workflow-retrospective uses factory-metrics.mjs --feature "<feature>" for single-feature scope and keeps project-wide option
    const retro = fs.readFileSync(
      path.join(REPO_ROOT, 'plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md'),
      'utf8',
    );
    const retroUnwrapped = retro.replace(/\\\r?\n\s*/g, ' ');
    const metricsCmds = retroUnwrapped
      .split(/\r?\n/)
      .filter((line) => line.includes('factory-metrics.mjs') && line.includes('--root'));
    assert.ok(
      metricsCmds.some((line) => line.includes('--feature "<feature>"')),
      'workflow-retrospective must pass --feature "<feature>" for single-feature retrospective',
    );
    assert.ok(
      metricsCmds.some((line) => !line.includes('--feature')),
      'workflow-retrospective must keep project-wide factory-metrics.mjs invocation without --feature',
    );
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

describe('#849 a passed audit always reaches human approval', () => {
  it('Human-Pending does not depend on category or on consent to file an issue', () => {
    const skill = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/skills/wfi-audit-cycle/SKILL.md'), 'utf8');
    const step = skill.slice(skill.indexOf('3. **完了遷移**'), skill.indexOf('## Boundaries'));
    const pendingLine = step.split('\n').find((l) => l.includes('Human-Pending'));
    assert.ok(pendingLine, 'completion step sets Human-Pending');
    assert.doesNotMatch(pendingLine, /同意|plugin-improvement/, 'Human-Pending must not be conditional on consent or category');
    assert.match(step, /追跡 Issue/);
  });
});

describe('#847 the Cycle 1 summary carries everything Cycle 2 must report', () => {
  it('the audit cycle writes each cycle_1_summary field auditor B reads from integrated-summary.json', () => {
    const root = path.join(REPO_ROOT, 'plugins/sdd-quality-loop');
    const b = fs.readFileSync(path.join(root, 'agents/wfi-auditor-b.md'), 'utf8');
    const block = /"cycle_1_summary": \{([^}]*)\}/.exec(b)[1];
    const fields = [...block.matchAll(/"(auditor_a_[a-z_]+)"/g)].map((m) => m[1]);
    assert.deepEqual(fields.sort(), ['auditor_a_fail_count', 'auditor_a_pass_count', 'auditor_a_verdict']);
    const skill = fs.readFileSync(path.join(root, 'skills/wfi-audit-cycle/SKILL.md'), 'utf8');
    const step = skill.split('\n').find((l) => l.includes('integrated-summary.json') && l.includes('書き出す'));
    assert.ok(step, 'Cycle 1 step writes integrated-summary.json');
    for (const f of fields) assert.match(step, new RegExp(f), `integrated summary must include ${f}`);
    assert.match(b, /never infer|推測しない|do not infer/i, 'B must not guess a missing verdict');
  });
});

describe('#845 the plugin source-repository carve-out is one rule in both audits', () => {
  it('auditor B, the template and the contributor doc all name the same three conditions', () => {
    const root = path.join(REPO_ROOT, 'plugins/sdd-quality-loop');
    const conditions = [/Category: plugin-improvement/, /source of truth/i, /## GitHub-Issue/];
    const b = fs.readFileSync(path.join(root, 'agents/wfi-auditor-b.md'), 'utf8');
    const feasibility = b.slice(b.indexOf('## FEASIBILITY-WITHOUT-PLUGINS'), b.indexOf('\n## ', b.indexOf('## FEASIBILITY-WITHOUT-PLUGINS') + 5));
    for (const c of conditions) assert.match(feasibility, c, `auditor B FEASIBILITY-WITHOUT-PLUGINS names ${c}`);
    const template = fs.readFileSync(path.join(root, 'templates/workflow-improvement.template.md'), 'utf8');
    assert.doesNotMatch(template, /Plugin files must not be listed\.\s+-->/);
    assert.match(template, /wfi-auditor-a\.md/);
    const doc = fs.readFileSync(path.join(REPO_ROOT, 'docs/contributor/workflow-detail.md'), 'utf8');
    assert.doesNotMatch(doc, /`plugins\/` 内は禁止\)/);
  });
});

describe('#870 documented agent models match the distributed agent definitions', () => {
  it('every agent table row names a shipped agent and its frontmatter model, and no shipped agent is missing', () => {
    const doc = fs.readFileSync(path.join(REPO_ROOT, 'docs/skill-reference.md'), 'utf8');
    const rows = [...doc.matchAll(/^\| `([\w-]+)`(?:（`[\w-]+`）)? \| (sdd-[\w-]+) \| `([\w.-]+)` \|/gm)];
    assert.ok(rows.length > 0, 'agent table found');
    const documented = new Set();
    for (const [, name, plugin, model] of rows) {
      const file = path.join(REPO_ROOT, 'plugins', plugin, 'agents', `${name}.md`);
      assert.ok(fs.existsSync(file), `${name} is documented but plugins/${plugin}/agents/${name}.md does not exist`);
      const declared = /^model:\s*(\S+)/m.exec(fs.readFileSync(file, 'utf8'))?.[1];
      assert.equal(model, declared, `${name}: documented model ${model} but the definition says ${declared}`);
      documented.add(`${plugin}/${name}`);
    }
    for (const plugin of fs.readdirSync(path.join(REPO_ROOT, 'plugins'))) {
      const dir = path.join(REPO_ROOT, 'plugins', plugin, 'agents');
      if (!fs.existsSync(dir)) continue;
      for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.md'))) {
        const name = f.replace(/\.md$/, '');
        assert.ok(
          documented.has(`${plugin}/${name}`) || doc.includes(`\`${name}\``),
          `${plugin}/agents/${f} is not documented`,
        );
      }
    }
  });
});

describe('#866 adopt PR template follows the SDD Core v2 artifact set', () => {
  it('requires the three Core files and treats traceability.md as present-only', () => {
    const tpl = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-bootstrap/skills/sdd-adopt/templates/pull-request.template.md'), 'utf8');
    for (const f of ['requirements.md', 'design.md', 'tasks.md']) assert.match(tpl, new RegExp(f.replace('.', '\\.')));
    for (const line of tpl.split('\n').filter((l) => l.includes('traceability.md'))) {
      assert.match(line, /if (it )?exists|存在する場合|when present/i, `traceability.md must be conditional: ${line}`);
    }
  });
});

describe('#867 user guides never present retired sudo / Lite tooling as current', () => {
  const BANNER = /v2\.0\.0 で廃止（v1\.x のみの参考情報）/;
  const docs = ['docs/skill-reference.md', 'docs/troubleshooting.md', 'docs/contributor/workflow-detail.md', 'docs/contributor/skill-reference-detail.md'];
  it('current command lists and tool tables omit them', () => {
    const ref = fs.readFileSync(path.join(REPO_ROOT, 'docs/skill-reference.md'), 'utf8');
    const visible = ref.split('\n').find((l) => l.startsWith('ユーザーに見えるコマンドは'));
    assert.ok(visible);
    assert.doesNotMatch(visible, /sdd-sudo/);
    assert.doesNotMatch(ref, /^\| sdd-sudo \|/m);
    assert.doesNotMatch(ref, /^\| `check-task-state-lite` \|/m);
  });
  it('every remaining sudo / Lite section carries the retirement banner', () => {
    for (const rel of docs) {
      const lines = fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8').split('\n');
      lines.forEach((line, i) => {
        if (!/^#{2,4} /.test(line) || !/sudo|Sudo|lite-spec|lite-gate|check-task-state-lite/.test(line)) return;
        const next = lines.slice(i + 1, i + 4).join('\n');
        assert.match(next, BANNER, `${rel}:${i + 1} "${line}" lacks the retirement banner`);
      });
    }
  });
});

describe('#868 a retrospective drafts WFIs from the canonical template with audit-required fields', () => {
  it('Step 4 names the template and every field the auditors check, without guessing', () => {
    const skill = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md'), 'utf8');
    const step3 = skill.slice(skill.indexOf('## Step 3'), skill.indexOf('## Step 4'));
    const step4 = skill.slice(skill.indexOf('## Step 4'), skill.indexOf('## Boundaries'));
    assert.match(step4, /templates\/workflow-improvement\.template\.md/);
    for (const field of ['Category', 'Meta-Change', 'Why-Why Analysis', 'Root Cause Hypothesis', 'Verification Metric', 'Audit-Status: Not-Started']) {
      assert.ok(step4.includes(field), `Step 4 must carry ${field}`);
    }
    assert.match(step4, /推測しない|TBD（人間確認）/);
    assert.match(step3, /Category/);
    assert.match(step3, /評価時期/);
  });
});

describe('#864 bootstrap stops on an unapproved domain model; domain-sync alone does not', () => {
  it('sdd-core-spec states the concept-test gate and domain-sync scopes its never-block promise', () => {
    const core = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-bootstrap/skills/sdd-core-spec/SKILL.md'), 'utf8');
    const line = core.split('\n').find((l) => l.includes('concept-test') && l.includes('domain-sync'));
    assert.ok(line);
    assert.match(line, /BLOCK/);
    assert.match(line, /Approved/);
    assert.match(line, /concept-test[^。]*先/);
    const sync = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-domain/skills/domain-sync/SKILL.md'), 'utf8');
    const caller = sync.split('\n').find((l) => l.startsWith('> **Caller**'));
    assert.match(caller, /concept-test/);
    assert.match(caller, /CONTINUE/);
  });
});

describe('#863 the context-map template states what an edit after approval actually does', () => {
  it('no automatic reset is promised; the update flow resets and stale proposals stop', () => {
    const tpl = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-domain/skills/domain-interviewer/templates/context-map.template.md'), 'utf8');
    assert.doesNotMatch(tpl, /Editing any file under `domain\/` after\s+approval resets this field/);
    assert.match(tpl, /domain-model update/);
    const validator = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-domain/scripts/validate-concept-test.py'), 'utf8');
    assert.match(validator, /concept-test: BLOCK/, 'the documented stop line is the one bootstrap prints');
    assert.match(tpl, /concept-test: BLOCK/);
    assert.doesNotMatch(tpl, /stops with `Concept Test input changed`/, 'that message is internal, not what bootstrap prints');
    assert.match(tpl, /generated_from/, 'only pinned inputs invalidate a proposal');
  });
});

describe('#814 the domain review finalizer names its own operation in diagnostics', () => {
  it('bash (run) and PowerShell (static) report FINALIZE_DOMAIN_REVIEW_RUNTIME_UNAVAILABLE', () => {
    const dir = path.join(REPO_ROOT, 'plugins/sdd-domain/scripts');
    const ps = fs.readFileSync(path.join(dir, 'finalize-domain-review.ps1'), 'utf8');
    assert.doesNotMatch(ps, /GENERATE_APPROVAL_SIDECAR_RUNTIME_UNAVAILABLE/);
    assert.match(ps, /FINALIZE_DOMAIN_REVIEW_RUNTIME_UNAVAILABLE/);
    if (process.platform === 'win32') return;
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'sdd-finalize-'));
    try {
      fs.copyFileSync(path.join(dir, 'finalize-domain-review.sh'), path.join(tmp, 'finalize-domain-review.sh'));
      const res = spawnSync('bash', [path.join(tmp, 'finalize-domain-review.sh'), '--help'], { encoding: 'utf8' });
      assert.notEqual(res.status, 0);
      assert.match(res.stderr, /finalize-domain-review: FINALIZE_DOMAIN_REVIEW_RUNTIME_UNAVAILABLE/);
    } finally {
      fs.rmSync(tmp, { recursive: true, force: true });
    }
  });
});

describe('#811 the v1 domain-review precheck is optional and its placement limit is stated', () => {
  it('no shipped skill requires it, and the reference says it only works with the project in the same tree', () => {
    const skillsRoot = path.join(REPO_ROOT, 'plugins');
    const offenders = [];
    for (const plugin of fs.readdirSync(skillsRoot)) {
      const dir = path.join(skillsRoot, plugin, 'skills');
      if (!fs.existsSync(dir)) continue;
      for (const skill of fs.readdirSync(dir)) {
        const file = path.join(dir, skill, 'SKILL.md');
        if (!fs.existsSync(file)) continue;
        // A line may name the v1 precheck to say it is old and not used; any
        // other mention would make the public review depend on it.
        const uses = fs.readFileSync(file, 'utf8').split('\n')
          .filter((line) => line.includes('domain-review-precheck') && !/旧 v1|v1 互換/.test(line));
        if (uses.length > 0) offenders.push(`${plugin}/${skill}`);
      }
    }
    assert.deepEqual(offenders, [], 'the public domain review must not depend on the v1 precheck');
    const row = fs.readFileSync(path.join(REPO_ROOT, 'docs/skill-reference.md'), 'utf8')
      .split('\n').find((l) => l.startsWith('| `domain-review-precheck`'));
    assert.match(row, /v1/);
    assert.match(row, /同じツリー/);
    assert.match(row, /版別キャッシュ/);
  });
});

describe('#848 domain-conformance findings are opt-in in v2, and "not run" differs from zero', () => {
  it('the contract and ADR do not claim the gate runs the check; retro and template tell N/A from 0', () => {
    const contracts = fs.readFileSync(path.join(REPO_ROOT, 'PLUGIN-CONTRACTS.md'), 'utf8');
    const conformance = contracts.split('\n').filter((l) => /check-domain-conformance|DOMAIN-CONFORMANCE/.test(l)).join('\n');
    assert.doesNotMatch(conformance, /deterministic gate/, 'v2 sdd-gate does not run the check');
    assert.match(contracts, /does not run\s+`check-domain-conformance`/);
    const adr = fs.readFileSync(path.join(REPO_ROOT, 'docs/adr/0015-ddd-upstream-domain-lane.md'), 'utf8');
    assert.match(adr, /Status note, v2: the v2 `sdd-gate` does not run\s+`check-domain-conformance`/);
    const retro = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md'), 'utf8');
    assert.match(retro, /`N\/A`[^\n]*未実行/);
    const template = fs.readFileSync(path.join(REPO_ROOT, 'plugins/sdd-quality-loop/templates/retrospective-report.template.md'), 'utf8');
    assert.match(template, /N\/A[^\n]*not run/);
    assert.match(template, /0[^\n]*ran with no findings|ran with no findings[^\n]*0/);
  });
});

describe('#803 approving the domain model also publishes the contract', () => {
  it('every place that tells a human how to approve names the contract publication step', () => {
    const read = (rel) => fs.readFileSync(path.join(REPO_ROOT, rel), 'utf8');
    // Approving only context-map.md leaves domain-contract.json Pending, and the
    // Concept Test then stops with "domain model must be approved".
    const template = read('plugins/sdd-domain/skills/domain-interviewer/templates/context-map.template.md');
    assert.match(template, /publish(es|ing)? the domain contract/i);
    assert.match(template, /domain-review-loop/);
    assert.doesNotMatch(template, /signed off by editing this line directly\)/);
    for (const rel of ['plugins/sdd-domain/skills/domain-interviewer/SKILL.md', 'plugins/sdd-domain/GEMINI.md']) {
      assert.match(read(rel), /人による承認と契約の発行/, rel);
    }
  });
});
