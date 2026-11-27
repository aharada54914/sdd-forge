import { Lexer } from './vendor/marked/marked.mjs';

// Release entries use top-level ATX level-two headings, e.g. "## v2.1.5 (date)".
export function countReleaseHeadings(changelog, version) {
  return Lexer.lex(changelog).filter(token =>
    token.type === 'heading' && token.depth === 2 && token.raw.trimStart().startsWith('##') &&
    token.text.split(/[ \t]/, 1)[0] === `v${version}`
  ).length;
}
