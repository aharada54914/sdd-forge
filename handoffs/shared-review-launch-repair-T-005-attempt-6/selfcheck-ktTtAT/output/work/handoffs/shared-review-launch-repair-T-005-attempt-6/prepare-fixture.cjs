// Verify immutable inputs first; reconstruct executable copies and self-contained history in output.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const [manifestFile,snapshotArg,outputArg]=process.argv.slice(2);
const snapshot=fs.realpathSync(snapshotArg),output=fs.realpathSync(outputArg);
const handoff=fs.realpathSync(path.dirname(manifestFile));
if(snapshot!==path.join(handoff,'snapshot')||output!==path.join(handoff,'output'))throw Error('external fixture roots');
const manifest=JSON.parse(fs.readFileSync(manifestFile));
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const safe=p=>typeof p==='string'&&!path.isAbsolute(p)&&!p.includes('\\')&&p.split('/').every(x=>x&&x!=='.'&&x!=='..');
const prefix='handoffs/shared-review-launch-repair-T-005-attempt-6/';
const inventoryPath=prefix+'source-modes.json';
const allowed=new Map();
for(const row of manifest.allowed_inputs){if(!safe(row.path)||allowed.has(row.path))throw Error('duplicate/unsafe input');allowed.set(row.path,row.sha256);}
const inventoryFile=path.join(snapshot,inventoryPath);
if(!fs.lstatSync(inventoryFile).isFile()||fs.realpathSync(inventoryFile)!==inventoryFile)throw Error('unsafe inventory');
const inventoryBytes=fs.readFileSync(inventoryFile);
if(hash(inventoryBytes)!==allowed.get(inventoryPath))throw Error('inventory hash');
const inventory=JSON.parse(inventoryBytes),seen=new Set(),before=[];
if(inventory.schema!=='t005-fixture-modes/v1'||!Array.isArray(inventory.entries))throw Error('inventory schema');
for(const row of inventory.entries){
 if(!safe(row.path)||seen.has(row.path)||allowed.get(row.path)!==row.sha256||!Number.isInteger(row.mode)||row.mode<0||row.mode>511)throw Error('inventory entry');
 seen.add(row.path);const src=path.join(snapshot,row.path),st=fs.lstatSync(src);
 if(!st.isFile()||fs.realpathSync(src)!==src||hash(fs.readFileSync(src))!==row.sha256)throw Error('snapshot mismatch');
 before.push({src,mode:st.mode,sha256:row.sha256});
}
for(const required of ['git-history.cjs','git-history.pack','git-history.json'])if(!seen.has(prefix+required))throw Error('missing pinned history input');
const work=path.join(output,'work'),history=path.join(output,'git-history.git');
if(fs.existsSync(work)||fs.existsSync(history))throw Error('output fixture already exists');
fs.mkdirSync(work);
for(const row of inventory.entries){const dest=path.join(work,row.path);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(path.join(snapshot,row.path),dest,fs.constants.COPYFILE_EXCL);fs.chmodSync(dest,row.mode);if(hash(fs.readFileSync(dest))!==row.sha256||(fs.statSync(dest).mode&511)!==row.mode)throw Error('output mismatch');}
const historyResult=require(path.join(work,prefix,'git-history.cjs')).restore(path.join(work,prefix,'git-history.pack'),path.join(work,prefix,'git-history.json'),history);
for(const row of before){if(fs.lstatSync(row.src).mode!==row.mode||hash(fs.readFileSync(row.src))!==row.sha256)throw Error('snapshot changed');}
console.log(JSON.stringify({result:'FIXTURE_READY',files:seen.size,snapshot_unchanged:true,work,source_git_root:history,history:historyResult}));
