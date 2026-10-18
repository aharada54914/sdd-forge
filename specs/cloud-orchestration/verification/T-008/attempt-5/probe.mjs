// Local repository probe: only counts, envelopes and task parse results are saved.
import fs from 'node:fs';
import { syncBuiltinESMExports } from 'node:module';
import { pathToFileURL } from 'node:url';
import path from 'node:path';
const [repo, packageRoot, output] = process.argv.slice(2);
const { listActiveSpecs } = await import(pathToFileURL(path.join(packageRoot, 'dist-test/src/tools/core.js')));
const { parseTaskState } = await import(pathToFileURL(path.join(packageRoot, 'dist-test/src/parsers/tasks.js')));
const { resolveRoot } = await import(pathToFileURL(path.join(packageRoot, 'dist-test/src/root.js')));
const root = resolveRoot(['--root', repo]);
const originals = {};
const counts = {}; const files = new Map(); let bytes = 0;
for (const key of ['readFileSync', 'statSync', 'realpathSync']) {
  originals[key] = fs[key]; counts[key] = 0;
  fs[key] = (...args) => {
    counts[key]++;
    const result = originals[key](...args);
    if (key === 'readFileSync') {
      files.set(String(args[0]), (files.get(String(args[0])) ?? 0) + 1);
      bytes += Buffer.byteLength(result);
    }
    return result;
  };
}
syncBuiltinESMExports();
const start = performance.now();
const result = listActiveSpecs(root);
const elapsed_ms = performance.now() - start;
for (const key of Object.keys(originals)) fs[key] = originals[key];
syncBuiltinESMExports();
fs.mkdirSync(output, { recursive: true });
fs.writeFileSync(path.join(output, 'tool.json'), JSON.stringify(result));
fs.writeFileSync(path.join(output, 'counts.json'), JSON.stringify({ counts, bytes, distinctFiles: files.size, maximumReads: Math.max(...files.values()), elapsed_ms }, null, 2)+'\n');
if (!result.ok) throw new Error('listActiveSpecs failed');
const parses = result.data.specs.map(spec => parseTaskState(root, spec.feature, `specs/${spec.feature}/tasks.md`));
fs.writeFileSync(path.join(output, 'parses.json'), JSON.stringify(parses));
console.log(JSON.stringify({ counts, bytes, distinctFiles: files.size, elapsed_ms }));
