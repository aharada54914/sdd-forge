"""One synthetic closed-record fixture; all generated files stay in a caller temp root."""
import hashlib
import copy
import json
import re
import subprocess
import shutil
from pathlib import Path

FEATURE = "epic-197-a9-dogfood"
SOURCE = f"reports/spec-review/{FEATURE}/attempt-3/round-3"
PREVIOUS = f"reports/spec-review/{FEATURE}/attempt-3/round-2"
INVOCATION = f"reports/review-context/{FEATURE}-spec-a3r3-a-invocation.json"
RECORD = "reports/verification/a9-fixture-recovery.json"
AUTH = "reports/verification/a9-fixture-authorization.md"
CALIBRATION = "plugins/sdd-review-loop/references/spec-review-calibration.md"
LEDGER = "reports/review-context/identity-ledger.json"
AUTH_LINES = ("Feature", "Source Attempt", "Source Round", "Target Attempt",
              "Target Round", "Maximum Rounds", "Decision", "Recovery Binding SHA256")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def bash_functions(source):
    # These originals close each top-level function on an unindented brace.
    return "\n".join(re.findall(r"(?ms)^[a-zA-Z_][a-zA-Z_0-9]*\(\) \{(?:[^\n]*\}$|\n.*?^\})", source))


def at(value, path):
    for key in path:
        value = value[key]
    return value


def leaves(value, path=()):
    if isinstance(value, (dict, list)):
        for key, child in (value.items() if isinstance(value, dict) else enumerate(value)):
            yield from leaves(child, path + (key,))
    else:
        yield path, value


def references(record):
    paths = [(name,) for name in ("authorization", "previous_contract", "interrupted_precheck")]
    # Acceptance P/H numbers follow canonical roles, not sorted array position.
    for group, expected in (
        ("pinned_inputs", [f"specs/{FEATURE}/{name}" for name in
                           ("requirements.md", "acceptance-tests.md", "investigation.md")] + [CALIBRATION]),
        ("interrupted_artifacts", [f"{SOURCE}/{name}" for name in
                                  ("precheck-result.json", "reviewer-a.json", "reviewer-a-reservation.txt",
                                   "reviewer-a-host-receipt.json", "spec-review-report.md")] + [INVOCATION])):
        paths += [(group, next(index for index, ref in enumerate(record[group]) if ref["path"] == path))
                  for path in expected]
    return paths + [("reviewer_a", "invocation")]


