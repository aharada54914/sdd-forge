#!/usr/bin/env node
/**
 * generate-sbom.ts — Zero-dependency CycloneDX 1.5 SBOM generator (ADR-0055).
 *
 * Buildless erasable TypeScript 7.0 port of `.github/scripts/generate-sbom.py`.
 * Produces identical CycloneDX 1.5 component inventory from `.github/workflows/`
 * and `mcp/` lockfiles (`package-lock.json`).
 *
 * Usage:
 *   node .github/scripts/generate-sbom.ts [--version VERSION] [--repo OWNER/REPO]
 *                                         [--output PATH] [--source-root DIR]
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

interface ActionUse {
  repo: string;
  ref: string;
  subpath: string;
}

interface SbomComponent {
  type: 'library';
  name: string;
  version: string;
  purl: string;
  externalReferences?: Array<{ type: 'vcs'; url: string }>;
  properties?: Array<{ name: string; value: string }>;
}

export interface CycloneDxSbom {
  bomFormat: 'CycloneDX';
  specVersion: '1.5';
  version: number;
  metadata: {
    timestamp: string;
    tools: Array<{ vendor: string; name: string; version: string }>;
    component: {
      type: 'application';
      name: string;
      version: string;
      purl: string;
      description: string;
      externalReferences: Array<{ type: 'vcs'; url: string }>;
    };
  };
  components: SbomComponent[];
}

const USES_RE = /^\s*-?\s*uses:\s*([^\s#'"]+)/;
const ACTION_RE = /^([^/@\s]+\/[^/@\s]+)(\/[^@\s]*)?@([^\s#]+)$/;
const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

export function readDefaultVersion(repoRoot = REPO_ROOT): string {
  const candidate = path.join(repoRoot, '.claude-plugin', 'marketplace.json');
  try {
    const data = JSON.parse(fs.readFileSync(candidate, 'utf8')) as Record<string, unknown>;
    if (typeof data.version === 'string') return data.version;
    const meta = data.metadata;
    if (meta && typeof meta === 'object' && typeof (meta as Record<string, unknown>).version === 'string') {
      return (meta as Record<string, unknown>).version as string;
    }
  } catch {
    // fallback below
  }
  return '0.0.0';
}

export function collectActionUses(repoRoot = REPO_ROOT): Map<string, ActionUse> {
  const workflowsDir = path.join(repoRoot, '.github', 'workflows');
  const found = new Map<string, ActionUse>();
  if (!fs.existsSync(workflowsDir) || !fs.statSync(workflowsDir).isDirectory()) {
    return found;
  }
  const names = fs.readdirSync(workflowsDir).sort();
  for (const name of names) {
    if (!name.endsWith('.yml') && !name.endsWith('.yaml')) continue;
    const filePath = path.join(workflowsDir, name);
    let content: string;
    try {
      content = fs.readFileSync(filePath, 'utf8');
    } catch {
      throw new Error('workflow source is unreadable');
    }
    for (const line of content.split(/\r?\n/)) {
      const m = USES_RE.exec(line);
      if (!m || !m[1]) continue;
      const refStr = m[1].trim();
      if (refStr.startsWith('./') || refStr.startsWith('docker://')) continue;
      const am = ACTION_RE.exec(refStr);
      if (!am || !am[1] || !am[3]) continue;
      const repo = am[1];
      const subpath = am[2] ?? '';
      const ref = am[3];
      found.set(`${repo}${subpath}@${ref}`, { repo, ref, subpath });
    }
  }
  return found;
}

export function collectNpmDependencies(repoRoot = REPO_ROOT): Map<string, { name: string; version: string }> {
  const mcpDir = path.join(repoRoot, 'mcp');
  const found = new Map<string, { name: string; version: string }>();
  if (!fs.existsSync(mcpDir) || !fs.statSync(mcpDir).isDirectory()) {
    return found;
  }
  for (const entry of fs.readdirSync(mcpDir).sort()) {
    const lockfile = path.join(mcpDir, entry, 'package-lock.json');
    if (!fs.existsSync(lockfile) || !fs.statSync(lockfile).isFile()) continue;
    let data: unknown;
    try {
      data = JSON.parse(fs.readFileSync(lockfile, 'utf8'));
    } catch {
      throw new Error('dependency lockfile is unreadable or invalid JSON');
    }
    if (!data || typeof data !== 'object' || Array.isArray(data)) {
      throw new Error('dependency lockfile must be an object');
    }
    const packages = (data as Record<string, unknown>).packages;
    if (!packages || typeof packages !== 'object' || Array.isArray(packages)) {
      throw new Error('dependency lockfile packages must be an object');
    }
    for (const [pkgPath, meta] of Object.entries(packages as Record<string, unknown>)) {
      if (!pkgPath || !meta || typeof meta !== 'object' || Array.isArray(meta)) continue;
      const record = meta as Record<string, unknown>;
      if (record.dev) continue;
      if (typeof record.version !== 'string') continue;
      const idx = pkgPath.lastIndexOf('node_modules/');
      const name = idx >= 0 ? pkgPath.slice(idx + 'node_modules/'.length) : pkgPath;
      found.set(`${name}@${record.version}`, { name, version: record.version });
    }
  }
  return found;
}

function encodeNpmPurlName(name: string): string {
  return name
    .split('/')
    .map((segment) => encodeURIComponent(segment))
    .join('/');
}

export function buildSbom(version: string, repo: string, repoRoot = REPO_ROOT): CycloneDxSbom {
  const timestamp = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');
  const components: SbomComponent[] = [];

  const actionEntries = [...collectActionUses(repoRoot).entries()].sort(([a], [b]) =>
    a < b ? -1 : a > b ? 1 : 0,
  );
  for (const [, { repo: actionRepo, ref, subpath }] of actionEntries) {
    const comp: SbomComponent = {
      type: 'library',
      name: actionRepo,
      version: ref,
      purl: `pkg:github/${actionRepo}@${ref}`,
      externalReferences: [{ type: 'vcs', url: `https://github.com/${actionRepo}` }],
    };
    if (subpath) {
      comp.properties = [{ name: 'github:action:subpath', value: subpath.replace(/^\/+/, '') }];
    }
    components.push(comp);
  }

  const npmEntries = [...collectNpmDependencies(repoRoot).values()].sort((a, b) => {
    if (a.name !== b.name) return a.name < b.name ? -1 : 1;
    return a.version < b.version ? -1 : a.version > b.version ? 1 : 0;
  });
  for (const { name, version: pkgVersion } of npmEntries) {
    components.push({
      type: 'library',
      name,
      version: pkgVersion,
      purl: `pkg:npm/${encodeNpmPurlName(name)}@${pkgVersion}`,
    });
  }

  return {
    bomFormat: 'CycloneDX',
    specVersion: '1.5',
    version: 1,
    metadata: {
      timestamp,
      tools: [{ vendor: 'sdd-forge', name: 'generate-sbom', version: '1.0' }],
      component: {
        type: 'application',
        name: 'sdd-forge',
        version,
        purl: `pkg:github/${repo}@${version}`,
        description: 'SDD plugin suite with deterministic enforcement layer and cross-platform installers.',
        externalReferences: [{ type: 'vcs', url: `https://github.com/${repo}` }],
      },
    },
    components,
  };
}

function parseArgs(argv: readonly string[]): {
  version: string | null;
  repo: string;
  output: string | null;
  sourceRoot: string;
} {
  let version: string | null = null;
  let repo = 'aharada54914/sdd-forge';
  let output: string | null = null;
  let sourceRoot = REPO_ROOT;

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i] ?? '';
    if (arg === '--version' && argv[i + 1] !== undefined) version = argv[++i] ?? null;
    else if (arg.startsWith('--version=')) version = arg.slice('--version='.length);
    else if (arg === '--repo' && argv[i + 1] !== undefined) repo = argv[++i] ?? repo;
    else if (arg.startsWith('--repo=')) repo = arg.slice('--repo='.length);
    else if (arg === '--output' && argv[i + 1] !== undefined) output = argv[++i] ?? null;
    else if (arg.startsWith('--output=')) output = arg.slice('--output='.length);
    else if (arg === '--source-root' && argv[i + 1] !== undefined) sourceRoot = argv[++i] ?? sourceRoot;
    else if (arg.startsWith('--source-root=')) sourceRoot = arg.slice('--source-root='.length);
  }
  return { version, repo, output, sourceRoot };
}

function main(): number {
  const args = parseArgs(process.argv.slice(2));
  if (!fs.existsSync(args.sourceRoot) || !fs.statSync(args.sourceRoot).isDirectory()) {
    process.stderr.write('generate-sbom: source root must be a directory\n');
    return 2;
  }
  const version = args.version || readDefaultVersion(args.sourceRoot);
  let sbom: CycloneDxSbom;
  try {
    sbom = buildSbom(version, args.repo, args.sourceRoot);
  } catch {
    process.stderr.write('SBOM_SOURCE_INVALID: source inputs could not be inventoried\n');
    return 1;
  }
  const text = `${JSON.stringify(sbom, null, 2)}\n`;
  if (args.output) {
    fs.writeFileSync(args.output, text, 'utf8');
    process.stderr.write(
      `Wrote SBOM for ${args.repo}@${version} with ${sbom.components.length} component(s) to ${args.output}\n`,
    );
  } else {
    process.stdout.write(text);
  }
  return 0;
}

if (path.resolve(process.argv[1] || '') === path.resolve(fileURLToPath(import.meta.url))) {
  process.exit(main());
}
