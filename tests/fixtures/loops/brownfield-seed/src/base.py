"""Canonical brownfield seed: abstract base class (T-002 / Issue #146).

Each abstract hook below carries a legitimate stub-exception marker (see
the class body) modeling a real existing-codebase pattern. Neither this
file nor legacy_util.py ever appears in CHANGED_FILES.txt -- the
check-placeholders brownfield lock's Case B (full-directory scan) is the
only case meant to detect these pre-existing markers; Case A
(changed-files-only) must never see them (requirements.md Edge Cases).
"""


class BaseHandler:
    """Abstract handler; concrete subclasses must implement every hook."""

    def handle(self, payload):
        raise NotImplementedError

    def validate(self, payload):
        raise NotImplementedError

    def teardown(self):
        raise NotImplementedError
