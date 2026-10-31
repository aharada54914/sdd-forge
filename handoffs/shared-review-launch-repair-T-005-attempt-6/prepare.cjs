const fs=require('fs'),path=require('path'),crypto=require('crypto');
const base=__dirname,root=path.resolve(base,'../..'),rel=path.relative(root,base);
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const prior=JSON.parse(fs.readFileSync(path.join(base,'../shared-review-launch-repair-T-005-attempt-5/manifest.json')));
const session=JSON.parse(fs.readFileSync(path.join(base,'native-thread-start-result.json'))).result.thread.id;
prior.allowed_inputs=prior.allowed_inputs.filter(x=>!x.path.startsWith('handoffs/shared-review-launch-repair-T-005-attempt-5/'));
const repins=[
 ['plugins/sdd-review-loop/references/review-context-boundary.md','d627ed207f1bc8e89a5f0f9bd32b637259205bf695966ab052d92a0ecbf39477','95f994a868ed6a64299fdbca4eb5c5953e3a42fae303649fb66683d4ccb62fe1'],
 ['tests/review-context-boundary.tests.sh','653df82aaef2d5b70d1052a959c4994904a7741320eb49eccd1a9d12bf169b1b','f8d6a0835d28285e74543f587798e9e4bba73bf15ff1c97ee19ea41cca1a8cff']
];
for(const [p,before,after] of repins){
 const entry=prior.allowed_inputs.find(x=>x.path===p);
 if(!entry||entry.sha256!==before)throw Error('unexpected previous input '+p);
 entry.sha256=after;
}
for(const p of [
 'plugins/sdd-review-loop/agents/spec-reviewer-a.md',
 'plugins/sdd-review-loop/agents/spec-reviewer-b.md',
 'plugins/sdd-review-loop/agents/impl-reviewer-b.md',
 'plugins/sdd-review-loop/agents/task-reviewer-a.md',
 'plugins/sdd-review-loop/agents/task-reviewer-b.md',
 'plugins/sdd-implementation/scripts/validate-implementation-report.sh',
 rel+'/git-history.pack',rel+'/git-history.json',rel+'/git-history.cjs'
]){
 if(prior.allowed_inputs.some(x=>x.path===p))throw Error('duplicate addition '+p);
 prior.allowed_inputs.push({path:p,sha256:hash(fs.readFileSync(path.join(root,p)))});
}
const seen=new Set();
const entries=prior.allowed_inputs.map(({path:p,sha256})=>{
 if(path.isAbsolute(p)||p.split('/').some(x=>!x||x==='..'||x==='.')||seen.has(p))throw Error('unsafe or duplicate path');
 seen.add(p);const full=path.join(root,p),st=fs.lstatSync(full);
 if(!st.isFile()||fs.realpathSync(full)!==full||hash(fs.readFileSync(full))!==sha256)throw Error('source mismatch '+p);
 return {path:p,sha256,mode:st.mode&0o777};
});
fs.writeFileSync(path.join(base,'source-modes.json'),JSON.stringify({schema:'t005-fixture-modes/v1',entries},null,2)+'\n',{flag:'wx'});
prior.run_id='T-005-'+session;prior.session_id=session;prior.agent_instance_id=session;
prior.allowed_outputs=[rel+'/output/'];
for(const p of [rel+'/source-modes.json',rel+'/prepare-fixture.cjs'])prior.allowed_inputs.push({path:p,sha256:hash(fs.readFileSync(path.join(root,p)))});
fs.writeFileSync(path.join(base,'manifest.json'),JSON.stringify(prior,null,2)+'\n',{flag:'wx'});
console.log(session,entries.length,hash(fs.readFileSync(path.join(base,'manifest.json'))));
