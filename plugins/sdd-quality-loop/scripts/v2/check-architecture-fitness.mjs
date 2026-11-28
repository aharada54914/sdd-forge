#!/usr/bin/env node
/**
 * check-architecture-fitness.mjs — Strategic DDD Fitness Function & Ubiquitous Language Gate (ADR-0056 Phase 5).
 *
 * Enforces:
 *   1. `domain-isolated`: files under a Bounded Context's `domainDir` must not import
 *      infrastructure/UI/IO packages (`node:http`, `express`, `prisma`, `infra/`, `ui/`).
 *   2. `context-via-api`: cross-context imports between Bounded Contexts declared in
 *      `sdd/context-map.json` must target an `allowedDependencies` context AND import
 *      only through its declared `publicApi` entrypoint.
 *   3. Ubiquitous Language: detects `forbiddenSynonyms` from `sdd/glossary.json` in source identifiers.
 *   4. R-04 Context Hygiene: blocks `CLAUDE.md` coexistence alongside `AGENTS.md`.
 *
 * Usage:
 *   node plugins/sdd-quality-loop/scripts/v2/check-architecture-fitness.mjs --root <dir> [--json]
 *
 * Exit codes:
 *   0 — PASS
 *   1 — Architecture fitness or ubiquitous language violation found
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const INFRA_IMPORT_RE = /(?:^|\/)(?:infra|infrastructure|ui|presentation|controllers|db|prisma|express|fastify|node:http|node:https)(?:\/|$)/i;
const IMPORT_SPEC_RE = /(?:import\s+(?:[\s\S]*?\s+from\s+)?|require\s*\(\s*)['"]([^'"]+)['"]/g;
const PY_IMPORT_RE = /^(?:from\s+([\w.]+)\s+import|import\s+([\w.]+))/gm;

function walkSourceFiles(dir, root, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (e.name.startsWith('.') || e.name === 'node_modules' || e.name === 'dist' || e.name === 'sdd' || e.name === 'specs') continue;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) {
      walkSourceFiles(full, root, out);
    } else if (/\.(?:ts|tsx|js|mjs|cjs|py)$/.test(e.name)) {
      out.push(path.relative(root, full).split(path.sep).join('/'));
    }
  }
  return out;
}

function extractImports(text, ext) {
  const specs = [];
  if (ext === '.py') {
    for (const m of text.matchAll(PY_IMPORT_RE)) {
      const mod = m[1] || m[2];
      if (mod) specs.push(mod);
    }
  } else {
    for (const m of text.matchAll(IMPORT_SPEC_RE)) {
      if (m[1]) specs.push(m[1]);
    }
  }
  return specs;
}

function normalizePosix(p) {
  return p.split(path.sep).join('/');
}

function stripExt(p) {
  return p.replace(/\.(?:ts|tsx|js|mjs|cjs)$/, '');
}

export function checkArchitectureFitness({ root } = {}) {
  const absRoot = path.resolve(root);
  const violations = [];

  // 1. Check CLAUDE.md coexistence (R-04)
  const checkClaudeWalk = (dir, relBase) => {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      if (e.name === '.git' || e.name === 'node_modules') continue;
      const rel = relBase ? `${relBase}/${e.name}` : e.name;
      if (e.isDirectory()) checkClaudeWalk(path.join(dir, e.name), rel);
      else if (e.name === 'CLAUDE.md') {
        violations.push({
          rule: 'context-hygiene-r04',
          file: rel,
          reason: 'CLAUDE.md coexists with AGENTS.md (violates R-04)',
          remediation: `Remove ${rel} and keep instructions in AGENTS.md`,
        });
      }
    }
  };
  checkClaudeWalk(absRoot, '');

  const contextMapAbs = path.join(absRoot, 'sdd/context-map.json');
  const glossaryAbs = path.join(absRoot, 'sdd/glossary.json');
  const contextMap = fs.existsSync(contextMapAbs) ? JSON.parse(fs.readFileSync(contextMapAbs, 'utf8')) : null;
  const glossary = fs.existsSync(glossaryAbs) ? JSON.parse(fs.readFileSync(glossaryAbs, 'utf8')) : null;

  const sourceFiles = walkSourceFiles(absRoot, absRoot);

  // 2. Strategic DDD rules: domain-isolated & context-via-api
  if (contextMap && Array.isArray(contextMap.contexts)) {
    const rules = contextMap.fitnessRules || { domainIsolated: true, contextViaApi: true };
    const contexts = contextMap.contexts;
    const ownerOf = (relFile) => contexts.find((c) => relFile === c.rootDir || relFile.startsWith(`${c.rootDir}/`));

    for (const relFile of sourceFiles) {
      const owner = ownerOf(relFile);
      if (!owner) continue;
      const text = fs.readFileSync(path.join(absRoot, relFile), 'utf8');
      const ext = path.extname(relFile);
      const imports = extractImports(text, ext);

      const inDomain = owner.domainDir && (relFile === owner.domainDir || relFile.startsWith(`${owner.domainDir}/`));
      for (const spec of imports) {
        // Rule A: domain-isolated
        if (rules.domainIsolated && inDomain && INFRA_IMPORT_RE.test(spec)) {
          violations.push({
            rule: 'domain-isolated',
            file: relFile,
            reason: `Domain file in context '${owner.name}' imports infrastructure/IO dependency '${spec}'`,
            remediation: `Invert dependency behind a domain port interface inside ${owner.domainDir}`,
          });
        }

        // Rule B: context-via-api (relative imports crossing into another bounded context)
        if (rules.contextViaApi && spec.startsWith('.')) {
          const resolvedRel = normalizePosix(path.relative(absRoot, path.resolve(absRoot, path.dirname(relFile), spec)));
          const targetCtx = ownerOf(resolvedRel);
          if (targetCtx && targetCtx.name !== owner.name) {
            const allowed = Array.isArray(owner.allowedDependencies) ? owner.allowedDependencies : [];
            if (!allowed.includes(targetCtx.name)) {
              violations.push({
                rule: 'context-via-api',
                file: relFile,
                reason: `Context '${owner.name}' imports disallowed context '${targetCtx.name}' (${spec})`,
                remediation: `Remove cross-context import or declare '${targetCtx.name}' in sdd/context-map.json allowedDependencies`,
              });
            } else if (targetCtx.publicApi) {
              const normTarget = stripExt(resolvedRel);
              const normPublic = stripExt(targetCtx.publicApi);
              if (normTarget !== normPublic && normTarget !== targetCtx.rootDir) {
                violations.push({
                  rule: 'context-via-api',
                  file: relFile,
                  reason: `Context '${owner.name}' bypasses '${targetCtx.name}' publicApi (${targetCtx.publicApi}) via internal import '${spec}'`,
                  remediation: `Import only from '${targetCtx.publicApi}'`,
                });
              }
            }
          }
        }
      }
    }
  }

  // 3. Ubiquitous Language forbiddenSynonyms check
  if (glossary && Array.isArray(glossary.terms)) {
    const forbidden = [];
    for (const t of glossary.terms) {
      for (const syn of t.forbiddenSynonyms || []) {
        if (syn) forbidden.push({ synonym: syn, canonical: t.term });
      }
    }
    for (const relFile of sourceFiles) {
      const text = fs.readFileSync(path.join(absRoot, relFile), 'utf8');
      for (const { synonym, canonical } of forbidden) {
        const escaped = typeof RegExp.escape === 'function'
          ? RegExp.escape(synonym)
          : synonym.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        if (new RegExp(`\\b${escaped}\\b`).test(text)) {
          violations.push({
            rule: 'ubiquitous-language',
            file: relFile,
            reason: `Forbidden synonym '${synonym}' used instead of canonical term '${canonical}'`,
            remediation: `Rename '${synonym}' to '${canonical}' per sdd/glossary.json`,
          });
        }
      }
    }
  }

  return {
    passed: violations.length === 0,
    filesScanned: sourceFiles.length,
    violations,
  };
}

function parseCliArgs(argv) {
  const opts = { root: process.cwd(), json: false };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === '--root' && i + 1 < argv.length) opts.root = argv[++i];
    else if (argv[i] === '--json') opts.json = true;
  }
  return opts;
}

const isDirectMain =
  Boolean(process.argv[1]) &&
  (() => {
    try {
      return fs.realpathSync(path.resolve(process.argv[1])) === fs.realpathSync(fileURLToPath(import.meta.url));
    } catch {
      return path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url));
    }
  })();

if (isDirectMain) {
  const opts = parseCliArgs(process.argv.slice(2));
  const result = checkArchitectureFitness(opts);
  if (opts.json) {
    process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  } else if (!result.passed) {
    for (const v of result.violations) {
      process.stderr.write(`FITNESS FAIL [${v.rule}]: ${v.file} — ${v.reason}\n  Fix: ${v.remediation}\n`);
    }
  } else {
    process.stdout.write(`check-architecture-fitness: PASS (${result.filesScanned} source file(s) checked)\n`);
  }
  process.exit(result.passed ? 0 : 1);
}
