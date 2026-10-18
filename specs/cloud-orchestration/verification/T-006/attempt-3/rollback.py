"""Restore exact candidate entry bytes in a disposable checkout; no shared reset."""

from pathlib import Path
import hashlib
import json
import shutil
import shlex
import subprocess

ROOT = Path.cwd()
OUT = ROOT / "specs/cloud-orchestration/verification/T-006/attempt-3"
SCRATCH = Path("/tmp/cloud-T006-01a14e9b")
DEST = SCRATCH / "rollback"
BASE = json.loads((OUT / "entry.json").read_text())["spec_revision"]
SHARED = "plugins/sdd-quality-loop/scripts/cloud_verification.py"
AZURE = "plugins/sdd-azure-cloud/scripts/azure_observation.py"
AWS = "plugins/sdd-aws-cloud/scripts/aws_observation.py"
TEST = "tests/cloud-orchestration-verification.tests.py"
paths = [
    SHARED,
    AZURE,
    AWS,
    TEST,
    "plugins/sdd-azure-cloud/references/azure-local-config.schema.json",
    "plugins/sdd-azure-cloud/references/observations.md",
    "plugins/sdd-aws-cloud/references/observations.md",
]
results = []


def command(name, cmd, cwd=DEST):
    if cmd[:3] == ["python3", "-B", TEST]:
        wrapper = (
            "import runpy,sys; from unittest.mock import patch; "
            "path=sys.argv.pop(1); "
            "guard=patch('urllib.request.OpenerDirector.open', side_effect=AssertionError('LIVE_NETWORK_FORBIDDEN_IN_ROLLBACK')); "
            "guard.start(); print('OFFLINE_GUARD_INSTALLED',flush=True); "
            "runpy.run_path(path,run_name='__main__')"
        )
        cmd = ["python3", "-B", "-c", wrapper, TEST, *cmd[3:]]
    p = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (OUT / (name + ".log")).write_bytes(
        ("$ " + shlex.join(cmd) + "\n").encode()
        + p.stdout
        + f"\nExit code: {p.returncode}\n".encode()
    )
    results.append(dict(name=name, command=cmd, exit_code=p.returncode))
    print(name, p.returncode, flush=True)
    return p


def overlay(blobs):
    for name, data in blobs.items():
        path = DEST / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)


assert (
    command(
        "rollback-create", ["git", "worktree", "add", "--detach", str(DEST), BASE], ROOT
    ).returncode
    == 0
)
for folder in ("initial", "dependencies", "supplemental"):
    for path in (SCRATCH / folder).rglob("*"):
        if path.is_file():
            relative = path.relative_to(SCRATCH / folder)
            target = DEST / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
