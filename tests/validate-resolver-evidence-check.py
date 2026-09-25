#!/usr/bin/env python3
"""T-008 driver shared by the POSIX and PowerShell twins for
`validate-resolver-evidence` (design.md Test Strategy; AC-021/AC-050/AC-051/
AC-054).

Every case below builds a throwaway git repository, installs the REAL
`validate-resolver-evidence.{py,sh,ps1}` under test plus the REAL dependency
scripts it discovers (`registry_discovery.py`, `generate-registry-digest.py`,
`canonicalize-sdd-yaml.py`), plants one fixture's own Registry/Evidence/
Facet-Manifest/journal files, and launches the runtime-appropriate wrapper as
a genuine subprocess. Nothing about the validator is mocked or reimplemented
here.

Two oracle properties this driver deliberately does NOT hand-transcribe:

- **The Registry digest.** Each Evidence/Manifest fixture carries the literal
  token `@REGISTRY_DIGEST@` in `context_binding.registry_digest`, replaced at
  run time by the value the REAL `generate-registry-digest.py --whole`
  subprocess computes over the fixture repo's own ADR-0025-discovered
  Registry. A hardcoded digest would silently rot the instant the
  canonicalizer's own serialization changed; more importantly, substituting
  the real tool's own output is what makes every `exit 0` case an assertion
  that the validator's digest computation AGREES with
  `generate-registry-digest --whole`, rather than merely being
  self-consistent. `provenance-registry-self-discovery-mismatch` carries a
  separate `digest-registry.json` so its placeholder is bound to a DIFFERENT
  Registry than the one the fixture repo will actually discover -- that
  divergence is the fixture's whole point.
- **The twelve-value check-id enum.** `CHECK_ID_ENUM` below is an INDEPENDENT
  literal transcription of design.md's own closed enum, never imported from
  the validator under test. `run_enum_completeness_check` compares it against
  the set of check-ids this run actually OBSERVED a fixture fire, so a fixture
  that is deleted, renamed, or accidentally unwired fails the matrix check
  even though every surviving case still passes.
"""

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "tests/fixtures/capability-resolver/validate-resolver-evidence"
LIVE_SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"

VALIDATOR_STEM = "validate-resolver-evidence"
DEPENDENCY_SCRIPTS = (
    "registry_discovery.py",
    "generate-registry-digest.py",
    "canonicalize-sdd-yaml.py",
)

FEATURE = "example-feature"
EVIDENCE_REL = f"specs/{FEATURE}/resolver-evidence.yaml"
MANIFEST_REL = f"specs/{FEATURE}/facet-manifest.yaml"
OVERRIDE_REGISTRY_REL = "override/capability-registry.json"
CONTEXT_REL = "generated/project-context.resolved.json"

DIGEST_PLACEHOLDER = "@REGISTRY_DIGEST@"
EVIDENCE_REL_PLACEHOLDER = "@EVIDENCE_REL@"

DIAGNOSTIC_RE = re.compile(r"^resolver-evidence: ([a-z0-9-]+): (.+)$")

# design.md `validate-resolver-evidence.{py,sh,ps1}` contract (REQ-004), "this
# script's own closed check-id enum (now **twelve** values)". Transcribed
# independently -- never imported from the module under test.
CHECK_ID_ENUM = (
    "schema-invalid",
    "registry-digest-unbound",
    "capability-set-mismatch",
    "capability-evaluation-id-duplicate",
    "affected-component-provenance-mismatch",
    "trigger-evaluation-set-mismatch",
    "component-evaluation-id-duplicate",
    "matched-result-contradiction",
    "conditional-facet-set-mismatch",
    "conditional-facet-evaluation-set-mismatch",
    "applied-result-contradiction",
    "array-not-stable-sorted",
)

# Operational fail-closed refusals are deliberately NOT members of that closed
# enum: they are refusals to evaluate at all, the same category as Epic A4's own
# `canonicalizer-invocation-failed`/`manifest-unreadable` lines, which those
# three validators likewise emit outside their own check-id enums. Enumerated
# here so the namespace-closure assertion stays exact -- an id outside BOTH
# sets still fails the run.
JOURNAL_CHECK_ID = "resolver-publication-in-progress"
OPERATIONAL_IDS = frozenset({
    JOURNAL_CHECK_ID,
    "canonicalizer-invocation-failed",
    "registry-version-mismatch",
})


class Counts:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.observed_check_ids = set()

    def check(self, condition, label, detail=""):
        if condition:
            self.passed += 1
            print(f"PASS: {label}")
        else:
            self.failed += 1
            suffix = f": {detail}" if detail else ""
            print(f"FAIL: {label}{suffix}")


