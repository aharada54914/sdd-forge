import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const root=path.dirname(fileURLToPath(import.meta.url));
const suites=['quality-nontty-transport','host-review-preflight','unified-task-launch','unified-launch-order'];
const names=['audit.md','verify.mjs','context.json','target-hashes.json','baseline-hashes.json','check-candidate.json','check-restored.json','restored-26-hashes.json','candidate-results.json','restored-results.json',
 ...[...suites,'review-conditional-inputs','shared-launch-build'].map(s=>'candidate-'+s+'.log'),
 ...suites.map(s=>'restored-'+s+'.log')];
const entries=names.map(name=>({source:path.join(root,name),canonical_relative_path:'verification/T-001/compact-runtime-rollback-'+name,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,name))).digest('hex')}));
fs.writeFileSync(path.join(root,'evidence-index.json'),JSON.stringify({schema:'diagnostic-evidence-copy-index/v1',note:'Proposed canonical copy destinations only; this index does not copy or authorize replacement of canonical evidence.',entries},null,2)+'\n',{flag:'wx'});
console.log(JSON.stringify({files:entries.length,index:path.join(root,'evidence-index.json')}));
