"""Acceptance checks for the design contract to CSS command."""

from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/generate_tokens.py"
SOURCE = Path(os.environ.get("TASK_BOARD_TOKEN_SOURCE", ROOT / "design-system/design-tokens.json"))
EXPECTED = """/* Generated from design tokens; do not edit. */
:root {
  --color-background: #ffffff;
  --color-border: #8b949e;
  --color-danger: #b42318;
  --color-primary: #007f78;
  --color-text: #102038;
  --layout-max-width: 880px;
  --layout-mobile-breakpoint: 640px;
  --layout-touch-target: 44px;
  --radius-md: 8px;
  --spacing-lg: 24px;
  --spacing-md: 16px;
  --spacing-sm: 8px;
  --spacing-xl: 40px;
  --spacing-xs: 4px;
  --typography-font-family-base: system-ui, sans-serif;
  --typography-font-size-base: 16px;
  --typography-font-size-heading: 32px;
  --typography-line-height-base: 1.5;
}
"""


def contract() -> dict[str, object]:
    """A small independent contract for invalid-input and CLI checks."""
    return {
        "meta": {
            "schema": "design-system-contract/v1",
            "version": "0.1.0",
            "generated_by": "manual",
            "profile": "custom",
        },
        "spacing": {"small": {"$type": "dimension", "$value": "4px"}},
    }


class TokenAcceptanceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.directory = tempfile.TemporaryDirectory(prefix="task-board-tokens-")
        self.addCleanup(self.directory.cleanup)
        self.work = Path(self.directory.name)
        self.source = self.work / "tokens.json"
        self.output = self.work / "nested/tokens.css"

    def run_generator(self, source: Path | None = None) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, "-B", str(SCRIPT), "--input", str(source or self.source),
             "--output", str(self.output)],
            cwd=self.work, text=True, capture_output=True, check=False,
        )

    def write_source(self, value: object) -> None:
        self.source.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")

    def assert_rejected(self, value: object) -> None:
        self.write_source(value)
        self.output.parent.mkdir(exist_ok=True)
        self.output.write_bytes(b"previous generated CSS\n")
        result = self.run_generator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error:", result.stderr.lower())
        self.assertNotIn("Traceback", result.stderr)
        self.assertEqual(self.output.read_bytes(), b"previous generated CSS\n")

    def test_actual_contract_has_expected_values_and_deterministic_bytes(self) -> None:
        before = SOURCE.read_bytes()
        first = self.run_generator(SOURCE)
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(self.output.read_bytes(), EXPECTED.encode())
        second = self.run_generator(SOURCE)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertEqual(self.output.read_bytes(), EXPECTED.encode())
        self.assertEqual(SOURCE.read_bytes(), before)

    def test_sorted_nested_names_and_quoted_font_family(self) -> None:
        value = contract()
        value["z"] = {"depth": {"weight": {"$type": "number", "$value": 2}}}
        value["a"] = {"font": {"$type": "fontFamily", "$value": ["Noto Sans JP", "sans-serif"]}}
        self.write_source(value)
        result = self.run_generator()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.output.read_text(),
                         '/* Generated from design tokens; do not edit. */\n:root {\n'
                         '  --a-font: "Noto Sans JP", sans-serif;\n'
                         '  --spacing-small: 4px;\n  --z-depth-weight: 2;\n}\n')
        value = dict(reversed(list(value.items())))
        self.write_source(value)
        self.assertEqual(self.run_generator().returncode, 0)
        self.assertLess(self.output.read_text().index("--a-font"),
                        self.output.read_text().index("--z-depth-weight"))

    def test_invalid_token_types_values_and_shapes(self) -> None:
        invalid: list[object] = [
            None, [], "4px", {}, {"$type": "dimension"}, {"$value": "4px"},
            {"$type": "unsupported", "$value": "4px"},
            {"$type": "dimension", "$value": "4px", "extra": 1},
            {"$type": "dimension", "$value": 4},
            {"$type": "dimension", "$value": "4px; color: red"},
            {"$type": "dimension", "$value": "calc(1px + 2px)"},
            {"$type": "color", "$value": "#xyzxyz"},
            {"$type": "color", "$value": "red; } body { display: none"},
            {"$type": "color", "$value": True},
            {"$type": "number", "$value": True},
            {"$type": "number", "$value": "1.5"},
            {"$type": "number", "$value": float("nan")},
            {"$type": "number", "$value": float("inf")},
            {"$type": "fontFamily", "$value": "sans-serif"},
            {"$type": "fontFamily", "$value": []},
            {"$type": "fontFamily", "$value": ["safe", 1]},
            {"$type": "fontFamily", "$value": [""]},
            {"$type": "fontFamily", "$value": ["sans-serif; color: red"]},
        ]
        for token in invalid:
            with self.subTest(token=token):
                value = contract()
                value["spacing"] = {"small": token}
                self.assert_rejected(value)

    def test_invalid_metadata_and_empty_contract(self) -> None:
        invalid: list[object] = [None, [], {}, {"schema": "unknown", "version": "0.1.0"},
                                 {"schema": "design-system-contract/v1", "version": 1},
                                 {"schema": "design-system-contract/v1", "version": ""}]
        for metadata in invalid:
            with self.subTest(metadata=metadata):
                value = contract()
                value["meta"] = metadata
                self.assert_rejected(value)
        self.assert_rejected({"meta": contract()["meta"]})
        self.assert_rejected({"spacing": {"small": {"$type": "number", "$value": 1}}})
        self.assert_rejected([])

    def test_unsafe_names_and_flattening_collisions(self) -> None:
        for name in ["", "0bad", "bad name", "bad;name", "$unknown", "x\n}"]:
            with self.subTest(name=name):
                value = contract()
                value[name] = {"$type": "number", "$value": 1}
                self.assert_rejected(value)
        value = contract()
        value["a-b"] = {"c": {"$type": "number", "$value": 1}}
        value["a"] = {"b-c": {"$type": "number", "$value": 2}}
        self.assert_rejected(value)

    def test_malformed_duplicate_key_and_non_utf8_input(self) -> None:
        valid = json.dumps(contract())
        inputs = [b"{", b"\xff", valid.replace('"4px"', '"4px", "$value": "8px"').encode()]
        for raw in inputs:
            with self.subTest(raw=raw):
                self.source.write_bytes(raw)
                result = self.run_generator()
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("error:", result.stderr.lower())
                self.assertNotIn("Traceback", result.stderr)
                self.assertFalse(self.output.exists())

    def test_missing_input_fails_visibly_without_output(self) -> None:
        result = self.run_generator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error:", result.stderr.lower())
        self.assertNotIn("Traceback", result.stderr)
        self.assertFalse(self.output.exists())

    def test_output_io_failure_is_visible(self) -> None:
        self.write_source(contract())
        self.output.parent.write_text("not a directory")
        result = self.run_generator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error:", result.stderr.lower())
        self.assertNotIn("Traceback", result.stderr)

    def test_input_cannot_be_overwritten_by_output(self) -> None:
        self.write_source(contract())
        original = self.source.read_bytes()
        self.output = self.source
        result = self.run_generator()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("error:", result.stderr.lower())
        self.assertEqual(self.source.read_bytes(), original)

    def test_defaults_are_relative_to_script_not_working_directory(self) -> None:
        app = self.work / "app"
        (app / "scripts").mkdir(parents=True)
        (app / "design-system").mkdir()
        shutil.copyfile(SCRIPT, app / "scripts/generate_tokens.py")
        (app / "design-system/design-tokens.json").write_text(json.dumps(copy.deepcopy(contract())))
        result = subprocess.run([sys.executable, "-B", str(app / "scripts/generate_tokens.py")],
                                cwd=self.work, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((app / "design-system/build/tokens.css").read_text(),
                         "/* Generated from design tokens; do not edit. */\n"
                         ":root {\n  --spacing-small: 4px;\n}\n")


if __name__ == "__main__":
    unittest.main()
