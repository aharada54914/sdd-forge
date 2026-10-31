// Exercise manifest/inventory disagreement without changing the pinned snapshot.
const fs=require('fs'),path=require('path'),{spawnSync}=require('child_process');
const root=fs.realpathSync(process.argv[2]);
if(path.dirname(root)!==__dirname||!path.basename(root).startsWith('selfcheck-'))throw Error('not a local selfcheck');
const manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json')));
const inventory='handoffs/shared-review-launch-repair-T-005-attempt-6/source-modes.json';
manifest.allowed_inputs.find(r=>r.path===inventory).sha256='0'.repeat(64);
const candidate=path.join(root,'mismatch-manifest.json');
fs.writeFileSync(candidate,JSON.stringify(manifest,null,2)+'\n',{flag:'wx'});
const result=spawnSync(process.execPath,[path.join(__dirname,'prepare-fixture.cjs'),candidate,path.join(root,'snapshot'),path.join(root,'output')],{encoding:'utf8'});
if(result.status===0||!result.stderr.includes('Error: inventory hash'))throw Error('mismatched inventory was not rejected at admission');
const record={inventory_hash_mismatch_rejected:true,status:result.status};
fs.writeFileSync(path.join(root,'admission-result.json'),JSON.stringify(record)+'\n',{flag:'wx'});
console.log(JSON.stringify(record));
