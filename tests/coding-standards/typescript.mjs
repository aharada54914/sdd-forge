// The installed compiler parses its own syntax; no unsupported ESLint parser.
import { API } from '../../mcp/sdd-forge-mcp/node_modules/typescript/dist/api/sync/api.js';
import { SyntaxKind } from '../../mcp/sdd-forge-mcp/node_modules/typescript/dist/ast/index.js';
import ts from '../../mcp/sdd-forge-mcp/node_modules/typescript/lib/version.cjs';
import { readFileSync } from 'node:fs';

let api;
try {
  const [major, minor] = process.versions.node.split('.').map(Number);
  if (major < 22 || (major === 22 && minor < 19)) throw new Error('Unsupported Node runtime');
  if (ts.version !== '7.0.2') throw new Error('Unsupported TypeScript compiler');
  const paths = JSON.parse(readFileSync(0, 'utf8'));
  if (!Array.isArray(paths) || paths.some(path => typeof path !== 'string')) {
    throw new Error('Invalid path list');
  }
  const findings = [];
  api = new API();
  const snapshot = api.updateSnapshot({ openFiles: paths });
  for (const path of paths) {
    const project = snapshot.getDefaultProjectForFile(path);
    if (!project) throw new Error('Missing compiler project');
    const source = project.program.getSourceFile(path);
    if (!source) throw new Error('Missing compiler source');
    for (const error of project.program.getSyntacticDiagnostics(path)) {
      const position = source.getLineAndCharacterOfPosition(error.start ?? 0);
      findings.push({ path, line: position.line + 1, column: position.character + 1,
        code: `TS${error.code}`, message: 'TypeScript/JavaScript syntax error' });
    }
    function visit(node) {
      if (node.kind === SyntaxKind.AnyKeyword) {
        const position = source.getLineAndCharacterOfPosition(node.getStart(source));
        findings.push({ path, line: position.line + 1, column: position.character + 1,
          code: 'explicit-any', message: 'Replace explicit any with a validated boundary or precise type' });
      }
      node.forEachChild(visit);
    }
    visit(source);
  }
  process.stdout.write(JSON.stringify({ version: ts.version, findings }));
} catch {
  process.stderr.write('TypeScript analysis failed\n');
  process.exitCode = 2;
} finally {
  api?.close();
}
