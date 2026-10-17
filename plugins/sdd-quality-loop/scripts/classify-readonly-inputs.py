#!/usr/bin/env python3
"""Classify input operands of three shipped, pure read-only Python CLIs.

This helper parses argv and checks script identity; it never executes that argv.
Unknown syntax, distribution files, or execution directories grant no exemption.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import sys

FIELDS = {"input_options", "value_options", "switch_options", "required", "positionals"}
REDIRECT = re.compile(r"^(?:\d*|&)(>>?)([\s\S]*)$")
FD_DUP = re.compile(r"^&(?:\d+|-)$")


def classify(tokens, directories):
    try:
        if not isinstance(tokens, list) or not isinstance(directories, list):
            return []
        if any(not isinstance(t, list) or len(t) != 2 or t[0] not in ("word", "sep")
               or not isinstance(t[1], str) for t in tokens):
            return []
        if any(t[0] == "word" and (any(c in t[1] for c in "$`(){}*?[]")
               or "<" in t[1] or t[1].startswith(("#", "~")) or t[1].lower().replace("\\", "/").rsplit("/", 1)[-1]
               in ("cd", "pushd", "popd")) for t in tokens):
            return []
        words = []
        for index, (kind, text) in enumerate(tokens):
            if kind == "sep":
                if words:
                    break
            else:
                words.append((index, text))
        if len(words) < 2 or words[0][1] not in ("python", "python3"):
            return []
        roots = []
        for directory in directories or [os.getcwd()]:
            if not isinstance(directory, str) or not Path(directory).is_absolute():
                return []
            root = Path(directory).resolve(strict=True)
            if not root.is_dir():
                return []
            roots.append(root)
        if any(root != roots[0] for root in roots):
            return []
        script_dir = Path(__file__).resolve().parent
        script = Path(words[1][1])
        if not script.is_absolute():
            script = roots[0] / script
        script = script.resolve(strict=True)
        if not script.is_file() or script.parent != script_dir:
            return []
        catalog = json.loads((script_dir.parent / "references/readonly-input-contracts.json").read_text(encoding="utf-8"))
        if set(catalog) != {"schema_version", "commands"} or type(catalog["schema_version"]) is not int or catalog["schema_version"] != 1:
            return []
        variants = catalog["commands"].get(script.name, [])
        args = []
        cursor = 2
        while cursor < len(words):
            index, text = words[cursor]
            if ">" in text:
                match = REDIRECT.fullmatch(text)
                if not match:
                    return []
                target = match.group(2)
                if not target:
                    cursor += 1
                    if cursor >= len(words) or ">" in words[cursor][1]:
                        return []
                elif target.startswith("&") and not FD_DUP.fullmatch(target):
                    return []
                # Redirects and their targets are NEVER input exemptions.
            else:
                args.append((index, text))
            cursor += 1
        for contract in variants:
            if set(contract) != FIELDS or type(contract["positionals"]) is not int:
                return []
            inputs, values, switches = contract["input_options"], contract["value_options"], contract["switch_options"]
            if not all(isinstance(v, list) and all(isinstance(s, str) for s in v)
                       for v in (inputs, switches, contract["required"])) or not isinstance(values, dict):
                return []
            seen, read_indices, positionals = set(), [], 0
            cursor = 0
            valid = True
            while cursor < len(args):
                index, text = args[cursor]
                option, separator, attached = text.partition("=")
                if text.startswith("-"):
                    if option in seen:
                        valid = False
                        break
                    seen.add(option)
                    if option in switches:
                        if separator:
                            valid = False
                            break
                    elif option in inputs or option in values:
                        if separator:
                            value, value_index = attached, index
                        else:
                            cursor += 1
                            if cursor >= len(args):
                                valid = False
                                break
                            value_index, value = args[cursor]
                        if not value or value.startswith(("-", "~")):
                            valid = False
                            break
                        if option in inputs:
                            read_indices.append(value_index)
                        elif not isinstance(values[option], list) or value not in values[option]:
                            valid = False
                            break
                    else:
                        valid = False
                        break
                else:
                    positionals += 1
                    read_indices.append(index)
                cursor += 1
            if valid and positionals == contract["positionals"] and set(contract["required"]) <= seen:
                return sorted(read_indices)
    except (OSError, ValueError, TypeError, KeyError, AttributeError):
        pass
    return []


def main():
    try:
        request = json.load(sys.stdin)
        if set(request) != {"tokens", "directories"}:
            raise ValueError("invalid request")
        result = classify(request["tokens"], request["directories"])
        print(json.dumps(result, separators=(",", ":")))
        return 0
    except Exception:
        print("[]")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
