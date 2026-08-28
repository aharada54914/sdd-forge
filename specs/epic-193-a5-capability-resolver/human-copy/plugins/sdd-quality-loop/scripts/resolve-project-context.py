#!/usr/bin/env python3
"""Capability Resolver, implementation stages T-002+T-003+T-004 (steps 0-13).

T-002 validates CLI input, derives Resolver state, obtains a single canonical
Project Context snapshot, and assembles/canonicalizes the Context Projection
in memory (steps 0-3). T-003 extends the same Python master with
affected-component resolution (`resolve-component-paths`), Registry
discovery + validation (ADR-0025 discovery + `validate-capability-registry`),
`registry_digest` (`generate-registry-digest --whole`), per-Capability/
per-affected-component trigger evaluation, matched-Capability
conditional-facet evaluation (both via `evaluate-predicate`), and the
any-branch WARN check (steps 4-9). T-004 completes the staged-only pipeline:
the track branch (Facet Manifest on `full`, Capability Summary on `lite`,
never both -- B4), Resolver Evidence assembly (context_binding/resolver
provenance canonicalization, B9), output schema self-validation against
every staged artifact's own governing schema (B3), and the pre-publication
snapshot recheck (B8 TOCTOU) (steps 10-13). Every step 0-13 result is staged
in memory only. T-007 completes the pipeline with the two halves of
design.md's own "Resolver publication transactional bundle contract": the
mandatory crash-recovery scan (step 0.5 -- run by every invocation,
immediately after argument validation, scoped to this invocation's own
`--feature`), and the journaled publication transaction (step 14 --
Prepare/Journal/Commit/Post-publication verification/Complete).

This script has exactly TWO live-filesystem write routes, and design.md
requires both to be exactly what they are:

  1. The journaled transaction (step 14). Every MULTI-target publication
     goes through it -- a successful Full-track run publishes three targets,
     a successful Lite-track run two -- so that the set lands atomically or
     not at all, never a bare per-file `rename()` with no cross-file
     atomicity and no crash-safe rollback.

  2. A direct `temp file + fsync + rename` for the Block case, where
     Resolver Evidence is the WHOLE write set. design.md:1419 and :2846
     both require this write to be direct, with no staging area and no
     journal: a one-file write needs no cross-file atomicity, and opening a
     second journal against the very Feature whose existing journal this
     invocation has just declared unconvergeable would be incoherent.

An earlier revision of this docstring said step 14 was the sole write route
and that a Block published "via the identical journaled mechanism". That was
never what design.md required, and it is not what this script does; it is
corrected here rather than left to mislead a reader of a Security-Sensitive
file whose Standing Note tells reviewers to trust these descriptions.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


EXIT_BLOCK = 1
EXIT_USAGE = 2
FEATURE_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
EVIDENCE_SCHEMA = "sdd-resolver-evidence/v1"

# T-004 (steps 10-13): resolver.version/resolver.rule_set_revision
# single-source-of-truth + canonical-preimage rules (Data Plan "B9", no
# upstream rule fixed either). RESOLVER_VERSION is this feature's own
# single source of truth -- the .sh/.ps1 dispatchers never read, duplicate,
# or independently derive it, so .py/.sh/.ps1 parity (REQ-005/AC-023) is
# structural. Mutated only via scripts/bump-version.sh (REQ-008/AC-034),
# matching Epic A3's own identical `resolve-component-paths.py:
# RESOLVER_VERSION` precedent. RULE_SET_REVISION is the sha256 of a fixed,
# versioned canonical string identifying *which revision of this feature's
# own orchestration rule set* (union-match, WARN-Block scope, facet-name
# aggregation, the REQ-002 Block taxonomy) produced a given Resolver
# Evidence instance -- never a hash of any input file, so it is identical
# across every invocation of the same Resolver revision.
RESOLVER_VERSION = "1.0.0"
RULE_SET_STRING = "sdd-resolver-rule-set/v1"
RULE_SET_REVISION = "sha256:" + hashlib.sha256(RULE_SET_STRING.encode("utf-8")).hexdigest()

# T-004 step 12's own governing-schema filenames (ADR-0025 discovery,
# `_discover_governing_schema` below).
FACET_MANIFEST_SCHEMA_FILENAME = "facet-manifest.schema.json"
CAPABILITY_SUMMARY_SCHEMA_FILENAME = "capability-summary.schema.json"
CONTEXT_PROJECTION_SCHEMA_FILENAME = "context-projection.schema.json"
RESOLVER_EVIDENCE_SCHEMA_FILENAME = "resolver-evidence.schema.json"


class CanonicalizerFailed(Exception):
    pass


class CanonicalizerOutputMalformed(Exception):
    pass


class AffectedComponentResolutionFailed(Exception):
    """`resolve-component-paths` itself exited non-zero (step 4)."""

    def __init__(self, returncode):
        super().__init__(f"resolve-component-paths exited {returncode}")
        self.returncode = returncode


class ContractDiscoveryFailed(Exception):
    """ADR-0025 discovery/version-check failure for a Registry artifact
    (step 5's own `contract-discovery-failed` half)."""


class RegistryValidationFailed(Exception):
    """`validate-capability-registry` (step 5) or a `PREDICATE_SCHEMA_ERROR`
    exit from `evaluate-predicate` (steps 7/8) -- both are, by construction,
    a Registry validation defect this feature did not itself introduce."""


class DependencySubprocessFailed(Exception):
    """A dependency subprocess's own generic, otherwise-unnamed non-zero
    exit (B3's closed-enum catch-all) -- `generate-registry-digest` (step 6)
    or `evaluate-predicate` (steps 7/8), for a reason other than an internal
    canonicalizer failure or a `PREDICATE_SCHEMA_ERROR`."""


class AffectedComponentAbsentFromContext(Exception):
    """Ruling C(2) (human-approved 2026-08-26): `resolve-component-paths`
    returned an `affected_components[]` entry naming a component id absent
    from this invocation's own Context Projection -- a dependency result
    inconsistent with the canonical Context it was derived against. Maps to
    `dependency-output-malformed` (REQ-002's amended row); steps 7-8 MUST
    NOT evaluate such an entry against an empty or defaulted properties
    document."""


class DependencyOutputMalformed(Exception):
    """A dependency subprocess exited zero but its own stdout does not
    parse as the JSON/digest shape that dependency's own contract promises
    (B3)."""


class LiteCheckSourceUndefined(Exception):
    """Step 10b's own Block condition (B5-narrowed): `spec_profile ==
    lite`, `capability_enforcement == required`, and at least one matched
    Capability's own `lite_policy.required_lite_checks` key is absent.
    Carries that Capability's own id for the diagnostic detail."""


class OutputSchemaValidationFailed(Exception):
    """Step 12 (B3): a staged artifact failed its own defensive output
    schema self-validation. `artifact_name` is one of "resolver-evidence"
    (the sole case where nothing is written to any live path at all),
    "context-projection", "facet-manifest", or "capability-summary"."""

    def __init__(self, artifact_name):
        super().__init__(artifact_name)
        self.artifact_name = artifact_name


class SnapshotGenerationMismatch(Exception):
    """Step 13 (B8 TOCTOU): the pre-publication recheck of the Project
    Context/Registry/ownership-source snapshot, including a fresh
    re-derivation of `affected_components` (not only `ownership_digest`),
    no longer matches this invocation's own step-2/4/5-6 snapshot."""


def _reject_json_constant(token):
    raise ValueError(f"non-standard JSON constant {token}")


def _parse_args(argv):
    parser = argparse.ArgumentParser(prog="resolve-project-context.py")
    parser.add_argument("--config", required=True)
    parser.add_argument("--source-rev", default="HEAD")
    parser.add_argument("--target-rev", required=True)
    parser.add_argument("--include-untracked", action="store_true")
    parser.add_argument("--feature", required=True)
    args = parser.parse_args(argv)
    if not FEATURE_RE.fullmatch(args.feature):
        parser.error("--feature must match ^[a-z0-9][a-z0-9-]*$")
    return args


def _find_repo_root(config_path):
    candidate = config_path if config_path.is_absolute() else Path.cwd() / config_path
    for parent in (candidate.parent, *candidate.parent.parents):
        if (parent / ".git").exists():
            return parent
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=Path.cwd(), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            check=False,
        )
    except OSError:
        result = None
    if result is not None and result.returncode == 0:
        return Path(result.stdout.decode("utf-8").strip())
    return Path.cwd()


def _canonicalizer_argv(input_path, input_format):
    script_dir = Path(__file__).resolve().parent
    python_master = script_dir / "canonicalize-sdd-yaml.py"
    shell_wrapper = script_dir / "canonicalize-sdd-yaml.sh"
    if python_master.is_file():
        return [sys.executable, str(python_master), str(input_path), "--input-format", input_format]
    if shell_wrapper.is_file():
        return [str(shell_wrapper), str(input_path), "--input-format", input_format]
    return ["canonicalize-sdd-yaml", str(input_path), "--input-format", input_format]


def _canonicalize(input_path, input_format):
    try:
        result = subprocess.run(
            _canonicalizer_argv(input_path, input_format),
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False,
        )
    except OSError as exc:
        raise CanonicalizerFailed(str(exc)) from exc
    if result.returncode != 0:
        raise CanonicalizerFailed(f"exit {result.returncode}")
    try:
        text = result.stdout.decode("utf-8")
        parsed = json.loads(text, parse_constant=_reject_json_constant)
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        raise CanonicalizerOutputMalformed(str(exc)) from exc
    return result.stdout, parsed


def _repo_relative(path, repo_root):
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def _repo_relative_target(path, repo_root):
    """`_repo_relative` for a PUBLICATION TARGET, which must name the LEXICAL
    directory entry the commit will replace -- never a symlink's referent.

    Introduced 2026-08-28 (openai panel slot, round 11 Major) as the necessary
    companion to ruling (b). Narrowing `_target_escapes_via_symlink` to the
    target's parent made a symlink AT the leaf acceptable, which is correct
    for the write -- `os.replace` replaces that entry rather than following
    it. But `_repo_relative` resolves the whole path, so the journal would
    then record the symlink's REFERENT while the commit replaced the lexical
    entry. Rollback and crash recovery both work from the recorded path, so
    they would restore or validate the referent and leave the entry the commit
    actually wrote still holding its POST bytes: a rollback that reports
    success and did not undo the publication, and a journal the recovery scan
    cannot converge.

    The rule here is therefore the SAME rule the containment check uses --
    resolve the parent, join the leaf by name -- and it must stay the same
    rule. A check and a journal that disagree about what "the target" means
    reintroduce exactly this class of defect."""
    parent_real = Path(os.path.realpath(str(path.parent)))
    lexical = parent_real / path.name
    try:
        return lexical.relative_to(Path(os.path.realpath(str(repo_root)))).as_posix()
    except ValueError:
        return lexical.as_posix()


def _reemit_dependency_stderr(result):
    """B5 (security-spec.md)/REQ-005: "a dependency subprocess's own
    stderr remains visible to a human operator on the terminal exactly as
    that subprocess itself already writes it, but never participates in
    this feature's own byte-identity comparison" -- design.md's API/
    Contract Plan step 4 and the frozen requirements.md sentence both
    repeat this verbatim as the reason the canonical `<detail>` field is
    allowed to omit upstream stderr entirely. Confirmation-panel Major
    (2026-08-24, both vendors): this feature previously captured every
    dependency's stderr via `subprocess.PIPE` and never wrote it back out
    anywhere, making the operator-visibility half of that sentence false
    -- the operator saw only this feature's own canonical line, pointing
    at diagnostics it had itself swallowed. Re-emits the dependency's own
    captured bytes to this process's own stderr, VERBATIM (raw bytes, not
    decoded/re-encoded, so no transcoding can alter what the subprocess
    itself wrote) -- called at each dependency call site immediately
    after that subprocess exits, always before this feature's own later
    `_block`/`_block_no_write` canonical diagnostic line is written, so
    the canonical line always stays the LAST line on this process's own
    stderr. A no-op when the dependency wrote nothing (the common case on
    a clean, non-Block exit)."""
    if not result.stderr:
        return
    try:
        sys.stderr.buffer.write(result.stderr)
        sys.stderr.buffer.flush()
    except AttributeError:
        sys.stderr.write(result.stderr.decode("utf-8", errors="replace"))
        sys.stderr.flush()


def _script_argv(script_dir, base_name, tail):
    python_master = script_dir / f"{base_name}.py"
    shell_wrapper = script_dir / f"{base_name}.sh"
    if python_master.is_file():
        return [sys.executable, str(python_master)] + tail
    if shell_wrapper.is_file():
        return [str(shell_wrapper)] + tail
    return [base_name] + tail