entry = {p: (SCRATCH / "initial" / p).read_bytes() for p in paths}
current = {p: (ROOT / p).read_bytes() for p in paths}
assert command("rollback-entry-verification", ["python3", "-B", TEST]).returncode == 0
overlay(current)
assert (
    command("rollback-candidate-verification", ["python3", "-B", TEST]).returncode == 0
)
overlay(entry)
assert all((DEST / p).read_bytes() == data for p, data in entry.items())
assert (
    command("rollback-restored-verification", ["python3", "-B", TEST]).returncode == 0
)
overlay(current)
# Each mutation targets a meaningful shared guard; every affected field also has
# an executed mismatch body. No setup/import failure is accepted as sensitivity.
mutations = [
    (
        "context",
        SHARED,
        [("all(context.get(k) == v for k, v in expected.items())", "True")],
        "ReducerCases.test_each_context_counterpart_mismatch",
    ),
    (
        "observations",
        SHARED,
        [("all(obs[k] == context[k] for k in OBS_FIELDS)", "True")],
        "ReducerCases.test_each_observation_counterpart_mismatch",
    ),
    (
        "payload-digest",
        SHARED,
        [('obs["result"]["sha256"] == digest(item["payload_bytes"])', "True")],
        "ReducerCases.test_check_fail_block_unknown_stale_missing_tampered",
    ),
    (
        "provenance",
        SHARED,
        [('context["classification"] != "native" or trusted_native', "True")],
        "ExpandedBindingCases.test_nested_context_fields_and_untrusted_native_labels",
    ),
    (
        "http-outcome",
        SHARED,
        [('any(q["http_status"] != 200 for q in payload["queries"])', "False")],
        "ReducerCases.test_native_denial_cannot_be_overridden_by_healthy_label",
    ),
    (
        "fresh-age",
        SHARED,
        [("(current - sample).total_seconds() <= age", "True")],
        "FreshnessCases.test_old_deployment_recent_samples_and_time_order",
    ),
    (
        "fresh-order",
        SHARED,
        [("start <= sample <= end <= current", "True")],
        "FreshnessCases.test_old_deployment_recent_samples_and_time_order",
    ),
    (
        "final-recheck",
        SHARED,
        [("queries = recheck()", "queries = []")],
        "NativeAdversarialCases.test_postcollection_lease_expiry_prevents_publication",
    ),
    (
        "azure-principal",
        AZURE,
        [('prop["principalId"] == self.principal', "True")],
        "AzureClosureAndDcrCases.test_permission_closure_mismatches",
    ),
    (
        "azure-caller",
        AZURE,
        [("actual == grants[target]", "True")],
        "AzureClosureAndDcrCases.test_permission_closure_mismatches",
    ),
    (
        "azure-stability",
        AZURE,
        [("first == last", "True")],
        "AzureClosureAndDcrCases.test_permission_closure_mismatches",
    ),
    (
        "azure-pagination",
        AZURE,
        [('type(value) is dict and not value.get("nextLink")', "type(value) is dict")],
        "AzureClosureAndDcrCases.test_permission_closure_mismatches",
    ),
    (
        "azure-dcr",
        AZURE,
        [('counter["samplingFrequencyInSeconds"] == 60', "True")],
        "AzureClosureAndDcrCases.test_dcr_readback_and_mismatches",
    ),
    (
        "azure-metric-context",
        AZURE,
        [('response["namespace"] == cfg["namespace"]', "True")],
        "AzureMetricContextCases.test_metric_context_counterparts",
    ),
    (
        "azure-current",
        AZURE,
        [('native_time(row["properties"]["timestamp"]) < original_time', "True")],
        "AzureResourceBindingCases.test_compiled_and_original_operation_membership",
    ),
    (
        "aws-current",
        AWS,
        [
            ('latest.get("ClientRequestToken") == executor.token', "True"),
            (
                'stamp < completed or event.get("ClientRequestToken") == executor.token',
                "True",
            ),
        ],
        "AwsObservationOrchestration.test_newer_or_ambiguous_stack_operation_rejected",
    ),
    (
        "aws-membership",
        AWS,
        [('detail["LogicalResourceId"] == logical', "True")],
        "AwsObservationOrchestration.test_stack_membership_counterparts",
    ),
    (
        "aws-minimum",
        AWS,
        [('(("Minimum", "Maximum") if workload else ("Maximum",))', '("Maximum",)')],
        "WorkloadRangeCases",
    ),
    (
        "azure-minimum",
        AZURE,
        [('(("minimum", "maximum") if workload else ("maximum",))', '("maximum",)')],
        "WorkloadRangeCases",
    ),
    (
        "azure-publication-scan",
        "plugins/sdd-azure-cloud/scripts/cloud.py",
        [
            (
                'c._require(safe_publication(data), "SECRET_SCAN_FAILED")',
                'c._require(True, "SECRET_SCAN_FAILED")',
            )
        ],
        "PublicObservationCases.test_publication_bindings_scan_no_overwrite_escape_and_secret_redaction",
    ),
]
for name, source_path, replacements, test in mutations:
    before = (DEST / source_path).read_bytes()
    source = before.decode()
    for old, new in replacements:
        assert source.count(old) == 1, (name, old, source.count(old))
        source = source.replace(old, new)
    (DEST / source_path).write_text(source)
    p = command("sensitivity-" + name, ["python3", "-B", TEST, test])
    (DEST / source_path).write_bytes(before)
    assert p.returncode != 0 and b"FAIL:" in p.stdout, name
    assert not any(
        marker in p.stdout
        for marker in (b"SyntaxError", b"ImportError", b"ModuleNotFoundError")
    ), name
assert (
    command("rollback-reapplied-verification", ["python3", "-B", TEST]).returncode == 0
)
assert all((ROOT / p).read_bytes() == data for p, data in current.items())
summary = dict(
    base_revision=BASE,
    scratch=str(DEST),
    entry_sha256={p: hashlib.sha256(b).hexdigest() for p, b in entry.items()},
    candidate_sha256={p: hashlib.sha256(b).hexdigest() for p, b in current.items()},
    results=results,
    shared_tree_unchanged=True,
)
(OUT / "rollback.json").write_text(json.dumps(summary, indent=2) + "\n")
assert (
    command(
        "rollback-remove", ["git", "worktree", "remove", "--force", str(DEST)], ROOT
    ).returncode
    == 0
)
