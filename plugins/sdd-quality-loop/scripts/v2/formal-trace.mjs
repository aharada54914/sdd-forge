import fs from 'node:fs';
import path from 'node:path';

const identifier = /^[A-Za-z][A-Za-z0-9_]*$/;

function literal(value) {
  if (typeof value === 'boolean') return value ? 'TRUE' : 'FALSE';
  if (Number.isSafeInteger(value) && value >= 0) return String(value);
  if (typeof value === 'string' && /^[\w .:-]+$/.test(value)) return JSON.stringify(value);
  if (Array.isArray(value)) return '{' + value.map(literal).join(', ') + '}';
  throw new Error('Unsupported TLA+ trace value');
}

// TLC 2.19 separates sections by reserved tokens, independently of line breaks.
// Also recognize newer ALIAS/POSTCONDITION sections so replay rejects them.
const cfgKeywords = new Set([
  'CONSTANT', 'CONSTANTS', 'CONSTRAINT', 'CONSTRAINTS', 'ACTION_CONSTRAINT', 'ACTION_CONSTRAINTS',
  'INIT', 'NEXT', 'SPECIFICATION', 'INVARIANT', 'INVARIANTS', 'CHECK_DEADLOCK',
  'PROPERTY', 'PROPERTIES', 'TYPE', 'TYPE_CONSTRAINT', 'VIEW', 'SYMMETRY', 'ALIAS', 'POSTCONDITION',
]);

export function parseCfgSections(config) {
  // Strings are atomic. Keep the original section text for the checker so that
  // quoted values, operator overrides and punctuation are never reconstructed.
  const lexer = /\s+|\\\*[^\r\n]*|\(\*|\*\)|"(?:[^"\\\r\n]|\\[^\r\n])*"|[A-Za-z0-9_]+|<-|[^\s]/gy;
  const sections = [];
  let section;
  let match;
  while ((match = lexer.exec(config))) {
    const token = match[0];
    if (token === '(*') {
      const delimiters = /\(\*|\*\)/g;
      delimiters.lastIndex = lexer.lastIndex;
      let depth = 1;
      while (depth) {
        const next = delimiters.exec(config);
        if (!next) throw new Error('Unterminated baseline CFG comment');
        depth += next[0] === '(*' ? 1 : -1;
      }
      lexer.lastIndex = delimiters.lastIndex;
    } else if (token === '"' || token === '*)') {
      throw new Error('Invalid baseline CFG string or comment delimiter');
    } else if (!token.trim() || token.startsWith('\\*')) {
      continue;
    } else if (cfgKeywords.has(token)) {
      if (section) section.end = match.index;
      section = { key: token, tokens: [], start: match.index, end: config.length };
      sections.push(section);
    } else {
      if (!section) throw new Error('Unsupported baseline CFG directive: ' + token);
      section.tokens.push(token);
    }
  }
  return sections.map(({ key, tokens, start, end }) => ({ key, tokens, text: config.slice(start, end).trimEnd() }));
}

