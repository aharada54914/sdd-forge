# PR #409 / T-003 cross-model consent and preparation

Scope: epic-159-pillar-d, T-003 only.

The user explicitly authorized changing `Cross-Model: enabled` and sending
secret-redacted review material to the models. Other task flags are unchanged.
No approval, task status, or historical verdict was changed.

## Actual preparation result

Command:

```sh
bash plugins/sdd-quality-loop/scripts/prepare-panelist-input.sh --task T-003 --feature epic-159-pillar-d --input specs/epic-159-pillar-d/verification/T-003/ --spec-root specs --max-bytes 1048576
```

Exit: 1. Consent was accepted, but declared-output validation rejected:

- `specs/epic-159-pillar-d/tasks.md`
- `reports/implementation/epic-159-pillar-d/T-003.md`

The historical report's Outputs table declares a self-hash explicitly described
as the hash before inserting its own row. That is not the committed blob hash.
Its tasks.md declaration also fails the current/declaration-commit check.
Other drifted production outputs were accepted against declaration commit
`e8cdd74`; this does not make the two failed declarations valid.

`detect-panel.sh` exited 0 with `gpt`. No panelist runner was invoked and no
review material was sent externally. No cross-model PASS is established.

## Resume

### Declaration-commit verification

Read-only `git show e8cdd746:<path> | shasum -a 256` confirmed that
both declarations already disagree with their declaration commit, independently
of the new consent change:

| Artifact | Declared SHA-256 | Declaration-commit SHA-256 |
| --- | --- | --- |
| tasks.md | 9436d0c0cc0270371cb492d4dc96915fe8942313b4b0f5050f109c620d7662ee | bb45105c8ee0e3846bc1960259c96595d646e28e69f88fcc68f20f96b2e8861d |
| T-003 implementation report | a2fdf713ddfb8fbc7a0d3bf6541e4c51a9c31ea511f2609ad20c0c610d79ca56 | 4c62987e75a893022d0b578f6a6f1e6210333c1487ad42e17bcbe74d260a8a0a |

The current report still has exactly the declaration-commit hash above. It was
not modified. The actual consent update is not the origin of these two invalid
historical declarations.

Preserve the historical report and failed results. Resolve the declaration
contract using a traceable current-artifact record / supported report selection
before retrying preparation. Do not silently replace old hashes, omit declared
files, forge a self-hash, or bypass the preparation validator. Check sanitized
input coverage and content before blind vendor collection.
