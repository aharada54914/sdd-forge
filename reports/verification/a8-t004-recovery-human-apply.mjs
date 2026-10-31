// Human-only application helper. Agents must not execute --apply after hook refusal.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';
const config=JSON.parse(fs.readFileSync(new URL('./a8-t004-recovery-v2-pins.json',import.meta.url),'utf8'));
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
const run=args=>execFileSync('rtk',['proxy',...args],{cwd:config.root,stdio:'inherit'});
if(fs.realpathSync(config.root)!==config.root)throw Error('Owner path mismatch');
if(hash(path.join(config.root,config.patch))!==config.patch_sha256)throw Error('Patch digest mismatch');
const patchText=fs.readFileSync(path.join(config.root,config.patch),'utf8');
const sections=patchText.trimEnd().split(/(?=^diff --git )/m);
const admitted=[];
for(const section of sections){
 const lines=section.replace(/\n$/, '').split('\n');
 const match=lines.shift().match(/^diff --git a\/(.+) b\/(.+)$/);
 if(!match||match[1]!==match[2])throw Error('Invalid diff header');
 const name=match[1];admitted.push(name);
 if(!/^index [0-9a-f]+\.\.[0-9a-f]+ [0-7]+$/.test(lines.shift()))throw Error('Invalid index');
 if(lines.shift()!=='--- a/'+name||lines.shift()!=='+++ b/'+name)throw Error('Invalid file headers');
 let oldCount=0,newCount=0;
 for(const line of lines){
  if(line.startsWith('@@ ')){
   if(oldCount||newCount)throw Error('Incomplete hunk');
   const h=line.match(/^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/);
   if(!h)throw Error('Invalid hunk header');oldCount=Number(h[2]??1);newCount=Number(h[4]??1);
  }else if(line[0]===' '){oldCount--;newCount--;}
  else if(line[0]==='-')oldCount--;
  else if(line[0]==='+')newCount--;
  else throw Error('Nonpatch content detected');
  if(oldCount<0||newCount<0)throw Error('Invalid hunk length');
 }
 if(oldCount||newCount)throw Error('Incomplete final hunk');
}
if(JSON.stringify(admitted)!==JSON.stringify(config.targets.map(t=>t.path)))throw Error('Unexpected patch target set');
for(const t of config.targets){
 const target=path.join(config.root,t.path);
 if(fs.lstatSync(target).isSymbolicLink()||fs.realpathSync(target)!==target)throw Error('Noncanonical target '+t.path);
 if(hash(target)!==t.before)throw Error('Before mismatch; stop without overwriting: '+t.path);
}
run(['git','apply','--check',config.patch]);
if(process.argv[2]!=='--apply'){console.log('CHECK ONLY: all before hashes and patch applicability verified');process.exit(0);}
const backup=fs.mkdtempSync(path.join(os.tmpdir(),'a8-t004-recovery-human-backup-'));
for(const t of config.targets){
 const dst=path.join(backup,t.path);fs.mkdirSync(path.dirname(dst),{recursive:true});
 fs.copyFileSync(path.join(config.root,t.path),dst);
 if(hash(dst)!==t.before)throw Error('Backup hash mismatch');
}
console.log('BACKUP='+backup);
fs.writeFileSync(path.join(backup,'pins.json'),JSON.stringify(config,null,2)+'\n',{flag:'wx'});
run(['git','apply',config.patch]);
for(const t of config.targets){
 const actual=hash(path.join(config.root,t.path));
 if(actual!==t.after)throw Error('Readback mismatch; retain backup and inspect: '+t.path);
 console.log(actual+'  '+t.path);
}
console.log('APPLIED AND READBACK VERIFIED; regression and independent evaluation still required.');
