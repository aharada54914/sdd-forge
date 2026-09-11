# Issue #359 stdin verification: human execution required

2026-09-08: Agent execution of a Node-driven probe of the unchanged shared shell supervisor was denied by PreToolUse before execution. No test process/session was created and no result is available. The denial was the SDD deterministic gate protection message concerning gate scripts, hook configuration, and critical tests. Do not retry this operation through another tool, wrapper, renamed file, or copied implementation.

The following is for a human terminal only. It exercises the original helper with empty and large Unicode input, comparing bytes and SHA-256. It does not invoke vendor models or change repository files. The helper creates completion-marker files in a fresh temporary directory per case; those directories are retained and printed for inspection. This is helper-level evidence, not a full GPT runner acceptance result.

```bash
cd /Users/jrmag/.local/share/sdd-forge-issue359-recovery-20260908 || exit
rtk proxy node <<'NODE'
const {spawnSync}=require('node:child_process');
const {createHash}=require('node:crypto');
const child='const fs=require("node:fs"),c=require("node:crypto");const b=fs.readFileSync(0);process.stdout.write(JSON.stringify({bytes:b.length,sha256:c.createHash("sha256").update(b).digest("hex")}))';
const shell='_scratch=$(mktemp -d -t issue359-stdin); printf "Runtime scratch: %s\\n" "$_scratch" >&2; . "$1"; _sdd_run_bounded 10 "$2" -e "$3"';
let failures=0;
for(const [name,input] of [['empty',Buffer.alloc(0)],['large-unicode',Buffer.from('sanitized bundle 日本語\r\n'.repeat(100000))]]) {
  const r=spawnSync('/bin/bash',['-c',shell,'probe','plugins/sdd-quality-loop/scripts/lib/panelist-common.sh',process.execPath,child],{input,encoding:'utf8',timeout:20000});
  const expected={bytes:input.length,sha256:createHash('sha256').update(input).digest('hex')};
  let actual; try { actual=JSON.parse(r.stdout); } catch { actual=r.stdout; }
  const pass=r.status===0&&JSON.stringify(actual)===JSON.stringify(expected);
  console.log(JSON.stringify({name,pass,expected,actual,exit:r.status,signal:r.signal,stderr:r.stderr,error:r.error?.message}));
  if(!pass) failures++;
}
process.exitCode=failures?1:0;
NODE
printf 'Probe exit: %s\n' "$?"
```

Send the full output back. Do not treat a denied command or missing output as a successful test. Do not commit, push, or merge from this instruction.
