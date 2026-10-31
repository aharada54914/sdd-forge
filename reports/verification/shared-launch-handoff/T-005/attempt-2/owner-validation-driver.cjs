// Noninteractive test driver: EOF on stdin, never an unclosed input pipe.
const cp = require('node:child_process');
const commands = [
  ['python3', '-B', 'tests/unified-launch-order.tests.py', '-v'],
  ['python3', '-B', 'tests/review-conditional-inputs.tests.py', '-v'],
  ['bash', 'tests/review-context-boundary.tests.sh'],
];
Promise.all(commands.map(args => new Promise(resolve => {
  const started = new Date().toISOString();
  const child = cp.spawn('rtk', ['proxy', ...args], {
    cwd: process.cwd(), env: process.env, stdio: ['ignore', 'pipe', 'pipe'],
  });
  let stdout = '', stderr = '';
  child.stdout.on('data', data => stdout += data);
  child.stderr.on('data', data => stderr += data);
  child.on('error', error => { throw error; });
  child.on('close', (exit, signal) => {
    console.log(JSON.stringify({command: ['rtk', 'proxy', ...args],
      cwd: process.cwd(), stdin: 'EOF (/dev/null)', environment: 'inherited default',
      started, ended: new Date().toISOString(), exit, signal, stdout, stderr}));
    if (exit !== 0) process.exitCode = 1;
    resolve();
  });
})));
