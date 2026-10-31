"""Unadmitted prototype: one evidence-bound historical declaration, no I/O writes."""
import hashlib
import re
from pathlib import Path


def resolve(report, raw, receipt_path, admitted, canonical, safe_path):
    """Caller must formally admit the receipt; hashes are not signatures."""
    if admitted.get(str(receipt_path)) != hashlib.sha256(receipt_path.read_bytes()).hexdigest():
        raise ValueError("unbound recovery receipt")
    import json
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate receipt key")
            result[key] = value
        return result
    item = json.loads(receipt_path.read_text(), object_pairs_hook=unique)
    if set(item) != {"report", "report_sha256", "raw_root", "run", "session", "attempt", "owner", "owner_observation", "owner_observation_sha256"}:
        raise ValueError("invalid receipt fields")
    if any(not isinstance(item[k], str) or not item[k] for k in item if k != "attempt") or type(item["attempt"]) is not int or item["attempt"] < 1:
        raise ValueError("invalid receipt types")
    owner = Path(item["owner"])
    canonical(str(owner))
    if not owner.is_dir() or str(owner.resolve(strict=True)) != item["owner"]:
        raise ValueError("noncanonical owner")
    safe_path(owner, report)
    if not report.is_file() or str(report) != item["report"] or hashlib.sha256(report.read_bytes()).hexdigest() != item["report_sha256"]:
        raise ValueError("changed report")
    text = report.read_text()
    expected = {r"^Run ID: (.+)$": item["run"], r"^Task Attempt Count: (.+)$": str(item["attempt"]), r"^- \*\*Session ID\*\*: (.+)$": item["session"], r"^- \*\*Scratch Root\*\*: (.+)$": raw}
    if any(re.findall(pattern, text, re.M) != [value] for pattern, value in expected.items()) or raw != item["raw_root"]:
        raise ValueError("identity or declaration mismatch")
    observation = Path(item["owner_observation"])
    safe_path(owner, observation)
    if not observation.is_file() or admitted.get(str(observation)) != item["owner_observation_sha256"] or hashlib.sha256(observation.read_bytes()).hexdigest() != item["owner_observation_sha256"]:
        raise ValueError("unbound owner observation")
    # Observation authenticity is an admission responsibility, not inferred from JSON.
    evidence = json.loads(observation.read_text(), object_pairs_hook=unique)
    if evidence != {"owner": item["owner"], "run": item["run"], "report_sha256": item["report_sha256"]}:
        raise ValueError("conflicting owner observation")
    relative = raw[:-1] if raw.endswith("/") else raw
    if not relative or relative.startswith("/") or any(p in ("", ".", "..") for p in relative.split("/")) or re.search(r"[\\\r\n:]", relative):
        raise ValueError("unsafe relative declaration")
    target = safe_path(owner, owner / relative)
    return canonical(str(target))
