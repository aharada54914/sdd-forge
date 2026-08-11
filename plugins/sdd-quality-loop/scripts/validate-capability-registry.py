#!/usr/bin/env python3
"""validate-capability-registry: the Registry validator (T-004, REQ-003).

Usage: validate-capability-registry.py --registry <path>
Exit 0 when all nine independently identifiable checks (a-i) pass; exit 1
with one diagnostic line per failed check on stdout, in the style of
check-sdd-structure.sh's `missing: <item>` lines: `registry: <check-id>: <detail>`.

Checks (diagnostic ID):
  (a) gate-id-duplicate            -- Gate-ID uniqueness, top-level gates[]
  (b) implementation-ref-missing   -- stage:implementation gates resolve to an existing file
  (c) unregistered-script          -- Gate implementation identity / unregistered-script detection
      gate-implementation-collision -- (c)'s own AC-016 sibling: two gates[] entries must
      never resolve implementation_ref to the identical real path
  (d) pack-owns-gate-definition    -- no capability-packs/*/gates.yaml exists (forward-guard)
  (e) stage-missing                -- defense-in-depth re-assertion, independent of schema
  (f) dangling-gate-reference       -- capabilities[].gate_ids referential integrity
  (g) provider-name-detected       -- provider-name contamination scan (ADR-0018)
  (h) unknown-upgrade-reason       -- lite_policy.upgrade_reasons vs the versioned catalog
  (i) capability-id-duplicate      -- Capability-ID uniqueness, top-level capabilities[], independent of (a)
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from registry_discovery import discover_artifact, resolve_git_root, DiscoveryError  # noqa: E402

SCAN_ROOT_REL = "plugins/sdd-quality-loop/scripts"
PROVIDER_TERMS_REL = "plugins/sdd-quality-loop/references/provider-terms.json"


def _script_dir() -> Path:
    return Path(__file__).resolve().parent


def _load_json(path: Path):
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def check_a_gate_id_uniqueness(registry, diagnostics):
    ids = [g.get("id") for g in registry.get("gates", []) if isinstance(g, dict)]
    seen, dups = set(), set()
    for i in ids:
        if i in seen:
            dups.add(i)
        seen.add(i)
    for d in sorted(dups, key=lambda x: (x is None, x)):
        diagnostics.append(f"registry: gate-id-duplicate: {d}")
    return not dups


def check_i_capability_id_uniqueness(registry, diagnostics):
    ids = [c.get("id") for c in registry.get("capabilities", []) if isinstance(c, dict)]
    seen, dups = set(), set()
    for i in ids:
        if i in seen:
            dups.add(i)
        seen.add(i)
    for d in sorted(dups, key=lambda x: (x is None, x)):
        diagnostics.append(f"registry: capability-id-duplicate: {d}")
    return not dups


def check_b_stage_completeness(registry, repo_root, diagnostics):
    ok = True
    for g in registry.get("gates", []):
        if not isinstance(g, dict) or g.get("stage") != "implementation":
            continue
        ref = g.get("implementation_ref")
        gid = g.get("id", "?")
        if not ref:
            diagnostics.append(f"registry: implementation-ref-missing: {gid}")
            ok = False
            continue
        if not (repo_root / ref).is_file():
            diagnostics.append(f"registry: implementation-ref-missing: {gid} (path does not exist: {ref})")
            ok = False
    return ok


def check_e_stage_missing(registry, diagnostics):
    """Defense-in-depth: independently re-assert no gates[] entry lacks
    `stage`, exercised against a fixture that bypasses schema validation
    (this validator never invokes the JSON Schema itself, so this
    assertion always runs regardless of whether upstream schema
    validation happened)."""
    ok = True
    for g in registry.get("gates", []):
        if not isinstance(g, dict):
            continue
        if not g.get("stage"):
            diagnostics.append(f"registry: stage-missing: {g.get('id', '?')}")
            ok = False
    return ok


def check_d_no_pack_owned_gates(repo_root, diagnostics):
    matches = sorted(repo_root.glob("capability-packs/*/gates.yaml"))
    for m in matches:
        diagnostics.append(f"registry: pack-owns-gate-definition: {m.relative_to(repo_root).as_posix()}")
    return not matches


def check_f_referential_integrity(registry, diagnostics):
    gate_ids = {g.get("id") for g in registry.get("gates", []) if isinstance(g, dict)}
    ok = True
    for c in registry.get("capabilities", []):
        if not isinstance(c, dict):
            continue
        for gid in c.get("gate_ids", []) or []:
            if gid not in gate_ids:
                diagnostics.append(f"registry: dangling-gate-reference: {c.get('id', '?')} -> {gid}")
                ok = False
    return ok


def _load_provider_terms(repo_root):
    path = repo_root / PROVIDER_TERMS_REL
    doc = _load_json(path)
    terms = []
    for category_terms in (doc.get("categories") or {}).values():
        terms.extend(category_terms)
    return terms


def check_g_provider_name_contamination(registry, provider_terms, diagnostics):
    ok = True
    terms_lower = [t.lower() for t in provider_terms]
    findings = []

    def walk(obj, path):
        if isinstance(obj, dict):
            for k, v in obj.items():
                walk(v, f"{path}.{k}")
        elif isinstance(obj, list):
            for idx, v in enumerate(obj):
                walk(v, f"{path}[{idx}]")
        elif isinstance(obj, str):
            lowered = obj.lower()
            for term in terms_lower:
                if term in lowered:
                    findings.append((path, term))

    walk(registry, "registry")
    for path, term in findings:
        diagnostics.append(f"registry: provider-name-detected: {path} contains {term!r}")
        ok = False
    return ok


def check_h_catalog_conformance(registry, diagnostics):
    try:
        catalog_path = discover_artifact("lite-upgrade-reason-catalog.json")
    except DiscoveryError as exc:
        diagnostics.append(f"registry: unknown-upgrade-reason: cannot locate/verify catalog: {exc}")
        return False
    try:
        catalog = _load_json(catalog_path)
    except (OSError, json.JSONDecodeError) as exc:
        diagnostics.append(f"registry: unknown-upgrade-reason: cannot read catalog: {exc}")
        return False
    known = set(catalog.get("reasons", []) or [])
    ok = True
    for c in registry.get("capabilities", []):
        if not isinstance(c, dict):
            continue
        lite_policy = c.get("lite_policy")
        if not isinstance(lite_policy, dict):
            continue
        for reason in lite_policy.get("upgrade_reasons", []) or []:
            if reason not in known:
                diagnostics.append(f"registry: unknown-upgrade-reason: {c.get('id', '?')} -> {reason!r}")
                ok = False
    return ok


def check_c_unregistered_script(registry, repo_root, diagnostics):
    """Gate implementation identity (AC-016/AC-017): every check-*.py
    master directly under the sole scan root is referenced by exactly one
    gates[].implementation_ref (symlink-resolved before comparison). A
    non-check-* script, or any script outside the scan root, is never
    scanned or flagged. Wrapper (.sh/.ps1/.js) siblings are never
    independently scanned -- only their .py master is a candidate.

    AC-016 also requires: "two gates[] entries must not resolve to the
    same wrapper group" -- i.e. two distinct gates[] entries must never
    resolve their implementation_ref to the identical real path. This is
    tracked as gate-implementation-collision, a diagnostic distinct from
    unregistered-script (RT-20260723-001 remedy: a set-based dedup here
    previously absorbed a collision silently instead of failing it)."""
    scan_root = repo_root / SCAN_ROOT_REL
    ok = True

    masters = {}  # real-path str -> original Path (for reporting)
    if scan_root.is_dir():
        for entry in sorted(scan_root.iterdir()):
            if entry.is_file() and entry.name.startswith("check-") and entry.suffix == ".py":
                masters[str(entry.resolve())] = entry

    registered_by_real = {}  # real-path str -> [gate id, ...] referencing it
    for g in registry.get("gates", []):
        if not isinstance(g, dict):
            continue
        ref = g.get("implementation_ref")
        if not ref:
            continue
        ref_path = repo_root / ref
        if ref_path.is_file():
            real = str(ref_path.resolve())
            registered_by_real.setdefault(real, []).append(g.get("id", "?"))

    for real_str, gate_ids in sorted(registered_by_real.items()):
        if len(gate_ids) > 1:
            diagnostics.append(
                "registry: gate-implementation-collision: "
                f"{sorted(gate_ids)} all resolve to {real_str}"
            )
            ok = False

    for real_str, original in masters.items():
        if real_str not in registered_by_real:
            diagnostics.append(f"registry: unregistered-script: {original.relative_to(repo_root).as_posix()}")
            ok = False
    return ok


def run(registry_path: str, repo_root: Path):
    diagnostics = []
    try:
        registry = _load_json(Path(registry_path))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"registry: cannot read/parse registry: {exc}"]

    if not isinstance(registry, dict):
        return ["registry: registry document is not a JSON object"]

    check_a_gate_id_uniqueness(registry, diagnostics)
    check_b_stage_completeness(registry, repo_root, diagnostics)
    check_c_unregistered_script(registry, repo_root, diagnostics)
    check_d_no_pack_owned_gates(repo_root, diagnostics)
    check_e_stage_missing(registry, diagnostics)
    check_f_referential_integrity(registry, diagnostics)
    try:
        provider_terms = _load_provider_terms(repo_root)
        check_g_provider_name_contamination(registry, provider_terms, diagnostics)
    except (OSError, json.JSONDecodeError) as exc:
        diagnostics.append(f"registry: provider-name-detected: cannot read provider-terms.json: {exc}")
    check_h_catalog_conformance(registry, diagnostics)
    check_i_capability_id_uniqueness(registry, diagnostics)

    return diagnostics


def main(argv=None):
    argv = sys.argv[1:] if argv is None else list(argv)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--registry", required=True, help="path to the capability-registry.json instance to validate")
    parser.add_argument(
        "--repo-root",
        default=None,
        help=(
            "override the repository root used for checks (b)/(c)/(d)'s filesystem lookups "
            "(implementation_ref existence, the scan-root script inventory, and the "
            "repository-wide capability-packs/*/gates.yaml guard). Defaults to git-root "
            "resolution (git rev-parse --show-toplevel / .git walk). This exists so this "
            "task's own test suite can exercise checks (b)/(c)/(d) against isolated, "
            "fixture-controlled fake repository roots instead of this repository's own, "
            "evolving real script inventory."
        ),
    )
    args = parser.parse_args(argv)

    if args.repo_root is not None:
        repo_root = Path(args.repo_root).resolve()
    else:
        repo_root = resolve_git_root()
    if repo_root is None:
        print("registry: cannot resolve repository root (no git command and no reachable .git)")
        return 1

    diagnostics = run(args.registry, repo_root)
    if diagnostics:
        for line in diagnostics:
            print(line)
        return 1
    print("validate-capability-registry: all 9 checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
