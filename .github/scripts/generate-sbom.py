#!/usr/bin/env python3
"""Generate a CycloneDX 1.5 SBOM for sdd-forge (C-06 / supply-chain transparency).

The core sdd-forge plugin suite (shell + Python stdlib + Markdown) has no
third-party runtime dependencies, but the mcp/ directory's Node/TypeScript MCP
servers (sdd-forge-mcp, local-env-mcp, ci-mcp) each bundle npm production
dependencies into their dist/ build. This script's supply chain therefore has
two parts: the GitHub Actions referenced by the workflows under
.github/workflows/ (build/CI dependencies), and the non-dev packages recorded
in each mcp/*/package-lock.json (runtime dependencies actually shipped in
dist/). It scans workflows for ``uses:`` entries and each lockfile's
``packages`` map for non-dev entries, emitting one SBOM component per pinned
action and per npm package, plus the repository itself as the root component.
Pinning actions to commit SHAs (H-04) means each action component's version is
the exact commit; each npm component's version is the exact resolved version
recorded by ``npm ci``, so the SBOM records precisely what runs in CI and what
ships in the MCP servers.

Usage:
  generate-sbom.py [--version VERSION] [--repo OWNER/REPO] [--output PATH]

  --version  Version/tag for the root component (default: read from
             .claude-plugin/marketplace.json, else "0.0.0").
  --repo     owner/repo for the root purl (default: aharada54914/sdd-forge).
  --output   Write to PATH instead of stdout.

Stdlib only; no external dependencies.
"""
import argparse
import datetime
import json
import os
import re
import urllib.parse
import sys

USES_RE = re.compile(r"^\s*-?\s*uses:\s*([^\s#'\"]+)")
# owner/repo[/subpath]@ref  -> capture owner/repo and the ref; ignore inline "# vX" comments
ACTION_RE = re.compile(r"^(?P<repo>[^/@\s]+/[^/@\s]+)(?P<path>/[^@\s]*)?@(?P<ref>[^\s#]+)$")

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def read_default_version():
    """Read the plugin version from marketplace.json, or return '0.0.0' as fallback."""
    candidate = os.path.join(REPO_ROOT, ".claude-plugin", "marketplace.json")
    try:
        with open(candidate, encoding="utf-8") as f:
            data = json.load(f)
        # marketplace.json may carry a top-level or nested version field.
        if isinstance(data, dict):
            if isinstance(data.get("version"), str):
                return data["version"]
            meta = data.get("metadata")
            if isinstance(meta, dict) and isinstance(meta.get("version"), str):
                return meta["version"]
    except (OSError, ValueError):
        pass
    return "0.0.0"


def collect_action_uses():
    """Scan .github/workflows/*.{yml,yaml} for `uses:` action references."""
    workflows_dir = os.path.join(REPO_ROOT, ".github", "workflows")
    found = {}  # key: "repo@ref" -> (repo, ref, path)
    if not os.path.isdir(workflows_dir):
        return found
    for name in sorted(os.listdir(workflows_dir)):
        if not name.endswith((".yml", ".yaml")):
            continue
        path = os.path.join(workflows_dir, name)
        try:
            with open(path, encoding="utf-8") as f:
                lines = f.readlines()
        except OSError:
            continue
        for line in lines:
            m = USES_RE.match(line)
            if not m:
                continue
            ref_str = m.group(1).strip()
            # Skip local composite actions (uses: ./path or docker://).
            if ref_str.startswith("./") or ref_str.startswith("docker://"):
                continue
            am = ACTION_RE.match(ref_str)
            if not am:
                continue
            repo = am.group("repo")
            ref = am.group("ref")
            subpath = am.group("path") or ""
            found[f"{repo}{subpath}@{ref}"] = (repo, ref, subpath)
    return found