def mutations(root, record):
    """Named finite contract cases; payloads contain no live evidence."""
    cases = []

    def add(name, kind, path, value=None):
        cases.append((name, kind, tuple(path), value))

    def label(path):
        return ".".join(map(str, path)) or "root"

    def closed(value, path=()):
        if isinstance(value, dict):
            for key, child in value.items():
                slot = path + (key,)
                add("TEST-050:" + label(slot), "delete", slot)
                variants = [None]
                if isinstance(child, int):
                    variants += [str(child), True, child + 0.5]
                elif isinstance(child, list):
                    variants += [{}]
                elif isinstance(child, dict):
                    variants += [[]]
                for index, wrong in enumerate(variants):
                    add(f"TEST-051:{label(slot)}:{index}", "set", slot, wrong)
                closed(child, slot)
            key = next(iter(value))
            add("TEST-052:" + label(path), "set", path + ("unexpected",), True)
            add("TEST-053:" + label(path) + ":literal", "duplicate", path, key)
            add("TEST-053:" + label(path) + ":escaped", "escaped-duplicate", path, key)
            add("TEST-055:" + label(path), "miscase", path + (key,))
        elif isinstance(value, list):
            for index, child in enumerate(value):
                closed(child, path + (index,))

    closed(record)
    for index, path in enumerate(references(record), 1):
        for name, value in (("empty", ""), ("absolute", "/fixture"), ("traversal", "../fixture"),
                            ("backslash", "reports\\fixture"), ("control", "reports/fi\txture")):
            add(f"TEST-083-P{index:02}:{name}", "set", path + ("path",), value)
        for name, value in (("null", None), ("uppercase", "A" * 64), ("nonhex", "g" * 64),
                            ("short", "0" * 63), ("incorrect", "0" * 64)):
            add(f"TEST-057-H{index:02}:{name}", "set", path + ("sha256",), value)
        add(f"TEST-057-H{index:02}:missing", "delete", path + ("sha256",))
        # Same bytes at the wrong canonical path must also reject.
        add(f"canonical-ref-P{index:02}", "copy-ref", path)
    for index, field in enumerate(AUTH_LINES, 1):
        for variant in ("remove", "duplicate", "change"):
            add(f"TEST-050-A{index:02}:{variant}", "authorization", (field,), variant)
    for name, path, wrong in (
        ("044", ("schema",), "wrong/v1"), ("054", ("schema",), "SPEC-review-interrupted-recovery/v1"),
        ("045", ("feature",), "other-feature"), ("046", ("source", "attempt"), 2),
        ("047", ("source", "round"), 2), ("048", ("target", "attempt"), 5),
        ("049", ("target", "round"), 2)):
        add("TEST-" + name, "set", path, wrong)
    add("TEST-056", "malformed", ())
    requirements = f"specs/{FEATURE}/requirements.md"
    for number, value in ((12, "Passed"), (13, ""), (14, "Unknown"), (15, "pending")):
        add(f"TEST-{number:03}", "status", (requirements,), value)
    for index, ref in enumerate(record["pinned_inputs"], 58):
        add(f"TEST-{index:03}", "alter-file", (ref["path"],))
    file_cases = ((62, "precheck-result.json"), (63, "reviewer-a.json"),
                  (64, "reviewer-a-host-receipt.json"), (65, "reviewer-a-reservation.txt"),
                  (66, None), (67, "spec-review-report.md"))
    for number, name in file_cases:
        path = INVOCATION if name is None else f"{SOURCE}/{name}"
        for variant in ("missing-file", "alter-file"):
            add(f"TEST-{number:03}:{variant}", variant, (path,))
    for variant in ("missing", "extra", "duplicate"):
        add("TEST-068:" + variant, "inventory", (), variant)
    for number, key, wrong in ((69, "sequence", 99), (70, "run_id", "other-run"),
                              (71, "host_session_id", "other-session"), (72, "stage", "task"),
                              (73, "role", "spec-reviewer-b"), (74, "record_sha256", "0" * 64)):
        add(f"TEST-{number:03}", "set", ("reviewer_a", key), wrong)
    for key in ("previous_record_sha256", "allowed_inputs_sha256", "record_sha256", "run_id", "host_session_id"):
        add("identity-ledger:" + key, "file-set", (LEDGER, "records", 1, key), "0" * 64)
    add("TEST-075:prefix", "file-set", (LEDGER, "records", 0, "record_sha256"), "0" * 64)
    add("TEST-077", "duplicate-identity", ())
    for key in ("run_id", "host_session_id"):
        add("TEST-078:" + key, "collision", (), key)
    for path, value in leaves(json.loads((root / INVOCATION).read_text())):
        add("identity-invocation:" + label(path), "file-set", (INVOCATION,) + path, None)
    for key in ("requirements_sha256", "acceptance_sha256", "investigation_sha256", "calibration_sha256", "input_sha256"):
        add("source-precheck:" + key, "file-set", (f"{SOURCE}/precheck-result.json", key), "0" * 64)
    for key in ("schema", "stage", "feature", "attempt", "round", "spec_review_status_field"):
        add("source-precheck:" + key, "file-set", (f"{SOURCE}/precheck-result.json", key), None)
    for number, name in ((26, "reviewer-b-reservation.txt"), (27, "reviewer-b.json"),
                          (28, "reviewer-b-host-receipt.json"), (29, "integrated-summary.json"),
                          (30, "integrated-verdict.json"), (31, "spec-review-contract.json")):
        add(f"TEST-{number:03}", "extra-file", (f"{SOURCE}/{name}",))
    add("TEST-024", "b-invocation", ())
    add("TEST-025", "b-ledger", ())
    add("TEST-080", "ambiguous-ledger", ())
    add("TEST-033", "file-set", (f"{SOURCE}/reviewer-a-host-receipt.json", "review_execution_started"), True)
    add("TEST-034", "file-set", (f"{SOURCE}/reviewer-a.json", "verdict"), "PASS")
    for path in (f"{PREVIOUS}/spec-review-contract.json", f"{PREVIOUS}/integrated-summary.json"):
        add("prior-missing:" + Path(path).name, "missing-file", (path,))
    for filename in ("spec-review-contract.json", "reviewer-a.json", "reviewer-b.json",
                     "integrated-summary.json", "integrated-verdict.json"):
        path = f"{PREVIOUS}/{filename}"
        # Null each persisted leaf, including every manifest/check/count/identity.
        for leaf, value in leaves(json.loads((root / path).read_text())):
            add("full-prior:" + filename + ":" + label(leaf), "file-set", (path,) + leaf, None)
    add("TEST-017", "malformed-file", (f"{PREVIOUS}/spec-review-contract.json",))
    for number, value in ((18, "PASS"), (19, "BLOCKED")):
        add(f"TEST-{number:03}", "file-set", (f"{PREVIOUS}/spec-review-contract.json", "verdict"), value)
    assert len({case[0] for case in cases}) == len(cases)
    return cases


