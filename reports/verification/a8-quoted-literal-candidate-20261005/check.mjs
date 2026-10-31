// Candidate-only, in-memory predicate regression. Never executes fixture commands.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import crypto from 'node:crypto';
import { createRequire } from 'node:module';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '../../..');
const config = JSON.parse(fs.readFileSync(path.join(here, 'candidate.json'), 'utf8'));
const evidence = JSON.parse(fs.readFileSync(path.join(root, 'reports/impl-review/epic-196-a8-integration/attempt-8/round-1/launch-command-diagnostic.json'), 'utf8'));
const a = evidence.a, b = evidence.b;
if (typeof a !== 'string' || typeof b !== 'string') throw Error('Missing diagnostic command strings');
const protectedPath = 'plugins/sdd-quality-loop/scripts/sdd-hook-guard.py';
const cases = [
  {name: 'exact-refused-B', command: b, red: true, deny: false},
  {name: 'reconstructed-A-control', command: a, red: false, deny: false},
];
const deny = (name, command) => cases.push({name, command, red: true, deny: true});
deny('external-redirect', b + ' > ' + protectedPath);
deny('mixed-compound-writer', b + '; rm ' + protectedPath);
deny('writer-request-in-prompt', b.slice(0,-1) + '; rm ' + protectedPath + "'");
deny('python-request-in-prompt', b.slice(0,-1) + ' python ' + protectedPath + "'");
deny('arbitrary-bash', b.replace('--allowedTools Read ', "--allowedTools Read 'Bash(*)' "));
deny('write-tool-enabled', b.replace('--tools Read,Bash', '--tools Read,Bash,Write'));
deny('missing-disallowed-tools', b.replace(' --disallowedTools Write,Edit,NotebookEdit', ''));
deny('interactive-permission-mode', b.replace('dontAsk', 'default'));
deny('unknown-option', b.replace(' --print ', ' --dangerously-skip-permissions --print '));
deny('case-variant-option', b.replace('--tools Read,Bash', '--tools read,bash'));
deny('unclosed-prompt', b.slice(0,-1));
deny('trailing-newline-writer', b + '\nrm ' + protectedPath);
deny('changed-system-substitution', b.replace('$(rtk proxy cat ', '$(rtk proxy rm '));
deny('unquoted-round-control', 'rtk proxy cat ' + protectedPath + ' round>1');
deny('shell-interpreter-control', "bash -c 'cat > " + protectedPath + "'");
cases.push({name: 'read-only-cat-control', command: 'rtk proxy cat ' + protectedPath, red:false, deny:false});
const sha = s => crypto.createHash('sha256').update(s).digest('hex');
const result = {status: 'candidate-only', fixtures: cases.map(({command,...rest}) => ({...rest, command_sha256:sha(command)})), runtimes: []};
for (const entry of config.entries) {
  const target = path.join(root, 'plugins/sdd-quality-loop/scripts/sdd-hook-guard.' + entry.ext);
  const original = fs.readFileSync(target, 'utf8');
  if (sha(original) !== entry.sha) throw Error('Baseline drift: ' + target);
  if (original.split(entry.anchor).length !== 2) throw Error('Anchor mismatch');
  // Limit the replacement to the R-10 function, not similarly named later checks.
  const index = original.indexOf(entry.anchor);
  const candidate = original.slice(0,index) + entry.helper + original.slice(index).replace(entry.old, entry.replace);
  if (!candidate.includes(entry.replace)) throw Error('Replacement mismatch');
  const outputs = [];
  for (const [phase, source] of [['RED',original],['GREEN',candidate]]) {
    let values;
    if (entry.ext === 'js') {
      if (!source.endsWith('main();\n')) throw Error('Unknown JS main boundary');
      const context = {require:createRequire(target),__dirname:path.dirname(target),console,process,Buffer};
      vm.createContext(context);
      vm.runInContext(source.slice(0,-'main();\n'.length),context);
      values = cases.map(c => context.shellTargetsProtectedGateFile(c.command));
    } else {
      const program = entry.ext === 'py' ? 'python3' : 'pwsh';
      const py = 'import sys,json; d=json.load(sys.stdin); n={"__name__":"candidate_predicate","__file__":d["target"]}; exec(compile(d["source"],d["target"],"exec"),n); print(json.dumps([n["_shell_targets_protected_gate_file"](c["command"]) for c in d["cases"]]))';
      const args = entry.ext === 'py' ? ['-B','-c',py] : ['-NoProfile','-File',path.join(here,'check.ps1')];
      const proc = spawnSync(program,args,{input:JSON.stringify({source,target,cases}),encoding:'utf8',cwd:root,maxBuffer:2e6});
      if (proc.status !== 0) throw Error(program + ': ' + proc.stderr + proc.stdout);
      values = JSON.parse(proc.stdout);
    }
    const mismatches = cases.filter((c,i)=>values[i] !== (phase==='RED'?c.red:c.deny)).map(c=>c.name);
    outputs.push({phase, matched:cases.length-mismatches.length, mismatches, decisions:values});
  }
  if (sha(fs.readFileSync(target)) !== entry.sha) throw Error('Original changed');
  result.runtimes.push({ext:entry.ext, before_sha256:entry.sha,candidate_sha256:sha(candidate),outputs});
}
console.log(JSON.stringify(result,null,2));
if (result.runtimes.some(r=>r.outputs.some(o=>o.mismatches.length))) process.exitCode=1;
