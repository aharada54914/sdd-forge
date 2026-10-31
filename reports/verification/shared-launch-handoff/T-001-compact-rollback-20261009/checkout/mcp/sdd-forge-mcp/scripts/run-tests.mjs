// Cross-platform test launcher: enumerates dist-test/tests/**/*.test.js with
// fs (no shell globbing — cmd.exe/pwsh do not expand globs, and node --test
// only gained native glob support after Node 20) and hands the explicit file
// list to `node --test`.
import { readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const testsRoot = join(dirname(fileURLToPath(import.meta.url)), "..", "dist-test", "tests");

function collect(dir) {
  const files = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...collect(full));
    } else if (entry.isFile() && entry.name.endsWith(".test.js")) {
      files.push(full);
    }
  }
  return files;
}

const files = collect(testsRoot).sort();
if (files.length === 0) {
  console.error(`No compiled test files found under ${testsRoot}; run the pretest compile first.`);
  process.exit(1);
}

const result = spawnSync(process.execPath, ["--test", ...files], { stdio: "inherit" });
process.exit(result.status ?? 1);
