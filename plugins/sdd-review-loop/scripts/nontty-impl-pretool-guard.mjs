// Additive session-local guard; existing host hooks remain active.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';

let allowed = false;
try {
  if (process.argv.length !== 4 || !/^[0-9a-f]{64}$/.test(process.argv[3])) {
    throw new Error('pinned policy path and digest required');
  }
  const bytes = fs.readFileSync(process.argv[2]);
  if (crypto.createHash('sha256').update(bytes).digest('hex') !== process.argv[3]) {
    throw new Error('policy bytes differ from caller pin');
  }
  const policy = JSON.parse(bytes.toString('utf8'));
  if (policy.schema !== 'impl-nontty-pretool/v1' ||
      !Array.isArray(policy.read_paths) || !Array.isArray(policy.bash_commands)) {
    throw new Error('invalid policy');
  }
  if (policy.output_tool !== undefined && policy.output_tool !== 'StructuredOutput') {
    throw new Error('invalid output tool');
  }
  let input = '';
  for await (const chunk of process.stdin) input += chunk;
  const event = JSON.parse(input);
  if (event.tool_name === 'Bash') {
    allowed = typeof event.tool_input?.command === 'string' &&
      policy.bash_commands.includes(event.tool_input.command);
  } else if (event.tool_name === 'Read') {
    const requested = event.tool_input?.file_path;
    allowed = typeof requested === 'string' && requested.length > 0 &&
      policy.read_paths.includes(fs.realpathSync(path.resolve(requested)));
  } else if (event.tool_name === 'StructuredOutput') {
    allowed = policy.output_tool === 'StructuredOutput' &&
      event.tool_input !== null && typeof event.tool_input === 'object' &&
      !Array.isArray(event.tool_input);
  }
} catch {
  // Any missing/malformed policy, event or path fails closed.
}

if (!allowed) {
  process.stdout.write(JSON.stringify({hookSpecificOutput: {
    hookEventName: 'PreToolUse', permissionDecision: 'deny',
    permissionDecisionReason: 'Impl non-TTY tool call differs from caller-pinned inputs'
  }}));
}
