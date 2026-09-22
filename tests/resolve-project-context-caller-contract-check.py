#!/usr/bin/env python3
"""Validate the live A5 capability-interview caller contract.

The contract is deliberately anchored by headings rather than line numbers:
the capability phase must be immediately followed by the existing full-profile
phase, and the committed baseline records the post-integration bytes and
heading ordinal.  A relocation fixture proves that the adjacency check is
not replaced by a heading-exists-only check.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL = ROOT / "plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md"
BASELINE = ROOT / "tests/fixtures/capability-resolver/caller-contract-baseline.json"
HEADING_RE = re.compile(r"^(##|###) .+$", re.MULTILINE)
CAPABILITY = "### Capability Interview Phase"
FULL_PROFILE = "### Full-Profile Layer Interview"
REQUIRED_MARKERS = (
    "exactly once",
    "disabled-legacy",
    "event-identical",
    "at most 15",
    "Open Questions",
    "A `Block` result",
    "never silently fall back",
    "Do not invoke the resolver a second time",
    "--config <current-project-context>",
    "--target-rev <target-revision>",
    "--feature <feature-slug>",
    "--source-rev",
    "documented `HEAD` default",
)


def _anchor(text: str) -> tuple[str, int, int]:
    lines = text.replace("\r\n", "\n").replace("\r", "\n").splitlines()
    headings = [line for line in lines if line.startswith("## ") or line.startswith("### ")]
    cap = [i for i, line in enumerate(lines) if line == CAPABILITY]
    full = [i for i, line in enumerate(lines) if line == FULL_PROFILE]
    if len(cap) != 1:
        raise AssertionError(f"capability heading count is {len(cap)}, expected 1")
    if len(full) != 1:
        raise AssertionError(f"full-profile heading count is {len(full)}, expected 1")
    cap_index, full_index = cap[0], full[0]
    next_heading = next(
        (i for i in range(cap_index + 1, len(lines)) if lines[i].startswith("## ") or lines[i].startswith("### ")),
        None,
    )
    if next_heading != full_index:
        found = lines[next_heading] if next_heading is not None else "<EOF>"
        raise AssertionError(f"full-profile heading is not immediately next; found {found}")
    phase = "\n".join(lines[cap_index:full_index])
    missing = [marker for marker in REQUIRED_MARKERS if marker not in phase]
    if missing:
        raise AssertionError("caller contract markers missing: " + ", ".join(missing))
    if phase.count("resolve-project-context.{sh,ps1}") != 1:
        raise AssertionError("caller contract must name one dispatcher invocation")
    for flag in ("--config", "--target-rev", "--feature"):
        if phase.count(flag) != 2:
            raise AssertionError(
                f"caller contract must declare {flag} once in the invocation and once in its omission rule"
            )
    # Include the phase and its adjacent target heading, with one terminal LF.
    window = "\n".join(lines[cap_index : full_index + 1]) + "\n"
    digest = hashlib.sha256(window.encode("utf-8")).hexdigest()
    ordinal = headings.index(FULL_PROFILE) + 1
    return digest, ordinal, full_index + 1


def _assert_baseline(text: str) -> None:
    digest, ordinal, _ = _anchor(text)
    baseline = json.loads(BASELINE.read_text(encoding="utf-8"))
    if baseline["normalization"] != "utf-8-lf-terminal-lf":
        raise AssertionError("baseline normalization contract changed")
    if baseline["anchor_sha256"] != digest:
        raise AssertionError(
            f"caller anchor drift: expected {baseline['anchor_sha256']}, observed {digest}"
        )
    if baseline["full_profile_heading_ordinal"] != ordinal:
        raise AssertionError(
            "full-profile heading ordinal drift: "
            f"expected {baseline['full_profile_heading_ordinal']}, observed {ordinal}"
        )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--launcher", choices=("sh", "ps1"), required=True)
    args = parser.parse_args()
    if not SKILL.is_file() or not BASELINE.is_file():
        raise AssertionError("caller contract inputs are missing")
    text = SKILL.read_text(encoding="utf-8")
    _assert_baseline(text)
    anchor_digest, anchor_ordinal, _ = _anchor(text)

    # Relocation regression: preserve the heading text but insert another
    # heading before it.  The contract must reject this even though the text
    # and the baseline digest of the unmodified document are unchanged.
    mutated = text.replace(
        "\n" + FULL_PROFILE + "\n",
        "\n### Relocated Layer Marker\n\n" + FULL_PROFILE + "\n",
        1,
    )
    with tempfile.TemporaryDirectory(prefix="a5-caller-contract-") as temp:
        candidate = Path(temp) / "SKILL.md"
        candidate.write_text(mutated, encoding="utf-8", newline="\n")
        try:
            _anchor(mutated)
        except AssertionError:
            pass
        else:
            raise AssertionError("relocation fixture was accepted")

    print(f"caller-contract {args.launcher}: PASS")
    print(f"anchor-sha256: {anchor_digest}")
    print(f"full-profile-heading-ordinal: {anchor_ordinal}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
