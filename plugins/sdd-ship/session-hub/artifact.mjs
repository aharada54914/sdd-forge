/** Generate one self-contained Artifact; bind SDD adapters through real remote connectors. */
import { hubAssets } from './assets.mjs';
const assets = hubAssets();
const script = assets['components.mjs'].replace(/^export /gm,'') + '\n' + assets['client.mjs'].replace(/^import .*;\n/gm,'');
const page = assets['hub.html'].replace('<body>','<body data-mode="artifacts">')
  .replace('<link rel="stylesheet" href="/hub/hub.css">','<style>' + assets['hub.css'] + '</style>')
  .replace('<script type="module" src="/hub/client.mjs"></script>','<script type="module">' + script.replace(/<\/script/gi,'<\\/script') + '</script>')
  .replace('<a href="/">開発状況に戻る</a>','');
process.stdout.write(page);
