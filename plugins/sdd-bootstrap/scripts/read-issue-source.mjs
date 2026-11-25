#!/usr/bin/env node
// Convert gh issue view --json title,body output to the bootstrap source contract.
import fs from 'node:fs';

try {
  const issue = JSON.parse(fs.readFileSync(0, 'utf8'));
  if (typeof issue?.title !== 'string' || typeof issue.body !== 'string') throw new Error();
  const source = { kind: 'untrusted-issue', title: issue.title, body: issue.body };
  process.stdout.write(JSON.stringify(source) + '\n');
} catch {
  process.stderr.write('Expected GitHub issue JSON containing title and body strings.\n');
  process.exitCode = 2;
}
