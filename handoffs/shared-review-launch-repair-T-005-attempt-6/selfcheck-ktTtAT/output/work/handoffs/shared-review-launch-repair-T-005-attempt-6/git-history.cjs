// Preserve exact historical Git objects without borrowing the owner's object store.
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const {execFileSync} = require('child_process');
const commits = ['a745aed583291b9b4eda91237a06996896e5d5e8', '1bba72f4a8b539b070956d6fe3644a8ca4aa8f3a', '7df7318e73c688a85bbe29a8e7e326b41eeae4e2'];
const paths = [
  'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh',
  'plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1',
  'plugins/sdd-quality-loop/skills/quality-gate/SKILL.md',
  'plugins/sdd-quality-loop/agents/evaluator.md',
  ...['spec','impl','task'].map(s => `plugins/sdd-review-loop/skills/${s}-review-loop/SKILL.md`),
  ...['spec','impl','task'].flatMap(s => ['a','b'].map(r => `plugins/sdd-review-loop/agents/${s}-reviewer-${r}.md`)),
];
const hash = b => crypto.createHash('sha256').update(b).digest('hex');
const env = Object.fromEntries(Object.entries(process.env).filter(([k]) => !k.startsWith('GIT_')));
Object.assign(env, {GIT_CONFIG_NOSYSTEM:'1', GIT_CONFIG_GLOBAL:'/dev/null', GIT_NO_REPLACE_OBJECTS:'1', GIT_TERMINAL_PROMPT:'0'});
function git(root, args, input) { return execFileSync('git', ['-C',root,...args], {env,input,maxBuffer:128*1024*1024}); }
function verify(root) {
  if(git(root,['rev-parse','a745aed^{commit}']).toString().trim()!==commits[0] || git(root,['rev-parse','a745aed^']).toString().trim()!==commits[1]) throw Error('Red identity mismatch');
  if(git(root,['rev-parse','7df7318^{commit}']).toString().trim()!==commits[2]) throw Error('rollback identity mismatch');
  const changed=git(root,['diff-tree','--no-commit-id','--name-only','-r',commits[0]]).toString().trim().split('\n');
  if(!changed.includes('tests/review-agent-isolation.tests.sh')) throw Error('Red test missing from diff');
  const present=[];
  for(const [i,p] of paths.entries()) {
    let exists=true; try {git(root,['cat-file','-e',`${commits[2]}:${p}`]);} catch {exists=false;}
    if(exists !== (i>=2)) throw Error(`baseline presence mismatch: ${p}`);
    if(exists) present.push(p);
  }
  const archive=git(root,['archive',commits[2],...present]);
  if(!archive.length) throw Error('empty rollback archive');
  return {commits,changed,baseline_present:present,baseline_absent:paths.slice(0,2),archive_sha256:hash(archive)};
}
function create(source, destination) {
  if(path.resolve(destination)!==__dirname) throw Error('artifact destination must be this handoff');
  const objects=new Set(commits);
  for(const c of commits) {
    objects.add(git(source,['rev-parse',`${c}^{tree}`]).toString().trim());
    for(const row of git(source,['ls-tree','-r','-t',c]).toString().trim().split('\n')) {
      const m=row.match(/^\d+ (tree|blob) ([0-9a-f]{40})\t/);
      if(!m) throw Error('unexpected historical tree entry');
      objects.add(m[2]);
    }
  }
  const ids=[...objects].sort();
  const pack=git(source,['pack-objects','--stdout'],ids.join('\n')+'\n');
  const metadata={schema:'t005-git-history/v1',commits,shallow:[commits[1],commits[2]],objects:ids,pack_sha256:hash(pack),expected:verify(source)};
  fs.writeFileSync(path.join(destination,'git-history.pack'),pack,{flag:'wx'});
  fs.writeFileSync(path.join(destination,'git-history.json'),JSON.stringify(metadata,null,2)+'\n',{flag:'wx'});
  return {objects:ids.length,pack_bytes:pack.length,pack_sha256:metadata.pack_sha256};
}
function restore(packFile, metadataFile, destination) {
  const pack=fs.readFileSync(packFile),m=JSON.parse(fs.readFileSync(metadataFile));
  if(m.schema!=='t005-git-history/v1'||JSON.stringify(m.commits)!==JSON.stringify(commits)||JSON.stringify(m.shallow)!==JSON.stringify(commits.slice(1))||hash(pack)!==m.pack_sha256) throw Error('history package mismatch');
  if(!Array.isArray(m.objects)||new Set(m.objects).size!==m.objects.length||m.objects.some(x=>! /^[0-9a-f]{40}$/.test(x))) throw Error('object inventory mismatch');
  if(fs.existsSync(destination)) throw Error('history destination exists');
  fs.mkdirSync(destination);
  git(destination,['init','--bare','--template=']);
  git(destination,['index-pack','--stdin'],pack);
  fs.writeFileSync(path.join(destination,'shallow'),m.shallow.join('\n')+'\n',{flag:'wx'});
  git(destination,['update-ref','refs/heads/fixture-red',commits[0]]);
  git(destination,['update-ref','refs/heads/fixture-rollback',commits[2]]);
  const actual=git(destination,['cat-file','--batch-all-objects','--batch-check=%(objectname)']).toString().trim().split('\n').sort();
  if(JSON.stringify(actual)!==JSON.stringify([...m.objects].sort())) throw Error('restored object inventory mismatch');
  git(destination,['fsck','--full','--no-reflogs']);
  if(fs.existsSync(path.join(destination,'objects/info/alternates'))||fs.existsSync(path.join(destination,'commondir'))) throw Error('external object store');
  const config=fs.readFileSync(path.join(destination,'config'),'utf8');
  if(/remote|alternate|include|promisor/i.test(config)) throw Error('external git configuration');
  const result=verify(destination);
  if(JSON.stringify(result)!==JSON.stringify(m.expected)) throw Error('restored history mismatch');
  return result;
}
if(require.main===module) {
  const [mode,...args]=process.argv.slice(2);
  const result=mode==='create'?create(...args):mode==='restore'?restore(...args):mode==='verify'?verify(...args):(()=>{throw Error('expected create, restore, or verify');})();
  console.log(JSON.stringify(result));
}
module.exports={restore,verify,hash};
