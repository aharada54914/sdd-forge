import fs from 'node:fs';
import path from 'node:path';
import { LINTABLE } from './lint-diff.mjs';

const EXTENSIONS = ['.ts', '.tsx', '.mts', '.cts', '.js', '.jsx', '.mjs', '.cjs'];

export function projectFile(root, rel) {
  const absolute = path.resolve(root, rel);
  const fromRoot = path.relative(root, absolute);
  if (!fromRoot || fromRoot.split(path.sep).includes('..') || path.isAbsolute(fromRoot)) return null;
  if (!fs.statSync(absolute, { throwIfNoEntry: false })?.isFile()) return null;
  // Do not cross symlinks while reading user-controlled import paths.
  return fs.realpathSync(absolute) === absolute ? absolute : null;
}

function resolveImport(root, from, specifier) {
  const rel = path.posix.normalize(path.posix.join(path.posix.dirname(from), specifier));
  if (rel.split('/').some(part => ['..', '.git', 'node_modules'].includes(part))) return null;
  let candidates = [rel];
  const ext = path.posix.extname(rel);
  if (!ext) candidates = EXTENSIONS.flatMap(suffix => [rel + suffix, rel + '/index' + suffix]);
  else if (['.js', '.mjs', '.cjs'].includes(ext)) {
    candidates.push(rel.slice(0, -ext.length) + ext.replace('js', 'ts'));
  }
  return candidates.find(candidate => LINTABLE.test(candidate) && projectFile(root, candidate)) ?? null;
}

// Include unchanged dependencies to discover cycles that cross the diff boundary.
// Report the source range of the changed edge, not all members of the cycle.
export function dependencyCycles(root, seeds, importsFor, inScope) {
  const graph = new Map();
  const queue = [...seeds];
  for (let i = 0; i < queue.length; i++) {
    const from = queue[i];
    if (graph.has(from)) continue;
    const edges = [];
    graph.set(from, edges);
    for (const edge of importsFor(from)) {
      const target = resolveImport(root, from, edge.specifier);
      if (!target) continue;
      edges.push({ ...edge, target });
      if (!graph.has(target)) queue.push(target);
    }
  }
  // Kosaraju's two passes, with explicit stacks so long import chains are safe.
  const visited = new Set();
  const order = [];
  const backwards = new Map([...graph.keys()].map(key => [key, []]));
  for (const [source, edges] of graph) {
    for (const { target } of edges) backwards.get(target).push(source);
    if (visited.has(source)) continue;
    const stack = [[source, 0]];
    visited.add(source);
    while (stack.length) {
      const frame = stack.at(-1);
      const next = graph.get(frame[0])[frame[1]++];
      if (!next) { order.push(stack.pop()[0]); continue; }
      if (!visited.has(next.target)) { visited.add(next.target); stack.push([next.target, 0]); }
    }
  }
  const group = new Map();
  for (const source of order.reverse()) {
    if (group.has(source)) continue;
    const stack = [source];
    group.set(source, source);
    while (stack.length) {
      for (const prev of backwards.get(stack.pop())) {
        if (group.has(prev)) continue;
        group.set(prev, source);
        stack.push(prev);
      }
    }
  }
  const findings = [];
  for (const from of seeds) {
    for (const edge of graph.get(from)) {
      if (inScope(from, edge) && group.get(from) === group.get(edge.target)) {
        findings.push({ rule: 'no-dependency-cycle', path: from, line: edge.line, endLine: edge.endLine, snippet: edge.specifier });
      }
    }
  }
  return findings;
}
