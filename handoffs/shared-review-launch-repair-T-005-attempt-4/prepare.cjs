const fs=require('fs'),path=require('path'),crypto=require('crypto');
const base=__dirname,root=path.resolve(base,'../..'),rel=path.relative(root,base);
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const prior=JSON.parse(fs.readFileSync(path.join(root,'handoffs/shared-review-launch-repair-T-005-attempt-3/manifest.json')));
const session=JSON.parse(fs.readFileSync(path.join(base,'native-thread-start-result.json'))).result.thread.id;
const seen=new Set();
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