def remaining_cases():
    cases = [("TEST-079:later-valid", "later-valid", (), None),
             ("TEST-008:actual-source-not-latest", "source-not-latest", (), None),
             ("TEST-032:complete-NEEDS_WORK", "completed-source", (), None),
             ("TEST-035:missing-authorization", "missing-file", (AUTH,), None),
             ("TEST-082:isolated-composite", "composite", (), None)]
    for token in ("REVIEW_CONTEXT_OK", "record_sha256", "sequence", "previous_record_sha256",
                  "pre_append_tip_sequence", "identity_unique"):
        for variant in ("remove", "change", "duplicate"):
            cases.append((f"TEST-065:receipt:{token}:{variant}", "receipt", (token,), variant))
    for index in range(7):
        cases.append((f"TEST-034:raw-finding:{index}", "file-set",
                      (f"{SOURCE}/reviewer-a.json", "checks", index, "finding"), "Completed substantive review; no issues found."))
    for variant in ("launch-failure", "b-not-launched", "integrated-result"):
        cases.append(("TEST-067:diagnostic:" + variant, "diagnostic", (), variant))
    for variant, value in (("null", None), ("uppercase", "A" * 64), ("nonhex", "g" * 64),
                           ("short", "0" * 63), ("incorrect", "0" * 64)):
        cases.append(("TEST-074:record-hash:" + variant, "set", ("reviewer_a", "record_sha256"), value))
    cases.append(("TEST-074:record-hash:missing", "delete", ("reviewer_a", "record_sha256"), None))
    return cases


def complete_contract(root, original, directory):
    helper = re.search(r"(?ms)^write_contract\(\) \{.*?^\}",
                       (original / "tests/spec-review-loop.tests.sh").read_text()).group()
    subprocess.run(["bash", "-c", "set -euo pipefail\n" + helper + '\nROOT=$1; FEATURE=$2; SPEC_DIR="$ROOT/specs/$FEATURE"\nwrite_contract "$ROOT/$3" NEEDS_WORK Major',
                    "fixture", str(root), FEATURE, directory], check=True, capture_output=True)


def rebind_source(root, record):
    """Keep all siblings coherent when only source semantics are under test."""
    precheck = record["interrupted_precheck"]["path"]
    invocation_path = record["reviewer_a"]["invocation"]["path"]
    invocation = json.loads((root / invocation_path).read_text())
    inputs = sorted(record["pinned_inputs"] + [{"path": precheck, "sha256": digest((root / precheck).read_bytes())}], key=lambda item: item["path"])
    invocation["allowed_input_manifest"] = inputs
    ledger = json.loads((root / LEDGER).read_text())
    identity = ledger["records"][1]
    identity["allowed_inputs_sha256"] = digest("\n".join(f'{item["path"]}\t{item["sha256"]}' for item in inputs).encode())
    raw_path = str(Path(precheck).parent / "reviewer-a.json")
    raw = json.loads((root / raw_path).read_text())
    for field in ("run_id", "host_session_id"):
        identity[field] = invocation[field] = record["reviewer_a"][field] = raw[field]
    identity["record_sha256"] = digest((f'2|spec|spec-reviewer-a|{identity["run_id"]}|{identity["host_session_id"]}|{identity["previous_record_sha256"]}|allowed-inputs-v1|{identity["allowed_inputs_sha256"]}').encode())
    record["reviewer_a"]["record_sha256"] = identity["record_sha256"]
    raw["allowed_input_manifest"] = inputs
    (root / raw_path).write_bytes(canonical(raw) + b"\n")
    (root / invocation_path).write_bytes(canonical(invocation) + b"\n")
    (root / LEDGER).write_bytes(canonical(ledger) + b"\n")
    receipt = Path(precheck).parent / "reviewer-a-reservation.txt"
    (root / receipt).write_text(f'REVIEW_CONTEXT_OK {identity["record_sha256"]} sequence=2 previous_record_sha256={identity["previous_record_sha256"]} pre_append_tip_sequence=1 identity_unique=yes\n')


