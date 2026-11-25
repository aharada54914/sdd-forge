#!/usr/bin/env node
import fs from 'node:fs';
import { parseArgs } from 'node:util';

try {
  const { values } = parseArgs({ options: {
    risk: { type: 'string', default: 'standard' },
    reframe: { type: 'boolean', default: false },
  } });
  if (!['low', 'standard', 'high'].includes(values.risk)) throw new Error('risk must be low, standard or high');
  const template = fs.readFileSync(new URL('../skills/sdd-core-spec/templates/design.md', import.meta.url), 'utf8');
  const section = /^<!-- reframing:start -->\n([\s\S]*?)^<!-- reframing:end -->\n\n/m;
  if (!section.test(template)) throw new Error('design template lacks a reframing section');
  process.stdout.write(template.replace(section, values.risk === 'low' && !values.reframe ? '' : '$1\n'));
} catch (err) {
  process.stderr.write(err.message + '\n');
  process.exitCode = 2;
}
