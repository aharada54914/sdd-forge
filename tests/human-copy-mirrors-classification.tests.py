#!/usr/bin/env python3
"""Focused regression checks for human-copy mirror classification."""
import copy
import hashlib
import importlib.util
import json
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "human_copy_mirrors", ROOT / "scripts" / "human_copy_mirrors.py"
)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


class MainDigests:
    def __init__(self, digest):
        self.digest = digest

    def get(self, _rel):
        return self.digest


def setup_bundle(root: Path) -> None:
    bundle = root / "specs" / "fixture" / "human-copy"
    bundle.mkdir(parents=True)
    staged = bundle / "plugins" / "example.txt"
    staged.parent.mkdir(parents=True)
    staged.write_text("reviewed candidate\n", encoding="utf-8")
    digest = hashlib.sha256(staged.read_bytes()).hexdigest()
    (bundle / "MANIFEST.sha256").write_text(
        f"{digest}  plugins/example.txt\n", encoding="utf-8"
    )


def states(root: Path, main_digest):
    return [row[0] for row in MODULE.classify(str(root), MainDigests(main_digest))]


LIVE = "plugins/sdd-ship/skills/ship/SKILL.md"
EPICS = ("epic-136-phase2-gates", "epic-189-a1-project-context")
PIN_PATH = Path("tests/fixtures/ship-track-selection-current-publication.json")
OTHER = "plugins/other/example.txt"


def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


class MainMap:
    """origin/main digests by repo-relative path; unknown paths are absent."""

    def __init__(self, digests=None):
        self.digests = digests or {}

    def get(self, rel):
        return self.digests.get(rel)


def stage(root: Path, bundle: str, rel: str, text: str) -> None:
    """Write a staged file and register its true digest in the bundle manifest."""
    directory = root / "specs" / bundle / "human-copy"
    (directory / rel).parent.mkdir(parents=True, exist_ok=True)
    (directory / rel).write_text(text, encoding="utf-8")
    with (directory / "MANIFEST.sha256").open("a", encoding="utf-8") as manifest:
        manifest.write(f"{sha(text)}  {rel}\n")


def write_pins(root: Path, pins) -> None:
    path = root / PIN_PATH
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(pins if isinstance(pins, str) else json.dumps(pins), encoding="utf-8")


def valid_pins(staged: str, live: str) -> dict:
    return {
        "schema": "ship-track-selection-current-publication/v1",
        "successors": [
            {
                "live": LIVE,
                "staged": f"specs/{epic}/human-copy/{LIVE}",
                "staged_sha256": sha(staged),
                "live_sha256": sha(live),
                "intentional_changes": f"synthetic reviewed change for {epic}",
            }
            for epic in EPICS
        ],
    }


STAGED, LIVE_TEXT = "ship predecessor\n", "ship successor\n"


def ship_root(directory: str, pins="valid") -> Path:
    """Synthetic root: both ship mirrors staged at STAGED, live at LIVE_TEXT."""
    root = Path(directory)
    for epic in EPICS:
        stage(root, epic, LIVE, STAGED)
    (root / LIVE).parent.mkdir(parents=True, exist_ok=True)
    (root / LIVE).write_text(LIVE_TEXT, encoding="utf-8")
    if pins == "valid":
        write_pins(root, valid_pins(STAGED, LIVE_TEXT))
    elif pins is not None:
        write_pins(root, pins)
    return root


def ship_states(root: Path, main=None):
    return {
        row[1].replace("\\", "/").split("/")[1]: row[0]
        for row in MODULE.classify(str(root), MainMap(main)) if row[2] == LIVE
    }


def expect(root: Path, expected, message: str, main=None) -> None:
    got = set(ship_states(root, main).values())
    assert got == {expected}, f"{message}: expected {expected}, got {ship_states(root, main)}"


def mutated(change):
    pins = valid_pins(STAGED, LIVE_TEXT)
    change(pins)
    return pins


