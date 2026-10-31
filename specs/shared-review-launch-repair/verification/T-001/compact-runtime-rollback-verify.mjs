// Isolated current-candidate rollback; derived from T-001-current-rollback/verify.mjs.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import cp from 'node:child_process';
import {fileURLToPath} from 'node:url';
const out=path.dirname(fileURLToPath(import.meta.url));
const owner=path.resolve(out,'../../../..');
const baseline=path.join(owner,'reports/verification/shared-launch-handoff/T-001-git-rollback');
const checkout=path.join(out,'checkout');
const evidence=path.join(owner,'reports/verification/shared-launch-handoff/T-001-output/verification/T-001');
const hash=p=>fs.existsSync(p)?crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex'):null;
const json=(name,data)=>fs.writeFileSync(path.join(out,name),JSON.stringify(data,null,2)+'\n');
const records=fs.readFileSync(path.join(evidence,'git-rollback-restored-hashes.txt'),'utf8').trim().split('\n').map(JSON.parse);
const expected=JSON.parse(fs.readFileSync(path.join(evidence,'before-hashes.json'))).inputs;
const targets=records.slice(0,18).map(x=>x.path).filter(x=>!x.endsWith('task-review-contract.template.json'));
targets.push('tests/review-conditional-inputs.tests.py','tests/shared-launch-build.tests.py','tests/shared-launch-python-requirements.txt','tests/shared-launch-python/pyproject.toml');
// Delivered alongside the caller because the current validator's optional
// supplemental-declaration branch invokes it. Never omit a shipped call target.
targets.push('plugins/sdd-quality-loop/scripts/supplemental-delivery-inputs.py');
targets.push('plugins/sdd-quality-loop/scripts/validate-review-context-set.sh','plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1');
const env=Object.fromEntries(Object.entries(process.env).filter(([k])=>!k.startsWith('GIT_')));
Object.assign(env,{GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:'/dev/null',GIT_NO_REPLACE_OBJECTS:'1',PYTHONDONTWRITEBYTECODE:'1',TMPDIR:path.join(out,'tmp')});
function command(args,cwd=checkout){return cp.spawnSync('rtk',['proxy',...args],{cwd,env,encoding:'utf8',maxBuffer:32*1024*1024});}
function verify26(root=checkout){return records.map(x=>({path:x.path,expected:expected.find(y=>y.path===x.path).sha256,actual:hash(path.join(root,x.path))}));}
function assert26(rows){if(rows.length!==26||rows.some(x=>x.expected!==x.actual))throw Error('26 pretask hashes mismatch');}
function makePatch(reverse){
 let patch='*** Begin Patch\n';
 for(const name of targets){
  const a=path.join(reverse?owner:baseline,name),b=path.join(reverse?baseline:owner,name);
  const old=fs.existsSync(a)?fs.readFileSync(a,'utf8'):null,next=fs.existsSync(b)?fs.readFileSync(b,'utf8'):null;
  if(old===next)continue;
  const dest=path.join(checkout,name);
  if(next===null)patch+=`*** Delete File: ${dest}\n`;
  else if(old===null)patch+=`*** Add File: ${dest}\n`+next.replace(/\n$/,'').split('\n').map(x=>'+'+x).join('\n')+'\n';
  else{const r=command(['diff','-U3',a,b],owner);if(r.status!==1)throw Error('diff failed');patch+=`*** Update File: ${dest}\n`+r.stdout.split('\n').slice(2).join('\n').replace(/^@@.*@@.*$/gm,'@@');}
 }
 return patch+'*** End Patch\n';
}
const mode=process.argv[2];
if(mode==='prepare'){
 if(fs.existsSync(checkout))throw Error('checkout already exists');
 assert26(verify26(baseline));
 fs.mkdirSync(path.join(out,'tmp'));
 const ctx={owner,baseline,checkout,head:command(['git','rev-parse','HEAD'],owner).stdout.trim(),dirty:command(['git','status','--short'],owner).stdout,scope:'Approved T-001 current compact caller rollback; high risk; disposable only; no formal gate',evidenceHashes:{before:hash(path.join(evidence,'before-hashes.json')),previousRestored:hash(path.join(evidence,'git-rollback-restored-hashes.txt')),previousVerifier:hash(path.join(owner,'reports/verification/shared-launch-handoff/T-001-current-rollback/verify.mjs'))}};
 json('context.json',ctx);
 json('target-hashes.json',targets.map(name=>({path:name,baseline:hash(path.join(baseline,name)),candidate:hash(path.join(owner,name))})));
 fs.cpSync(baseline,checkout,{recursive:true,errorOnExist:true,force:false});
 if(fs.existsSync(path.join(checkout,'.git/objects/info/alternates'))||fs.existsSync(path.join(checkout,'.git/commondir')))throw Error('external Git store');
 const rows=verify26();assert26(rows);json('baseline-hashes.json',rows);
 fs.writeFileSync(path.join(out,'apply.patch'),makePatch(false));fs.writeFileSync(path.join(out,'restore.patch'),makePatch(true));
 console.log(`Baseline verified: ${rows.length}; candidate targets: ${targets.length}`);
}else if(mode==='refresh-candidate'){
 assert26(verify26());
 const rows=targets.map(name=>({path:name,baseline:hash(path.join(baseline,name)),candidate:hash(path.join(owner,name)),baseline_mode:fs.existsSync(path.join(baseline,name))?fs.statSync(path.join(baseline,name)).mode&511:null}));
 json('target-hashes.json',rows);
 fs.writeFileSync(path.join(out,'apply.patch'),makePatch(false));fs.writeFileSync(path.join(out,'restore.patch'),makePatch(true));
 for(const row of rows){const p=path.join(checkout,row.path);if(fs.existsSync(p))fs.chmodSync(p,fs.statSync(p).mode|0o200);}
 console.log('Final candidate pinned; only disposable target files made owner-writable');
}else if(mode==='check-candidate'||mode==='check-restored'){
 const saved=JSON.parse(fs.readFileSync(path.join(out,'target-hashes.json')));
 if(mode==='check-restored')for(const row of saved){if(row.baseline_mode!==null&&row.baseline_mode!==undefined)fs.chmodSync(path.join(checkout,row.path),row.baseline_mode);}
 const rows=saved.map(x=>({...x,actual:hash(path.join(checkout,x.path)),owner_now:hash(path.join(owner,x.path)),old_disposable_now:hash(path.join(baseline,x.path))}));
 json(mode+'.json',rows);
 if(rows.some(x=>x.actual!==x[mode==='check-candidate'?'candidate':'baseline']||x.owner_now!==x.candidate||x.old_disposable_now!==x.baseline))throw Error('target or source drift');
 assert26(verify26(baseline));
 if(mode==='check-restored'){const rows=verify26();json('restored-26-hashes.json',rows);assert26(rows);}
 console.log(mode+': all hashes match; owner and old disposable preserved');
}else if(mode==='tests'){
 const phase=process.argv[3];if(!['candidate','restored'].includes(phase))throw Error('invalid phase');
 const suites=['quality-nontty-transport','host-review-preflight','unified-task-launch','unified-launch-order'];
 if(phase==='candidate')suites.push('review-conditional-inputs','shared-launch-build');
 const results=[];
 for(const suite of suites){const args=['python3','-B',`tests/${suite}.tests.py`],r=command(args);fs.writeFileSync(path.join(out,`${phase}-${suite}.log`),r.stdout+r.stderr);results.push({command:['rtk','proxy',...args],exit:r.status,signal:r.signal});console.log(`${phase} ${suite}: ${r.status}`);}
 json(`${phase}-results.json`,results);if(results.some(x=>x.exit!==0))process.exitCode=1;
}else throw Error('invalid mode');
