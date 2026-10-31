# T-002 Registry additive candidate — NOT APPLIED

Base HEAD: `06bc32cc26f2d67adb02e827610b5230e1658f72`
Run ID: `sdd423-registry-registration-recovery-20260929`

This candidate only registers four already-existing Python gate masters.
It preserves every existing gate and capability, including the unavailable
required `check-update-migration`. Its remaining diagnostic is intentional
fail-closed evidence, not a Registry PASS. No protected source was applied,
no task state or formal review verdict was changed, and no Windows execution
is claimed. See `verification/T-002/registry-registration-recovery.md` for
the separate fixture/production contract conflict and unresolved decision.

Before any human application, run from the repository root and require both
the exact HEAD above and every baseline hash to match. The hashes include all
three source artifacts and all four registered masters. If any differs, stop
and regenerate/reverify the candidate; do not apply this stale snapshot.

```sh
rtk proxy git rev-parse HEAD
rtk proxy shasum -a 256 --check specs/sdd-domain-multitarget/human-copy/T-002-registry/BASELINE.sha256
rtk proxy python3 specs/sdd-domain-multitarget/verification/T-002/registry-registration.tests.py --candidate
```

The existing `apply-human-copy` publisher rejects duplicate basenames in a
single batch (`plugins/sdd-quality-loop/scripts/apply-human-copy.sh:593`).
Therefore canonical/vendor `capability-registry.json` cannot share one
manifest. The human-only sequence below uses the existing publisher without
changing it: canonical first, then vendored Registry plus generated projection.
The two invocations are **not one atomic three-file transaction**; between
them the derived copies are stale, and release/verification must not run.
If publication fails, follow the publisher's existing recovery contract and
do not claim completion or bypass a refusal.

```sh
rtk proxy sh plugins/sdd-quality-loop/scripts/apply-human-copy.sh --staging-dir specs/sdd-domain-multitarget/human-copy/T-002-registry --manifest specs/sdd-domain-multitarget/human-copy/T-002-registry/CANONICAL.MANIFEST.sha256
rtk proxy sh plugins/sdd-quality-loop/scripts/apply-human-copy.sh --staging-dir specs/sdd-domain-multitarget/human-copy/T-002-registry --manifest specs/sdd-domain-multitarget/human-copy/T-002-registry/DERIVED.MANIFEST.sha256
rtk proxy bash plugins/sdd-quality-loop/scripts/vendor-capability-registry.sh --check
rtk proxy bash plugins/sdd-quality-loop/scripts/generate-gate-capabilities.sh --check
rtk proxy python3 specs/sdd-domain-multitarget/verification/T-002/registry-registration.tests.py
```

The last suite should pass only the registration/fail-closed assertions, not
the full Registry gate: the real validator must still exit 1 naming only the
unavailable migration implementation. After publication, `--candidate` is no
longer a valid pre-apply check because the exact baseline has changed.

Preparation and candidate verification only were authorized/executed here.
These human commands have **not** been executed by the agent; this README is
not authorization to bypass the existing source protection.
