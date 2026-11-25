import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { createRequire, SourceMap } from 'node:module';
import { parseSource } from './source-ast.mjs';

// This compiler belongs to the lint tool checkout. Never load code or builders
// from the project passed to --root. Missing build inputs leave diagnostics intact.
const requireTool = createRequire(new URL('../../../mcp/sdd-forge-mcp/package.json', import.meta.url));
const bundlePath = 'mcp/sdd-forge-mcp/dist/index.js';
const maxBytes = 12 * 1024 * 1024;

function documentedCatch(source, filename, entry) {
  const catches = parseSource(source, filename).findAll({ rule: { kind: 'catch_clause' } });
  for (const clause of catches) {
    const start = clause.range().start;
    if (start.line !== entry.originalLine || start.column < entry.originalColumn) continue;
    // esbuild can map the entire generated '} catch' span to the preceding brace.
    const prefix = source.split('\n')[start.line].slice(entry.originalColumn, start.column);
    if (!/^}?\s*$/.test(prefix)) continue;
    const body = clause.field('body');
    const statements = body.namedChildren();
    if (!statements.length || !statements.every(n => n.is('comment'))) continue;
    const offset = body.range().start.index;
    if (source[offset] === '{') return offset + 1;
  }
  return null;
}

async function verifiedLines(root, lines) {
  const { build } = requireTool('./node_modules/esbuild');
  const pkg = path.join(root, 'mcp/sdd-forge-mcp');
  const dist = path.join(pkg, 'dist');
  const options = { absWorkingDir: pkg, entryPoints: ['src/index.ts'], bundle: true, platform: 'node',
    format: 'esm', outfile: 'dist/index.js', sourcemap: 'external', write: false, logLevel: 'silent' };
  const first = await build(options);
  const output = first.outputFiles.find(file => file.path === path.join(dist, 'index.js')).contents;
  const original = fs.readFileSync(path.join(root, bundlePath));
  if (!original.equals(output)) return [];
  const committedBundle = execFileSync('git', ['-C', root, 'show', 'HEAD:' + bundlePath],
    { maxBuffer: maxBytes, stdio: ['ignore', 'pipe', 'ignore'] });
  if (!original.equals(committedBundle)) return [];
  const sourceMap = JSON.parse(first.outputFiles.find(file => file.path.endsWith('.js.map')).text);
  const map = new SourceMap(sourceMap);
  const outputLines = original.toString('utf8').split('\n');
  const edits = new Map();
  const expected = new Map();
  const prefix = 'sdd_lint_provenance_';
  if (original.includes(prefix)) return [];

  for (const line of lines) {
    const text = outputLines[line - 1];
    if (!/^\s*} catch(?: \([^)]*\))? \{$/.test(text)) continue;
    const entry = map.findEntry(line - 1, text.indexOf('catch'));
    if (typeof entry.originalSource !== 'string') continue;
    const filename = path.resolve(dist, entry.originalSource);
    const rel = path.relative(root, filename);
    if (rel.startsWith('..' + path.sep) || path.isAbsolute(rel) || rel.split(path.sep).includes('node_modules')) continue;
    if (!/\.(?:[cm]?[jt]s|[jt]sx)$/.test(rel) || fs.realpathSync(filename) !== filename) continue;
    const embedded = sourceMap.sourcesContent[sourceMap.sources.indexOf(entry.originalSource)];
    if (typeof embedded !== 'string' || fs.readFileSync(filename, 'utf8') !== embedded) continue;
    const committed = execFileSync('git', ['-C', root, 'show', 'HEAD:' + rel.split(path.sep).join('/')],
      { encoding: 'utf8', maxBuffer: maxBytes, stdio: ['ignore', 'pipe', 'ignore'] });
    if (committed !== embedded || embedded.includes(prefix)) continue;
    const offset = documentedCatch(embedded, filename, entry);
    if (offset === null) continue;
    const marker = prefix + line;
    if (!edits.has(filename)) edits.set(filename, { source: embedded, changes: [] });
    edits.get(filename).changes.push({ offset, marker });
    expected.set(marker, line);
  }
  if (!edits.size) return [];

  // Prove that changing this source catch changes this generated catch.
  // A stale or misleading sourceMappingURL alone cannot satisfy this check.
  const instrument = { name: 'verify-catch-origin', setup(build) {
    build.onLoad({ filter: /\.[cm]?[jt]sx?$/ }, args => {
      const edit = edits.get(args.path);
      if (!edit) return;
      let contents = edit.source;
      for (const { offset, marker } of edit.changes.sort((a, b) => b.offset - a.offset)) {
        contents = contents.slice(0, offset) + 'console.warn("' + marker + '");' + contents.slice(offset);
      }
      const ext = path.extname(args.path);
      const loader = ext.endsWith('sx') ? ext.slice(1) : ext.endsWith('ts') ? 'ts' : 'js';
      return { contents, loader, resolveDir: path.dirname(args.path) };
    });
  } };
  // Both builds are in memory. Their outputs are compared as data and never run.
  const second = await build({ ...options, plugins: [instrument] });
  const regenerated = second.outputFiles.find(file => file.path === path.join(dist, 'index.js')).text;
  const unmarked = [];
  const verified = [];
  for (const text of regenerated.split('\n')) {
    const match = /^\s*console\.warn\("(sdd_lint_provenance_\d+)"\);$/.exec(text);
    if (!match) { unmarked.push(text); continue; }
    if (expected.get(match[1]) === unmarked.length) verified.push(unmarked.length);
  }
  return unmarked.join('\n') === original.toString('utf8') ? verified : [];
}

try {
  const { root, lines } = JSON.parse(fs.readFileSync(0, 'utf8'));
  process.stdout.write(JSON.stringify(await verifiedLines(root, lines)));
} catch {
  process.stdout.write('[]');
}
