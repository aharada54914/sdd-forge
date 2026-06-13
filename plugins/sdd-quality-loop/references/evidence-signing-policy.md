# Evidence Signing Policy (Critical bundles)

Critical-risk evidence bundles (`risk: critical`) must carry a cryptographic
signature that binds the bundle's security-relevant claims to an external key
holder. An agent without the key cannot mint a valid critical bundle. This
mirrors the sudo-token signing design (see `sudo-mode-policy.md`) and adds no new
crypto primitive.

## Why a fixed-field canonical string (not whole-JSON canonicalization)

The design (design.md §6) calls for HMAC over the canonicalized bundle. A
byte-identical whole-JSON serialization is **not** reliably reproducible across
the two runtimes (`python3` for `*.sh`, PowerShell for `*.ps1`): key ordering at
depth, number formatting, and unicode escaping differ. A signature that the
generator and verifier compute from different byte streams is worthless. We
therefore sign a **fixed, ordered list of scalar fields joined by LF** — exactly
the approach the sudo token already uses (`_sudo_canonical`) — which is trivially
identical across runtimes and injection-safe.

## Signing key resolution (external-only, never in-repo, never agent-readable)

Identical priority order across all runtimes. Mirrors the sudo-key resolver but
uses an **evidence-specific** variable so the two keys are independent:

1. Env `SDD_EVIDENCE_KEY` (non-empty) → key bytes are its UTF-8 bytes.
2. Else env `SDD_EVIDENCE_KEY_FILE` → read that file; drop a leading UTF-8 BOM;
   strip trailing whitespace/newlines.
3. Else `<HOME>/.sdd/evidence-key` (HOME = env `HOME` or `USERPROFILE`) → read +
   strip as above.
4. Else **no key** → a critical bundle cannot be generated or verified
   (fail-closed).

## Canonical string (v1)

The HMAC-SHA256 input is the following ten values joined by a single LF (`\n`),
with **no trailing newline**. Values are the stripped field values verbatim;
booleans are the literal lowercase `true`/`false`.

```
sdd-evidence-v1
<task_id>
<feature>
<risk>
<required_workflow>
<spec_revision>
<git_commit>
<git_generated_dirty>          # "true" or "false"
<review_verdict.verdict>       # e.g. "PASS" (empty string if absent)
<artifacts_digest>             # see below
```

`artifacts_digest` is the lowercase SHA-256 hex of the following byte string:
for every artifact in `artifacts[]`, form `"<path>\x00<sha256>"` (NUL `\x00`
separates the two; neither a repo-relative path nor a 64-hex digest can contain
NUL, so there is no ambiguity); **sort these strings ascending** (so artifact
order in the bundle does not affect the signature); join them with LF; SHA-256
the UTF-8 bytes. An empty `artifacts[]` digests the empty string.

The leading `sdd-evidence-v1` line is a domain/version tag that prevents
cross-protocol confusion (e.g. a sudo token being replayed as an evidence
signature) and lets future versions change the field set without ambiguity.

## Signature object in the bundle

```json
"signature": { "alg": "hmac-sha256", "value": "<lowercase-hex>", "key_ref": "env:SDD_EVIDENCE_KEY" }
```

- `alg`: `hmac-sha256` (local) or `sigstore` (CI attestation path).
- `value`: for `hmac-sha256`, the lowercase-hex HMAC-SHA256 of the canonical
  string. (For `sigstore`, an attestation reference; verification is performed by
  the CI step, not by the local hex compare.)
- `key_ref`: **descriptive only, never trusted** — records which source produced
  the key (`env:SDD_EVIDENCE_KEY`, `file:<path>`, `file:~/.sdd/evidence-key`).
  The verifier re-resolves the key itself; it does not honor `key_ref`.

## Generation (`generate-evidence-bundle`)

- Compute and attach `signature` **only when `risk == critical`**. Non-critical
  bundles carry no `signature` field (backward compatibility: bundles without the
  field validate exactly as before for risk ≤ high / legacy).
- If `risk == critical` and **no key resolves**, generation **fails** with a
  clear error. You cannot mint a critical bundle without the key — the control is
  enforced at authoring time, not only at verification time.
- Local generation always uses `hmac-sha256`. The `sigstore` path is produced by
  the CI attestation action (out of scope for this script).

## Verification (`check-evidence-bundle`, when effective risk == critical)

`effective_risk` is the **hash-validated contract risk** (never the bundle's own
self-asserted risk — see the T-006 fix). When it is `critical`:

1. **Reject a dirty tree**: if `git_generated_dirty == true`, FAIL. (For
   non-critical this stays warning-only.)
2. Require a `signature` object with non-empty `alg` and `value`.
3. If `alg == "hmac-sha256"`:
   - Resolve the evidence key. **If no key resolves, FAIL** (cannot verify ⇒
     fail-closed — never silently pass).
   - Recompute the canonical string from the bundle's own fields, recompute the
     HMAC, and compare **constant-time** (Python/Node `compare_digest`;
     PowerShell does an ordinal compare of equal-length lowercased hex). Mismatch
     ⇒ FAIL.
4. Else if `alg == "sigstore"`: require env `SDD_EVIDENCE_SIGSTORE_VERIFIED` to be
   truthy (set **only** by the CI step that has already verified the attestation).
   If unset, FAIL. This prevents an agent from writing `alg: sigstore` locally to
   dodge the HMAC check.
5. Else (missing/unknown `alg`): FAIL.

## Fail-closed cases that MUST be tested (both runtimes)

- critical bundle with **no** `signature` ⇒ FAIL
- critical bundle, valid signature, then **any** signed field tampered (risk,
  spec_revision, git_commit, an artifact sha256, the verdict) ⇒ FAIL
- critical bundle `alg: sigstore` without `SDD_EVIDENCE_SIGSTORE_VERIFIED` ⇒ FAIL
- critical bundle with missing/unknown `alg` ⇒ FAIL
- critical bundle with `git_generated_dirty: true` ⇒ FAIL
- no evidence key available at verify time ⇒ FAIL (not a silent pass)
- **high** (not critical) bundle without `signature` ⇒ PASS (signature is a
  critical-only requirement)
- legacy bundle (contract `risk` absent) ⇒ PASS (no signature required)

## See Also

- `sudo-mode-policy.md` — the sibling external-key signing design this mirrors.
- `risk-gate-matrix.md` — the canonical risk → required-control matrix.
- design.md §5–§7 — provenance, signature mechanism, two-person approval.
</content>
