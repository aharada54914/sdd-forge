#!/usr/bin/env node
// Thin Node.js dispatcher for canonicalize-sdd-yaml (REQ-003). Locates
// python3, else python, on PATH and spawns canonicalize-sdd-yaml.py
// unchanged, with stdio inherited (passed through as-is). Exactly ONE
// behavioral implementation exists (the Python script beside this file);
// this wrapper never reimplements canonicalization natively. If neither
// python3 nor python is found, denies fail-closed with the SAME documented
// exit code every .sh/.ps1/.js wrapper uses: CANONICALIZER_RUNTIME_UNAVAILABLE
// (exit 3). No output is produced on that path; the diagnostic goes to
// stderr only.
'use strict';

const path = require('path');
const { spawnSync } = require('child_process');

const dir = __dirname;
const scriptPath = path.join(dir, 'canonicalize-sdd-yaml.py');
const forwardArgs = process.argv.slice(2);

function invoke(cmd) {
  return spawnSync(cmd, [scriptPath, ...forwardArgs], { stdio: 'inherit' });
}

let result = invoke('python3');
if (result.error && result.error.code === 'ENOENT') {
  result = invoke('python');
  if (result.error && result.error.code === 'ENOENT') {
    process.stderr.write(
      'canonicalize-sdd-yaml: CANONICALIZER_RUNTIME_UNAVAILABLE: no python3 or python interpreter found on PATH\n'
    );
    process.exit(3);
  }
}

if (result.error) {
  process.stderr.write(
    `canonicalize-sdd-yaml: CANONICALIZER_RUNTIME_UNAVAILABLE: failed to invoke a python interpreter: ${result.error.message}\n`
  );
  process.exit(3);
}

process.exit(result.status === null ? 1 : result.status);
