#!/usr/bin/env python3
"""T-002 driver shared by the POSIX and PowerShell twins.

Two sections:

1. The steps 0-3 Block matrix (five diagnostic rows over six invocations).
2. The step 3 Context Projection assembly and its own second canonicalizer
   pass. T-002 stages the projection in memory and deliberately writes no
   live artifact (design.md step 3, B1/B4), so the only point at which the
   assembled structure is observable from outside the resolver process is
   the input handed to the second (JSON-mode) canonicalizer invocation. A
   capture stub standing in for `canonicalize-sdd-yaml` records exactly
   those bytes, which are then compared against the field set Epic A4's
   REQ-003 fixes verbatim -- the authority design.md:818-822 cites for this
   step ("Epic A4's own REQ-003 generation procedure, verbatim"), restated
   in this feature's own investigation.md:136-138:

     {schema (const "sdd-context-projection/v1"), source_sha256
      (project-context.yaml's own canonical-form sha256), workflow
      (verbatim), components (re-keyed by each entry's own `id`, with `id`
      itself omitted), shared_paths (as-is)}

   with `components: {}` / `shared_paths: []` materialized whenever the
   source document omits either key
   (specs/epic-192-a4-facet-manifest/requirements.md REQ-003, AC-015).

   REQ-003 also allows an OPTIONAL `provider_bindings_sha256`. T-002's own
   steps 0-3 consume no provider bindings, so this suite asserts the exact
   five-field set below. A later task that starts populating that sixth
   field must widen PROJECTION_FIELDS deliberately -- the assertion is meant
   to fail first, not to be silently outgrown.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/capability-resolver/resolve-project-context-block"
PROJECTION_FIXTURES = ROOT / "tests/fixtures/capability-resolver/resolve-project-context-projection"
STAGED = (
    ROOT
    / "specs/epic-193-a5-capability-resolver/human-copy"
    / "plugins/sdd-quality-loop/scripts"
)
REAL_CANONICALIZER = ROOT / "plugins/sdd-quality-loop/scripts/canonicalize-sdd-yaml.py"
SCHEMA = ROOT / "contracts/resolver-evidence.schema.json"
SCHEMA_CHECK = ROOT / "tests/resolver-evidence-schema-check.py"

PROJECTION_SCHEMA = "sdd-context-projection/v1"
PROJECTION_FIELDS = ["components", "schema", "shared_paths", "source_sha256", "workflow"]

CASES = (
    ("disabled-legacy-invocation", "absent", "disabled-legacy-invocation", "sdd/project-context.yaml", "disabled-legacy"),
    ("workflow-combination-invalid-lite", "workflow-combination-invalid/lite-wrong-layout.yaml", "workflow-combination-invalid", "workflow spec_profile/artifact_layout combination is invalid", "advisory"),
    ("workflow-combination-invalid-full", "workflow-combination-invalid/full-lite-layout.yaml", "workflow-combination-invalid", "workflow spec_profile/artifact_layout combination is invalid", "required"),
    ("project-context-validation-failed", "project-context-validation-failed/missing-enforcement.yaml", "project-context-validation-failed", "project context does not conform to contracts/project-context.schema.json", None),
    ("canonicalizer-invocation-failed", "canonicalizer-invocation-failed/project-context.yaml", "canonicalizer-invocation-failed", "canonicalize-sdd-yaml failed while canonicalizing project context", None),
    ("dependency-output-malformed", "dependency-output-malformed/project-context.yaml", "dependency-output-malformed", "canonicalize-sdd-yaml returned malformed JSON while canonicalizing project context", None),
)

# The two Context Projection sources, with the projection each must produce
# per REQ-003. `source_sha256` is not spelled out here: it is recomputed
# independently, by hashing the real canonicalizer's own YAML-mode output
# over the same fixture (see expected_projection below).
PROJECTION_SOURCES = {
    "two-components": {
        "schema": PROJECTION_SCHEMA,
        "workflow": {
            "spec_profile": "full",
            "artifact_layout": "facet-hybrid",
            "capability_enforcement": "required",
        },
        "components": {
            "desktop-client": {
                "artifact_kinds": ["desktop-app"],
                "runtime_classes": ["electron"],
                "characteristics": {"pii": False, "ui": True},
                "paths": {"include": ["apps/desktop/**"]},
            },
            "Desktop/App": {
                "artifact_kinds": ["installer"],
                "paths": {"include": ["apps/installer/**"]},
            },
        },
        "shared_paths": [
            {"pattern": "shared/**", "classification": "cross-cutting"},
            {"pattern": "libs/core/**", "components": ["desktop-client"]},
        ],
    },
    "omits-components": {
        "schema": PROJECTION_SCHEMA,
        "workflow": {
            "spec_profile": "full",
            "artifact_layout": "facet-native",
            "capability_enforcement": "advisory",
        },
        "components": {},
        "shared_paths": [],
    },
}

# (case name, projection source, stub mode, expected diagnostic id, detail,
#  expected `state`). The two Block rows below are step 3's own second
# canonicalizer pass, distinct from the step 2 rows in CASES: same two
# diagnostic ids, different detail text, and `state` is already known by the
# time step 3 runs, so it must be present.
PROJECTION_BLOCK_CASES = (
    (
        "projection-canonicalizer-invocation-failed",
        "two-components",
        "json-fail",
        "canonicalizer-invocation-failed",
        "canonicalize-sdd-yaml failed while canonicalizing context projection",
        "required",
    ),
    (
        "projection-dependency-output-malformed",
        "omits-components",
        "json-garbage",
        "dependency-output-malformed",
        "canonicalize-sdd-yaml returned malformed JSON while canonicalizing context projection",
        "advisory",
    ),
)

ALL_CASE_NAMES = (
    [case[0] for case in CASES]
    + [f"projection-{name}" for name in PROJECTION_SOURCES]
    + [case[0] for case in PROJECTION_BLOCK_CASES]
)


class Counts:
    def __init__(self):
        self.passed = 0
        self.failed = 0

    def check(self, condition, label, detail=""):
        if condition:
            self.passed += 1
            print(f"PASS: {label}")
        else:
            self.failed += 1
            suffix = f": {detail}" if detail else ""
            print(f"FAIL: {label}{suffix}")


def install_scripts(repo):
    scripts = repo / "plugins/sdd-quality-loop/scripts"
    scripts.mkdir(parents=True)
    for suffix in ("py", "sh", "ps1"):
        shutil.copy2(STAGED / f"resolve-project-context.{suffix}", scripts)
    shutil.copy2(REAL_CANONICALIZER, scripts)
    contracts = repo / "contracts"
    contracts.mkdir()
    shutil.copy2(ROOT / "contracts/project-context.schema.json", contracts)
    return scripts


def copy_inputs(repo, fixture_rel, case_name):
    scripts = install_scripts(repo)
    config = repo / "sdd/project-context.yaml"
    config.parent.mkdir()
    if fixture_rel != "absent":
        shutil.copy2(FIXTURES / fixture_rel, config)
    if case_name in ("canonicalizer-invocation-failed", "dependency-output-malformed"):
        shutil.copy2(FIXTURES / case_name / "canonicalize-sdd-yaml.py", scripts / "canonicalize-sdd-yaml.py")


def copy_projection_inputs(repo, source_name):
    """Install the real canonicalizer under a delegate name and put the
    capture stub in its place, so step 2 stays production-faithful while
    step 3's own input becomes observable."""
    scripts = install_scripts(repo)
    shutil.copy2(REAL_CANONICALIZER, scripts / "canonicalize-sdd-yaml-real.py")
    shutil.copy2(PROJECTION_FIXTURES / "canonicalize-sdd-yaml.py", scripts / "canonicalize-sdd-yaml.py")
    config = repo / "sdd/project-context.yaml"
    config.parent.mkdir()
    shutil.copy2(PROJECTION_FIXTURES / f"{source_name}.yaml", config)


