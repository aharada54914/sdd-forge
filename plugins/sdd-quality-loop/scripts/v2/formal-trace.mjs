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
  const constraints = (state, prime) => fields.map((field) => field + prime + ' = ' + literal(state[field]));
  const init = ['Init', 'sddStep = 0', ...constraints(events[0].state, '')].join(' /\\ ');
  const transitions = events.slice(1).map(({ action, actor, state }, index) => {
    if (!actions.includes(action)) throw new Error('Unmapped trace action');
    const call = actors.includes(action) ? action + '(' + literal(actor) + ')' : action;
    return (
      '  \\/ ' +
      ['Next', call, 'sddStep = ' + index, "sddStep' = " + (index + 1), ...constraints(state, "'")].join(' /\\ ')
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
  // Preserve the baseline model constants and state constraints. Ambiguous cfg
  // forms are rejected by TLC rather than silently enabling a different model.
  const original = fs.readFileSync(cfg, 'utf8');
  const constants = original
    .split(/\r?\n/)
    .filter((line) => !/^\s*(?:SPECIFICATION|INIT|NEXT|INVARIANTS?|CHECK_DEADLOCK)\b/.test(line));
  const traceCfg = path.join(directory, 'SDDTraceReplay.cfg');
  fs.writeFileSync(
    traceCfg,
    [...constants, 'INIT TraceInit', 'NEXT TraceNext', 'INVARIANT TraceIncomplete', 'CHECK_DEADLOCK FALSE', ''].join(
      '\n',
    ),
  );
  return { model: tla, cfg: traceCfg };
}
