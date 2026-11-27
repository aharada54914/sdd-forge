import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
let parser;

/** Parse a source file with the same grammar as the Layer 2/3 lint rules. */
export function parseSource(source, filename = 'source.mjs') {
  if (!parser) {
    try {
      parser = require('@ast-grep/napi');
    } catch (cause) {
      throw new Error('Agent Lint requires ast-grep. Run npm ci --prefix plugins/sdd-quality-loop/rules.', { cause });
    }
  }
  const lang = /\.tsx$/i.test(filename) ? parser.Lang.Tsx
    : /\.(?:ts|mts|cts)$/i.test(filename) ? parser.Lang.TypeScript : parser.Lang.JavaScript;
  return parser.parse(lang, source).root();
}
