import { parseSource } from './source-ast.mjs';

const NESTED = new Set(['if_statement', 'switch_statement', 'for_statement', 'for_in_statement',
  'while_statement', 'do_statement', 'try_statement', 'ternary_expression']);
const SCOPES = new Set(['statement_block', 'program', 'switch_case', 'switch_default']);
const FUNCTIONS = new Set(['function_declaration', 'function_expression', 'arrow_function',
  'method_definition', 'generator_function', 'generator_function_declaration']);
const SUPPRESS = /^\s*(?:\/\/|\/\*+|\*)?\s*(?:eslint-disable(?:-next-line|-line)?|@ts-(?:ignore|nocheck)|nosemgrep|(?:agent|sdd)-lint-disable)\b/;

function lineSpan(node) {
  const { start, end } = node.range();
  return [start.line + 1, end.line + (end.column ? 1 : 0)];
}

// Limit combinations to bare flags, negation and boolean operators. Comparisons,
// calls and property reads may have side effects or represent unrelated values.
function readFlags(node, flags) {
  if (!node) return false;
  if (node.is('identifier')) {
    flags.add(node.text());
    return true;
  }
  if (node.is('parenthesized_expression')) return readFlags(node.namedChildren()[0], flags);
  if (node.is('unary_expression') && node.field('operator')?.text() === '!') {
    return readFlags(node.field('argument'), flags);
  }
  if (node.is('binary_expression') && ['&&', '||'].includes(node.field('operator')?.text())) {
    return readFlags(node.field('left'), flags) && readFlags(node.field('right'), flags);
  }
  return false;
}

function moduleLiteral(node) {
  if (!node?.is('string')) return null;
  const parts = node.namedChildren();
  return parts.length === 1 && parts[0].is('string_fragment') ? parts[0].text() : null;
}

function staticImport(node) {
  if (node.is('import_statement') || node.is('export_statement')) {
    if (node.children().some(child => child.kind() === 'type')) return null;
    return node.field('source');
  }
  if (node.is('call_expression') && ['require', 'import'].includes(node.field('function')?.text())) {
    return node.field('arguments')?.namedChildren()[0];
  }
  return null;
}

function memberIs(node, object, property) {
  return node?.is('member_expression') && node.field('object')?.text() === object &&
    node.field('property')?.text() === property;
}

function localEdge(node) {
  const literal = staticImport(node);
  const specifier = moduleLiteral(literal);
  if (!specifier?.startsWith('./') && !specifier?.startsWith('../')) return null;
  const [line, endLine] = lineSpan(literal);
  return { specifier, line, endLine };
}

// Transitive dependencies only need import edges. Keep their AST traversal in
// the native parser, avoiding lint queries on unchanged dependency bodies.
export function readImports(source, filename) {
  return parseSource(source, filename).findAll({
    rule: { any: ['import_statement', 'export_statement', 'call_expression'].map(kind => ({ kind })) }
  }).map(localEdge).filter(Boolean);
}

export function analyzeSource(source, filename, { maxDepth = 6 } = {}) {
  const ast = parseSource(source, filename);
  const findings = [];
  const imports = [];
  const groups = new Map();

  function record(rule, node, snippet = null) {
    const [line, endLine] = lineSpan(node);
    findings.push({ rule, line, endLine, snippet: snippet ?? node.text().slice(0, 120) });
  }

  function visit(node, depth, scope) {
    const kind = node.kind();
    if (FUNCTIONS.has(kind)) depth = 0;
    if (SCOPES.has(kind)) scope = node.id();
    const elseIf = kind === 'if_statement' && node.parent()?.is('else_clause');
    if (NESTED.has(kind) && !elseIf && ++depth > maxDepth) {
      record('no-deep-nesting', node.child(0) ?? node, `depth ${depth} exceeds ${maxDepth}`);
    }
    if (kind === 'if_statement') {
      const condition = node.field('condition');
      const flags = new Set();
      if (readFlags(condition, flags) && flags.size >= 2) {
        const key = JSON.stringify([scope, ...[...flags].sort()]);
        if (!groups.has(key)) groups.set(key, []);
        groups.get(key).push(condition);
      }
    }
    if (kind === 'call_expression') {
      const fn = node.field('function');
      if (fn?.text() === 'eval') record('no-eval-or-new-function', fn);
      if (fn?.text() === 'execSync') record('no-child-process-shell-true', fn);
      if (memberIs(fn, 'console', 'log')) record('no-console-log', fn);
    }
    if (kind === 'new_expression' && node.field('constructor')?.text() === 'Function') {
      record('no-eval-or-new-function', node.field('constructor'));
    }
    if (kind === 'pair' && node.field('key')?.text() === 'shell' && node.field('value')?.is('true')) {
      record('no-child-process-shell-true', node);
    }
    if (kind === 'catch_clause' && node.field('body')?.namedChildren().length === 0) {
      record('no-empty-catch', node);
    }
    if (kind === 'comment') {
      const firstLine = node.range().start.line + 1;
      for (const [index, text] of node.text().split('\n').entries()) {
        if (SUPPRESS.test(text)) {
          findings.push({ rule: 'no-inline-suppression', line: firstLine + index, endLine: firstLine + index,
            snippet: text.trim().slice(0, 120) });
        }
      }
    }
    if (kind === 'ERROR') record('syntax-error', node);
    if (['import_statement', 'export_statement', 'call_expression'].includes(kind)) {
      const edge = localEdge(node);
      if (edge) imports.push(edge);
    }
    for (const child of node.namedChildren()) visit(child, depth, scope);
  }
  visit(ast, 0, ast.id());
  for (const conditions of groups.values()) {
    if (conditions.length > 1) {
      for (const condition of conditions) record('no-combinatorial-flags', condition);
    }
  }
  return { findings, imports };
}
