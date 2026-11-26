import fs from 'node:fs';
import path from 'node:path';

const operatorName = '[A-Za-z][A-Za-z0-9_]*';
const identifier = new RegExp('^' + operatorName + '$');

// TLC treats /\, [], ]_, << and >> as indivisible tokens. Each token
// boundary can contain whitespace, including the whitespace left by a comment.
const tuple = '<<\\s*' + operatorName + '(?:\\s*,\\s*' + operatorName + ')*\\s*>>';
const safetyFormula = new RegExp([
  '^(' + operatorName + ')', '/\\\\', '\\[\\]', '\\[', '(' + operatorName + ')', '\\]_', '(?:' + operatorName + '|' + tuple + ')$',
].join('\\s*'));

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

function blockCommentEnd(source, start, kind) {
  const delimiters = /\(\*|\*\)/g;
  delimiters.lastIndex = start;
  let depth = 1;
  while (depth) {
    const next = delimiters.exec(source);
    if (!next) throw new Error('Unterminated ' + kind + ' comment');
    depth += next[0] === '(*' ? 1 : -1;
  }
  return delimiters.lastIndex;
}

// SANY's BEGIN_MODULE token consumes four or more hyphens, ASCII spaces, and
// the literal MODULE. The module name can start immediately after the token.
export const tlaModuleStart = /-{4,} *MODULE/;

// Expose only model code to declaration checks. Comments are whitespace and
// strings remain opaque operands, so neither can introduce a new definition.
export function tlaDeclarationSource(source) {
  // The model lexer starts at the outer module. Quotes and comment delimiters in the preamble are prose.
  const header = source.search(tlaModuleStart);
  if (header < 0) return '';
  const specials = new RegExp(tlaModuleStart.source + '|' + /={4,}|\\\*[^\r\n]*|\(\*|\*\)|"(?:[^"\\\r\n]|\\[^\r\n])*"|"/.source, 'g');
  let code = '';
  let moduleDepth = 0;
  let start = header;
  specials.lastIndex = header;
  let match;
  while ((match = specials.exec(source))) {
    code += source.slice(start, match.index);
    const token = match[0];
    if (token.startsWith('-')) {
      moduleDepth++;
      code += token;
    } else if (token.startsWith('=')) {
      code += token;
      // Source files may contain free-form prose after the outer module.
      if (moduleDepth > 0) {
        moduleDepth--;
        if (moduleDepth === 0) return code;
      }
    } else if (token === '(*') {
      specials.lastIndex = blockCommentEnd(source, specials.lastIndex, 'TLA+');
      code += source.slice(match.index, specials.lastIndex).replace(/[^\r\n]+/g, ' ');
    } else if (token === '"' || token === '*)') {
      throw new Error('Invalid TLA+ string or comment delimiter');
    } else {
      code += token.startsWith('"') ? '""' : ' ';
    }
    start = specials.lastIndex;
  }
  return code + source.slice(start);
}

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
      lexer.lastIndex = blockCommentEnd(config, lexer.lastIndex, 'baseline CFG');
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
    const source = tlaDeclarationSource(fs.readFileSync(model, 'utf8'));
    // Do not infer the behavior from an overridden or ambiguously scoped definition.
    const overridden = sections.some(({ key, tokens }) => /^CONSTANTS?$/.test(key) &&
      tokens.some((token, index) => token === spec && tokens[index + 1] === '<-'));
    const headers = [...source.matchAll(new RegExp(tlaModuleStart, 'g'))];
    const footer = /^[ \t]*={4,}[ \t]*\r?$/m.exec(source);
    const module = headers.length === 1 && footer ? source.slice(headers[0].index, footer.index) : '';
    const parts = module.split(new RegExp('^[ \\t]*' + spec + '\\s*==', 'm'));
    // A LET-local definition can shadow an operator inherited through EXTENDS.
    // Only match a definition outside the declaration lists of active LETs.
    let letDepth = 0;
    for (const [token] of parts[0].matchAll(/\b(?:LET|IN)\b/g)) letDepth += token === 'LET' ? 1 : -1;
    const nextDefinition = /^[ \t]*[A-Za-z]\w*\s*(?:\([^()]*\)\s*)?==/m;
    const body = parts[1]?.split(nextDefinition, 1)[0].trim();
    const safety = safetyFormula.exec(body || '');
    if (
      operators.INIT ||
      operators.NEXT ||
      overridden ||
      letDepth !== 0 ||
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
  return { model: tla, cfg: traceCfg, actions: events.map((event) => event.action) };
}
