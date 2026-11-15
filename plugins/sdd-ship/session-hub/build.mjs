import { readFileSync } from 'node:fs';
import { hubAssets } from './assets.mjs';
export function embeddedHub() {
  const code = ['core.mjs','http.mjs','asset-response.mjs','mcp.mjs'].map(file => readFileSync(new URL(file, import.meta.url),'utf8')
    .replace(/^import .*;\n/gm,'').replace(/^export /gm,'')).join('\n');
  return `const hub = (() => {\n${code}\nreturn {hubRequest,digest,assetResponse,mcpRequest};\n})();\nconst hubAssets = ${JSON.stringify(hubAssets())};`;
}
