import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

// Reuse the repository's locked YAML parser; never interpret frontmatter as code.
const require = createRequire(new URL('../../mcp/sdd-forge-mcp/package.json', import.meta.url));
const horizontal = value => value.replace(/[ \t]+/g, ' ').trim();
const byteOrder = (a, b) => Buffer.compare(Buffer.from(a), Buffer.from(b));

function checkedNumber(value) {
  if (!Number.isFinite(value)) throw new Error('non-finite YAML value');
  if (Number.isInteger(value) && !Number.isSafeInteger(value)) throw new Error('unsafe YAML integer');
  return value;
}

function normalize(value, ancestors = new Set()) {
  if (typeof value === 'string') return horizontal(value);
  if (typeof value === 'number') return checkedNumber(value);
  if (value === null || typeof value !== 'object') return value;
  if (ancestors.has(value)) throw new Error('cyclic YAML alias');
  ancestors.add(value);
  const result = Array.isArray(value)
    ? value.map(item => normalize(item, ancestors))
    : Object.fromEntries(Object.keys(value).sort(byteOrder).map(key => [key, normalize(value[key], ancestors)]));
  ancestors.delete(value);
  return result;
}

try {
  if (process.argv.length !== 3) throw new Error('expected one Markdown file');
  const yaml = require('js-yaml');
  // Reject lossy integers during scalar construction, including mapping keys
  // that js-yaml would otherwise round before converting them to strings.
  const schema = new yaml.Schema(yaml.CORE_SCHEMA.tags.map(tag =>
    tag === yaml.intCoreTag || tag === yaml.floatCoreTag
      ? yaml.defineScalarTag(tag.tagName, {
        ...tag,
        resolve(...args) {
          const value = tag.resolve(...args);
          return value === yaml.NOT_RESOLVED ? value : checkedNumber(value);
        },
      }) : tag));
  const lines = new TextDecoder('utf-8', { fatal: true }).decode(readFileSync(process.argv[2]))
    .replace(/\r\n?/g, '\n').split('\n');
  let start = 0;
  let frontmatter = [];
  if (lines[0] === '---') {
    const end = lines.indexOf('---', 1);
    if (end === -1) throw new Error('unterminated frontmatter');
    const source = lines.slice(1, end).join('\n');
    const parsed = yaml.load(source, { schema });
    if (parsed !== undefined && (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed))) {
      throw new Error('frontmatter must be a key-value map');
    }
    const mapping = normalize(parsed ?? {});
    frontmatter = Object.keys(mapping).sort(byteOrder).map(key => ({ key, value: mapping[key] }));
    start = end + 1;
  }
  const headings = [];
  for (const line of lines.slice(start)) {
    if (line.startsWith('#')) {
      const match = /^(#{1,6})[ \t]+(.*)$/.exec(line);
      if (!match || !horizontal(match[2])) throw new Error('unrecognized or empty heading');
      headings.push({ level: match[1].length, text: horizontal(match[2]) });
    } else if (/^[ \t]*(?:={3,}|-{3,})[ \t]*$/.test(line)) {
      throw new Error('setext heading grammar is unsupported');
    }
  }
  process.stdout.write(JSON.stringify({ frontmatter, headings }) + '\n');
} catch (error) {
  process.stderr.write(`markdown AST parse failure: ${error.message}\n`);
  process.exitCode = 2;
}
