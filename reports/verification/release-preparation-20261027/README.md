# Concrete local release preparation

The existing release packaging mechanism built a source archive from exact
commit `4ac41d51`; its absolute local path, SHA-256 and size are in `receipt.json`.
The existing CycloneDX generator produced the attached 101-component SBOM.
Release loop prerequisites passed: consistency 34/34, inventory 76/76.
Warnings in the logs belong to their isolated negative controls; none of the
required tests was omitted. The source archive remains outside the Git tree
to avoid committing a generated copy of the entire repository.

This is reviewable packaging, not a published release, Sigstore attestation or
the full #197 release cycle. No tag or release was created. The A9 candidate
preflight is retained: candidate valid, no signed approval, no activation and
no promotion authority. There are no published final releases in the current
repository API observation. A genuine cycle cannot be synthesized retrospectively.

Before publication, choose the final source, obtain its successful required CI,
finish the existing protected Phase-1 publication through its real operator
route, and collect advisory evidence for every PR in the bounded release cycle.
The existing release workflow requires a real tag and exact-source CI and emits
the actual SBOM/checksums/provenance. Later promotion additionally requires the
already defined signed approval/decision, findings triage, all three platforms,
successful signed rollback rehearsal and post-promotion real-feature completion.
This packet does not authorize or bypass any of those transitions.
