import { performance } from 'node:perf_hooks';

const INPUT_BYTES = 1024 * 1024;

/** Shared JSON syntax/member/Unicode checks only; callers still validate schemas.
 * deadline is the trusted core absolute monotonic deadline, including startup.
 */
export function parseJson(source, deadline = 1000) {
  try {
    const check = () => {
      if (!Number.isFinite(deadline) || performance.now() >= deadline) throw new Error();
    };
    check();
    if (typeof source !== 'string' || source.length > INPUT_BYTES ||
        !source.isWellFormed() || Buffer.byteLength(source) > INPUT_BYTES) throw new Error();
    check();
    const value = JSON.parse(source);
    check();

    // Syntax is already validated. Scan strings/containers, not another JSON grammar.
    const scopes = [];
    for (let index = 0; index < source.length; index++) {
      if ((index & 4095) === 0) check();
      const character = source[index];
      if (character === '"') {
        const start = index;
        while (++index < source.length) {
          if ((index & 4095) === 0) check();
          if (source[index] === '\\') index++;
          else if (source[index] === '"') break;
        }
        check();
        const decoded = JSON.parse(source.slice(start, index + 1));
        if (!decoded.isWellFormed()) throw new Error();
        const scope = scopes.at(-1);
        if (scope?.expectKey) {
          if (scope.keys.has(decoded)) throw new Error();
          scope.keys.add(decoded);
        }
      } else if (character === '{') {
        scopes.push({ keys: new Set(), expectKey: true });
      } else if (character === '[') {
        scopes.push(null);
      } else if (character === '}' || character === ']') {
        scopes.pop();
      } else if (character === ':') {
        scopes.at(-1).expectKey = false;
      } else if (character === ',' && scopes.at(-1)) {
        scopes.at(-1).expectKey = true;
      }
    }
    check();
    return value;
  } catch {
    // Discard decoder/scanner input, stack, cause and partial values.
    const error = new Error('json-rejected');
    delete error.stack;
    error.code = 'json-rejected';
    throw error;
  }
}