def write_mutation(root, original_record, case):
    """Change the named input only; rebind outer hashes to reach semantic checks."""
    record = copy.deepcopy(original_record)
    reference_slots = references(record)
    _, kind, path, value = case
    raw_override = None
    if kind in ("set", "delete", "miscase"):
        parent = at(record, path[:-1])
        if kind == "set":
            parent[path[-1]] = value
        elif kind == "delete":
            del parent[path[-1]]
        else:
            parent[str(path[-1]).upper()] = parent.pop(path[-1])
    elif kind in ("duplicate", "escaped-duplicate"):
        def encode(obj, current=()):
            if isinstance(obj, dict):
                pairs = [(json.dumps(key), encode(child, current + (key,))) for key, child in sorted(obj.items())]
                if current == path:
                    key = json.dumps(value) if kind == "duplicate" else '"\\u%04x%s"' % (ord(value[0]), value[1:])
                    pairs.append((key, encode(obj[value], current + (value,))))
                return "{" + ",".join(key + ":" + child for key, child in pairs) + "}"
            if isinstance(obj, list):
                return "[" + ",".join(encode(child, current + (index,)) for index, child in enumerate(obj)) + "]"
            return canonical(obj).decode()
        raw_override = encode(record).encode()
    elif kind == "malformed":
        raw_override = b"{"
    elif kind == "copy-ref":
        ref = at(record, path)
        destination = "reports/verification/alternate-" + str(references(record).index(path))
        (root / destination).write_bytes((root / ref["path"]).read_bytes())
        ref["path"] = destination
    elif kind in ("missing-file", "alter-file", "extra-file", "malformed-file", "status", "file-set"):
        target = root / path[0]
        if kind == "missing-file":
            target.unlink()
        elif kind == "file-set":
            obj = json.loads(target.read_text())
            at(obj, path[1:-1])[path[-1]] = value
            target.write_bytes(canonical(obj) + b"\n")
        elif kind == "status":
            target.write_text("# Synthetic requirements\n" + (f"Spec-Review-Status: {value}\n" if value else ""))
        else:
            target.write_bytes(b"{" if kind == "malformed-file" else target.read_bytes() + b"\nchanged\n" if target.exists() else b"extra\n")
    elif kind == "inventory":
        items = record["interrupted_artifacts"]
        if value == "missing":
            items.pop()
        elif value == "duplicate":
            items.append(copy.deepcopy(items[0]))
        else:
            items.append(copy.deepcopy(record["authorization"]))
    elif kind in ("duplicate-identity", "collision", "b-ledger", "ambiguous-ledger", "later-valid"):
        ledger = json.loads((root / LEDGER).read_text())
        item = copy.deepcopy(ledger["records"][-1])
        if kind != "duplicate-identity":
            item.update(sequence=3, previous_record_sha256=item["record_sha256"])
            item["run_id"] = "later-run"
            item["host_session_id"] = "later-session"
            if kind == "collision":
                item[value] = ledger["records"][-1][value]
            if kind == "b-ledger":
                item["role"] = "spec-reviewer-b"
            if kind == "ambiguous-ledger":
                item.pop("allowed_inputs_sha256")
            suffix = "|allowed-inputs-v1|" + item["allowed_inputs_sha256"] if "allowed_inputs_sha256" in item else ""
            item["record_sha256"] = digest((f'3|spec|{item["role"]}|{item["run_id"]}|{item["host_session_id"]}|{item["previous_record_sha256"]}' + suffix).encode())
        ledger["records"].append(item)
        (root / LEDGER).write_bytes(canonical(ledger) + b"\n")
    elif kind == "b-invocation":
        obj = json.loads((root / INVOCATION).read_text())
        obj.update(role="spec-reviewer-b", run_id="source-b", host_session_id="source-b-session")
        (root / INVOCATION.replace("-a-invocation", "-b-invocation")).write_bytes(canonical(obj) + b"\n")
    elif kind == "receipt":
        target = root / SOURCE / "reviewer-a-reservation.txt"
        tokens = target.read_text().split()
        index = {"REVIEW_CONTEXT_OK": 0, "record_sha256": 1, "sequence": 2,
                 "previous_record_sha256": 3, "pre_append_tip_sequence": 4, "identity_unique": 5}[path[0]]
        if value == "remove":
            tokens.pop(index)
        elif value == "duplicate":
            tokens.append(tokens[index])
        else:
            tokens[index] = "INVALID" if index < 2 else tokens[index].split("=", 1)[0] + "=incorrect"
        target.write_text(" ".join(tokens) + "\n")
    elif kind == "diagnostic":
        target = root / SOURCE / "spec-review-report.md"
        text = target.read_text()
        if value == "launch-failure":
            text = text.replace("Reviewer A launch failure: unreadable input.", "Reviewer A completed substantive review.")
        elif value == "b-not-launched":
            text = text.replace("Reviewer B was not launched.", "Reviewer B was launched.")
        else:
            text += "Final integrated verdict: NEEDS_WORK\n"
        target.write_text(text)
    elif kind == "composite":
        target = root / SOURCE / "precheck-result.json"
        obj = json.loads(target.read_text())
        obj["input_sha256"] = "0" * 64
        target.write_bytes(canonical(obj) + b"\n")
        rebind_source(root, record)
    elif kind in ("source-not-latest", "completed-source"):
        earlier = SOURCE.replace("round-3", "round-2")
        preceding = PREVIOUS.replace("round-2", "round-1")
        shutil.copytree(root / PREVIOUS, root / preceding)
        obj = json.loads((root / preceding / "precheck-result.json").read_text())
        obj["round"] = 1
        (root / preceding / "precheck-result.json").write_bytes(canonical(obj) + b"\n")
        complete_contract(root, Path(__file__).resolve().parents[1], preceding)
        shutil.rmtree(root / earlier)  # synthetic owned fixture only
        shutil.copytree(root / SOURCE, root / earlier)
        obj = json.loads((root / earlier / "precheck-result.json").read_text())
        obj["round"] = 2
        (root / earlier / "precheck-result.json").write_bytes(canonical(obj) + b"\n")
        earlier_invocation = INVOCATION.replace("a3r3", "a3r2")
        shutil.copyfile(root / INVOCATION, root / earlier_invocation)
        for slot in reference_slots:
            ref = at(record, slot)
            ref["path"] = ref["path"].replace(PREVIOUS, preceding).replace(SOURCE, earlier).replace(INVOCATION, earlier_invocation)
        record["source"]["round"] = 2
        if kind == "completed-source":
            shutil.rmtree(root / SOURCE)  # synthetic owned fixture only
            (root / INVOCATION).unlink()
            complete_contract(root, Path(__file__).resolve().parents[1], earlier)
        rebind_source(root, record)
        if kind == "completed-source":
            receipt = root / earlier / "reviewer-a-host-receipt.json"
            obj = json.loads(receipt.read_text())
            obj.update(threadId="session-a", sessionId="session-a", review_execution_started=True)
            receipt.write_bytes(canonical(obj) + b"\n")
            (root / earlier / "spec-review-report.md").write_text("# Synthetic completed review\nAttempt: 3\nRound: 2\nFinal integrated verdict: NEEDS_WORK\n")
    elif kind != "authorization":
        raise AssertionError(kind)
    # Rebind changed evidence bytes; direct reference/hash mutations remain untouched.
    if kind not in ("set", "delete", "miscase", "duplicate", "escaped-duplicate", "malformed", "copy-ref", "inventory"):
        for slot in reference_slots:
            ref = at(record, slot)
            if ref["path"] != AUTH and (root / ref["path"]).is_file():
                ref["sha256"] = digest((root / ref["path"]).read_bytes())
    # Missing authorization is a real absent file, never recreated by rebinding.
    if kind == "missing-file" and path == (AUTH,):
        (root / RECORD).write_bytes(canonical(record) + b"\n")
        return
    auth = (root / AUTH).read_text().splitlines()
    binding = digest(canonical({key: child for key, child in record.items() if key != "authorization"}))
    auth = ["Recovery Binding SHA256: " + binding if line.startswith("Recovery Binding SHA256: ") else line for line in auth]
    if kind in ("source-not-latest", "completed-source"):
        auth = ["Source Round: 2" if line.startswith("Source Round: ") else line for line in auth]
    if kind == "authorization":
        selected = next(line for line in auth if line.startswith(path[0] + ": "))
        if value == "remove":
            auth.remove(selected)
        elif value == "duplicate":
            auth.append(selected)
        else:
            auth[auth.index(selected)] = path[0] + ": incorrect"
    (root / AUTH).write_text("\n".join(auth) + "\n")
    if kind not in ("set", "delete", "miscase", "duplicate", "escaped-duplicate", "malformed", "copy-ref") or not path or path[0] != "authorization":
        record["authorization"]["sha256"] = digest((root / AUTH).read_bytes())
    (root / RECORD).write_bytes((raw_override if raw_override is not None else canonical(record)) + b"\n")


