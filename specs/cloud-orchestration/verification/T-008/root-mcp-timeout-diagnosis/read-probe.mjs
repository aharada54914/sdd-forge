import fs from 'node:fs';
import { syncBuiltinESMExports } from 'node:module';
import { createHash } from 'node:crypto';
const original = {};
const counts = {}; const reads = new Map(); let active = false; let bytes = 0;
for (const name of ['readFileSync','statSync','realpathSync','readdirSync']) {
  original[name] = fs[name]; counts[name] = 0;
  const native = fs[name].native;
  fs[name] = function(...args) {
    const result = original[name](...args);
    if (active) {
      counts[name]++;
      if (name === 'readFileSync') {
        const key = String(args[0]); reads.set(key,(reads.get(key) ?? 0)+1);
        bytes += typeof result === 'string' ? Buffer.byteLength(result) : result.length;
      }
    }
    return result;
  };
  if (native) fs[name].native = native;
}
syncBuiltinESMExports();
const { listActiveSpecs } = await import('/workspace/sdd-forge/mcp/sdd-forge-mcp/dist-test/src/tools/core.js');
const root = {path:'/workspace/sdd-forge',source:'cli'};
active = true; const start = performance.now(); const result=listActiveSpecs(root);const seconds=(performance.now()-start)/1000;active=false;
console.log(JSON.stringify({seconds,counts,bytes,distinct_read_files:reads.size,top_reads:[...reads].sort((a,b)=>b[1]-a[1]).slice(0,15).map(([p,n])=>({path:p.replace(root.path+'/',''),reads:n})),result_ok:result.ok,spec_count:result.data?.specs?.length,result_sha256:createHash('sha256').update(JSON.stringify(result)).digest('hex'),scope:'Read-only Linux diagnosis on current working tree; no Windows completion or release acceptance inferred.'},null,2));
