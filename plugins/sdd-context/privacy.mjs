import { performance } from 'node:perf_hooks';

const INPUT_BYTES = 1024 * 1024;
const VALUE_BYTES = 4096;
const MAX_SPANS = 512;
const sensitiveKey = /^(password|passwd|secret|api_key|apikey|access_token|refresh_token|client_secret|authorization)$/i;

function reject() {
  const error = new Error('privacy-rejected');
  delete error.stack;
  error.code = 'privacy-rejected';
  throw error;
}

/** In-memory rule-v1 only. Caller must independently validate owner/schema/path.
 * deadline is trusted core monotonic time, never taken from a host payload.
 * Default includes process startup time; callers propagate the original deadline.
 */
export function redact(text, deadline = 1000) {
  try {
    return scan(text, deadline);
  } catch {
    // Do not retain scanner exceptions, input, stack, cause or partial output.
    reject();
  }
}

function scan(text, deadline) {
  const check = () => {
    if (!Number.isFinite(deadline) || performance.now() >= deadline) reject();
  };
  check();
  if (typeof text !== 'string' || text.length > INPUT_BYTES || !text.isWellFormed() || Buffer.byteLength(text) > INPUT_BYTES) reject();
  const spans = [];
  const headers = [];
  const add = (start, end, family) => {
    check();
    if (end === start) return;
    if (Buffer.byteLength(text.slice(start, end)) > VALUE_BYTES || spans.length >= MAX_SPANS) reject();
    spans.push({ start, end, family });
  };

  const openings = /-----BEGIN (PRIVATE KEY|RSA PRIVATE KEY|EC PRIVATE KEY|OPENSSH PRIVATE KEY)-----/g;
  for (const match of text.matchAll(openings)) {
    check();
    const closing = `-----END ${match[1]}-----`;
    const end = text.indexOf(closing, match.index + match[0].length);
    if (end < 0) reject();
    add(match.index, end + closing.length, 'pem');
  }

  // Header precedence prevents a second assignment span for the same value.
  const headerPattern = /(^|[\r\n])([ \t]*authorization[ \t]*:[ \t]*)([^\r\n]*)/gi;
  for (const match of text.matchAll(headerPattern)) {
    check();
    const start = match.index + match[1].length + match[2].length;
    const end = match.index + match[0].length;
    headers.push([match.index, end]);
    add(start, end, 'header');
  }

  // Consume whole identifiers once, avoiding retrying a greedy key pattern
  // at every character of a long nonmatching identifier.
  let headerIndex = 0;
  for (const match of text.matchAll(/[A-Za-z_][A-Za-z0-9_]*/g)) {
    check();
    if (!sensitiveKey.test(match[0])) continue;
    let start = match.index;
    let next = start + match[0].length;
    while (headerIndex < headers.length && headers[headerIndex][1] <= start) headerIndex++;
    if (headerIndex < headers.length && headers[headerIndex][0] <= start) continue;
    const before = text[start - 1];
    if (before === '"' || before === "'") {
      if (text[next] !== before) continue;
      start--;
      next++;
    }
    if (/[A-Za-z0-9_]/.test(text[start - 1] ?? '')) continue;
    while (text[next] === ' ' || text[next] === '\t') next++;
    if (text[next] !== ':' && text[next] !== '=') continue;
    next++;
    while (text[next] === ' ' || text[next] === '\t') next++;
    const valueStart = next;
    let family = 'assignment';
    const quote = text[next];
    if (quote === '|' || quote === '>') reject();
    if (quote === '"' || quote === "'") {
      next++;
      while (next < text.length && text[next] !== quote) {
        check();
        if (next - valueStart > VALUE_BYTES) reject();
        if (text[next] === '\\') {
          if (quote === "'" && text[next + 1] !== "'" && text[next + 1] !== '\\') reject();
          next++;
        }
        next++;
      }
      if (text[next] !== quote) reject();
      next++;
      const literal = text.slice(valueStart, next);
      if (Buffer.byteLength(literal) > VALUE_BYTES) reject();
      if (quote === '"' && !JSON.parse(literal).isWellFormed()) reject();
      if (next - valueStart === 2) continue;
    } else {
      for (const candidate of ['pem', 'assignment', 'header', 'url', 'token', 'jwt']) {
        const marker = `[REDACTED:${candidate}]`;
        if (!text.startsWith(marker, next)) continue;
        next += marker.length;
        family = candidate;
        break;
      }
      while (next < text.length && !/[\s,;}\]]/.test(text[next])) {
        if (next - valueStart > VALUE_BYTES) reject();
        next++;
      }
    }
    add(valueStart, next, family);
  }

  for (const match of text.matchAll(/https?:\/\/[^\s"'<>]*/gi)) {
    check();
    const raw = match[0];
    if (Buffer.byteLength(raw) > VALUE_BYTES) reject();
    const question = raw.indexOf('?');
    const query = question < 0 ? '' : raw.slice(question + 1).split('#', 1)[0];
    const sensitiveQuery = [...new URLSearchParams(query).keys()].some(key => sensitiveKey.test(key));
    const candidate = raw.includes('@') || sensitiveQuery;
    let url;
    try { url = new URL(raw); } catch {
      if (candidate) reject();
      continue;
    }
    if (candidate && /%(?![0-9a-f]{2})/i.test(raw)) reject();
    if (url.username || url.password || sensitiveQuery) add(match.index, match.index + raw.length, 'url');
  }

  for (const match of text.matchAll(/[A-Za-z0-9_-]+/g)) {
    check();
    const token = match[0];
    const prefix = ['sk-', 'ghp_', 'github_pat_'].find(item => token.startsWith(item));
    if (!prefix) continue;
    const size = token.length - prefix.length;
    if (size > 256) reject();
    if (size >= 20) add(match.index, match.index + token.length, 'token');
  }
  for (const match of text.matchAll(/[A-Za-z0-9]+/g)) {
    check();
    const token = match[0];
    if (!token.startsWith('AKIA') && !token.startsWith('ASIA')) continue;
    if (/^[A-Z0-9]+$/.test(token) && token.length > 20) reject();
    if (/^(AKIA|ASIA)[A-Z0-9]{16}$/.test(token)) add(match.index, match.index + token.length, 'token');
  }

  // Maximal runs and a single linear split avoid JWT regex backtracking.
  for (const match of text.matchAll(/[A-Za-z0-9_.-]+/g)) {
    check();
    const parts = match[0].split('.');
    if (parts.length !== 3 || parts.some(part => part.length < 8)) continue;
    if (parts.some(part => part.length > 2048)) reject();
    add(match.index, match.index + match[0].length, 'jwt');
  }

  spans.sort((a, b) => a.start - b.start || b.end - a.end);
  const merged = [];
  for (const span of spans) {
    check();
    const previous = merged.at(-1);
    if (!previous || span.start >= previous.end) {
      merged.push({ ...span, longest: span.end - span.start });
    } else {
      if (span.end - span.start > previous.longest) {
        previous.family = span.family;
        previous.longest = span.end - span.start;
      }
      previous.end = Math.max(previous.end, span.end);
    }
  }
  const chunks = [];
  let end = text.length;
  for (let index = merged.length - 1; index >= 0; index--) {
    check();
    const span = merged[index];
    chunks.push(text.slice(span.end, end), `[REDACTED:${span.family}]`);
    end = span.start;
  }
  chunks.push(text.slice(0, end));
  const result = chunks.reverse().join('');
  check();
  if (Buffer.byteLength(result) > INPUT_BYTES || !result.isWellFormed()) reject();
  return { text: result, omission: spans.length > 0, ruleVersion: 1 };
}
