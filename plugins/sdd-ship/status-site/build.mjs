// Build from the existing bundled MCP distribution; no credentials or source data are embedded.
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
const here = dirname(fileURLToPath(import.meta.url));
const output = resolve(process.argv[2] || '.');
const project = resolve(process.argv[3] || '.');
const html = execFileSync(process.execPath, [resolve(here, '../../../mcp/sdd-forge-mcp/dist/index.js'), '--root', project, '--dashboard-html', '--parent-service', 'chatgpt'], { encoding: 'utf8', maxBuffer: 4 * 1024 * 1024, stdio: ['ignore','pipe','ignore'] });
const worker = readFileSync(resolve(here, 'worker.mjs'), 'utf8').replace('__DASHBOARD_PAGE__', JSON.stringify(html)).replace('__OBSERVATION_CODE__', readFileSync(resolve(here, 'observations.js'), 'utf8'));
mkdirSync(resolve(output, 'worker'), { recursive: true });
writeFileSync(resolve(output, 'worker/index.js'), worker);
writeFileSync(resolve(output, 'package.json'), JSON.stringify({ name: 'sdd-forge-dashboard', private: true, type: 'module' }, null, 2) + '\n');
console.log('Built self-contained worker: ' + resolve(output, 'worker/index.js'));
