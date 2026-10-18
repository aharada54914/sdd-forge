"""Disposable local rollback of task-owned code; never resets the shared tree."""

from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import shlex

ROOT = Path.cwd()
SCRATCH = Path("/tmp/cloud-T006-01a14e73")
OUT = ROOT / "specs/cloud-orchestration/verification/T-006/attempt-2"
DEST = SCRATCH / "rollback"
BASE = json.loads((OUT / "input-preservation.json").read_text())["base_revision"]
results = []


def command(name, cmd, cwd=ROOT):
    p = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    (OUT / (name + ".log")).write_bytes(
        ("$ " + shlex.join(cmd) + "\n").encode()
        + p.stdout
        + f"\nExit code: {p.returncode}\n".encode()
    )
    results.append(dict(name=name, command=cmd, exit_code=p.returncode))
    return p.returncode


assert (
    command("rollback-create", ["git", "worktree", "add", "--detach", str(DEST), BASE])
    == 0
)
# Overlay the exact entry candidate and declared test dependencies, not a
# fabricated clean baseline. Entry inputs include uncommitted prior work.
for folder in ["initial", "dependency", "regression", "routing-fixture"]:
    for path in (SCRATCH / folder).rglob("*"):
        if path.is_file():
            dest = DEST / path.relative_to(SCRATCH / folder)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, dest)
patterns = [
    "plugins/sdd-quality-loop/scripts/cloud_verification.py",
    "plugins/sdd-aws-cloud/scripts/*.py",
    "plugins/sdd-azure-cloud/scripts/*.py",
    "plugins/sdd-aws-cloud/references/*",
    "plugins/sdd-azure-cloud/references/*",
    "contracts/cloud-collection-context.schema.json",
    "contracts/cloud-check-result.schema.json",
    "contracts/cloud-observation-evidence.schema.json",
    "tests/cloud-orchestration-verification.tests.py",
    "tests/cloud-orchestration-routing.tests.py",
    "tests/cloud-orchestration-contracts.tests.py",
]
paths = sorted(
    {
        p.relative_to(ROOT).as_posix()
        for pat in patterns
        for p in ROOT.glob(pat)
        if p.is_file()
    }
)
entry = {p: (DEST / p).read_bytes() if (DEST / p).exists() else None for p in paths}
current = {p: (ROOT / p).read_bytes() for p in paths}


def overlay(blobs):
    for p, data in blobs.items():
        target = DEST / p
        if data is None:
            target.unlink(missing_ok=True)
        else:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)


def hashes(blobs):
    return {
        p: hashlib.sha256(b).hexdigest() if b is not None else None
        for p, b in blobs.items()
    }


