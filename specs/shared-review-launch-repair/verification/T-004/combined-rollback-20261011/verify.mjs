// Disposable T004 combined rollback, extending T001 compact-runtime verifier.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import cp from 'node:child_process';
import os from 'node:os';
import {fileURLToPath} from 'node:url';
const out=path.dirname(fileURLToPath(import.meta.url));
const owner=path.resolve(out,'../../../../..');
const baseline=path.join(owner,'reports/verification/shared-launch-handoff/T-001-git-rollback');
const prior=path.join(owner,'reports/verification/shared-launch-handoff/T-001-output/verification/T-001');
const roots=['plugins/sdd-review-loop','plugins/sdd-quality-loop','plugins/sdd-implementation','contracts','tests','.github'];
const digest=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const state=p=>fs.existsSync(p)?{sha256:digest(p),mode:fs.statSync(p).mode&511}:null;
const same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
const write=(n,v)=>fs.writeFileSync(path.join(out,`combined-${n}.json`),JSON.stringify(v,null,2)+'\n');
if(fs.existsSync(path.join(out,'combined-context.json')))throw Error('Existing run evidence; refusing overwrite');
function inventory(root,dir,result=new Set()) {
  const p=path.join(root,dir);if(!fs.existsSync(p))return result;
  for(const e of fs.readdirSync(p,{withFileTypes:true})){
    if(['node_modules','__pycache__'].includes(e.name))continue;
    const rel=path.join(dir,e.name);
    if(e.isSymbolicLink()){
      const other=path.join(root===owner?baseline:owner,rel);
      if(!fs.lstatSync(other).isSymbolicLink()||fs.readlinkSync(path.join(root,rel))!==fs.readlinkSync(other))throw Error(`changed symlink not admitted: ${rel}`);
      continue;
    }
    if(e.isDirectory())inventory(root,rel,result);else if(e.isFile())result.add(rel);
  }return result;
}
const names=new Set();for(const root of roots){for(const n of inventory(owner,root))names.add(n);for(const n of inventory(baseline,root))names.add(n);}
const targets=[...names].sort().map(p=>({path:p,before:state(path.join(baseline,p)),candidate:state(path.join(owner,p))})).filter(x=>!same(x.before,x.candidate));
const before=JSON.parse(fs.readFileSync(path.join(prior,'before-hashes.json')));
const oldRecords=fs.readFileSync(path.join(prior,'git-rollback-restored-hashes.txt'),'utf8').trim().split('\n').map(JSON.parse);
for(const r of oldRecords){const pin=before.inputs.find(x=>x.path===r.path);if(!pin||digest(path.join(baseline,r.path))!==pin.sha256)throw Error('historical baseline mismatch '+r.path);}
const coverage=targets.map(t=>({...t,historical_hash:before.inputs.find(x=>x.path===t.path)?.sha256??null}));
for(const t of coverage)if(t.historical_hash&&t.before?.sha256!==t.historical_hash)throw Error('historical input drift '+t.path);
const temp=fs.mkdtempSync(path.join(os.tmpdir(),'sdd-t004-combined-'));
const checkout=path.join(temp,'checkout');
const env=Object.fromEntries(Object.entries(process.env).filter(([k])=>!k.startsWith('GIT_')));
Object.assign(env,{GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:'/dev/null',GIT_NO_REPLACE_OBJECTS:'1',PYTHONDONTWRITEBYTECODE:'1',TMPDIR:temp});
const run=(args,cwd=checkout)=>cp.spawnSync('rtk',['proxy',...args],{cwd,env,encoding:'utf8',maxBuffer:32*1024*1024});
write('context',{owner,baseline,checkout,head:run(['git','rev-parse','HEAD'],owner).stdout.trim(),scope:'T004 disposable combined product/config/test rollback; excludes ledger, approvals, historical evidence and installed state',prior_helper_sha256:digest(path.join(owner,'specs/shared-review-launch-repair/verification/T-001/compact-runtime-rollback-verify.mjs')),historical_baseline_records:oldRecords.length,targets:coverage});
fs.cpSync(baseline,checkout,{recursive:true,errorOnExist:true,force:false});
if(fs.existsSync(path.join(checkout,'.git/objects/info/alternates'))||fs.existsSync(path.join(checkout,'.git/commondir')))throw Error('external git storage');
// Copying here assembles disposable test fixtures; owner inputs are never edited.
function install(which){for(const t of targets){const dest=path.join(checkout,t.path),src=path.join(which==='candidate'?owner:baseline,t.path),s=t[which==='candidate'?'candidate':'before'];if(s===null){if(fs.existsSync(dest))fs.unlinkSync(dest);}else{fs.mkdirSync(path.dirname(dest),{recursive:true});if(fs.existsSync(dest))fs.chmodSync(dest,0o600);fs.copyFileSync(src,dest);fs.chmodSync(dest,s.mode);}}}
function verify(which){const rows=targets.map(t=>({path:t.path,expected:t[which==='candidate'?'candidate':'before'],actual:state(path.join(checkout,t.path)),owner_preserved:same(state(path.join(owner,t.path)),t.candidate),baseline_preserved:same(state(path.join(baseline,t.path)),t.before)}));write(which+'-readback',rows);if(rows.some(r=>!same(r.expected,r.actual)||!r.owner_preserved||!r.baseline_preserved))throw Error('hash/mode/source preservation failed');}
const results=[];
function test(phase,args,name){const r=run(args);fs.writeFileSync(path.join(out,`combined-${phase}-${name}.log`),r.stdout+r.stderr);results.push({phase,name,argv:['rtk','proxy',...args],exit:r.status,signal:r.signal});write('results',results);console.log(`${phase} ${name}: ${r.status}`);}
install('candidate');verify('candidate');
for(const n of ['host-review-preflight','unified-task-launch','unified-launch-order','review-conditional-inputs','quality-nontty-transport','traceability-freeze-contract','spec-review-verify-inputs'])test('candidate',['python3','-B',`tests/${n}.tests.py`],n);
test('candidate',['pwsh','-NoProfile','-File','tests/review-hash-normalization.tests.ps1'],'hash-normalization');
install('before');verify('restored');
for(const n of ['host-review-preflight','unified-task-launch','unified-launch-order','quality-nontty-transport'])test('restored',['python3','-B',`tests/${n}.tests.py`],n);
verify('restored');
write('summary',{target_count:targets.length,hash_mode_restoration:true,owner_and_baseline_preserved:true,results,limitations:['Disposable rollback only; not installed/native activation or formal quality verdict','Historical 26 pins retained; additional baseline bytes inventoried, with available before-hashes checked','Full suites, CI and ledger/approval/history rollback intentionally excluded']});
if(results.some(r=>r.exit!==0))process.exitCode=1;

