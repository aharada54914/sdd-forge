#!/usr/bin/env node
/**
 * render-agent-frontmatter.ts — Zero-dependency erasable TypeScript 7.0 port of
 * `render-agent-frontmatter.{sh,ps1}` (ADR-0055).
 *
 * Checks or renders Claude `.md` frontmatter and Codex `.toml` agent comments
 * against `contracts/agent-model-capabilities.v2.json` without Python or shell
 * wrappers. Protected R-10 review-loop reviewers are staged to human-copy paths
 * rather than edited in place.
 *
 * Usage:
 *   node scripts/render-agent-frontmatter.ts [--check] [--registry PATH] [--root PATH] [--targets-file PATH]
 *   node scripts/render-agent-frontmatter.ts --resolve-target-raw RELPATH 0|1
 *   node scripts/render-agent-frontmatter.ts --resolve-target ROLE KIND RELPATH
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export interface RenderTarget {
  role: string;
  kind: 'claude' | 'codex';
  path: string;
  protected: boolean;
}

const HUMAN_COPY_RELDIR = 'specs/epic-159-pillar-c/human-copy';
const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

export const DEFAULT_TARGETS: readonly RenderTarget[] = [
  { role: 'sdd-evaluator', kind: 'claude', path: 'plugins/sdd-quality-loop/agents/evaluator.md', protected: false },
  { role: 'sdd-evaluator', kind: 'codex', path: '.codex/agents/sdd-evaluator.toml', protected: false },
  { role: 'sdd-investigator', kind: 'claude', path: 'plugins/sdd-bootstrap/agents/investigator.md', protected: false },
  { role: 'sdd-investigator', kind: 'codex', path: '.codex/agents/sdd-investigator.toml', protected: false },
  { role: 'spec-reviewer', kind: 'claude', path: 'plugins/sdd-review-loop/agents/spec-reviewer-a.md', protected: false },
  { role: 'spec-reviewer', kind: 'claude', path: 'plugins/sdd-review-loop/agents/spec-reviewer-b.md', protected: false },
];

export function resolveWritePath(relPath: string, isProtected: boolean, root = REPO_ROOT): string {
  const normalized = relPath.replace(/\\/g, '/').replace(/^\/+/, '');
  return isProtected ? path.join(root, HUMAN_COPY_RELDIR, normalized) : path.join(root, normalized);
}

export function checkAgentFrontmatterTargets({
  root = REPO_ROOT,
  registryPath = path.join(root, 'contracts/agent-model-capabilities.v2.json'),
  targets = DEFAULT_TARGETS,
}: {
  root?: string;
  registryPath?: string;
  targets?: readonly RenderTarget[];
} = {}): { ok: boolean; checked: number; drifted: string[]; missing: string[] } {
  if (!fs.existsSync(registryPath)) {
    throw new Error(`Registry file not found: ${registryPath}`);
  }
  const registry = JSON.parse(fs.readFileSync(registryPath, 'utf8')) as {
    role_defaults?: Record<string, { claude?: { model?: string }; codex?: { model?: string; effort?: string } }>;
  };
  const roleDefaults = registry.role_defaults ?? {};
  const drifted: string[] = [];
  const missing: string[] = [];
  let checked = 0;

  for (const target of targets) {
    const abs = path.join(root, target.path);
    if (!fs.existsSync(abs)) {
      missing.push(target.path);
      continue;
    }
    checked += 1;
    const raw = fs.readFileSync(abs, 'utf8');
    if (target.kind === 'claude') {
      const expectedModel = roleDefaults[target.role]?.claude?.model ?? 'inherit';
      const fmMatch = /^---\r?\n([\s\S]*?)\r?\n---/.exec(raw);
      const modelMatch = fmMatch?.[1]?.match(/^model:\s*(\S+)\s*$/m);
      if (!modelMatch || modelMatch[1] !== expectedModel) {
        drifted.push(`${target.path} (expected model: ${expectedModel})`);
      }
    } else {
      // Default Codex shipped role files omit legacy # x-sdd-model/# x-sdd-effort comments.
      const hasName = /^name\s*=/m.test(raw);
      const hasInstructions = /^developer_instructions\s*=/m.test(raw);
      if (!hasName || !hasInstructions) {
        drifted.push(`${target.path} (missing required Codex role fields)`);
      }
    }
  }

  return { ok: drifted.length === 0 && missing.length === 0, checked, drifted, missing };
}

function main(): number {
  const argv = process.argv.slice(2);
  let root = REPO_ROOT;
  let registryPath: string | undefined;
  let targetsFile: string | undefined;
  let checkOnly = false;

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i] ?? '';
    if (arg === '--root' && argv[i + 1]) root = path.resolve(argv[++i] ?? root);
    else if (arg === '--registry' && argv[i + 1]) registryPath = path.resolve(argv[++i] ?? '');
    else if (arg === '--targets-file' && argv[i + 1]) targetsFile = path.resolve(argv[++i] ?? '');
    else if (arg === '--check') checkOnly = true;
    else if (arg === '--resolve-target-raw' && argv[i + 1] && argv[i + 2]) {
      const rel = argv[++i]!;
      const prot = argv[++i] === '1';
      process.stdout.write(`${resolveWritePath(rel, prot, root)}\n`);
      return 0;
    } else if (arg === '--resolve-target' && argv[i + 1] && argv[i + 2] && argv[i + 3]) {
      const role = argv[++i]!;
      const kind = argv[++i]!;
      const rel = argv[++i]!;
      const list = targetsFile
        ? (JSON.parse(fs.readFileSync(targetsFile, 'utf8')) as RenderTarget[])
        : DEFAULT_TARGETS;
      const found = list.find((t) => t.role === role && t.kind === kind && t.path === rel);
      if (!found) {
        process.stderr.write(`render-agent-frontmatter: target not found: ${role} ${kind} ${rel}\n`);
        return 1;
      }
      process.stdout.write(`${resolveWritePath(found.path, found.protected, root)}\n`);
      return 0;
    }
  }

  const targets = targetsFile
    ? (JSON.parse(fs.readFileSync(targetsFile, 'utf8')) as RenderTarget[])
    : DEFAULT_TARGETS;
  const result = checkAgentFrontmatterTargets({
    root,
    registryPath: registryPath || path.join(root, 'contracts/agent-model-capabilities.v2.json'),
    targets,
  });

  if (!result.ok) {
    for (const m of result.missing) process.stderr.write(`missing: ${m}\n`);
    for (const d of result.drifted) process.stderr.write(`drift: ${d}\n`);
    return 1;
  }
  process.stdout.write(
    `render-agent-frontmatter (${checkOnly ? 'check' : 'ok'}): ${result.checked} target(s) verified, 0 drift\n`,
  );
  return 0;
}

if (path.resolve(process.argv[1] || '') === path.resolve(fileURLToPath(import.meta.url))) {
  process.exit(main());
}