def check_pins_never_waive() -> int:
    bad_pins = {
        "missing pin file": None,
        "malformed json": "{not json",
        "json list": "[]",
        "wrong schema": mutated(lambda p: p.update(schema="ship-track-selection-current-publication/v0")),
        "missing schema": mutated(lambda p: p.pop("schema")),
        "successors not a list": mutated(lambda p: p.update(successors={})),
        "short staged sha": mutated(lambda p: [e.update(staged_sha256=sha(STAGED)[:63]) for e in p["successors"]]),
        "uppercase live sha": mutated(lambda p: [e.update(live_sha256=sha(LIVE_TEXT).upper()) for e in p["successors"]]),
        "empty intentional_changes": mutated(lambda p: [e.update(intentional_changes="") for e in p["successors"]]),
        "blank intentional_changes": mutated(lambda p: [e.update(intentional_changes="  \n") for e in p["successors"]]),
        "missing intentional_changes": mutated(lambda p: [e.pop("intentional_changes") for e in p["successors"]]),
        "staged and live pinned equal": mutated(lambda p: [e.update(live_sha256=sha(STAGED)) for e in p["successors"]]),
        "wrong live path": mutated(lambda p: [e.update(live="plugins/sdd-ship/skills/ship/OTHER.md") for e in p["successors"]]),
        "duplicate entries": mutated(lambda p: p["successors"].extend(copy.deepcopy(p["successors"]))),
    }
    for label, pins in bad_pins.items():
        with tempfile.TemporaryDirectory() as directory:
            root = ship_root(directory, pins)
            expect(root, "STALE", f"{label} must not waive the mismatch")
            expect(root, "STALE", f"{label} must not waive the mismatch", main={LIVE: sha("x")})
    return len(bad_pins)


def check_ship_successors() -> int:
    checks = 0
    with tempfile.TemporaryDirectory() as directory:
        root = ship_root(directory)
        expect(root, "PUBLISHED", "exact reviewed pair"); checks += 1
        assert set(ship_states(root)) == {"epic-136-phase2-gates", "epic-189-a1-project-context"}
        checks += 1  # both known pairs classified, independently

        (root / LIVE).write_text(LIVE_TEXT + "extra\n", encoding="utf-8")
        expect(root, "STALE", "live mutation after publication"); checks += 1

        (root / LIVE).write_text(LIVE_TEXT, encoding="utf-8")
        for epic in EPICS:  # staged predecessor mutated, manifest left alone
            (root / "specs" / epic / "human-copy" / LIVE).write_text(STAGED + "x\n", encoding="utf-8")
        expect(root, "STALE", "staged mutation after publication"); checks += 1

        # Predecessor tampered to equal live: no mismatch left to classify, still refused.
        for epic in EPICS:
            (root / "specs" / epic / "human-copy" / LIVE).write_text(LIVE_TEXT, encoding="utf-8")
        expect(root, "STALE", "staged tampered to equal live"); checks += 1
        (root / LIVE).write_text("both mutated\n", encoding="utf-8")
        for epic in EPICS:
            (root / "specs" / epic / "human-copy" / LIVE).write_text("both mutated\n", encoding="utf-8")
        expect(root, "STALE", "equal mutated live and staged"); checks += 1
        write_pins(root, "{}")
        expect(root, "STALE", "equal mutated live and staged with unusable pins"); checks += 1

    with tempfile.TemporaryDirectory() as directory:
        root = ship_root(directory)
        (root / LIVE).write_text(STAGED, encoding="utf-8")  # sync applied: staged == live == pinned predecessor
        expect(root, "FRESH", "unmutated equal predecessor stays fresh"); checks += 1

    with tempfile.TemporaryDirectory() as directory:
        pins = valid_pins(STAGED, LIVE_TEXT)
        pins["successors"].pop(0)  # only epic-189 pinned
        root = ship_root(directory, pins)
        assert ship_states(root) == {
            "epic-136-phase2-gates": "STALE",
            "epic-189-a1-project-context": "PUBLISHED",
        }, ship_states(root)
        checks += 1

    with tempfile.TemporaryDirectory() as directory:
        pins = valid_pins(STAGED, LIVE_TEXT)
        pins["successors"][0]["staged"] = f"specs/epic-999-unknown/human-copy/{LIVE}"
        root = Path(directory)
        stage(root, "epic-999-unknown", LIVE, STAGED)
        (root / LIVE).parent.mkdir(parents=True)
        (root / LIVE).write_text(LIVE_TEXT, encoding="utf-8")
        write_pins(root, pins)
        assert [r[0] for r in MODULE.classify(directory, MainMap())] == ["PENDING"], (
            "a pin cannot extend the two known pairs to another bundle"
        )
        checks += 1
    return checks


