#!/usr/bin/env python3
"""Human-only one-paragraph repair; no changes without --apply."""
import hashlib
from pathlib import Path
import sys
import tempfile

target = Path("/Users/jrmag/.codex/worktrees/issue290-concept-phase1/sdd-forge/specs/sdd-domain-concept-test/design.md")
expected = "f6ef6a89fa8a76e58b00ef7310b9188864342f81ea2a92672287b27db7ce511b"
anchor = "## Open Questions\n"
paragraph = """単体検証の対象は、新しいConcept Test契約検査のJSON構造・列挙値・md/json一致・入力path/hash一致、および証跡検証結果から続行/保留/停止を選ぶ処理とする。下流のdomain-syncと後続生成だけを呼出順・回数を記録するspyに置換し、不正/保留/停止で各0回、続行でdomain-sync→生成の順となることを検証する。標準approval検証はモックせず、隔離した一時鍵・登録済みテスト承認者を使った実署名・content/hash/HMAC/registry検証を統合検証し、TEST-030〜034の拒否を実際の検証器で確認する。鍵・registry・署名検証結果を固定値で代替しない。TEST-035〜078の入力差替え・md/json差・manifest欠落検証と既存Phase0回帰も保持する。

"""
if sys.argv[1:] not in ([], ["--dry-run"], ["--apply"]):
    raise SystemExit("usage: human-apply-test-strategy.py [--dry-run|--apply]")
if target.is_symlink() or not target.is_file():
    raise SystemExit("STOP: target is not a regular file")
raw = target.read_bytes()
if hashlib.sha256(raw).hexdigest() != expected:
    raise SystemExit("STOP: reviewed design hash mismatch")
text = raw.decode("utf-8")
if text.count(anchor) != 1:
    raise SystemExit("STOP: paragraph boundary is not unique")
updated = text.replace(anchor, paragraph + anchor, 1).encode("utf-8")
if sys.argv[1:] != ["--apply"]:
    print("DRY_RUN_OK: one test-strategy paragraph; no files changed")
else:
    backup = Path(tempfile.mkdtemp(prefix="sdd290-design-backup-")) / "design.md"
    backup.write_bytes(raw)
    if target.read_bytes() != raw:
        raise SystemExit("STOP: concurrent edit; backup=" + str(backup))
    target.write_bytes(updated)
    print("APPLIED: design Test Strategy only; backup=" + str(backup))
    print("design_sha256=" + hashlib.sha256(updated).hexdigest())
    print("No status, approval, verdict, commit, push or merge changes.")
