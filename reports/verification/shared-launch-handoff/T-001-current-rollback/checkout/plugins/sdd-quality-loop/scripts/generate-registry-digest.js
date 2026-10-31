#!/usr/bin/env node
// Thin argument-forwarding wrapper for generate-registry-digest.py.
'use strict';

const path = require('path');
const { spawnSync } = require('child_process');
const script = path.join(__dirname, 'generate-registry-digest.py');
const args = process.argv.slice(2);

for (const python of ['python3', 'python']) {
  const result = spawnSync(python, [script, ...args], { stdio: 'inherit' });
  if (!result.error || result.error.code !== 'ENOENT') {
    if (result.error) {
      process.stderr.write(`generate-registry-digest: ${result.error.message}\n`);
      process.exit(1);
    }
    process.exit(result.status === null ? 1 : result.status);
  }
}

process.stderr.write('generate-registry-digest: python3 (or python) is required\n');
process.exit(3);
