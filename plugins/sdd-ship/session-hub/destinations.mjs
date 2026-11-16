export function destination(transport, target) {
  if (transport === 'pull') return null;
  if (transport === 'codex' && typeof target === 'string' && /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(target)) return target;
  if (transport === 'claude-cloud' && typeof target === 'string') {
    const value = target.replace(/^https:\/\/claude\.ai\/code\//,'').split('?')[0];
    if (/^(session|cse)_[A-Za-z0-9_-]{1,150}$/.test(value)) return value;
  }
  throw new Error('unsupported-conversation');
}
