#!/usr/bin/env python3
"""Check an unapplied two-file patch in memory; parse only, never execute candidates."""
import hashlib
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[2]
patch = (root / 'reports/verification/a8-nonce-driver-minimal-candidate-20261005.patch').read_text()
pins = {'sh': '479ab524fae57a47c117129f16fcf045b7010af9544f181bb369389d957027ae', 'ps1': '8a01086d9612cf4f21a243ac407fef5cb26af9f94082209927e12e118daf29f9'}
sections = patch.split('diff --git ')[1:]
assert len(sections) == 2
for ext, section in zip(pins, sections):
    path = f'tests/cross-runtime-handoff.tests.{ext}'
    assert section.splitlines()[0] == f'a/{path} b/{path}'
    raw = (root / path).read_bytes()
    assert hashlib.sha256(raw).hexdigest() == pins[ext]
    lines = raw.decode().splitlines(keepends=True)
    edits = []
    for hunk in section.split('@@ -')[1:]:
        header, body = hunk.split('\n', 1)
        match = re.fullmatch(r'(\d+),(\d+) \+(\d+),(\d+) @@', header)
        assert match
        old_start, old_count, new_start, new_count = map(int, match.groups())
        body_lines = body.splitlines(keepends=True)
        assert all(line.startswith(('-', '+')) for line in body_lines)
        old = [line[1:] for line in body_lines if line.startswith('-')]
        new = [line[1:] for line in body_lines if line.startswith('+')]
        assert (len(old), len(new)) == (old_count, new_count)
        assert lines[old_start-1:old_start-1+old_count] == old
        edits.append((old_start-1, old_count, new))
    assert len(edits) == 3
    for start, count, replacement in reversed(edits):
        lines[start:start+count] = replacement
    candidate = ''.join(lines)
    if ext == 'sh':
        result = subprocess.run(['bash', '-n'], input=candidate, text=True, capture_output=True)
        # bash -n does not parse the embedded Python here-document.
        for block in re.findall(r"<<'PY'[^\n]*\n(.*?)\nPY", candidate, re.S):
            compile(block, '<candidate-heredoc>', 'exec')
    else:
        parser = '$s=[Console]::In.ReadToEnd(); $t=$null; $e=$null; $null=[Management.Automation.Language.Parser]::ParseInput($s,[ref]$t,[ref]$e); if($e.Count){$e | ForEach-Object {[Console]::Error.WriteLine($_.Message)}; exit 1}'
        result = subprocess.run(['pwsh', '-NoLogo', '-NoProfile', '-NonInteractive', '-Command', parser], input=candidate, text=True, capture_output=True)
    assert result.returncode == 0, result.stderr
    assert not result.stdout and not result.stderr, (result.stdout, result.stderr)
    print(f'{path}: pinned base, 3 exact hunks, syntax valid; candidate sha256={hashlib.sha256(candidate.encode()).hexdigest()}')
print('No candidate execution or file application performed.')
