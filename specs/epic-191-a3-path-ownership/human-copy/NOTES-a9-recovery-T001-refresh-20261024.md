# Shared precheck mirror refresh — A9 recovery T-001, 2026-10-24

The two already-applied `spec-review-precheck.{sh,ps1}` mirrors and their existing
`MANIFEST.sha256` entries were refreshed with the unchanged
`python3 scripts/sync-human-copy-mirrors.py` procedure from
`docs/contributor/shared-file-mirrors.md` (WFI-039).

At source `6cb9ef2d585cf3ad561624a92335259f8d058ca2` and `origin/main`
`fcb8275a42061b8132ea88a36e69b02f4487be71`, both staged files equaled main's
live bytes and differed from the approved T-001 live implementation. The shared
classifier therefore reported exactly these two files as STALE. This refresh
updates an already-applied shared mirror; it does not apply pending work or
change historical review results, approvals, input manifests, or logs.

| Mirror | Prior staged/main SHA-256 | Refreshed/live SHA-256 |
| --- | --- | --- |
| `spec-review-precheck.sh` | `73a547e30025ad4c54313aaf03a3bec31286e50f90d80c37340c22ffee0603d4` | `88062b265569f02573565aa904d26b4385eea5f4e45b82e4c819732f476752f2` |
| `spec-review-precheck.ps1` | `08792df3be712917b9e771abec28e153a8d013624286ad221da1837f2d462b2e` | `fc41fea4e6c6c3eeb39bb2e9ca4f5f96d7a1a9c70ce78fe47d9934000966b60e` |

The twelve-entry manifest retains its membership and order; only these two
existing digest rows change. The six pending guard-invariant mirrors, their
digests, the existing additive-evolution checks and the six pinned T-001 source
files remain unchanged. Historical records and earlier notes remain intact.
This is mirror freshness maintenance, not a new historical approval or a formal
Done decision. The failed CI run remains evidence of the omitted refresh;
final integration requires a new successful run on the final revision.
