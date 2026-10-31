const fs=require('fs'),path=require('path'),crypto=require('crypto');
const base=__dirname,root=path.resolve(base,'../..'),rel=path.relative(root,base);
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const prior=JSON.parse(fs.readFileSync(path.join(root,'handoffs/shared-review-launch-repair-T-005-attempt-4/manifest.json')));
const session=JSON.parse(fs.readFileSync(path.join(base,'native-thread-start-result.json'))).result.thread.id;
const seen=new Set();
prior.allowed_inputs=prior.allowed_inputs.filter(x=>!x.path.startsWith('handoffs/shared-review-launch-repair-T-005-attempt-4/'));
const declaration=fs.readFileSync(path.join(root,'specs/shared-review-launch-repair/verification/T-005/supplemental-delivery-closure.json'));
if(hash(declaration)!=='0ad60a6ea4c4aeff5aaa55aebc5c7acfaf32f18ad86e29f6f05cfed6d7d2f7e8')throw Error('declaration changed');
const admitted=JSON.parse(declaration).artifacts;
for(const entry of admitted){
 const index=prior.allowed_inputs.findIndex(x=>x.path===entry.path);
 if(index<0)prior.allowed_inputs.push(entry);else prior.allowed_inputs[index]=entry;
}
const task=prior.allowed_inputs.find(x=>x.path==='specs/shared-review-launch-repair/tasks.md');
if(!task||task.sha256!=='1a6b36bdc946724ee24bd6e77b7af98f9f6c167d8d736397f41b9f5d6dbfb898')throw Error('unexpected prior task');
task.sha256='0e87f48308c92d4c1736cdc1744be697f5e1b37adde87f35b9a2cb8136c047c2';
const entries=prior.allowed_inputs.map(({path:p,sha256})=>{
 if(path.isAbsolute(p)||p.split('/').some(x=>x==='..'||x==='.')||seen.has(p))throw Error('unsafe or duplicate path');
 seen.add(p);const full=path.join(root,p),st=fs.lstatSync(full);
 if(!st.isFile()||fs.realpathSync(full)!==full||hash(fs.readFileSync(full))!==sha256)throw Error('source mismatch '+p);
 return {path:p,sha256,mode:st.mode&0o777};
});
fs.writeFileSync(path.join(base,'source-modes.json'),JSON.stringify({schema:'t005-fixture-modes/v1',entries},null,2)+'\n',{flag:'wx'});
prior.run_id='T-005-'+session;prior.session_id=session;prior.agent_instance_id=session;
prior.allowed_outputs=[rel+'/output/'];
for(const p of [rel+'/source-modes.json',rel+'/prepare-fixture.cjs'])prior.allowed_inputs.push({path:p,sha256:hash(fs.readFileSync(path.join(root,p)))});
fs.writeFileSync(path.join(base,'manifest.json'),JSON.stringify(prior,null,2)+'\n',{flag:'wx'});
console.log(session,hash(fs.readFileSync(path.join(base,'manifest.json'))));
