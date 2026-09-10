# PR #400: human collection of current guard-source evidence

The agent's previous source-hash/membership probe was rejected by the protection
hook. Do not execute this block through an agent tool or use another launcher to
evade that refusal. A human may run it directly in their own terminal.

This command only reads the repository and installed guard sources. It does not
import or execute them, change protection, edit files, reserve review identities,
or commit/push/merge. It prints SHA-256 and source excerpts around panelist entries.
These are source observations, NOT an end-to-end enforcement test or review PASS.
The initial command searched only the main Python file. Human execution at
2026-09-07T22:58:42Z returned no panelist literals in either copy (errors=2).
That result does not establish absence from the generated protection inventory.
Reported main-source SHA-256 values were
`0202c8f32f8810d77ba438a965f6b57213fb907f1a3c724f318cda9fd7b19d90`
(repository) and
`da37e08d7341f58ee61bbd0aa146486be21a069b4435ccd449114eaf72363889`
(installed cache). Both excerpt arrays were empty. These are human-reported
observations, not independently executed membership checks.
The corrected command below reads both the main source's inventory references
and the generated inventory; it does not import or execute either source.
Missing entries, files, or unexpected source structure remain unresolved findings.
Return the complete output so it can be bound into the review-authorized
investigation input before a new formal review. The existing failed round remains.

```bash
rtk proxy node <<'NODE'
const fs = require('node:fs');
const crypto = require('node:crypto');
const roots = [
  '/Users/jrmag/sdd-forge/plugins/sdd-quality-loop/scripts',
  '/Users/jrmag/.codex/plugins/cache/sdd-plugins/sdd-quality-loop/1.17.0/scripts'
];
const sources = roots.flatMap(root => [
  {path: root + '/sdd-hook-guard.py', pattern: /generated|guard_invariants|PROTECTED/i},
  {path: root + '/generated/guard_invariants.py', pattern: /run-panelist/}
]);
let errors = 0;
for (const {path, pattern} of sources) {
  try {
    const bytes = fs.readFileSync(path);
    const lines = bytes.toString('utf8').split('\n');
    const selected = new Set();
    lines.forEach((line, i) => {
      if (pattern.test(line)) {
        for (let j = Math.max(0, i - 12); j <= Math.min(lines.length - 1, i + 12); j++) selected.add(j);
      }
    });
    console.log(JSON.stringify({
      capturedAt: new Date().toISOString(), path,
      sha256: crypto.createHash('sha256').update(bytes).digest('hex'),
      observation: 'source excerpts only; not a computed protection verdict',
      excerpts: [...selected].sort((a,b) => a-b).map(i => ({line:i+1, text:lines[i]}))
    }, null, 2));
    if (!selected.size) { errors++; console.error('No matching inventory/reference excerpts: ' + path); }
  } catch (error) {
    errors++;
    console.error(JSON.stringify({path, error:String(error.message)}));
  }
}
console.log('Human evidence collection finished; errors=' + errors + '. Send complete output to Codex.');
process.exitCode = errors ? 1 : 0;
NODE
```

No execution or successful result is claimed for this human-only command.