def snapshot(root):
    return {str(path.relative_to(root)): digest(path.read_bytes()) for path in sorted(root.rglob("*")) if path.is_file()}


def build(root, original):
    root, original = Path(root), Path(original)
    assert root.is_dir() and not any(root.iterdir()), "fixture root must be empty"

    def put(path, data):
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data if isinstance(data, bytes) else data.encode())

    def put_json(path, value):
        put(path, canonical(value) + b"\n")

    def ref(path):
        return {"path": path, "sha256": digest((root / path).read_bytes())}

    spec = f"specs/{FEATURE}"
    put(f"{spec}/requirements.md", "# Synthetic requirements\nSpec-Review-Status: Pending\n")
    put(f"{spec}/acceptance-tests.md", "# Synthetic acceptance tests\nAC-001: observed fixture only.\n")
    put(f"{spec}/investigation.md", "# Synthetic investigation\nNo live recovery evidence.\n")
    put(CALIBRATION, (original / CALIBRATION).read_bytes())
    pins = sorted([ref(f"{spec}/{name}") for name in (
        "requirements.md", "acceptance-tests.md", "investigation.md")]+[ref(CALIBRATION)], key=lambda item: item["path"])
    hashes = {item["path"].split("/")[-1]: item["sha256"] for item in pins}

    def precheck(round_number):
        return {"schema": "spec-review-precheck/v1", "stage": "spec", "feature": FEATURE,
                "attempt": 3, "round": round_number, "spec_review_status_field": "Pending",
                "requirements_sha256": hashes["requirements.md"],
                "acceptance_sha256": hashes["acceptance-tests.md"],
                "investigation_sha256": hashes["investigation.md"],
                "calibration_sha256": hashes["spec-review-calibration.md"],
                "input_sha256": digest(":".join(hashes[name] for name in (
                    "requirements.md", "acceptance-tests.md", "investigation.md")).encode()),
                "edit_summary": "Synthetic fixture", "reset": False,
                "generated_at": "2026-09-29T00:00:00Z"}

    put_json(f"{PREVIOUS}/precheck-result.json", precheck(2))
    # Reuse the existing complete-round builder without executing its registry writes.
    helper_source = (original / "tests/spec-review-loop.tests.sh").read_text()
    helper = re.search(r"(?ms)^write_contract\(\) \{.*?^\}", helper_source).group()
    subprocess.run(["bash", "-c", "set -euo pipefail\n" + helper + '\nROOT=$1; FEATURE=$2; SPEC_DIR="$ROOT/specs/$FEATURE"\nwrite_contract "$ROOT/$3" NEEDS_WORK Major',
                    "fixture", str(root), FEATURE, PREVIOUS], check=True, capture_output=True)
    put_json(f"{SOURCE}/precheck-result.json", precheck(3))
    inputs = sorted(pins + [ref(f"{SOURCE}/precheck-result.json")], key=lambda item: item["path"])
    input_binding = digest("\n".join(f'{item["path"]}\t{item["sha256"]}' for item in inputs).encode())
    genesis_hash = digest(b"1|spec|spec-reviewer-a|fixture-a9-genesis|fixture-a9-genesis-session|")
    genesis = {"sequence": 1, "stage": "spec", "role": "spec-reviewer-a",
               "run_id": "fixture-a9-genesis", "host_session_id": "fixture-a9-genesis-session",
               "previous_record_sha256": "", "record_sha256": genesis_hash}
    ledger_path = "reports/review-context/identity-ledger.json"
    put_json(ledger_path, {"schema": "review-identity-ledger/v1", "records": [genesis]})
    historical_ledger_hash = ref(ledger_path)["sha256"]
    run, session = "fixture-a9-source-a", "fixture-a9-source-session-a"
    record_hash = digest(f"2|spec|spec-reviewer-a|{run}|{session}|{genesis_hash}|allowed-inputs-v1|{input_binding}".encode())
    identity = {"sequence": 2, "stage": "spec", "role": "spec-reviewer-a", "run_id": run,
                "host_session_id": session, "previous_record_sha256": genesis_hash,
                "record_sha256": record_hash, "allowed_inputs_sha256": input_binding}
    put_json(ledger_path, {"schema": "review-identity-ledger/v1", "records": [genesis, identity]})
    invocation = {"schema": "review-context-invocation/v2", "stage": "spec", "role": "spec-reviewer-a",
                  "feature": FEATURE, "run_id": run, "host_session_id": session, "read_only": True,
                  "input_mode": "file-manifest", "fallback_mode": "none", "sequence": 2,
                  "identity_ledger_path": ledger_path, "identity_ledger_sha256": historical_ledger_hash,
                  "previous_record_sha256": genesis_hash, "allowed_input_manifest": inputs}
    put_json(INVOCATION, invocation)
    a_ids = ["REQ-TESTABILITY", "GOAL-AC-TRACE", "AC-OBSERVABLE", "SCOPE-BOUNDARY",
             "CONSTRAINTS-EXPLICIT", "RISK-VALIDATION-SURFACE", "DOMAIN-CONFORMANCE"]
    put_json(f"{SOURCE}/reviewer-a.json", {"schema": "spec-reviewer-a/v1", "stage": "spec",
             "role": "spec-reviewer-a", "run_id": run, "host_session_id": session,
             "allowed_input_manifest": inputs, "verdict": "BLOCKED", "checks": [
                 {"id": name, "result": "FAIL", "severity": "Critical" if index == 0 else "Major",
                  "finding": "Review blocked before substantive reading: unreadable input prevented manifest hash verification."}
                 for index, name in enumerate(a_ids)]})
    put_json(f"{SOURCE}/reviewer-a-host-receipt.json", {"host": "Synthetic fixture host",
             "rpc": "thread/start", "threadId": session, "sessionId": session,
             "review_execution_started": False})
    put(f"{SOURCE}/reviewer-a-reservation.txt", f"REVIEW_CONTEXT_OK {record_hash} sequence=2 previous_record_sha256={genesis_hash} pre_append_tip_sequence=1 identity_unique=yes\n")
    put(f"{SOURCE}/spec-review-report.md", "# Synthetic interrupted review\nAttempt: 3\nRound: 3\nExecution: BLOCKED before substantive review\nReviewer A launch failure: unreadable input.\nReviewer B was not launched. No integrated verdict or complete review contract exists.\n")
    inventory = sorted([ref(f"{SOURCE}/{name}") for name in (
        "precheck-result.json", "reviewer-a.json", "reviewer-a-reservation.txt",
        "reviewer-a-host-receipt.json", "spec-review-report.md")] + [ref(INVOCATION)], key=lambda item: item["path"])
    record = {"schema": "spec-review-interrupted-recovery/v1", "feature": FEATURE,
              "source": {"attempt": 3, "round": 3}, "target": {"attempt": 4, "round": 1},
              "previous_contract": ref(f"{PREVIOUS}/spec-review-contract.json"),
              "interrupted_precheck": ref(f"{SOURCE}/precheck-result.json"), "pinned_inputs": pins,
              "interrupted_artifacts": inventory,
              "reviewer_a": {"invocation": ref(INVOCATION), "sequence": 2, "stage": "spec",
                             "role": "spec-reviewer-a", "run_id": run, "host_session_id": session,
                             "record_sha256": record_hash}}
    binding = digest(canonical(record))
    put(AUTH, f"Feature: {FEATURE}\nSource Attempt: 3\nSource Round: 3\nTarget Attempt: 4\nTarget Round: 1\nMaximum Rounds: 3\nDecision: Authorize interrupted A-before-B recovery\nRecovery Binding SHA256: {binding}\nSynthetic test input; no human-origin execution evidence.\n")
    record["authorization"] = ref(AUTH)
    put_json(RECORD, record)
    return record
