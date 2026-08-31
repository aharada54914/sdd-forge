#!/usr/bin/env python3
import re
import sys
from pathlib import Path

ANCHORS = re.compile(
    r"^(?:ux|frontend|infra|security)-spec\.md#[a-z0-9][a-z0-9-]*"
    r"(?:\s*;\s*(?:ux|frontend|infra|security)-spec\.md#[a-z0-9][a-z0-9-]*)*$"
)
EXCLUSION = re.compile(r"^N/A — cross-layer only:\s*\S.*$")


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: validate-layer-traceability.py <traceability.md> <requirements.md>", file=sys.stderr)
        return 2
    path = Path(sys.argv[1])
    requirements_path = Path(sys.argv[2])
    if not path.is_file() or path.is_symlink():
        print(f"traceability input is missing or substituted: {path}", file=sys.stderr)
        return 1
    if not requirements_path.is_file() or requirements_path.is_symlink():
        print(f"requirements input is missing or substituted: {requirements_path}", file=sys.stderr)
        return 1
    required_ids = set(re.findall(r"\bREQ-\d{3}\b", requirements_path.read_text(encoding="utf-8")))
    if not required_ids:
        print("no requirement ids found in requirements.md", file=sys.stderr)
        return 1
    traced_ids: set[str] = set()
    in_traceability_table = False
    layer_spec_index = None
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.rstrip()
        if line.startswith("## "):
            in_traceability_table = False
            layer_spec_index = None
            continue
        if not line.strip():
            if in_traceability_table:
                in_traceability_table = False
                layer_spec_index = None
            continue
        if not line.startswith("|"):
            continue

        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if not in_traceability_table:
            if cells and cells[0] == "Requirement" and "Layer Spec" in cells:
                in_traceability_table = True
                layer_spec_index = cells.index("Layer Spec")
            continue

        if not cells or layer_spec_index is None:
            continue
        if re.fullmatch(r"REQ-\d{3}", cells[0]):
            traced_ids.add(cells[0])
            value = cells[layer_spec_index] if len(cells) > layer_spec_index else ""
            if not (ANCHORS.fullmatch(value) or EXCLUSION.fullmatch(value)):
                print(f"invalid Layer Spec for {cells[0]}: {value}", file=sys.stderr)
                return 1
    if not traced_ids:
        print("no requirement rows found in traceability.md", file=sys.stderr)
        return 1
    missing = sorted(required_ids - traced_ids)
    if missing:
        print(f"requirements missing Layer Spec coverage: {', '.join(missing)}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
