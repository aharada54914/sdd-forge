// Session-local diagnostic guard. This does not replace existing host hooks.
let input = '';
for await (const chunk of process.stdin) input += chunk;

let allowed = false;
try {
  const event = JSON.parse(input);
  allowed = process.argv.length === 3 &&
    process.argv[2].length > 0 &&
    event.tool_name === 'Bash' &&
    typeof event.tool_input?.command === 'string' &&
    event.tool_input.command === process.argv[2];
} catch {
  // Invalid or absent hook input fails closed.
}

if (!allowed) {
  process.stdout.write(JSON.stringify({
    hookSpecificOutput: {
      hookEventName: 'PreToolUse',
      permissionDecision: 'deny',
      permissionDecisionReason: 'A8 session-local Bash command is not the caller-pinned exact command'
    }
  }));
}
