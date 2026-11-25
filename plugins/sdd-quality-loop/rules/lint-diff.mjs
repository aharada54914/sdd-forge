import { execFileSync } from 'node:child_process';

const EXT = ['js', 'jsx', 'mjs', 'cjs', 'ts', 'tsx', 'mts', 'cts'];
export const LINTABLE = /\.(?:[cm]?[jt]s|[jt]sx)$/i;

function git(root, args) {
  return execFileSync('git', args, {
    cwd: root, encoding: 'utf8', shell: false, maxBuffer: 64 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'],
  });
}

// The raw NUL-delimited names and the patch sections have the same diff order.
// Associating by index preserves filenames containing spaces, quotes or newlines.
export function changedHunks(root, baseRef = 'HEAD') {
  const sha = git(root, ['rev-parse', '--verify', '--end-of-options', baseRef + '^{commit}']).trim();
  const paths = EXT.map(ext => ':(icase,glob)**/*.' + ext);
  const data = git(root, ['diff', '--no-ext-diff', '--no-textconv', '--no-color', '--no-renames',
    '--diff-filter=AMT', '--raw', '-z', '--patch', '--unified=0', sha, '--', ...paths]);
  const files = new Map();
  if (data) {
    const delimiter = data.indexOf('\0\0');
    if (delimiter < 0) throw new Error('Cannot read Git diff header');
    const raw = data.slice(0, delimiter).split('\0');
    const patches = data.slice(delimiter + 2).split(/^diff --git /m).slice(1);
    if (patches.length * 2 !== raw.length) throw new Error('Cannot match Git filenames to hunks');
    for (const [i, patch] of patches.entries()) {
      const ranges = [];
      for (const match of patch.matchAll(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/gm)) {
        const start = Number(match[1]);
        const count = Number(match[2] ?? 1);
        if (count) ranges.push([start, start + count - 1]);
      }
      if (ranges.length) files.set(raw[2 * i + 1], ranges);
    }
  }
  for (const file of git(root, ['ls-files', '--others', '--exclude-standard', '-z', '--', ...paths]).split('\0')) {
    if (file) files.set(file, [[1, Infinity]]);
  }
  return files;
}
