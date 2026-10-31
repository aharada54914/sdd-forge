// Adapter for an existing pipe transport; never creates a process or changes permissions.
import { StringDecoder } from 'node:string_decoder';

export async function observeTransport({ readable, writable, audit, onRecorded = () => {}, responseMethods = new Map(), onResponse = () => {} }) {
  const decoder = new StringDecoder('utf8');
  let pending = '';
  const record = async line => {
    if (!line.trim()) return;
    let message;
    try { message = JSON.parse(line); } catch { throw new Error('invalid JSON: transport evidence incomplete'); }
    if (message && !message.method && responseMethods.has(message.id)) {
      const method = responseMethods.get(message.id);
      responseMethods.delete(message.id);
      await onResponse(audit.captureResponse(method, message));
      return;
    }
    const row = audit.capture('server', line);
    if (!row) return;
    // Persistence and redaction precede the only observer callback.
    const reply = await onRecorded(row);
    if (reply !== undefined) {
      if (row.event.id === undefined || reply?.id !== row.event.id || reply.method) {
        throw new Error('reply must match the observed server request');
      }
      const text = JSON.stringify(reply);
      audit.capture('client', text);
      await new Promise((resolve, reject) => writable.write(text + '\n', error => error ? reject(error) : resolve()));
    }
  };
  const consume = async text => {
    pending += text;
    let newline;
    while ((newline = pending.indexOf('\n')) !== -1) {
      const line = pending.slice(0, newline);
      pending = pending.slice(newline + 1);
      if (Buffer.byteLength(line) > 16 * 1024 * 1024) throw new Error('audit frame bound exceeded');
      await record(line);
    }
    if (Buffer.byteLength(pending) > 16 * 1024 * 1024) throw new Error('audit frame bound exceeded');
  };
  try {
    for await (const chunk of readable) await consume(typeof chunk === 'string' ? chunk : decoder.write(chunk));
    await consume(decoder.end());
    // A complete final JSON frame is valid even without LF; partial JSON throws.
    if (pending.trim()) await record(pending);
  } finally {
    audit.close();
  }
}