def _run_resolve_component_paths(script_dir, args):
    """Step 4: invoke `resolve-component-paths` with this invocation's own
    `--config`/`--source-rev`/`--target-rev`/`--include-untracked` values
    passed through verbatim -- no rev resolution, merge-base computation, or
    diff-basis logic performed here.

    `--include-untracked` is this feature's own CLI's sole bracketed,
    optional flag (`_parse_args`, `action="store_true"`, no `--no-...`
    counterpart of its own): its own argparse namespace cannot distinguish
    "the caller explicitly omitted it" from any other false-ish state, so
    the identical omission is the only value this invocation could ever
    pass through verbatim. AC-004/design.md step 4 both spell the
    dependency's own flag as bracketed-optional (`[--include-untracked]`),
    passed only when supplied -- never synthesizing the dependency's own
    separate `--no-include-untracked` flag as a stand-in for "not supplied"
    (cross-model panel finding, T-003 NEEDS_WORK cycle 2): that flag is not
    part of this feature's own CLI contract at all, and always emitting one
    of the two turns a caller's genuine omission into an explicit,
    unrequested `false`, diverging from `resolve-component-paths`'s own
    default (`True`) whenever this invocation's own caller never mentioned
    the flag either way."""
    tail = [
        "--config", args.config,
        "--source-rev", args.source_rev,
        "--target-rev", args.target_rev,
    ]
    if args.include_untracked:
        tail.append("--include-untracked")
    tail.append("--json")
    argv = _script_argv(script_dir, "resolve-component-paths", tail)
    try:
        result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    except OSError as exc:
        # A launch failure (missing binary, unreadable/non-executable
        # wrapper) never produced an exit code at all, so it cannot be
        # formatted through AffectedComponentResolutionFailed's own
        # returncode-shaped canonical sentence (that constructor's sole
        # parameter is a returncode, not a string) -- doing so is exactly
        # the panelist-caught defect: the raw OSError text (an absolute
        # path, an errno) would otherwise land in the committed Resolver
        # Evidence, violating both AC-014's canonical-sentence rule and
        # security-spec.md B5's no-local-path containment. Instead, this
        # sub-case is folded into the SAME closed-enum, fixed-sentence
        # DependencySubprocessFailed path steps 5/6/7-8 already use for an
        # identical OSError on their own subprocess.run calls -- main()'s
        # own handler discards this exception's payload entirely.
        raise DependencySubprocessFailed(f"launch failed: {exc}") from exc
    _reemit_dependency_stderr(result)
    if result.returncode != 0:
        raise AffectedComponentResolutionFailed(result.returncode)
    try:
        parsed = json.loads(result.stdout.decode("utf-8"), parse_constant=_reject_json_constant)
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        raise DependencyOutputMalformed(str(exc)) from exc
    if not isinstance(parsed, dict):
        raise DependencyOutputMalformed("resolve-component-paths stdout is not a JSON object")
    affected_components = parsed.get("affected_components")
    # `context_binding` is untrusted dependency output: a truthy
    # NON-OBJECT value (bare string/array/number) escaped the `or {}`
    # fallback and crashed `.get` with an uncaught AttributeError instead
    # of the canonical Block (route-(a) cross-model panel round-5 Major;
    # fixture `resolve-component-paths-binding-not-object`). Type-check
    # before field access; a non-dict binding leaves ownership_digest
    # None, which the validation below rejects under this site's existing
    # canonical sentence.
    context_binding = parsed.get("context_binding")
    ownership_digest = (
        context_binding.get("ownership_digest")
        if isinstance(context_binding, dict)
        else None
    )
    if not isinstance(affected_components, list) or not all(isinstance(c, str) for c in affected_components):
        raise DependencyOutputMalformed("resolve-component-paths stdout has no valid affected_components array")
    # A duplicate component id is malformed dependency output (Epic A3's
    # own contract guarantees unique ids; REQ-004 binds every
    # capability_evaluations[] entry to EXACTLY one trigger_evaluations[]
    # element per affected component). Without this rejection the
    # duplicate fans out into two evaluations per capability and two warn
    # diagnostics for the same node, publishing Evidence that violates
    # REQ-004's exact-set rule while still passing the step-12 schema
    # self-validation (route-(a) cross-model panel round-4 Major; fixture
    # `affected-component-duplicate-ids`).
    if len(set(affected_components)) != len(affected_components):
        raise DependencyOutputMalformed("resolve-component-paths returned duplicate affected component ids")
    if not isinstance(ownership_digest, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", ownership_digest):
        raise DependencyOutputMalformed("resolve-component-paths stdout has no valid context_binding.ownership_digest")
    return affected_components, ownership_digest


def _discover_registry(script_dir):
    """Step 5, discovery half: ADR-0025's own script-relative-then-git-root-
    fallback procedure (reused unmodified via Epic A2's own
    `registry_discovery` module, co-located with this script at its
    deployed, protected-suffix destination) for both `capability-
    registry.json` and its own `capability-registry.schema.json`.

    Cross-model panel Minor (Anthropic, raised against BOTH T-003 and
    T-004 and re-raised in every round since): the `sys.path` prepend
    below was never restored -- no `try`/`finally`, no `importlib.util.
    spec_from_file_location` -- so the deployed scripts directory stayed
    permanently ahead of the stdlib on `sys.path` for the whole remaining
    life of the process, and any later stdlib-shadowing module dropped
    into that directory would win import resolution for every subsequent
    import anywhere in the process. On a `Security-Sensitive: true` task
    that is a real, if narrow, import-hijack surface. The prepend is now
    scoped to exactly the window that needs it -- the sibling-module
    import plus the discovery calls that use it -- and removed in a
    `finally` so every exit path (clean return, `ContractDiscoveryFailed`,
    or any unexpected exception) restores it. Removal is by VALUE via
    `list.remove`, which drops only the FIRST occurrence: if `script_dir`
    was already on `sys.path` before this call (the common case, since
    Python puts the running script's own directory there), that
    pre-existing entry is deliberately left intact and only this
    function's own duplicate is taken back off."""
    inserted_path_entry = str(script_dir)
    sys.path.insert(0, inserted_path_entry)
    try:
        return _discover_registry_with_sibling_module()
    finally:
        try:
            sys.path.remove(inserted_path_entry)
        except ValueError:  # pragma: no cover -- only if a callee mutated sys.path
            pass


def _discover_registry_with_sibling_module():
    """`_discover_registry`'s own body, split out so the `sys.path`
    prepend above can own a single `try`/`finally` covering every exit
    path rather than repeating the restore at each `raise` site. Runs
    with `script_dir` on `sys.path`; never re-reads `script_dir` itself
    (verified: no reference to it survives below this point)."""
    try:
        import registry_discovery  # noqa: E402  (deliberately deferred: co-located sibling module)
    except Exception as exc:  # noqa: BLE001 (deliberately broad -- see below)
        # Cross-model confirmation-panel finding (Anthropic T-003 Minor
        # B5): a co-located sibling-module import failure for any reason
        # OTHER than ImportError (a SyntaxError, or any exception raised
        # at that module's own top level) previously escaped this site's
        # narrow `except ImportError` uncaught -- a raw Python traceback,
        # no `capability-resolver:` diagnostic line, no Resolver Evidence
        # written at all, exactly the failure mode the registry-
        # discovery-unimportable fixture exists to close, and (since a
        # SyntaxError's own `str()` embeds the failing file's absolute
        # path) a security-spec.md B5 no-local-path-in-committed-output
        # containment bypass. Widened to the broad `except Exception` a
        # module-level import genuinely warrants; only the exception's
        # own CLASS NAME is interpolated below, never `str(exc)` -- the
        # identical containment rule `_load_governing_schema` (step 12)
        # already applies to its own read/parse failure two sections
        # below, reused here rather than reinvented.
        raise ContractDiscoveryFailed(
            f"registry_discovery module not importable ({type(exc).__name__})"
        ) from exc

    try:
        registry_path = registry_discovery.discover_artifact("capability-registry.json")
        registry_discovery.discover_artifact("capability-registry.schema.json")
    except registry_discovery.DiscoveryError as exc:
        raise ContractDiscoveryFailed(str(exc)) from exc
    try:
        registry_raw = registry_path.read_bytes()
        registry_document = json.loads(registry_raw.decode("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ContractDiscoveryFailed(str(exc)) from exc
    # Ruling C(1) (human-approved 2026-08-26, design.md's sanctioned third
    # recheck): `validate-capability-registry` and `generate-registry-digest
    # --whole` each independently re-discover and re-read the SAME
    # `registry_path` with no binding to THIS read. The raw-bytes digest
    # retained here is this invocation's own single snapshot identity for
    # `registry_path`, compared by `_recheck_registry_snapshot` (below)
    # immediately after those two dependency invocations complete
    # (step 6.5, REQ-002's amended second trigger site).
    registry_snapshot_digest = hashlib.sha256(registry_raw).hexdigest()
    return registry_path, registry_document, registry_snapshot_digest


def _recheck_registry_snapshot(registry_path, expected_digest):
    """Step 6.5 (ruling C(1), human-approved 2026-08-26): detection-only
    Registry recheck, now spec-sanctioned as design.md's third recheck and
    REQ-002's amended second `snapshot-generation-mismatch` trigger site.
    This invocation re-reads the SAME `registry_path` its own
    `_discover_registry` call already resolved, right after
    `validate-capability-registry` and `generate-registry-digest --whole`
    have each independently read the Registry on their own, and compares
    the fresh bytes' own digest against the one retained at
    `_discover_registry`'s own first read. Any difference -- including this
    re-read itself failing outright, which is at least as suspicious as a
    genuine byte difference -- raises SnapshotGenerationMismatch (the
    step-13 recheck reuses the identical diagnostic id).

    Honesty limitation (unchanged from the recheck's first, pre-ruling
    incarnation): this detects a Registry swap across THIS invocation's own
    read window; it cannot observe what bytes those two subprocesses
    themselves actually read inside their own separate processes."""
    try:
        current_raw = registry_path.read_bytes()
    except OSError as exc:
        raise SnapshotGenerationMismatch(f"registry re-read failed: {exc}") from exc
    if hashlib.sha256(current_raw).hexdigest() != expected_digest:
        raise SnapshotGenerationMismatch("registry bytes changed since discovery")


def _validate_capability_registry(script_dir, registry_path):
    """Step 5, validation half: Epic A2's own `validate-capability-registry`
    checks (a)-(i), run against the located Registry as a real subprocess.

    A launch failure (missing binary, unreadable/non-executable wrapper) is
    a local-environment fault, never a defect in the Registry itself, so it
    is routed through the SAME closed-enum, fixed-sentence
    DependencySubprocessFailed path steps 4/6/7-8 already use for an
    identical OSError on their own subprocess.run calls -- never
    RegistryValidationFailed, whose own `registry-validation-failed`
    diagnostic id REQ-002 defines as "the located Registry fails ...
    validate-capability-registry checks", which blames the project's own
    Registry content for a fault this invocation's own environment caused
    (cross-model panel finding, T-003 NEEDS_WORK cycle 2 -- this step
    previously contradicted the launch-vs-outcome rule this same file
    already states at step 4)."""
    argv = _script_argv(script_dir, "validate-capability-registry", ["--registry", str(registry_path)])
    try:
        result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    except OSError as exc:
        raise DependencySubprocessFailed(f"launch failed: {exc}") from exc
    _reemit_dependency_stderr(result)
    if result.returncode != 0:
        raise RegistryValidationFailed(f"exit {result.returncode}")


def _generate_registry_digest_whole(script_dir):
    """Step 6: `generate-registry-digest --whole` against the located
    Registry (the tool performs its own, identical ADR-0025 discovery).
    A canonicalizer failure inside that invocation is surfaced by the
    dependency's own stable `canonicalizer-failed:` error-class prefix
    (never this feature's own raw-stderr-embedding -- M8 -- this is a
    fixed, stable token this feature classifies control flow on, not a
    verbatim quotation placed into this feature's own emitted `detail`)."""
    argv = _script_argv(script_dir, "generate-registry-digest", ["--whole"])
    try:
        result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    except OSError as exc:
        raise DependencySubprocessFailed(f"launch failed: {exc}") from exc
    _reemit_dependency_stderr(result)
    if result.returncode != 0:
        # Confirmation-panel Minor (Anthropic T-003, unanchored token):
        # a whole-stream substring search for `canonicalizer-failed`
        # could be steered by Registry content this dependency's own
        # error message happens to echo back mid-line. Anchored to
        # `generate-registry-digest`'s own fixed `"generate-registry-
        # digest: canonicalizer-failed: ..."` line-start format
        # (`generate-registry-digest.py`'s own sole stderr `print`
        # call), matching `_invoke_evaluate_predicate`'s identical
        # line-start-anchored classification above.
        stderr_lines = result.stderr.decode("utf-8", errors="replace").splitlines()
        if any(line.startswith("generate-registry-digest: canonicalizer-failed") for line in stderr_lines):
            raise CanonicalizerFailed("generate-registry-digest")
        raise DependencySubprocessFailed(f"exit {result.returncode}")
    try:
        text = result.stdout.decode("ascii").strip()
    except UnicodeDecodeError as exc:
        raise DependencyOutputMalformed(str(exc)) from exc
    if not re.fullmatch(r"[0-9a-f]{64}", text):
        raise DependencyOutputMalformed("generate-registry-digest stdout is not a bare 64-hex digest")
    return "sha256:" + text


def _evaluate_predicate(script_dir, predicate, properties):
    """Steps 7/8's own shared per-(capability-or-facet, component) call:
    `evaluate-predicate --predicate <path> --component-properties <path>`.
    Both arguments are written to their own temp file (rather than `-`)
    since exactly one stdin stream cannot carry two independent documents."""
    # Confirmation-panel Minor (Anthropic T-003, temp-file leak): the two
    # `mkstemp` calls previously both executed before either was inside a
    # `try`/`finally` -- if the SECOND call raised (ENOSPC, EMFILE, TMPDIR
    # removed between the two calls), the FIRST descriptor and its
    # on-disk temp file leaked for this process's own lifetime, since the
    # single outer `finally` below only ever runs once both names are
    # already bound. The second `mkstemp` is now nested inside the first
    # temp file's own `try`/`finally`, so a failure there still cleans up
    # the first.
    predicate_fd, predicate_name = tempfile.mkstemp(suffix=".json")
    try:
        with os.fdopen(predicate_fd, "w", encoding="utf-8") as handle:
            json.dump(predicate, handle, ensure_ascii=False, separators=(",", ":"))
        properties_fd, properties_name = tempfile.mkstemp(suffix=".json")
        try:
            with os.fdopen(properties_fd, "w", encoding="utf-8") as handle:
                json.dump(properties, handle, ensure_ascii=False, separators=(",", ":"))
            return _invoke_evaluate_predicate(script_dir, predicate_name, properties_name)
        finally:
            os.unlink(properties_name)
    finally:
        os.unlink(predicate_name)


def _invoke_evaluate_predicate(script_dir, predicate_name, properties_name):
    """The real dependency invocation half of `_evaluate_predicate`,
    split out so the outer function's own two temp-file `try`/`finally`
    blocks (above) stay uncluttered by this call's own logic."""
    argv = _script_argv(
        script_dir, "evaluate-predicate",
        ["--predicate", predicate_name, "--component-properties", properties_name],
    )
    try:
        result = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    except OSError as exc:
        raise DependencySubprocessFailed(f"launch failed: {exc}") from exc
    _reemit_dependency_stderr(result)
    if result.returncode != 0:
        # Cross-model panel finding (T-003 NEEDS_WORK cycle 3): this
        # branch previously keyed the PREDICATE_SCHEMA_ERROR ->
        # registry-validation-failed mapping on a hardcoded `returncode
        # == 2` magic number. `evaluate-predicate`'s own contract
        # (investigation.md's predicate-DSL-evaluator section) fixes
        # only a stable stderr token -- "a distinct, non-zero-exit
        # PREDICATE_SCHEMA_ERROR" -- never a specific exit code; the
        # SAME stable-stderr-token classification `_generate_registry_
        # digest_whole` (step 6) already uses for its own
        # `canonicalizer-failed` sub-branch is reused here rather than
        # trusting an unfixed number a future revision of `evaluate-
        # predicate.py` could change without notice.
        #
        # Confirmation-panel Minor (Anthropic T-003, unanchored token):
        # both this classification and `_generate_registry_digest_whole`'s
        # own `canonicalizer-failed` classification below previously
        # searched anywhere in the whole stderr stream for their stable
        # token -- a Registry-supplied string value that happened to
        # embed the literal token verbatim (echoed back by a dependency's
        # own error message) could steer a generic dependency failure
        # into the wrong Block id. Anchored to the STABLE ERROR-CLASS
        # PREFIX each dependency's own contract fixes (`evaluate-
        # predicate`'s own `PREDICATE_SCHEMA_ERROR: ...` lines always
        # start the line, never appear embedded mid-sentence; same for
        # `generate-registry-digest`'s own `canonicalizer-failed: ...`),
        # via a per-line, line-start check rather than a whole-stream
        # substring search -- Registry/predicate content embedded
        # mid-line can no longer steer this classification.
        stderr_lines = result.stderr.decode("utf-8", errors="replace").splitlines()
        if any(line.startswith("PREDICATE_SCHEMA_ERROR") for line in stderr_lines):
            raise RegistryValidationFailed("PREDICATE_SCHEMA_ERROR")
        raise DependencySubprocessFailed(f"exit {result.returncode}")
    try:
        parsed = json.loads(result.stdout.decode("utf-8"), parse_constant=_reject_json_constant)
    except (UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        raise DependencyOutputMalformed(str(exc)) from exc
    if (
        not isinstance(parsed, dict)
        or not isinstance(parsed.get("result"), bool)
        or not _evidence_tree_well_formed(parsed.get("evidence"))
    ):
        raise DependencyOutputMalformed("evaluate-predicate stdout is not the {result, evidence} shape")
    return parsed["result"], parsed["evidence"]


_EVIDENCE_NODE_KEYS = frozenset(("operator", "path", "outcome", "reason", "children"))
_EVIDENCE_NODE_OPERATORS = frozenset(
    ("all", "any", "not", "equals", "not_equals", "contains", "in", "exists")
)
_EVIDENCE_NODE_OUTCOMES = frozenset(("match", "no-match", "warn"))


def _evidence_tree_well_formed(nodes):
    """Recursive validation of an evaluate-predicate Evidence tree against
    the SAME node contract the published Resolver Evidence embeds it under
    (contracts/resolver-evidence.schema.json #/definitions/evidenceNode):
    `nodes` must be a list; every element at EVERY depth must be an object
    with no keys beyond the contract's five, a required enum-valid
    `operator`, a required string-or-null `path`, a required enum-valid
    `outcome` (with `reason` a string, mandatory when `outcome` is
    "warn"), and a `children` value that -- when present -- is itself a
    well-formed subtree (null children are rejected: the contract types
    children as an array). History: the original step-7 check validated
    only top-level object-ness (round-2 panel Major: a nested bare string
    crashed `_iter_warn_nodes` with an uncaught AttributeError); the
    structural-only recursion that fixed it still accepted field-invalid
    nodes, which then flowed into the published Evidence and were
    MISATTRIBUTED downstream as `output-schema-validation-failed` at the
    step-12 self-validation instead of Blocking
    `dependency-output-malformed` at their upstream source (round-3 panel
    Major; fixture `evaluate-predicate-output-malformed-nested`)."""
    if not isinstance(nodes, list):
        return False
    for node in nodes:
        if not isinstance(node, dict):
            return False
        if not set(node) <= _EVIDENCE_NODE_KEYS:
            return False
        # Enum membership MUST be hash-safe: `x in <frozenset>` hashes x,
        # so a JSON array/object arriving in an enum-checked field of the
        # untrusted dependency payload would raise TypeError instead of
        # returning False (gate cycle-7 Critical; fixture
        # `evaluate-predicate-output-malformed-unhashable`). Both enums
        # contain only strings, so the isinstance guard loses nothing.
        operator = node.get("operator")
        if not isinstance(operator, str) or operator not in _EVIDENCE_NODE_OPERATORS:
            return False
        if "path" not in node or not (
            node["path"] is None or isinstance(node["path"], str)
        ):
            return False
        outcome = node.get("outcome")
        if not isinstance(outcome, str) or outcome not in _EVIDENCE_NODE_OUTCOMES:
            return False
        if "reason" in node and not isinstance(node["reason"], str):
            return False
        if node["outcome"] == "warn" and not isinstance(node.get("reason"), str):
            return False
        if "children" in node and not _evidence_tree_well_formed(node["children"]):
            return False
    return True


def _iter_warn_nodes(evidence_nodes, node_path=()):
    """Depth-first, declaration-order walk of an Evidence tree, yielding
    `(node, node_path)` for every `outcome: "warn"` node at any depth
    (step 9, B2's own any-branch, any-depth scope; AC-056). `node_path` is
    the 0-based child-index path from this tree's own root -- a stable,
    always-distinct positional identifier for a warn node even when two
    leaves happen to share an identical `field`/`operator`/`reason`."""
    for index, node in enumerate(evidence_nodes):
        this_path = node_path + (index,)
        if node.get("outcome") == "warn":
            yield node, this_path
        yield from _iter_warn_nodes(node.get("children") or [], this_path)


def _evidence_has_warn(evidence_nodes):
    """Depth-first scan for an `outcome: "warn"` node anywhere in an
    Evidence tree (step 9, B2's own any-branch, any-depth scope)."""
    for _ in _iter_warn_nodes(evidence_nodes):
        return True
    return False


def _warn_diagnostic_detail(capability_id, component_id, declaration_index, node_path, node):
    """AC-056: one `severity: "warn"` diagnostics[] entry's own `detail`
    per individual `outcome: "warn"` DSL-evaluation node, naming that
    node's own `capability_id`/`component_id`/(`declaration_index`, only
    for a `conditional_facets[].when` node -- requirements.md REQ-004's
    own diagnostics[] severity paragraph, AC-056) location plus its own
    tree position/DSL attributes -- guaranteeing a distinct `detail` per
    node even across two nodes sharing an identical location (AC-024
    no-`(id, detail)`-repeat), and always distinct from the summary
    `severity: "block"` entry's own fixed sentence (below), which carries
    no location suffix at all.

    Cross-model confirmation-panel Minor (Anthropic T-003): REQ-004
    scopes `declaration_index` to a `when` node only -- a trigger-
    evaluation node (the caller's own `None` sentinel) never carries that
    key at all, not even as a literal `declaration_index=None`. The
    `location` text below omits the `declaration_index=...` clause
    entirely when `declaration_index is None`, rather than rendering it
    unconditionally."""
    location = f"capability_id={capability_id!r} component_id={component_id!r}"
    if declaration_index is not None:
        location += f" declaration_index={declaration_index!r}"
    node_position = ".".join(str(index) for index in node_path)
    return (
        f"a predicate evaluation produced an outcome: warn evidence node at {location} "
        f"(node_path={node_position!r}, operator={node.get('operator')!r}, "
        f"field={node.get('path')!r}, reason={node.get('reason')!r})"
    )


def _evaluate_capabilities(
    script_dir, registry_document, affected_components, projection_components,
    capability_evaluations, warn_diagnostics,
):
    """Steps 7-8. Every Registry Capability, matched or not, is evaluated in
    full against every affected component, in Registry-declaration order
    (capabilities) and ascending-lexicographic order (affected_components,
    explicitly sorted at this fan-out -- REQ-005/AC-024 determinism, never
    assumed pre-sorted from `resolve-component-paths`, whose own contract
    makes no ordering guarantee, investigation.md INV-006) -- no
    short-circuit on any individual evaluation's own outcome. `capability_
    evaluations` is mutated in place (appending one complete entry per
    Capability only after that Capability's own evaluation set is fully
    built) so a caller can still read every already-completed entry if a
    dependency subprocess failure aborts this function partway through.
    ADJUDICATED (recorded in T-003.contract.json 'FINDINGS REJECTED WITH
    EVIDENCE'; re-raised blind and re-adjudicated at panel round 6): the
    complete-entry-only append is DELIBERATE, not an omission bug.
    REQ-004 binds every published `capability_evaluations[]` entry to
    carry EXACTLY one `trigger_evaluations[]` element per affected
    component (AC-018 repeats it as an exact-set rule), so a
    partially-evaluated Capability's entry CANNOT be published without
    itself violating the frozen per-entry cardinality -- on an abort the
    array is necessarily incomplete either way (later Capabilities never
    ran at all), and omitting the partial entry keeps every entry that
    IS present well-formed. The WARN half is governed separately:
    already-collected warn diagnostics are FORWARDED on every abort path
    under human-amended AC-056 (ruling A(1)), which explicitly sanctions
    a forwarded warn whose Capability entry is absent (locked by the
    `evaluate-predicate-failure-after-warn` fixture's exact-Evidence
    assertion). tasks.md's 'every evaluation already performed through
    step 8' sentence is scoped to the `dsl-warn-on-matched-capability`
    fixtures, where every per-Capability set completes before the step-9
    Block -- it does not mandate publishing contract-violating partial
    entries on a mid-Capability abort.
    `warn_diagnostics` is likewise mutated in place, gaining one
    `severity: "warn"` diagnostics[] entry per individual `outcome: "warn"`
    DSL-evaluation node found anywhere in any evaluation's own Evidence
    tree, in this same declaration-order evaluation sequence (AC-056).
    Returns whether any evaluation's own Evidence tree contained an
    `outcome: "warn"` node anywhere (step 9's own condition)."""
    sorted_affected_components = sorted(affected_components)
    # Ruling C(2) (human-approved 2026-08-26): fail closed BEFORE any
    # predicate evaluation when a dependency-returned affected component is
    # absent from the Context Projection -- never a defaulted-empty-
    # properties evaluation (the fail-open both the quality gate and the
    # cross-model panel flagged).
    for component_id in sorted_affected_components:
        if component_id not in projection_components:
            raise AffectedComponentAbsentFromContext(component_id)
    any_warn = False
    for capability in registry_document.get("capabilities", []):
        capability_id = capability["id"]
        trigger_evaluations = []
        matched = False
        for component_id in sorted_affected_components:
            properties = projection_components[component_id]
            result, evidence = _evaluate_predicate(script_dir, capability["trigger"], properties)
            for node, node_path in _iter_warn_nodes(evidence):
                any_warn = True
                warn_diagnostics.append({
                    "id": "dsl-warn-on-matched-capability",
                    "detail": _warn_diagnostic_detail(capability_id, component_id, None, node_path, node),
                    "severity": "warn",
                })
            trigger_evaluations.append({"component_id": component_id, "result": result, "evidence": evidence})
            if result:
                matched = True
        entry = {"capability_id": capability_id, "matched": matched, "trigger_evaluations": trigger_evaluations}
        if matched:
            conditional_facet_evaluations = []
            for declaration_index, facet_declaration in enumerate(capability.get("conditional_facets", [])):
                evaluations = []
                applied = False
                for component_id in sorted_affected_components:
                    properties = projection_components[component_id]
                    result, evidence = _evaluate_predicate(script_dir, facet_declaration["when"], properties)
                    for node, node_path in _iter_warn_nodes(evidence):
                        any_warn = True
                        warn_diagnostics.append({
                            "id": "dsl-warn-on-matched-capability",
                            "detail": _warn_diagnostic_detail(
                                capability_id, component_id, declaration_index, node_path, node,
                            ),
                            "severity": "warn",
                        })
                    evaluations.append({"component_id": component_id, "result": result, "evidence": evidence})
                    if result:
                        applied = True
                conditional_facet_evaluations.append({
                    "facet": facet_declaration["facet"],
                    "declaration_index": declaration_index,
                    "applied": applied,
                    "evaluations": evaluations,
                })
            entry["conditional_facet_evaluations"] = conditional_facet_evaluations
        capability_evaluations.append(entry)
    return any_warn


def _json_type_matches(value, expected):
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    return True


def _schema_errors(value, schema, pointer="$"):
    errors = []
    if "const" in schema and value != schema["const"]:
        errors.append(f"{pointer}: const mismatch")
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{pointer}: enum mismatch")
    expected_type = schema.get("type")
    if expected_type and not _json_type_matches(value, expected_type):
        return errors + [f"{pointer}: type mismatch"]
    if isinstance(value, str) and len(value) < schema.get("minLength", 0):
        errors.append(f"{pointer}: minLength mismatch")
    if isinstance(value, dict):
        properties = schema.get("properties", {})
        for required in schema.get("required", []):
            if required not in value:
                errors.append(f"{pointer}: missing {required}")
        if schema.get("additionalProperties") is False:
            for key in value:
                if key not in properties:
                    errors.append(f"{pointer}: additional property {key}")
        for key, child in value.items():
            if key in properties:
                errors.extend(_schema_errors(child, properties[key], f"{pointer}/{key}"))
    if isinstance(value, list) and "items" in schema:
        for index, child in enumerate(value):
            errors.extend(_schema_errors(child, schema["items"], f"{pointer}/{index}"))
    if "oneOf" in schema:
        matches = sum(not _schema_errors(value, branch, pointer) for branch in schema["oneOf"])
        if matches != 1:
            errors.append(f"{pointer}: oneOf mismatch")
    return errors


def _project_context_valid(document, repo_root):
    schema_path = repo_root / "contracts/project-context.schema.json"
    try:
        with schema_path.open("r", encoding="utf-8") as handle:
            schema = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return False
    return not _schema_errors(document, schema)


# ---------------------------------------------------------------------------
# T-007 (step 0.5 + step 14): the Resolver publication transactional bundle
# contract (design.md, "Resolver publication transactional bundle contract",
# applying Epic A1's own already-fixed multi-target contract -- Epic A1
# `design.md:987-1016` -- isomorphically, reusing its protocol shape and its
# journal field names rather than inventing a second one).
#
# Everything below is reachable from exactly two places: `main()`'s own step
# 0.5 (`_crash_recovery_scan`) and its own step 14 (`_publish_bundle`), plus
# `_write_evidence`, which does NOT use this transaction at all: a Block's
# Evidence write is a direct `temp file + fsync + rename` with no staging
# area and no journal (design.md:1419, :2846; requirements.md line 371,
# "published directly, not through the journaled transaction"). An earlier
# revision of this comment called it "a degenerate instance of the SAME
# transaction", quoting design.md's own "exactly one target" sentence --
# that is one of the stale siblings panel round 5 withdrew, corrected here
# on round 10.
# ---------------------------------------------------------------------------

TRANSACTION_SCHEMA = "sdd-resolver-transaction/v1"
STAGING_DIRNAME = ".resolver-staging"
JOURNAL_FILENAME = "TRANSACTION.json"
PRE_IMAGE_DIRNAME = "pre"
ABSENT = "ABSENT"
_HASH_RE = re.compile(r"[0-9a-f]{64}")

ARTIFACT_PUBLICATION_FAILED_PREFIX = (
    "a staged artifact could not be written, fsynced, or renamed to its live path during this "
    "invocation's own publication transaction"
)
POST_PUBLICATION_MISMATCH_PREFIX = (
    "a post-publication verification of the Project Context, Registry, or ownership-source snapshot "
    "detected drift after every rename in this invocation's own publication transaction had already "
    "succeeded"
)
JOURNAL_RECOVERY_DETAIL = (
    "a stale publication transaction journal for this feature could not be safely converged to a "
    "fully-applied or fully-reverted state"
)


class ArtifactPublicationFailed(Exception):
    """A `write`/`fsync`/`rename` failure caught IN-PROCESS during this
    invocation's own publication transaction's Prepare/Journal/Commit phases
    (REQ-002's `artifact-publication-failed` row). Carries the already-
    resolved rollback clause -- AC-039 requires the rollback attempt, and any
    failure encountered in it, to be recorded in this diagnostic's own
    `detail`, "never silently swallowed"."""

    def __init__(self, rollback_clause):
        super().__init__(rollback_clause)
        self.rollback_clause = rollback_clause


class PublicationStagingAreaUncontained(Exception):
    """This feature's own `.resolver-staging` area does not really resolve
    inside `specs/<feature>/` (panel round 3, CRITICAL) -- it is a symlink, or
    sits behind one. Distinct from `PublicationJournalUnrecoverable` because
    the response differs: the scan refuses before it globs, having touched
    nothing.

    Panel round 5 (openai, Major) corrected what follows the refusal. The
    earlier revision made NO live write here at all, reasoning that a Block
    record's own transaction needs the compromised staging area. That was
    true of the code as it then stood and false of the contract: design.md
    requires an Evidence-only write to be DIRECT, "no staging area, no
    journal" (design.md:1419, :2846). The direct write puts its temp file
    beside the target in `specs/<feature>/`, so a compromised staging area
    does not obstruct it, and this Block now emits Evidence like every other
    one -- AC-012's always-emitted rule with exactly its two stated
    exceptions and no third. It still reports the CORRECT diagnostic id
    (`publication-journal-recovery`) rather than being misattributed to a
    publication failure, so the operator is pointed at the real cause."""


class EvidenceTargetUncontained(Exception):
    """`specs/<feature>/resolver-evidence.yaml` does not itself resolve inside
    `specs/<feature>/` -- the feature directory is a symlink, or sits behind
    one (panel round 4's scenario, reached again by round 5's direct Evidence
    route).

    This is NOT the staging-area condition and must not be answered the same
    way. There, only the bookkeeping area was compromised and the Evidence
    target was still where it should be, so the record can be written. Here
    the record's own destination is outside the tree, so writing it IS the
    escape -- the one thing every panel round since round 1 has been closing.

    So this alone keeps a Block from emitting Evidence, and it is narrower
    than the condition it replaces: not "the staging area is compromised" but
    "this feature's own Evidence artifact has no valid location". AC-012
    names an artifact at a fixed path inside `specs/<feature>/`; when that
    path does not resolve inside `specs/<feature>/`, the artifact the
    criterion governs has no well-defined location in the governed tree at
    all, which is a different situation from declining to write one that
    does.

    RULED 2026-08-28 (repository owner, ruling (a)). This is nonetheless a
    THIRD no-write exception where requirements.md line 386 says the
    always-emitted rule "excepts exactly two diagnostic ids", and both
    cross-model panel slots raised it as such. The question was put to the
    owner with the alternatives stated plainly -- there is no third option
    here, because writing to a destination that resolves outside the tree IS
    the escape, not writing violates AC-012's count, and only the latter is
    fail-closed -- and the owner ACCEPTED it as a known limitation. So the
    behaviour below is SPECIFIED-WITH-A-KNOWN-LIMITATION, not an open defect.
    No frozen document was amended for it: the ruling is recorded here and in
    investigation.md, the same way the 2026-08-27 ruling on the
    doubly-degraded rollback corner was recorded.

    Ruling (b), taken at the same time, narrowed
    `_target_escapes_via_symlink` to resolve only the target's PARENT. That
    shrinks this exception's reach to the irreducible case: a symlink AT
    `resolver-evidence.yaml` itself no longer trips it, because
    `os.replace` replaces that entry rather than following it. What remains
    is a feature directory that genuinely resolves outside the tree, where no
    valid write exists at all.

    The caller preserves the ORIGINAL diagnostic id rather than relabelling
    the Block a publication failure -- relabelling would point the operator
    at the wrong cause, which is exactly the misattribution the staging-area
    class above was written to avoid."""


class PublicationJournalUnrecoverable(Exception):
    """The step-0.5 crash-recovery scan found a stale journal it cannot
    safely converge to either terminal state (REQ-002's `publication-journal-
    recovery` row): a referenced `pre/<target-basename>` backup is missing,
    unreadable, or no longer matches its own journal-recorded hash; a
    target's current live hash matches NEITHER its journal-recorded PRE nor
    POST value; or the journal document itself is unreadable or mis-shaped.

    A mis-shaped-but-parseable journal is deliberately rejected here rather
    than silently treated as "no journal at all" (Epic A1's own carry-forward
    obligation 2 on the isomorphic mechanism): silently ignoring it would let
    an unrecovered partial publish stand forever."""


def _rollback_clause(count, complete):
    """AC-039's own "the rollback attempt is itself recorded in this
    diagnostic's own `detail`" text, as a canonical, Resolver-owned sentence
    built only from fixed fields plus a count -- never an OS/errno string or
    a local path (security-spec.md B5, AC-014). Deliberately carries NO
    exception class name either, unlike this file's own governing-schema
    read failures: the OSError subclasses a failed `mkdir`/`rename` raises
    differ BY PLATFORM (`NotADirectoryError` vs `FileExistsError` vs
    `PermissionError` for the identical injected condition), so naming the
    class would break REQ-005's own dual-runtime byte-identity guarantee for
    `<detail>`."""
    if count == 0:
        return "no live rename had yet been committed, so no target needed rolling back"
    noun = "rename" if count == 1 else "renames"
    verb = "was" if count == 1 else "were"
    pronoun = "its own" if count == 1 else "their own"
    if complete:
        return (
            f"{count} already-committed live {noun} {verb} rolled back to {pronoun} "
            f"PRE-transaction state via this transaction's own journal"
        )
    # Kept VERBATIM from REQ-002's own `artifact-publication-failed` row
    # ("safely completed by the next invocation's own crash-recovery scan
    # instead"), even though `_rollback_transaction`'s own KNOWN LIMITATION
    # note explains that the next scan will in fact Block for manual
    # intervention on this path rather than converge automatically. Softening
    # the operator-facing sentence here would put this file's own wording at
    # odds with the frozen requirement text without fixing the underlying
    # contract conflict, which is a human ruling (panel round 1, MAJOR 2).
    return (
        f"an in-process journal-based rollback of {count} already-committed live {noun} did not "
        f"itself complete; the next invocation's own crash-recovery scan is the durable backstop"
    )


def _normalized(path):
    """Absolute + LEXICALLY normalized (`..` and `.` segments collapsed).

    Deliberately NOT `Path.resolve()`: resolving would follow symlinks on
    BOTH sides of the containment comparison below, so an attacker who
    replaced an in-set path with a symlink pointing outside the set would see
    the allowed-set entry resolve to the same outside location and the check
    would pass. Lexical normalization is what actually defeats `..`
    traversal and absolute-path escape.

    SYMLINKS ARE NOT THIS FUNCTION'S JOB. The round-1 justification that used
    to sit here -- "`os.replace` REPLACES a symlink at the target rather than
    writing through it, and `unlink` removes the link rather than its
    referent" -- is true but covers ONLY a symlink at the FINAL path
    component (panel round 2 established that; rounds 2-4 then found three
    separate escapes above it). A symlinked PARENT is caught by
    `_target_escapes_via_symlink`; a symlinked staging area or
    `specs/<feature>` by `_staging_area_contained` /
    `_expected_staging_root_real`. Use this function for lexical set
    membership only, and always pair it with one of those realpath checks."""
    return os.path.normpath(os.path.abspath(str(path)))


def _allowed_publication_targets(repo_root, feature):
    """The Resolver's ENTIRE live write set for one `--feature`, fixed by
    name in requirements.md's own Security Boundaries bullet 1
    (requirements.md:1144-1151): "never ... writes outside
    `specs/<feature>/facet-manifest.yaml`/`capability-summary.yaml`,
    `generated/project-context.resolved.json`, its own Resolver Evidence
    path, and its own transient `specs/<feature>/.resolver-staging/` ...
    area"; security-spec.md's B2 row enumerates the identical destination
    set.

    This is the single source of truth for BOTH directions. Step 14 asserts
    its own constructed targets against it (a fail-closed assertion about
    this file's own code), and the step-0.5 crash-recovery scan validates
    every journal-recorded target against it (a genuine trust boundary --
    see `_recover_journal`). The staging area itself is not listed: it is
    never a live target, only the transaction's own bookkeeping, and
    recovery never treats it as one."""
    feature_dir = repo_root / "specs" / feature
    script_dir = Path(__file__).resolve().parent
    return frozenset(
        _normalized(path)
        for path in (
            feature_dir / "facet-manifest.yaml",
            feature_dir / "capability-summary.yaml",
            feature_dir / "resolver-evidence.yaml",
            script_dir / "generated" / "project-context.resolved.json",
        )
    )


def _allowed_publication_targets_real(repo_root, feature):
    """The same fixed target set as `_allowed_publication_targets`, but each
    entry's OWN symlinks fully resolved -- the trusted bases (`repo_root`,
    the script directory) resolved once, then the fixed lexical subpath
    joined on WITHOUT following any further symlink.

    This is the reference `os.path.realpath(target)` is compared against by
    `_target_escapes_via_symlink` below. Because the base is resolved but the
    subpath (`specs/<feature>/...`, `generated/...`) is not, a symlink placed
    anywhere from the base down to the target -- `specs/<feature>` itself,
    `generated`, or the leaf -- makes `realpath(target)` diverge from this
    reference and is caught. Resolving the base first is deliberate: on macOS
    `/var` is a symlink to `/private/var`, and every fixture temp repo lives
    under it, so a check that forbade *any* symlink from the filesystem root
    down would reject every legitimate run. The threat is a symlink INSIDE
    the controlled subtree, not one above the repository."""
    repo_real = os.path.realpath(str(repo_root))
    script_real = os.path.realpath(str(Path(__file__).resolve().parent))
    feature_dir = os.path.join(repo_real, "specs", feature)
    return frozenset((
        os.path.join(feature_dir, "facet-manifest.yaml"),
        os.path.join(feature_dir, "capability-summary.yaml"),
        os.path.join(feature_dir, "resolver-evidence.yaml"),
        os.path.join(script_real, "generated", "project-context.resolved.json"),
    ))


def _target_escapes_via_symlink(repo_root, feature, target):
    """True iff `target`, after FULL symlink resolution of its ancestry,
    would land outside this feature's own fixed publication target set
    (panel round 2, MAJOR 2).

    `_normalized` (the lexical check) deliberately does not resolve symlinks,
    so it cannot see a symlinked PARENT directory -- `os.path.normpath`
    collapses `..` but leaves a symlink component intact, and the later
    `mkdir`/`mkstemp`/`os.replace` then follow that component and write
    outside the set. This closes that gap the only way a check without a
    stored real-path oracle can: resolve the candidate the same way the
    kernel will at write time (`os.path.realpath`, which follows every
    symlink in the ancestry and, with the default `strict=False`, resolves
    the existing prefix while leaving a not-yet-created leaf lexical) and
    require the result to be one of the fixed, base-resolved target
    locations. It also subsumes the lexical `..`-traversal case, so the two
    checks are belt-and-suspenders, not redundant coverage of one bug.

    NARROWED 2026-08-28 (repository owner, ruling (b), raised by the openai
    panel slot on round 9). The resolution stops at the target's PARENT; the
    leaf is then joined on by name. Resolving the leaf as well modelled a
    write this code does not perform: every write here lands via
    `os.replace(tmp, target)`, which replaces the directory ENTRY at `target`
    rather than following a symlink sitting there, and the temp file itself
    is created with `mkstemp(dir=target.parent)`. So the parent is the only
    component whose symlinks can move a write, and a symlink AT the leaf is
    destroyed by the rename rather than followed. The old form refused those
    cases anyway, suppressing a valid in-tree destination -- stricter than
    the semantics it existed to guard.

    What is still caught is unchanged in substance: a symlinked
    `specs/<feature>`, a symlinked `generated/`, any symlink between the
    trusted base and the parent, and every lexical `..` traversal, because
    each of those makes the resolved parent diverge from the fixed reference.
    Reading is the one operation that does follow a leaf symlink
    (`_live_bytes` captures the PRE image), and it cannot escape either: the
    bytes it reads are written back, on rollback, to the leaf NAME inside the
    tree, never to the symlink's own target."""
    parent_real = os.path.realpath(str(Path(target).parent))
    candidate = os.path.join(parent_real, Path(target).name)
    return candidate not in _allowed_publication_targets_real(repo_root, feature)


def _path_contained_in(container_real, candidate_real):
    """`candidate_real` is `container_real` itself or something strictly
    beneath it. Both arguments must already be realpath-resolved.

    `os.path.commonpath` raises **ValueError** (never `OSError`) for inputs it
    cannot compare -- a mix of absolute and relative paths, or, on Windows,
    two different drives, which is exactly what a `subst`ed drive or a
    cross-drive junction produces. An escaping `ValueError` here would leave
    `main()` as a raw traceback instead of the canonical `capability-resolver:
    <id>: <detail>` line REQ-002/AC-014 require, so it is caught and treated
    as "not contained" -- fail closed (panel round 3, Minor 2; unreachable on
    POSIX, but this file's own `.ps1` twin runs on Windows CI)."""
    try:
        return os.path.commonpath([container_real, candidate_real]) == container_real
    except ValueError:
        return False


def _expected_staging_root_real(repo_root, feature):
    """Where this feature's staging area MUST really live: THE ANCHOR
    (`repo_root`, resolved) joined with the whole fixed lexical subpath
    `specs/<feature>/.resolver-staging`, resolving nothing in between.

    Panel round 4 (Major) fixed a drift here. An earlier revision resolved
    `specs/<feature>` first and appended only `.resolver-staging` -- it
    treated an intermediate, branch-committable path component as trusted. A
    symlinked `specs/` or `specs/<feature>` then moved the reference itself,
    so `_staging_area_contained` compared a realpath against a reference that
    had resolved THE SAME symlink: both sides cancelled, the check passed
    vacuously, and an external staging tree was accepted. That is precisely
    the both-sides-resolve failure mode `_normalized`'s own docstring warns
    about, reintroduced one layer up.

    `repo_root` is THE ANCHOR because it is the one path here not derived
    from repo-local, branch-committable metadata: `_find_repo_root` locates
    it by walking up to a `.git`, and a `.git` component cannot be
    represented inside a git tree, so no committed branch can plant or
    redirect it. Every containment reference in this file is therefore built
    as anchor + fixed lexical subpath -- the construction
    `_allowed_publication_targets_real` already used, which is exactly why
    the PUBLICATION path was never affected by this defect (verified
    directly: with `specs/<feature>` symlinked out,
    `_target_escapes_via_symlink` still refuses, because its reference stays
    lexical under the anchored root while `realpath(target)` is external, so
    the two do not cancel)."""
    return os.path.join(os.path.realpath(str(repo_root)), "specs", feature, STAGING_DIRNAME)


def _staging_area_contained(repo_root, feature):
    """Whether this feature's staging area really resolves inside
    `specs/<feature>/` (panel round 3, CRITICAL).

    requirements.md:1144-1151 grants this feature exactly one writable
    directory beyond its four named output files -- "its own transient
    `specs/<feature>/.resolver-staging/` transaction-journal/pre-image area".
    If that path is a SYMLINK, every write the transaction bookkeeping
    performs there lands somewhere else, and the most destructive of them is
    `_discard_batch`'s own `shutil.rmtree`. A `.resolver-staging` symlink and
    a `TRANSACTION.json` are both ordinary committed files, so a malicious
    branch can plant them together and have the next invocation recursively
    delete an arbitrary external directory -- strictly worse than the
    single-file writes rounds 1 and 2 closed, and reachable WITHOUT any
    escaping target path: an entry naming an in-set, currently-ABSENT target
    classifies all-PRE (SAFE abandonment) and goes straight to
    `_discard_batch`, so the round-1 allowlist and the round-2 symlink check
    are both consulted and both legitimately approve.

    Checked BEFORE the scan globs the directory, not merely before it writes:
    discovery through a symlinked staging root is itself the first step of
    the exploit."""
    return _path_contained_in(
        _expected_staging_root_real(repo_root, feature),
        os.path.realpath(str(_staging_root(repo_root, feature))),
    )


def _staging_root(repo_root, feature):
    """`specs/<feature>/.resolver-staging` -- an unprotected staging area,
    this feature's own equivalent of Epic A1's own `sdd/.staging/`
    convention (design.md; infra-spec.md's own Journal Recovery table row
    classifies it "NOT git-tracked ... transient"). Scoped to ONE feature by
    construction: a stale journal under a different Feature's own staging
    directory is that Feature's own concern and is never inspected here."""
    return repo_root / "specs" / feature / STAGING_DIRNAME


def _live_bytes(path):
    """The target's own current live bytes, or `None` when nothing is there.

    A dangling symlink is treated as PRESENT (and therefore read, which
    raises) rather than as "genuinely does not exist": `Path.exists()` alone
    reports False for it, and mistaking a present-but-unreadable target for
    an absent one is exactly the misrepresentation that lets recovery delete
    a journal and its backups while a real target still stands (Epic A1's
    own seq0360 finding on the isomorphic mechanism). Every other read
    failure propagates as `OSError`, never as a silent `ABSENT`."""
    if not (path.is_symlink() or path.exists()):
        return None
    return path.read_bytes()


def _digest(payload):
    return hashlib.sha256(payload).hexdigest()


def _live_digest(path):
    payload = _live_bytes(path)
    return ABSENT if payload is None else _digest(payload)


def _atomic_write_bytes(target, payload):
    """The single-file primitive every write in this file uses, unchanged in
    itself from the revision step 14 already used (design.md: "temp file +
    `fsync` + `rename`, the same single-file primitive an earlier revision of
    step 14 already used ... only the surrounding journal/verify/recovery
    discipline is new") -- plus the temp-then-REHASH round trip design.md's
    own Journal step names, so a torn temp file can never be renamed into
    place."""
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=".resolver-publish-", dir=str(target.parent))
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        with open(temp_name, "rb") as handle:
            if handle.read() != payload:
                raise OSError("temp-file round-trip verification failed before rename")
        os.replace(temp_name, target)
    finally:
        if os.path.exists(temp_name):
            os.unlink(temp_name)


def _canonical_payload(document):
    """Every artifact this transaction publishes is serialized identically:
    canonical, key-sorted, separator-fixed JSON plus one trailing newline --
    the SAME form `_write_evidence` already used for Resolver Evidence,
    reused for the Facet Manifest/Capability Summary rather than a second
    serialization rule (REQ-005 determinism)."""
    return (json.dumps(document, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")


def _discard_batch(batch_dir):
    """Complete (design.md step 5): delete the journal -- an ordinary
    `unlink`; a delete failure here just leaves a stale-but-fully-applied
    journal, trivially resolved by the crash-recovery scan -- then take the
    batch's own `pre/` backups and the (now empty) staging root with it, so a
    completed transaction leaves no litter for the next scan to walk."""
    # Defence in depth (panel round 3; scope corrected panel round 4). This
    # guard compares `realpath(batch_dir)` against `realpath(batch_dir.
    # parent)` ONLY, so what it actually covers is a NONCE directory that is
    # itself a symlink inside an otherwise-legitimate staging root. It does
    # NOT cover an escaping staging root or an escaping `specs/<feature>`:
    # there the batch dir still sits inside its own parent and this check
    # passes -- those are `_staging_area_contained`'s job, one layer up. It
    # needs no repo/feature context, which keeps it correct at every call
    # site including the cleanup paths, and it precedes the `unlink`
    # deliberately: `shutil.rmtree` refuses a symlink argument, but
    # `journal.unlink()` below would still follow one.
    parent_real = os.path.realpath(str(batch_dir.parent))
    batch_real = os.path.realpath(str(batch_dir))
    if batch_real == parent_real or not _path_contained_in(parent_real, batch_real):
        return
    journal = batch_dir / JOURNAL_FILENAME
    try:
        if journal.exists():
            journal.unlink()
    except OSError:
        return
    shutil.rmtree(batch_dir, ignore_errors=True)
    try:
        batch_dir.parent.rmdir()
    except OSError:
        pass


def _write_journal(batch_dir, nonce, entries):
    """Journal (design.md step 2): written before ANY live rename, listing
    every target in COMMIT ORDER with its live path, its PRE-transaction hash
    (or `"ABSENT"`), and its POST-transaction (staged-candidate) hash, plus
    this batch's own nonce and `status: "in-progress"`. Field names mirror
    Epic A1's own already-shipped journal (`live_path`/`pre_hash`/
    `post_hash`) rather than inventing a parallel vocabulary for the
    isomorphic mechanism. `sort_keys` orders each target object's own keys
    and never the `targets` ARRAY, so commit order survives serialization."""
    document = {
        "schema": TRANSACTION_SCHEMA,
        "nonce": nonce,
        "status": "in-progress",
        "targets": [
            {"live_path": entry["live_path"], "pre_hash": entry["pre_hash"], "post_hash": entry["post_hash"]}
            for entry in entries
        ],
    }
    _atomic_write_bytes(batch_dir / JOURNAL_FILENAME, _canonical_payload(document))


def _hash_or_absent(value):
    return value == ABSENT or bool(_HASH_RE.fullmatch(value))


def _read_journal(journal_path):
    """Strict shape validation; every deviation is unrecoverable, never a
    silent "no journal" (see `PublicationJournalUnrecoverable`)."""
    try:
        document = json.loads(journal_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise PublicationJournalUnrecoverable("journal unreadable or unparseable") from exc
    if (
        not isinstance(document, dict)
        or document.get("schema") != TRANSACTION_SCHEMA
        or document.get("status") != "in-progress"
        or not isinstance(document.get("nonce"), str)
        or not isinstance(document.get("targets"), list)
        or not document["targets"]
    ):
        raise PublicationJournalUnrecoverable("journal does not conform to its own transaction shape")
    # The nonce must BE this batch's own directory name, not merely a string
    # (openai panel slot, round 9 Minor). `_write_journal` records exactly
    # that, so any journal whose nonce names a different batch is malformed --
    # a copied, hand-edited, or cross-batch-grafted journal -- and acting on
    # it would restore one batch's pre-images against another batch's targets.
    # Refusing here routes it to `publication-journal-recovery`, which is the
    # fail-closed outcome every other shape deviation already gets.
    if document["nonce"] != journal_path.parent.name:
        raise PublicationJournalUnrecoverable("journal nonce does not name its own batch directory")
    entries = []
    for target in document["targets"]:
        if not isinstance(target, dict) or set(target) != {"live_path", "pre_hash", "post_hash"}:
            raise PublicationJournalUnrecoverable("journal target entry does not conform to its own shape")
        if not all(isinstance(value, str) for value in target.values()):
            raise PublicationJournalUnrecoverable("journal target entry carries a non-string field")
        if not target["live_path"] or not _hash_or_absent(target["pre_hash"]) or not _hash_or_absent(target["post_hash"]):
            raise PublicationJournalUnrecoverable("journal target entry carries an invalid path or hash")
        entries.append(target)
    return entries


def _journal_target_path(repo_root, live_path):
    """Journals record repo-relative paths whenever the target lives inside
    the repository (the ordinary case, `_repo_relative`'s own rule), so a
    journal survives the tree being moved; an installed-standalone
    deployment whose script directory sits outside the repository records an
    absolute path instead, and is resolved as-is here."""
    candidate = Path(live_path)
    return candidate if candidate.is_absolute() else repo_root / candidate


def _read_pre_image(batch_dir, entry):
    """The journal's own `pre/<target-basename>` backup for one entry,
    verified against that entry's own journal-recorded PRE hash before it is
    ever written anywhere. A missing, unreadable, or no-longer-matching
    backup raises `OSError` -- the caller turns that into the unrecoverable
    state design.md names, never a silently-wrong restore."""
    basename = Path(entry["live_path"]).name
    payload = (batch_dir / PRE_IMAGE_DIRNAME / basename).read_bytes()
    if _digest(payload) != entry["pre_hash"]:
        raise OSError("pre-image backup no longer matches its own journal-recorded hash")
    return payload


def _restore_to_pre(repo_root, batch_dir, entry):
    """Put one target back at its own PRE-transaction state, via the SAME
    atomic-rename primitive the commit itself used -- restoring the journal's
    own byte-exact backup, or deleting the live file when its own PRE state
    was `"ABSENT"`. NEVER a bare `unlink` of a target that had pre-existing
    live bytes (adversarial review B1's own "existing bytes destroyed with no
    restore path" gap)."""
    target = _journal_target_path(repo_root, entry["live_path"])
    if entry["pre_hash"] == ABSENT:
        if target.is_symlink() or target.exists():
            target.unlink()
        return
    _atomic_write_bytes(target, _read_pre_image(batch_dir, entry))


class _PublicationTransaction:
    """An open transaction: every rename already committed, journal still
    standing, awaiting either post-publication verification + Complete or an
    in-process rollback."""

    def __init__(self, repo_root, batch_dir):
        self.repo_root = repo_root
        self.batch_dir = batch_dir
        self.entries = []
        self.journalled = False
        self.committed = 0


def _rollback_transaction(transaction, discard=True):
    """The in-process half of the journal-based rollback (design.md step 4's
    own mechanism, reused verbatim by the Prepare/Journal/Commit failure
    path). Returns `(count, complete)`.

    Every needed backup is validated BEFORE the first restore, so a batch
    whose backups are not all sound is left exactly as found instead of
    half-reverted -- the same reason the crash-recovery scan below
    pre-validates. Only once every target is confirmed back at PRE is the
    journal deleted; an incomplete rollback RETAINS the journal (design.md;
    infra-spec.md "In-process variant").

    KNOWN LIMITATION of that retention, recorded rather than papered over
    (cross-model panel round 1, MAJOR 2 -- both vendors raised it). REQ-002's
    own `artifact-publication-failed` row says a rollback that "cannot itself
    fully complete" is "safely completed by the next invocation's own
    crash-recovery scan instead". That promise does NOT hold as written on
    this path, and the reason is a second frozen mandate pulling the other
    way: the caller is REQUIRED (REQ-002's Evidence-on-every-Block rule,
    AC-012) to publish a Block Evidence record immediately afterwards, and
    `resolver-evidence.yaml` is itself one of the retained journal's own
    recorded targets. Writing it therefore leaves that target matching
    NEITHER its journal-recorded PRE nor its POST hash -- which the recovery
    algorithm defines as the unrecoverable third state. The next invocation
    consequently Blocks `publication-journal-recovery` and waits for a human,
    rather than converging automatically.

    This is fail-closed in every direction that matters -- no live bytes are
    destroyed (the PRE-image backups are retained on disk), no mixed
    generation is left standing as publishable, and the operator is told
    explicitly -- but it is MANUAL INTERVENTION, not the automatic
    convergence the phrase "durable backstop" suggests. Making it converge
    automatically would require AMENDING a retained journal in place
    (re-recording that one target's hashes, or dropping its entry), and the
    frozen contract defines exactly three journal operations -- write at
    Journal, delete at Complete, delete after a converged recovery -- with no
    amend. Adding a fourth is a contract change, not an implementation
    choice, so it was raised for human ruling instead of being invented here.

    RULED 2026-08-27 (repository owner, via a structured question relayed by
    the coordinating session): this limitation was put to the owner with both
    repair options -- (a) accept the current fail-closed behaviour as a known
    limitation, or (b) authorize a fourth journal operation / a design.md
    amendment -- and the owner selected (a),
    「(a) 現行 fail-closed を既知制限として受容（推奨）」. So the behaviour
    described above is SPECIFIED-WITH-A-KNOWN-LIMITATION, not an open defect:
    manual operator intervention is by design in this doubly-degraded corner
    (a publication failure AND a rollback that could not itself complete),
    and no journal-amend operation is authorized. Do not "fix" this by
    amending a retained journal in place; that option was considered and
    declined.

    `_rollback_clause`'s own diagnostic sentence below deliberately keeps
    REQ-002's wording verbatim rather than silently diverging from the frozen
    text this limitation is about."""
    count = transaction.committed
    if count == 0:
        # Nothing reached a live path, so there is nothing to roll back --
        # and neither the journal (if Journal had already run) nor any
        # pre-image backup captured during Prepare has any remaining
        # purpose. Discarding the whole batch here is what the next
        # invocation's scan would do anyway for an all-PRE journal (SAFE
        # abandonment), done now so a Prepare/Journal-phase failure cannot
        # leave an orphaned nonce directory of pre-images behind that no
        # later scan would ever look at (panel round 1, MINOR: the scan only
        # globs `*/TRANSACTION.json`, so a journal-less leftover is
        # invisible to it forever).
        _discard_batch(transaction.batch_dir)
        return 0, True
    # Evidence is NEVER rolled back (REQ-001 step (m); requirements.md's own
    # "the subject is the three publication artifacts ... and never
    # `resolver-evidence.yaml`"). Restoring it would destroy the only record
    # that the rolled-back publication was ever attempted, which is precisely
    # the audit obligation REQ-004 exists to guarantee -- and on the
    # post-publication-mismatch path Evidence IS among the committed entries,
    # because it commits last. Both cross-model panelists reached this same
    # code independently on round 7 (openai Critical, anthropic Minor 1); the
    # end state was already correct only because `_block` overwrites Evidence
    # immediately afterwards, but a crash in the gap between the restore and
    # that write left the PRE record standing as the whole audit trail.
    #
    # Excluding it here does not touch the doubly-degraded corner ruled on
    # 2026-08-27: an INCOMPLETE rollback still retains the journal, and the
    # journal still lists Evidence as one of its targets, so the next
    # invocation still Blocks `publication-journal-recovery` for a human.
    # No journal-amend operation is introduced.
    committed_entries = [
        entry
        for entry in transaction.entries[:count]
        if Path(entry["live_path"]).name != "resolver-evidence.yaml"
    ]
    # The reported count is the number of PUBLICATION ARTIFACTS rolled back,
    # not the number of journal entries committed, for the same reason the
    # set above excludes Evidence: REQ-002's own rollback clause names the
    # publication artifacts as its subject, so counting Evidence among them
    # overstated the rollback by one on every post-publication-mismatch Full
    # or Lite track.
    rolled_back = len(committed_entries)
    try:
        for entry in committed_entries:
            if entry["pre_hash"] != ABSENT:
                _read_pre_image(transaction.batch_dir, entry)
    except OSError:
        return rolled_back, False
    for entry in reversed(committed_entries):
        try:
            _restore_to_pre(transaction.repo_root, transaction.batch_dir, entry)
        except OSError:
            return rolled_back, False
    for entry in committed_entries:
        try:
            if _live_digest(_journal_target_path(transaction.repo_root, entry["live_path"])) != entry["pre_hash"]:
                return rolled_back, False
        except OSError:
            return rolled_back, False
    # `discard=False` defers the journal's deletion to the caller. It is used
    # on the post-publication paths ONLY, and it is not a fourth journal
    # operation -- it is this same delete, moved to the far side of the Block
    # Evidence write. Deleting here instead would open a window in which the
    # publication artifacts are back at PRE, Evidence still holds the
    # SUCCESS-form record committed moments earlier, and no journal survives
    # for the next invocation's recovery scan to notice: a crash there leaves
    # Evidence asserting a publication whose artifacts are gone, undetectably.
    # Keeping the journal until Evidence is durable makes that same crash
    # land in the recovery scan's own unrecoverable third state, which Blocks
    # `publication-journal-recovery` for a human -- fail-closed and visible,
    # which is the behaviour the owner ruled acceptable for this corner on
    # 2026-08-27. (openai panel slot, round 8 Critical.)
    if discard:
        _discard_batch(transaction.batch_dir)
    return rolled_back, True


def _validate_publication_preconditions(repo_root, feature, batch_dir, targets):
    """Every check that must pass BEFORE this transaction creates anything.

    Raises `ArtifactPublicationFailed` directly (never `OSError`), so a
    caller's refusal cannot be mistaken for a mid-transaction failure and
    routed into the rollback/discard path -- see `_publish_bundle`'s own
    PRE-TRANSACTION VALIDATION note. The rollback clause is the
    nothing-was-committed variant by construction: no rename, no journal, no
    staging directory exists yet."""
    def refuse():
        raise ArtifactPublicationFailed(_rollback_clause(0, True))

    # A fail-closed assertion about THIS file's own target lists, not a trust
    # boundary (these paths are constructed here, never read from anywhere):
    # it keeps step 14 and the crash-recovery scan provably governed by one
    # allowed set, so the two can never drift apart into a state journal
    # recovery is structurally unable to converge.
    allowed = _allowed_publication_targets(repo_root, feature)
    if any(_normalized(target) not in allowed for target, _payload in targets):
        refuse()
    # Panel round 2: the lexical check above cannot see a symlinked PARENT
    # (`generated/`, `specs/<feature>/`). Resolve each target's ancestry the
    # way the kernel will at write time and re-assert containment, so a
    # symlinked parent cannot launder a write outside the fixed set. This
    # fires the first time a Full-track resolve runs in a tree where one of
    # those directories is a symlink -- no planted journal required.
    if any(_target_escapes_via_symlink(repo_root, feature, target) for target, _payload in targets):
        refuse()
    # The staging area itself is where the journal and PRE-image backups are
    # written; a symlinked staging root (or `specs/<feature>`, panel round 4)
    # would put that bookkeeping outside the tree too. Contain it against the
    # anchored reference so the WHOLE write surface -- targets AND
    # bookkeeping -- stays within `specs/<feature>/`.
    if not _staging_area_contained(repo_root, feature) or not _path_contained_in(
        _expected_staging_root_real(repo_root, feature), os.path.realpath(str(batch_dir))
    ):
        refuse()
    # A batch whose targets share a basename would collapse two distinct
    # `pre/<target-basename>` backups into one slot, permanently defeating
    # recovery for one of them (Epic A1's own already-fixed defect on the
    # isomorphic mechanism). No track's own output set can produce this.
    basenames = [target.name for target, _payload in targets]
    if len(set(basenames)) != len(basenames):
        refuse()


def _publish_bundle(repo_root, feature, targets):
    """Prepare + Journal + Commit (design.md steps 1-3). `targets` is a
    sequence of `(live_path, payload)` pairs IN COMMIT ORDER. Returns the
    open transaction with every rename committed; the caller either runs
    post-publication verification and then `_discard_batch` (Complete), or
    rolls back.

    Prepare's own "re-hash every staged candidate TOGETHER, as one step" is
    structural here rather than a discipline that could slip: every staged
    candidate is already an in-memory `bytes` payload by this point (steps
    3/10/11 stage in memory only), so the intra-batch TOCTOU window the
    contract closes -- between validating the first staged target and
    reaching the last -- does not exist to be closed. The PRE-image capture
    below is the half that genuinely touches the filesystem, and it reads
    each target's live bytes exactly ONCE, hashing that same buffer, so the
    journal's recorded PRE hash always describes the bytes actually backed
    up."""
    batch_dir = _staging_root(repo_root, feature) / os.urandom(16).hex()
    transaction = _PublicationTransaction(repo_root, batch_dir)
    # PRE-TRANSACTION VALIDATION, deliberately OUTSIDE the `try` below (panel
    # round 4, Minor 4). Nothing exists on disk yet at this point, so a
    # refusal must NOT fall into the `except OSError` handler: that handler
    # calls `_rollback_transaction` -> `_discard_batch` -> `batch_dir.parent.
    # rmdir()`, an rmdir against the very staging root the validation just
    # REJECTED. Today that is survivable only by accident (on POSIX the sole
    # way the staging check fails is `.resolver-staging` itself being a
    # symlink, and rmdir on a trailing symlink fails ENOTDIR, swallowed by
    # `except OSError: pass`); the round-4 anchor fix makes a REAL-directory
    # staging root able to fail the check, which would turn that into a live
    # attempt to delete the rejected path. Validating before the `try` makes
    # "refused" and "cleaned up" structurally disjoint.
    _validate_publication_preconditions(repo_root, feature, batch_dir, targets)
    try:
        (batch_dir / PRE_IMAGE_DIRNAME).mkdir(parents=True, exist_ok=True)
        for target, payload in targets:
            pre_bytes = _live_bytes(target)
            pre_hash = ABSENT if pre_bytes is None else _digest(pre_bytes)
            if pre_bytes is not None:
                backup = batch_dir / PRE_IMAGE_DIRNAME / target.name
                _atomic_write_bytes(backup, pre_bytes)
                if _digest(backup.read_bytes()) != pre_hash:
                    raise OSError("pre-image backup is not byte-exact")
            transaction.entries.append({
                "live_path": _repo_relative_target(target, repo_root),
                "pre_hash": pre_hash,
                "post_hash": _digest(payload),
                "target": target,
                "payload": payload,
            })
        _write_journal(batch_dir, batch_dir.name, transaction.entries)
        transaction.journalled = True
        for entry in transaction.entries:
            _atomic_write_bytes(entry["target"], entry["payload"])
            transaction.committed += 1
    except OSError as exc:
        rolled_back, complete = _rollback_transaction(transaction)
        raise ArtifactPublicationFailed(_rollback_clause(rolled_back, complete)) from exc
    return transaction


# `_publish_and_complete` stood here: the one-target transaction helper the
# Block path used before panel round 5 withdrew that route. `_write_evidence`
# now writes Evidence directly (temp file + fsync + rename, no staging area
# and no journal), so nothing called it. Deleted on round 9 rather than left
# standing as a second, unreachable write path into the journal machinery of
# a Security-Sensitive file.


def _recover_journal(repo_root, feature, journal_path):
    """Converge ONE stale journal to a terminal state, or raise
    `PublicationJournalUnrecoverable` (design.md's own four-outcome
    classification; infra-spec.md `#journal-recovery` restates it).

    Idempotent and re-entrant: every comparison is current-vs-journaled and
    never assumes prior recovery progress, so a crash DURING recovery is
    itself safely resumed by the next invocation."""
    # Panel round 3: re-validate the DISCOVERED batch directory and journal
    # before reading or deleting anything through them. The scan validated
    # the staging root; this covers a nonce directory (or the journal file
    # itself) that is independently symlinked out of an otherwise-legitimate
    # staging root.
    # Panel round 5, Minor 1: this used to be
    # `os.path.realpath(_staging_root(repo_root, feature))` -- a RESOLVED
    # INTERMEDIATE, the exact construction the Standing Note forbids, which
    # made this "independent second layer" cancel against itself for the
    # symlinked-staging-root case and silently depend on layer 1 having run
    # first. Using the anchored reference makes the layer genuinely
    # independent at no cost, so "one containment rule governs both paths"
    # holds by construction rather than by call ordering.
    staging_real = _expected_staging_root_real(repo_root, feature)
    if not _path_contained_in(
        staging_real, os.path.realpath(str(journal_path.parent))
    ) or not _path_contained_in(staging_real, os.path.realpath(str(journal_path))):
        raise PublicationStagingAreaUncontained(
            "a discovered transaction journal does not resolve inside this feature's own staging area"
        )
    entries = _read_journal(journal_path)
    batch_dir = journal_path.parent

    # TRUST BOUNDARY (panel round 1, MAJOR 1). Everything above this point
    # has only READ the journal; everything below it can WRITE or UNLINK the
    # paths the journal names. The journal lives in an unprotected,
    # repository-local staging area (infra-spec.md's own classification), so
    # its content is attacker-reachable -- a malicious branch can simply
    # commit one. Acting on a recorded path without checking it would let
    # that journal steer a `write` (via a `pre/` backup the same attacker
    # supplies) or an `unlink` (via `pre_hash: "ABSENT"`) at any path this
    # process can reach, which is precisely the "never ... writes outside" a
    # fixed, named path set boundary requirements.md:1144-1151 fixes.
    #
    # Validation happens for EVERY entry up front, before a single file is
    # touched, so a journal that is partly in-set cannot get half-applied
    # before the escaping entry is noticed. A duplicate live path is rejected
    # for the same reason `_publish_bundle` rejects a duplicate basename: two
    # entries for one target cannot both be converged coherently.
    allowed = _allowed_publication_targets(repo_root, feature)
    seen_paths = set()
    for entry in entries:
        target_path = _journal_target_path(repo_root, entry["live_path"])
        normalized = _normalized(target_path)
        if normalized not in allowed or _target_escapes_via_symlink(repo_root, feature, target_path):
            # No journal content is interpolated into the diagnostic (B5):
            # the recorded path is attacker-controlled text and would carry
            # an absolute local path into committed Resolver Evidence. The
            # symlink-resolved half (panel round 2, MAJOR 2) closes the same
            # symlinked-parent escape on the recovery path that the lexical
            # half alone would miss.
            raise PublicationJournalUnrecoverable(
                "a journal-listed target lies outside this feature's own fixed publication target set"
            )
        if normalized in seen_paths:
            raise PublicationJournalUnrecoverable("a journal lists the same live target more than once")
        seen_paths.add(normalized)

    states = []
    for entry in entries:
        try:
            current = _live_digest(_journal_target_path(repo_root, entry["live_path"]))
        except OSError as exc:
            raise PublicationJournalUnrecoverable("a journal-listed target is unreadable") from exc
        if current == entry["post_hash"]:
            states.append("post")
        elif current == entry["pre_hash"]:
            states.append("pre")
        else:
            # The unrecoverable third state: neither generation, so no
            # automatic recovery can know what the operator intended.
            raise PublicationJournalUnrecoverable(
                "a journal-listed target matches neither its PRE nor its POST hash"
            )
    if all(state == "post" for state in states) or all(state == "pre" for state in states):
        # SAFE completion / SAFE abandonment: the transaction had in fact
        # fully committed (crash between the last rename and the journal
        # delete), or never began committing / had already fully rolled back.
        _discard_batch(batch_dir)
        return
    # MIX -- the exact partial-publish state this design must never leave
    # standing. Validate every backup this rollback will need BEFORE
    # touching any live path, so an unrecoverable batch is left exactly as
    # found rather than half-reverted.
    try:
        for entry, state in zip(entries, states):
            if state == "post" and entry["pre_hash"] != ABSENT:
                _read_pre_image(batch_dir, entry)
    except OSError as exc:
        raise PublicationJournalUnrecoverable(
            "a journal-recorded pre-image backup is missing, unreadable, or corrupted"
        ) from exc
    for entry, state in reversed(list(zip(entries, states))):
        if state != "post":
            continue
        try:
            _restore_to_pre(repo_root, batch_dir, entry)
        except OSError as exc:
            raise PublicationJournalUnrecoverable("a journal-based rollback write failed") from exc
    for entry in entries:
        try:
            if _live_digest(_journal_target_path(repo_root, entry["live_path"])) != entry["pre_hash"]:
                raise PublicationJournalUnrecoverable("a target could not be confirmed back at its PRE state")
        except OSError as exc:
            raise PublicationJournalUnrecoverable("a target could not be confirmed back at its PRE state") from exc
    _discard_batch(batch_dir)


def _crash_recovery_scan(repo_root, feature):
    """Step 0.5 (mandatory, every invocation): scan
    `specs/<feature>/.resolver-staging/*/TRANSACTION.json`, scoped to THIS
    invocation's own `--feature` value, and converge every journal found.
    Absent -> return, no diagnostic, proceed directly to step 1."""
    # Panel round 3 (CRITICAL): validate containment BEFORE the glob. A
    # symlinked staging root is discovered THROUGH the symlink (`Path.glob`
    # traverses it and returns the journal beneath), and every converged
    # outcome -- SAFE completion, SAFE abandonment, and MIX alike -- ends in
    # `_discard_batch`'s own `rmtree`. Refusing here is what keeps all three
    # off that path, and it refuses without having touched a single file.
    if not _staging_area_contained(repo_root, feature):
        raise PublicationStagingAreaUncontained(
            "this feature's own staging area does not resolve inside its own specs/<feature> directory"
        )
    try:
        journals = sorted(_staging_root(repo_root, feature).glob(f"*/{JOURNAL_FILENAME}"))
    except OSError as exc:
        raise PublicationJournalUnrecoverable("the staging area itself is unreadable") from exc
    for journal_path in journals:
        _recover_journal(repo_root, feature, journal_path)


def _write_evidence(
    repo_root, feature, diagnostic_id, detail, state_marker,
    capability_evaluations=None, warn_diagnostics=None,
    context_binding=None, resolver_block=None,
):
    # AC-024 stable-sort discipline: capability_evaluations[] is sorted by
    # capability_id in the written record, even though steps 7-8 evaluate
    # capabilities in Registry-declaration order (the evaluation order
    # itself is never re-sorted, only this feature's own output array).
    sorted_evaluations = sorted(capability_evaluations or [], key=lambda entry: entry["capability_id"])
    # AC-056/AC-024: every already-collected `severity: "warn"`
    # diagnostics[] entry (one per individual `outcome: "warn"`
    # DSL-evaluation node -- see `_evaluate_capabilities`) plus exactly one
    # summary `severity: "block"` entry -- sharing the identical
    # `diagnostic_id` on the step-9 Block, or carrying the abort's own
    # different id on a steps-7/8 abort path (amendment A①, human-approved
    # 2026-08-24: the abort and the warns are jointly caused by the same
    # evaluation pass) -- are combined, then the WHOLE array is stable-sorted
    # by `(id, detail)` (AC-024's own stable-sort discipline covers
    # `diagnostics[]` generally, not only `capability_evaluations[]`
    # above) -- never left in declaration-evaluation-then-summary emission
    # order, which is not itself a `(id, detail)` sort whenever a warn
    # entry's own `detail` does not happen to sort after the summary's
    # fixed sentence. Every other diagnostic path passes no
    # `warn_diagnostics`, so this sort is a no-op there (a 1-element list
    # is already sorted).
    diagnostics = sorted(
        list(warn_diagnostics or []) + [{"id": diagnostic_id, "detail": detail, "severity": "block"}],
        key=lambda entry: (entry["id"], entry["detail"]),
    )
    evidence = {
        "schema": EVIDENCE_SCHEMA,
        "feature": feature,
        "capability_evaluations": sorted_evaluations,
        "diagnostics": diagnostics,
    }
    if state_marker is not None:
        evidence["state"] = state_marker
    # Cross-model panel finding (T-004 NEEDS_WORK cycle 2, "late Blocks
    # drop provenance"): once step 10 has computed `context_binding`/
    # `resolver` (design.md step 11 defines their derivation; step 14
    # publishes "Resolver Evidence alone" on any Block reached at step
    # 10/12/13, the identical already-assembled record, never a
    # provenance-stripped one), every later Block call site threads those
    # SAME values through so this record is REQ-004's "full Resolver
    # Evidence record", not just its diagnostics/capability_evaluations
    # half. A Block reached before step 10 (disabled-legacy/workflow-
    # invalid/project-context-invalid/steps 4-9) never has these values to
    # give, so every call site there simply omits both kwargs (default
    # None) and this record is unaffected -- identical to before this fix.
    if context_binding is not None:
        evidence["context_binding"] = context_binding
    if resolver_block is not None:
        evidence["resolver"] = resolver_block
    # Panel round 5 (openai, Major, AC-012): a Block's own Resolver Evidence
    # record is written DIRECTLY -- `temp file + fsync + rename`, no staging
    # area and no journal -- because that is what the frozen design says, in
    # two places, and what REQ-001 step (m) and requirements.md's own Roles
    # and Permissions table authorize as the second publication route ("direct
    # temp+fsync+rename when Evidence is the whole write set").
    #
    #   design.md:1419  "`resolver-evidence.yaml` itself receives this
    #     invocation's own Block record, written directly (`temp file + fsync
    #     + rename`, no staging area, no journal -- REQ-001 step (m); opening
    #     a second journal against the very Feature whose existing journal
    #     this invocation has just declared unconvergeable would be
    #     incoherent), exactly as on the step-1 Block branches above."
    #   design.md:2846  "when Resolver Evidence is a Block's whole write set
    #     THAT WRITE NEVER PASSES THROUGH THE ON-DISK AREA: it is a direct
    #     `temp file + fsync + rename` with no staging area and no journal".
    #
    # The revision this replaces routed every Block's Evidence through
    # `_publish_and_complete`, and its comment asserted design.md said the
    # opposite of the two sentences above. That was the root cause of the
    # round-5 AC-012 finding rather than a separate defect: because the write
    # needed the staging area, the one Block whose premise IS a compromised
    # staging area could not perform it, and fell back to writing nothing --
    # behaviour outside AC-012's two stated exceptions, and outside the
    # owner's 2026-08-27 ruling that this Block writes Evidence directly.
    # With the direct route the staging area is irrelevant to this write, so
    # that Block emits its record like every other one.
    #
    # `_atomic_write_bytes` creates its temp file in the TARGET's own parent
    # (`specs/<feature>/`), never in the staging area, and `os.replace`
    # replaces a symlink at the target rather than following it. The
    # symlinked-PARENT case that `os.replace` cannot see is still refused
    # here, by the same round-2 check the journaled route applies.
    evidence_target = repo_root / "specs" / feature / "resolver-evidence.yaml"
    if _target_escapes_via_symlink(repo_root, feature, evidence_target):
        # Not `ArtifactPublicationFailed`: that id would relabel the Block a
        # publication failure and point the operator at the wrong cause. The
        # caller preserves whatever id it was already Blocking on and writes
        # nothing, which is the only fail-closed option when the record's own
        # destination lies outside the tree.
        raise EvidenceTargetUncontained(
            "this feature's own resolver-evidence.yaml does not resolve inside its own specs/<feature> directory"
        )
    try:
        _atomic_write_bytes(evidence_target, _canonical_payload(evidence))
    except OSError as exc:
        # No live rename was ever committed on this route -- the direct write
        # either renamed into place or did not -- so the count is 0 and the
        # canonical no-rollback-needed clause is the accurate one.
        raise ArtifactPublicationFailed(_rollback_clause(0, True)) from exc


def _block(
    repo_root, feature, diagnostic_id, detail, state_marker,
    capability_evaluations=None, warn_diagnostics=None,
    context_binding=None, resolver_block=None,
):
    """The exit code alone. Forty call sites want exactly this, so the return
    type does not change for any of them."""
    return _block_reporting(
        repo_root, feature, diagnostic_id, detail, state_marker,
        capability_evaluations, warn_diagnostics, context_binding, resolver_block,
    )[0]


def _block_reporting(
    repo_root, feature, diagnostic_id, detail, state_marker,
    capability_evaluations=None, warn_diagnostics=None,
    context_binding=None, resolver_block=None,
):
    """`_block`, plus whether the Block record actually reached Evidence's
    live path: returns `(exit_code, wrote_evidence)`.

    Added 2026-08-28 (openai panel slot, round 12 Major). Round 9 deferred the
    journal's deletion past the Block Evidence write so a crash in between
    would leave the journal for the recovery scan -- but it guarded that
    deletion on `complete`, which is whether the ROLLBACK finished, not
    whether the record became durable. `_block` swallows both write-failure
    conditions into `_block_no_write` and returns a bare exit code, so the
    caller could not tell the difference. The journal was therefore discarded
    even when Evidence had not been written, leaving exactly the state the
    round-9 fix existed to prevent: artifacts back at PRE, the SUCCESS-form
    Evidence still live from the commit, and no journal for anyone to notice.

    Only the two post-publication branches need the second value; everything
    else calls `_block` and is untouched."""
    try:
        _write_evidence(
            repo_root, feature, diagnostic_id, detail, state_marker,
            capability_evaluations, warn_diagnostics,
            context_binding, resolver_block,
        )
    except EvidenceTargetUncontained:
        # Panel round 5: this feature's own Evidence artifact has no valid
        # location -- `specs/<feature>/resolver-evidence.yaml` does not
        # resolve inside `specs/<feature>/`. Writing it would be the very
        # escape every round since round 1 has been closing, so nothing is
        # written; but the ORIGINAL diagnostic id is preserved rather than
        # relabelled, so the operator sees the cause this invocation actually
        # Blocked on. This is the only condition under which a Block outside
        # AC-012's two stated exceptions emits no record, and it is narrower
        # than the staging-area condition it replaced: a compromised staging
        # area no longer suppresses Evidence, because the direct write route
        # design.md requires does not touch that area at all.
        return _block_no_write(diagnostic_id, detail), False
    except ArtifactPublicationFailed as exc:
        # Fail-closed terminal, defense-in-depth: this invocation had already
        # decided to Block, and the direct write that publishes
        # that Block's own record has itself failed. Writing the record is
        # then impossible by definition, so re-entering `_block` for the
        # `artifact-publication-failed` row would recurse forever; instead
        # the canonical line is emitted with no live write at all, exactly as
        # `_block_no_write` (step 12's own Evidence-itself-fails case) already
        # does for the other condition under which no record can be written.
        # No fixture reaches this branch -- every REQ-002 row that CAN be
        # reached still writes Evidence (AC-012) -- and it is deliberately
        # kept rather than left to surface as an uncaught traceback, matching
        # this file's own existing treatment of `_resolved_gates`'s
        # unreachable dangling-`gate_id` branch.
        return _block_no_write(
            "artifact-publication-failed",
            f"{ARTIFACT_PUBLICATION_FAILED_PREFIX}; {exc.rollback_clause}",
        ), False
    sys.stderr.write(f"capability-resolver: {diagnostic_id}: {detail}\n")
    return EXIT_BLOCK, True


def _projection(document, source_sha256):
    components = {}
    for component in document.get("components", []):
        components[component["id"]] = {key: value for key, value in component.items() if key != "id"}
    return {
        "schema": "sdd-context-projection/v1",
        "source_sha256": source_sha256,
        "workflow": document["workflow"],
        "components": components,
        "shared_paths": document.get("shared_paths", []),
    }


# ---------------------------------------------------------------------------
# T-004 (steps 10-13): track branch, Resolver Evidence assembly, output
# schema self-validation, pre-publication snapshot recheck.
# ---------------------------------------------------------------------------


def _rfc6901_escape(token):
    return token.replace("~", "~0").replace("/", "~1")


def _dependency_pointers(affected_components):
    """B9 (Data Plan, no upstream rule fixed this): exactly `/workflow`
    plus one RFC-6901-escaped `/components/<id>` pointer per affected
    component (never every component the Project Context declares), the
    resulting set stable-sorted and de-duplicated. `/shared_paths` is
    never included (Data Plan, "dependency_pointers[] -- canonical
    derivation rule")."""
    pointers = {"/workflow"}
    for component_id in affected_components:
        pointers.add("/components/" + _rfc6901_escape(component_id))
    return sorted(pointers)


def _required_facets(registry_document, matched_capability_ids):
    capabilities_by_id = {c["id"]: c for c in registry_document.get("capabilities", [])}
    facets = set()
    for capability_id in matched_capability_ids:
        facets.update(capabilities_by_id.get(capability_id, {}).get("required_facets", []))
    return sorted(facets)


def _resolved_gates(registry_document, matched_capability_ids):
    """Every matched Capability's own `gate_ids[]`, resolved via a
    Resolver-side join against the discovered Registry's own `gates[]`, at
    any `stage` value -- this feature does not filter to
    `stage: implementation` only (Design Decisions, "resolved_gates[]
    includes ... at any stage value")."""
    capabilities_by_id = {c["id"]: c for c in registry_document.get("capabilities", [])}
    gates_by_id = {g["id"]: g for g in registry_document.get("gates", [])}
    seen = set()
    resolved = []
    for capability_id in matched_capability_ids:
        for gate_id in capabilities_by_id.get(capability_id, {}).get("gate_ids", []):
            # Confirmation-panel Minor (Anthropic T-004): a `gate_id` this
            # join cannot resolve against `gates_by_id` is silently
            # dropped here rather than Blocking, which would be a live
            # under-population defect if a Registry with a dangling
            # `gate_ids` reference could ever reach this point. It
            # cannot: step 5's own `validate-capability-registry` (Epic
            # A2, check (f) `dangling-gate-reference`) already Blocks
            # `registry-validation-failed` on exactly this condition --
            # `capabilities[].gate_ids` referential integrity against
            # `gates[]` -- for the WHOLE Registry, unconditionally,
            # before step 7-8 evaluation (and therefore this function,
            # step 10) ever runs; this feature's own `registry-
            # validation-failed` Block fixture (`tests/fixtures/
            # capability-resolver/resolve-project-context-block/
            # registry-validation-failed/`) already exercises precisely
            # this condition (its own Registry declares `gate_ids:
            # ["nonexistent-gate"]` against an empty `gates: []]`, and
            # this invocation Blocks at step 5, never reaching this
            # join). Design decision (decision-document v2 s19, "Block
            # when ambiguous"): this is not ambiguous -- the Registry
            # content this join would need to under-populate against is
            # already unreachable, so the `continue` below is
            # defense-in-depth against a condition Epic A2's own
            # validator has already fully closed off, never a live
            # under-population path in production.
            if gate_id in seen or gate_id not in gates_by_id:
                continue
            seen.add(gate_id)
            gate = gates_by_id[gate_id]
            resolved.append({"id": gate_id, "stage": gate["stage"], "blocking": gate["blocking"]})
    resolved.sort(key=lambda entry: entry["id"])
    return resolved


def _capability_minimum_enforcement(registry_document, matched_capability_ids):
    """The `max()` (logical OR, since `"required"` is the schema's own
    only non-absent value) of every matched Capability's own
    `minimum_enforcement` -- the key is omitted entirely (never a false-ish
    placeholder) when no matched Capability names it, matching the
    Facet Manifest schema's own optional, `const: "required"`-only field."""
    capabilities_by_id = {c["id"]: c for c in registry_document.get("capabilities", [])}
    for capability_id in matched_capability_ids:
        if capabilities_by_id.get(capability_id, {}).get("minimum_enforcement") == "required":
            return "required"
    return None


def _lite_eligibility(registry_document, matched_capability_ids):
    """The aggregate `{eligible, upgrade_reasons}` signal both 10a's own
    Facet Manifest field and 10b's own `full_upgrade_required` derive
    from: `eligible` is the AND of every matched Capability's own
    `lite_policy.eligible` (a single non-lite-eligible matched Capability
    forces the aggregate non-eligible, the identical union/soundness
    argument this feature's own Design Decisions already apply to
    `trigger`/`when` matching, one level higher); `upgrade_reasons` is the
    stable-sorted, de-duplicated union of every matched Capability's own
    `lite_policy.upgrade_reasons`. Zero matched Capabilities is vacuously
    `{eligible: true, upgrade_reasons: []}` (Edge Cases, "zero affected
    components" -- the identical vacuous shape applies here since an empty
    AND is true and an empty union is `[]`)."""
    capabilities_by_id = {c["id"]: c for c in registry_document.get("capabilities", [])}
    eligible = True
    reasons = set()
    for capability_id in matched_capability_ids:
        policy = capabilities_by_id.get(capability_id, {}).get("lite_policy") or {}
        if not policy.get("eligible", True):
            eligible = False
        reasons.update(policy.get("upgrade_reasons", []))
    return {"eligible": eligible, "upgrade_reasons": sorted(reasons)}


def _aggregate_conditional_facets(capability_evaluations):
    """Step 10a's own cross-Capability facet-name aggregation (Design
    Decisions "facet-name aggregation, predicate-instance keyed", B7).
    Aggregates, per distinct `facet` name, across every predicate instance
    `(capability_id, declaration_index)` -- Registry-wide, across every
    matched Capability -- whose own `conditional_facets[declaration_index].
    facet` equals that name: `applied` is the OR of every contributing
    instance's own `applied` (step 8's own per-instance union-match
    result); `evidence` is the concatenation of every contributing
    `(capability_id, declaration_index, component_id)` triple's own
    evaluation-node array, ordered `capability_id`-then-`declaration_
    index`-then-`component_id` ascending; `reason` (present iff
    `applied: false`) names every contributing predicate instance in the
    identical ascending order."""
    contributions = {}
    for entry in capability_evaluations:
        if not entry.get("matched"):
            continue
        for cfe in entry.get("conditional_facet_evaluations", []):
            contributions.setdefault(cfe["facet"], []).append(
                (entry["capability_id"], cfe["declaration_index"], cfe["applied"], cfe["evaluations"])
            )

    result = []
    for facet in sorted(contributions):
        instances = sorted(contributions[facet], key=lambda instance: (instance[0], instance[1]))
        applied = any(instance[2] for instance in instances)
        evidence = []
        for _capability_id, _declaration_index, _applied, evaluations in instances:
            for evaluation in sorted(evaluations, key=lambda e: e["component_id"]):
                evidence.extend(evaluation["evidence"])
        node = {"facet": facet, "applied": applied, "evidence": evidence}
        if not applied:
            names = ", ".join(f"{cid}[{idx}]" for cid, idx, _a, _e in instances)
            node["reason"] = (
                "no contributing predicate instance's conditional facet matched "
                f"any affected component (contributing: {names})"
            )
        result.append(node)
    return result


def _assemble_facet_manifest(feature, affected_components, registry_document, capability_evaluations, context_binding, resolver_block):
    """Step 10a: Full-track Facet Manifest assembly (staged only)."""
    matched_ids = sorted(entry["capability_id"] for entry in capability_evaluations if entry["matched"])
    manifest = {
        "schema": "sdd-facet-manifest/v1",
        "feature": feature,
        "affected_components": sorted(set(affected_components)),
        "required_facets": _required_facets(registry_document, matched_ids),
        "conditional_facets": _aggregate_conditional_facets(capability_evaluations),
        "resolved_gates": _resolved_gates(registry_document, matched_ids),
        "capabilities": matched_ids,
        "lite_eligibility": _lite_eligibility(registry_document, matched_ids),
        "context_binding": context_binding,
        "resolver": resolver_block,
    }
    enforcement = _capability_minimum_enforcement(registry_document, matched_ids)
    if enforcement is not None:
        manifest["capability_minimum_enforcement"] = enforcement
    return manifest


def _assemble_capability_summary(feature, registry_document, capability_evaluations, state):
    """Step 10b: Lite-track Capability Summary assembly (staged only).
    Raises LiteCheckSourceUndefined (B5-narrowed) iff `state == "required"`
    and at least one matched Capability's own `lite_policy.
    required_lite_checks` key is absent; under `advisory`, an absent key
    contributes an empty `[]` instead."""
    capabilities_by_id = {c["id"]: c for c in registry_document.get("capabilities", [])}
    matched_ids = sorted(entry["capability_id"] for entry in capability_evaluations if entry["matched"])
    required_lite_checks = set()
    for capability_id in matched_ids:
        lite_policy = capabilities_by_id.get(capability_id, {}).get("lite_policy") or {}
        if "required_lite_checks" in lite_policy:
            required_lite_checks.update(lite_policy["required_lite_checks"])
        elif state == "required":
            raise LiteCheckSourceUndefined(capability_id)
        # else: advisory (or a non-required state) -- absent contributes [].
    lite_eligibility = _lite_eligibility(registry_document, matched_ids)
    return {
        "schema": "sdd-capability-summary/v1",
        "feature": feature,
        "track": "lite",
        "capabilities": matched_ids,
        "required_lite_checks": sorted(required_lite_checks),
        "full_upgrade_required": not lite_eligibility["eligible"],
    }


def _assemble_context_binding(source_sha256, affected_components, projection_sha256, registry_digest, ownership_digest):
    return {
        "full_context_revision": source_sha256,
        "dependency_pointers": _dependency_pointers(affected_components),
        "projection_sha256": projection_sha256,
        "registry_digest": registry_digest,
        "ownership_digest": ownership_digest,
    }


def _resolver_block():
    return {"version": RESOLVER_VERSION, "rule_set_revision": RULE_SET_REVISION}


def _assemble_resolver_evidence(feature, state, capability_evaluations, context_binding, resolver_block):
    """Step 11: Resolver Evidence assembly (staged only) for a clean
    resolve -- `diagnostics: []` (no Block condition fired through step
    10), every `capability_evaluations[]` entry from steps 7-8 in full."""
    return {
        "schema": EVIDENCE_SCHEMA,
        "feature": feature,
        "state": state,
        "context_binding": context_binding,
        "resolver": resolver_block,
        "capability_evaluations": sorted(capability_evaluations, key=lambda entry: entry["capability_id"]),
        "diagnostics": [],
    }


# --- Step 12: output schema self-validation (B3) --------------------------
#
# A hand-rolled, stdlib-only draft-07 subset engine -- reimplemented locally
# rather than imported, mirroring Epic A4's own `validate-facet-manifest.py`
# engine closely enough to validate against the identical governing schema
# documents ($ref, if/then/else, oneOf, propertyNames, pattern, uniqueItems,
# minItems). Resolver Evidence's own self-check has no external validator
# script to shell out to at all -- `validate-resolver-evidence` is T-008's
# own, not-yet-built deliverable -- so this feature's own step 12 validates
# every governing schema (Facet Manifest/Capability Summary/Context
# Projection/Resolver Evidence) the identical, uniform, in-process way.


def _draft7_type_matches(value, type_spec):
    if isinstance(type_spec, list):
        return any(_draft7_type_matches(value, entry) for entry in type_spec)
    if type_spec == "object":
        return isinstance(value, dict)
    if type_spec == "array":
        return isinstance(value, list)
    if type_spec == "string":
        return isinstance(value, str)
    if type_spec == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if type_spec == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if type_spec == "boolean":
        return isinstance(value, bool)
    if type_spec == "null":
        return value is None
    return False


def _draft7_resolve_ref(ref, root_schema):
    if not ref.startswith("#/"):
        raise ValueError(f"unsupported $ref (not a same-document fragment): {ref}")
    node = root_schema
    for part in ref[2:].split("/"):
        node = node[part.replace("~1", "/").replace("~0", "~")]
    return node


def _ecma_anchored_pattern(pattern):
    """T-004 confirmation-panel Minor (Anthropic): JSON Schema's own
    `pattern` keyword fixes ECMA-262 regex semantics, where `$` matches
    ONLY at the true end of the subject string. Python's `re` module's own
    `$` additionally matches immediately before a single trailing `\\n`,
    so `re.search(r"^sha256:[0-9a-f]{64}$", "sha256:" + "a" * 64 + "\\n")`
    -- a value ECMA-262/JSON-Schema itself rejects -- previously passed
    this file's own step-12 defensive self-check. Every governing schema
    this feature discovers (`sha256Digest`'s `^sha256:[0-9a-f]{64}$`,
    `feature`'s `^[a-z0-9][a-z0-9-]*$`, confirmed directly against all
    four landed documents) uses only a trailing, unescaped `$` -- the one
    shape translated here, to Python's own `\\Z` (true-end-of-string,
    no trailing-newline exception); a `$` anywhere else in a pattern, or
    an escaped `\\$` (a literal dollar sign), is left untouched."""
    if pattern.endswith("$") and (len(pattern) < 2 or pattern[-2] != "\\"):
        return pattern[:-1] + r"\Z"
    return pattern


def _draft7_matches(instance, schema, root_schema):
    probe = []
    _draft7_validate(instance, schema, root_schema, "", probe)
    return not probe


def _draft7_validate(instance, schema, root_schema, pointer, diags):
    if schema is True:
        return
    if schema is False:
        diags.append(pointer)
        return
    if "$ref" in schema:
        _draft7_validate(instance, _draft7_resolve_ref(schema["$ref"], root_schema), root_schema, pointer, diags)
        return
    if "const" in schema and instance != schema["const"]:
        diags.append(pointer)
        return
    if "enum" in schema and instance not in schema["enum"]:
        diags.append(pointer)
        return
    if "type" in schema and not _draft7_type_matches(instance, schema["type"]):
        diags.append(pointer)
        return
    if "oneOf" in schema:
        matches = sum(1 for branch in schema["oneOf"] if _draft7_matches(instance, branch, root_schema))
        if matches != 1:
            diags.append(pointer)
    if "if" in schema:
        if _draft7_matches(instance, schema["if"], root_schema):
            if "then" in schema:
                _draft7_validate(instance, schema["then"], root_schema, pointer, diags)
        elif "else" in schema:
            _draft7_validate(instance, schema["else"], root_schema, pointer, diags)
    # `not` (T-004 NEEDS_WORK cycle 2, OpenAI panelist): this driver's own
    # `resolver-evidence.schema.json` uses `"then": {"not": {"required":
    # [...]}}` to forbid `conditional_facet_evaluations` on an unmatched
    # `capabilityEvaluation` entry (B6) -- an unimplemented `not` silently
    # no-ops that whole branch (`_draft7_validate` returns having checked
    # nothing), so a `matched: false` entry carrying that key previously
    # passed step 12's self-validation regardless.
    if "not" in schema and _draft7_matches(instance, schema["not"], root_schema):
        diags.append(pointer)
    if isinstance(instance, str):
        if "pattern" in schema and not re.search(_ecma_anchored_pattern(schema["pattern"]), instance):
            diags.append(pointer)
        if "minLength" in schema and len(instance) < schema["minLength"]:
            diags.append(pointer)
    # `minimum` (T-004 NEEDS_WORK cycle 2, OpenAI panelist): only
    # `capabilityEvaluation.conditional_facet_evaluations[].declaration_
    # index` declares `"minimum": 0` among this driver's own four
    # governing schemas -- an unimplemented `minimum` previously let a
    # negative `declaration_index` (never producible by this feature's own
    # `_evaluate_capabilities`, which only ever `enumerate()`s, but a
    # defensive check this task's REQ-002 fail-closed contract still
    # requires actually enforcing) pass step 12 unnoticed.
    if isinstance(instance, (int, float)) and not isinstance(instance, bool):
        if "minimum" in schema and instance < schema["minimum"]:
            diags.append(pointer)
    if isinstance(instance, dict):
        for required_key in schema.get("required", []):
            if required_key not in instance:
                diags.append(f"{pointer}/{required_key}")
        properties = schema.get("properties", {})
        for key, value in instance.items():
            if key in properties:
                _draft7_validate(value, properties[key], root_schema, f"{pointer}/{key}", diags)
        if "propertyNames" in schema:
            for key in instance:
                _draft7_validate(key, schema["propertyNames"], root_schema, f"{pointer}/{key}", diags)
        additional = schema.get("additionalProperties", True)
        if additional is not True:
            extra_keys = [key for key in instance if key not in properties]
            if additional is False:
                for key in extra_keys:
                    diags.append(f"{pointer}/{key}")
            else:
                for key in extra_keys:
                    _draft7_validate(instance[key], additional, root_schema, f"{pointer}/{key}", diags)
    if isinstance(instance, list):
        if "items" in schema:
            items_schema = schema["items"]
            for index, element in enumerate(instance):
                _draft7_validate(element, items_schema, root_schema, f"{pointer}/{index}", diags)
        if schema.get("uniqueItems"):
            seen = []
            for index, element in enumerate(instance):
                canonical = json.dumps(element, sort_keys=True)
                if canonical in seen:
                    diags.append(f"{pointer}/{index}")
                else:
                    seen.append(canonical)
        if "minItems" in schema and len(instance) < schema["minItems"]:
            diags.append(pointer)


def _draft7_conforms(document, schema):
    diags = []
    _draft7_validate(document, schema, schema, "", diags)
    return not diags


def _discover_governing_schema(script_dir, repo_root, filename):
    """Step 12's own ADR-0025-style discovery for a governing output
    schema: the packaged, script-relative `contracts/` copy first, then
    the git-root `contracts/` fallback -- the identical two-step order
    `registry_discovery.discover_artifact` already uses for the Registry
    (step 5), reimplemented locally here rather than reused, since that
    shared module's own `VERSION_CHECKS` table is closed to Epic A2's own
    three registry-family filenames and this feature's own Global
    Constraints forbid editing any file under `plugins/**`, including
    `registry_discovery.py` itself. A resolution failure maps to the
    identical `contract-discovery-failed` diagnostic REQ-002 already names
    for "any of Epic A4's three schemas" failing this same procedure."""
    packaged = script_dir.parent / "contracts" / filename
    if packaged.is_file():
        return packaged
    git_path = repo_root / "contracts" / filename
    if git_path.is_file():
        return git_path
    raise ContractDiscoveryFailed(f"{filename} not found at the packaged or git-root contracts/ location")


# Cross-model panel finding (T-004 NEEDS_WORK cycle 2, OpenAI panelist):
# every real governing schema this feature discovers publishes the
# identical `https://github.com/aharada54914/sdd-forge/contracts/<filename>`
# `$id` convention (confirmed directly against all four landed documents),
# mirroring `registry_discovery.EXPECTED_SCHEMA_ID`'s own identical
# prefix-plus-filename shape for the Registry's own schema sibling (step
# 5) -- reimplemented locally here rather than reused, for the same
# `plugins/**` Global-Constraints reason `_discover_governing_schema`'s
# own docstring already gives.
GOVERNING_SCHEMA_ID_PREFIX = "https://github.com/aharada54914/sdd-forge/contracts/"


def _governing_schema_version_ok(document, filename):
    """REQ-002/AC-002's own per-artifact `$schema`/`$id` version check for
    a governing output schema (step 12): presence of `$schema` plus an
    EXACT `$id` match, never merely "a JSON document was found at this
    location" -- the identical check `registry_discovery.
    check_capability_registry_schema` already applies to the Registry's
    own schema sibling. A wrong-version or substituted schema document
    must Block `contract-discovery-failed` rather than silently
    self-validate against it (cross-model panel finding, T-004 NEEDS_WORK
    cycle 2, OpenAI panelist)."""
    return (
        isinstance(document, dict)
        and "$schema" in document
        and document.get("$id") == GOVERNING_SCHEMA_ID_PREFIX + filename
    )


def _load_governing_schema(script_dir, repo_root, filename):
    path = _discover_governing_schema(script_dir, repo_root, filename)
    try:
        with path.open("r", encoding="utf-8") as handle:
            document = json.load(handle)
    except (OSError, json.JSONDecodeError, UnicodeDecodeError) as exc:
        # Cross-model panel finding (T-004 NEEDS_WORK cycle 2, OpenAI
        # panelist): the raw exception text (an absolute path, errno
        # wording, OS-specific phrasing) must never be interpolated into a
        # diagnostic this invocation writes to Resolver Evidence/stderr --
        # AC-014's own canonical-sentence rule and security-spec.md B5's
        # no-local-path containment. Only the exception's own CLASS NAME
        # (a fixed, stable, cross-runtime-identical token, e.g. "OSError"/
        # "JSONDecodeError") is included, never `str(exc)`. `UnicodeDecode
        # Error` (T-004 confirmation-panel bookkeeping-lag delta, OpenAI
        # v3 Major 3): a governing schema file containing invalid UTF-8
        # bytes previously escaped this handler entirely -- `json.load`
        # raises `UnicodeDecodeError` (a `ValueError` subclass, not an
        # `OSError`/`JSONDecodeError`) while consuming the open text-mode
        # handle, and would surface as a raw, uncaught traceback rather
        # than the canonical `contract-discovery-failed` Block REQ-002
        # requires for every governing-schema-handling failure.
        raise ContractDiscoveryFailed(
            f"{filename} could not be read or parsed ({type(exc).__name__})"
        ) from exc
    if not _governing_schema_version_ok(document, filename):
        raise ContractDiscoveryFailed(f"{filename} failed its own $schema/$id version check")
    return document


def _draft7_conforms_or_raise(instance, schema, filename):
    """Wraps `_draft7_conforms` so a MALFORMED governing schema document
    (never the instance under validation) cannot escape as a raw,
    uncaught traceback (T-004 confirmation-panel bookkeeping-lag delta,
    OpenAI v3 Major 3): `_draft7_resolve_ref` walks a `$ref`'s own
    fragment path directly against `root_schema` with no existence/type
    guard, so a `$ref` naming a definition the schema's own `definitions`
    block never declares raises `KeyError` (or `TypeError`/`IndexError` if
    an intermediate node is not a dict/list at all), and a `$ref` that is
    not itself a string raises `AttributeError` from its own leading
    `.startswith` check; `_draft7_resolve_ref`'s own explicit
    non-fragment guard raises `ValueError`. Every one of these is a
    property of the malformed governing SCHEMA document, not the instance
    -- reclassified here as `ContractDiscoveryFailed`, matching every
    other `_load_governing_schema`-adjacent failure this same function's
    caller already funnels into the identical `contract-discovery-failed`
    id (REQ-002), never `OutputSchemaValidationFailed` (that id is
    reserved for a well-formed schema the CORRECT instance still fails).
    Only the exception's own CLASS NAME is included in the diagnostic,
    matching `_load_governing_schema`'s own no-raw-text discipline."""
    try:
        return _draft7_conforms(instance, schema)
    except (KeyError, TypeError, AttributeError, IndexError, ValueError) as exc:
        raise ContractDiscoveryFailed(
            f"{filename} contains a malformed $ref ({type(exc).__name__})"
        ) from exc


def _self_validate_output(script_dir, repo_root, evidence, context_projection, track_artifact, track_artifact_schema_filename, track_artifact_name):
    """Step 12 (B3). Resolver Evidence (already staged, step 11) is
    re-validated FIRST -- if it is itself the artifact that fails, the
    caller must write NOTHING to any live path, not even a best-effort,
    fields-omitted Evidence instance (the sole exception to REQ-002's
    "Evidence always emitted" rule). Context Projection (staged at step 3
    on every invocation, regardless of track) is checked next, then the
    track-exclusive artifact (Facet Manifest on `full`, Capability Summary
    on `lite`) last -- if either check after Evidence's own fails,
    Resolver Evidence itself (already independently schema-valid) is still
    written normally as this Block's own record."""
    evidence_schema = _load_governing_schema(script_dir, repo_root, RESOLVER_EVIDENCE_SCHEMA_FILENAME)
    if not _draft7_conforms_or_raise(evidence, evidence_schema, RESOLVER_EVIDENCE_SCHEMA_FILENAME):
        raise OutputSchemaValidationFailed("resolver-evidence")

    projection_schema = _load_governing_schema(script_dir, repo_root, CONTEXT_PROJECTION_SCHEMA_FILENAME)
    if not _draft7_conforms_or_raise(context_projection, projection_schema, CONTEXT_PROJECTION_SCHEMA_FILENAME):
        raise OutputSchemaValidationFailed("context-projection")

    track_schema = _load_governing_schema(script_dir, repo_root, track_artifact_schema_filename)
    if not _draft7_conforms_or_raise(track_artifact, track_schema, track_artifact_schema_filename):
        raise OutputSchemaValidationFailed(track_artifact_name)


def _pre_publication_recheck(script_dir, args, absolute_config, source_sha256, affected_components, ownership_digest, registry_digest):
    """Step 13 (B8 TOCTOU, Data Plan gives the digest-derivation
    mechanism). Re-reads the Project Context, re-invokes `resolve-
    component-paths` for a FRESH `ownership_digest` and a FRESH
    `affected_components` set (B8 correction -- `ownership_digest` alone
    cannot detect a diff-only generation change), and re-derives
    `registry_digest`; any digest mismatch, or any `affected_components`
    set difference (even with every digest, including `ownership_digest`,
    still matching), raises SnapshotGenerationMismatch. This function
    performs no live write of any kind -- the values it recomputes are
    used only for this comparison; a passing recheck changes nothing this
    invocation has already computed.

    A dependency subprocess this function itself invokes (the second
    canonicalizer pass, the second `resolve-component-paths` call, the
    second `generate-registry-digest --whole` call) failing to even RUN is
    a distinct condition from that same subprocess running and reporting
    genuine drift -- re-labeling every such failure as
    `snapshot-generation-mismatch` (an earlier revision of this function
    did exactly that) asserts "a pre-publication recheck ... detected
    drift" when the true cause is a subprocess failure, which is neither
    accurate (AC-014's own canonical-sentence rule) nor this function's own
    fail-closed contract's most specific match (cross-model panel finding,
    T-004 NEEDS_WORK cycle 2). Every helper below is therefore called
    UNWRAPPED here: `CanonicalizerFailed`/`CanonicalizerOutputMalformed`/
    `AffectedComponentResolutionFailed`/`DependencySubprocessFailed`/
    `DependencyOutputMalformed` propagate to the caller unchanged, mapped
    by `main()`'s own step-13 handler to the SAME REQ-002 diagnostic id
    steps 2/4/6 already use for an identical failure (ids are already
    reused across multiple steps throughout this file -- `canonicalizer-
    invocation-failed` alone already covers steps 2/3/6). This function's
    own `SnapshotGenerationMismatch` is raised ONLY by the drift comparison
    below, never as a catch-all for a recheck subprocess that could not
    even run."""
    fresh_canonical, _fresh_document = _canonicalize(absolute_config, "yaml")
    fresh_source_sha256 = "sha256:" + hashlib.sha256(fresh_canonical).hexdigest()

    fresh_affected_components, fresh_ownership_digest = _run_resolve_component_paths(script_dir, args)

    fresh_registry_digest = _generate_registry_digest_whole(script_dir)

    if (
        fresh_source_sha256 != source_sha256
        or fresh_ownership_digest != ownership_digest
        or fresh_registry_digest != registry_digest
        or set(fresh_affected_components) != set(affected_components)
    ):
        raise SnapshotGenerationMismatch("snapshot recheck detected drift")


# Step 14's own post-publication verification reuses `_pre_publication_
# recheck` verbatim (identical sources, identical comparison), so it can
# raise the identical dependency exceptions. Each maps to the SAME REQ-002
# diagnostic id its own originating step already uses, with a `<detail>`
# naming the post-publication window rather than the pre-publication one --
# the identical id-reuse discipline step 13's own handlers already apply
# (ids are reused across steps throughout this file; `canonicalizer-
# invocation-failed` alone already covers steps 2/3/6/13).
_POST_PUBLICATION_DEPENDENCY_BLOCKS = {
    CanonicalizerFailed: (
        "canonicalizer-invocation-failed",
        "canonicalize-sdd-yaml failed while re-canonicalizing the project context during the "
        "post-publication verification",
    ),
    CanonicalizerOutputMalformed: (
        "dependency-output-malformed",
        "canonicalize-sdd-yaml returned malformed JSON while re-canonicalizing the project context "
        "during the post-publication verification",
    ),
    AffectedComponentResolutionFailed: (
        "affected-component-resolution-failed",
        "resolve-component-paths failed re-resolving affected components during the post-publication "
        "verification; see resolve-component-paths diagnostics",
    ),
    DependencySubprocessFailed: (
        "dependency-subprocess-failed",
        "a dependency subprocess failed while re-deriving affected components or registry_digest "
        "during the post-publication verification",
    ),
    DependencyOutputMalformed: (
        "dependency-output-malformed",
        "a dependency subprocess returned malformed output while re-deriving affected components or "
        "registry_digest during the post-publication verification",
    ),
}


def _block_no_write(diagnostic_id, detail):
    """Step 12's own sole exception (B3): Resolver Evidence itself failed
    its own schema self-validation, so this invocation writes NOTHING to
    any live path at all, not even a best-effort record."""
    sys.stderr.write(f"capability-resolver: {diagnostic_id}: {detail}\n")
    return EXIT_BLOCK


def main(argv=None):
    args = _parse_args(argv)
    config_path = Path(args.config)
    absolute_config = config_path if config_path.is_absolute() else Path.cwd() / config_path
    # THE ANCHOR, resolved exactly ONCE, here (panel round 5, Major).
    #
    # `_find_repo_root` returns the caller's own lexical path verbatim for an
    # absolute `--config`, so `repo_root` could differ from its realpath
    # whenever the repository is reached through a symlinked ancestor -- the
    # ORDINARY case for any repo under macOS `/tmp` or `/var`, or any
    # symlinked checkout. That left ONE live path compared against THREE
    # anchors: `_allowed_publication_targets` mixed a raw-`repo_root` base
    # for its `specs/<feature>` entries with a symlink-RESOLVED base for its
    # `generated/` entry; `_repo_relative` wrote journal paths relative to
    # `repo_root.resolve()`; `_journal_target_path` rebuilt them against the
    # unresolved `repo_root`. The round trip was therefore not identity for
    # the script-dir-anchored target, and step 0.5 rejected a Full-track
    # journal THIS RESOLVER HAD WRITTEN as "outside the fixed publication
    # target set" -- permanently, on every later invocation, misattributing
    # its own artifact to the attack condition round 1's allowlist exists to
    # catch (REQ-002's own row promises the opposite: a convergeable journal
    # "is silently resolved by that same scan and never reaches this
    # diagnostic at all").
    #
    # Resolving here makes all three anchors coincide BY CONSTRUCTION rather
    # than by accident, which is the Standing Note's own rule applied to the
    # anchor itself: derive everything from one resolved root plus fixed
    # lexical subpaths. It weakens nothing -- the anchor is the `.git`-
    # bearing directory, which committed content cannot redirect, and no
    # INTERMEDIATE component is resolved anywhere.
    repo_root = Path(os.path.realpath(str(_find_repo_root(absolute_config))))

    # Step 0.5 (mandatory crash-recovery scan, design.md/infra-spec.md
    # `#journal-recovery`): runs on EVERY invocation, immediately after step
    # 0's own argument validation succeeds and before step 1 begins -- so a
    # stale journal is converged, or Blocked on, before any Registry/
    # ownership/Context-Projection work has happened at all.
    try:
        _crash_recovery_scan(repo_root, args.feature)
    except PublicationStagingAreaUncontained:
        # Panel round 3 (CRITICAL) established the refusal; panel round 5
        # (openai, Major) established that refusing must not also suppress
        # this Block's own Evidence record.
        #
        # The earlier revision returned `_block_no_write` here, reasoning
        # that a Block's Evidence write is a one-target journaled
        # transaction and so needs the very staging area this branch has
        # just declared compromised. That reasoning was sound about the
        # code as it then stood and wrong about the contract: design.md
        # requires an Evidence-only write to go DIRECTLY -- "no staging
        # area, no journal" (design.md:1419, :2846) -- which `_write_evidence`
        # now does. The staging area is therefore irrelevant to this write:
        # `_atomic_write_bytes` puts its temp file in `specs/<feature>/`
        # beside the target, so nothing here passes through the symlink that
        # caused the refusal.
        #
        # So this Block emits Evidence like every other one, and AC-012's
        # always-emitted rule holds with exactly its two stated exceptions --
        # no third exception, which is what the owner ruled on 2026-08-27.
        return _block(
            repo_root, args.feature, "publication-journal-recovery", JOURNAL_RECOVERY_DETAIL, None,
        )
    except PublicationJournalUnrecoverable:
        # The live state is left exactly as found, pending manual operator
        # intervention -- the scan itself has already refused to half-revert
        # anything (`_recover_journal` validates every backup before its
        # first restore). `state_marker` is None because the Project Context
        # has not been read yet, and never will be on this path.
        return _block(
            repo_root, args.feature, "publication-journal-recovery", JOURNAL_RECOVERY_DETAIL, None,
        )

    if not absolute_config.is_file():
        return _block(repo_root, args.feature, "disabled-legacy-invocation", args.config, "disabled-legacy")

    try:
        canonical_context, document = _canonicalize(absolute_config, "yaml")
    except CanonicalizerFailed:
        return _block(
            repo_root, args.feature, "canonicalizer-invocation-failed",
            "canonicalize-sdd-yaml failed while canonicalizing project context", None,
        )
    except CanonicalizerOutputMalformed:
        return _block(
            repo_root, args.feature, "dependency-output-malformed",
            "canonicalize-sdd-yaml returned malformed JSON while canonicalizing project context", None,
        )

    if not _project_context_valid(document, repo_root):
        return _block(
            repo_root, args.feature, "project-context-validation-failed",
            "project context does not conform to contracts/project-context.schema.json", None,
        )

    workflow = document["workflow"]
    state = workflow["capability_enforcement"]
    invalid = (
        workflow["spec_profile"] == "lite" and workflow["artifact_layout"] != "lite-three-file"
    ) or (
        workflow["spec_profile"] == "full" and workflow["artifact_layout"] == "lite-three-file"
    )
    if invalid:
        return _block(
            repo_root, args.feature, "workflow-combination-invalid",
            "workflow spec_profile/artifact_layout combination is invalid", state,
        )

    source_sha256 = "sha256:" + hashlib.sha256(canonical_context).hexdigest()
    projection = _projection(document, source_sha256)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".json", delete=False, newline="\n") as handle:
        json.dump(projection, handle, ensure_ascii=False, separators=(",", ":"))
        projection_input = Path(handle.name)
    try:
        try:
            canonical_projection, parsed_projection = _canonicalize(projection_input, "json")
        except CanonicalizerFailed:
            return _block(
                repo_root, args.feature, "canonicalizer-invocation-failed",
                "canonicalize-sdd-yaml failed while canonicalizing context projection", state,
            )
        except CanonicalizerOutputMalformed:
            return _block(
                repo_root, args.feature, "dependency-output-malformed",
                "canonicalize-sdd-yaml returned malformed JSON while canonicalizing context projection", state,
            )
    finally:
        projection_input.unlink(missing_ok=True)

    # T-002's own steps 0-3 staged values, retained in memory for T-004's
    # own step 11 (context_binding.projection_sha256, below). T-007:
    # `canonical_projection` itself is retained too -- it IS the staged
    # Context Projection candidate step 14 publishes to `generated/
    # project-context.resolved.json` on the Full track (design.md step 3,
    # "Staged, not written to a live path yet"), so the bytes whose digest
    # this line takes are the exact bytes that later reach that live path.
    projection_sha256 = "sha256:" + hashlib.sha256(canonical_projection).hexdigest()
    del canonical_context

    script_dir = Path(__file__).resolve().parent
    repo_relative_config = _repo_relative(absolute_config, repo_root)
    # The pass-2 canonicalizer's stdout is untrusted dependency output
    # exactly like pass 1's (security-spec B1 names both passes): a
    # zero-exit, PARSEABLE payload of the wrong TYPE (non-object
    # projection, or an object whose `components` is not an object)
    # previously escaped the parse-level checks: a non-object projection
    # crashed `.get` here with an uncaught AttributeError, and a
    # non-object `components` either sailed past step 3 to be
    # misattributed downstream (array/string) or crashed later
    # subscripting (numeric) (gate cycle-10 Major; projection
    # stub modes json-wrong-type / json-components-wrong-type).
    # Wrong-typed output IS malformed canonicalizer output -- same Block
    # row, same canonical sentence as the unparseable case.
    projection_components = (
        parsed_projection.get("components", {})
        if isinstance(parsed_projection, dict)
        else None
    )
    if not isinstance(projection_components, dict):
        return _block(
            repo_root, args.feature, "dependency-output-malformed",
            "canonicalize-sdd-yaml returned malformed JSON while canonicalizing context projection", state,
        )

    # Step 4: affected-component resolution (Epic A3).
    try:
        affected_components, ownership_digest = _run_resolve_component_paths(script_dir, args)
    except AffectedComponentResolutionFailed as exc:
        detail = (
            f"resolve-component-paths exited {exc.returncode} resolving "
            f"{repo_relative_config}; see resolve-component-paths diagnostics"
        )
        return _block(repo_root, args.feature, "affected-component-resolution-failed", detail, state)
    except DependencySubprocessFailed:
        detail = "resolve-component-paths failed to launch while resolving affected components"
        return _block(repo_root, args.feature, "dependency-subprocess-failed", detail, state)
    except DependencyOutputMalformed:
        detail = "resolve-component-paths returned malformed JSON while resolving affected components"
        return _block(repo_root, args.feature, "dependency-output-malformed", detail, state)

    # Step 5: Registry discovery (ADR-0025) + validate-capability-registry.
    try:
        registry_path, registry_document, registry_snapshot_digest = _discover_registry(script_dir)
    except ContractDiscoveryFailed:
        detail = "registry discovery failed to locate or verify capability-registry.json or capability-registry.schema.json"
        return _block(repo_root, args.feature, "contract-discovery-failed", detail, state)
    try:
        _validate_capability_registry(script_dir, registry_path)
    except RegistryValidationFailed:
        detail = "capability-registry.json failed validate-capability-registry checks"
        return _block(repo_root, args.feature, "registry-validation-failed", detail, state)
    except DependencySubprocessFailed:
        detail = "validate-capability-registry failed to launch while validating the located Registry"
        return _block(repo_root, args.feature, "dependency-subprocess-failed", detail, state)

    # Step 6: registry_digest.
    try:
        registry_digest = _generate_registry_digest_whole(script_dir)
    except CanonicalizerFailed:
        detail = "canonicalize-sdd-yaml failed while computing registry_digest"
        return _block(repo_root, args.feature, "canonicalizer-invocation-failed", detail, state)
    except DependencySubprocessFailed:
        detail = "generate-registry-digest failed while computing registry_digest"
        return _block(repo_root, args.feature, "dependency-subprocess-failed", detail, state)
    except DependencyOutputMalformed:
        detail = "generate-registry-digest returned malformed output while computing registry_digest"
        return _block(repo_root, args.feature, "dependency-output-malformed", detail, state)

    # Step 6.5 (ruling C(1), human-approved 2026-08-26 -- design.md's third
    # recheck, REQ-002's amended second trigger site): neither
    # `validate-capability-registry` above nor `generate-registry-digest
    # --whole` above accepts a path/bytes argument binding it to THIS
    # invocation's own step-5 `registry_document` read -- each independently
    # re-discovers/re-reads the Registry on its own. A Registry swap across
    # that window would let an unvalidated document reach steps 7-9 while
    # `registry_digest` describes different bytes entirely. Detection only
    # (see `_recheck_registry_snapshot`'s own honesty-limitation docstring):
    # this invocation re-reads the identical `registry_path` right now and
    # compares against the raw-bytes digest retained at step 5's own first
    # read.
    try:
        _recheck_registry_snapshot(registry_path, registry_snapshot_digest)
    except SnapshotGenerationMismatch:
        detail = (
            "the Registry changed between this invocation's own discovery read (step 5) and its "
            "post-validation/digest recheck (step 6)"
        )
        return _block(repo_root, args.feature, "snapshot-generation-mismatch", detail, state)

    # Steps 7-8: per-Capability/per-component trigger evaluation and
    # matched-Capability conditional-facet evaluation.
    capability_evaluations = []
    warn_diagnostics = []
    try:
        any_warn = _evaluate_capabilities(
            script_dir, registry_document, affected_components, projection_components,
            capability_evaluations, warn_diagnostics,
        )
    except RegistryValidationFailed:
        # Amendment A① (human-approved 2026-08-24): requirements.md's
        # AC-056 sentence now carries an explicit exception in the "or
        # jointly caused" shape -- `severity: "warn"` entries already
        # collected before an evaluation abort lawfully appear alongside
        # that abort's own different-id `severity: "block"` summary entry,
        # with no same-id summary (step 9 is never reached on this abort
        # path), when the abort and the warns are jointly caused by the
        # same evaluation pass. This reconciles the sentence with REQ-004's
        # own "recording every diagnostic-worthy condition this invocation
        # encountered" mandate: already-collected warn entries are
        # therefore FORWARDED, not dropped, on all three steps-7/8 abort
        # paths (restoring the forwarding 1811ed0e reversed when the
        # unamended sentence forbade it).
        detail = "a Registry-declared predicate failed predicate-schema validation"
        return _block(repo_root, args.feature, "registry-validation-failed", detail, state, capability_evaluations, warn_diagnostics)
    except DependencySubprocessFailed:
        detail = "evaluate-predicate failed while evaluating a predicate"
        return _block(repo_root, args.feature, "dependency-subprocess-failed", detail, state, capability_evaluations, warn_diagnostics)
    except AffectedComponentAbsentFromContext:
        # Ruling C(2): same steps-7/8 abort discipline as the three handlers
        # around it -- already-collected warns are FORWARDED (ruling A(1)'s
        # own "or jointly caused" rule applies to this evaluation-pass abort
        # identically), and the detail is a fixed canonical sentence (B5).
        detail = "resolve-component-paths returned an affected component absent from the Project Context"
        return _block(repo_root, args.feature, "dependency-output-malformed", detail, state, capability_evaluations, warn_diagnostics)
    except DependencyOutputMalformed:
        detail = "evaluate-predicate returned malformed JSON while evaluating a predicate"
        return _block(repo_root, args.feature, "dependency-output-malformed", detail, state, capability_evaluations, warn_diagnostics)

    # Step 9: any-branch WARN check (B2, widened scope). AC-056:
    # `warn_diagnostics` already carries one `severity: "warn"` entry per
    # individual `outcome: "warn"` DSL-evaluation node `_evaluate_
    # capabilities` found above; `_block` prepends them before this one
    # summary `severity: "block"` entry, which shares the identical id.
    if any_warn:
        detail = "a predicate evaluation produced an outcome: warn evidence node"
        return _block(
            repo_root, args.feature, "dsl-warn-on-matched-capability", detail, state,
            capability_evaluations, warn_diagnostics,
        )

    # Step 10: track branch, decided here, before any publication (B4).
    context_binding = _assemble_context_binding(
        source_sha256, affected_components, projection_sha256, registry_digest, ownership_digest,
    )
    resolver_block = _resolver_block()

    if workflow["spec_profile"] == "full":
        # 10a: Full track -- Facet Manifest assembly. No Capability Summary
        # is staged on this track (B4).
        track_artifact = _assemble_facet_manifest(
            args.feature, affected_components, registry_document, capability_evaluations,
            context_binding, resolver_block,
        )
        track_artifact_schema_filename = FACET_MANIFEST_SCHEMA_FILENAME
        track_artifact_name = "facet-manifest"
    else:
        # 10b: Lite track -- Capability Summary assembly only. No Facet
        # Manifest and no published Context Projection on this track (B4).
        try:
            track_artifact = _assemble_capability_summary(
                args.feature, registry_document, capability_evaluations, state,
            )
        except LiteCheckSourceUndefined as exc:
            capability_id = exc.args[0]
            detail = (
                f"matched Capability {capability_id!r} has no lite_policy.required_lite_checks "
                "source while capability_enforcement is required"
            )
            return _block(
                repo_root, args.feature, "lite-check-source-undefined", detail, state, capability_evaluations,
                context_binding=context_binding, resolver_block=resolver_block,
            )
        track_artifact_schema_filename = CAPABILITY_SUMMARY_SCHEMA_FILENAME
        track_artifact_name = "capability-summary"

    # Step 11: Resolver Evidence assembly (staged only).
    evidence = _assemble_resolver_evidence(args.feature, state, capability_evaluations, context_binding, resolver_block)

    # Step 12: output schema self-validation (B3).
    try:
        _self_validate_output(
            script_dir, repo_root, evidence, parsed_projection,
            track_artifact, track_artifact_schema_filename, track_artifact_name,
        )
    except ContractDiscoveryFailed as exc:
        detail = f"governing output schema discovery failed: {exc}"
        return _block(
            repo_root, args.feature, "contract-discovery-failed", detail, state, capability_evaluations,
            context_binding=context_binding, resolver_block=resolver_block,
        )
    except OutputSchemaValidationFailed as exc:
        if exc.artifact_name == "resolver-evidence":
            detail = "resolver-evidence.yaml failed its own defensive output schema self-validation"
            return _block_no_write("output-schema-validation-failed", detail)
        detail = f"the staged {exc.artifact_name} artifact failed its own defensive output schema self-validation"
        return _block(
            repo_root, args.feature, "output-schema-validation-failed", detail, state, capability_evaluations,
            context_binding=context_binding, resolver_block=resolver_block,
        )

    # Step 13: pre-publication snapshot recheck (B8 TOCTOU). A recheck
    # dependency subprocess that fails to even run is mapped to the SAME
    # REQ-002 id its own step (2/4/6) already uses for an identical
    # failure -- never re-labeled as `snapshot-generation-mismatch`, which
    # is reserved for the genuine drift comparison
    # `_pre_publication_recheck` itself raises (cross-model panel finding,
    # T-004 NEEDS_WORK cycle 2).
    try:
        _pre_publication_recheck(
            script_dir, args, absolute_config, source_sha256, affected_components, ownership_digest, registry_digest,
        )
    except CanonicalizerFailed:
        detail = "canonicalize-sdd-yaml failed while re-canonicalizing the project context during the pre-publication recheck"
        return _block(
            repo_root, args.feature, "canonicalizer-invocation-failed", detail, state, capability_evaluations,
            context_binding=context_binding, resolver_block=resolver_block,
        )
    except CanonicalizerOutputMalformed:
        detail = "canonicalize-sdd-yaml returned malformed JSON while re-canonicalizing the project context during the pre-publication recheck"
        return _block(
            repo_root, args.feature, "dependency-output-malformed", detail, state, capability_evaluations,
            context_binding=context_binding, resolver_block=resolver_block,
        )
    except AffectedComponentResolutionFailed as exc:
        detail = (
            f"resolve-component-paths exited {exc.returncode} re-resolving affected components "
            "during the pre-publication recheck; see resolve-component-paths diagnostics"
        )
        return _block(
            repo_root, args.feature, "affected-component-resolution-failed", detail, state, capability_evaluations,
            context_binding=context_binding, resolver_block=resolver_block,
        )
    except DependencySubprocessFailed:
        detail = (
            "a dependency subprocess failed while re-deriving affected components or registry_digest "
            "during the pre-publication recheck"
        )
        return _block(
            repo_root, args.feature, "dependency-subprocess-failed", detail, state, capability_evaluations,
            context_binding=context_binding, resolver_block=resolver_block,
        )
    except DependencyOutputMalformed:
        detail = (
            "a dependency subprocess returned malformed output while re-deriving affected components or "
            "registry_digest during the pre-publication recheck"
        )
        return _block(
            repo_root, args.feature, "dependency-output-malformed", detail, state, capability_evaluations,
            context_binding=context_binding, resolver_block=resolver_block,
        )
    except SnapshotGenerationMismatch:
        detail = (
            "a pre-publication recheck of the Project Context, Registry, or "
            "ownership-source snapshot detected drift since this invocation's own snapshot"
        )
        return _block(
            repo_root, args.feature, "snapshot-generation-mismatch", detail, state, capability_evaluations,
            context_binding=context_binding, resolver_block=resolver_block,
        )

    # Step 14: publication, as a single journaled multi-target transaction
    # (design.md "Resolver publication transactional bundle contract"). The
    # target list IS this invocation's own track-exclusive output set
    # (design.md's own diagram): Facet Manifest + Context Projection +
    # Resolver Evidence on the Full track, Capability Summary + Resolver
    # Evidence on the Lite track -- never both track artifacts (B4), and
    # never `project-context.resolved.json` on a Lite resolve. Resolver
    # Evidence is a member of BOTH sets and is committed LAST, so the record
    # of a publication is never durable before the artifacts it describes.
    if workflow["spec_profile"] == "full":
        targets = [
            (repo_root / "specs" / args.feature / "facet-manifest.yaml", _canonical_payload(track_artifact)),
            (script_dir / "generated" / "project-context.resolved.json", canonical_projection),
        ]
    else:
        targets = [
            (repo_root / "specs" / args.feature / "capability-summary.yaml", _canonical_payload(track_artifact)),
        ]
    targets.append(
        (repo_root / "specs" / args.feature / "resolver-evidence.yaml", _canonical_payload(evidence))
    )

    try:
        transaction = _publish_bundle(repo_root, args.feature, targets)
    except ArtifactPublicationFailed as exc:
        return _block(
            repo_root, args.feature, "artifact-publication-failed",
            f"{ARTIFACT_PUBLICATION_FAILED_PREFIX}; {exc.rollback_clause}", state, capability_evaluations,
            context_binding=context_binding, resolver_block=resolver_block,
        )

    # Step 14's own Post-publication verification (B8, design.md step 4):
    # every rename above has now succeeded and the journal is still present,
    # not yet deleted. This re-reads the SAME three sources step 13 rechecked
    # -- including a THIRD `resolve-component-paths` invocation for a fresh
    # `ownership_digest` and a fresh `affected_components` set -- and compares
    # against step 13's own (passing) recheck snapshot, which is by
    # construction this invocation's own step-2/4/5-6 snapshot.
    try:
        _pre_publication_recheck(
            script_dir, args, absolute_config, source_sha256, affected_components, ownership_digest, registry_digest,
        )
    except SnapshotGenerationMismatch:
        rolled_back, complete = _rollback_transaction(transaction, discard=False)
        result, wrote = _block_reporting(
            repo_root, args.feature, "post-publication-generation-mismatch",
            f"{POST_PUBLICATION_MISMATCH_PREFIX}; {_rollback_clause(rolled_back, complete)}",
            state, capability_evaluations,
            context_binding=context_binding, resolver_block=resolver_block,
        )
        # BOTH conditions, not just `complete` (openai panel slot, round 12
        # Major). `complete` says the rollback finished; `wrote` says the
        # Block record actually reached Evidence's live path. Discarding on
        # `complete` alone deleted the journal even when the Evidence write
        # had failed, which is the very state round 9's deferral existed to
        # prevent: artifacts back at PRE, the success-form Evidence still live
        # from the commit, and no journal left for the recovery scan.
        if complete and wrote:
            _discard_batch(transaction.batch_dir)
        return result
    except tuple(_POST_PUBLICATION_DEPENDENCY_BLOCKS) as exc:
        # A verification dependency that cannot even RUN is not a "mismatch"
        # -- re-labelling it `post-publication-generation-mismatch` would
        # assert drift that was never observed, the exact defect the
        # cross-model panel rejected for step 13 (see
        # `_pre_publication_recheck`'s own docstring). It is still a
        # verification this invocation could not complete, and every rename
        # is already live, so the rollback runs identically and the Block
        # carries the SAME REQ-002 id the corresponding step-13 handler
        # already uses -- never a seventeenth diagnostic-id value, which the
        # enum is closed against.
        _rolled_back, _complete = _rollback_transaction(transaction, discard=False)
        # Resolved by `isinstance`, never by an exact `type(exc)` key lookup:
        # a future subclass of any of these five would be CAUGHT by the
        # `except` above and then `KeyError` out of the mapping as a raw
        # traceback -- the exact no-canonical-diagnostic failure shape
        # REQ-002 forbids.
        diagnostic_id, detail = next(
            mapped for exception_class, mapped in _POST_PUBLICATION_DEPENDENCY_BLOCKS.items()
            if isinstance(exc, exception_class)
        )
        result, wrote = _block_reporting(
            repo_root, args.feature, diagnostic_id, detail, state, capability_evaluations,
            context_binding=context_binding, resolver_block=resolver_block,
        )
        # Same deferral, and the same two-condition guard, as the mismatch
        # branch above: the journal outlives the rollback and dies only once
        # the Block record is genuinely durable.
        if _complete and wrote:
            _discard_batch(transaction.batch_dir)
        return result

    # Complete (design.md step 5): every rename succeeded AND the
    # post-publication verification passed -- delete the journal. This is
    # this invocation's own success path, exit 0.
    _discard_batch(transaction.batch_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
