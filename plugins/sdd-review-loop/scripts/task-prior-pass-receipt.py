#!/usr/bin/env python3
"""Read-only, hash-bound historical task PASS receipt; never grants a verdict."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import stat
import sys


def require(condition, message):
    if not condition:
        raise ValueError(message)


def pairs(items):
    result = {}
    for key, value in items:
        require(key not in result, "duplicate JSON member")
        result[key] = value
    return result


def read(root, relative):
    path = Path(relative)
    require(not path.is_absolute() and path.as_posix() == relative and
            all(part not in (".", "..") for part in path.parts), "unsafe evidence path")
    current = root
    for part in path.parts:
        current = current / part
        require(not current.is_symlink(), "substituted evidence path")
    require(stat.S_ISREG(current.stat().st_mode), "evidence is not a file")
    return current.read_bytes()


def digest(data):
    return hashlib.sha256(data).hexdigest()


def document(root, path):
    raw = read(root, path)
    data = json.loads(raw, object_pairs_hook=pairs)
    require(type(data) is dict, "expected JSON object")
    return data, digest(raw)


def build(root, feature, attempt, source=None):
    require(re.fullmatch(r"[a-z0-9][a-z0-9-]*", feature), "invalid feature")
    require(type(attempt) is int and attempt > 0, "invalid attempt")
    prefix = f"reports/task-review/{feature}/"
    pattern = re.compile(re.escape(prefix) + r"attempt-([1-9][0-9]*)/round-([1-9][0-9]*)/task-review-contract.json")
    if source is None:
        candidates = []
        for path in (root / prefix).glob("attempt-*/round-*/integrated-verdict.json"):
            relative = path.relative_to(root).as_posix()
            contract_path = relative.replace("integrated-verdict.json", "task-review-contract.json")
            match = pattern.fullmatch(contract_path)
            if not match or int(match[1]) >= attempt:
                continue
            verdict, _ = document(root, relative)
            if verdict.get("verdict") == "PASS":
                candidates.append((int(match[1]), int(match[2]), contract_path))
        require(candidates, "missing earlier persisted PASS")
        source = max(candidates)[2]
    match = pattern.fullmatch(source)
    require(match is not None and int(match[1]) < attempt, "source must be an earlier same-feature attempt")
    contract, contract_hash = document(root, source)
    verdict_path = source.replace("task-review-contract.json", "integrated-verdict.json")
    verdict, verdict_hash = document(root, verdict_path)
    for data, schema in ((contract, "task-review-contract/v1"), (verdict, "integrated-verdict/v1")):
        require(data.get("schema") == schema and data.get("stage") == "task" and
                data.get("feature") == feature and data.get("verdict") == "PASS" and
                type(data.get("attempt")) is int and data["attempt"] == int(match[1]) and
                type(data.get("round")) is int and data["round"] == int(match[2]), "invalid prior PASS identity")
    require(isinstance(contract.get("run_id"), str) and bool(contract["run_id"]) and
            contract["run_id"] == verdict.get("run_id"), "contract/verdict run mismatch")
    for field in ("reviewer_a_verdict", "reviewer_b_verdict", "findings_critical", "findings_major", "findings_minor"):
        require(field in contract and field in verdict and contract[field] == verdict[field], "contract/verdict outcome mismatch")
    require(contract["reviewer_a_verdict"] == "PASS" and contract["reviewer_b_verdict"] == "PASS" and
            all(type(contract[f]) is int and contract[f] == 0 and
                type(verdict[f]) is int and verdict[f] == 0 for f in
                ("findings_critical", "findings_major", "findings_minor")), "receipt requires clean prior PASS")
    reviewers = contract.get("reviewers")
    require(type(reviewers) is list and len(reviewers) == 2 and
            [r.get("role") for r in reviewers] == ["task-reviewer-a", "task-reviewer-b"], "invalid prior reviewer roles")
    manifests = []
    for reviewer in reviewers:
        rows = reviewer.get("allowed_input_manifest")
        require(type(rows) is list, "missing prior input manifest")
        manifest = {}
        for row in rows:
            path, sha = row.get("path"), row.get("sha256")
            require(isinstance(path, str) and path not in manifest and
                    isinstance(sha, str) and re.fullmatch(r"[0-9a-f]{64}", sha), "invalid prior input manifest")
            manifest[path] = sha
        manifests.append(manifest)
    spec = f"specs/{feature}/"
    fields = {"tasks.md": "tasks_sha256", "requirements.md": "requirements_sha256",
              "acceptance-tests.md": "acceptance_sha256", "design.md": "design_sha256",
              "traceability.md": "traceability_sha256"}
    wanted = {spec + name: contract.get(field) for name, field in fields.items()}
    layers = contract.get("layer_sha256")
    names = ["frontend-spec.md", "infra-spec.md", "security-spec.md", "ux-spec.md"]
    require(type(layers) is dict and sorted(layers) == names, "receipt requires complete prior layer binding")
    wanted.update({spec + name: layers[name] for name in names})
    calibration = "plugins/sdd-review-loop/references/reviewer-calibration.md"
    wanted[calibration] = manifests[0].get(calibration)
    for path in ("plugins/sdd-quality-loop/references/risk-gate-matrix.md",
                 "plugins/sdd-quality-loop/references/risk-classification-policy.md"):
        wanted[path] = manifests[1].get(path)
    form = contract.get("tasks_sha256_form", "raw")
    # No guessing which undocumented legacy normalization generated a digest.
    require(form == "raw", "prior receipt currently requires raw task binding")
    bindings = []
    for path, expected in sorted(wanted.items()):
        relevant = manifests[1:] if "/risk-" in path else manifests
        require(isinstance(expected, str) and re.fullmatch(r"[0-9a-f]{64}", expected) and
                all(m.get(path) == expected for m in relevant), "prior field/manifest mismatch")
        current = digest(read(root, path))
        bindings.append({"path": path, "prior_sha256": expected, "current_sha256": current,
                         "unchanged": expected == current})
    return {"schema": "task-prior-pass-receipt/v1", "feature": feature, "attempt": attempt,
            "source_attempt": int(match[1]), "source_round": int(match[2]),
            "contract": {"path": source, "sha256": contract_hash},
            "verdict": {"path": verdict_path, "sha256": verdict_hash},
            "tasks_sha256_form": form, "bindings": bindings,
            "all_inputs_unchanged": all(row["unchanged"] for row in bindings)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--feature", required=True)
    parser.add_argument("--attempt", type=int, required=True)
    parser.add_argument("--verify", help="repository-relative current precheck")
    args = parser.parse_args()
    root = args.root.resolve()
    if args.verify:
        data, _ = document(root, args.verify)
        if "provenance_rereview" not in data and "prior_pass_receipt" not in data:
            return  # Legacy prechecks carry no convergence evidence.
        require(type(data.get("provenance_rereview")) is bool, "invalid provenance flag")
        receipt = data.get("prior_pass_receipt")
        if not data["provenance_rereview"]:
            require(receipt is None, "ordinary review cannot carry a prior receipt")
            return
        require(type(receipt) is dict and type(receipt.get("contract")) is dict,
                "missing prior-PASS receipt")
        expected = build(root, args.feature, args.attempt, receipt["contract"].get("path"))
        require(expected["all_inputs_unchanged"],
                "prior-PASS receipt inputs changed")
        require(json.dumps(receipt, sort_keys=True) == json.dumps(expected, sort_keys=True),
                "prior-PASS receipt changed or stale")
    else:
        print(json.dumps(build(root, args.feature, args.attempt), separators=(",", ":")))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError) as error:
        print(f"task prior-PASS receipt: {error}", file=sys.stderr)
        sys.exit(1)