def collect_npm_dependencies():
    """Scan mcp/*/package-lock.json (npm lockfile v3) for non-dev packages.

    Each lockfile's ``packages`` map keys entries by their path under
    node_modules/ (e.g. ``node_modules/@scope/name`` or, for a dependency
    nested inside another package's own node_modules,
    ``node_modules/pkg-a/node_modules/pkg-b``); the root package itself is
    keyed by the empty string and is skipped. Entries carrying ``"dev": true``
    are dev-only and excluded -- they are not shipped in the esbuild dist/
    bundle. Returns a dict keyed by "name@version" (deduping the same package
    version recorded across multiple lockfiles) mapping to (name, version).
    """
    mcp_dir = os.path.join(REPO_ROOT, "mcp")
    found = {}
    if not os.path.isdir(mcp_dir):
        return found
    for entry in sorted(os.listdir(mcp_dir)):
        lockfile = os.path.join(mcp_dir, entry, "package-lock.json")
        if not os.path.isfile(lockfile):
            continue
        try:
            with open(lockfile, encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, ValueError):
            continue
        packages = data.get("packages")
        if not isinstance(packages, dict):
            continue
        for path, meta in packages.items():
            if not path or not isinstance(meta, dict):
                continue  # "" is the root package entry, not a dependency.
            if meta.get("dev"):
                continue
            version = meta.get("version")
            if not isinstance(version, str):
                continue
            # A dependency nested inside another package's own node_modules
            # repeats the "node_modules/" separator; the real package name is
            # whatever follows the LAST occurrence.
            name = path.rsplit("node_modules/", 1)[-1]
            found[f"{name}@{version}"] = (name, version)
    return found


def build_sbom(version, repo):
    """Build a CycloneDX SBOM dict for the given plugin version and GitHub repo slug."""
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    components = []
    for _, (action_repo, ref, subpath) in sorted(collect_action_uses().items()):
        comp = {
            "type": "library",
            "name": action_repo,
            "version": ref,
            "purl": f"pkg:github/{action_repo}@{ref}",
            "externalReferences": [
                {"type": "vcs", "url": f"https://github.com/{action_repo}"}
            ],
        }
        if subpath:
            comp["properties"] = [{"name": "github:action:subpath", "value": subpath.lstrip("/")}]
        components.append(comp)
    for name, version_ in sorted(collect_npm_dependencies().values()):
        # Canonical purl form percent-encodes the scope's "@" (purl-spec npm
        # examples: pkg:npm/%40angular/animation@12.3.1).
        components.append({
            "type": "library",
            "name": name,
            "version": version_,
            "purl": f"pkg:npm/{urllib.parse.quote(name, safe='/')}@{version_}",
        })
    return {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "version": 1,
        "metadata": {
            "timestamp": timestamp,
            "tools": [{"vendor": "sdd-forge", "name": "generate-sbom", "version": "1.0"}],
            "component": {
                "type": "application",
                "name": "sdd-forge",
                "version": version,
                "purl": f"pkg:github/{repo}@{version}",
                "description": "SDD plugin suite with deterministic enforcement layer and cross-platform installers.",
                "externalReferences": [
                    {"type": "vcs", "url": f"https://github.com/{repo}"}
                ],
            },
        },
        "components": components,
    }


def main(argv):
    """Parse CLI arguments and write a CycloneDX SBOM to stdout or a file."""
    parser = argparse.ArgumentParser(description="Generate a CycloneDX SBOM for sdd-forge.")
    parser.add_argument("--version", default=None)
    parser.add_argument("--repo", default="aharada54914/sdd-forge")
    parser.add_argument("--output", default=None)
    args = parser.parse_args(argv)

    version = args.version or read_default_version()
    sbom = build_sbom(version, args.repo)
    text = json.dumps(sbom, indent=2) + "\n"
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(text)
        sys.stderr.write(
            f"Wrote SBOM for {args.repo}@{version} with {len(sbom['components'])} component(s) to {args.output}\n"
        )
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