def plant_sentinels(repo, scripts):
    feature_dir = repo / "specs/example-feature"
    feature_dir.mkdir(parents=True)
    sentinels = {
        feature_dir / "facet-manifest.yaml": b"facet-preimage\n",
        feature_dir / "capability-summary.yaml": b"summary-preimage\n",
        scripts / "generated/project-context.resolved.json": b"projection-preimage\n",
    }
    for path, value in sentinels.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(value)
    return feature_dir, sentinels


def install_spy(repo):
    """A PATH shim for every step-4-or-later dependency this task must never
    reach. Firing it leaves a marker file behind."""
    spy = repo / "subprocess-spy-fired"
    spy_bin = repo / "spy-bin"
    spy_bin.mkdir()
    for name in ("resolve-component-paths", "validate-capability-registry"):
        path = spy_bin / name
        path.write_text(f"#!/bin/sh\nprintf fired > '{spy}'\nexit 91\n", encoding="utf-8", newline="\n")
        path.chmod(0o755)
    env = os.environ.copy()
    env["PATH"] = str(spy_bin) + os.pathsep + env.get("PATH", "")
    return spy, env


def launcher_args(kind, scripts):
    if kind == "sh":
        return ["sh", str(scripts / "resolve-project-context.sh")]
    return ["pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(scripts / "resolve-project-context.ps1")]


def resolver_argv(kind, scripts):
    return launcher_args(kind, scripts) + [
        "--config", "sdd/project-context.yaml",
        "--target-rev", "HEAD",
        "--feature", "example-feature",
    ]


def read_evidence(evidence_path):
    try:
        return json.loads(evidence_path.read_text(encoding="utf-8")), ""
    except (OSError, json.JSONDecodeError) as exc:
        return None, str(exc)


def check_evidence_schema(counts, evidence_path, case_name):
    schema_result = subprocess.run(
        [sys.executable, str(SCHEMA_CHECK), str(SCHEMA), str(evidence_path), "valid"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    ) if evidence_path.is_file() else None
    counts.check(schema_result is not None and schema_result.returncode == 0,
                 f"{case_name}: Resolver Evidence schema agreement",
                 "evidence absent" if schema_result is None else schema_result.stderr.decode("utf-8", errors="replace"))


def expected_projection(source_name):
    """REQ-003's expected projection for one source fixture, with
    `source_sha256` recomputed here from the real canonicalizer rather than
    taken from the resolver under test."""
    canonical = subprocess.run(
        [sys.executable, str(REAL_CANONICALIZER), str(PROJECTION_FIXTURES / f"{source_name}.yaml"),
         "--input-format", "yaml"],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
    ).stdout
    expected = dict(PROJECTION_SOURCES[source_name])
    expected["source_sha256"] = "sha256:" + hashlib.sha256(canonical).hexdigest()
    return expected


def run_case(kind, case, counts):
    case_name, fixture_rel, expected_id, expected_detail, expected_state = case
    with tempfile.TemporaryDirectory(prefix="resolver-block-") as tmp:
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        copy_inputs(repo, fixture_rel, case_name)
        scripts = repo / "plugins/sdd-quality-loop/scripts"
        feature_dir, sentinels = plant_sentinels(repo, scripts)
        spy, env = install_spy(repo)

        result = subprocess.run(resolver_argv(kind, scripts), cwd=repo, env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stderr = result.stderr.decode("utf-8", errors="replace")
        stdout = result.stdout.decode("utf-8", errors="replace")
        expected_line = f"capability-resolver: {expected_id}: {expected_detail}\n"
        counts.check(result.returncode == 1, f"{case_name}: exit 1", f"got {result.returncode}")
        counts.check(stdout == "" and stderr == expected_line and "UPSTREAM_SECRET" not in stderr,
                     f"{case_name}: canonical diagnostic only", f"stdout={stdout!r} stderr={stderr!r}")

        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = read_evidence(evidence_path)
        expected = {
            "schema": "sdd-resolver-evidence/v1",
            "feature": "example-feature",
            "capability_evaluations": [],
            "diagnostics": [{"id": expected_id, "detail": expected_detail, "severity": "block"}],
        }
        if expected_state is not None:
            expected["state"] = expected_state
        counts.check(evidence == expected, f"{case_name}: exact Resolver Evidence", parse_error or repr(evidence))

        check_evidence_schema(counts, evidence_path, case_name)
        unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
        counts.check(unchanged, f"{case_name}: no partial live artifact")
        counts.check(not spy.exists(), f"{case_name}: no step-4-or-later subprocess")


def run_projection_success_case(kind, source_name, counts):
    """Step 3 runs to completion; assert the projection handed to the second
    canonicalizer pass is exactly REQ-003's shape."""
    case_name = f"projection-{source_name}"
    with tempfile.TemporaryDirectory(prefix="resolver-projection-") as tmp:
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        copy_projection_inputs(repo, source_name)
        scripts = repo / "plugins/sdd-quality-loop/scripts"
        feature_dir, sentinels = plant_sentinels(repo, scripts)
        spy, env = install_spy(repo)
        env["SDD_T002_PROJECTION_MODE"] = "passthrough"

        result = subprocess.run(resolver_argv(kind, scripts), cwd=repo, env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        counts.check(result.returncode == 0, f"{case_name}: exit 0", f"got {result.returncode} stderr={stderr!r}")
        counts.check(stdout == "" and stderr == "", f"{case_name}: no diagnostic on either stream",
                     f"stdout={stdout!r} stderr={stderr!r}")

        capture_path = repo / "projection-capture.json"
        captured, parse_error = read_evidence(capture_path)
        counts.check(isinstance(captured, dict),
                     f"{case_name}: step 3 second canonicalizer pass ran in JSON mode",
                     parse_error or "no projection was handed to a JSON-mode canonicalizer invocation")

        expected = expected_projection(source_name)
        fields = sorted(captured) if isinstance(captured, dict) else None
        counts.check(fields == PROJECTION_FIELDS,
                     f"{case_name}: Context Projection field set is REQ-003's exact five", repr(fields))
        got = captured if isinstance(captured, dict) else {}
        counts.check(got.get("schema") == PROJECTION_SCHEMA,
                     f"{case_name}: Context Projection schema const", repr(got.get("schema")))
        counts.check(got.get("source_sha256") == expected["source_sha256"],
                     f"{case_name}: source_sha256 binds the canonical Project Context",
                     f"{got.get('source_sha256')!r} != {expected['source_sha256']!r}")
        counts.check(got.get("workflow") == expected["workflow"],
                     f"{case_name}: workflow copied verbatim", repr(got.get("workflow")))
        counts.check(got.get("components") == expected["components"],
                     f"{case_name}: components re-keyed by id with id stripped", repr(got.get("components")))
        counts.check(got.get("shared_paths") == expected["shared_paths"],
                     f"{case_name}: shared_paths carried as-is", repr(got.get("shared_paths")))
        counts.check(captured == expected, f"{case_name}: exact Context Projection document", repr(captured))

        if source_name == "two-components":
            counts.check(not (feature_dir / "resolver-evidence.yaml").exists(),
                         f"{case_name}: no Resolver Evidence on the success path")
            unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
            counts.check(unchanged, f"{case_name}: no partial live artifact")
            counts.check(not spy.exists(), f"{case_name}: no step-4-or-later subprocess")


def run_projection_block_case(kind, case, counts):
    """Step 3's own second canonicalizer pass fails; assert its two Block
    rows, which are distinct from step 2's same-id rows."""
    case_name, source_name, mode, expected_id, expected_detail, expected_state = case
    with tempfile.TemporaryDirectory(prefix="resolver-projection-") as tmp:
        repo = Path(tmp).resolve()
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        copy_projection_inputs(repo, source_name)
        scripts = repo / "plugins/sdd-quality-loop/scripts"
        feature_dir, sentinels = plant_sentinels(repo, scripts)
        spy, env = install_spy(repo)
        env["SDD_T002_PROJECTION_MODE"] = mode

        result = subprocess.run(resolver_argv(kind, scripts), cwd=repo, env=env,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        expected_line = f"capability-resolver: {expected_id}: {expected_detail}\n"
        counts.check(result.returncode == 1, f"{case_name}: exit 1", f"got {result.returncode}")
        counts.check(stdout == "" and stderr == expected_line and "UPSTREAM_SECRET" not in stderr,
                     f"{case_name}: canonical diagnostic only", f"stdout={stdout!r} stderr={stderr!r}")

        evidence_path = feature_dir / "resolver-evidence.yaml"
        evidence, parse_error = read_evidence(evidence_path)
        expected = {
            "schema": "sdd-resolver-evidence/v1",
            "feature": "example-feature",
            "capability_evaluations": [],
            "diagnostics": [{"id": expected_id, "detail": expected_detail, "severity": "block"}],
            "state": expected_state,
        }
        counts.check(evidence == expected, f"{case_name}: exact Resolver Evidence", parse_error or repr(evidence))

        check_evidence_schema(counts, evidence_path, case_name)
        unchanged = all(path.read_bytes() == value for path, value in sentinels.items())
        counts.check(unchanged, f"{case_name}: no partial live artifact")
        counts.check(not spy.exists(), f"{case_name}: no step-4-or-later subprocess")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--launcher", choices=("sh", "ps1"), required=True)
    args = parser.parse_args()
    counts = Counts()

    required = [STAGED / f"resolve-project-context.{suffix}" for suffix in ("py", "sh", "ps1")]
    if not all(path.is_file() for path in required):
        for case_name in ALL_CASE_NAMES:
            counts.check(False, f"{case_name}: staged implementation exists", "TDD RED: implementation absent")
    else:
        for case in CASES:
            run_case(args.launcher, case, counts)
        for source_name in PROJECTION_SOURCES:
            run_projection_success_case(args.launcher, source_name, counts)
        for case in PROJECTION_BLOCK_CASES:
            run_projection_block_case(args.launcher, case, counts)

    sh_registered = "tests/resolve-project-context-block.tests.sh" in (ROOT / "tests/run-all.sh").read_text(encoding="utf-8")
    ps_registered = "tests/resolve-project-context-block.tests.ps1" in (ROOT / "tests/run-all.ps1").read_text(encoding="utf-8")
    counts.check(sh_registered, "POSIX suite registered in tests/run-all.sh")
    counts.check(ps_registered, "PowerShell suite registered in tests/run-all.ps1")

    print(f"RESULT: {counts.passed} passed, {counts.failed} failed")
    return 1 if counts.failed else 0


if __name__ == "__main__":
    sys.exit(main())
