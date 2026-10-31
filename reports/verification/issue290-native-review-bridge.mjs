import fs from 'node:fs';
import readline from 'node:readline';
import {spawn} from 'node:child_process';

// Transparent local stdio transport; never synthesizes reviewer output.
const [role, prefix] = process.argv.slice(2);
if (!['task-reviewer-a', 'task-reviewer-b'].includes(role) || !prefix) throw Error('role/prefix required');
const fd = fs.openSync(prefix + '-events.jsonl', 'wx');
const err = fs.openSync(prefix + '-stderr.txt', 'wx');
const child = spawn('rtk', ['proxy', 'codex', 'app-server', '--stdio'],
  {stdio: ['pipe', 'pipe', err]});
let buffered = '';
const send = value => child.stdin.write(JSON.stringify(value) + '\n');
child.stdout.on('data', chunk => {
  buffered += chunk;
  let end;
  while ((end = buffered.indexOf('\n')) >= 0) {
    const line = buffered.slice(0, end); buffered = buffered.slice(end + 1);
    fs.writeSync(fd, line + '\n');
    let message; try { message = JSON.parse(line); } catch { continue; }
    if (message.id !== undefined || ['turn/completed', 'error', 'thread/started', 'item/completed'].includes(message.method)) {
      console.log(JSON.stringify(message));
    }
    if (message.id === 1 && message.result) send({method: 'initialized'});
  }
});
readline.createInterface({input: process.stdin}).on('line', line => {
  if (line === 'EXIT') { child.stdin.end(); child.kill(); return; }
  if (line.startsWith('SEND ')) {
    try { send(JSON.parse(fs.readFileSync(line.slice(5), 'utf8'))); }
    catch (e) { console.error(e.message); }
    return;
  }
  try { send(JSON.parse(line)); } catch (e) { console.error(e.message); }
});
child.on('exit', code => {fs.closeSync(fd); fs.closeSync(err); process.exit(code ?? 1);});
send({id: 1, method: 'initialize', params: {
  clientInfo: {name: 'issue290-formal-review', version: '1'},
  capabilities: {experimentalApi: true}
}});