def load_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def canonical_bytes(document):
    """The byte form this feature's own Resolver publishes every artifact in
    (`resolve-project-context.py` `_canonical_payload`) -- canonical,
    key-sorted, separator-fixed JSON plus one trailing newline. Fixtures are
    planted in exactly that form so the `.yaml` reading path under test is the
    production one, not a test-only shape."""
    return (json.dumps(document, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def substitute_digest(document, digest):
    if isinstance(document, dict):
        return {key: substitute_digest(value, digest) for key, value in document.items()}
    if isinstance(document, list):
        return [substitute_digest(value, digest) for value in document]
    if document == DIGEST_PLACEHOLDER:
        return digest
    return document


def install_scripts(repo):
    scripts = repo / "plugins/sdd-quality-loop/scripts"
    scripts.mkdir(parents=True)
    for suffix in ("py", "sh", "ps1"):
        source = LIVE_SCRIPTS / f"{VALIDATOR_STEM}.{suffix}"
        if source.is_file():
            shutil.copy2(source, scripts / source.name)
    for name in DEPENDENCY_SCRIPTS:
        shutil.copy2(LIVE_SCRIPTS / name, scripts / name)
    return scripts


def real_registry_digest(repo, scripts, registry_source):
    """`sha256:<64-hex>` from the REAL `generate-registry-digest.py --whole`,
    computed over `registry_source` by placing it at the location that tool's
    own ADR-0025 discovery resolves. Returns None when the tool itself fails
    (the caller turns that into a visible FAIL rather than a silent skip)."""
    contracts = repo / "contracts"
    contracts.mkdir(parents=True, exist_ok=True)
    shutil.copy2(registry_source, contracts / "capability-registry.json")
    result = subprocess.run(
        [sys.executable, str(scripts / "generate-registry-digest.py"), "--whole"],
        cwd=str(repo), stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
    )
    if result.returncode != 0:
        return None
    text = result.stdout.decode("ascii", errors="replace").strip()
    return "sha256:" + text if re.fullmatch(r"[0-9a-f]{64}", text) else None


def wrapper_argv(launcher, scripts):
    if launcher == "sh":
        return ["bash", str(scripts / f"{VALIDATOR_STEM}.sh")]
    return ["pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(scripts / f"{VALIDATOR_STEM}.ps1")]


def resolve_args(raw_args):
    table = {
        "@OVERRIDE_REGISTRY@": OVERRIDE_REGISTRY_REL,
        "@MANIFEST@": MANIFEST_REL,
        "@CONTEXT@": CONTEXT_REL,
        "@EVIDENCE@": EVIDENCE_REL,
    }
    return [table.get(item, item) for item in raw_args]


def build_repo(repo, case_dir):
    """Plant one fixture into a fresh git repository. Returns the resolved
    `sha256:` digest the fixture's own placeholders were bound to, or None on
    a dependency failure."""
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    scripts = install_scripts(repo)

    contracts = repo / "contracts"
    contracts.mkdir(parents=True, exist_ok=True)
    shutil.copy2(ROOT / "contracts/resolver-evidence.schema.json", contracts)

    digest_source = case_dir / "digest-registry.json"
    if not digest_source.is_file():
        digest_source = case_dir / "registry.json"
    digest = real_registry_digest(repo, scripts, digest_source)
    # The digest is measured against `digest_source`; the Registry the fixture
    # actually leaves discoverable is always `registry.json`.
    shutil.copy2(case_dir / "registry.json", contracts / "capability-registry.json")
    if digest is None:
        return None

    evidence = substitute_digest(load_json(case_dir / "evidence.json"), digest)
    evidence_path = repo / EVIDENCE_REL
    evidence_path.parent.mkdir(parents=True, exist_ok=True)
    evidence_path.write_bytes(canonical_bytes(evidence))

    if (case_dir / "manifest.json").is_file():
        manifest = substitute_digest(load_json(case_dir / "manifest.json"), digest)
        (repo / MANIFEST_REL).write_bytes(canonical_bytes(manifest))

    if (case_dir / "override-registry.json").is_file():
        override = repo / OVERRIDE_REGISTRY_REL
        override.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(case_dir / "override-registry.json", override)

    if (case_dir / "projection.json").is_file():
        projection = repo / CONTEXT_REL
        projection.parent.mkdir(parents=True, exist_ok=True)
        projection.write_bytes(canonical_bytes(load_json(case_dir / "projection.json")))

    journal_source = case_dir / "journal.json"
    if journal_source.is_file():
        journal = load_json(journal_source)
        for target in journal.get("targets", []):
            # A deliberately malformed fixture may carry non-dict entries
            # (reader-journal-malformed); plant them verbatim.
            if isinstance(target, dict) and target.get("live_path") == EVIDENCE_REL_PLACEHOLDER:
                target["live_path"] = EVIDENCE_REL
        journal_path = repo / f"specs/{FEATURE}/.resolver-staging" / journal["nonce"] / "TRANSACTION.json"
        journal_path.parent.mkdir(parents=True, exist_ok=True)
        journal_path.write_bytes(canonical_bytes(journal))

    # Installed LAST, and only when a fixture asks for it: the real
    # canonicalizer is required above, by `generate-registry-digest --whole`,
    # to bind this fixture's own digest placeholders before it is displaced.
    stub = case_dir / "canonicalizer.py"
    if stub.is_file():
        shutil.copy2(stub, scripts / "canonicalize-sdd-yaml.py")

    return digest


def parse_diagnostics(stdout):
    """Split stdout into (check_ids, malformed_lines). A line that does not
    match the `resolver-evidence: <check-id>: <detail>` convention is reported
    rather than silently dropped."""
    check_ids = []
    malformed = []
    for line in stdout.splitlines():
        match = DIAGNOSTIC_RE.match(line)
        if match is None:
            malformed.append(line)
        else:
            check_ids.append(match.group(1))
    return check_ids, malformed


def run_case(launcher, name, counts):
    case_dir = FIXTURES / name
    meta = load_json(case_dir / "case.json")
    expected_ids = list(meta["expect_check_ids"])
    expected_exit = meta["expect_exit"]

    with tempfile.TemporaryDirectory(prefix="validate-resolver-evidence-") as tmp:
        repo = Path(tmp).resolve()
        digest = build_repo(repo, case_dir)
        if digest is None:
            counts.check(False, f"{name}: fixture repo prepared",
                         "generate-registry-digest --whole did not yield a digest")
            return

        scripts = repo / "plugins/sdd-quality-loop/scripts"
        argv = wrapper_argv(launcher, scripts) + ["--evidence", EVIDENCE_REL] + resolve_args(meta["args"])
        result = subprocess.run(argv, cwd=str(repo), stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, check=False)
        stdout = result.stdout.decode("utf-8", errors="replace")
        stderr = result.stderr.decode("utf-8", errors="replace")
        observed_ids, malformed = parse_diagnostics(stdout)
        for check_id in observed_ids:
            counts.observed_check_ids.add(check_id)

        counts.check(result.returncode == expected_exit,
                     f"{name}: exit {expected_exit}",
                     f"got {result.returncode}; stdout={stdout!r} stderr={stderr!r}")
        counts.check(sorted(observed_ids) == sorted(expected_ids),
                     f"{name}: emits exactly {expected_ids!r} and nothing else",
                     f"got {observed_ids!r}; stdout={stdout!r}")
        counts.check(not malformed,
                     f"{name}: every diagnostic line follows the "
                     f"'resolver-evidence: <check-id>: <detail>' convention",
                     f"malformed={malformed!r}")
        counts.check(stderr == "", f"{name}: nothing on stderr", f"stderr={stderr!r}")
        counts.check("\r" not in stdout,
                     f"{name}: LF-only diagnostic bytes (no CR)", f"stdout={stdout!r}")

        # security-spec.md B5: a dependency subprocess's own raw stderr, and any
        # OS/environment-specific text it carries, must never reach this
        # validator's own emitted diagnostic (it would also break REQ-005
        # dual-runtime byte-identity). Checked against BOTH streams.
        forbidden = meta.get("forbidden_strings", [])
        if forbidden:
            leaked = [token for token in forbidden if token in stdout or token in stderr]
            counts.check(
                not leaked,
                f"{name}: no dependency raw-stderr text reaches this validator's own "
                f"diagnostic (B5 containment)",
                f"leaked={leaked!r} stdout={stdout!r}",
            )


def run_enum_completeness_check(counts):
    """Every one of design.md's own twelve check-ids was actually OBSERVED
    firing during this run (AC-021's "one independently-triggerable fixture
    per check-id"), and this run fired NOTHING outside that enum plus the
    documented reader-side refusal."""
    expected = set(CHECK_ID_ENUM)
    observed = set(counts.observed_check_ids)
    missing = sorted(expected - observed)
    extra = sorted(observed - expected - OPERATIONAL_IDS)
    counts.check(not missing,
                 "TEST-021 matrix completeness: every one of the twelve check-ids "
                 "was observed firing on its own fixture",
                 f"never observed: {missing!r}")
    counts.check(not extra,
                 "TEST-021 namespace closure: no check-id outside the closed "
                 "twelve-value enum (plus the reader-side refusal) was emitted",
                 f"unexpected: {extra!r}")
    counts.check(len(expected) == 12,
                 "TEST-021 enum cardinality: design.md's own enum is twelve-valued",
                 f"got {len(expected)}")


def run_ordering_check(counts):
    """AC-050's ordering claim, asserted structurally rather than by reading
    the implementation: both TEST-050 mismatch fixtures pair a digest mismatch
    with a Registry whose own capabilities[] set WOULD independently fire
    `capability-set-mismatch`, so `registry-digest-unbound` being the sole
    expected diagnostic is only satisfiable if the binding check runs first
    and suppresses the exact-set check."""
    for name in ("provenance-registry-override-mismatch", "provenance-registry-self-discovery-mismatch"):
        meta = load_json(FIXTURES / name / "case.json")
        registry_name = "override-registry.json" if "override" in name else "registry.json"
        registry = load_json(FIXTURES / name / registry_name)
        evidence = load_json(FIXTURES / name / "evidence.json")
        registry_ids = {entry["id"] for entry in registry["capabilities"]}
        evidence_ids = {entry["capability_id"] for entry in evidence["capability_evaluations"]}
        counts.check(
            registry_ids != evidence_ids and meta["expect_check_ids"] == ["registry-digest-unbound"],
            f"{name}: the fixture's own Registry capability set diverges from the "
            f"Evidence instance's own, so the sole-diagnostic expectation is a "
            f"genuine binding-before-exact-set ordering assertion (AC-050)",
            f"registry_ids={sorted(registry_ids)!r} evidence_ids={sorted(evidence_ids)!r} "
            f"expect={meta['expect_check_ids']!r}",
        )


def run_b7_keying_check(counts):
    """AC-021/B7: the `conditional-facet-set-mismatch` fixture is only a
    genuine declaration_index-keying assertion if the Registry declares ONE
    facet name more than once for the Capability under test AND the Evidence
    instance's own surviving entries carry that same single distinct name --
    otherwise a facet-name-keyed implementation would fire on it too and the
    fixture would prove nothing."""
    case_dir = FIXTURES / "conditional-facet-set-mismatch"
    registry = load_json(case_dir / "registry.json")
    evidence = load_json(case_dir / "evidence.json")
    capability = next(c for c in registry["capabilities"] if c["id"] == "alpha-capability")
    declared = [entry["facet"] for entry in capability["conditional_facets"]]
    recorded = [
        entry["facet"]
        for cap in evidence["capability_evaluations"]
        if cap["capability_id"] == "alpha-capability"
        for entry in cap.get("conditional_facet_evaluations", [])
    ]
    counts.check(
        len(declared) > len(set(declared)) and set(declared) == set(recorded) and len(recorded) != len(declared),
        "conditional-facet-set-mismatch: the fixture is name-blind by construction "
        "-- the Registry declares one facet name twice, the Evidence instance "
        "records that same name-set at a different cardinality, so only "
        "declaration_index keying can detect it (B7)",
        f"declared={declared!r} recorded={recorded!r}",
    )


def run_journal_pair_check(counts):
    """AC-054: the live-journal fixture and its control differ ONLY by the
    planted journal, so the fail-closed verdict cannot be attributed to
    Evidence content."""
    live = FIXTURES / "reader-journal-live"
    control = FIXTURES / "reader-journal-absent"
    same_evidence = load_json(live / "evidence.json") == load_json(control / "evidence.json")
    same_manifest = load_json(live / "manifest.json") == load_json(control / "manifest.json")
    same_registry = load_json(live / "registry.json") == load_json(control / "registry.json")
    counts.check(
        same_evidence and same_manifest and same_registry
        and (live / "journal.json").is_file() and not (control / "journal.json").is_file(),
        "TEST-054 pair: the live-journal fixture and its control are identical "
        "in Registry/Evidence/Manifest and differ only by the planted journal",
        f"evidence={same_evidence} manifest={same_manifest} registry={same_registry}",
    )
    journal = load_json(live / "journal.json")
    counts.check(
        journal.get("schema") == "sdd-resolver-transaction/v1"
        and journal.get("status") == "in-progress"
        and any(target.get("live_path") == EVIDENCE_REL_PLACEHOLDER for target in journal.get("targets", [])),
        "TEST-054 journal shape: the planted journal matches T-007's own "
        "TRANSACTION.json format and names the resolver-evidence.yaml path "
        "this validator is about to read",
        f"journal={journal!r}",
    )


def _sh_wrapper_dispatches(text):
    """The POSIX twin names the `.py` implementation only on its own `exec`
    line -- the mention IS the launch."""
    mentions = _non_comment_mentions(text, "#")
    launches = [line for line in mentions if "exec" in line]
    return bool(launches) and launches == mentions


def _ps1_wrapper_dispatches(text):
    """The PowerShell twin follows Epic A4's own already-shipped wrapper
    shape: the `.py` filename is bound to `$Target` via `Join-Path`, and the
    launch is `& $python.Path $Target @args` on a later line. Asserting "the
    mention is itself the launch" (correct for the `sh` twin) would false-fail
    that shape, so the two halves are checked as they are actually written:
    every non-comment mention must bind `$Target`, and a genuine invocation of
    that same variable must exist."""
    mentions = _non_comment_mentions(text, "#")
    binds_target = bool(mentions) and all(
        re.match(r"\s*\$Target\s*=\s*Join-Path\b", line) for line in mentions
    )
    launches_target = any(
        re.search(r"^\s*&\s+\$python\.Path\s+\$Target\b", line)
        for line in text.splitlines()
    )
    return binds_target and launches_target


def _non_comment_mentions(text, comment_prefix):
    return [
        line for line in text.splitlines()
        if f"{VALIDATOR_STEM}.py" in line and not line.strip().startswith(comment_prefix)
    ]


def run_wrapper_shape_check(counts):
    """The `.sh`/`.ps1` twins are thin dispatchers over the single Python
    implementation (Epic A4 wrapper precedent): each one's every non-comment
    mention of the `.py` file participates in a real process launch, and
    neither wrapper carries a check-id of its own -- so cross-runtime identity
    is a structural consequence of single-sourcing rather than two copies that
    merely agree today."""
    dispatch_checks = {"sh": _sh_wrapper_dispatches, "ps1": _ps1_wrapper_dispatches}
    for suffix in ("sh", "ps1"):
        path = LIVE_SCRIPTS / f"{VALIDATOR_STEM}.{suffix}"
        if not path.is_file():
            counts.check(False, f"{VALIDATOR_STEM}.{suffix}: wrapper exists",
                         "TDD RED: wrapper absent")
            continue
        text = path.read_text(encoding="utf-8")
        dispatches = dispatch_checks[suffix](text)
        carries_check_id = any(check_id in text for check_id in CHECK_ID_ENUM)
        counts.check(
            dispatches and not carries_check_id,
            f"{VALIDATOR_STEM}.{suffix}: dispatches to the single .py "
            f"implementation via a real process launch, and carries no "
            f"check-id of its own",
            f"dispatches={dispatches} carries_check_id={carries_check_id} "
            f"mentions={_non_comment_mentions(text, '#')!r}",
        )


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--launcher", choices=("sh", "ps1"), required=True)
    args = parser.parse_args()
    counts = Counts()

    case_names = load_json(FIXTURES / "INDEX.json")["cases"]
    required = [LIVE_SCRIPTS / f"{VALIDATOR_STEM}.{suffix}" for suffix in ("py", "sh", "ps1")]
    if not all(path.is_file() for path in required):
        for name in case_names:
            counts.check(False, f"{name}: validator exists at its Planned Files path",
                         "TDD RED: implementation absent")
    else:
        for name in case_names:
            run_case(args.launcher, name, counts)

    run_enum_completeness_check(counts)
    run_ordering_check(counts)
    run_b7_keying_check(counts)
    run_journal_pair_check(counts)
    run_wrapper_shape_check(counts)

    sh_registered = f"tests/{VALIDATOR_STEM}.tests.sh" in (ROOT / "tests/run-all.sh").read_text(encoding="utf-8")
    ps_registered = f"tests/{VALIDATOR_STEM}.tests.ps1" in (ROOT / "tests/run-all.ps1").read_text(encoding="utf-8")
    counts.check(sh_registered, "POSIX suite registered in tests/run-all.sh")
    counts.check(ps_registered, "PowerShell suite registered in tests/run-all.ps1")

    print(f"RESULT: {counts.passed} passed, {counts.failed} failed")
    return 1 if counts.failed else 0


if __name__ == "__main__":
    sys.exit(main())