def check_other_mirrors_unchanged() -> int:
    with tempfile.TemporaryDirectory() as directory:
        root = ship_root(directory)
        stage(root, "fixture-stale", OTHER, "staged==main\n")
        stage(root, "fixture-pending", "plugins/other/pending.txt", "waiting for human\n")
        stage(root, "fixture-fresh", "plugins/other/fresh.txt", "same\n")
        (root / OTHER).parent.mkdir(parents=True)
        for rel, text in ((OTHER, "live moved\n"), ("plugins/other/pending.txt", "live differs\n"),
                          ("plugins/other/fresh.txt", "same\n")):
            (root / rel).write_text(text, encoding="utf-8")
        main = {OTHER: sha("staged==main\n"), "plugins/other/pending.txt": sha("main differs\n")}
        got = {row[2]: row[0] for row in MODULE.classify(str(root), MainMap(main)) if row[2] != LIVE}
        assert got == {OTHER: "STALE", "plugins/other/pending.txt": "PENDING",
                       "plugins/other/fresh.txt": "FRESH"}, got
        # Unrelated stale/pending stay put even when the ship pins are unusable.
        write_pins(root, "{broken")
        again = {row[2]: row[0] for row in MODULE.classify(str(root), MainMap(main)) if row[2] != LIVE}
        assert again == got, again
    return 3


def check_manifest_digest_independent() -> int:
    with tempfile.TemporaryDirectory() as directory:
        root = ship_root(directory)
        assert list(MODULE.manifest_digest_mismatches(directory)) == []
        manifest = root / "specs" / EPICS[0] / "human-copy" / "MANIFEST.sha256"
        manifest.write_text(f"{'0' * 64}  {LIVE}\n", encoding="utf-8")
        expect(root, "PUBLISHED", "stale manifest digest does not change the pin classification")
        rows = list(MODULE.manifest_digest_mismatches(directory))
        assert [(r[0].replace("\\", "/"), r[1], r[2], r[3]) for r in rows] == [
            (f"specs/{EPICS[0]}/human-copy", LIVE, "0" * 64, sha(STAGED))
        ], rows
        # The reverse: a published pair with a correct manifest is not reported.
        manifest.write_text(f"{sha(STAGED)}  {LIVE}\n", encoding="utf-8")
        assert list(MODULE.manifest_digest_mismatches(directory)) == []
    return 2


def main() -> None:
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        setup_bundle(root)
        assert states(root, None) == ["PENDING"], "new human-copy file must remain pending"
        staged = root / "specs" / "fixture" / "human-copy" / "plugins" / "example.txt"
        assert states(root, hashlib.sha256(staged.read_bytes()).hexdigest()) == ["MISSING"], (
            "missing file that exists on main must remain a failure"
        )
    passed = 2
    passed += check_ship_successors()
    passed += check_pins_never_waive()
    passed += check_other_mirrors_unchanged()
    passed += check_manifest_digest_independent()
    print(f"human-copy mirror classification regression: {passed} passed")


if __name__ == "__main__":
    main()
