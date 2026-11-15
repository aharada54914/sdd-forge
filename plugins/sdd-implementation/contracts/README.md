# Packaged model capability contracts

The two JSON registries here are byte-identical distribution mirrors of the
canonical repository `contracts/agent-model-capabilities*.json` files. Update both
locations together; `tests/model-selector-package.tests.py` enforces equality.

Source-layout selectors retain the canonical repository defaults. Standalone and
versioned plugin installs use these local mirrors instead of assuming the source
repository's parent directories exist. Explicit registry arguments retain their
existing semantics. Legacy selection defaults to v1; policy selection defaults to
v2. Use an explicit packaged v2 path for registered v2 capabilities in the legacy
selector. Packaging does not declare host availability, invent model tiers, or
admit an unsupported managed launch route.
