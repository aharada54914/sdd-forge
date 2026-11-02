#!/usr/bin/env python3
"""Documentation quality checks for README.md and docs/**/*.md.

Checks:
  (a) relative Markdown links resolve to existing files;
  (b) every ```mermaid block parses (mermaid + jsdom, no browser);
  (c) no hard-coded vX.Y.Z version appears inside a Mermaid block;
  (d) pinned anchors that scripts and other tests depend on are still present.

The Mermaid check needs Node.js plus the `mermaid` and `jsdom` packages.
When they are unavailable the check is skipped locally, and it fails under CI
(CI=true) or when DOC_DIAGRAMS_REQUIRE_MERMAID=1, so CI never passes silently.
DOC_DIAGRAMS_MERMAID_DIR may point at a directory that already contains
node_modules/mermaid and node_modules/jsdom.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

MERMAID_VERSION = "12.2.0"
JSDOM_VERSION = "30.1.3"

FENCE_RE = re.compile(r"^```mermaid[ \t]*\n(.*?)\n```[ \t]*$", re.S | re.M)
ANY_FENCE_RE = re.compile(r"^```.*?^```[ \t]*$", re.S | re.M)
LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+?)(?:\s+\"[^\"]*\")?\)")
VERSION_RE = re.compile(r"\bv?\d+\.\d+\.\d+\b")
RELEASE_LINE_RE = re.compile(r"^v\d+\.\d+\.\d+ — ", re.M)

MJS_HELPER = """\
import { JSDOM } from 'jsdom';
import fs from 'node:fs';
const dom = new JSDOM('<!doctype html><html><body></body></html>', { pretendToBeVisual: true });
globalThis.window = dom.window;
globalThis.document = dom.window.document;
try { globalThis.navigator = dom.window.navigator; } catch {}
const mermaid = (await import('mermaid')).default;
mermaid.initialize({ startOnLoad: false });
const blocks = JSON.parse(fs.readFileSync(0, 'utf8'));
const results = [];
for (const b of blocks) {
  try { await mermaid.parse(b.source); results.push({ id: b.id, ok: true }); }
  catch (e) { results.push({ id: b.id, ok: false, error: String(e.message || e).split('\\n').slice(0, 3).join(' | ') }); }
}
process.stdout.write(JSON.stringify(results));
"""


def doc_files(root: Path) -> list[Path]:
    files = []
    readme = root / "README.md"
    if readme.is_file():
        files.append(readme)
    docs = root / "docs"
    if docs.is_dir():
        files.extend(sorted(docs.rglob("*.md")))
    return files


def mermaid_blocks(text: str) -> list[tuple[int, str]]:
    return [(text.count("\n", 0, m.start()) + 1, m.group(1)) for m in FENCE_RE.finditer(text)]


def check_links(root: Path, files: list[Path]) -> list[str]:
    errors = []
    for path in files:
        text = path.read_text(encoding="utf-8")
        text = ANY_FENCE_RE.sub("", text)
        for m in LINK_RE.finditer(text):
            target = m.group(1)
            if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", target) or target.startswith("#"):
                continue
            rel = target.split("#", 1)[0]
            if not rel:
                continue
            resolved = (path.parent / rel).resolve()
            if not resolved.exists():
                errors.append(f"{path.relative_to(root)}: broken relative link -> {target}")
    return errors


def check_versions(root: Path, files: list[Path]) -> list[str]:
    errors = []
    for path in files:
        text = path.read_text(encoding="utf-8")
        for line, source in mermaid_blocks(text):
            found = sorted(set(VERSION_RE.findall(source)))
            if found:
                errors.append(
                    f"{path.relative_to(root)}:{line}: hard-coded version in Mermaid block: {', '.join(found)}"
                )
    return errors


def check_pinned(root: Path) -> list[str]:
    errors = []
    readme = root / "README.md"
    if readme.is_file():
        head = readme.read_text(encoding="utf-8").splitlines()[:5]
        if not any(RELEASE_LINE_RE.match(line) for line in head):
            errors.append("README.md: the release line 'vX.Y.Z — ...' must stay within the first 5 lines")
    guide = root / "docs" / "workflow-guide.md"
    if guide.is_file():
        if "P --> W[workflow-retrospective" not in guide.read_text(encoding="utf-8"):
            errors.append("docs/workflow-guide.md: pinned Mermaid line 'P --> W[workflow-retrospective' is missing")
    return errors


def find_mermaid_dir() -> tuple[Path | None, str]:
    env = os.environ.get("DOC_DIAGRAMS_MERMAID_DIR")
    if env:
        d = Path(env)
        if (d / "node_modules" / "mermaid").is_dir() and (d / "node_modules" / "jsdom").is_dir():
            return d, ""
        return None, f"DOC_DIAGRAMS_MERMAID_DIR={env} lacks node_modules/mermaid or node_modules/jsdom"
    if shutil.which("node") is None or shutil.which("npm") is None:
        return None, "node/npm not found"
    tmp = Path(tempfile.mkdtemp(prefix="doc-diagrams-"))
    proc = subprocess.run(
        ["npm", "install", "--no-audit", "--no-fund", "--ignore-scripts", "--prefix", str(tmp),
         f"mermaid@{MERMAID_VERSION}", f"jsdom@{JSDOM_VERSION}"],
        capture_output=True, text=True, timeout=600,
    )
    if proc.returncode != 0:
        shutil.rmtree(tmp, ignore_errors=True)
        tail = proc.stderr.strip().splitlines()[-1:] or ["no stderr"]
        return None, f"npm install of mermaid/jsdom failed: {tail[0]}"
    return tmp, ""


def parse_blocks(blocks: list[dict]) -> list[dict]:
    mdir, why = find_mermaid_dir()
    if mdir is None:
        raise RuntimeError(why)
    work = Path(tempfile.mkdtemp(prefix="doc-diagrams-run-"))
    try:
        (work / "node_modules").symlink_to(mdir / "node_modules", target_is_directory=True)
        helper = work / "parse.mjs"
        helper.write_text(MJS_HELPER, encoding="utf-8")
        proc = subprocess.run(
            ["node", str(helper)], input=json.dumps(blocks), capture_output=True, text=True,
            cwd=work, timeout=600,
        )
        if proc.returncode != 0:
            raise RuntimeError("node parser failed: " + proc.stderr.strip()[:300])
        return json.loads(proc.stdout)
    finally:
        shutil.rmtree(work, ignore_errors=True)


def mermaid_required() -> bool:
    return os.environ.get("CI", "").lower() == "true" or os.environ.get("DOC_DIAGRAMS_REQUIRE_MERMAID") == "1"


def check_mermaid(root: Path, files: list[Path]) -> tuple[list[str], str]:
    blocks, labels = [], {}
    for path in files:
        for line, source in mermaid_blocks(path.read_text(encoding="utf-8")):
            bid = len(blocks)
            blocks.append({"id": bid, "source": source})
            labels[bid] = f"{path.relative_to(root)}:{line}"
    if not blocks:
        return [], "no Mermaid blocks"
    try:
        results = parse_blocks(blocks)
    except RuntimeError as exc:
        if mermaid_required():
            return [f"Mermaid parser unavailable but required: {exc}"], ""
        return [], f"SKIP Mermaid parse ({exc})"
    errors = [f"{labels[r['id']]}: Mermaid parse error: {r['error']}" for r in results if not r["ok"]]
    return errors, f"parsed {len(results)} Mermaid blocks"


def run_checks(root: Path) -> tuple[list[str], list[str]]:
    files = doc_files(root)
    errors = check_links(root, files) + check_versions(root, files) + check_pinned(root)
    merr, note = check_mermaid(root, files)
    return errors + merr, [f"checked {len(files)} Markdown files", note]


def selftest() -> list[str]:
    """Negative controls: each defect must be detected."""
    failures = []
    with tempfile.TemporaryDirectory(prefix="doc-diagrams-self-") as t:
        root = Path(t)
        (root / "docs").mkdir()
        (root / "README.md").write_text("v1.2.3 — x\n", encoding="utf-8")
        good = root / "docs" / "ok.md"
        good.write_text("[a](../README.md)\n```mermaid\nflowchart TD\n    A --> B\n```\n", encoding="utf-8")
        if check_links(root, doc_files(root)) or check_versions(root, doc_files(root)):
            failures.append("selftest: clean fixture was rejected")
        (root / "docs" / "bad-link.md").write_text("[x](missing.md)\n", encoding="utf-8")
        if not check_links(root, doc_files(root)):
            failures.append("selftest: broken link not detected")
        (root / "docs" / "bad-link.md").unlink()
        (root / "docs" / "ver.md").write_text("```mermaid\nflowchart TD\n    A[\"v1.2.3\"] --> B\n```\n", encoding="utf-8")
        if not check_versions(root, doc_files(root)):
            failures.append("selftest: hard-coded version in Mermaid not detected")
        (root / "docs" / "ver.md").unlink()
        (root / "README.md").write_text("no release line\n", encoding="utf-8")
        if not check_pinned(root):
            failures.append("selftest: missing release line not detected")
    return failures


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[1]))
    parser.add_argument("--no-selftest", action="store_true")
    args = parser.parse_args()
    root = Path(args.root).resolve()

    problems = [] if args.no_selftest else selftest()
    errors, notes = run_checks(root)
    for note in notes:
        if note:
            print(note)
    for line in problems + errors:
        print(f"not ok: {line}", file=sys.stderr)
    if problems or errors:
        return 1
    print("ok: documentation links, Mermaid diagrams and pinned anchors are consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
