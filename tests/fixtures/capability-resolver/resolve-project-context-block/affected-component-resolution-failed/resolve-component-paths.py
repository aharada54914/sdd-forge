#!/usr/bin/env python3
"""T-003 fixture stub: deterministically fails, standing in for a genuine
`resolve-component-paths` non-zero exit (step 4's own
`affected-component-resolution-failed` Block), so this suite can assert the
Block fires without depending on a real git-diff failure mode."""
import sys

sys.stderr.write("resolve-component-paths: FIXTURE_INJECTED_FAILURE\n")
sys.exit(3)
