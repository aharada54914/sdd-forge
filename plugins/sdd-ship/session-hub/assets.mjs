import { readFileSync } from 'node:fs';
export function hubAssets() {
  return Object.fromEntries(['hub.html','hub.css','client.mjs','components.mjs'].map(name => [name, readFileSync(new URL(name, import.meta.url), 'utf8')]));
}
