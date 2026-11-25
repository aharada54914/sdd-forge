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

// Replay supports explicit behavior operators and the canonical finite-prefix
// safety specification. Other temporal formulas require a different projection.
function replayBehavior(model, cfg) {
  const sections = [];
  const config = fs.readFileSync(cfg, 'utf8').replace(/\\\*[^\n]*/g, '');
  for (const line of config.split(/\r?\n/).filter((line) => line.trim())) {
    const header =
      /^\s*(INIT|NEXT|SPECIFICATION|INVARIANTS?|CHECK_DEADLOCK|CONSTANTS?|(?:ACTION_)?CONSTRAINTS?)\b(.*)$/.exec(line);
    if (header) sections.push({ key: header[1], lines: [header[2]] });
    // The remaining TLC 2.19 section keywords have semantics replay cannot project.
    // Uppercase identifiers and values can continue a section across line breaks.
    else if (/^\s*(VIEW|SYMMETRY|PROPERT(?:Y|IES)|TYPE(?:_CONSTRAINT)?)\b/.test(line))
      throw new Error('Unsupported baseline CFG directive: ' + line.trim());
    else if (sections.length) sections.at(-1).lines.push(line);
    else throw new Error('Unsupported baseline CFG for trace replay');
  }
  const operators = {};
  const retained = [];
  for (const { key, lines } of sections) {
    const value = lines.join('\n').trim();
    if (['INIT', 'NEXT', 'SPECIFICATION'].includes(key)) {
      if (operators[key] || !identifier.test(value)) throw new Error('Invalid baseline CFG ' + key);
      operators[key] = value;
    } else if (/^INVARIANTS?$/.test(key)) {
      if (!value.split(/\s+/).every((name) => identifier.test(name)))
        throw new Error('Unsupported baseline CFG invariants');
    } else if (key === 'CHECK_DEADLOCK') {
      if (!/^(TRUE|FALSE)$/.test(value)) throw new Error('Invalid baseline CFG CHECK_DEADLOCK');
    } else retained.push(key + ' ' + value);
  }

  if (operators.SPECIFICATION) {
    const spec = operators.SPECIFICATION;
    const source = fs.readFileSync(model, 'utf8').replace(/\\\*[^\n]*/g, '');
    // Do not infer the behavior from an overridden or ambiguously scoped definition.
    const overridden = new RegExp('\\b' + spec + '\\s*<-').test(config);
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
