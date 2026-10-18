"""Check the actual release audit and immutable tag against saved CI evidence."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

ROOT = Path(__file__).resolve().parents[5]
DIRECTORY = Path(__file__).resolve().parent


def read(name):
    return json.loads((DIRECTORY / name).read_text())


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True).strip()


publication = read("tag-publication.json")
revision = publication["revision"]
ci = read("ci-final.json")
local = read("local-full-validation.json")
assert ci["headSha"] == revision and ci["status"] == "completed"
assert ci["conclusion"] == "success"
assert local["revision"] == revision and local["status"] == "PASS"
assert len(local["records"]) == 8
assert git("rev-parse", publication["tag"] + "^{}") == revision
assert git("cat-file", "-t", publication["tag"]) == "tag"
remote = dict(line.split()[::-1] for line in git("ls-remote", "--tags", "origin").splitlines())
assert remote["refs/tags/" + publication["tag"] + "^{}"] == revision
assert remote["refs/tags/" + publication["tag"]] == publication["annotated_tag_object"]
assert all(remote.get(k) == v for k, v in read("tags-before.json").items())
assert read("tags-after.json")["refs/tags/" + publication["tag"] + "^{}"] == revision
baseline = json.loads((DIRECTORY.parent / "root-release-attempt-1/ci-final.json").read_text())
assert {job["name"] for job in ci["jobs"]} == {job["name"] for job in baseline["jobs"]}
for job in ci["jobs"]:
    assert job["status"] == "completed"
    expected = "skipped" if job["name"] == "capability-mode Gate" else "success"
    assert job["conclusion"] == expected, job["name"]
windows = read("native-windows-junction.json")
assert windows["revision"] == revision and windows["run_id"] == publication["run_id"]
assert windows["status"] == "PASS" and windows["native_windows_executed"] is True
evidence = (ROOT / windows["evidence"]).read_bytes()
assert hashlib.sha256(evidence).hexdigest() == windows["sha256"]
assert re.search(rb"test_windows_output_parent_junction_is_rejected \([^\n]+\) \.\.\. ok(?:\r?\n|$)", evidence)
audit = ROOT / "reports/verification/cloud-orchestration-release.md"
binding = read("release-audit-binding.json")
assert hashlib.sha256(audit.read_bytes()).hexdigest() == binding["sha256"]
assert all(value in audit.read_text() for value in (revision, publication["tag"], ci["url"], "BLOCKED", "NOT PUBLISHED"))
assert publication["release_assets"] == "not published"
assert publication["live_cloud_acceptance"].startswith("BLOCKED")
print(json.dumps({"status": "PASS", "revision": revision, "tag": publication["tag"], "ci_url": ci["url"], "audit_sha256": binding["sha256"]}))
