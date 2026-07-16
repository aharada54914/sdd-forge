"""Canonical brownfield seed: pre-existing, task-unrelated legacy utility
(T-002 / Issue #146). Carries a single pre-existing marker unrelated to any
changed feature -- never appears in CHANGED_FILES.txt.
"""


def normalize(text):
    # TODO: revisit encoding for non-UTF-8 legacy inputs
    return text.strip()