command(
    "rollback-entry-verification",
    ["python3", "-B", "tests/cloud-orchestration-verification.tests.py"],
    DEST,
)
command(
    "rollback-entry-routing-known-red",
    ["python3", "-B", "tests/cloud-orchestration-routing.tests.py"],
    DEST,
)
routing_log = (OUT / "rollback-entry-routing-known-red.log").read_text()
assert "Ran 86 tests" in routing_log and "FAILED (failures=9)" in routing_log
assert "ERROR:" not in routing_log and "skipped=" not in routing_log
overlay(current)
command(
    "rollback-candidate-verification",
    ["python3", "-B", "tests/cloud-orchestration-verification.tests.py"],
    DEST,
)
overlay(entry)
assert all(
    ((DEST / p).read_bytes() if (DEST / p).exists() else None) == b
    for p, b in entry.items()
)
command(
    "rollback-restored-verification",
    ["python3", "-B", "tests/cloud-orchestration-verification.tests.py"],
    DEST,
)
overlay(current)
command(
    "rollback-reapplied-verification",
    ["python3", "-B", "tests/cloud-orchestration-verification.tests.py"],
    DEST,
)
# Meaningful sensitivity: remove individual candidate checks only in disposable copy.
mutations = [
    (
        "azure-incomplete-native-proof",
        "plugins/sdd-azure-cloud/scripts/azure_observation.py",
        "type(self.transport) is not HttpsTransport",
        "True",
        "NativeCollectorCases.test_native_azure_incomplete_permission_proof_cannot_pass",
    ),
    (
        "freshness-current-age",
        "plugins/sdd-quality-loop/scripts/cloud_verification.py",
        "and (current - sample).total_seconds() <= age",
        "and True",
        "FreshnessCases.test_old_deployment_recent_samples_and_time_order",
    ),
    (
        "freshness-time-order",
        "plugins/sdd-quality-loop/scripts/cloud_verification.py",
        "start <= sample <= end <= current",
        "True",
        "FreshnessCases.test_old_deployment_recent_samples_and_time_order",
    ),
    (
        "freshness-deployment-age-regression",
        "plugins/sdd-quality-loop/scripts/cloud_verification.py",
        "and (current - sample).total_seconds() <= age",
        "and (sample - start).total_seconds() <= age and (current - sample).total_seconds() <= age",
        "FreshnessCases.test_old_deployment_native_recent_metric_and_backup",
    ),
    (
        "freshness-query-window",
        "plugins/sdd-aws-cloud/scripts/aws_observation.py",
        "StartTime=start,",
        "StartTime=self.completed,",
        "FreshnessCases.test_metric_query_recent_postcompletion_minute_window",
    ),
    (
        "membership-stack",
        "plugins/sdd-aws-cloud/scripts/aws_observation.py",
        'detail["StackId"] == executor.stack_id',
        "True",
        "AwsObservationOrchestration.test_stack_membership_counterparts",
    ),
    (
        "membership-logical",
        "plugins/sdd-aws-cloud/scripts/aws_observation.py",
        'detail["LogicalResourceId"] == logical',
        "True",
        "AwsObservationOrchestration.test_stack_membership_counterparts",
    ),
    (
        "membership-type",
        "plugins/sdd-aws-cloud/scripts/aws_observation.py",
        'detail["ResourceType"] == typ',
        "True",
        "AwsObservationOrchestration.test_stack_membership_counterparts",
    ),
    (
        "membership-state",
        "plugins/sdd-aws-cloud/scripts/aws_observation.py",
        'detail["ResourceStatus"] in ("CREATE_COMPLETE", "UPDATE_COMPLETE")',
        "True",
        "AwsObservationOrchestration.test_stack_membership_counterparts",
    ),
    (
        "lease",
        "plugins/sdd-aws-cloud/scripts/aws_observation.py",
        "int(self.clock()) < self.lease",
        "True",
        "NativeCollectorCases.test_expired_collector_lease_has_zero_reads",
    ),
    (
        "context-binding",
        "plugins/sdd-quality-loop/scripts/cloud_verification.py",
        "all(context.get(k) == v for k, v in expected.items())",
        "True",
        "ReducerCases.test_each_context_counterpart_mismatch",
    ),
]
for name, mutation_path, old, new, test in mutations:
    original = current[mutation_path].decode()
    assert old in original, (name, old)
    (DEST / mutation_path).write_text(original.replace(old, new))
    code = command(
        "sensitivity-" + name,
        ["python3", "-B", "tests/cloud-orchestration-verification.tests.py", test],
        DEST,
    )
    assert code != 0, name + " survived"
    (DEST / mutation_path).write_bytes(current[mutation_path])
command(
    "rollback-sensitivity-restored",
    ["python3", "-B", "tests/cloud-orchestration-verification.tests.py"],
    DEST,
)
assert all((ROOT / p).read_bytes() == b for p, b in current.items())
(OUT / "rollback.json").write_text(
    json.dumps(
        dict(
            base_revision=BASE,
            entry=hashes(entry),
            candidate=hashes(current),
            commands=results,
            shared_tree_unchanged=True,
        ),
        indent=2,
    )
    + "\n"
)
command("rollback-remove", ["git", "worktree", "remove", "--force", str(DEST)])
print(json.dumps(results, indent=2))
