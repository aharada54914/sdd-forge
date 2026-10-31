"""Fixed Concept Test Markdown projection shared by validation and authoring."""

import json


def render_concept_test_md(obj):
    body = json.dumps(
        obj, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False,
    )
    return ("# Concept Test\n\n" + "\n".join("    " + line for line in body.split("\n")) + "\n").encode("utf-8")
