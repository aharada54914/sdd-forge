"""Read-only recheck of the evaluator input bytes and delivery binding."""
import hashlib, json, pathlib
root = pathlib.Path(__file__).resolve().parents[5]
run = "c3d9b63a-ad5e-4e90-bc50-5d0d387c7a4f"
delivery = root / ("specs/shared-review-launch-repair/verification/T-004/delivery-" + run)
launch = root / ("reports/quality-gate/launch-" + run)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
inv = json.loads((delivery / "invocation.json").read_text())
assert sha(delivery / "invocation.json") == "d890705ac6f4731e28a6733c25aca12d4a969759b2c66b427901d63e34f940ca"
for item in inv["allowed_input_manifest"]:
    assert sha(root / item["path"]) == item["sha256"], item["path"]
proof = json.loads((launch / "delivery.json").read_text())
assert proof["status"] == "DELIVERY_OK"
wrapper = json.loads((launch / "wrapper.json").read_text())
assert wrapper["session_id"] == run and wrapper["is_error"] is False
assert "VERDICT: PASS" in wrapper["result"]
for key, name in [("prompt_sha256","prompt.txt"),("wrapper_sha256","wrapper.json"),("transcript_sha256",run+".jsonl")]:
    assert sha(launch / name) == proof[key], name
print(json.dumps({"run_id":run,"inputs_verified":len(inv["allowed_input_manifest"]),"manifest_sha256":sha(delivery/"invocation.json"),"delivery":"DELIVERY_OK","verdict":"PASS","critical":0,"major":0,"minor":4,"wrapper_sha256":sha(launch/"wrapper.json")},indent=2))

