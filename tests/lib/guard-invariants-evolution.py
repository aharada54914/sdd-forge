"""Check additive live inventory evolution against the immutable A1 archive."""
import argparse
import ast
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile


def generator_tree(path):
    tree = ast.parse(path.read_text(encoding="utf-8"))
    assignments = [node for node in tree.body if isinstance(node, ast.Assign)
                   and any(isinstance(target, ast.Name) and target.id == "BASELINE_SUFFIXES"
                           for target in node.targets)]
    if len(assignments) != 1:
        raise ValueError("expected one literal BASELINE_SUFFIXES assignment")
    value = ast.literal_eval(assignments[0].value)
    if not isinstance(value, tuple) or not all(isinstance(item, str) for item in value):
        raise ValueError("BASELINE_SUFFIXES must be a string tuple")
    assignments[0].value = ast.Tuple(elts=[], ctx=ast.Load())
    return ast.dump(tree), value


def retains_ordered(original, current):
    return (len(current) == len(set(current))
            and [item for item in current if item in original] == list(original))


def validate(staged, live):
    # Authenticate archive bytes before importing its validator or renderer.
    manifest = staged.parents[1] / "MANIFEST.sha256"
    entries = dict(line.split("  ", 1)[::-1] for line in manifest.read_text(encoding="utf-8").splitlines() if line)
    for relative in ("references/guard-invariants.json", "scripts/generate-guard-invariants.py"):
        path = staged / relative
        expected = entries.get(path.relative_to(manifest.parent).as_posix())
        if expected != hashlib.sha256(path.read_bytes()).hexdigest():
            raise ValueError("archived invariant source does not match its frozen manifest")
    staged_generator = staged / "scripts/generate-guard-invariants.py"
    live_generator = live / "scripts/generate-guard-invariants.py"
    staged_code, staged_baseline = generator_tree(staged_generator)
    live_code, live_baseline = generator_tree(live_generator)
    if live_code != staged_code:
        raise ValueError("generator changed beyond the baseline inventory")
    if not retains_ordered(staged_baseline, live_baseline):
        raise ValueError("live baseline removed, reordered or duplicated a protection")

    spec = importlib.util.spec_from_file_location("archived_invariants", staged_generator)
    generator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(generator)
    original, _ = generator.load_and_validate(staged / "references/guard-invariants.json")
    # Use the archived validator and renderer, not a potentially weakened live one.
    generator.BASELINE_SUFFIXES = live_baseline
    current, digest = generator.load_and_validate(live / "references/guard-invariants.json")
    if not retains_ordered(original["protected_gate_suffixes"], current["protected_gate_suffixes"]):
        raise ValueError("live inventory removed or reordered a staged protection")
    original.pop("protected_gate_suffixes")
    current_policy = dict(current)
    current_policy.pop("protected_gate_suffixes")
    if original != current_policy:
        raise ValueError("live policy changed beyond additive protected paths")
    for path, content in generator.expected_outputs(current, digest, live / "scripts/generated").items():
        if path.read_bytes() != content.encode("ascii"):
            raise ValueError("live generated projection differs: " + path.name)


def self_test(staged, live):
    """Mutate coherent candidates so passing cannot be a stale-output side effect."""
    validate(staged, live)
    spec = importlib.util.spec_from_file_location("fixture_invariants", staged / "scripts/generate-guard-invariants.py")
    generator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(generator)
    current = json.loads((live / "references/guard-invariants.json").read_text(encoding="utf-8"))
    source = (live / "scripts/generate-guard-invariants.py").read_text(encoding="utf-8")
    historical = generator.BASELINE_SUFFIXES[0]

    with tempfile.TemporaryDirectory(prefix="guard-evolution-") as directory:
        candidate = Path(directory)
        (candidate / "references").mkdir()
        (candidate / "scripts/generated").mkdir(parents=True)

        corrupted_archive = candidate / "archive/plugins/sdd-quality-loop"
        (corrupted_archive / "references").mkdir(parents=True)
        (corrupted_archive / "scripts").mkdir()
        (corrupted_archive.parents[1] / "MANIFEST.sha256").write_bytes((staged.parents[1] / "MANIFEST.sha256").read_bytes())
        for relative in ("references/guard-invariants.json", "scripts/generate-guard-invariants.py"):
            (corrupted_archive / relative).write_bytes((staged / relative).read_bytes() + b"\n")
        try:
            validate(corrupted_archive, live)
        except ValueError as error:
            if "frozen manifest" not in str(error):
                raise
        else:
            raise AssertionError("accepted unauthenticated archived source")

        def write_fixture(data, code):
            raw = (json.dumps(data, indent=2) + "\n").encode("utf-8")
            (candidate / "references/guard-invariants.json").write_bytes(raw)
            (candidate / "scripts/generate-guard-invariants.py").write_text(code, encoding="utf-8")
            for path, content in generator.expected_outputs(data, hashlib.sha256(raw).hexdigest(), candidate / "scripts/generated").items():
                path.write_bytes(content.encode("ascii"))

        def reject(label):
            try:
                validate(staged, candidate)
            except (ValueError, OSError):
                return
            raise AssertionError("accepted mutation: " + label)

        # A second addition must pass without refreshing any frozen digest.
        added = copy.deepcopy(current)
        added["protected_gate_suffixes"].insert(0, "plugins/example/new-gate.py")
        added_code = source.replace("BASELINE_SUFFIXES = (", 'BASELINE_SUFFIXES = (\n    "plugins/example/new-gate.py",', 1)
        write_fixture(added, added_code)
        validate(staged, candidate)

        removed = copy.deepcopy(current)
        removed["protected_gate_suffixes"].remove(historical)
        write_fixture(removed, source.replace('    "' + historical + '",\n', "", 1))
        reject("coherent removal of historical protection")

        reordered = copy.deepcopy(current)
        reordered["protected_gate_suffixes"][:2] = reversed(reordered["protected_gate_suffixes"][:2])
        write_fixture(reordered, source)
        reject("reordered protections")

        duplicated = copy.deepcopy(current)
        duplicated["protected_gate_suffixes"].append(historical)
        write_fixture(duplicated, source)
        reject("duplicate protection")

        weakened = copy.deepcopy(current)
        weakened["shell"]["read_only_start_re"] = ".*"
        write_fixture(weakened, source)
        reject("coherent policy weakening")

        write_fixture(current, source + "\nBASELINE_SUFFIXES = ()\n")
        reject("generator validation bypass")

        for name in ("guard_invariants.py", "guard-invariants.generated.js", "guard-invariants.generated.ps1", "guard-invariants.generated.sh"):
            write_fixture(current, source)
            path = candidate / "scripts/generated" / name
            path.write_bytes(path.read_bytes() + b"stale\n")
            reject("stale " + name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("staged", type=Path)
    parser.add_argument("live", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    try:
        (self_test if args.self_test else validate)(args.staged, args.live)
    except (ValueError, OSError, AssertionError) as error:
        parser.exit(1, str(error) + "\n")
