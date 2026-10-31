import ast
import hashlib
import json
import re
import tempfile
from pathlib import Path
from normalization_candidate import resolve

repo = Path(__file__).resolve().parents[3]
count = 0
for suffix in ("sh", "ps1"):
    source = (repo / f"plugins/sdd-quality-loop/scripts/validate-review-context-set.{suffix}").read_text()
    start = source.index("def safe_path(root, path):")
    end = source.index("def identity(document):", start)
    ns = {"re": re}
    exec(compile(ast.parse(source[start:end]), suffix, "exec"), ns)
    with tempfile.TemporaryDirectory(prefix="sdd423-normalization-") as tmp:
        owner = Path(tmp).resolve()
        report, observation, receipt = [owner / name for name in ("report.md", "observation.json", "receipt.json")]
        raw = "specs/feature/verification/T-003/run/"
        body = f"Run ID: original-run\nTask Attempt Count: 2\n- **Session ID**: original-session\n- **Scratch Root**: {raw}\n"
        report.write_text(body)
        digest = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
        evidence = {"owner": str(owner), "run": "original-run", "report_sha256": digest(report)}
        observation.write_text(json.dumps(evidence))
        item = {"report": str(report), "report_sha256": digest(report), "raw_root": raw, "run": "original-run", "session": "original-session", "attempt": 2, "owner": str(owner), "owner_observation": str(observation), "owner_observation_sha256": digest(observation)}
        def setup(change=None):
            current = dict(item)
            if change:
                current.update(change)
            receipt.write_text(json.dumps(current))
            return {str(receipt): digest(receipt), str(observation): digest(observation)}
        def run(admitted, declaration=raw):
            return resolve(report, declaration, receipt, admitted, ns["canonical"], ns["safe_path"])
        def rejected(name, action):
            global count
            try:
                action()
            except (ValueError, OSError):
                count += 1
                print(f"ok {suffix} {name}")
            else:
                raise AssertionError(name)
        rejected("original rejects relative root", lambda: ns["canonical"](raw))
        target = run(setup())
        assert target == str(owner / raw.rstrip("/")) and not Path(target).exists()
        count += 1
        print(f"ok {suffix} exact evidence resolves absent historical directory without creating it")
        for label, change in (("run", {"run": "wrong"}), ("session", {"session": "wrong"}), ("attempt", {"attempt": 3}), ("bool attempt", {"attempt": True}), ("report hash", {"report_sha256": "0"*64}), ("owner", {"owner": str(owner / "missing")}), ("unknown field", {"extra": "x"}), ("raw mismatch", {"raw_root": "other"}), ("observation hash", {"owner_observation_sha256": "0"*64})):
            pins = setup(change)
            rejected(label, lambda: run(pins))
        rejected("missing admission", lambda: run({}))
        pins = setup()
        receipt.write_text(receipt.read_text() + " ")
        rejected("changed receipt", lambda: run(pins))
        pins = setup()
        report.write_text(body + "changed")
        rejected("changed report", lambda: run(pins))
        report.write_text(body)
        pins = setup()
        observation.write_text(json.dumps(dict(evidence, owner="/other")))
        rejected("changed observation", lambda: run(pins))
        observation.write_text(json.dumps(evidence))
        for malicious in ("../escape", "/absolute", "a//b", "a/./b", "a\\b", "C:/escape", "a//"):
            report.write_text(body.replace(raw, malicious))
            pins = setup({"report_sha256": digest(report), "raw_root": malicious})
            # Rebind observation to the mutated fixture report; path must still reject.
            observation.write_text(json.dumps(dict(evidence, report_sha256=digest(report))))
            pins = setup({"report_sha256": digest(report), "raw_root": malicious, "owner_observation_sha256": digest(observation)})
            rejected("unsafe " + repr(malicious), lambda: run(pins, malicious))
        report.write_text(body)
        observation.write_text(json.dumps(evidence))
        (owner / "specs").symlink_to(owner.parent, target_is_directory=True)
        rejected("symlink escape", lambda: run(setup()))
        for other in (target, target + "/child", str(Path(target).parent)):
            assert ns["overlap"](target, other)
            count += 1
        assert not ns["overlap"](target, target + "-sibling")
        count += 1
print(f"PASS: {count}; prototype only; no original validator or reservation executed")
