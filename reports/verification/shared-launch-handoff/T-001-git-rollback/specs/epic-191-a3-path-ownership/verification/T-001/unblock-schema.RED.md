# T-001 acceptance-first RED evidence — 2026-08-08

Run ID: t001-20260808-codex-02

The original acceptance-first evidence remains in the pre-existing
`component-path-resolver.RED.log`. After the external Epic A1 artifacts
landed, the resumed TDD attempt reproduced the following mismatches before
each corresponding product change.

## Contract-unblock RED

Commands:

```text
bash tests/component-path-resolver.tests.sh
pwsh -NoProfile -File tests/component-path-resolver.tests.ps1
```

- Bash: 38 passed, 7 failed.
- PowerShell: 41 passed, 4 failed.
- Failures showed that the resolver rejected canonical `components: []`, did
  not validate the real JSON Schema instance, and emitted the wrong
  `excluded_match` evidence shape.

## PowerShell case-sensitivity RED

Mis-cased negative fixtures were added before the PowerShell implementation
was narrowed to ordinal/case-sensitive comparisons.

- Bash: 54 passed, 0 failed (the Python master already rejected them).
- PowerShell: 52 passed, 2 failed.
- Failing branches: `classification: Cross-Cutting` and top-level
  `Components:` were incorrectly accepted.

A focused schema-contract mutation (`id` to `ID`) also returned non-zero from
the Python master but exit 0 from the PowerShell twin before exact property-name
checks were added.

## Canonical component-field RED

An ordinary resolve test using the pre-A1 legacy component key failed before
the loader was changed to require canonical `id`. The deliberately-invalid
fixture also tripped the fixture-corpus assertion, producing 56 passed / 2
failed; the negative fixture was subsequently generated at runtime so the
test source is not its own false-positive target.

## Ownership-input projection RED

TEST-011.8 was added before the serializer change and proved that the resolver
rewrote canonical `components[].id` to the legacy key in `ownership_input`.

- Bash: 58 passed, 1 failed.
- PowerShell: 58 passed, 1 failed.

The final Green state is recorded in `unblock-schema.GREEN.md`.
