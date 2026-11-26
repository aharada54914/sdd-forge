"""Exercise the deployed pre-upload helper and selected native scanner offline."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


runtime, case = sys.argv[1:]
root = Path(__file__).resolve().parents[3]
scripts = root / "plugins/sdd-bootstrap/scripts"
skill = (scripts.parent / "skills/design-sync-loop/SKILL.md").read_text(encoding="utf-8")
assert "アップロード直前とモックアップの再生成後は毎回" in skill
assert "scripts/design-sync-override.py sh <送信予定ディレクトリ>" in skill
assert "PowerShell では `sh` を `ps1` に替える" in skill
assert "upload_directory" in skill and "latest_override" in skill

with tempfile.TemporaryDirectory() as work:
    work = Path(work)
    helper = work / "design-sync-override.py"
    scanner = work / ("design-sync-scan." + runtime)
    for artifact in (helper, scanner):
        shutil.copy2(scripts / artifact.name, artifact)
    payload = work / "send"
    payload.mkdir()
    page = payload / "page.html"
    markup = b"<p>+1202" + b"5550100</p>\n<p>NEW_MARKER</p>\n"
    page.write_bytes(markup)
    attachment = payload / "theme.css"
    attachment.write_bytes(b"a{}")
    scope = dict(feature="account", session="session-A", service="claude.ai/design", destination_id="project-A")

    def run(expected, previous=None, **changes):
        request = dict(scope, latest_override=previous)
        request.update(changes)
        p = subprocess.run([sys.executable, str(helper), runtime, str(payload)], capture_output=True,
                           text=True, input=json.dumps(request), timeout=30)
        assert p.returncode == {"review": 1, "reuse": 0, "clean": 0, "error": 2}[expected], (p.returncode, p.stdout, p.stderr)
        if expected == "error":
            assert not p.stdout
            return None
        result = json.loads(p.stdout)
        assert result["action"] == expected, result
        if expected == "review":
            assert "upload_directory" not in result
        else:
            stage = Path(result["upload_directory"])
            try:
                assert stage.resolve() != payload.resolve()
                def contents(directory):
                    return {p.relative_to(directory): p.read_bytes() for p in directory.rglob("*") if p.is_file()}
                assert contents(stage) == contents(payload)
            finally:
                shutil.rmtree(stage)
        return result

    first = run("review")
    identity = first["identity"]
    grant = dict(decision="granted", party="reviewer", identity=identity)
    if case == "TEST-037":
        consent = {
            "schema": "design-sync-request/v1", "operation": "upload", "ui_app": True,
            "ds_profile": "custom", "capability_resolved": True, "provider_available": True,
            "egress_permitted": True, "feature": scope["feature"], "session": scope["session"],
            "destination": scope["service"] + "/" + scope["destination_id"], "records": [],
        }

        def resolve(**fields):
            response = subprocess.run([sys.executable, str(scripts / "resolve-design-sync.py")],
                                      input=json.dumps(dict(consent, **fields)), text=True,
                                      check=True, capture_output=True)
            return json.loads(response.stdout)

        assert resolve(latest_override=grant)["action"] == "prompt"
        assert resolve(setting="off", latest_override=grant)["action"] == "manual"
        egress = resolve(response="grant", party="reviewer")
        assert egress["action"] == "proceed" and egress["audit"]["decision"] == "granted"
        run("review", egress["audit"])
        for previous in ({"decision": "declined", "identity": identity, "party": "reviewer"},
                         {"decision": "withdrawn", "identity": identity, "party": "reviewer"},
                         dict(grant, decision="unknown"), dict(grant, valid=False), dict(grant, party=""), {"decision": "granted"}):
            run("review", previous)
        run("review", grant, feature="other")
        run("review", grant, session="other")
        run("error", grant, destination_id="")
        page.write_bytes(b"<p>clean</p>")
        run("clean", grant)
        page.write_bytes(markup)
        scanner.unlink()
        run("error", grant)
    elif case == "TEST-038":
        # A regeneration with identical bytes needs a new scan, and can reuse this grant.
        contents = page.read_bytes()
        page.unlink()
        page.write_bytes(contents)
        assert run("reuse", grant)["identity"] == identity
        for axis, value in (("service", "another-service"), ("destination_id", "project-B")):
            changed = run("review", grant, **{axis: value})["identity"]
            assert {k for k in changed if changed[k] != identity[k]} == {axis}
        page.write_bytes(contents.replace(b"0100", b"0101"))
        changed = run("review", grant)
        assert changed["findings"] == first["findings"]
        assert changed["identity"]["payload_sha256"] != identity["payload_sha256"]
        page.write_bytes(contents)
        attachment.rename(payload / "renamed.css")
        changed = run("review", grant)["identity"]
        assert {k for k in changed if changed[k] != identity[k]} == {"payload_sha256"}
        (payload / "renamed.css").rename(attachment)
        # A changed detector produces additional real findings on the exact original upload.
        data = scanner.read_bytes()
        old = b"".join((b"TO", b"DO|FI", b"XME|"))
        assert data.count(old) == 1
        scanner.write_bytes(data.replace(old, b"NEW_MARKER|" + old))
        changed = run("review", grant)
        assert {k for k in identity if changed["identity"][k] != identity[k]} == {"findings_sha256"}
        assert len(changed["findings"]) > len(first["findings"])
    else:
        raise ValueError(case)
print(case, runtime, "verified")