// Replay supports explicit behavior operators and the canonical finite-prefix
// safety specification. Other temporal formulas require a different projection.
function replayBehavior(model, cfg) {
  const sections = parseCfgSections(fs.readFileSync(cfg, 'utf8'));
  const operators = {};
  const retained = [];
  for (const { key, tokens, text } of sections) {
    if (['INIT', 'NEXT', 'SPECIFICATION'].includes(key)) {
      if (operators[key] || tokens.length !== 1 || !identifier.test(tokens[0])) throw new Error('Invalid baseline CFG ' + key);
      operators[key] = tokens[0];
    } else if (/^INVARIANTS?$/.test(key)) {
      if (!tokens.length || !tokens.every((name) => identifier.test(name)))
        throw new Error('Unsupported baseline CFG invariants');
    } else if (key === 'CHECK_DEADLOCK') {
      if (tokens.length !== 1 || !['TRUE', 'FALSE'].includes(tokens[0])) throw new Error('Invalid baseline CFG CHECK_DEADLOCK');
    } else if (/^CONSTANTS?$|^(?:ACTION_)?CONSTRAINTS?$/.test(key)) {
      retained.push(text);
    } else {
      throw new Error('Unsupported baseline CFG directive: ' + key);
    }
  }

  if (operators.SPECIFICATION) {
    const spec = operators.SPECIFICATION;
    const source = fs.readFileSync(model, 'utf8').replace(/\\\*[^\n]*/g, '');
    // Do not infer the behavior from an overridden or ambiguously scoped definition.
    const overridden = sections.some(({ key, tokens }) => /^CONSTANTS?$/.test(key) &&
      tokens.some((token, index) => token === spec && tokens[index + 1] === '<-'));
    const parts = source.split(new RegExp('^' + spec + '[ \\t]*==', 'm'));
    const body = parts[1]?.split(/^\s*(?:={4,}|[A-Za-z]\w*(?:\([^)\n]*\))?[ \t]*==)/m, 1)[0].trim();
    const safety =
      /^([A-Za-z]\w*)\s*\/\\\s*\[\]\s*\[([A-Za-z]\w*)\]\s*_(?:[A-Za-z]\w*|<<\s*[A-Za-z]\w*(?:\s*,\s*[A-Za-z]\w*)*\s*>>)$/.exec(
        body || '',
      );
    if (
      operators.INIT ||
      operators.NEXT ||
      overridden ||
      source.includes('(*') ||
      (source.match(/-{4,}\s*MODULE\b/g) || []).length !== 1 ||
      parts.length !== 2 ||
      !safety
    )
      throw new Error('Unsupported baseline SPECIFICATION for trace replay: ' + spec);
    return { init: safety[1], next: safety[2], retained };
  }
  if (!operators.INIT || !operators.NEXT) throw new Error('Baseline CFG must select both INIT and NEXT');
  return { init: operators.INIT, next: operators.NEXT, retained };
}

// Check for an actual path through the baseline model matching every observed
// action and projected state. Reaching the last observation refutes TraceIncomplete.
export function prepareTraceReplay({ model, cfg, contract, tracePath, directory }) {
  const { fields, actor_actions: actors = [] } = contract.trace;
  const actions = Object.keys(contract.actions || contract.mapping);
  const events = fs
    .readFileSync(tracePath, 'utf8')
    .trim()
    .split(/\r?\n/)
    .map((line) => JSON.parse(line));
  if (
    !Array.isArray(fields) ||
    !fields.length ||
    !fields.every((field) => identifier.test(field)) ||
    !actions.every((action) => identifier.test(action)) ||
    !actors.every((action) => actions.includes(action)) ||
    events.length < 2
  )
    throw new Error('Trace needs mapped state fields, actions and at least one transition');
  const module = path.basename(model, '.tla');
  if (!identifier.test(module) || module === 'SDDTraceReplay') throw new Error('Invalid source module name');
  fs.mkdirSync(directory);
  for (const file of fs.readdirSync(path.dirname(model)).filter((file) => file.endsWith('.tla')))
    fs.copyFileSync(path.join(path.dirname(model), file), path.join(directory, file));
  const behavior = replayBehavior(model, cfg);
  const constraints = (state, prime) => fields.map((field) => field + prime + ' = ' + literal(state[field]));
  const init = [behavior.init, 'sddStep = 0', ...constraints(events[0].state, '')].join(' /\\ ');
  const transitions = events.slice(1).map(({ action, actor, state }, index) => {
    if (!actions.includes(action)) throw new Error('Unmapped trace action');
    const call = actors.includes(action) ? action + '(' + literal(actor) + ')' : action;
    return (
      '  \\/ ' +
      [behavior.next, call, 'sddStep = ' + index, "sddStep' = " + (index + 1), ...constraints(state, "'")].join(' /\\ ')
    );
  });
  const tla = path.join(directory, 'SDDTraceReplay.tla');
  fs.writeFileSync(
    tla,
    [
      '---- MODULE SDDTraceReplay ----',
      'EXTENDS ' + module,
      'VARIABLE',
      '\\* @type: Int;',
      'sddStep',
      'TraceInit == ' + init,
      'TraceNext ==',
      ...transitions,
      'TraceIncomplete == sddStep < ' + (events.length - 1),
      '====',
      '',
    ].join('\n'),
  );
  const traceCfg = path.join(directory, 'SDDTraceReplay.cfg');
  fs.writeFileSync(
    traceCfg,
    [
      ...behavior.retained,
      'INIT TraceInit',
      'NEXT TraceNext',
      'INVARIANT TraceIncomplete',
      'CHECK_DEADLOCK FALSE',
      '',
    ].join('\n'),
  );
  return { model: tla, cfg: traceCfg };
}
