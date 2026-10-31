from __future__ import annotations

import hashlib
import difflib
import json
from pathlib import Path

PATCH = Path("reports/verification/a8-issuer-formal-spec-amendment-attempt-2-v3-native-apply.patch")


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


lines = PATCH.read_text(encoding="utf-8").splitlines(keepends=True)
assert lines[0].rstrip("\n") == "*** Begin Patch"
assert lines[-1].rstrip("\n") == "*** End Patch"
files: list[dict[str, object]] = []
i = 1
while i < len(lines) - 1:
    marker = lines[i].rstrip("\n")
    assert marker.startswith("*** Update File: "), marker
    path = Path(marker.removeprefix("*** Update File: "))
    original = path.read_text(encoding="utf-8")
    reconstructed = original
    hunks: list[dict[str, object]] = []
    i += 1
    while i < len(lines) - 1 and not lines[i].startswith("*** Update File: "):
        assert lines[i].rstrip("\n").startswith("@@"), lines[i]
        i += 1
        old_parts: list[str] = []
        new_parts: list[str] = []
        while i < len(lines) - 1 and not lines[i].startswith("@@") and not lines[i].startswith("*** Update File: "):
            tag = lines[i][:1]
            assert tag in {" ", "+", "-"}, repr(lines[i])
            body = lines[i][1:]
            if tag in {" ", "-"}:
                old_parts.append(body)
            if tag in {" ", "+"}:
                new_parts.append(body)
            i += 1
        old = "".join(old_parts)
        new = "".join(new_parts)
        count = reconstructed.count(old)
        assert count == 1, f"{path}: hunk {len(hunks) + 1}: old block match count {count}"
        reconstructed = reconstructed.replace(old, new, 1)
        hunks.append({"old_block_match_count": count, "old_bytes": len(old.encode()), "new_bytes": len(new.encode())})
    diff = "".join(difflib.unified_diff(
        original.splitlines(keepends=True),
        reconstructed.splitlines(keepends=True),
        fromfile=str(path),
        tofile=str(path) + ".candidate",
    ))
    files.append({
        "path": str(path),
        "hunks": hunks,
        "original_sha256": sha(original.encode()),
        "reconstructed_sha256": sha(reconstructed.encode()),
        "reconstructed_diff_sha256": sha(diff.encode()),
        "diff_additions": sum(1 for line in diff.splitlines() if line.startswith("+") and not line.startswith("+++")),
        "diff_deletions": sum(1 for line in diff.splitlines() if line.startswith("-") and not line.startswith("---")),
        "changed": reconstructed != original,
    })

print(json.dumps({
    "result": "APPLICABLE_IN_MEMORY",
    "frozen_files_written": False,
    "patch_sha256": sha(PATCH.read_bytes()),
    "files": files,
}, indent=2, sort_keys=True))
