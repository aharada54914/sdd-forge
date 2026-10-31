// Diagnostic fixture test only; all generated files stay within this handoff.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {spawnSync}=require('child_process');
const base=__dirname,owner=path.resolve(base,'../..');
const prefix='handoffs/shared-review-launch-repair-T-005-attempt-6/';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const files=[
 'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh',
 'plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1',
 'plugins/sdd-quality-loop/skills/quality-gate/SKILL.md',
 'plugins/sdd-quality-loop/agents/evaluator.md',
 ...['spec','impl','task'].map(s=>`plugins/sdd-review-loop/skills/${s}-review-loop/SKILL.md`),
 ...['spec','impl','task'].flatMap(s=>['a','b'].map(r=>`plugins/sdd-review-loop/agents/${s}-reviewer-${r}.md`)),
 'tests/review-agent-isolation.tests.sh','tests/review-scratch-history.tests.py',
 'plugins/sdd-implementation/scripts/validate-implementation-report.sh',
 'plugins/sdd-quality-loop/scripts/review-conditional-inputs.py',
 ...['git-history.cjs','git-history.pack','git-history.json','prepare-fixture.cjs'].map(p=>prefix+p),
];
const run=fs.mkdtempSync(path.join(base,'selfcheck-'));
const snapshot=path.join(run,'snapshot'),output=path.join(run,'output');
fs.mkdirSync(snapshot);fs.mkdirSync(output);
const entries=files.map(p=>{
 const src=path.join(owner,p),bytes=fs.readFileSync(src),dest=path.join(snapshot,p);
 fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,bytes,{flag:'wx',mode:0o444});
 return {path:p,sha256:hash(bytes),mode:fs.statSync(src).mode&511};
});
const inventoryPath=prefix+'source-modes.json';
const inventory=Buffer.from(JSON.stringify({schema:'t005-fixture-modes/v1',entries},null,2)+'\n');
fs.writeFileSync(path.join(snapshot,inventoryPath),inventory,{flag:'wx',mode:0o444});
const manifest=path.join(run,'manifest.json');
fs.writeFileSync(manifest,JSON.stringify({allowed_inputs:[...entries.map(({path,sha256})=>({path,sha256})),{path:inventoryPath,sha256:hash(inventory)}]},null,2)+'\n',{flag:'wx'});
const env=Object.fromEntries(Object.entries(process.env).filter(([k])=>!k.startsWith('GIT_')));
Object.assign(env,{GIT_CONFIG_NOSYSTEM:'1',GIT_CONFIG_GLOBAL:'/dev/null',GIT_NO_REPLACE_OBJECTS:'1',GIT_TERMINAL_PROMPT:'0',GIT_CEILING_DIRECTORIES:output});
const prep=spawnSync(process.execPath,[path.join(snapshot,prefix,'prepare-fixture.cjs'),manifest,snapshot,output],{env,encoding:'utf8'});
fs.writeFileSync(path.join(run,'prepare.stdout'),prep.stdout);fs.writeFileSync(path.join(run,'prepare.stderr'),prep.stderr);
if(prep.status!==0)throw Error(`prepare failed: ${prep.stderr}`);
const result=JSON.parse(prep.stdout);
if(result.history.baseline_present.length!==11||result.history.baseline_absent.length!==2)throw Error('baseline inventory');
const helper=require(path.join(base,'git-history.cjs'));
const corrupt=Buffer.from(fs.readFileSync(path.join(base,'git-history.pack')));corrupt[corrupt.length-1]^=1;
const corruptFile=path.join(run,'corrupt.pack');fs.writeFileSync(corruptFile,corrupt);
let rejected=false;
try{helper.restore(corruptFile,path.join(base,'git-history.json'),path.join(output,'corrupt-history.git'));}catch(e){if(e.message==='history package mismatch')rejected=true;else throw e;}
if(!rejected||fs.existsSync(path.join(output,'corrupt-history.git')))throw Error('corruption accepted or output created');
// Pin mismatch must be rejected before an output/work directory is created.
const negative=path.join(base,path.basename(run)+'-negative');fs.mkdirSync(negative);
fs.symlinkSync(snapshot,path.join(negative,'snapshot'));fs.mkdirSync(path.join(negative,'output'));
fs.copyFileSync(manifest,path.join(negative,'manifest.json'));
const outside=spawnSync(process.execPath,[path.join(snapshot,prefix,'prepare-fixture.cjs'),path.join(negative,'manifest.json'),path.join(negative,'snapshot'),path.join(negative,'output')],{env,encoding:'utf8'});
if(outside.status===0||!outside.stderr.includes('external fixture roots'))throw Error('external roots accepted');
const temp=path.join(output,'tmp');fs.mkdirSync(temp);
Object.assign(env,{TMPDIR:temp,T005_SOURCE_GIT_ROOT:result.source_git_root});
const suite=spawnSync('bash',['tests/review-agent-isolation.tests.sh'],{cwd:result.work,env,encoding:'utf8',maxBuffer:16*1024*1024});
fs.writeFileSync(path.join(run,'suite.stdout'),suite.stdout||'');fs.writeFileSync(path.join(run,'suite.stderr'),suite.stderr||'');
for(const e of entries){const p=path.join(snapshot,e.path);if(hash(fs.readFileSync(p))!==e.sha256||(fs.statSync(p).mode&511)!==0o444)throw Error('snapshot changed');}
const summary={run,files:entries.length,source_files:17,history:result.history,corrupt_pack_rejected:rejected,external_snapshot_rejected:true,snapshot_unchanged:true,suite_status:suite.status,suite_signal:suite.signal};
fs.writeFileSync(path.join(run,'result.json'),JSON.stringify(summary,null,2)+'\n');
console.log(JSON.stringify(summary));process.stdout.write(suite.stdout||'');process.stderr.write(suite.stderr||'');
if(suite.status!==0)process.exit(suite.status||1);
